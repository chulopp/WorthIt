import sys
import os
import ssl
import urllib.request
import json
import argparse
import re
import random
from pathlib import Path
from uuid import uuid4
import pandas as pd
from collections import defaultdict

random.seed(42)

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

# IHK Configuration
TESTING_DIR = PROJECT_ROOT.parent / "personal" / "testing"
DEFAULT_CPI_GROUP = "Umum (Headline)"
FOOD_CPI_GROUP = "Makanan, Minuman dan Tembakau"
PERSONAL_CARE_CPI_GROUP = "Perawatan Pribadi dan Jasa Lainnya"
HOUSEHOLD_CARE_CPI_GROUP = "Perlengkapan, Peralatan dan Pemeliharaan Rutin Rumah Tangga"

MONTH_LABELS = ["Nov 25", "Dec 25", "Jan 26", "Feb 26", "Mar 26", "Apr 26", "May 26", "Jun 26", "Jul 26"]
MONTH_DATES = {
    "Nov 25": "2025-11-01",
    "Dec 25": "2025-12-01",
    "Jan 26": "2026-01-01",
    "Feb 26": "2026-02-01",
    "Mar 26": "2026-03-01",
    "Apr 26": "2026-04-01",
    "May 26": "2026-05-01",
    "Jun 26": "2026-06-01",
    "Jul 26": "2026-07-01",
}

IHK_FILES = {
    "Nov 25": ("tabel_ihk_inflasi_november_2025.xlsx", "November", "2025"),
    "Dec 25": ("tabel_ihk_inflasi_desember_2025.xlsx", "Desember", "2025"),
    "Jan 26": ("tabel_ihk_inflasi_januari_2026.xlsx", "Januari", "2026"),
    "Feb 26": ("tabel_ihk_inflasi_februari_2026.xlsx", "Februari", "2026"),
    "Mar 26": ("tabel_ihk_inflasi_maret_2026.xlsx", "Maret", "2026"),
    "Apr 26": ("tabel_ihk_inflasi_april_2026.xlsx", "April", "2026"),
    "May 26": ("tabel_ihk_inflasi_mei_2026.xlsx", "Mei", "2026"),
    "Jun 26": ("tabel_ihk_inflasi_juni_2026.xlsx", "Juni", "2026"),
}

# Regex Patterns for CPI Mapping
SEMBAKO_PATTERNS = [
    r"\bberas\b", r"\bminyak\s+goreng\b", r"\bgula\b", r"\btepung\b", r"\btelur\b",
    r"\bmargarin\b", r"\bsusu\b", r"\bkrimer\b", r"\bmie\b",
    r"\bmi\s+(instan|goreng|kuah|ayam|soto|kari|cup|telur)\b", r"\bbihun\b",
    r"\bsarden\b", r"\bkornet\b", r"\bbubur\b", r"\bbumbu\b", r"\bgaram\b",
    r"\bkecap\b", r"\bsaus\b", r"\bsambal\b", r"\bsereal\b",
]

FOOD_PATTERNS = [
    *SEMBAKO_PATTERNS, r"\bmi\b", r"\bkopi\b", r"\bteh\b", r"\bair\s+mineral\b",
    r"\bminuman\b", r"\bsusu\b", r"\byoghurt\b", r"\bkeju\b", r"\bmayones\b",
    r"\bselai\b", r"\bmadu\b", r"\bbiskuit\b", r"\bwafer\b", r"\bcokelat\b",
    r"\bpermen\b", r"\bsnack\b", r"\bkeripik\b", r"\bchitato\b", r"\bpop\s*mie\b",
    r"\bsarden\b", r"\bspaghetti\b", r"\bpasta\b", r"\bkornet\b",
]

PERSONAL_CARE_PATTERNS = [
    r"\bpasta\s+gigi\b", r"\bsikat\s+gigi\b", r"\bshampo\b", r"\bsampo\b",
    r"\bsabun\b", r"\bbody\s*wash\b", r"\bdeodorant\b", r"\bdeodoran\b",
    r"\bhandbody\b", r"\blotion\b", r"\bskincare\b", r"\bpembalut\b",
    r"\btissue\b", r"\btisu\b",
]

HOUSEHOLD_CARE_PATTERNS = [
    r"\bdeterjen\b", r"\bdetergen\b", r"\bpewangi\b", r"\bpelembut\b",
    r"\bpembersih\b", r"\bpencuci\b", r"\bsabun\s+cuci\b", r"\bkarbol\b",
    r"\bdisinfektan\b", r"\bpel\b", r"\bwipol\b", r"\brinso\b", r"\bmolto\b",
    r"\bsunlight\b", r"\bso\s*klin\b",
]

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

def normalize_text(value):
    return re.sub(r"\s+", " ", str(value).replace("\n", " ")).strip()

def parse_number(value):
    if pd.isna(value):
        return None
    text = str(value).strip()
    if not text or text.startswith("Catatan") or "Persentase" in text:
        return None
    if text.startswith("~0"):
        return 0.0
    text = text.replace(",", ".")
    try:
        return float(text)
    except ValueError:
        return None

