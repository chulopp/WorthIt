"""
Refresh Supabase products and price_history from the Alfagift CPI dummy CSV.

The script uses the Supabase Management API SQL endpoint so it can run schema
alignment, destructive cleanup, import, and validation in one transaction.
"""

from __future__ import annotations

import csv
import argparse
from collections import Counter
import json
import os
import re
import ssl
import sys
import urllib.error
import urllib.request
from decimal import Decimal, InvalidOperation
from pathlib import Path
from uuid import uuid4


PROJECT_REF = "nyjojldhvpufxesplrtk"
CSV_PATH = Path(__file__).resolve().parents[2] / "personal" / "testing" / "alfagift_monthly_prices_cpi_dummy.csv"
MONTH_COLUMNS = [
    ("Nov 25", "2025-11-01"),
    ("Dec 25", "2025-12-01"),
    ("Jan 26", "2026-01-01"),
    ("Feb 26", "2026-02-01"),
    ("Mar 26", "2026-03-01"),
    ("Apr 26", "2026-04-01"),
    ("May 26", "2026-05-01"),
]


CATEGORY_KEYWORDS: list[tuple[str, tuple[str, ...]]] = [
    (
        "Kesehatan dan Kebersihan",
        (
            "sabun", "shampoo", "sampo", "pasta gigi", "sikat gigi", "deodoran",
            "lotion", "pembalut", "popok", "vitamin", "obat", "hand sanitizer",
            "masker", "bayi", "pembersih wajah", "tisu basah pembersih wajah",
            "cetaphil", "garnier", "pond's", "vaseline", "rexona", "dove",
        ),
    ),
    (
        "Kebutuhan Rumah",
        (
            "deterjen", "pewangi", "pembersih lantai", "pembersih toilet",
            "pembersih kaca", "tisu", "tissue", "kantong sampah", "aluminium foil",
            "plastik wrap", "spons", "sabut", "baterai", "lampu", "lem ",
            "lakban", "tusuk gigi", "pengharum ruangan", "obat nyamuk",
            "baygon", "hit ", "klin pak", "attack", "so klin", "daia",
        ),
    ),
    (
        "Minuman",
        (
            "air mineral", "teh ", "kopi", "susu cair", "susu uht", "susu steril",
            "yogurt drink", "minuman", "soda", "isotonik", "jus", "sirup",
            "drink", "coca-cola", "sprite", "fanta", "mizone", "hydro coco",
            "yakult", "cimory", "golda", "nescafe", "fruit tea", "pokka",
        ),
    ),
    (
        "Bumbu Dapur",
        (
            "kecap", "saus", "sambal", "bumbu", "kaldu", "penyedap", "msg",
            "merica", "kunyit", "ketumbar", "terasi", "santan", "cuka",
            "minyak wijen", "minyak zaitun", "mayones", "tepung bumbu",
            "racik", "royco", "masako", "ajinomoto", "sajiku", "kobe",
        ),
    ),
    (
        "Makanan Beku",
        (
            "nugget", "dimsum", "frozen", "beku", "es krim",
            "ice cream", "french fries", "kentang beku",
        ),
    ),
    (
        "Makanan Ringan",
        (
            "snack", "keripik", "biskuit", "wafer", "cokelat", "permen",
            "kacang", "roti", "kue", "puding", "sereal", "granola", "chiki",
            "momogi", "oreo", "tango", "richeese", "silverqueen", "kitkat",
        ),
    ),
]


def classify_category(name: str) -> str:
    haystack = f" {name.lower()} "
    for category, keywords in CATEGORY_KEYWORDS:
        if any(keyword in haystack for keyword in keywords):
            return category
    return "Sembako"


def parse_decimal(value: str, field_name: str) -> Decimal:
    cleaned = value.strip().replace(",", ".")
    try:
        return Decimal(cleaned)
    except InvalidOperation as exc:
        raise ValueError(f"Invalid numeric value for {field_name}: {value!r}") from exc


