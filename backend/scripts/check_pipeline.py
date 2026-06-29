"""Check Supabase data pipeline status."""
import sys, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from utils.supabase_client import get_supabase

sb = get_supabase()

# 1. Count tables
for table in ["weekly_prices", "price_history", "products"]:
    r = sb.table(table).select("count", count="exact").execute()
    print(f"{table}: {r.count} rows")

# 2. Check if weekly_prices has recent data
wp = sb.table("weekly_prices").select("scraped_at").order("scraped_at", desc=True).limit(3).execute()
print(f"\nLatest weekly_prices dates: {[r['scraped_at'][:10] for r in wp.data]}")

# 3. Check price variance - sample 3 products
ph = sb.table("price_history").select("product_id,price,recorded_at").limit(100).execute()
from collections import defaultdict
by_product = defaultdict(list)
for r in ph.data:
    by_product[r["product_id"]].append(r["price"])

varied = 0
for pid, prices in list(by_product.items())[:10]:
    unique = len(set(prices))
    print(f"  {pid[:30]}: {len(prices)} months, {unique} unique prices -> {'VARIED' if unique > 1 else 'FLAT'}")
    if unique > 1:
        varied += 1

print(f"\nProducts with price variance: {varied}/{min(10, len(by_product))}")
