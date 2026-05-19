from __future__ import annotations

import os
import re
import mimetypes
from pathlib import Path
from datetime import datetime, timedelta, timezone
from uuid import uuid4
from supabase import create_client, Client
from dotenv import load_dotenv

from core.categories import OFFICIAL_CATEGORIES

load_dotenv()

# ─── Singleton Supabase Client ─────────────────────────────────────────────────

_supabase: Client | None = None

def get_supabase() -> Client:
    global _supabase
    if _supabase is None:
        url = os.getenv("SUPABASE_URL")
        key = (
            os.getenv("SUPABASE_SERVICE_ROLE_KEY")
            or os.getenv("SUPABASE_SECRET_KEY")
            or os.getenv("SUPABASE_KEY")
        )
        if not url or not key:
            raise RuntimeError(
                "SUPABASE_URL dan SUPABASE_SERVICE_ROLE_KEY/SUPABASE_KEY tidak ditemukan di .env"
            )
        _supabase = create_client(url, key)
    return _supabase


def _safe_execute(query):
    """Helper untuk menjalankan query Supabase dengan proteksi None response."""
    res = query.execute()
    if res is None:
        # Ini biasanya terjadi jika ada network error atau bug di client library
        raise RuntimeError("Supabase execute() returned None")
    return res


def _missing_column_name(exc: Exception) -> str | None:
    """Extract PostgREST missing-column messages across select/insert failures."""
    match = re.search(r"(?:column [^.]+\.)?([A-Za-z_][A-Za-z0-9_]*) (?:does not exist|column)", str(exc))
    if match:
        return match.group(1)
    match = re.search(r"Could not find the '([^']+)' column", str(exc))
    return match.group(1) if match else None


def _insert_with_schema_fallback(table: str, payload: dict) -> dict:
    """
    Insert while stripping optional fields that are absent in a partial demo schema.
    Required FK/business columns should still fail normally.
    """
    sb = get_supabase()
    current = dict(payload)
    optional_columns = {
        "decision_score",
        "decision",
        "is_fake_discount",
        "is_shrinkflation",
        "wma_insight",
        "snr_insight",
        "scan_result_score",
        "scanned_price",
        "normal_price",
        "status",
        "urgency",
        "weight_gram",
        "analysis_snapshot",
    }
    action_variants = {
        "BUY": ["buy", "buy_original"],
        "SUBSTITUTE": ["buy_substitute", "substitute"],
        "SKIP": ["skip", "dont_buy"],
    }

    while True:
        try:
            res = _safe_execute(sb.table(table).insert(current))
            return res.data[0] if res.data else {}
        except Exception as exc:
            missing = _missing_column_name(exc)
            if missing not in optional_columns or missing not in current:
                action = current.get("action_taken")
                if "invalid input value for enum" in str(exc) and action in action_variants:
                    current["action_taken"] = action_variants[action].pop(0)
                    continue
                raise
            current.pop(missing)


def _canonical_action(action: str | None) -> str:
    """Normalize action names across PRD and older demo enum values."""
    value = (action or "").upper()
    if value in {"BUY", "BOUGHT", "ADD", "BUY_ORIGINAL"}:
        return "BUY"
    if value in {"SUBSTITUTE", "BUY_SUBSTITUTE", "SUBSTITUTION"}:
        return "SUBSTITUTE"
    if value in {"SKIP", "DONT_BUY", "DON'T_BUY", "CANCEL", "SKIPPED"}:
        return "SKIP"
    return value


def weights_match(scanned_weight: float, database_weight: float, tolerance: float = 0.5) -> bool:
    """Match berat/ukuran produk. Tolerance kecil untuk angka OCR decimal."""
    if scanned_weight <= 0 or database_weight <= 0:
        return False
    return abs(float(scanned_weight) - float(database_weight)) <= tolerance


# ─── Users ────────────────────────────────────────────────────────────────────

