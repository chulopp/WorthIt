#!/usr/bin/env python3
"""
scripts/scrape_alfagift_automated.py — WorthIt Alfagift Automated Price Scraper

Mengotomatisasi pengambilan harga produk dari Alfagift.id menggunakan Playwright
(headless Chromium) dengan teknik stealth untuk menghindari deteksi bot.

Arsitektur Stealth:
  - Rotasi User-Agent dari pool real browser signatures
  - playwright-stealth untuk menghapus fingerprint WebDriver
  - Random delay antar request (3–7 detik default) untuk meniru pola browsing manusia
  - Context rotation periodik (default: setiap 25 item) untuk refresh session
  - Penanganan terpisah untuk 429 (rate limit), 403 (block), dan CAPTCHA

Pipeline Per-Produk:
  1. Baca daftar produk dari tabel `products` Supabase
  2. Build query string (strict → alternative fallback)
  3. Capture JSON payload dari Alfagift Search API
  4. Score kandidat produk via fuzzy matching + unit validation
  5. Insert harga terpilih ke tabel `weekly_prices` Supabase

Scheduler (--daemon mode):
  - Scraping: 2 slot acak dari Jum/Sab/Minggu, jam 00:00–04:59
    (jadwal dirandomisasi setiap Senin untuk stealth long-term)
  - Agregasi bulanan: setiap tanggal 28, jam 23:50
    (average weekly_prices → price_history, lalu flush weekly_prices)

Usage:
  python scrape_alfagift_automated.py --now            # sekali jalan
  python scrape_alfagift_automated.py --daemon          # daemon penjadwalan
  python scrape_alfagift_automated.py --now --limit 10  # test 10 produk pertama
"""
from __future__ import annotations

import argparse
import asyncio
import logging
import os
import random
import re
import unicodedata
from dataclasses import dataclass
from datetime import datetime
from pathlib import Path
from typing import Any, Callable
from urllib.parse import quote

from apscheduler.schedulers.asyncio import AsyncIOScheduler
from apscheduler.triggers.cron import CronTrigger
from supabase import create_client, Client


PROJECT_ROOT = Path(__file__).resolve().parents[1]
ALFAGIFT_BASE_URL = "https://alfagift.id"
ALFAGIFT_SEARCH_API_TOKEN = "webcommerce-gw.alfagift.id/v2/products/searches"
LOGGER = logging.getLogger("alfagift_automation")

def get_supabase() -> Client:
    url = os.environ.get("SUPABASE_URL")
    key = os.environ.get("SUPABASE_KEY")
    if not url or not key:
        raise ValueError("SUPABASE_URL dan SUPABASE_KEY environment variables harus diset.")
    return create_client(url, key)

DISPLAY_UNIT_PATTERN = re.compile(r"\b(\d+(?:[.,]\d+)?)\s*([lL]|[kK][gG]|[gG]|[mM][lL])\b")
MEASUREMENT_PATTERN = re.compile(
    r"\b(\d+(?:[.,]\d+)?)\s*(kg|g|gr|gram|ml|l|ltr|liter|pcs|pc|pack)\b",
    re.I,
)

GENERIC_BRANDS = {"cap", "curah", "-", ""}
ALTERNATIVE_MIN_SCORE = 55
COMMON_PRODUCT_WORDS = {
    "air", "ayam", "barang", "beras", "bubuk", "buah", "cair", "cap", "curah", "dapur",
    "enak", "gula", "instan", "instant", "makanan", "mie", "mi", "minuman", "minyak",
    "original", "premium", "produk", "rasa", "sabun", "sambal", "saus", "shampoo",
    "special", "spesial", "super", "susu", "wangi",
}

USER_AGENTS = [
    "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/125.0.0.0 Safari/537.36",
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/125.0.0.0 Safari/537.36",
    "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.4 Safari/605.1.15",
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36 Edg/124.0.0.0",
]

PREFERRED_PRICE_KEYS = [
    "finalPrice", "finalprice", "final_price", "memberPrice", "memberprice", "member_price",
    "promoPrice", "promoprice", "promo_price", "sellingPrice", "sellingprice", "selling_price", "price",
]
REJECT_PRICE_KEYS = [
    "discount", "diskon", "percentage", "percent", "minimumQuantity", "minimum_quantity",
    "minQty", "min_qty", "qty", "quantity", "point", "poin", "cashback", "normalPrice",
    "normal_price", "originalPrice", "original_price", "strikethrough", "label", "text",
]
PREFERRED_NAME_KEYS = [
    "productName", "product_name", "name", "title", "displayName", "display_name", "itemName", "item_name",
]
PREFERRED_UNIT_KEYS = [
    "size", "variant", "variantName", "variant_name", "unit", "uom", "packSize",
    "pack_size", "netto", "weight", "volume",
]
PREFERRED_ID_KEYS = ["sku", "skuId", "sku_id", "productId", "product_id", "plu", "id"]

