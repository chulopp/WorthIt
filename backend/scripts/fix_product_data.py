#!/usr/bin/env python3
"""
scripts/fix_product_data.py — WorthIt Database Cleanup Script

This script fixes the critical data issues found in Supabase:
1. base_weight_gram: Parses correct weights from product names for today-created products.
2. brand: Extracts and updates the brand for today-created products using a known brand list.
3. category: Fixes categories for products based on specific FMCG keyword rules.

Usage:
  python scripts/fix_product_data.py --dry-run   # Preview changes without modifying DB
  python scripts/fix_product_data.py             # Apply changes to Supabase
"""
from __future__ import annotations

import argparse
import os
import re
import sys
from pathlib import Path

# Setup path so it can import from utils
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from utils.supabase_client import get_supabase

# Curated list of common FMCG brands in Indonesia (case-sensitive, order by length desc to match longest first)
CURATED_BRANDS = [
    "Tropicana Slim", "Fisherman's Friend", "Cussons Baby", "Sari Roti", "Mama Lemon", "Mama Lime",
    "Bumbu Bunda", "Tjampolay", "La Fonte", "Bihunku", "Arirang", "Mr Bread", "Nutrijell", "SilverQueen",
    "Bear Brand", "Hydro Coco", "Coca-Cola", "Le Minerale", "Cimory", "Cadbury", "Fortune", "Alfamart",
    "Fukumi", "Anak Raja", "Zwitsal", "Lifebuoy", "Pringles", "Banyuatis", "Ajinomoto", "Dua Belibis",
    "Del Monte", "Chocolatos", "East Bali Cashews", "Nextar", "Selection", "Wardah", "Azarine", "Cetaphil",
    "Garnier", "Vaseline", "Sensodyne", "Ciptadent", "Listerine", "Sania", "Biskuat", "Flimrice", "Nature",
    "Filippo Berio", "Bagus", "Bali Dancer", "Bee Brand Soap", "Belfoods", "Benfarm", "BenFarm", "Fiesta",
    "Poci", "Sasa", "Yupi", "Mentos", "Relaxa", "Oreo", "Tango", "Richeese", "KitKat", "Oatside", "Naraya",
    "Nescafe", "Kopiko", "Golda", "Dancow", "SGM", "Bebelac", "Nutrilon Royal", "Nutrilon", "Prenagen",
    "Indomilk", "Omela", "Prochiz", "WinCheez", "Honey Stars", "Kellogg's", "Sharon", "Pondan", "Haan",
    "My Vla", "Morris", "Zinc", "Ellips", "Natur", "Mitu", "Pigeon", "Aice", "Campina", "Wall's", "Morris",
    "Lervia", "Ekonomi", "Rinso", "So Klin", "Daia", "Attack", "Sunlight", "Milo", "Kobe", "Royco",
    "Masako", "Sajiku", "Bamboe", "Desaku", "Koepoe Koepoe", "Swallow Globe", "Sedaap", "Indomie", "Pop Mie",
    "Gaga", "Sarimi", "Supermi", "Lemonilo", "Bihunku", "Burung Dara", "Super Bubur", "Energen", "Maya",
    "Botan", "Pronas", "Royale", "Kokita", "BonCabe", "Aoka", "Refina", "Antaka", "Saori", "Djoe Hoa",
    "Cap Angsa", "Maestro", "Heinz", "Lee Kum Kee", "Bertolli", "Club", "Vit", "Cleo", "Pura", "Grouu",
    "Gasol", "Milna", "2Tang", "Aquviva", "Anget Sari", "Anmum", "2 Jempol", "Aladdin"
]

# Sort brands by length in descending order to prioritize matching e.g., "Tropicana Slim" before "Slim" or "Sari Roti" before "Roti"
CURATED_BRANDS.sort(key=len, reverse=True)