def get_user(user_id: str) -> dict | None:
    """Ambil data user beserta subscription tier."""
    sb = get_supabase()
    res = _safe_execute(sb.table("users").select("*").eq("id", user_id).limit(1))
    return res.data[0] if res.data else None


def delete_user_account(user_id: str) -> None:
    """
    Hapus data aplikasi user lalu hapus Supabase Auth user dengan service role.
    Urutan delete mengikuti FK aplikasi; master products/price_history tidak disentuh.
    """
    sb = get_supabase()
    for table in (
        "notifications",
        "favorite_products",
        "scan_history",
        "purchase_history",
        "monthly_shopping_lists",
        "subscriptions",
        "users",
    ):
        try:
            _safe_execute(sb.table(table).delete().eq("user_id", user_id))
        except Exception as exc:
            message = str(exc).lower()
            if "does not exist" not in message and "not found" not in message:
                raise

    sb.auth.admin.delete_user(user_id)


FREE_WEEKLY_SCAN_LIMIT = 35


def get_scan_quota_status(user_id: str) -> dict:
    """Hitung quota scan mingguan dari scan_history 7 hari terakhir."""
    sb = get_supabase()
    user = get_user(user_id)
    if not user:
        return {
            "can_scan": False,
            "message": "User tidak ditemukan.",
            "tier": "free",
            "limit": FREE_WEEKLY_SCAN_LIMIT,
            "period": "weekly",
            "used": 0,
            "remaining": 0,
        }

    tier = user.get("subscription_tier", "FREE").upper()
    if tier == "PRO":
        return {
            "can_scan": True,
            "message": "Pro user has unlimited scans.",
            "tier": "pro",
            "limit": None,
            "period": "unlimited",
            "used": None,
            "remaining": None,
        }

    since = (datetime.now(timezone.utc) - timedelta(days=7)).isoformat()
    res = _safe_execute(sb.table("scan_history")
        .select("id")
        .eq("user_id", user_id)
        .gte("created_at", since)
        .limit(FREE_WEEKLY_SCAN_LIMIT + 1))
    used = len(res.data or [])
    remaining = max(0, FREE_WEEKLY_SCAN_LIMIT - used)
    can_scan = used < FREE_WEEKLY_SCAN_LIMIT

    return {
        "can_scan": can_scan,
        "message": (
            f"Scan tersedia: {used}/{FREE_WEEKLY_SCAN_LIMIT} terpakai minggu ini."
            if can_scan
            else "Limit scan mingguan (35x) telah tercapai. Upgrade ke PRO untuk scan tanpa batas."
        ),
        "tier": "free",
        "limit": FREE_WEEKLY_SCAN_LIMIT,
        "period": "weekly",
        "used": used,
        "remaining": remaining,
    }


def check_scan_limit(user_id: str) -> tuple[bool, str]:
    """Compatibility wrapper untuk pengecekan limit scan."""
    status = get_scan_quota_status(user_id)
    return bool(status["can_scan"]), status["message"]




# ─── Products ─────────────────────────────────────────────────────────────────

def find_product(name: str, category: str) -> dict | None:
    """
    Cari produk dengan logika multi-stage:
    1. Exact match dalam kategori.
    2. Partial match dalam kategori.
    3. Partial match global.
    """
    sb = get_supabase()

    # 1. Exact match dalam kategori
    res = _safe_execute(sb.table("products") \
        .select("*") \
        .ilike("name", name) \
        .eq("category", category) \
        .limit(1))
    if res.data:
        return res.data[0]

    # 2. Partial match dalam kategori
    res = _safe_execute(sb.table("products") \
        .select("*") \
        .ilike("name", f"%{name}%") \
        .eq("category", category) \
        .limit(1))
    if res.data:
        return res.data[0]

    # 3. Partial match global
    res = _safe_execute(sb.table("products") \
        .select("*") \
        .ilike("name", f"%{name}%") \
        .limit(1))
    return res.data[0] if res.data else None


# ─── Price History ─────────────────────────────────────────────────────────────