CAPTCHA_MARKERS = ("captcha", "cf-challenge", "cloudflare", "turnstile", "access denied", "akamai")
UNAVAILABLE_MARKERS = (
    "stok kosong", "stock empty", "out of stock", "unavailable", "tidak tersedia", "not available", "stok habis",
)


@dataclass(frozen=True)
class InputProduct:
    id_produk: str
    category: str
    name: str
    brand: str
    unit: str

    @property
    def input_name(self) -> str:
        parts = []
        if normalize_text(self.brand) not in GENERIC_BRANDS:
            parts.append(self.brand)
        parts.append(self.name)
        if self.unit:
            parts.append(self.unit)
        return " ".join(part for part in parts if part).strip()


@dataclass(frozen=True)
class ProductCandidate:
    raw: dict[str, Any]
    found_name: str
    price: int | float
    unit: str
    sku_id: str
    fuzzy_score: int
    match_type: str
    match_reason: str


@dataclass(frozen=True)
class ScrapeResult:
    input_name: str
    source: str
    found_name: str
    price: int | float
    unit: str
    fuzzy_score: int
    sku_id: str
    match_type: str
    match_reason: str


class ScrapeError(RuntimeError):
    pass


class RateLimitedError(ScrapeError):
    pass


class BlockedError(ScrapeError):
    pass


class CaptchaDetectedError(ScrapeError):
    pass


def normalize_text(value: Any) -> str:
    text = unicodedata.normalize("NFKD", str(value or ""))
    text = text.encode("ascii", "ignore").decode("ascii").lower()
    text = re.sub(r"(\d+)\s*(kg|g|gr|gram|ml|l|ltr|liter|pcs|pc|pack)\b", r"\1 \2", text)
    text = re.sub(r"[^a-z0-9]+", " ", text)
    text = text.replace(" gram", " g").replace(" gr", " g").replace(" liter", " l").replace(" ltr", " l")
    return re.sub(r"\s+", " ", text).strip()


def normalize_key(key: Any) -> str:
    return re.sub(r"[^a-z0-9]", "", str(key).lower())


def fetch_products_from_supabase(supabase: Client) -> list[InputProduct]:
    response = supabase.table("products").select("*").execute()
    products = []
    for row in response.data:
        unit_val = row.get("unit_label")
        if not unit_val:
            weight = row.get("base_weight_gram", 0)
            unit_val = f"{weight} g" if weight else ""
        
        products.append(InputProduct(
            id_produk=row["id"],
            category=row.get("category") or "",
            name=row.get("name") or "",
            brand=row.get("brand") or "",
            unit=unit_val,
        ))
    return products


def build_strict_queries(product: InputProduct) -> list[str]:
    queries = []
    brand = product.brand.strip()
    if normalize_text(brand) not in GENERIC_BRANDS:
        queries.append(f"{brand} {product.name} {product.unit}")
    else:
        queries.append(f"{product.name} {product.unit}")
    return dedupe_queries(queries)


def build_alternative_queries(product: InputProduct) -> list[str]:
    queries = [f"{product.name} {product.unit}", product.name, smart_query(product)]
    category = normalize_text(product.category)
    if category:
        queries.append(f"{category} {product.unit}".strip())
    return dedupe_queries(queries)


def build_queries(product: InputProduct) -> list[str]:
    return dedupe_queries(build_strict_queries(product) + build_alternative_queries(product))


def smart_query(product: InputProduct) -> str:
    measurements = " ".join(sorted(extract_numbers_and_units(product.unit)))
    tokens = []
    if normalize_text(product.brand) not in GENERIC_BRANDS:
        tokens.extend(normalize_text(product.brand).split())
    tokens.extend(normalize_text(product.name).split())
    specific = [token for token in tokens if token not in COMMON_PRODUCT_WORDS and not token.isdigit() and len(token) > 2]
    query = " ".join(specific[:3])
    if measurements:
        query = f"{query} {measurements}".strip()
    return query or product.name


def dedupe_queries(queries: list[str]) -> list[str]:
    deduped, seen = [], set()
    for query in queries:
        key = normalize_text(query)
        if key and key not in seen:
            seen.add(key)
            deduped.append(query.strip())
    return deduped


def value_for_keys(obj: dict[str, Any], keys: list[str]) -> Any:
    normalized = {normalize_key(key): key for key in obj.keys()}
    for preferred in keys:
        actual_key = normalized.get(normalize_key(preferred))
        if actual_key is not None:
            value = obj.get(actual_key)
            if value not in (None, ""):
                return value
    return None


def number_from_value(value: Any) -> int | float | None:
    if isinstance(value, bool) or value is None:
        return None
    if isinstance(value, (int, float)):
        return value
    if isinstance(value, str):
        cleaned = re.sub(r"rp|\s", "", value.strip(), flags=re.I)
        thousands_match = re.search(r"\d{1,3}(?:[.,]\d{3})+", cleaned)
        if thousands_match:
            digits = re.sub(r"\D", "", thousands_match.group(0))
            return int(digits) if digits else None
        match = re.search(r"\d+(?:[.,]\d+)?", cleaned)
        if not match:
            return None
        try:
            number = float(match.group(0).replace(",", "."))
        except ValueError:
            return None
        return int(number) if number.is_integer() else number
    return None


