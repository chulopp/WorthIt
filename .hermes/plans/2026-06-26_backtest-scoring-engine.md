# Backtest WorthIt Scoring Engine — Real Win Rate + Proposal Data

> **Target Agent:** Antigravity / Codex (vibe coding via prompt)
> **Goal:** Ganti backtest sederhana jadi full scoring engine, output win rate + data grafik buat proposal GEMASTIK

---

## Background

Saat ini `backend/scripts/backtest.py` menjalankan backtest dengan model **sederhana** (compare ke average price), BUKAN pakai full scoring engine (`engine/scoring.py`). Kita butuh backtest yang:

1. Menggunakan **full pipeline** `run_analysis()` yang sama dengan production API
2. Mengukur **win rate** berdasarkan prediksi vs actual future price
3. Menghasilkan **data numerik + grafik** untuk Bab 4 (Pengujian) dan Bab 5 (Metodologi) proposal GEMASTIK

---

## Task 1: Fix Backtest Engine — Gunakan Full Scoring Pipeline

### Objective
Buat script `backend/scripts/backtest_v2.py` yang menggunakan `engine/scoring.py::run_analysis()` langsung.

### Files
- Create: `backend/scripts/backtest_v2.py`
- Modify: (none — keep old backtest.py as reference)
- Read: `backend/engine/scoring.py`, `backend/engine/backtesting.py`, `backend/utils/supabase_client.py`

### Specification