def get_price_history(product_id: str, months: int = 6) -> list[dict]:
    """
    Ambil riwayat harga produk untuk N bulan terakhir.
    Return: list of {price, weight_gram, recorded_at}, diurutkan TERLAMA → TERBARU.
    """
    sb = get_supabase()
    cutoff = (datetime.now(timezone.utc) - timedelta(days=months * 30)).isoformat()

    res = _safe_execute(sb.table("price_history") \
        .select("price, weight_gram, recorded_at") \
        .eq("product_id", product_id) \
        .gte("recorded_at", cutoff) \
        .order("recorded_at", desc=False))

    return res.data or []


def group_history_by_month(history: list[dict]) -> list[dict]:
    """
    Kelompokkan data historis per bulan, hitung rata-rata harga & berat.
    Return: list of {month_offset, avg_price, avg_weight}, diurutkan TERLAMA → TERBARU.
    month_offset: 0 = bulan ini, 1 = 1 bulan lalu, dst.
    """
    from collections import defaultdict

    now = datetime.now(timezone.utc)
    buckets: dict[int, list] = defaultdict(list)

    for record in history:
        raw_date = record["recorded_at"]
        if len(raw_date) == 10:
            rec_date = datetime.fromisoformat(raw_date).replace(tzinfo=timezone.utc)
        else:
            rec_date = datetime.fromisoformat(raw_date.replace("Z", "+00:00"))
        # Hitung selisih bulan dari sekarang
        diff_months = (now.year - rec_date.year) * 12 + (now.month - rec_date.month)
        buckets[diff_months].append(record)

    result = []
    for offset in sorted(buckets.keys(), reverse=True):  # terlama dulu
        records = buckets[offset]
        avg_price  = sum(r["price"] for r in records) / len(records)
        avg_weight = sum(r["weight_gram"] for r in records) / len(records)
        result.append({
            "month_offset": offset,
            "avg_price":    avg_price,
            "avg_weight":   avg_weight,
        })

    return result


# ─── Substitusi ───────────────────────────────────────────────────────────────

def find_substitutes(category: str, max_ppg: float, exclude_product_id: str) -> list[dict]:
    """
    Cari produk pengganti dalam kategori yang sama dengan price-per-gram lebih rendah.
    Jika tabel substitutions memiliki mapping eksplisit, kandidat tersebut diprioritaskan.
    Return: list of {product_id, name, price, weight_gram, price_per_gram}
    """
    sb = get_supabase()

    products = []
    seen_ids = set()

    def _fetch_mapped_products(product_ids: list[str]) -> list[dict]:
        try:
            return _safe_execute(sb.table("products")
                .select("id, name, base_weight_gram")
                .in_("id", product_ids)).data or []
        except Exception as exc:
            if "base_weight_gram" not in str(exc):
                raise
            return _safe_execute(sb.table("products")
                .select("id, name")
                .in_("id", product_ids)).data or []

    def _fetch_category_products() -> list[dict]:
        try:
            return _safe_execute(sb.table("products")
                .select("id, name, base_weight_gram")
                .eq("category", category)
                .neq("id", exclude_product_id)).data or []
        except Exception as exc:
            if "base_weight_gram" not in str(exc):
                raise
            return _safe_execute(sb.table("products")
                .select("id, name")
                .eq("category", category)
                .neq("id", exclude_product_id)).data or []

    try:
        mapped_res = _safe_execute(sb.table("substitutions")
            .select("substitute_product_id")
            .eq("product_id", exclude_product_id))
        mapped_ids = [row["substitute_product_id"] for row in (mapped_res.data or [])]
        if mapped_ids:
            mapped_products = _fetch_mapped_products(mapped_ids)
            for prod in mapped_products:
                products.append(prod)
                seen_ids.add(prod["id"])
    except Exception:
        # Older demo databases may not have the optional substitutions table yet.
        pass

    # Ambil semua produk dalam kategori (kecuali produk saat ini dan kandidat mapping)
    category_products = _fetch_category_products()

    for prod in category_products:
        if prod["id"] not in seen_ids:
            products.append(prod)
            seen_ids.add(prod["id"])

    if not products:
        return []

    candidates = []
    for prod in products:
        # Ambil harga terbaru untuk produk ini
        ph_res = _safe_execute(sb.table("price_history") \
            .select("price, weight_gram") \
            .eq("product_id", prod["id"]) \
            .order("recorded_at", desc=True) \
            .limit(1))

        if not ph_res.data:
            continue

        latest = ph_res.data[0]
        weight = latest.get("weight_gram") or prod.get("base_weight_gram")
        if weight and weight > 0:
            ppg = latest["price"] / weight
            if ppg < max_ppg:
                candidates.append({
                    "product_id":    prod["id"],
                    "name":          prod["name"],
                    "price":         latest["price"],
                    "weight_gram":   weight,
                    "price_per_gram": round(ppg, 4),
                })

    # Urutkan dari yang paling hemat
    candidates.sort(key=lambda x: x["price_per_gram"])
    return candidates