def valid_price(value: Any) -> bool:
    number = number_from_value(value)
    return number is not None and 500 < number < 1_000_000


def recursive_json_search(
    payload: Any,
    preferred_keys: list[str],
    fallback_tokens: tuple[str, ...] = (),
    reject_tokens: tuple[str, ...] = (),
    validator: Callable[[Any], bool] | None = None,
) -> Any:
    if isinstance(payload, dict):
        normalized = {normalize_key(key): key for key in payload.keys()}
        for preferred in preferred_keys:
            actual_key = normalized.get(normalize_key(preferred))
            if actual_key is None:
                continue
            found = first_valid_value(payload.get(actual_key), preferred_keys, fallback_tokens, reject_tokens, validator)
            if found is not None:
                return found
        for key, value in payload.items():
            key_norm = normalize_key(key)
            if fallback_tokens and any(token in key_norm for token in fallback_tokens):
                if not any(normalize_key(reject) in key_norm for reject in reject_tokens):
                    found = first_valid_value(value, preferred_keys, fallback_tokens, reject_tokens, validator)
                    if found is not None:
                        return found
        for value in payload.values():
            found = recursive_json_search(value, preferred_keys, fallback_tokens, reject_tokens, validator)
            if found is not None:
                return found
    elif isinstance(payload, list):
        for item in payload:
            found = recursive_json_search(item, preferred_keys, fallback_tokens, reject_tokens, validator)
            if found is not None:
                return found
    elif validator is None or validator(payload):
        return payload
    return None


def first_valid_value(
    value: Any,
    preferred_keys: list[str],
    fallback_tokens: tuple[str, ...],
    reject_tokens: tuple[str, ...],
    validator: Callable[[Any], bool] | None,
) -> Any:
    if isinstance(value, list):
        for item in value:
            found = first_valid_value(item, preferred_keys, fallback_tokens, reject_tokens, validator)
            if found is not None:
                return found
        return None
    if isinstance(value, dict):
        return recursive_json_search(value, preferred_keys, fallback_tokens, reject_tokens, validator)
    if validator is None or validator(value):
        return value
    return None


def extract_price(payload: Any) -> int | float | None:
    if isinstance(payload, dict):
        normalized = {normalize_key(key): key for key in payload.keys()}
        for preferred in PREFERRED_PRICE_KEYS:
            actual_key = normalized.get(normalize_key(preferred))
            if actual_key is None:
                continue
            number = number_from_value(payload.get(actual_key))
            if valid_price(number):
                return number
        for key, value in payload.items():
            key_norm = normalize_key(key)
            is_price_key = any(token in key_norm for token in ("price", "harga"))
            is_rejected = any(normalize_key(reject) in key_norm for reject in REJECT_PRICE_KEYS)
            if is_price_key and not is_rejected:
                number = number_from_value(value)
                if valid_price(number):
                    return number
            if isinstance(value, (dict, list)):
                number = extract_price(value)
                if number is not None:
                    return number
    elif isinstance(payload, list):
        for item in payload:
            number = extract_price(item)
            if number is not None:
                return number
    return None


def extract_first_string(obj: dict[str, Any], keys: list[str]) -> str:
    value = value_for_keys(obj, keys)
    if value in (None, "") or isinstance(value, (dict, list)):
        return ""
    return str(value).strip()


def extract_display_unit(value: str) -> str:
    match = DISPLAY_UNIT_PATTERN.search(str(value or ""))
    if not match:
        return ""
    amount, unit_raw = match.groups()
    unit = unit_raw.lower()
    if unit == "l":
        unit = "L"
    return f"{amount} {unit}"


def extract_numbers_and_units(value: str) -> set[str]:
    measurements = set()
    for amount, unit_raw in MEASUREMENT_PATTERN.findall(str(value or "")):
        unit = unit_raw.lower()
        if unit in {"gr", "gram"}:
            unit = "g"
        elif unit in {"ltr", "liter"}:
            unit = "l"
        elif unit in {"pc", "pack"}:
            unit = "pcs"
        measurements.add(f"{amount} {unit}")
    return measurements


def parse_measurements(value: str) -> set[tuple[float, str]]:
    measurements = set()
    for amount_raw, unit_raw in MEASUREMENT_PATTERN.findall(str(value or "")):
        amount = float(amount_raw.replace(",", "."))
        unit = unit_raw.lower()
        if unit in {"gr", "gram"}:
            unit = "g"
        elif unit in {"ltr", "liter"}:
            unit = "l"
        if unit == "kg":
            amount *= 1000
            unit = "g"
        elif unit == "l":
            amount *= 1000
            unit = "ml"
        elif unit in {"pc", "pack"}:
            unit = "pcs"
        measurements.add((amount, unit))
    return measurements


