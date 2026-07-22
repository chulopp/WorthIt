"""
backtest_v2.py — WorthIt Full-Pipeline Backtesting

Menggunakan engine/scoring.py::run_analysis() secara langsung untuk
mengevaluasi akurasi keputusan WorthIt terhadap data historis nyata.

Algoritma:
  1. Ambil semua produk dari Supabase (max 500)
  2. Untuk tiap produk, ambil price_history dan buat monthly_buckets
  3. Skip produk dengan < 4 bulan data
  4. Gunakan bulan 1..(N-1) sebagai training, bulan N sebagai target
  5. Jalankan run_analysis() dengan harga bulan N sebagai scanned_price
  6. Evaluasi correctness berdasarkan price movement

Output:
  - Console: hit rate, cost savings, accuracy per decision, 10 sample
  - File: data/backtest_latest.json
"""

from __future__ import annotations

import json
import os
import sys
from collections import defaultdict
from datetime import datetime, timezone

# ─── Path setup ───────────────────────────────────────────────────────────────
BACKEND_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, BACKEND_DIR)

from engine.scoring import run_analysis
from engine.backtesting import (
    Prediction,
    ActualOutcome,
    calculate_hit_rate,
    calculate_hit_rate_v2,
    calculate_cost_savings,
)
from utils.supabase_client import get_supabase


# ─── Decision Mapping ────────────────────────────────────────────────────────
# Removed DECISION_MAP mapping to BUY/SUBSTITUTE/DONT_BUY


# ─── Helpers ──────────────────────────────────────────────────────────────────

def _build_monthly_buckets(history: list[dict]) -> list[dict]:
    """
    Group price_history records into monthly buckets.
    Returns list of {month_offset, avg_price, avg_weight} sorted OLDEST → NEWEST.

    month_offset direlativkan ke record terlama agar training/test split
    tidak bergantung pada tanggal saat script dijalankan.
    """
    if not history:
        return []

    monthly: dict[str, list[dict]] = defaultdict(list)

    for record in history:
        raw_date = record["recorded_at"]
        if len(raw_date) >= 7:
            year_month = raw_date[:7]  # "YYYY-MM"
        else:
            continue
        monthly[year_month].append(record)

    buckets = []
    sorted_keys = sorted(monthly.keys())  # oldest first
    for idx, ym in enumerate(sorted_keys):
        records = monthly[ym]
        avg_price = sum(float(r["price"]) for r in records) / len(records)
        avg_weight = sum(float(r.get("weight_gram") or 0) for r in records) / len(records)
        buckets.append({
            "month_offset": idx,
            "avg_price": avg_price,
            "avg_weight": avg_weight,
        })

    return buckets


def _is_correct(decision: str, current_price: float, future_price: float) -> bool:
    if decision == "WorthIt":
        return future_price >= current_price
    elif decision == "Mahal":
        return future_price < current_price
    # Waspada = neutral, selalu return True biar gak dihitung negatif
    return True


# ─── Main Backtest Logic ──────────────────────────────────────────────────────