# ─── Shopping Sessions ─────────────────────────────────────────────────────────

# ─── Cart Items ───────────────────────────────────────────────────────────────

def add_scan_record(
    user_id: str,
    product_id: str,
    scan_result_score: int,
    decision: str | None = None,
    scanned_price: float | None = None,
    normal_price: float | None = None,
    urgency: int | None = None,
    weight_gram: float | None = None,
    analysis_snapshot: dict | None = None,
) -> dict:
    """Catat setiap scan ke tabel scan_history."""
    payload = {
        "user_id":    user_id,
        "product_id": product_id,
        "scan_result_score": scan_result_score,
        "decision": decision,
        "scanned_price": scanned_price,
        "normal_price": normal_price,
        "urgency": urgency,
        "weight_gram": weight_gram,
        "analysis_snapshot": analysis_snapshot,
    }
    payload = {key: value for key, value in payload.items() if value is not None}
    return _insert_with_schema_fallback("scan_history", payload)


# ─── Dashboard ────────────────────────────────────────────────────────────────

def get_dashboard_data(user_id: str) -> dict:
    """
    Kumpulkan ringkasan dashboard dari purchase_history nyata.
    Daftar belanja bulanan tetap dikelola terpisah oleh shopping_list_items.
    """
    sb = get_supabase()
    user = get_user(user_id) or {}
    monthly_budget = float(user.get("monthly_budget") or 0)
    start_of_month = datetime.now(timezone.utc).replace(
        day=1, hour=0, minute=0, second=0, microsecond=0
    ).isoformat()

    total_spent = 0.0
    recent_items = []
    try:
        purchase_res = _safe_execute(sb.table("purchase_history")
            .select("id, product_id, purchased_price, quantity, purchased_at, products(id, name)")
            .eq("user_id", user_id)
            .gte("purchased_at", start_of_month)
            .order("purchased_at", desc=True))
        for row in purchase_res.data or []:
            price = (row.get("purchased_price") or 0) * (row.get("quantity") or 1)
            total_spent += price
            if len(recent_items) < 5:
                product = row.get("products") or {}
                recent_items.append({
                    "product_name": product.get("name", "Produk Tidak Diketahui"),
                    "price":        price,
                    "decision":     "BUY",
                    "color":        "green",
                    "timestamp":    row.get("purchased_at", ""),
                })
    except Exception:
        pass

    money_saved = 0.0
    try:
        scan_res = _safe_execute(sb.table("scan_history")
            .select("decision, scanned_price, normal_price")
            .eq("user_id", user_id))
        for row in scan_res.data or []:
            decision = str(row.get("decision") or "").strip().lower()
            scanned_price = float(row.get("scanned_price") or 0)
            normal_price = float(row.get("normal_price") or 0)
            if decision.lower() == "worthit" and scanned_price < normal_price:
                money_saved += normal_price - scanned_price
    except Exception:
        pass

    budget_remaining = max(0.0, monthly_budget - total_spent)

    return {
        "monthly_budget":    monthly_budget,
        "budget_remaining":  budget_remaining,
        "money_saved":       money_saved,
        "recent_activities": recent_items,
    }