# Category correction rules
CATEGORY_RULES = [
    # (Target Category, Keyword list, Reason)
    ('Sembako', ['mi instan', 'mie instan', 'ramen', 'kwetiau instan', 'bihun instan', 'soto cup', 'pop mie', 'sedaap cup', 'mi cup', 'mie cup', 'kwetiau kuah', 'noodle', 'noodles'], 'Instant Noodles (Staples)'),
    ('Sembako', ['susu bubuk', 'sgm', 'dancow', 'bebelac', 'nutrilon', 'prenagen', 'milo bubuk', 'milo 3in1', 'susu formula', 'formula bayi', 'bubuk pertumbuhan'], 'Powdered Milk (Staples)'),
    ('Sembako', ['sarden', 'kornet', 'sosis kaleng', 'kaleng', 'sardine', 'mackerel kaleng'], 'Canned Foods (Staples)'),
    ('Sembako', ['tepung beras', 'tepung organik', 'tepung ketan', 'tepung tapioka', 'tepung maizena', 'tepung terigi', 'tepung terigu', 'garam meja', 'garam himalaya', 'gula pasir', 'gula batu', 'gula aren bubuk'], 'Staples / Baking / Flours'),
    ('Kebutuhan Rumah', ['deterjen', 'pewangi pakaian', 'pelembut pakaian', 'so klin', 'daia', 'attack', 'rinso', 'pewangi refill', 'detergent', 'sabun cuci piring', 'sunlight', 'mama lemon', 'mama lime', 'kilau nipis'], 'Laundry / Dish soaps'),
    ('Minuman', ['kopi bubuk', 'kopi instan', 'kopi hitam', 'kopi blend', 'kopi susu', 'americano', 'caffe latte', 'cappuccino', 'es teh', 'teh panas', 'gula jawa panas', 'teh celup', 'teh melati', 'teh hitam', 'teh hijau', 'kopi', 'teh', 'susu cair', 'susu uht', 'susu steril', 'susu pasteurisasi'], 'Drinks / Coffee / Tea'),
]


def parse_weight_from_name(name: str) -> float | None:
    """
    Parses weight/unit from product name and returns value in grams or milliliters.
    Handles multipliers like '25 x 2 g' or '9 x 27 g' and single units.
    """
    name_lower = name.lower()

    # 1. Multiplier pattern e.g., '25 x 2 g', '9 x 27 g', '24 x 8 g'
    # Format: QTY x VAL UNIT
    mult_match = re.search(
        r"\b(\d+)\s*[xX]\s*(\d+(?:[.,]\d+)?)\s*(kg|g|gr|gram|ml|l|ltr|liter|pcs|pc|pack|sachet|sheets|sheet|kantung|celup)\b",
        name_lower
    )
    if mult_match:
        qty = int(mult_match.group(1))
        val = float(mult_match.group(2).replace(",", "."))
        unit = mult_match.group(3)
        if unit in ['kg', 'l', 'ltr', 'liter']:
            val *= 1000
        return round(qty * val, 2)

    # 2. Single unit pattern e.g., '250 ml', '5 kg', '1.5 l', '45 g', '20 pcs'
    single_match = re.search(
        r"\b(\d+(?:[.,]\d+)?)\s*(kg|g|gr|gram|ml|l|ltr|liter|pcs|pc|pack|sachet|sheets|sheet|kantung celup|kantung|celup)\b",
        name_lower
    )
    if single_match:
        val = float(single_match.group(1).replace(",", "."))
        unit = single_match.group(2)
        if unit in ['kg', 'l', 'ltr', 'liter']:
            val *= 1000
        return round(val, 2)

    return None


def extract_brand_from_name(name: str, database_brands: set[str]) -> str:
    """
    Extracts brand name from product name based on CURATED_BRANDS and database distinct brands.
    """
    name_lower = name.lower()
    
    # Merge curated and database-discovered brands
    all_brands = sorted(list(set(CURATED_BRANDS) | database_brands), key=len, reverse=True)
    
    for brand in all_brands:
        brand_lower = brand.lower()
        # Check if product name starts with the brand name (or contains it with word boundaries)
        if name_lower.startswith(brand_lower) or f" {brand_lower} " in f" {name_lower} ":
            return brand
            
    # Default: if first word looks like a brand and is capitalized, we can fallback, but let's keep empty string if not matched
    return ""


def check_category_rules(name: str, current_category: str) -> str:
    """
    Returns suggested category if name matches specific FMCG rules.
    """
    name_lower = name.lower()
    for suggested_category, keywords, reason in CATEGORY_RULES:
        for kw in keywords:
            # Word boundary search to avoid partial word match
            if f" {kw} " in f" {name_lower} " or name_lower.startswith(kw) or name_lower.endswith(kw):
                if current_category != suggested_category:
                    return suggested_category
    return current_category