def run_backtest_v2() -> dict:
    sb = get_supabase()

    # 1. Fetch all products (max 500)
    print("📦 Fetching products from Supabase...")
    products_res = (
        sb.table("products")
        .select("id, name, category, base_weight_gram")
        .limit(500)
        .execute()
    )
    products = products_res.data or []
    print(f"   Found {len(products)} products")

    # 2. Iterate and build predictions
    raw_results: list[dict] = []
    predictions: list[Prediction] = []
    actuals: list[ActualOutcome] = []
    skipped = 0

    for i, product in enumerate(products):
        product_id = product["id"]
        product_name = product.get("name", "Unknown")
        category = product.get("category", "Unknown")
        weight_gram = float(product.get("base_weight_gram") or 0)

        # Fetch price history
        history_res = (
            sb.table("price_history")
            .select("price, weight_gram, recorded_at")
            .eq("product_id", product_id)
            .order("recorded_at", desc=False)
            .execute()
        )
        history = history_res.data or []

        # Build monthly buckets
        monthly_buckets = _build_monthly_buckets(history)

        # Skip if < 4 months of data
        if len(monthly_buckets) < 4:
            skipped += 1
            continue

        # Training: months 0..(N-2), Test target: month (N-1)
        training_buckets = monthly_buckets[:-1]
        test_month = monthly_buckets[-1]
        prev_month = monthly_buckets[-2]

        scanned_price = test_month["avg_price"]
        current_price = prev_month["avg_price"]  # "current" = the month before test
        future_price = test_month["avg_price"]    # "future" = the test month

        # Use weight from product or from history
        if weight_gram <= 0:
            weight_gram = test_month.get("avg_weight") or 100.0

        # 3. Run the real scoring engine
        try:
            result = run_analysis(
                scanned_price=scanned_price,
                current_weight=weight_gram,
                urgency=2,
                monthly_buckets=training_buckets,
                user_tier="FREE",
            )
        except Exception as e:
            print(f"   ⚠ Error scoring {product_name}: {e}")
            skipped += 1
            continue

        # 4. Map decision
        bt_decision = result["decision"]  # "WorthIt", "Waspada", atau "Mahal"

        # 5. Evaluate correctness
        was_correct = _is_correct(bt_decision, current_price, future_price)

        price_delta_pct = (
            ((future_price - current_price) / current_price * 100)
            if current_price > 0 else 0.0
        )

        # Build result record
        raw_results.append({
            "product_name": product_name,
            "category": category,
            "current_price": round(current_price, 2),
            "future_price": round(future_price, 2),
            "decision": bt_decision,
            "score": result["score"],
            "normal_price": result["normal_price"],
            "support": result["support"],
            "resistance": result["resistance"],
            "price_delta_percent": round(price_delta_pct, 2),
            "components": result["components"],
            "was_correct": was_correct,
        })

        # Build Prediction & ActualOutcome for hit_rate / cost_savings
        predictions.append(Prediction(
            decision=bt_decision,
            current_price=current_price,
            substitute_price=None,
        ))
        actuals.append(ActualOutcome(
            future_price=future_price,
            current_price=current_price,
            substitute_was_cheaper=False,
        ))

        # Progress
        if (i + 1) % 50 == 0:
            print(f"   Processed {i + 1}/{len(products)} products...")

    # 6. Calculate aggregate metrics
    # Hit rate = hanya WorthIt + Mahal
    evaluable = [r for r in raw_results if r["decision"] in ("WorthIt", "Mahal")]
    correct_in_evaluable = sum(1 for r in evaluable if r["was_correct"])
    hit_rate = (correct_in_evaluable / len(evaluable) * 100) if evaluable else 0.0

    # Simpan juga waspada_count
    waspada_count = sum(1 for r in raw_results if r["decision"] == "Waspada")

    cost_savings = calculate_cost_savings(predictions) if predictions else 0.0

    # Decision breakdown, gunakan key asli: WorthIt, Waspada, Mahal
    decision_breakdown: dict[str, dict] = {}
    for decision_type in ["WorthIt", "Waspada", "Mahal"]:
        matching = [r for r in raw_results if r["decision"] == decision_type]
        correct = sum(1 for r in matching if r["was_correct"])
        total = len(matching)
        accuracy = round((correct / total * 100), 2) if total > 0 else 0.0
        decision_breakdown[decision_type] = {
            "total": total,
            "correct": correct,
            "accuracy": accuracy,
        }

    # 7. Build final output
    output = {
        "total_predictions": len(raw_results),
        "total_products_tested": len(raw_results),
        "total_products_skipped": skipped,
        "hit_rate": hit_rate,
        "cost_savings_percent": cost_savings,
        "decision_breakdown": decision_breakdown,
        "raw_results": raw_results,
        "generated_at": datetime.now(timezone.utc).isoformat(),
        "evaluable_predictions": len(evaluable),
        "waspada_predictions": waspada_count,
    }

    return output


# ─── Console Output & File Save ──────────────────────────────────────────────

def main():
    print("=" * 60)
    print("  WorthIt Backtest v2 — Full Pipeline")
    print("=" * 60)
    print()

    output = run_backtest_v2()

    # ─── Console Summary ──────────────────────────────────────────────────
    print()
    print("═" * 60)
    print("  📊 BACKTEST RESULTS")
    print("═" * 60)
    print(f"  Total Products Tested : {output['total_products_tested']}")
    print(f"  Total Skipped         : {output['total_products_skipped']}")
    print(f"  Total Predictions     : {output['total_predictions']}")
    print(f"  Hit Rate              : {output['hit_rate']:.2f}%")
    print(f"  Cost Savings          : {output['cost_savings_percent']:.2f}%")
    print()

    print("  📈 Accuracy per Decision:")
    print("  ─" * 30)
    for decision, stats in output["decision_breakdown"].items():
        icon = "✅" if stats["accuracy"] >= 70 else ("⚠️" if stats["accuracy"] >= 50 else "❌")
        print(f"    {icon} {decision:12s} → {stats['correct']}/{stats['total']} = {stats['accuracy']:.1f}%")
    print()

    # ─── Sample Results ───────────────────────────────────────────────────
    print("  🔍 Sample Results (10):")
    print("  ─" * 30)
    samples = output["raw_results"][:10]
    for s in samples:
        check = "✅" if s["was_correct"] else "❌"
        print(
            f"    {check} {s['product_name'][:30]:30s} │ "
            f"Score={s['score']:3d} │ {s['decision']:10s} │ "
            f"Δ={s['price_delta_percent']:+.1f}%"
        )
    print()

    # ─── Save JSON ────────────────────────────────────────────────────────
    data_dir = os.path.join(BACKEND_DIR, "data")
    os.makedirs(data_dir, exist_ok=True)
    output_path = os.path.join(data_dir, "backtest_latest.json")

    with open(output_path, "w", encoding="utf-8") as f:
        json.dump(output, f, indent=2, ensure_ascii=False)

    print(f"  💾 Results saved to: {output_path}")
    print("=" * 60)


if __name__ == "__main__":
    main()