def parse_unit_value(unit: str) -> Decimal:
    match = re.search(r"(\d+(?:[.,]\d+)?)", unit or "")
    if not match:
        raise ValueError(f"Unit has no numeric component: {unit!r}")
    value = parse_decimal(match.group(1), "unit")
    normalized = unit.lower()
    if re.search(r"\bkg\b", normalized):
        return value * Decimal("1000")
    if re.search(r"\bl\b", normalized) and not re.search(r"\bml\b", normalized):
        return value * Decimal("1000")
    return value


def load_payload() -> tuple[list[dict], list[dict]]:
    if not CSV_PATH.exists():
        raise FileNotFoundError(f"CSV not found: {CSV_PATH}")

    products: list[dict] = []
    history: list[dict] = []
    seen_names: set[str] = set()

    with CSV_PATH.open("r", encoding="utf-8-sig", newline="") as handle:
        rows = list(csv.DictReader(handle))

    if len(rows) != 411:
        raise ValueError(f"Expected 411 products, found {len(rows)}")

    for index, row in enumerate(rows, start=1):
        name = (row.get("name") or "").strip()
        unit = (row.get("unit") or "").strip()
        if not name:
            raise ValueError(f"Row {index} has an empty product name")
        if name in seen_names:
            raise ValueError(f"Duplicate product name in CSV: {name}")
        seen_names.add(name)

        base_weight = parse_unit_value(unit)
        product_id = str(uuid4())
        category = classify_category(name)
        products.append(
            {
                "id": product_id,
                "name": name,
                "category": category,
                "base_weight_gram": str(base_weight),
            }
        )

        for column, recorded_at in MONTH_COLUMNS:
            price = parse_decimal(row.get(column, ""), column)
            history.append(
                {
                    "id": str(uuid4()),
                    "product_id": product_id,
                    "price": str(price),
                    "weight_gram": str(base_weight),
                    "unit_label": unit,
                    "recorded_at": recorded_at,
                }
            )

    if len(history) != len(products) * len(MONTH_COLUMNS):
        raise ValueError("History row count does not match products x months")
    return products, history


def sql_literal_json(data: list[dict]) -> str:
    payload = json.dumps(data, ensure_ascii=False, separators=(",", ":"))
    return "$json$" + payload + "$json$"