```python
"""
backtest_v2.py — WorthIt Full Scoring Engine Backtest

Menggunakan run_analysis() asli untuk menghitung win rate.
Cocok untuk data proposal GEMASTIK (Bab 4 & 5).
"""

import os, sys, json
from datetime import datetime
from collections import defaultdict

sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from engine.scoring import run_analysis, get_decision
from engine.backtesting import (
    Prediction, ActualOutcome,
    calculate_hit_rate, calculate_cost_savings,
    format_backtesting_report
)
from utils.supabase_client import get_supabase


def prepare_monthly_buckets(price_history: list[dict]) -> list[dict]:
    """
    Group price_history rows into monthly buckets.
    Returns list sorted OLDEST → NEWEST, each bucket:
    {month_offset: int, avg_price: float, avg_weight: float}
    """
    by_month = defaultdict(list)
    for row in price_history:
        month_key = row["recorded_at"][:7]  # "2026-03"
        by_month[month_key].append(row)

    buckets = []
    for offset, (month_key, rows) in enumerate(sorted(by_month.items())):
        avg_price = sum(r["price"] for r in rows) / len(rows)
        avg_weight = sum(r.get("weight_gram", 0) or 0 for r in rows) / len(rows)
        buckets.append({
            "month_offset": offset,
            "avg_price": avg_price,
            "avg_weight": avg_weight,
        })
    return buckets


def run_full_backtest() -> dict:
    """
    Backtest menggunakan full scoring engine.
    
    Untuk setiap produk dengan ≥ 4 bulan data historis:
      - Ambil bulan 1..(N-1) sebagai training → predict bulan N dengan run_analysis()
      - Bandingkan prediksi vs actual price movement di bulan N
    
    Returns dict dengan semua metrik + raw data untuk grafik.
    """
    sb = get_supabase()
    
    # Ambil semua produk (max 500 untuk performa)
    products = (
        sb.table("products")
        .select("id, name, category, weight_gram")
        .limit(500)
        .execute()
        .data or []
    )
    
    predictions: list[Prediction] = []
    actuals: list[ActualOutcome] = []
    raw_results = []  # untuk analisis detail + grafik
    
    for product in products:
        history = (
            sb.table("price_history")
            .select("price, weight_gram, recorded_at")
            .eq("product_id", product["id"])
            .order("recorded_at", desc=False)
            .execute()
            .data or []
        )
        
        if len(history) < 4:
            continue
        
        # Sliding window: training = semua kecuali bulan terakhir
        training = history[:-1]
        last_month_rows = [r for r in history if r["recorded_at"][:7] == history[-1]["recorded_at"][:7]]
        
        # Prepare monthly buckets for scoring engine
        monthly_buckets = prepare_monthly_buckets(training)
        
        # Run FULL scoring engine
        current_price = float(last_month_rows[0]["price"])
        current_weight = float(product.get("weight_gram") or last_month_rows[0].get("weight_gram", 0) or 100)
        
        analysis = run_analysis(
            scanned_price=current_price,
            current_weight=current_weight,
            urgency=2,  # "biasa saja" sebagai default backtest
            monthly_buckets=monthly_buckets,
            user_tier="FREE",  # bisa divariasikan nanti
        )
        
        decision = analysis["decision"]  # "WorthIt" / "Waspada" / "Mahal"
        score = analysis["score"]
        
        # Map scoring decision ke backtesting decision
        decision_map = {
            "WorthIt": "BUY",
            "Waspada": "SUBSTITUTE",
            "Mahal": "DONT_BUY",
        }
        bt_decision = decision_map.get(decision, "SUBSTITUTE")
        
        # Actual: harga 1 bulan setelahnya (jika ada)
        next_month_rows = [
            r for r in history 
            if r["recorded_at"][:7] > history[-2]["recorded_at"][:7]
        ] if len(history) >= 2 else []
        
        if not next_month_rows:
            continue
        
        future_price = float(next_month_rows[0]["price"])
        
        predictions.append(Prediction(
            decision=bt_decision,
            current_price=current_price,
            substitute_price=current_price * 0.9 if bt_decision == "SUBSTITUTE" else None,
        ))
        
        actuals.append(ActualOutcome(
            future_price=future_price,
            current_price=current_price,
            substitute_was_cheaper=bt_decision == "SUBSTITUTE" and (future_price < current_price),
        ))
        
        raw_results.append({
            "product_name": product["name"],
            "category": product.get("category", "unknown"),
            "current_price": current_price,
            "future_price": future_price,
            "decision": decision,
            "score": score,
            "normal_price": analysis["normal_price"],
            "support": analysis["support"],
            "resistance": analysis["resistance"],
            "price_delta_percent": analysis["price_delta_percent"],
            "components": analysis["components"],
            "was_correct": _is_correct(bt_decision, current_price, future_price),
        })
    
    # Hitung metrik
    hit_rate = calculate_hit_rate(predictions, actuals)
    cost_savings = calculate_cost_savings(predictions)
    
    # Breakdown per decision type
    decision_stats = _calculate_decision_breakdown(raw_results)
    
    return {
        "total_predictions": len(predictions),
        "total_products_tested": len(raw_results),
        "hit_rate": hit_rate,
        "cost_savings_percent": cost_savings,
        "decision_breakdown": decision_stats,
        "raw_results": raw_results,
    }


def _is_correct(decision: str, current_price: float, future_price: float) -> bool:
    """Check apakah prediksi benar berdasarkan price movement."""
    if decision == "BUY":
        return future_price >= current_price
    elif decision == "DONT_BUY":
        return future_price < current_price
    else:
        return future_price <= current_price  # SUBSTITUTE: harga turun atau flat


def _calculate_decision_breakdown(results: list[dict]) -> dict:
    """Hitung akurasi per tipe keputusan."""
    breakdown = {"BUY": {"total": 0, "correct": 0},
                 "DONT_BUY": {"total": 0, "correct": 0},
                 "SUBSTITUTE": {"total": 0, "correct": 0}}
    
    for r in results:
        dec = {"WorthIt": "BUY", "Mahal": "DONT_BUY", "Waspada": "SUBSTITUTE"}.get(r["decision"], "SUBSTITUTE")
        breakdown[dec]["total"] += 1
        if r["was_correct"]:
            breakdown[dec]["correct"] += 1
    
    for dec in breakdown:
        total = breakdown[dec]["total"]
        breakdown[dec]["accuracy"] = round(breakdown[dec]["correct"] / total * 100, 2) if total > 0 else 0
    
    return breakdown


if __name__ == "__main__":
    results = run_full_backtest()
    
    print("=" * 60)
    print("  WORTHIT BACKTEST — FULL SCORING ENGINE")
    print("=" * 60)
    print(f"Total prediksi        : {results['total_predictions']}")
    print(f"Hit Rate (overall)    : {results['hit_rate']:.2f}%")
    print(f"Cost Savings Impact   : {results['cost_savings_percent']:.2f}%")
    print()
    
    print("--- Accuracy per Decision Type ---")
    for dec, stats in results["decision_breakdown"].items():
        print(f"  {dec:12s}: {stats['accuracy']:.2f}% ({stats['correct']}/{stats['total']})")
    
    print()
    print("--- Sample Results (first 10) ---")
    for r in results["raw_results"][:10]:
        status = "✓" if r["was_correct"] else "✗"
        print(f"  {status} {r['product_name'][:30]:30s} | {r['decision']:8s} | "
              f"Score: {r['score']:3d} | Δ: {r['price_delta_percent']:+.1f}%")
    
    # Save full results as JSON for chart generation
    os.makedirs("data", exist_ok=True)
    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    output_path = f"data/backtest_{timestamp}.json"
    
    # Strip raw_results from print output, save separately
    with open(output_path, "w") as f:
        json.dump(results, f, indent=2, default=str)
    print(f"\n✓ Full results saved to: {output_path}")
```

