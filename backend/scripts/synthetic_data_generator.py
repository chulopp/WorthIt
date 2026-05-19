"""
testing/synthetic_data_generator.py — WorthIt Synthetic Price History Generator

Modul ini mensimulasikan riwayat harga bulanan historis (backtesting data) 
berdasarkan data nyata Indeks Harga Konsumen (IHK) / Consumer Price Index (CPI) 
yang diterbitkan oleh Badan Pusat Statistik (BPS) Indonesia.

Metodologi Simulasi:
  1. Anchor Price: Harga Alfagift saat ini (hasil scraping) digunakan sebagai 
     harga jangkar (anchor) pada bulan April 2026.
  2. CPI Mapping: Setiap produk dipetakan ke kelompok pengeluaran IHK BPS 
     berdasarkan NLP sederhana (regex pattern matching) dari nama dan kategori.
  3. Price Deflation: Harga historis untuk bulan t-n dihitung dengan mendeflasi 
     harga jangkar menggunakan rasio IHK:
        Price(t-n) = Anchor_Price * (IHK_Bulan_t-n / IHK_Anchor)
  4. Market Noise: Injeksi varians probabilistik (diskon acak 2-5% dengan 
     peluang 20%) untuk produk FMCG agar meniru volatilitas harga ritel asli.

Tujuan:
  Menyediakan dataset historis 6 bulan yang realistis secara makroekonomi 
  untuk menguji algoritma S/R dan WMA pada `worthit_engine.c` tanpa harus 
  menunggu pengumpulan data live selama 6 bulan.
"""
from pathlib import Path
import re
import random

import pandas as pd


random.seed(42)

SCRIPT_DIR = Path(__file__).resolve().parent
PROJECT_ROOT = SCRIPT_DIR.parent
INPUT_PATH = PROJECT_ROOT / "docs" / "alfagift.csv"
OUTPUT_PATH = SCRIPT_DIR / "alfagift_monthly_prices_cpi_dummy.csv"

MONTHS = ["Nov 25", "Dec 25", "Jan 26", "Feb 26", "Mar 26", "Apr 26", "May 26"]
HISTORICAL_MONTHS = MONTHS[:-1]
IHK_ANCHOR_MONTH = "Apr 26"
DEFAULT_CPI_GROUP = "Umum (Headline)"
FOOD_CPI_GROUP = "Makanan, Minuman dan Tembakau"
PERSONAL_CARE_CPI_GROUP = "Perawatan Pribadi dan Jasa Lainnya"
HOUSEHOLD_CARE_CPI_GROUP = "Perlengkapan, Peralatan dan Pemeliharaan Rutin Rumah Tangga"

IHK_FILES = {
    "Nov 25": ("tabel_ihk_inflasi_november_2025.xlsx", "November", "2025"),
    "Dec 25": ("tabel_ihk_inflasi_desember_2025.xlsx", "Desember", "2025"),
    "Jan 26": ("tabel_ihk_inflasi_januari_2026.xlsx", "Januari", "2026"),
    "Feb 26": ("tabel_ihk_inflasi_februari_2026.xlsx", "Februari", "2026"),
    "Mar 26": ("tabel_ihk_inflasi_maret_2026.xlsx", "Maret", "2026"),
    "Apr 26": ("tabel_ihk_inflasi_april_2026.xlsx", "April", "2026"),
}

SEMBAKO_PATTERNS = [
    r"\bberas\b",
    r"\bminyak\s+goreng\b",
    r"\bgula\b",
    r"\btepung\b",
    r"\btelur\b",
    r"\bmargarin\b",
    r"\bsusu\b",
    r"\bkrimer\b",
    r"\bmie\b",
    r"\bmi\s+(instan|goreng|kuah|ayam|soto|kari|cup|telur)\b",
    r"\bbihun\b",
    r"\bsarden\b",
    r"\bkornet\b",
    r"\bbubur\b",
    r"\bbumbu\b",
    r"\bgaram\b",
    r"\bkecap\b",
    r"\bsaus\b",
    r"\bsambal\b",
    r"\bsereal\b",
]

FOOD_PATTERNS = [
    *SEMBAKO_PATTERNS,
    r"\bmi\b",
    r"\bkopi\b",
    r"\bteh\b",
    r"\bair\s+mineral\b",
    r"\bminuman\b",
    r"\bsusu\b",
    r"\byoghurt\b",
    r"\bkeju\b",
    r"\bmayones\b",
    r"\bselai\b",
    r"\bmadu\b",
    r"\bbiskuit\b",
    r"\bwafer\b",
    r"\bcokelat\b",
    r"\bpermen\b",
    r"\bsnack\b",
    r"\bkeripik\b",
    r"\bchitato\b",
    r"\bpop\s*mie\b",
    r"\bsarden\b",
    r"\bspaghetti\b",
    r"\bpasta\b",
    r"\bkornet\b",
]

