"""
core/substitution_engine.py — WorthIt ML Substitution Rescoring Engine

Menangani kalkulasi multi-faktor untuk pemeringkatan kandidat substitusi:
  Score = α * Semantic_Similarity + β * Size_Match_Score + γ * Price_Savings_Score
  di mana α=0.50, β=0.30, γ=0.20.
"""

from typing import Any


def compute_size_similarity(scanned_weight: float, candidate_weight: float) -> float:
    """
    Hitung kesamaan ukuran kemasan antara 0.0 dan 1.0.
    Jika kedua berat diketahui (> 0): min(w1, w2) / max(w1, w2).
    Jika salah satu tidak diketahui: kembalikan 0.75 (netral).
    """
    if scanned_weight <= 0 or candidate_weight <= 0:
        return 0.75

    w1, w2 = float(scanned_weight), float(candidate_weight)
    return min(w1, w2) / max(w1, w2)


def compute_savings_score(scanned_price: float, candidate_price: float) -> float:
    """
    Hitung skor penghematan harga antara 0.0 dan 1.0.
    - Jika kandidat lebih mahal/sama: 0.0
    - Penghematan 20% atau lebih: 1.0 (maksimal skor)
    - Penghematan antara 0% dan 20%: skala linier 0.0 -> 1.0
    """
    if scanned_price <= 0 or candidate_price >= scanned_price:
        return 0.0

    savings_pct = (scanned_price - candidate_price) / scanned_price
    # Cap pada 20% penghematan (= 1.0 skor)
    return min(1.0, max(0.0, savings_pct / 0.20))


def rank_substitute_candidates(
    scanned_price: float,
    scanned_weight: float,
    candidates: list[dict[str, Any]],
    alpha: float = 0.50,
    beta: float = 0.30,
    gamma: float = 0.20,
) -> list[dict[str, Any]]:
    """
    Melakukan rescoring pada kandidat hasil pgvector similarity search.

    Params:
      scanned_price: harga produk yang sedang di-scan
      scanned_weight: berat/ukuran produk yang di-scan (gram/ml)
      candidates: list dict dari pgvector RPC (berisi similarity, price, base_weight_gram, dll)
      alpha: bobot kesamaan semantik nama/deskripsi (default 0.50)
      beta: bobot kesamaan ukuran kemasan (default 0.30)
      gamma: bobot besarnya penghematan harga (default 0.20)

    Return:
      List of ranked substitute candidates sorted by final_score descending.
    """
    rescored = []

    for item in candidates:
        price = float(item.get("price") or 0.0)
        # Hanya pertimbangkan produk yang harganya lebih murah dari yang di-scan
        if price <= 0 or price >= scanned_price:
            continue

        weight = float(item.get("base_weight_gram") or item.get("weight") or 0.0)
        similarity = float(item.get("similarity") or 0.0)

        size_sim = compute_size_similarity(scanned_weight, weight)
        savings_sc = compute_savings_score(scanned_price, price)

        final_score = (alpha * similarity) + (beta * size_sim) + (gamma * savings_sc)

        price_per_unit = round(price / weight, 4) if weight > 0 else 0.0
        savings_pct = round((scanned_price - price) / scanned_price * 100, 1)

        rescored.append({
            "product_id":          item["id"] if "id" in item else item.get("product_id"),
            "name":                item.get("name", ""),
            "brand":               item.get("brand"),
            "category":            item.get("category", ""),
            "price":               price,
            "weight":              weight,
            "price_per_unit":      price_per_unit,
            "image_url":           item.get("image_url"),
            "savings_percent":     savings_pct,
            "semantic_similarity": round(similarity, 4),
            "size_similarity":     round(size_sim, 4),
            "savings_score":       round(savings_sc, 4),
            "final_score":         round(final_score, 4),
            "is_ml_recommendation": True,
        })

    # Urutkan dari final_score tertinggi
    rescored.sort(key=lambda x: x["final_score"], reverse=True)
    return rescored
