import sys, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from utils.supabase_client import get_supabase
from collections import defaultdict

sb = get_supabase()

# Count tables
for t in ["weekly_prices", "price_history", "products"]:
    r = sb.table(t).select("count", count="exact").execute()
    print(f"{t}: {r.count} rows")

# Latest scrape dates
wp = sb.table("weekly_prices").select("scraped_at").order("scraped_at", desc=True).limit(3).execute()
print(f"Latest weekly_prices: {[r['scraped_at'][:10] for r in wp.data] if wp.data else 'KOSONG'}")

# Price variance check
ph = sb.table("price_history").select("product_id,price").limit(100).execute()
by_pid = defaultdict(list)
for r in ph.data:
    by_pid[r["product_id"]].append(r["price"])
flat = varied = 0
for pid, prices in by_pid.items():
    if len(set(prices)) > 1: varied += 1
    else: flat += 1
print(f"Variasi harga: {varied} produk bervariasi, {flat} produk flat")