def has_conflicting_unit(input_unit: str, candidate_text: str) -> bool:
    input_measurements = parse_measurements(input_unit)
    candidate_measurements = parse_measurements(candidate_text)
    if not input_measurements or not candidate_measurements:
        return False
    for input_amount, input_unit_name in input_measurements:
        comparable = {
            (candidate_amount, candidate_unit)
            for candidate_amount, candidate_unit in candidate_measurements
            if candidate_unit == input_unit_name
        }
        if comparable and (input_amount, input_unit_name) not in comparable:
            return True
    return False


def has_matching_unit(input_unit: str, candidate_text: str) -> bool:
    input_measurements = parse_measurements(input_unit)
    if not input_measurements:
        return True
    candidate_measurements = parse_measurements(candidate_text)
    return bool(input_measurements & candidate_measurements)


def specific_keywords(product: InputProduct) -> set[str]:
    values = [product.name]
    if normalize_text(product.brand) not in GENERIC_BRANDS:
        values.append(product.brand)
    keywords = set()
    for value in values:
        for token in normalize_text(value).split():
            if token not in COMMON_PRODUCT_WORDS and not token.isdigit() and len(token) > 2:
                keywords.add(token)
    return keywords


def product_keyword_tokens(product: InputProduct) -> set[str]:
    tokens = set()
    for value in (product.category, product.name):
        for token in normalize_text(value).split():
            if token not in {"barang", "tambahan", "dan", "atau", "produk", "serbaguna"} and len(token) > 2:
                tokens.add(token)
    return tokens


def has_brand_match(product: InputProduct, candidate_text: str) -> bool:
    brand_norm = normalize_text(product.brand)
    return brand_norm in GENERIC_BRANDS or brand_norm in normalize_text(candidate_text)


def has_unavailable_signal(payload: Any) -> bool:
    if isinstance(payload, dict):
        for key, value in payload.items():
            key_norm = normalize_key(key)
            is_availability_key = any(token in key_norm for token in ("stock", "stok", "status", "available", "availability"))
            if is_availability_key:
                if isinstance(value, bool) and value is False:
                    return True
                value_norm = normalize_text(value)
                if any(marker in value_norm for marker in UNAVAILABLE_MARKERS):
                    return True
            if isinstance(value, (dict, list)) and has_unavailable_signal(value):
                return True
    elif isinstance(payload, list):
        return any(has_unavailable_signal(item) for item in payload)
    return False


def get_fuzz():
    try:
        from thefuzz import fuzz
    except ImportError as exc:
        raise RuntimeError("Dependency thefuzz belum terpasang. Jalankan: pip install 'thefuzz[speedup]'") from exc
    return fuzz


def base_fuzzy_score(product: InputProduct, candidate_name: str) -> int:
    """
    Hitung skor kesamaan dasar antara nama produk input dan kandidat Alfagift.

    Menggunakan token_set_ratio dari thefuzz (FuzzyWuzzy successor) yang
    melakukan tokenisasi dan set-comparison sebelum Levenshtein distance,
    sehingga tahan terhadap perbedaan urutan kata ("Indomie Goreng" vs
    "Goreng Indomie Mi").

    Returns:
        int: Skor 0–100
    """
    fuzz = get_fuzz()
    return int(fuzz.token_set_ratio(normalize_text(product.input_name), normalize_text(candidate_name)))


def score_strict_product(product: InputProduct, candidate_name: str, candidate_text: str, min_score: int) -> int | None:
    if not has_brand_match(product, candidate_text):
        return None
    if has_conflicting_unit(product.unit, candidate_text):
        return None
    if not has_matching_unit(product.unit, candidate_text):
        return None
    base = base_fuzzy_score(product, candidate_name)
    if base < min_score:
        return None
    score = base
    candidate_norm = normalize_text(candidate_text)
    if has_brand_match(product, candidate_text):
        score += 10
    input_sizes = extract_numbers_and_units(product.unit)
    candidate_sizes = extract_numbers_and_units(candidate_text)
    if input_sizes and input_sizes & candidate_sizes:
        score += 12
    if specific_keywords(product) & set(candidate_norm.split()):
        score += 15
    return min(score, 100)


def score_alternative_product(product: InputProduct, candidate_name: str, candidate_text: str, min_score: int) -> int | None:
    candidate_tokens = set(normalize_text(candidate_text).split())
    keyword_overlap = product_keyword_tokens(product) & candidate_tokens
    if not keyword_overlap:
        return None
    base = base_fuzzy_score(product, candidate_name)
    if base < min_score:
        return None
    score = base + min(20, len(keyword_overlap) * 8)
    if has_brand_match(product, candidate_text):
        score += 5
    if has_matching_unit(product.unit, candidate_text):
        score += 8
    elif has_conflicting_unit(product.unit, candidate_text):
        score -= 8
    return max(0, min(score, 100))


def score_product(product: InputProduct, candidate_name: str, candidate_text: str, min_score: int) -> int | None:
    return score_strict_product(product, candidate_name, candidate_text, min_score)