def normalize_cpi_group(group):
    group = normalize_text(group)
    group = group.replace("Makanan, Minuman dan Tembakau", FOOD_CPI_GROUP)
    group = group.replace("Penyediaan Makanan", "Penyediaan Makan")
    group = group.replace("Perlengkapan, Peralatan, dan", "Perlengkapan, Peralatan dan")
    return group

def extract_monthly_cpi(file_path, target_month_name, target_year):
    raw = pd.read_excel(file_path, header=None)
    marker_rows = raw.index[
        raw.apply(lambda row: row.astype(str).str.fullmatch(r"\(1\)").any(), axis=1)
    ].tolist()

    if not marker_rows:
        # Search for row containing 'Kelompok Pengeluaran' exactly
        for idx, row in raw.iterrows():
            if any(str(val).strip().lower() == "kelompok pengeluaran" for val in row):
                marker_rows = [idx]
                break

    if not marker_rows:
        raise ValueError(f"Cannot find table marker row or header containing 'Kelompok Pengeluaran' in {file_path.name}")

    marker_row = marker_rows[0]
    header_row = raw.iloc[marker_row].fillna("").map(normalize_text)
    # Check if header row is correct, otherwise try previous row
    if not header_row.str.contains("Kelompok Pengeluaran", case=False).any() and marker_row > 0:
        header_row = raw.iloc[marker_row - 1].fillna("").map(normalize_text)
        
    category_col = next(
        (col for col, value in header_row.items() if "Kelompok Pengeluaran" in value),
        None,
    )
    cpi_col = next(
        (
            col
            for col, value in header_row.items()
            if "IHK" in value and target_month_name in value and target_year in value
        ),
        None,
    )

    if category_col is None or cpi_col is None:
        # Fallback for alternative header format
        category_col = 0
        cpi_col = next(
            (col for col, value in header_row.items() if target_month_name in value or "IHK" in value),
            1
        )

    cpi_by_group = {}
    data = raw.iloc[marker_row + 1 :].dropna(how="all")

    for _, row in data.iterrows():
        group = normalize_cpi_group(row[category_col])
        cpi_index = parse_number(row[cpi_col])

        if not group or cpi_index is None:
            continue
        if group.startswith("Catatan") or "Persentase" in group or "Data sangat kecil" in group:
            continue

        cpi_by_group[group] = cpi_index

    return cpi_by_group

def load_cpi_data():
    cpi_data = {}
    for month_label, (file_name, month_name, year) in IHK_FILES.items():
        file_path = TESTING_DIR / file_name
        if not file_path.exists():
            raise FileNotFoundError(f"IHK file not found: {file_path}")
        cpi_data[month_label] = extract_monthly_cpi(file_path, month_name, year)
    
    # Estimate July 2026 based on June 2026 + mild extrapolation (or equal to June)
    # Since July 2026 IHK is not yet published in BPS Excel, we use June 2026 as proxy
    cpi_data["Jul 26"] = cpi_data["Jun 26"].copy()
    
    return cpi_data

def matches_any_pattern(text, patterns):
    return any(re.search(pattern, text) for pattern in patterns)

def map_cpi_group(product_name, category):
    product_text = f"{product_name} {category}".lower()
    if matches_any_pattern(product_text, PERSONAL_CARE_PATTERNS):
        return PERSONAL_CARE_CPI_GROUP
    if matches_any_pattern(product_text, HOUSEHOLD_CARE_PATTERNS):
        return HOUSEHOLD_CARE_CPI_GROUP
    if matches_any_pattern(product_text, FOOD_PATTERNS):
        return FOOD_CPI_GROUP
    return DEFAULT_CPI_GROUP

def round_to_nearest_hundred(price):
    return int(round(price / 100) * 100)

