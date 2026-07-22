"""
scripts/evaluate_substitutions.py — WorthIt Substitution Benchmark & Evaluator

Membandingkan performa rekomendasi substitusi antara:
1. Legacy Rule-Based Model (Kategori & Price-per-gram)
2. ML Hybrid Model (SentenceTransformers + Supabase pgvector + Multi-Factor Rescoring)

Metrik Evaluasi:
- Coverage Rate (% produk yang mendapatkan min. 1 rekomendasi)
- Cross-Category Contamination Rate (target: 0%)
- Average Size Mismatch Ratio
- Average Savings Realized (%)
- Average Latency (ms)
"""

import sys
import time
import json
import logging
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from utils.supabase_client import get_supabase, _safe_execute, _get_substitutes_legacy, get_substitutes, latest_prices_by_product

logging.basicConfig(level=logging.INFO, format="%(asctime)s [%(levelname)s] %(message)s")


def evaluate_benchmark(sample_size: int = 30):
    sb = get_supabase()

    logging.info("Membaca %d sampel produk untuk pengujian benchmark...", sample_size)
    res = _safe_execute(
        sb.table("products")
        .select("id, name, brand, category, base_weight_gram, unit_label")
        .limit(sample_size)
    )
    products = res.data or []

    if not products:
        logging.error("Tidak ada produk ditemukan di DB untuk dievaluasi.")
        return

    product_ids = [p["id"] for p in products]
    latest_prices = latest_prices_by_product(product_ids)

    legacy_results = []
    ml_results = []

    legacy_times = []
    ml_times = []

    cross_category_legacy = 0
    cross_category_ml = 0

    size_ratios_legacy = []
    size_ratios_ml = []

    savings_legacy = []
    savings_ml = []

    for p in products:
        pid = p["id"]
        cat = p.get("category") or ""
        weight = float(p.get("base_weight_gram") or 0.0)
        price = latest_prices.get(pid, 0.0)

        if price <= 0:
            continue

        # Evaluate Legacy
        t0 = time.time()
        legacy_subs = _get_substitutes_legacy(pid, cat, price)
        t_legacy = (time.time() - t0) * 1000.0
        legacy_times.append(t_legacy)
        legacy_results.append((p, legacy_subs))

        for sub in legacy_subs:
            if sub.get("category") and sub["category"] != cat:
                cross_category_legacy += 1
            if weight > 0 and sub.get("weight", 0) > 0:
                w_sub = float(sub["weight"])
                ratio = min(weight, w_sub) / max(weight, w_sub)
                size_ratios_legacy.append(ratio)
            if sub.get("savings_percent"):
                savings_legacy.append(sub["savings_percent"])

        # Evaluate ML Hybrid
        t0 = time.time()
        ml_subs = get_substitutes(pid, cat, price)
        t_ml = (time.time() - t0) * 1000.0
        ml_times.append(t_ml)
        ml_results.append((p, ml_subs))

        for sub in ml_subs:
            if sub.get("category") and sub["category"] != cat:
                cross_category_ml += 1
            if weight > 0 and sub.get("weight", 0) > 0:
                w_sub = float(sub["weight"])
                ratio = min(weight, w_sub) / max(weight, w_sub)
                size_ratios_ml.append(ratio)
            if sub.get("savings_percent"):
                savings_ml.append(sub["savings_percent"])

    # Compute aggregates
    avg_t_legacy = sum(legacy_times) / len(legacy_times) if legacy_times else 0.0
    avg_t_ml = sum(ml_times) / len(ml_times) if ml_times else 0.0

    coverage_legacy = sum(1 for _, subs in legacy_results if len(subs) > 0) / len(legacy_results) * 100 if legacy_results else 0.0
    coverage_ml = sum(1 for _, subs in ml_results if len(subs) > 0) / len(ml_results) * 100 if ml_results else 0.0

    avg_size_ratio_legacy = sum(size_ratios_legacy) / len(size_ratios_legacy) if size_ratios_legacy else 0.0
    avg_size_ratio_ml = sum(size_ratios_ml) / len(size_ratios_ml) if size_ratios_ml else 0.0

    avg_savings_legacy = sum(savings_legacy) / len(savings_legacy) if savings_legacy else 0.0
    avg_savings_ml = sum(savings_ml) / len(savings_ml) if savings_ml else 0.0

    report = {
        "sample_count": len(legacy_results),
        "metrics": {
            "latency_ms": {
                "legacy": round(avg_t_legacy, 2),
                "ml_hybrid": round(avg_t_ml, 2),
            },
            "coverage_percent": {
                "legacy": round(coverage_legacy, 1),
                "ml_hybrid": round(coverage_ml, 1),
            },
            "cross_category_error_count": {
                "legacy": cross_category_legacy,
                "ml_hybrid": cross_category_ml,
            },
            "size_similarity_index": {
                "legacy": round(avg_size_ratio_legacy, 4),
                "ml_hybrid": round(avg_size_ratio_ml, 4),
            },
            "avg_savings_realized_percent": {
                "legacy": round(avg_savings_legacy, 2),
                "ml_hybrid": round(avg_savings_ml, 2),
            },
        },
    }

    print("\n" + "=" * 60)
    print("[REPORT] LAPORAN BENCHMARK EVALUASI SUBSTITUSI (MODUL D)")
    print("=" * 60)
    print(f"Sampel Teruji: {report['sample_count']} produk")
    print(f"Coverage Rate      : Legacy {report['metrics']['coverage_percent']['legacy']}%  vs  ML {report['metrics']['coverage_percent']['ml_hybrid']}%")
    print(f"Cross-Cat Errors   : Legacy {report['metrics']['cross_category_error_count']['legacy']}  vs  ML {report['metrics']['cross_category_error_count']['ml_hybrid']}")
    print(f"Size Match Index   : Legacy {report['metrics']['size_similarity_index']['legacy']}  vs  ML {report['metrics']['size_similarity_index']['ml_hybrid']} (1.0 = sempurna)")
    print(f"Rata-Rata Hemat    : Legacy {report['metrics']['avg_savings_realized_percent']['legacy']}%  vs  ML {report['metrics']['avg_savings_realized_percent']['ml_hybrid']}%")
    print(f"Rata-Rata Latensi  : Legacy {report['metrics']['latency_ms']['legacy']}ms  vs  ML {report['metrics']['latency_ms']['ml_hybrid']}ms")
    print("=" * 60 + "\n")

    report_path = Path(__file__).resolve().parent.parent / "evaluate_substitutions_report.json"
    with open(report_path, "w", encoding="utf-8") as f:
        json.dump(report, f, indent=2)
    logging.info("Laporan evaluasi disimpan ke: %s", report_path)



if __name__ == "__main__":
    evaluate_benchmark(sample_size=30)