def match_reason(product: InputProduct, candidate_text: str, match_type: str) -> str:
    if match_type == "exact":
        return "brand and size match"
    reasons = []
    if not has_brand_match(product, candidate_text):
        reasons.append("brand differs")
    if has_conflicting_unit(product.unit, candidate_text):
        reasons.append("size differs")
    elif not has_matching_unit(product.unit, candidate_text):
        reasons.append("size unavailable")
    if product_keyword_tokens(product) & set(normalize_text(candidate_text).split()):
        reasons.append("keyword overlap")
    return "; ".join(reasons) or "same category fallback"


def extract_product_candidates(payload: Any) -> list[dict[str, Any]]:
    candidates = []

    def walk(node: Any) -> None:
        if isinstance(node, dict):
            name = extract_first_string(node, PREFERRED_NAME_KEYS)
            if name and (value_for_keys(node, PREFERRED_ID_KEYS) not in (None, "") or extract_price(node) is not None):
                candidates.append(node)
            for child in node.values():
                walk(child)
        elif isinstance(node, list):
            for child in node:
                walk(child)

    walk(payload)
    deduped, seen = [], set()
    for candidate in candidates:
        name = extract_first_string(candidate, PREFERRED_NAME_KEYS)
        sku = extract_first_string(candidate, PREFERRED_ID_KEYS)
        key = f"{normalize_text(name)}|{sku}"
        if key not in seen:
            seen.add(key)
            deduped.append(candidate)
    return deduped


async def apply_stealth(context: Any) -> None:
    try:
        import playwright_stealth as stealth_module
    except ImportError as exc:
        raise RuntimeError("Dependency playwright-stealth wajib terpasang. Jalankan: pip install playwright-stealth") from exc

    if hasattr(stealth_module, "stealth_async"):
        await stealth_module.stealth_async(context)
        return
    stealth_class = getattr(stealth_module, "Stealth", None)
    if stealth_class is not None:
        stealth = stealth_class()
        if hasattr(stealth, "apply_stealth_async"):
            await stealth.apply_stealth_async(context)
            return
    raise RuntimeError("playwright-stealth terpasang, tetapi API stealth yang dikenal tidak ditemukan.")


async def apply_init_scripts(context: Any) -> None:
    await context.add_init_script(
        """
        Object.defineProperty(navigator, 'webdriver', { get: () => undefined });
        Object.defineProperty(navigator, 'languages', { get: () => ['id-ID', 'id', 'en-US', 'en'] });
        window.chrome = window.chrome || { runtime: {} };
        """
    )


def contains_captcha_marker(text: str) -> bool:
    return any(marker in normalize_text(text) for marker in CAPTCHA_MARKERS)


def is_search_response(response: Any) -> bool:
    return "json" in response.headers.get("content-type", "").lower() and ALFAGIFT_SEARCH_API_TOKEN in response.url


async def wait_for_search_response(page: Any, trigger: Callable[[], Any], timeout_ms: int) -> Any | None:
    try:
        if hasattr(page, "wait_for_response"):
            waiter = asyncio.create_task(page.wait_for_response(is_search_response, timeout=timeout_ms))
            await trigger()
            return await waiter
        async with page.expect_response(is_search_response, timeout=timeout_ms) as response_info:
            await trigger()
        return await response_info.value
    except Exception:
        return None