# ─── Tracker ──────────────────────────────────────────────────────────────────

def get_tracker_data(user_id: str, month: str) -> dict:
    """
    Aggregate pengeluaran nyata dari purchase_history untuk bulan tertentu.
    """
    sb = get_supabase()
    try:
        year, mon = map(int, month.split("-"))
        start_dt = datetime(year, mon, 1, tzinfo=timezone.utc)
        if mon == 12:
            end_dt = datetime(year + 1, 1, 1, tzinfo=timezone.utc)
        else:
            end_dt = datetime(year, mon + 1, 1, tzinfo=timezone.utc)
    except Exception:
        now = datetime.now(timezone.utc)
        start_dt = now.replace(day=1, hour=0, minute=0, second=0, microsecond=0)
        end_dt = None

    try:
        purchase_query = (sb.table("purchase_history")
            .select("id, product_id, purchased_price, quantity, purchased_at, products(id, name, category)")
            .eq("user_id", user_id)
            .gte("purchased_at", start_dt.isoformat()))
        if end_dt:
            purchase_query = purchase_query.lt("purchased_at", end_dt.isoformat())
        purchases = _safe_execute(purchase_query.order("purchased_at", desc=True)).data or []
    except Exception:
        purchases = []

    total_spent = 0.0
    cat_totals: dict[str, float] = {}
    tracker_items = []

    for item in purchases:
        price = (item.get("purchased_price") or 0) * (item.get("quantity") or 1)
        total_spent += price
        prod = item.get("products") or {}
        cat = prod.get("category", "Lainnya")
        cat_totals[cat] = cat_totals.get(cat, 0) + price

        tracker_items.append({
            "product_name": prod.get("name", "Produk Tidak Diketahui"),
            "price_paid":   price,
            "date":         (item.get("purchased_at") or "")[:10],
            "decision_score": None,
            "action_taken": "BUY",
        })

    total_items = len(tracker_items)
    avg_per_item = total_spent / total_items if total_items > 0 else 0.0

    by_category = []
    for cat, amount in sorted(cat_totals.items(), key=lambda x: -x[1]):
        pct = (amount / total_spent * 100) if total_spent > 0 else 0.0
        by_category.append({"category": cat, "amount": amount, "percentage": round(pct, 1)})

    return {
        "total_spent":  total_spent,
        "total_items":  total_items,
        "avg_per_item": avg_per_item,
        "by_category":  by_category,
        "items":        tracker_items,
    }

def find_product_by_name(name: str) -> dict | None:
    """Cari produk di DB dengan exact match nama."""
    sb = get_supabase()
    res = _safe_execute(sb.table("products").select("*").eq("name", name).maybe_single())
    return res.data


# ─── Product Images ───────────────────────────────────────────────────────────

PRODUCT_SELECT = "id, name, brand, category, base_weight_gram, image_url, created_at, updated_at"


def _apply_product_category(query, category: str | None):
    if category and category in OFFICIAL_CATEGORIES:
        return query.eq("category", category)
    return query


def list_products(category: str | None = None, limit: int = 30, offset: int = 0) -> list[dict]:
    """List produk katalog tanpa query dummy."""
    sb = get_supabase()
    query = sb.table("products") \
        .select(PRODUCT_SELECT) \
        .order("name") \
        .range(offset, max(offset, 0) + max(limit, 1) - 1)
    query = _apply_product_category(query, category)
    res = _safe_execute(query)
    return res.data or []


def _search_once(q: str, category: str | None, limit: int) -> list[dict]:
    sb = get_supabase()
    pattern = f"%{q}%"
    query = sb.table("products") \
        .select(PRODUCT_SELECT) \
        .or_(f"name.ilike.{pattern},brand.ilike.{pattern}") \
        .order("name") \
        .limit(limit)
    query = _apply_product_category(query, category)
    res = _safe_execute(query)
    return res.data or []