PERSONAL_CARE_PATTERNS = [
    r"\bpasta\s+gigi\b",
    r"\bsikat\s+gigi\b",
    r"\bshampo\b",
    r"\bsampo\b",
    r"\bsabun\b",
    r"\bbody\s*wash\b",
    r"\bdeodorant\b",
    r"\bdeodoran\b",
    r"\bhandbody\b",
    r"\blotion\b",
    r"\bskincare\b",
    r"\bpembalut\b",
    r"\btissue\b",
    r"\btisu\b",
]

HOUSEHOLD_CARE_PATTERNS = [
    r"\bdeterjen\b",
    r"\bdetergen\b",
    r"\bpewangi\b",
    r"\bpelembut\b",
    r"\bpembersih\b",
    r"\bpencuci\b",
    r"\bsabun\s+cuci\b",
    r"\bkarbol\b",
    r"\bdisinfektan\b",
    r"\bpel\b",
    r"\bwipol\b",
    r"\brinso\b",
    r"\bmolto\b",
    r"\bsunlight\b",
    r"\bso\s*klin\b",
]


def round_to_nearest_hundred(price):
    return int(round(price / 100) * 100)


def matches_any_pattern(text, patterns):
    return any(re.search(pattern, text) for pattern in patterns)


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


def categorize_product(row):
    """
    Klasifikasi heuristik awal: Sembako vs FMCG reguler.
    Sembako memiliki bobot inflasi/IHK yang berbeda dan lebih volatil.
    """
    product_text = f"{row['input_name']} {row['found_name']}".lower()

    if matches_any_pattern(product_text, SEMBAKO_PATTERNS):
        return "SEMBAKO"

    return "FMCG"


def map_cpi_group(row):
    product_text = f"{row['input_name']} {row['found_name']}".lower()

    if matches_any_pattern(product_text, PERSONAL_CARE_PATTERNS):
        return PERSONAL_CARE_CPI_GROUP
    if matches_any_pattern(product_text, HOUSEHOLD_CARE_PATTERNS):
        return HOUSEHOLD_CARE_CPI_GROUP
    if row["category"] == "SEMBAKO" or matches_any_pattern(product_text, FOOD_PATTERNS):
        return FOOD_CPI_GROUP

    return DEFAULT_CPI_GROUP


def extract_monthly_cpi(file_path, target_month_name, target_year):
    raw = pd.read_excel(file_path, header=None)
    marker_rows = raw.index[
        raw.apply(lambda row: row.astype(str).str.fullmatch(r"\(1\)").any(), axis=1)
    ].tolist()

    if not marker_rows:
        raise ValueError(f"Cannot find table marker row in {file_path.name}")

    marker_row = marker_rows[0]
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
        raise ValueError(f"Cannot locate CPI columns in {file_path.name}")

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
        file_path = SCRIPT_DIR / file_name

        if not file_path.exists():
            raise FileNotFoundError(f"IHK file not found: {file_path}")

        cpi_data[month_label] = extract_monthly_cpi(file_path, month_name, year)

    required_groups = {
        DEFAULT_CPI_GROUP,
        FOOD_CPI_GROUP,
        PERSONAL_CARE_CPI_GROUP,
        HOUSEHOLD_CARE_CPI_GROUP,
    }

    for month_label, cpi_by_group in cpi_data.items():
        missing_groups = sorted(required_groups - set(cpi_by_group))
        if missing_groups:
            raise ValueError(f"{month_label} is missing CPI groups: {missing_groups}")

    return cpi_data


def load_alfagift_products(input_path):
    if not input_path.exists():
        raise FileNotFoundError(f"Input file not found: {input_path}")

    df = pd.read_csv(input_path)
    required_columns = [
        "input_name",
        "source",
        "found_name",
        "price",
        "unit",
        "fuzzy_score",
        "sku_id",
        "match_type",
        "match_reason",
    ]
    missing_columns = [column for column in required_columns if column not in df.columns]

    if missing_columns:
        raise ValueError(f"Missing required columns: {missing_columns}")

    df = df.copy()
    df.insert(0, "id", range(1, len(df) + 1))
    df["name"] = df["found_name"]
    df["current_price"] = pd.to_numeric(df["price"], errors="coerce")

    if df["current_price"].isna().any():
        bad_rows = df[df["current_price"].isna()][["id", "input_name", "price"]]
        raise ValueError(f"Invalid price values found:\n{bad_rows.to_string(index=False)}")

    df["current_price"] = df["current_price"].astype(int)
    df["category"] = df.apply(categorize_product, axis=1)
    df["cpi_group"] = df.apply(map_cpi_group, axis=1)

    return df