class AlfagiftScraper:
    def __init__(self, browser: Any, headless: bool, timeout_ms: int, min_score: int, rotate_context_every: int) -> None:
        self.browser = browser
        self.headless = headless
        self.timeout_ms = timeout_ms
        self.min_score = min_score
        self.rotate_context_every = rotate_context_every
        self.context = None
        self.current_user_agent = ""
        self.items_since_rotate = 0

    async def start(self) -> None:
        await self.rotate_context("startup")

    async def close(self) -> None:
        if self.context is not None:
            await self.context.close()
            self.context = None

    async def rotate_context(self, reason: str) -> None:
        await self.close()
        self.current_user_agent = random.choice(USER_AGENTS)
        self.context = await self.browser.new_context(
            locale="id-ID",
            timezone_id="Asia/Jakarta",
            user_agent=self.current_user_agent,
            extra_http_headers={"Accept-Language": "id-ID,id;q=0.9,en-US;q=0.8,en;q=0.7"},
        )
        await apply_init_scripts(self.context)
        await apply_stealth(self.context)
        self.items_since_rotate = 0
        LOGGER.info("[alfagift] rotate context: %s", reason)

    async def maybe_rotate_context(self) -> None:
        if self.rotate_context_every > 0 and self.items_since_rotate >= self.rotate_context_every:
            await self.rotate_context("scheduled")

    async def search(self, product: InputProduct, used_result_keys: set[str] | None = None) -> ScrapeResult | None:
        used_result_keys = used_result_keys or set()
        await self.maybe_rotate_context()
        for query in build_strict_queries(product):
            payloads = await self.capture_search_payloads(query)
            candidate = self.choose_best_candidate(product, payloads, match_type="exact", used_result_keys=used_result_keys)
            if candidate:
                self.items_since_rotate += 1
                return self.result_from_candidate(product, candidate)
        for query in build_alternative_queries(product):
            payloads = await self.capture_search_payloads(query)
            candidate = self.choose_best_candidate(product, payloads, match_type="alternative", used_result_keys=used_result_keys)
            if candidate:
                self.items_since_rotate += 1
                return self.result_from_candidate(product, candidate)
        self.items_since_rotate += 1
        return None

    def result_from_candidate(self, product: InputProduct, candidate: ProductCandidate) -> ScrapeResult:
        return ScrapeResult(
            input_name=product.input_name,
            source="alfagift",
            found_name=candidate.found_name,
            price=candidate.price,
            unit=candidate.unit,
            fuzzy_score=candidate.fuzzy_score,
            sku_id=candidate.sku_id,
            match_type=candidate.match_type,
            match_reason=candidate.match_reason,
        )

    async def capture_search_payloads(self, query: str) -> list[Any]:
        assert self.context is not None
        page = await self.context.new_page()
        payloads = []
        rate_limited = False
        blocked = False
        captcha = False

        async def handle_response(response: Any) -> None:
            nonlocal rate_limited, blocked, captcha
            if response.status == 429:
                rate_limited = True
            if response.status == 403:
                blocked = True
            if contains_captcha_marker(response.url) or contains_captcha_marker(response.headers.get("content-type", "")):
                captcha = True
            if not is_search_response(response):
                return
            try:
                payloads.append(await response.json())
            except Exception:
                return

        page.on("response", lambda response: asyncio.create_task(handle_response(response)))

        async def trigger() -> None:
            await page.goto(f"{ALFAGIFT_BASE_URL}/find/{quote(query)}", wait_until="domcontentloaded", timeout=self.timeout_ms)

        response = await wait_for_search_response(page, trigger, self.timeout_ms)
        if response is not None and is_search_response(response):
            try:
                payloads.append(await response.json())
            except Exception:
                pass
        await page.wait_for_timeout(150)
        try:
            title = await page.title()
        except Exception:
            title = ""
        await page.close()

        if captcha or contains_captcha_marker(title):
            raise CaptchaDetectedError("captcha/access verification detected")
        if rate_limited:
            raise RateLimitedError("429")
        if blocked:
            raise BlockedError("403")
        return payloads

    def choose_best_candidate(
        self,
        product: InputProduct,
        payloads: list[Any],
        match_type: str,
        used_result_keys: set[str] | None = None,
    ) -> ProductCandidate | None:
        used_result_keys = used_result_keys or set()
        scored = []
        for payload in payloads:
            for raw_candidate in extract_product_candidates(payload):
                candidate = self.build_candidate(product, raw_candidate, match_type)
                if not candidate:
                    continue
                candidate_key = result_dedupe_key(candidate.sku_id, candidate.found_name, candidate.unit)
                if candidate_key in used_result_keys:
                    LOGGER.info("[alfagift] candidate already used: %s", candidate.found_name)
                    continue
                scored.append(candidate)
        if not scored:
            return None
        scored.sort(key=lambda item: (-item.fuzzy_score, item.price))
        return scored[0]

    def build_candidate(self, product: InputProduct, raw_candidate: dict[str, Any], match_type: str) -> ProductCandidate | None:
        found_name = extract_first_string(raw_candidate, PREFERRED_NAME_KEYS)
        if not found_name:
            return None
        sku_id = extract_first_string(raw_candidate, PREFERRED_ID_KEYS)
        if not sku_id:
            return None
        price = extract_price(raw_candidate)
        if price is None:
            return None
        unit = extract_display_unit(found_name) or extract_first_string(raw_candidate, PREFERRED_UNIT_KEYS) or product.unit
        candidate_text = f"{found_name} {unit}"
        if match_type == "exact":
            fuzzy_score = score_strict_product(product, found_name, candidate_text, self.min_score)
        else:
            fuzzy_score = score_alternative_product(product, found_name, candidate_text, ALTERNATIVE_MIN_SCORE)
        if fuzzy_score is None:
            return None
        return ProductCandidate(
            raw=raw_candidate,
            found_name=found_name,
            price=price,
            unit=unit,
            sku_id=sku_id,
            fuzzy_score=fuzzy_score,
            match_type=match_type,
            match_reason=match_reason(product, candidate_text, match_type),
        )


def insert_weekly_price_to_supabase(supabase: Client, product_id: str, price: int | float) -> None:
    try:
        supabase.table("weekly_prices").insert({
            "product_id": product_id,
            "price": price
        }).execute()
        LOGGER.info("[output] inserted weekly price %s for product %s", price, product_id)
    except Exception as exc:
        LOGGER.error("Failed to insert weekly price: %s", exc)


def dedupe_key(value: Any) -> str:
    return normalize_text(value)


