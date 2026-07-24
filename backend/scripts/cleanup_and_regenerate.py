import sys
import os
import ssl
import urllib.request
import json
from collections import defaultdict
from pathlib import Path
import subprocess

# Setup path
SCRIPT_DIR = Path(__file__).resolve().parent
PROJECT_ROOT = SCRIPT_DIR.parent
sys.path.append(str(PROJECT_ROOT))

base_url = 'https://nyjojldhvpufxesplrtk.supabase.co'
skey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im55am9qbGRodnB1Znhlc3BscnRrIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc3ODQxMTY1OCwiZXhwIjoyMDkzOTg3NjU4fQ.KlXI_YpE58JL3cZX6MfaYNzr08UvQ9aOXhBeWLDbw5M'
ctx = ssl.create_default_context()
headers = {
    'apikey': skey,
    'Authorization': f'Bearer {skey}',
    'Accept': 'application/json',
    'Content-Type': 'application/json'
}

def get_all(path):
    all_rows = []
    offset = 0
    batch = 1000
    while True:
        req = urllib.request.Request(f'{base_url}/rest/v1/{path}&limit={batch}&offset={offset}', headers=headers)
        with urllib.request.urlopen(req, timeout=30, context=ctx) as r:
            rows = json.loads(r.read())
        all_rows.extend(rows)
        if len(rows) < batch:
            break
        offset += batch
    return all_rows

def delete_rows(filters):
    url = f'{base_url}/rest/v1/price_history?{filters}'
    req = urllib.request.Request(url, headers=headers, method='DELETE')
    with urllib.request.urlopen(req, timeout=30, context=ctx) as r:
        return r.status

def main():
    print("--- STEP 1: Analyzing Database ---")
    products = get_all('products?select=id,name,created_at')
    
    old_pids = set()
    new_pids = set()
    for p in products:
        created_at_str = p.get('created_at', '')
        # Products created on or after July 22, 2026 are NEW products
        if created_at_str and created_at_str >= '2026-07-22':
            new_pids.add(p['id'])
        else:
            old_pids.add(p['id'])
            
    print(f"Total products: {len(products)}")
    print(f"OLD products (created < 22 July 2026): {len(old_pids)}")
    print(f"NEW products (created >= 22 July 2026): {len(new_pids)}")
    
    print("\n--- STEP 2: Cleaning up Price History Gaps & July Entries ---")
    
    # 1. Delete ALL July 2026 entries so they can be promoted cleanly from weekly_prices
    print("Deleting all July 2026 entries in price_history...")
    status_july = delete_rows('recorded_at=eq.2026-07-01')
    print(f"  July deletion status: {status_july}")
    
    # 2. Delete June 2026 entries (wholly synthetic for all products)
    print("Deleting all June 2026 entries in price_history...")
    status_june = delete_rows('recorded_at=eq.2026-06-01')
    print(f"  June deletion status: {status_june}")
    
    # 3. For NEW products, delete all other history rows (they must be regenerated using real July anchor)
    print("Deleting Nov-May synthetic entries for NEW products...")
    # Chunk product IDs to prevent URL length limits
    new_pids_list = list(new_pids)
    chunk_size = 100
    deleted_count = 0
    for i in range(0, len(new_pids_list), chunk_size):
        chunk = new_pids_list[i:i+chunk_size]
        id_filter = f"product_id=in.({','.join(chunk)})"
        status = delete_rows(id_filter)
        deleted_count += len(chunk)
        
    print(f"  Deleted entries for {deleted_count} new products.")
    
    # 4. For OLD products, delete January 2026 entries (they will be regenerated synthetically)
    print("Deleting January 2026 entries for OLD products...")
    old_pids_list = list(old_pids)
    deleted_jan = 0
    for i in range(0, len(old_pids_list), chunk_size):
        chunk = old_pids_list[i:i+chunk_size]
        id_filter = f"recorded_at=eq.2026-01-01&product_id=in.({','.join(chunk)})"
        status = delete_rows(id_filter)
        deleted_jan += len(chunk)
    print(f"  Deleted January entries for {deleted_jan} old products.")

    print("\n--- STEP 3: Promoting 1000 Scraped July Prices ---")
    # Execute promote_weekly_to_monthly.py
    promote_script = SCRIPT_DIR / "promote_weekly_to_monthly.py"
    subprocess.run([sys.executable, str(promote_script)], check=True)
    
    print("\n--- STEP 4: Seeding Synthetic Gaps ---")
    # Execute generate_synthetic_history.py
    generate_script = SCRIPT_DIR / "generate_synthetic_history.py"
    subprocess.run([sys.executable, str(generate_script)], check=True)
    
    print("\n--- STEP 5: Final Database Audit & Row Count Verification ---")
    final_history = get_all('price_history?select=recorded_at,product_id')
    print(f"Final total rows in price_history: {len(final_history)}")
    
    prod_counts = defaultdict(int)
    for h in final_history:
        prod_counts[h['product_id']] += 1
        
    correct_count = 0
    incorrect_pids = []
    for pid, count in prod_counts.items():
        if count == 9:
            correct_count += 1
        else:
            incorrect_pids.append((pid, count))
            
    print(f"Products with exactly 9 months of data: {correct_count} / {len(products)}")
    if incorrect_pids:
        print("Warning! The following products have incorrect row counts:")
        for pid, count in incorrect_pids[:10]:
            print(f"  - Product ID {pid}: {count} rows")
    else:
        print("Success! Every product has exactly 9 months of data.")

if __name__ == "__main__":
    main()
