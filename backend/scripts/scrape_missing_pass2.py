#!/usr/bin/env python3
"""
scripts/scrape_missing_pass2.py — Pass 2 Scraper for Missing August 1st Prices
Targeting only the missing products that have no entry in price_history for recorded_at=2026-08-01.
"""
from __future__ import annotations

import argparse
import asyncio
import logging
import random
import sys
from datetime import datetime
from pathlib import Path

# Add backend directory to sys.path
SCRIPT_DIR = Path(__file__).resolve().parent
BACKEND_DIR = SCRIPT_DIR.parent
PROJECT_ROOT = BACKEND_DIR.parent
sys.path.append(str(BACKEND_DIR))

from dotenv import load_dotenv
load_dotenv(dotenv_path=PROJECT_ROOT / ".env")

from playwright.async_api import async_playwright
from scripts.scrape_alfagift_automated import (
    get_supabase,
    InputProduct,
    AlfagiftScraper,
    insert_weekly_price_to_supabase,
    result_dedupe_key,
    RateLimitedError,
    BlockedError,
    CaptchaDetectedError,
)

logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(name)s: %(message)s")
LOGGER = logging.getLogger("pass2_scraper")


async def run_pass2(args: argparse.Namespace) -> int:
    supabase = get_supabase()
    
    LOGGER.info("Fetching products & existing August 1st price_history...")
    products_resp = supabase.table("products").select("id, name, brand, category, base_weight_gram, unit_label").execute()
    august_resp = supabase.table("price_history").select("product_id").eq("recorded_at", "2026-08-01").execute()
    august_pids = {r["product_id"] for r in august_resp.data}

    missing_products = []
    for row in products_resp.data:
        if row["id"] not in august_pids:
            unit_val = row.get("unit_label")
            if not unit_val:
                weight = row.get("base_weight_gram", 0)
                unit_val = f"{weight} g" if weight else ""
            missing_products.append(InputProduct(
                id_produk=row["id"],
                category=row.get("category") or "",
                name=row.get("name") or "",
                brand=row.get("brand") or "",
                unit=unit_val,
            ))

    LOGGER.info("Found %d products missing August 1st prices.", len(missing_products))
    if not missing_products:
        LOGGER.info("All 988 products already have August 1st prices!")
        return 0

    if args.limit:
        missing_products = missing_products[:args.limit]
        LOGGER.info("Applying limit: processing first %d missing products.", len(missing_products))

    used_result_keys: set[str] = set()
    unlisted_products: list[InputProduct] = []
    found_count = 0

    async with async_playwright() as p:
        browser = await p.chromium.launch(headless=args.headless)
        scraper = AlfagiftScraper(
            browser=browser,
            headless=args.headless,
            timeout_ms=args.timeout_ms,
            min_score=args.min_score,
            rotate_context_every=args.rotate_context_every,
        )
        await scraper.start()

        try:
            for idx, product in enumerate(missing_products, start=1):
                LOGGER.info("[%d/%d] search missing: %s", idx, len(missing_products), product.input_name)
                try:
                    result = await scraper.search(product, used_result_keys=used_result_keys)
                except (RateLimitedError, BlockedError, CaptchaDetectedError) as exc:
                    LOGGER.warning("Rate limit / bot protection triggered: %s. Sleeping...", exc)
                    await asyncio.sleep(random.uniform(args.rate_limit_sleep_min, args.rate_limit_sleep_max))
                    await scraper.rotate_context("rate-limited")
                    result = await scraper.search(product, used_result_keys=used_result_keys)

                if not result:
                    LOGGER.info("[alfagift] not found: %s", product.input_name)
                    unlisted_products.append(product)
                else:
                    found_count += 1
                    LOGGER.info(
                        "[alfagift] %s: %s -> %s (price=%.1f)",
                        result.match_type,
                        product.input_name,
                        result.found_name,
                        result.price,
                    )
                    insert_weekly_price_to_supabase(supabase, product.id_produk, result.price)
                    result_key = result_dedupe_key(result.sku_id, result.found_name, result.unit)
                    if result_key:
                        used_result_keys.add(result_key)
                
                await asyncio.sleep(random.uniform(args.delay_min, args.delay_max))
        finally:
            await scraper.close()
            await browser.close()

    LOGGER.info("Pass 2 complete! Found: %d | Unlisted/Not Found: %d", found_count, len(unlisted_products))
    if unlisted_products:
        print("\n" + "=" * 70)
        print(f"⚠️ UNLISTED / NOT FOUND PRODUCTS ({len(unlisted_products)} item):")
        print("=" * 70)
        for item in unlisted_products:
            print(f"- ID: {item.id_produk} | Name: {item.name} | Brand: {item.brand} | Unit: {item.unit}")
        print("=" * 70)
    return 0


def main() -> int:
    parser = argparse.ArgumentParser(description="Pass 2 Scraper for Missing August 1st Prices.")
    parser.add_argument("--headless", dest="headless", action="store_true", default=True)
    parser.add_argument("--no-headless", dest="headless", action="store_false")
    parser.add_argument("--limit", type=int, default=None)
    parser.add_argument("--timeout-ms", type=int, default=30000)
    parser.add_argument("--min-score", type=int, default=80)
    parser.add_argument("--delay-min", type=float, default=2.0)
    parser.add_argument("--delay-max", type=float, default=5.0)
    parser.add_argument("--rate-limit-sleep-min", type=float, default=30.0)
    parser.add_argument("--rate-limit-sleep-max", type=float, default=60.0)
    parser.add_argument("--rotate-context-every", type=int, default=20)
    args = parser.parse_args()
    return asyncio.run(run_pass2(args))


if __name__ == "__main__":
    sys.exit(main())