def result_dedupe_key(sku_id: Any, found_name: Any, unit: Any) -> str:
    sku_key = dedupe_key(sku_id)
    if sku_key:
        return f"sku:{sku_key}"
    fallback = dedupe_key(f"{found_name} {unit}")
    return f"name:{fallback}" if fallback else ""


def configure_logging(args: argparse.Namespace) -> None:
    handlers: list[logging.Handler] = [logging.StreamHandler()]
    if args.log_file is not None:
        args.log_file.parent.mkdir(parents=True, exist_ok=True)
        handlers.append(logging.FileHandler(args.log_file, encoding="utf-8"))

    logging.basicConfig(
        level=getattr(logging, args.log_level),
        format="%(asctime)s %(levelname)s %(name)s: %(message)s",
        handlers=handlers,
        force=True,
    )
    for logger_name in ("aiohttp", "asyncio", "httpx", "playwright", "urllib3", "websockets"):
        logging.getLogger(logger_name).setLevel(logging.WARNING)


async def run(args: argparse.Namespace, run_at: datetime | None = None) -> int:
    run_started_at = run_at or datetime.now()
    LOGGER.info("scrape run started")
    try:
        from playwright.async_api import async_playwright
    except ImportError as exc:
        raise RuntimeError("Dependency playwright belum terpasang. Jalankan: pip install playwright") from exc

    supabase = get_supabase()
    products = fetch_products_from_supabase(supabase)
    
    if args.offset:
        products = products[args.offset :]
    if args.limit is not None:
        products = products[: args.limit]
    if not products:
        LOGGER.error("Tidak ada produk yang bisa dibaca dari Supabase.")
        elapsed = (datetime.now() - run_started_at).total_seconds()
        LOGGER.info("scrape run finished; exit_code=1 elapsed=%.1fs", elapsed)
        return 1

    used_result_keys = set()
    pending_products = [(index, product) for index, product in enumerate(products, start=1 + args.offset)]

    async with async_playwright() as playwright:
        browser = await playwright.chromium.launch(
            headless=args.headless,
            args=["--disable-blink-features=AutomationControlled", "--no-sandbox"],
        )
        scraper = AlfagiftScraper(
            browser=browser,
            headless=args.headless,
            timeout_ms=args.timeout_ms,
            min_score=args.min_score,
            rotate_context_every=args.rotate_context_every,
        )
        try:
            await scraper.start()
            for index, product in pending_products:
                LOGGER.info("[%s] search: %s (%s)", index, product.input_name, product.unit)
                try:
                    result = await scraper.search(product, used_result_keys)
                except RateLimitedError as exc:
                    pause = random.uniform(args.rate_limit_sleep_min, args.rate_limit_sleep_max)
                    LOGGER.warning("[alfagift] rate limit %s; sleep %.0fs", exc, pause)
                    await scraper.rotate_context("rate limit")
                    await asyncio.sleep(pause)
                    result = None
                except (BlockedError, CaptchaDetectedError) as exc:
                    LOGGER.warning("[alfagift] blocked/captcha: %s", exc)
                    await scraper.rotate_context("blocked/captcha")
                    result = None
                except Exception as exc:
                    LOGGER.exception("[alfagift] search error for %s: %s", product.input_name, exc)
                    await scraper.rotate_context("search error")
                    result = None

                if result is None:
                    LOGGER.info("[alfagift] not found/skip: %s", product.input_name)
                else:
                    LOGGER.info(
                        "[alfagift] %s: %s -> %s (%s)",
                        result.match_type,
                        product.input_name,
                        result.found_name,
                        result.match_reason,
                    )
                    insert_weekly_price_to_supabase(supabase, product.id_produk, result.price)
                    result_key = result_dedupe_key(result.sku_id, result.found_name, result.unit)
                    if result_key:
                        used_result_keys.add(result_key)
                await asyncio.sleep(random.uniform(args.delay_min, args.delay_max))
        finally:
            await scraper.close()
            await browser.close()
    elapsed = (datetime.now() - run_started_at).total_seconds()
    LOGGER.info("scrape run finished; exit_code=0 elapsed=%.1fs", elapsed)
    return 0


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Scrape harga Alfagift dari Supabase.")
    mode = parser.add_mutually_exclusive_group()
    mode.add_argument("--now", action="store_true", help="Jalankan scraping sekali sekarang juga.")
    mode.add_argument("--daemon", action="store_true", help="Jalankan daemon penjadwalan.")
    parser.add_argument("--headless", dest="headless", action="store_true", default=True)
    parser.add_argument("--no-headless", dest="headless", action="store_false")
    parser.add_argument("--timeout-ms", type=int, default=30000)
    parser.add_argument("--min-score", type=int, default=85)
    parser.add_argument("--delay-min", type=float, default=3.0)
    parser.add_argument("--delay-max", type=float, default=7.0)
    parser.add_argument("--rate-limit-sleep-min", type=float, default=60.0)
    parser.add_argument("--rate-limit-sleep-max", type=float, default=120.0)
    parser.add_argument("--rotate-context-every", type=int, default=25)
    parser.add_argument("--limit", type=int, default=None)
    parser.add_argument("--offset", type=int, default=0)
    parser.add_argument("--log-level", default="INFO", help="Level logging: DEBUG, INFO, WARNING, ERROR, atau CRITICAL.")
    parser.add_argument("--log-file", type=Path, default=None, help="Tulis log tambahan ke file ini.")
    args = parser.parse_args()
    if args.delay_min < 0 or args.delay_max < args.delay_min:
        parser.error("--delay-max harus >= --delay-min dan delay tidak boleh negatif")
    if args.rate_limit_sleep_min < 0 or args.rate_limit_sleep_max < args.rate_limit_sleep_min:
        parser.error("--rate-limit-sleep-max harus >= --rate-limit-sleep-min")
    if args.min_score < 0 or args.min_score > 100:
        parser.error("--min-score harus di antara 0 dan 100")
    args.log_level = args.log_level.upper()
    if not isinstance(getattr(logging, args.log_level, None), int):
        parser.error("--log-level harus DEBUG, INFO, WARNING, ERROR, atau CRITICAL")
    return args