def generate_cpi_based_monthly_prices(products_df, cpi_data):
    """
    Menghasilkan harga historis sintetis menggunakan deflasi IHK bulanan BPS.

    Kompleksitas: O(N * M) di mana N = jumlah produk, M = jumlah bulan historis.
    
    Pendekatan ini menjamin bahwa tren inflasi makroekonomi (misalnya, kenaikan 
    harga sembako menjelang hari raya) tercermin akurat pada data historis 
    sintetis untuk pengujian algoritma scoring.
    """
    rows = []

    for product in products_df.to_dict(orient="records"):
        current_price = int(product["current_price"])
        cpi_group = product["cpi_group"]
        anchor_cpi = cpi_data[IHK_ANCHOR_MONTH][cpi_group]
        monthly_prices = {}

        for month in HISTORICAL_MONTHS:
            month_cpi = cpi_data[month][cpi_group]
            price = current_price * (month_cpi / anchor_cpi)

            if product["category"] == "FMCG" and random.random() < 0.2:
                discount_rate = random.uniform(0.02, 0.05)
                price *= 1 - discount_rate

            monthly_prices[month] = round_to_nearest_hundred(price)

        monthly_prices["May 26"] = current_price

        rows.append({**product, **monthly_prices})

    result_df = pd.DataFrame(rows)
    output_columns = [
        "id",
        "input_name",
        "source",
        "found_name",
        "name",
        "price",
        "current_price",
        "unit",
        "fuzzy_score",
        "sku_id",
        "match_type",
        "match_reason",
        "category",
        "cpi_group",
        *MONTHS,
    ]

    return result_df[output_columns]


def validate_generated_data(df):
    invalid_may_anchor = df[df["May 26"] != df["current_price"]]
    if not invalid_may_anchor.empty:
        raise ValueError("May 26 must be exactly equal to current_price for every row.")

    missing_month_values = df[MONTHS].isna().sum().sum()
    if missing_month_values:
        raise ValueError("Monthly price columns contain empty values.")

    for month in MONTHS:
        invalid_rounding = df[df[month] % 100 != 0]
        if not invalid_rounding.empty:
            raise ValueError(f"{month} contains prices that are not rounded to hundreds.")

    invalid_prices = df[df[MONTHS].le(0).any(axis=1)]
    if not invalid_prices.empty:
        raise ValueError("Monthly price columns contain non-positive prices.")

    if df["category"].isna().any() or df["cpi_group"].isna().any():
        raise ValueError("Every row must have category and cpi_group values.")


def dataframe_to_markdown(df):
    try:
        return df.to_markdown(index=False)
    except ImportError:
        columns = list(df.columns)
        rows = df.astype(str).values.tolist()
        table = [
            "| " + " | ".join(columns) + " |",
            "| " + " | ".join(["---"] * len(columns)) + " |",
        ]

        for row in rows:
            table.append("| " + " | ".join(row) + " |")

        return "\n".join(table)


def print_summary(df):
    print("# Alfagift CPI-Based Synthetic Monthly Prices")
    print()
    print("Method: CPI-based synthetic estimated historical prices, anchored to current Alfagift prices.")
    print(f"Input: {INPUT_PATH}")
    print(f"Output: {OUTPUT_PATH}")
    print(f"Rows: {len(df)}")
    print()
    print("## Category Summary")
    print(dataframe_to_markdown(df["category"].value_counts().rename_axis("category").reset_index(name="count")))
    print()
    print("## CPI Group Summary")
    print(dataframe_to_markdown(df["cpi_group"].value_counts().rename_axis("cpi_group").reset_index(name="count")))
    print()
    print("## Preview")
    print(dataframe_to_markdown(df.head(20)))
    print()
    print("Note: Full data is exported to CSV. These are synthetic estimates, not actual historical prices.")


def main():
    products_df = load_alfagift_products(INPUT_PATH)
    cpi_data = load_cpi_data()
    df = generate_cpi_based_monthly_prices(products_df, cpi_data)
    validate_generated_data(df)

    print_summary(df)
    df.to_csv(OUTPUT_PATH, index=False)


if __name__ == "__main__":
    main()