### Verification
```bash
cd backend && python scripts/backtest_v2.py
```
Expected: output menampilkan hit rate, cost savings, breakdown per decision, dan sample 10 hasil pertama.

---

## Task 2: Generate Charts untuk Proposal GEMASTIK

### Objective
Buat script `backend/scripts/generate_backtest_charts.py` yang membaca JSON hasil backtest dan menghasilkan grafik siap pakai.

### Files
- Create: `backend/scripts/generate_backtest_charts.py`
- Output: `data/charts/` folder dengan file PNG

### Specification

```python
"""
generate_backtest_charts.py — Generate charts from backtest JSON results.

Menghasilkan 4 grafik untuk proposal GEMASTIK:
1. Overall hit rate + cost savings (bar chart)
2. Accuracy per decision type (bar chart)
3. Score distribution vs correctness (scatter plot)
4. Price delta vs correctness (scatter plot)
"""

import json, os, sys
from pathlib import Path

# Pastikan matplotlib terinstall: pip install matplotlib numpy
import matplotlib
matplotlib.use('Agg')  # non-interactive backend
import matplotlib.pyplot as plt
import numpy as np


def load_backtest_results(json_path: str) -> dict:
    with open(json_path, "r") as f:
        return json.load(f)


def chart_1_overview(results: dict, output_dir: str):
    """Bar chart: Overall Hit Rate + Cost Savings"""
    fig, ax = plt.subplots(figsize=(8, 5))
    
    metrics = ['Hit Rate (%)', 'Cost Savings (%)']
    values = [results['hit_rate'], results['cost_savings_percent']]
    colors = ['#2ecc71', '#3498db']
    
    bars = ax.bar(metrics, values, color=colors, width=0.4)
    ax.set_ylim(0, 100)
    ax.set_ylabel('Percentage (%)')
    ax.set_title('WorthIt Backtest — Overall Performance Metrics\n'
                 f'(n={results["total_predictions"]} predictions)')
    
    # Add value labels on bars
    for bar, val in zip(bars, values):
        ax.text(bar.get_x() + bar.get_width()/2, bar.get_height() + 1,
                f'{val:.1f}%', ha='center', va='bottom', fontweight='bold')
    
    ax.grid(axis='y', alpha=0.3)
    plt.tight_layout()
    plt.savefig(os.path.join(output_dir, '01_overview.png'), dpi=150)
    plt.close()


def chart_2_decision_accuracy(results: dict, output_dir: str):
    """Bar chart: Accuracy per decision type"""
    breakdown = results['decision_breakdown']
    decisions = list(breakdown.keys())
    accuracies = [breakdown[d]['accuracy'] for d in decisions]
    totals = [breakdown[d]['total'] for d in decisions]
    
    fig, ax = plt.subplots(figsize=(8, 5))
    colors = ['#2ecc71', '#e74c3c', '#f39c12']
    
    bars = ax.bar(decisions, accuracies, color=colors[:len(decisions)], width=0.5)
    ax.set_ylim(0, 100)
    ax.set_ylabel('Accuracy (%)')
    ax.set_title('Accuracy per Decision Type')
    
    for bar, acc, total in zip(bars, accuracies, totals):
        ax.text(bar.get_x() + bar.get_width()/2, bar.get_height() + 1,
                f'{acc:.1f}%\n(n={total})', ha='center', va='bottom', fontsize=10)
    
    ax.grid(axis='y', alpha=0.3)
    plt.tight_layout()
    plt.savefig(os.path.join(output_dir, '02_decision_accuracy.png'), dpi=150)
    plt.close()


def chart_3_score_vs_correctness(results: dict, output_dir: str):
    """Scatter: Score vs apakah prediksi benar"""
    raw = results['raw_results']
    scores = [r['score'] for r in raw]
    correct = [1 if r['was_correct'] else 0 for r in raw]
    
    fig, ax = plt.subplots(figsize=(10, 6))
    
    # Split into correct/incorrect
    correct_scores = [s for s, c in zip(scores, correct) if c]
    incorrect_scores = [s for s, c in zip(scores, correct) if not c]
    
    ax.scatter(range(len(correct_scores)), correct_scores, 
               c='#2ecc71', alpha=0.6, s=30, label='Correct')
    ax.scatter(range(len(incorrect_scores)), incorrect_scores,
               c='#e74c3c', alpha=0.6, s=30, label='Incorrect')
    
    # Threshold lines
    ax.axhline(y=75, color='green', linestyle='--', alpha=0.5, label='WorthIt threshold (75)')
    ax.axhline(y=50, color='orange', linestyle='--', alpha=0.5, label='Waspada threshold (50)')
    
    ax.set_ylabel('Confidence Score')
    ax.set_title('Score Distribution vs Prediction Correctness')
    ax.legend()
    ax.grid(alpha=0.2)
    plt.tight_layout()
    plt.savefig(os.path.join(output_dir, '03_score_vs_correctness.png'), dpi=150)
    plt.close()


def chart_4_price_delta_vs_correctness(results: dict, output_dir: str):
    """Scatter: Price delta % vs correctness"""
    raw = results['raw_results']
    
    deltas = [r.get('price_delta_percent', 0) for r in raw]
    correct = [1 if r['was_correct'] else 0 for r in raw]
    
    fig, ax = plt.subplots(figsize=(10, 6))
    
    correct_deltas = [d for d, c in zip(deltas, correct) if c]
    incorrect_deltas = [d for d, c in zip(deltas, correct) if not c]
    
    ax.scatter(range(len(correct_deltas)), correct_deltas,
               c='#2ecc71', alpha=0.6, s=30, label='Correct')
    ax.scatter(range(len(incorrect_deltas)), incorrect_deltas,
               c='#e74c3c', alpha=0.6, s=30, label='Incorrect')
    
    ax.axhline(y=0, color='black', linestyle='-', alpha=0.3)
    ax.set_ylabel('Price Delta from WMA (%)')
    ax.set_title('Price Deviation vs Prediction Correctness')
    ax.legend()
    ax.grid(alpha=0.2)
    plt.tight_layout()
    plt.savefig(os.path.join(output_dir, '04_price_delta_vs_correctness.png'), dpi=150)
    plt.close()


def generate_all_charts(json_path: str):
    """Generate all 4 charts from backtest JSON results."""
    results = load_backtest_results(json_path)
    
    output_dir = os.path.join(os.path.dirname(json_path), "charts")
    os.makedirs(output_dir, exist_ok=True)
    
    chart_1_overview(results, output_dir)
    chart_2_decision_accuracy(results, output_dir)
    chart_3_score_vs_correctness(results, output_dir)
    chart_4_price_delta_vs_correctness(results, output_dir)
    
    print(f"✓ 4 charts saved to: {output_dir}/")
    
    # Generate summary report markdown
    report_path = os.path.join(output_dir, "summary_report.md")
    _generate_summary_md(results, report_path)


def _generate_summary_md(results: dict, path: str):
    """Generate summary markdown for easy copy-paste into proposal."""
    breakdown = results['decision_breakdown']
    
    md = f"""# WorthIt Backtest Summary Report

**Generated:** {datetime.now().strftime('%Y-%m-%d %H:%M')}
**Total Predictions:** {results['total_predictions']}

## Key Metrics

| Metric | Value |
|--------|-------|
| Overall Hit Rate | **{results['hit_rate']:.2f}%** |
| Cost Savings Impact | **{results['cost_savings_percent']:.2f}%** |

## Accuracy per Decision Type

| Decision | Accuracy | Count |
|----------|----------|-------|
"""
    for dec in ["BUY", "SUBSTITUTE", "DONT_BUY"]:
        stats = breakdown.get(dec, {"accuracy": 0, "total": 0})
        md += f"| {dec} | {stats['accuracy']:.2f}% | {stats['total']} |\n"
    
    md += """
## Charts
1. ![Overview](01_overview.png)
2. ![Decision Accuracy](02_decision_accuracy.png)
3. ![Score vs Correctness](03_score_vs_correctness.png)
4. ![Price Delta vs Correctness](04_price_delta_vs_correctness.png)

## Interpretation

"""
    if results['hit_rate'] >= 70:
        md += "- ✅ System menunjukkan performa di atas threshold 70%\n"
    elif results['hit_rate'] >= 50:
        md += "- ⚠️ System menunjukkan performa moderat, ada ruang improvement\n"
    else:
        md += "- ❌ System perlu perbaikan signifikan\n"
    
    md += f"- Penghematan biaya {results['cost_savings_percent']:.1f}% menunjukkan nilai ekonomi sistem\n"
    md += "- Saran: integrate ML model untuk meningkatkan akurasi pada edge cases\n"
    
    with open(path, "w") as f:
        f.write(md)
    print(f"✓ Summary report saved to: {path}")


if __name__ == "__main__":
    import glob
    from datetime import datetime
    
    # Auto-find latest backtest JSON
    json_files = sorted(glob.glob("data/backtest_*.json"), reverse=True)
    if not json_files:
        print("❌ No backtest JSON found in data/. Run backtest_v2.py first.")
        sys.exit(1)
    
    generate_all_charts(json_files[0])
```