def main():
    parser = argparse.ArgumentParser(description="Generate synthetic history using BPS CPI data.")
    parser.add_argument("--dry-run", action="store_true", help="Preview history rows without writing to Supabase.")
    args = parser.parse_args()

    print("Loading CPI BPS data...")
    try:
        cpi_data = load_cpi_data()
        print("CPI BPS data loaded successfully.")
    except Exception as e:
        print(f"Error loading CPI files: {e}")
        return 1

    print("Fetching products...")
    products = get_all("products?select=id,name,category,base_weight_gram,unit_label")
    print(f"Loaded {len(products)} products.")

    print("Fetching existing price history...")
    price_history = get_all("price_history?select=product_id,price,recorded_at")
    print(f"Loaded {len(price_history)} history rows.")

    # Group price history by product_id and month (YYYY-MM)
    history_by_prod = defaultdict(dict)
    for row in price_history:
        month = row["recorded_at"][:7] # YYYY-MM
        history_by_prod[row["product_id"]][month] = float(row["price"])

    to_insert = []
    skipped_count = 0
    missing_anchor_count = 0

    for prod in products:
        pid = prod["id"]
        category = prod.get("category") or ""
        name = prod.get("name") or ""
        weight = prod.get("base_weight_gram") or 1000
        unit_label = prod.get("unit_label")
        cpi_group = map_cpi_group(name, category)

        # Check existing months
        existing_months = history_by_prod[pid]

        # Determine target months to generate
        # Nov 25 to Jun 26 (we promote July 2026 in Phase 2)
        # Note: Nov 25-Mei 26 should be already present for old products
        for label in MONTH_LABELS:
            month_key = MONTH_DATES[label][:7]
            if month_key in existing_months:
                continue

            # We need to generate this month!
            # Tentukan anchor
            anchor_month = None
            anchor_price = None

            # Logic anchor:
            # 1. Jika ada harga Mei 26 (preferensi untuk produk lama)
            if "2026-05" in existing_months:
                anchor_month = "May 26"
                anchor_price = existing_months["2026-05"]
            # 2. Jika ada harga Juli 26 (preferensi untuk produk baru)
            elif "2026-07" in existing_months:
                anchor_month = "Jul 26"
                anchor_price = existing_months["2026-07"]
            # 3. Fallback ke Februari 2026 untuk Jan 2026 jika Mei/Juli tidak ada
            elif label == "Jan 26" and "2026-02" in existing_months:
                anchor_month = "Feb 26"
                anchor_price = existing_months["2026-02"]
            # 4. Fallback ke bulan pertama yang ada
            else:
                sorted_existing = sorted(existing_months.keys())
                if sorted_existing:
                    closest_month = sorted_existing[-1] # take latest available
                    for l, d in MONTH_DATES.items():
                        if d[:7] == closest_month:
                            anchor_month = l
                            anchor_price = existing_months[closest_month]
                            break

            if anchor_price is None or anchor_month is None:
                missing_anchor_count += 1
                continue

            # 1. Hitung harga baseline berdasarkan IHK BPS
            ihk_target = cpi_data[label][cpi_group]
            ihk_anchor = cpi_data[anchor_month][cpi_group]
            base_price = anchor_price * (ihk_target / ihk_anchor)

            # 2. Injeksi Volatilitas Retail & Promosi Realistis
            price = base_price

            # A. Ramadan/Lebaran Seasonality (Spike harga pangan Feb-Apr 2026)
            is_food = cpi_group == FOOD_CPI_GROUP
            if is_food and label in {"Feb 26", "Mar 26", "Apr 26"}:
                seasonality_spike = random.uniform(0.03, 0.06)
                price *= (1.0 + seasonality_spike)

            # B. Promosi & Diskon Bulanan (Peluang 25% per bulan untuk diskon 5% s.d. 15%)
            is_promo = random.random() < 0.25
            if is_promo:
                promo_discount = random.uniform(0.05, 0.15)
                price *= (1.0 - promo_discount)
            else:
                # C. Kenaikan Harga / Markup Sementara (Peluang 15% untuk naik 5% s.d. 12%)
                is_spike = random.random() < 0.15
                if is_spike:
                    price_spike = random.uniform(0.05, 0.12)
                    price *= (1.0 + price_spike)

            # D. Kebisingan Retail Harian/Bulanan (Volatilitas acak +/- 1% s.d. 3%)
            market_noise = random.uniform(-0.03, 0.03)
            price *= (1.0 + market_noise)

            final_price = round_to_nearest_hundred(price)
            if final_price <= 0:
                final_price = round_to_nearest_hundred(anchor_price)

            to_insert.append({
                "id": str(uuid4()),
                "product_id": pid,
                "price": float(final_price),
                "weight_gram": float(weight),
                "unit_label": unit_label,
                "recorded_at": MONTH_DATES[label]
            })

    print(f"Generated synthetic rows to insert: {len(to_insert)}")
    print(f"Skipped (missing anchor price): {missing_anchor_count}")

    if not to_insert:
        print("No synthetic data to generate.")
        return 0

    if args.dry_run:
        print("--- DRY RUN PREVIEW (Synthetic Rows) ---")
        for item in to_insert[:15]:
            p = next(x for x in products if x["id"] == item["product_id"])
            print(f"  {p['name']} ({item['recorded_at']}) -> Price: {item['price']}")
        if len(to_insert) > 15:
            print(f"  ... and {len(to_insert) - 15} more.")
        print("Dry run completed. No data written to database.")
        return 0

    # Insert in batches
    batch_size = 500
    for i in range(0, len(to_insert), batch_size):
        batch = to_insert[i:i+batch_size]
        print(f"Inserting batch {i//batch_size + 1}... ({len(batch)} rows)")
        try:
            insert_batch("price_history", batch)
        except Exception as e:
            print(f"Failed to insert batch: {e}")
            return 1

    print("Successfully seeded all synthetic price history gaps!")
    return 0

if __name__ == "__main__":
    sys.exit(main())