def build_sql(products: list[dict], history: list[dict]) -> str:
    products_json = sql_literal_json(products)
    history_json = sql_literal_json(history)
    return f"""
begin;

alter table public.products add column if not exists brand varchar(100);
alter table public.products add column if not exists base_weight_gram numeric(10,2) not null default 0;
alter table public.products add column if not exists created_at timestamptz not null default now();
alter table public.products add column if not exists updated_at timestamptz not null default now();

alter table public.price_history add column if not exists unit_label text;
alter table public.price_history drop column if exists province;
alter table public.price_history drop column if exists store_name;
alter table public.price_history alter column product_id set not null;
alter table public.price_history alter column recorded_at type date using recorded_at::date;
alter table public.price_history alter column recorded_at set default current_date;
alter table public.price_history alter column recorded_at set not null;

delete from public.cart_items;
delete from public.favorite_products;
delete from public.scan_history;
delete from public.price_history;
delete from public.products;

insert into public.products (id, name, category, base_weight_gram, image_url)
select
    id::uuid,
    name,
    category,
    base_weight_gram::numeric,
    null::text
from jsonb_to_recordset({products_json}::jsonb)
    as item(id text, name text, category text, base_weight_gram text);

insert into public.price_history (id, product_id, price, weight_gram, unit_label, recorded_at)
select
    id::uuid,
    product_id::uuid,
    price::numeric,
    weight_gram::numeric,
    unit_label,
    recorded_at::date
from jsonb_to_recordset({history_json}::jsonb)
    as item(id text, product_id text, price text, weight_gram text, unit_label text, recorded_at text);

do $$
declare
    product_count integer;
    history_count integer;
    orphan_count integer;
    wrong_history_count integer;
begin
    select count(*) into product_count from public.products;
    select count(*) into history_count from public.price_history;
    select count(*) into orphan_count
    from public.price_history ph
    left join public.products p on p.id = ph.product_id
    where p.id is null;
    select count(*) into wrong_history_count
    from (
        select product_id, count(*) as row_count
        from public.price_history
        group by product_id
    ) grouped
    where row_count <> 7;

    if product_count <> 411 then
        raise exception 'Expected 411 products, found %', product_count;
    end if;
    if history_count <> 2877 then
        raise exception 'Expected 2877 price_history rows, found %', history_count;
    end if;
    if orphan_count <> 0 then
        raise exception 'Found % orphan price_history rows', orphan_count;
    end if;
    if wrong_history_count <> 0 then
        raise exception 'Found % products without exactly 7 history rows', wrong_history_count;
    end if;
end $$;

commit;

select json_build_object(
    'products', (select count(*) from public.products),
    'price_history', (select count(*) from public.price_history),
    'categories', (
        select json_agg(row_to_json(c) order by c.category)
        from (
            select category, count(*)::int as count
            from public.products
            group by category
        ) c
    ),
    'months', (
        select json_agg(month_key order by month_key)
        from (
            select distinct to_char(recorded_at, 'YYYY-MM') as month_key
            from public.price_history
        ) m
    ),
    'sample', (
        select json_agg(row_to_json(s))
        from (
            select
                p.name,
                p.category,
                p.base_weight_gram,
                min(ph.unit_label) as unit_label,
                count(ph.id)::int as history_rows,
                min(to_char(ph.recorded_at, 'YYYY-MM')) as first_month,
                max(to_char(ph.recorded_at, 'YYYY-MM')) as last_month
            from public.products p
            join public.price_history ph on ph.product_id = p.id
            group by p.id, p.name, p.category, p.base_weight_gram
            order by p.name
            limit 5
        ) s
    )
) as report;
"""


def run_query(sql: str) -> object:
    token = os.getenv("SUPABASE_ACCESS_TOKEN")
    if not token:
        raise RuntimeError("SUPABASE_ACCESS_TOKEN is not set in this process")

    request = urllib.request.Request(
        f"https://api.supabase.com/v1/projects/{PROJECT_REF}/database/query",
        data=json.dumps({"query": sql}).encode("utf-8"),
        headers={
            "Authorization": f"Bearer {token}",
            "Content-Type": "application/json",
        },
        method="POST",
    )
    context = None
    try:
        import certifi  # type: ignore

        context = ssl.create_default_context(cafile=certifi.where())
    except Exception:
        context = ssl.create_default_context()

    try:
        with urllib.request.urlopen(request, timeout=120, context=context) as response:
            return json.loads(response.read().decode("utf-8"))
    except urllib.error.HTTPError as exc:
        detail = exc.read().decode("utf-8", errors="replace")
        raise RuntimeError(f"Supabase query failed: {exc.code} {detail}") from exc


def main() -> int:
    parser = argparse.ArgumentParser(description="Import Alfagift CPI dummy data into Supabase.")
    parser.add_argument("--dry-run", action="store_true", help="Validate and summarize CSV without touching Supabase.")
    parser.add_argument("--emit-query", action="store_true", help="Print the generated SQL transaction and exit.")
    args = parser.parse_args()

    products, history = load_payload()
    if args.emit_query:
        print(build_sql(products, history))
        return 0

    print(f"Validated CSV: {len(products)} products, {len(history)} price history rows")
    if args.dry_run:
        print(json.dumps({
            "categories": dict(sorted(Counter(product["category"] for product in products).items())),
            "months": [recorded_at[:7] for _column, recorded_at in MONTH_COLUMNS],
            "sample": products[:5],
        }, ensure_ascii=False, indent=2))
        return 0

    report = run_query(build_sql(products, history))
    print(json.dumps(report, ensure_ascii=False, indent=2))
    return 0


if __name__ == "__main__":
    sys.exit(main())
