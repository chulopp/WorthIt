"""Check scrape results from Supabase."""
import sys, os
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from utils.supabase_client import get_supabase
from collections import defaultdict

sb = get_supabase()

# Counts
p = sb.table('products').select('count', count='exact').execute()
wp = sb.table('weekly_prices').select('count', count='exact').execute()
ph = sb.table('price_history').select('count', count='exact').execute()

print(f"products: {p.count}")
print(f"weekly_prices (new): {wp.count}")
print(f"price_history (total): {ph.count}")

# Unique products scraped
wp_data = sb.table('weekly_prices').select('product_id').execute()
unique_ids = set(r['product_id'] for r in (wp_data.data or []))

# All products
all_data = sb.table('products').select('id,name,category').execute()
all_prods = all_data.data or []

found = [r for r in all_prods if r['id'] in unique_ids]
not_found = [r for r in all_prods if r['id'] not in unique_ids]

print(f"\nScraped: {len(found)}/{len(all_prods)}")
print(f"Not found: {len(not_found)}/{len(all_prods)}")

# Analyze not-found by category
cat_counts = defaultdict(int)
for r in not_found:
    cat_counts[r.get('category', 'Unknown')] += 1

print("\nNot-found by category:")
for cat, count in sorted(cat_counts.items(), key=lambda x: -x[1])[:10]:
    print(f"  {cat}: {count}")

# Sample not-found
print("\nSample not-found (first 5):")
for r in not_found[:5]:
    print(f"  {r['name'][:60]} ({r.get('category', '?')})")

# Check if not-found products have price_history data
if not_found:
    sample_ids = [r['id'] for r in not_found[:3]]
    for pid in sample_ids:
        ph_data = sb.table('price_history').select('count', count='exact').eq('product_id', pid).execute()
        print(f"  price_history entries for {pid[:8]}: {ph_data.count}")
