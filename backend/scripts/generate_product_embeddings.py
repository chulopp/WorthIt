"""
scripts/generate_product_embeddings.py — WorthIt Embedding Population Script

Membaca produk dari Supabase, menghasilkan 384-dim vector embedding menggunakan
SentenceTransformers, dan mengupdate kolom `embedding` di database Supabase.

Penggunaan:
  python scripts/generate_product_embeddings.py                 # Hanyaproduk tanpa embedding
  python scripts/generate_product_embeddings.py --force         # Regenerate semua produk
  python scripts/generate_product_embeddings.py --limit 100     # Maksimal 100 produk
"""

import sys
import time
import argparse
import logging
from pathlib import Path

# Fix import path for running script directly from root or scripts dir
sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from core.embedding_engine import format_product_text, generate_batch_embeddings
from utils.supabase_client import get_supabase, _safe_execute

logging.basicConfig(level=logging.INFO, format="%(asctime)s [%(levelname)s] %(message)s")


def populate_embeddings(force: bool = False, limit: int | None = None, batch_size: int = 50):
    sb = get_supabase()

    logging.info("Memulai proses populasi vector embedding produk...")
    start_time = time.time()

    # Build query
    query = sb.table("products").select("id, name, brand, category, unit_label, embedding")
    if not force:
        query = query.is_("embedding", "null")

    if limit:
        query = query.limit(limit)

    res = _safe_execute(query)
    products = res.data or []

    total_products = len(products)
    if total_products == 0:
        logging.info("Semua produk sudah memiliki vector embedding. Selesai.")
        return

    logging.info("Ditemukan %d produk yang akan di-generate embedding-nya.", total_products)

    processed_count = 0
    success_count = 0

    for i in range(0, total_products, batch_size):
        batch = products[i : i + batch_size]
        texts = [
            format_product_text(
                name=p.get("name") or "",
                brand=p.get("brand"),
                category=p.get("category"),
                unit_label=p.get("unit_label"),
            )
            for p in batch
        ]

        try:
            embeddings = generate_batch_embeddings(texts)
            for product, emb in zip(batch, embeddings):
                try:
                    _safe_execute(
                        sb.table("products")
                        .update({"embedding": emb})
                        .eq("id", product["id"])
                    )
                    success_count += 1
                except Exception as exc:
                    logging.error("Gagal update embedding produk ID %s (%s): %s", product["id"], product.get("name"), exc)

            processed_count += len(batch)
            logging.info("Progres: %d / %d produk selesai (%.1f%%)", processed_count, total_products, (processed_count / total_products) * 100)
        except Exception as exc:
            logging.error("Gagal generate embedding batch %d: %s", i, exc)

    duration = time.time() - start_time
    logging.info("✅ Selesai! %d / %d produk berhasil diperbarui dalam %.2f detik.", success_count, total_products, duration)


def main():
    parser = argparse.ArgumentParser(description="Generate product vector embeddings for WorthIt ML Substitution.")
    parser.add_argument("--force", action="store_true", help="Regenerate embedding untuk SEMUA produk, termasuk yang sudah ada.")
    parser.add_argument("--limit", type=int, default=None, help="Batasi jumlah produk yang diproses.")
    parser.add_argument("--batch-size", type=int, default=50, help="Jumlah produk per batch processing (default 50).")

    args = parser.parse_args()
    populate_embeddings(force=args.force, limit=args.limit, batch_size=args.batch_size)


if __name__ == "__main__":
    main()