def search_products(q: str, category: str | None = None, limit: int = 30) -> list[dict]:
    """Cari produk berdasarkan nama/brand, opsional dibatasi kategori."""
    normalized = " ".join((q or "").split())
    if not normalized:
        return list_products(category=category, limit=limit)

    rows = _search_once(normalized, category, limit)
    if rows:
        return rows

    seen: set[str] = set()
    fallback: list[dict] = []
    for token in [part for part in re.split(r"\W+", normalized) if len(part) >= 3]:
        for row in _search_once(token, category, limit):
            if row["id"] not in seen:
                fallback.append(row)
                seen.add(row["id"])
            if len(fallback) >= limit:
                return fallback
    return fallback


def latest_prices_by_product(product_ids: list[str]) -> dict[str, float]:
    if not product_ids:
        return {}
    sb = get_supabase()
    res = _safe_execute(sb.table("price_history")
        .select("product_id, price, recorded_at")
        .in_("product_id", product_ids)
        .order("recorded_at", desc=True))
    prices: dict[str, float] = {}
    for row in res.data or []:
        product_id = row.get("product_id")
        if product_id and product_id not in prices:
            prices[product_id] = float(row.get("price") or 0)
    return prices


def get_product(product_id: str) -> dict | None:
    """Ambil produk berdasarkan id."""
    sb = get_supabase()
    res = _safe_execute(sb.table("products").select(PRODUCT_SELECT).eq("id", product_id).limit(1))
    return res.data[0] if res.data else None


def get_product_price_history(product_id: str) -> list[dict]:
    """Ambil seluruh riwayat harga produk, urut dari data paling lama."""
    sb = get_supabase()
    res = _safe_execute(sb.table("price_history")
        .select("id, product_id, price, weight_gram, unit_label, recorded_at, created_at, updated_at")
        .eq("product_id", product_id)
        .order("recorded_at", desc=False))
    rows = res.data or []
    for row in rows:
        recorded_at = row.get("recorded_at")
        if isinstance(recorded_at, str) and len(recorded_at) >= 7:
            row["recorded_at"] = recorded_at[:7]
    return rows


def _flatten_favorite(row: dict) -> dict:
    product = row.get("products") or row.get("product") or {}
    return {
        "favorite_id": row["id"],
        "favorited_at": row.get("created_at", ""),
        "id": product.get("id", row.get("product_id")),
        "name": product.get("name", ""),
        "brand": product.get("brand"),
        "category": product.get("category", ""),
        "base_weight_gram": product.get("base_weight_gram", 0),
        "image_url": product.get("image_url"),
        "created_at": product.get("created_at"),
        "updated_at": product.get("updated_at"),
    }


def list_favorite_products(user_id: str) -> list[dict]:
    """Ambil produk favorit user dengan join ke tabel products."""
    sb = get_supabase()
    res = _safe_execute(sb.table("favorite_products")
        .select(f"id, product_id, created_at, products({PRODUCT_SELECT})")
        .eq("user_id", user_id)
        .order("created_at", desc=True))
    return [_flatten_favorite(row) for row in (res.data or [])]


def add_favorite_product(user_id: str, product_id: str) -> dict:
    """Tambahkan produk ke favorit user."""
    if not get_product(product_id):
        raise ValueError("PRODUCT_NOT_FOUND")

    sb = get_supabase()
    existing = _safe_execute(sb.table("favorite_products")
        .select("id")
        .eq("user_id", user_id)
        .eq("product_id", product_id)
        .limit(1))
    if existing.data:
        raise ValueError("FAVORITE_ALREADY_EXISTS")

    try:
        inserted = _safe_execute(sb.table("favorite_products")
            .insert({"user_id": user_id, "product_id": product_id}))
    except Exception as exc:
        message = str(exc).lower()
        if "duplicate" in message or "unique" in message or "23505" in message:
            raise ValueError("FAVORITE_ALREADY_EXISTS") from exc
        raise
    favorite_id = inserted.data[0]["id"] if inserted.data else None

    query = sb.table("favorite_products") \
        .select(f"id, product_id, created_at, products({PRODUCT_SELECT})") \
        .eq("user_id", user_id) \
        .eq("product_id", product_id)
    if favorite_id:
        query = query.eq("id", favorite_id)
    res = _safe_execute(query.limit(1))
    return _flatten_favorite(res.data[0]) if res.data else {}


