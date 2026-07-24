import sys
import os
import ssl
import urllib.request
import json
import argparse
from datetime import datetime
from pathlib import Path
from uuid import uuid4
from collections import defaultdict

# Add project root to path
SCRIPT_DIR = Path(__file__).resolve().parent
PROJECT_ROOT = SCRIPT_DIR.parent
sys.path.append(str(PROJECT_ROOT))

from dotenv import load_dotenv
load_dotenv(dotenv_path=PROJECT_ROOT / ".env")

SUPABASE_URL = os.environ.get("SUPABASE_URL")
SUPABASE_KEY = os.environ.get("SUPABASE_SERVICE_ROLE_KEY") or os.environ.get("SUPABASE_KEY")

if not SUPABASE_URL or not SUPABASE_KEY:
    print("Error: SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY/SUPABASE_KEY must be set in .env")
    sys.exit(1)

headers = {
    "apikey": SUPABASE_KEY,
    "Authorization": f"Bearer {SUPABASE_KEY}",
    "Content-Type": "application/json",
    "Accept": "application/json"
}
ctx = ssl.create_default_context()

def get_all(path):
    all_rows = []
    offset = 0
    batch = 1000
    while True:
        url = f"{SUPABASE_URL}/rest/v1/{path}"
        separator = "&" if "?" in path else "?"
        full_url = f"{url}{separator}limit={batch}&offset={offset}"
        
        req = urllib.request.Request(full_url, headers=headers)
        with urllib.request.urlopen(req, timeout=60, context=ctx) as r:
            rows = json.loads(r.read())
        all_rows.extend(rows)
        if len(rows) < batch:
            break
        offset += batch
    return all_rows

def insert_batch(table, rows):
    url = f"{SUPABASE_URL}/rest/v1/{table}"
    req = urllib.request.Request(
        url,
        data=json.dumps(rows).encode("utf-8"),
        headers={**headers, "Prefer": "return=minimal"},
        method="POST"
    )
    with urllib.request.urlopen(req, timeout=60, context=ctx) as r:
        return r.status

def main():
    parser = argparse.ArgumentParser(description="Promote July 2026 weekly prices to monthly price_history.")
    parser.add_argument("--dry-run", action="store_true", help="Preview modifications without writing to Supabase.")
    args = parser.parse_args()

    print("Fetching products...")
    products = {p["id"]: p for p in get_all("products?select=id,name,base_weight_gram,unit_label")}
    print(f"Loaded {len(products)} products.")

    print("Fetching existing July 2026 price history...")
    # July is 2026-07-01
    existing_july_history = {
        h["product_id"] for h in get_all("price_history?select=product_id&recorded_at=eq.2026-07-01")
    }
    print(f"Found {len(existing_july_history)} products already having July 2026 history.")

    print("Fetching weekly prices for July 2026...")
    weekly_july = get_all("weekly_prices?select=product_id,scraped_at,price&scraped_at=gte.2026-07-01T00:00:00")
    print(f"Loaded {len(weekly_july)} weekly entries in July.")

    # Group by product_id, find latest scrape
    latest_weekly = {}
    for entry in weekly_july:
        pid = entry["product_id"]
        # Parse timestamp to compare
        scraped_at = entry["scraped_at"]
        price = entry["price"]
        
        if pid not in latest_weekly or scraped_at > latest_weekly[pid]["scraped_at"]:
            latest_weekly[pid] = {
                "price": price,
                "scraped_at": scraped_at
            }

    print(f"Unique products with July weekly prices: {len(latest_weekly)}")

    # Filter out those that already have July history
    to_promote = []
    for pid, data in latest_weekly.items():
        if pid in existing_july_history:
            continue
        
        prod = products.get(pid)
        if not prod:
            print(f"Warning: Product {pid} not found in products table.")
            continue
            
        weight = prod.get("base_weight_gram") or 1000
        unit_label = prod.get("unit_label")
        
        to_promote.append({
            "id": str(uuid4()),
            "product_id": pid,
            "price": float(data["price"]),
            "weight_gram": float(weight),
            "unit_label": unit_label,
            "recorded_at": "2026-07-01"
        })

    print(f"Products to promote: {len(to_promote)}")

    if not to_promote:
        print("Nothing to promote.")
        return 0

    if args.dry_run:
        print("--- DRY RUN PREVIEW ---")
        for item in to_promote[:10]:
            prod = products[item["product_id"]]
            print(f"  {prod['name']} -> Price: {item['price']}, Weight: {item['weight_gram']}g, Label: {item['unit_label']}")
        if len(to_promote) > 10:
            print(f"  ... and {len(to_promote) - 10} more.")
        print("No changes written to database.")
        return 0

    print("Inserting into price_history...")
    try:
        status = insert_batch("price_history", to_promote)
        print(f"Successfully promoted {len(to_promote)} products. HTTP Status: {status}")
    except Exception as e:
        print(f"Error during insertion: {e}")
        return 1

    return 0

if __name__ == "__main__":
    sys.exit(main())