def main() -> int:
    parser = argparse.ArgumentParser(description="Fix product weights, brands, and categories in Supabase.")
    parser.add_argument("--dry-run", action="store_true", help="Preview modifications without writing to the database.")
    args = parser.parse_args()

    print("Connecting to Supabase...")
    sb = get_supabase()

    # 1. Fetch all products to analyze and build brand database
    print("Fetching products...")
    all_products_res = sb.table("products").select("id, name, category, brand, base_weight_gram, created_at, sku").execute()
    all_products = all_products_res.data or []
    
    # Discovery of database brands
    database_brands = {p['brand'] for p in all_products if p.get('brand') and p['brand'].strip() != ''}
    print(f"Loaded {len(all_products)} products. Discovered {len(database_brands)} distinct brands in DB.")

    # Filter products created today (2026-07-22) for weight/brand updates
    target_products = [p for p in all_products if p.get('created_at', '').startswith('2026-07-22')]
    print(f"Found {len(target_products)} products created today ('2026-07-22') for auditing.")

    weight_updates = []
    brand_updates = []
    category_updates = []
    
    print("\n--- Auditing Products ---")
    for p in all_products:
        pid = p['id']
        name = p['name']
        curr_weight = float(p.get('base_weight_gram') or 0.0)
        curr_brand = p.get('brand') or ""
        curr_category = p.get('category') or ""
        is_today = p.get('created_at', '').startswith('2026-07-22')

        updated_fields = {}

        # Rule A: Fix Weight (Only for today's products which are defaulted to 1000.00)
        if is_today and curr_weight == 1000.00:
            parsed_weight = parse_weight_from_name(name)
            if parsed_weight is not None and parsed_weight != curr_weight:
                updated_fields['base_weight_gram'] = parsed_weight
                weight_updates.append((name, curr_weight, parsed_weight))

        # Rule B: Fix Brand (Only for today's products which have empty brand)
        if is_today and curr_brand == "":
            extracted_brand = extract_brand_from_name(name, database_brands)
            if extracted_brand != "":
                updated_fields['brand'] = extracted_brand
                brand_updates.append((name, extracted_brand))

        # Rule C: Fix Category (For all products to ensure general clean classification)
        suggested_category = check_category_rules(name, curr_category)
        if suggested_category != curr_category:
            # Handle specific false positive exemptions
            is_false_positive = False
            if suggested_category == 'Makanan Ringan' and 'beras' in name.lower():
                is_false_positive = True  # "beras cokelat" is Sembako
            if suggested_category == 'Minuman' and 'permen' in name.lower():
                is_false_positive = True  # "permen kopi" is Snack
            if suggested_category == 'Kesehatan dan Kebersihan' and 'bubuk' in name.lower():
                is_false_positive = True  # "susu bubuk bayi" is Sembako
            if suggested_category == 'Bumbu Dapur' and 'sarden' in name.lower():
                is_false_positive = True  # "sarden saus tomat" is Sembako
            
            if not is_false_positive:
                updated_fields['category'] = suggested_category
                category_updates.append((name, curr_category, suggested_category))

        # Queue the database update if any fields changed
        if updated_fields:
            p['pending_updates'] = updated_fields

    # Display findings
    print(f"\nAudit Summary:")
    print(f"  - Weight updates queued: {len(weight_updates)} products")
    print(f"  - Brand updates queued: {len(brand_updates)} products")
    print(f"  - Category corrections queued: {len(category_updates)} products")

    if weight_updates:
        print("\nSample Weight Corrections (First 15):")
        for name, old, new in weight_updates[:15]:
            print(f"  - {name[:60]}: {old}g -> {new}g")
            
    if brand_updates:
        print("\nSample Brand Corrections (First 15):")
        for name, brand in brand_updates[:15]:
            print(f"  - {name[:60]}: Brand -> '{brand}'")
            
    if category_updates:
        print("\nSample Category Corrections (First 15):")
        for name, old, new in category_updates[:15]:
            print(f"  - {name[:60]}: [{old}] -> [{new}]")

    # Apply database updates
    to_update = [p for p in all_products if 'pending_updates' in p]
    if not to_update:
        print("\nNo database updates needed.")
        return 0

    if args.dry_run:
        print(f"\n[DRY RUN] Would update {len(to_update)} products in Supabase. Database was NOT modified.")
        return 0

    print(f"\nApplying {len(to_update)} product updates to Supabase in batches...")
    
    # We perform updates in batches to be efficient
    batch_size = 50
    success_count = 0
    for idx in range(0, len(to_update), batch_size):
        batch = to_update[idx : idx + batch_size]
        try:
            # Execute single update request per product (Supabase SDK client doesn't support bulk update with different values easily in one call, 
            # but we can run them concurrently or sequentially. We will run sequentially for safety)
            for p in batch:
                sb.table("products").update(p['pending_updates']).eq("id", p['id']).execute()
                success_count += 1
            print(f"Updated batch {idx // batch_size + 1}/{(len(to_update) - 1) // batch_size + 1}...")
        except Exception as exc:
            print(f"Error updating batch at index {idx}: {exc}")

    print(f"\nSuccessfully updated {success_count}/{len(to_update)} products in Supabase!")
    return 0


if __name__ == "__main__":
    sys.exit(main())
