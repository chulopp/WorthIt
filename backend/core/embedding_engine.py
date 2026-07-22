"""
core/embedding_engine.py — WorthIt Vector Embedding Engine

Menggunakan model sentence-transformers/paraphrase-multilingual-MiniLM-L12-v2
untuk menghasilkan vector embedding (384-dimensi) dari metadata produk.
"""

import logging
from typing import Optional

_model = None

MODEL_NAME = "sentence-transformers/paraphrase-multilingual-MiniLM-L12-v2"


def get_model():
    """
    Singleton loader untuk model SentenceTransformer.
    Model di-load sekali ke memory untuk efisiensi inference.
    """
    global _model
    if _model is None:
        try:
            from sentence_transformers import SentenceTransformer
            logging.info("Loading embedding model: %s", MODEL_NAME)
            _model = SentenceTransformer(MODEL_NAME)
        except Exception as exc:
            logging.error("Gagal me-load SentenceTransformer model: %s", exc)
            raise RuntimeError(f"Gagal me-load model embedding: {exc}") from exc
    return _model


def format_product_text(
    name: str,
    brand: Optional[str] = None,
    category: Optional[str] = None,
    unit_label: Optional[str] = None,
) -> str:
    """
    Memformat metadata produk menjadi teks deskriptif untuk embedding.
    Contoh: 'Lifebuoy Sabun Mandi Cair Total 10 450ml Kesehatan dan Kebersihan'
    """
    parts = []
    if brand:
        parts.append(brand.strip())
    parts.append(name.strip())
    if unit_label:
        parts.append(unit_label.strip())
    if category:
        parts.append(category.strip())

    return " ".join(parts)


def generate_embedding(text: str) -> list[float]:
    """
    Menghasilkan list vector float 384-dimensi dari teks produk.
    """
    model = get_model()
    # normalize_embeddings=True agar dot product / cosine calculation konsisten
    embedding = model.encode(text, normalize_embeddings=True)
    return embedding.tolist()


def generate_batch_embeddings(texts: list[str]) -> list[list[float]]:
    """
    Menghasilkan list vector float 384-dimensi untuk batch teks produk.
    """
    if not texts:
        return []
    model = get_model()
    embeddings = model.encode(texts, normalize_embeddings=True, show_progress_bar=False)
    return [emb.tolist() for emb in embeddings]