def remove_favorite_product(user_id: str, product_id: str) -> bool:
    """Hapus produk dari favorit user. Return False jika record tidak ada."""
    sb = get_supabase()
    existing = _safe_execute(sb.table("favorite_products")
        .select("id")
        .eq("user_id", user_id)
        .eq("product_id", product_id)
        .limit(1))
    if not existing.data:
        return False

    _safe_execute(sb.table("favorite_products")
        .delete()
        .eq("user_id", user_id)
        .eq("product_id", product_id))
    return True


def update_user_monthly_budget(user_id: str, monthly_budget: int) -> dict | None:
    """Update budget bulanan user."""
    sb = get_supabase()
    res = _safe_execute(sb.table("users")
        .update({"monthly_budget": monthly_budget})
        .eq("id", user_id))
    return res.data[0] if res.data else None


def upload_product_image(
    product_id: str,
    filename: str,
    content: bytes,
    content_type: str | None,
) -> dict:
    """
    Upload image bytes to Supabase Storage and save the public URL in products.image_url.

    Requires:
    - Storage bucket from PRODUCT_IMAGES_BUCKET, default: product-images
    - products.image_url column
    """
    if not get_product(product_id):
        raise ValueError("PRODUCT_NOT_FOUND")

    sb = get_supabase()
    try:
        _safe_execute(sb.table("products").select("id, image_url").eq("id", product_id).limit(1))
    except Exception as exc:
        if _missing_column_name(exc) == "image_url":
            raise RuntimeError(
                "PRODUCT_IMAGE_URL_COLUMN_MISSING: Tambahkan kolom image_url ke tabel products."
            ) from exc
        raise

    bucket = os.getenv("PRODUCT_IMAGES_BUCKET", "product-images")
    try:
        sb.storage.get_bucket(bucket)
    except Exception:
        try:
            sb.storage.create_bucket(bucket, options={"public": True})
        except Exception as exc:
            raise RuntimeError(f"STORAGE_BUCKET_UNAVAILABLE: {exc}") from exc

    suffix = Path(filename or "").suffix.lower()
    if suffix not in {".jpg", ".jpeg", ".png", ".webp", ".gif"}:
        guessed_ext = mimetypes.guess_extension(content_type or "") or ".jpg"
        suffix = ".jpg" if guessed_ext == ".jpe" else guessed_ext

    storage_path = f"products/{product_id}/{uuid4().hex}{suffix}"
    file_options = {
        "content-type": content_type or "application/octet-stream",
        "upsert": "true",
    }

    try:
        sb.storage.from_(bucket).upload(storage_path, content, file_options)
        image_url = sb.storage.from_(bucket).get_public_url(storage_path)
    except Exception as exc:
        raise RuntimeError(f"STORAGE_UPLOAD_FAILED: {exc}") from exc

    try:
        update_res = _safe_execute(sb.table("products")
            .update({"image_url": image_url})
            .eq("id", product_id))
    except Exception as exc:
        if _missing_column_name(exc) == "image_url":
            raise RuntimeError(
                "PRODUCT_IMAGE_URL_COLUMN_MISSING: Tambahkan kolom image_url ke tabel products."
            ) from exc
        raise

    if not update_res.data:
        raise ValueError("PRODUCT_NOT_FOUND")

    return {
        "product_id": product_id,
        "image_url": image_url,
        "storage_path": storage_path,
        "bucket": bucket,
    }