### Verification
```bash
pip install matplotlib numpy
cd backend && python scripts/generate_backtest_charts.py
```
Expected: 4 file PNG + 1 summary_report.md di `data/charts/`.

---

## Task 3: Install Dependency & Run Full Pipeline

```bash
# Di WSL
cd "/mnt/d/Fallah's File/Code/Personal Project/WorthIt/backend"
source .venv/bin/activate
pip install matplotlib numpy

# Run backtest
python scripts/backtest_v2.py

# Generate charts
python scripts/generate_backtest_charts.py
```

---

## What You Get (for Proposal)

| Output | File | Digunakan di |
|--------|------|-------------|
| Raw backtest JSON | `data/backtest_*.json` | Bab 4 — Hasil Pengujian |
| Hit Rate + Cost Savings chart | `charts/01_overview.png` | Bab 4 / Bab 5 |
| Accuracy per decision chart | `charts/02_decision_accuracy.png` | Bab 4 |
| Score vs correctness scatter | `charts/03_score_vs_correctness.png` | Bab 4 |
| Price delta analysis | `charts/04_price_delta_vs_correctness.png` | Bab 4 |
| Summary report | `charts/summary_report.md` | Copy-paste ke Bab 5 |

---

## Notes

- Backtest memakai urgency=2 (default) — bisa divariasikan untuk analisis sensitivitas
- Kalau data historis < 4 bulan per produk, produk di-skip
- Backtest saat ini single-threaded — untuk 500 produk estimasi ~30-60 detik
- Hasil backtest bisa langsung jadi **baseline** untuk dibandingkan dengan ML model nanti
