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

def clear_weekly_prices():
    url = f"{SUPABASE_URL}/rest/v1/weekly_prices?id=neq.00000000-0000-0000-0000-000000000000"
    req = urllib.request.Request(
        url,
        headers=headers,
        method="DELETE"
    )
    with urllib.request.urlopen(req, timeout=60, context=ctx) as r:
        return r.status

def main():
    default_recorded_at = datetime.now().strftime("%Y-%m-01")
    parser = argparse.ArgumentParser(description="Promote weekly prices to monthly price_history dynamically.")
    parser.add_argument("--dry-run", action="store_true", help="Preview modifications without writing to Supabase.")
    parser.add_argument("--recorded-at", type=str, default=default_recorded_at, help="Recorded date for price_history (YYYY-MM-DD), defaults to current month 1st.")
    parser.add_argument("--clear-weekly", action="store_true", help="Clear weekly_prices after successfully promoting to price_history.")
    args = parser.parse_args()

    target_date_str = args.recorded_at
    print(f"Target recorded_at date: {target_date_str}")

    print("Fetching products...")
    products = {p["id"]: p for p in get_all("products?select=id,name,base_weight_gram,unit_label")}
    print(f"Loaded {len(products)} products.")

    print(f"Fetching existing price history for {target_date_str}...")
    existing_history = {
        h["product_id"] for h in get_all(f"price_history?select=product_id&recorded_at=eq.{target_date_str}")
    }
    print(f"Found {len(existing_history)} products already having history for {target_date_str}.")

    # Month prefix for filtering weekly entries e.g. '2026-08'
    month_prefix = target_date_str[:7]
    print(f"Fetching weekly prices for {month_prefix}...")
    weekly_entries = get_all(f"weekly_prices?select=product_id,scraped_at,price&scraped_at=gte.{month_prefix}-01T00:00:00")
    if not weekly_entries:
        # Fallback: get all entries if no date filter matched
        weekly_entries = get_all("weekly_prices?select=product_id,scraped_at,price")
    print(f"Loaded {len(weekly_entries)} total weekly entries.")

    # Group by product_id, compute average price or latest price
    # Grouping all prices per product in the month
    product_prices = defaultdict(list)
    for entry in weekly_entries:
        pid = entry["product_id"]
        price = entry["price"]
        if price is not None:
            product_prices[pid].append(float(price))

    print(f"Unique products in weekly_prices: {len(product_prices)}")

    # Filter out those that already have history for this target date
    to_promote = []
    for pid, prices in product_prices.items():
        if pid in existing_history:
            continue
        
        prod = products.get(pid)
        if not prod:
            print(f"Warning: Product {pid} not found in products table.")
            continue
            
        weight = prod.get("base_weight_gram") or 1000
        unit_label = prod.get("unit_label")
        avg_price = sum(prices) / len(prices)
        
        to_promote.append({
            "id": str(uuid4()),
            "product_id": pid,
            "price": round(avg_price, 2),
            "weight_gram": float(weight),
            "unit_label": unit_label,
            "recorded_at": target_date_str
        })

    print(f"Products to promote: {len(to_promote)}")

    if not to_promote:
        print("Nothing to promote.")
        if args.clear_weekly and not args.dry_run:
            print("Clearing weekly_prices table as requested...")
            clear_weekly_prices()
        return 0

    if args.dry_run:
        print("--- DRY RUN PREVIEW ---")
        for item in to_promote[:10]:
            prod = products[item["product_id"]]
            print(f"  {prod['name']} -> Price: {item['price']}, Weight: {item['weight_gram']}g, Label: {item['unit_label']}, Date: {item['recorded_at']}")
        if len(to_promote) > 10:
            print(f"  ... and {len(to_promote) - 10} more.")
        if args.clear_weekly:
            print("[DRY RUN] Would clear weekly_prices table.")
        print("No changes written to database.")
        return 0

    print(f"Inserting {len(to_promote)} records into price_history...")
    try:
        status = insert_batch("price_history", to_promote)
        print(f"Successfully promoted {len(to_promote)} products. HTTP Status: {status}")
        
        if args.clear_weekly:
            print("Clearing weekly_prices table after promotion...")
            del_status = clear_weekly_prices()
            print(f"weekly_prices cleared. HTTP Status: {del_status}")
    except Exception as e:
        print(f"Error during promotion/clearing: {e}")
        return 1

    return 0

if __name__ == "__main__":
    sys.exit(main())
