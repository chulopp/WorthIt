"""
tests/test_substitutions_ml.py — Unit & Integration Tests for Modul D (ML Substitutions)
"""

import sys
from pathlib import Path



sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from core.embedding_engine import format_product_text
from core.substitution_engine import compute_size_similarity, compute_savings_score, rank_substitute_candidates


def test_format_product_text():
    text = format_product_text(
        name="Sabun Mandi Total 10 450ml",
        brand="Lifebuoy",
        category="Kesehatan dan Kebersihan",
        unit_label="Pouch 450ml",
    )
    assert "Lifebuoy" in text
    assert "Sabun Mandi" in text
    assert "Kesehatan dan Kebersihan" in text


def test_compute_size_similarity():
    # Exact weight match
    assert compute_size_similarity(400, 400) == 1.0
    # Half size match
    assert compute_size_similarity(400, 200) == 0.5
    assert compute_size_similarity(200, 400) == 0.5
    # Missing weight fallback
    assert compute_size_similarity(0, 400) == 0.75


def test_compute_savings_score():
    # Same or higher price -> 0.0
    assert compute_savings_score(20000, 20000) == 0.0
    assert compute_savings_score(20000, 25000) == 0.0
    # 10% savings -> 0.5
    assert abs(compute_savings_score(20000, 18000) - 0.5) < 1e-4
    # 20% or more savings -> 1.0
    assert compute_savings_score(20000, 16000) == 1.0
    assert compute_savings_score(20000, 10000) == 1.0


def test_rank_substitute_candidates():
    candidates = [
        {
            "id": "prod-1",
            "name": "Sabun Mandi Dettol 400ml",
            "brand": "Dettol",
            "category": "Kesehatan dan Kebersihan",
            "base_weight_gram": 400,
            "similarity": 0.85,
            "price": 18000,
        },
        {
            "id": "prod-2",
            "name": "Sabun Mandi Biore 400ml",
            "brand": "Biore",
            "category": "Kesehatan dan Kebersihan",
            "base_weight_gram": 400,
            "similarity": 0.92,
            "price": 17000,
        },
        {
            "id": "prod-3",
            "name": "Sabun Mahal 400ml",
            "brand": "Luxury",
            "category": "Kesehatan dan Kebersihan",
            "base_weight_gram": 400,
            "similarity": 0.95,
            "price": 25000,  # Lebih mahal dari 20.000 -> harus difilter out!
        },
    ]

    ranked = rank_substitute_candidates(
        scanned_price=20000,
        scanned_weight=400,
        candidates=candidates,
    )

    # Mahal harus terfilter
    assert len(ranked) == 2
    # Product 2 (Biore) harus menduduki posisi teratas (similarity lebih tinggi & harga lebih murah)
    assert ranked[0]["product_id"] == "prod-2"
    assert ranked[0]["final_score"] > ranked[1]["final_score"]
    assert "savings_percent" in ranked[0]
    assert "semantic_similarity" in ranked[0]


if __name__ == "__main__":
    test_format_product_text()
    test_compute_size_similarity()
    test_compute_savings_score()
    test_rank_substitute_candidates()
    print("[OK] Semua unit test Modul D (ML Substitutions) BERHASIL PASSED!")