async def aggregate_monthly_prices_job() -> None:
    LOGGER.info("Starting monthly price aggregation...")
    try:
        supabase = get_supabase()
        response = supabase.table("weekly_prices").select("*").execute()
        rows = response.data
        if not rows:
            LOGGER.info("No weekly prices to aggregate.")
            return

        from collections import defaultdict
        product_prices = defaultdict(list)
        for row in rows:
            product_prices[row["product_id"]].append(row["price"])

        for pid, prices in product_prices.items():
            avg_price = sum(prices) / len(prices)
            prod_resp = supabase.table("products").select("base_weight_gram, unit_label").eq("id", pid).execute()
            weight = 1000
            unit_label = None
            if prod_resp.data:
                weight = prod_resp.data[0].get("base_weight_gram") or 1000
                unit_label = prod_resp.data[0].get("unit_label")

            supabase.table("price_history").insert({
                "product_id": pid,
                "price": avg_price,
                "weight_gram": weight,
                "unit_label": unit_label,
            }).execute()

        # Hapus semua baris yang sudah diagregasi setelah berhasil di-insert ke price_history.
        # Menggunakan neq('id', '00000000-...') sebagai workaround karena Supabase
        # tidak mengizinkan DELETE tanpa filter (sebagai proteksi data).
        supabase.table("weekly_prices").delete().neq("id", "00000000-0000-0000-0000-000000000000").execute()
        LOGGER.info("Monthly price aggregation completed for %d products.", len(product_prices))
    except Exception as exc:
        LOGGER.exception("Failed to aggregate monthly prices: %s", exc)


async def setup_scheduler(args: argparse.Namespace) -> None:
    scheduler = AsyncIOScheduler()

    def schedule_weekend_jobs():
        # Clear existing scrape jobs
        for job in scheduler.get_jobs():
            if job.id and job.id.startswith("scrape_"):
                job.remove()

        days = random.sample([4, 5, 6], 2)
        for day in days:
            hour = random.randint(0, 4)
            minute = random.randint(0, 59)
            day_of_week = ["fri", "sat", "sun"][day - 4]
            scheduler.add_job(
                run,
                CronTrigger(day_of_week=day_of_week, hour=hour, minute=minute),
                args=[args],
                id=f"scrape_{day_of_week}",
                replace_existing=True
            )
            LOGGER.info("Scheduled scrape for %s at %02d:%02d", day_of_week, hour, minute)

    # Initial scheduling
    schedule_weekend_jobs()

    # Reschedule every Monday at 00:00
    scheduler.add_job(schedule_weekend_jobs, CronTrigger(day_of_week="mon", hour=0, minute=0), id="planner")

    # Agregasi bulanan: rata-rata weekly_prices → price_history
    # Dijadwalkan tanggal 28 (bukan EOM) untuk menghindari konflik dengan
    # variasi jumlah hari per bulan (28, 29, 30, 31)
    scheduler.add_job(aggregate_monthly_prices_job, CronTrigger(day="28", hour=23, minute=50), id="monthly_aggregator")

    scheduler.start()
    LOGGER.info("Scheduler started. Press Ctrl+C to exit.")
    
    try:
        while True:
            await asyncio.sleep(3600)
    except asyncio.CancelledError:
        LOGGER.info("Scheduler stopped.")


async def async_main(args: argparse.Namespace) -> int:
    if args.daemon:
        await setup_scheduler(args)
        return 0
    return await run(args, run_at=datetime.now())


def main() -> int:
    args = parse_args()
    configure_logging(args)
    try:
        return asyncio.run(async_main(args))
    except KeyboardInterrupt:
        LOGGER.info("Dihentikan oleh user.")
        return 130
    except Exception as exc:
        LOGGER.exception("fatal: %s", exc)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())

