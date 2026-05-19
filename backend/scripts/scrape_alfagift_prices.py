#!/usr/bin/env python3
from __future__ import annotations

import argparse
import asyncio
import random
import re
import sys
import unicodedata
from dataclasses import dataclass
from pathlib import Path
from typing import Any, Callable
from urllib.parse import quote

import pandas as pd


PROJECT_ROOT = Path(__file__).resolve().parents[1]
DEFAULT_INPUT = PROJECT_ROOT / "data/500_barang_tambahan_indonesia.md"
DEFAULT_OUTPUT = PROJECT_ROOT / "data/alfagift_final_500.csv"
ALFAGIFT_BASE_URL = "https://alfagift.id"
ALFAGIFT_SEARCH_API_TOKEN = "webcommerce-gw.alfagift.id/v2/products/searches"
CSV_COLUMNS = [
    "input_name", "source", "found_name", "price", "unit",
    "fuzzy_score", "sku_id", "match_type", "match_reason",
]
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

    def row(self) -> dict[str, Any]:
        return {
            "input_name": self.input_name,
            "source": self.source,
            "found_name": self.found_name,
            "price": format_price(self.price),
            "unit": self.unit,
            "fuzzy_score": self.fuzzy_score,
            "sku_id": self.sku_id,
            "match_type": self.match_type,
            "match_reason": self.match_reason,
        }

    def stdout_line(self) -> str:
        return " | ".join(str(self.row()[column]) for column in CSV_COLUMNS)


@dataclass(frozen=True)
class OutputState:
    input_keys: set[str]
    result_keys: set[str]


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


def parse_markdown_products(path: Path) -> list[InputProduct]:
    products = []
    for line in path.read_text(encoding="utf-8").splitlines():
        if not line.startswith("| ") or ":---" in line or "Kategori" in line:
            continue
        cells = [cell.strip() for cell in line.strip().strip("|").split("|")]
        if len(cells) == 4:
            category, name, brand, unit = cells
        elif len(cells) == 5:
            category, name, brand, unit, _estimated_price = cells
        else:
            continue
        if category and name:
            products.append(InputProduct(category=category, name=name, brand=brand, unit=unit))
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
        sys.stderr.write(f"[alfagift] rotate context: {reason}\n")

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
                    sys.stderr.write(f"[alfagift] candidate already used: {candidate.found_name}\n")
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


class PandasAppendWriter:
    def __init__(
        self,
        path: Path,
        input_keys: set[str] | None = None,
        result_keys: set[str] | None = None,
    ) -> None:
        self.path = path
        self.input_keys = input_keys or set()
        self.result_keys = result_keys or set()

    def write(self, result: ScrapeResult) -> bool:
        input_key = dedupe_key(result.input_name)
        if input_key in self.input_keys:
            sys.stderr.write(f"[output] duplicate input blocked: {result.input_name}\n")
            return False
        result_key = result_dedupe_key(result.sku_id, result.found_name, result.unit)
        if result_key and result_key in self.result_keys:
            sys.stderr.write(f"[output] duplicate result blocked: {result.found_name}\n")
            return False
        self.path.parent.mkdir(parents=True, exist_ok=True)
        header = not self.path.exists() or self.path.stat().st_size == 0
        pd.DataFrame([result.row()], columns=CSV_COLUMNS).to_csv(self.path, mode="a", header=header, index=False)
        self.input_keys.add(input_key)
        if result_key:
            self.result_keys.add(result_key)
        return True


def format_price(value: int | float) -> str:
    if isinstance(value, float) and not value.is_integer():
        return f"{value:.2f}".rstrip("0").rstrip(".")
    return str(int(value))


def dedupe_key(value: Any) -> str:
    return normalize_text(value)


def result_dedupe_key(sku_id: Any, found_name: Any, unit: Any) -> str:
    sku_key = dedupe_key(sku_id)
    if sku_key:
        return f"sku:{sku_key}"
    fallback = dedupe_key(f"{found_name} {unit}")
    return f"name:{fallback}" if fallback else ""


def row_result_dedupe_key(row: Any) -> str:
    return result_dedupe_key(row.get("sku_id", ""), row.get("found_name", ""), row.get("unit", ""))


def prepare_output_file(path: Path) -> OutputState:
    if not path.exists() or path.stat().st_size == 0:
        return OutputState(input_keys=set(), result_keys=set())
    try:
        df = pd.read_csv(path, dtype=str).fillna("")
    except pd.errors.EmptyDataError:
        return OutputState(input_keys=set(), result_keys=set())

    scraped_input_names = set()
    if "input_name" in df.columns:
        scraped_input_names = {
            dedupe_key(value)
            for value in df["input_name"].unique()
            if dedupe_key(value)
        }

    needs_migration = "image_url" in df.columns or list(df.columns) != CSV_COLUMNS
    duplicate_count = 0
    if "input_name" in df.columns:
        before_count = len(df)
        for column in CSV_COLUMNS:
            if column not in df.columns:
                df[column] = ""
        df["_input_dedupe_key"] = df["input_name"].map(dedupe_key)
        df["_result_dedupe_key"] = df.apply(row_result_dedupe_key, axis=1)
        df = df[df["_input_dedupe_key"] != ""]
        df = df.drop_duplicates(subset="_input_dedupe_key", keep="first")
        df = df.drop_duplicates(subset="_result_dedupe_key", keep="first")
        df = df.drop(columns=["_input_dedupe_key", "_result_dedupe_key"])
        duplicate_count = before_count - len(df)
    if needs_migration or duplicate_count:
        for column in CSV_COLUMNS:
            if column not in df.columns:
                df[column] = ""
        df = df[CSV_COLUMNS]
        path.parent.mkdir(parents=True, exist_ok=True)
        df.to_csv(path, index=False)
        if needs_migration:
            sys.stderr.write(f"[output] migrated CSV schema: {path}\n")
        if duplicate_count:
            sys.stderr.write(f"[output] removed duplicate rows: {duplicate_count}\n")

    if "input_name" in df.columns:
        input_keys = {dedupe_key(value) for value in df["input_name"].unique() if dedupe_key(value)}
        result_keys = {
            row_result_dedupe_key(row)
            for _, row in df.iterrows()
            if row_result_dedupe_key(row)
        }
        return OutputState(input_keys=input_keys, result_keys=result_keys)
    return OutputState(input_keys=scraped_input_names, result_keys=set())


async def run(args: argparse.Namespace) -> int:
    try:
        from playwright.async_api import async_playwright
    except ImportError as exc:
        raise RuntimeError("Dependency playwright belum terpasang. Jalankan: pip install playwright") from exc

    products = parse_markdown_products(args.input)
    if args.offset:
        products = products[args.offset :]
    if args.limit is not None:
        products = products[: args.limit]
    if not products:
        sys.stderr.write("Tidak ada produk yang bisa dibaca dari file input.\n")
        return 1

    output_state = prepare_output_file(args.output_file)
    scraped_input_names = output_state.input_keys
    used_result_keys = output_state.result_keys
    writer = PandasAppendWriter(args.output_file, scraped_input_names, used_result_keys)
    pending_products = []
    for index, product in enumerate(products, start=1 + args.offset):
        product_key = dedupe_key(product.input_name)
        if product_key in scraped_input_names:
            sys.stderr.write(f"[{index}] skip existing: {product.input_name}\n")
        else:
            pending_products.append((index, product))
    if not pending_products:
        sys.stderr.write("Semua produk sudah ada di output CSV.\n")
        return 0

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
                product_key = dedupe_key(product.input_name)
                if product_key in scraped_input_names:
                    sys.stderr.write(f"[{index}] skip existing: {product.input_name}\n")
                    continue
                sys.stderr.write(f"[{index}] search: {product.input_name} ({product.unit})\n")
                sys.stderr.flush()
                try:
                    result = await scraper.search(product, used_result_keys)
                except RateLimitedError as exc:
                    pause = random.uniform(args.rate_limit_sleep_min, args.rate_limit_sleep_max)
                    sys.stderr.write(f"\a[alfagift] rate limit {exc}; sleep {pause:.0f}s\n")
                    await scraper.rotate_context("rate limit")
                    await asyncio.sleep(pause)
                    result = None
                except (BlockedError, CaptchaDetectedError) as exc:
                    sys.stderr.write(f"\a[alfagift] blocked/captcha: {exc}\n")
                    await scraper.rotate_context("blocked/captcha")
                    result = None

                if result is None:
                    sys.stderr.write(f"[alfagift] not found/skip: {product.input_name}\n")
                    sys.stderr.flush()
                else:
                    sys.stderr.write(
                        f"[alfagift] {result.match_type}: {product.input_name} -> "
                        f"{result.found_name} ({result.match_reason})\n"
                    )
                    if writer.write(result):
                        print(result.stdout_line(), flush=True)
                        scraped_input_names.add(product_key)
                        result_key = result_dedupe_key(result.sku_id, result.found_name, result.unit)
                        if result_key:
                            used_result_keys.add(result_key)
                await asyncio.sleep(random.uniform(args.delay_min, args.delay_max))
        finally:
            await scraper.close()
            await browser.close()
    return 0


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Scrape harga Alfagift dari daftar barang Markdown.")
    parser.add_argument("--input", type=Path, default=DEFAULT_INPUT)
    parser.add_argument("--output-file", type=Path, default=DEFAULT_OUTPUT)
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
    parser.add_argument("--self-test", action="store_true")
    args = parser.parse_args()
    if args.delay_min < 0 or args.delay_max < args.delay_min:
        parser.error("--delay-max harus >= --delay-min dan delay tidak boleh negatif")
    if args.rate_limit_sleep_min < 0 or args.rate_limit_sleep_max < args.rate_limit_sleep_min:
        parser.error("--rate-limit-sleep-max harus >= --rate-limit-sleep-min")
    if args.min_score < 0 or args.min_score > 100:
        parser.error("--min-score harus di antara 0 dan 100")
    return args


def self_test() -> None:
    parsed = parse_markdown_products(DEFAULT_INPUT)
    assert len(parsed) == 500
    assert len({product.input_name for product in parsed}) == 500
    assert len(parsed[0].input_name.split()) > len(parsed[0].name.split())
    legacy_input = Path("/private/tmp/legacy_products_self_test.md")
    legacy_input.write_text(
        "\n".join(
            [
                "| Kategori | Nama Barang | Merek | Ukuran | Harga Estimasi (Rp) |",
                "|:--|:--|:--|:--|--:|",
                "| Test | Produk Lama | Merek Lama | 1 kg | 10000 |",
            ]
        ),
        encoding="utf-8",
    )
    legacy_products = parse_markdown_products(legacy_input)
    assert len(legacy_products) == 1
    assert legacy_products[0].input_name == "Merek Lama Produk Lama 1 kg"
    assert normalize_text("Indomie 90g!!") == "indomie 90 g"
    beras = InputProduct("Sembako", "Beras Ramos", "Cap", "5 kg")
    assert build_strict_queries(beras) == ["Beras Ramos 5 kg"]
    assert build_alternative_queries(beras) == ["Beras Ramos 5 kg", "Beras Ramos", "ramos 5 kg", "sembako 5 kg"]
    beras_verbose = InputProduct("Sembako", "Beras Ramos Wangi Enak", "Cap", "5kg")
    assert smart_query(beras_verbose) == "ramos 5 kg"

    payload = {
        "productName": "INDOMIE GORENG SPECIAL 85G",
        "sku": "123",
        "discount_percentage": 90,
        "minimum_quantity": 2,
        "finalPrice": "Rp 3.200",
    }
    assert extract_price(payload) == 3200
    assert extract_price({"discount_percentage": 50, "minimum_quantity": 2}) is None
    assert not valid_price(0)
    assert not valid_price(500)
    assert not valid_price(1_000_000)
    assert valid_price(3200)
    assert extract_display_unit("Filma Minyak Goreng 2 L") == "2 L"
    assert extract_display_unit("Aqua Air Mineral 1.5 L") == "1.5 L"
    assert extract_display_unit("Hand Soap 1,5 L") == "1,5 L"
    assert extract_display_unit("INDOMIE GORENG SPECIAL 85G") == "85 g"

    product = InputProduct("Sembako", "Mie Instan", "Indomie Goreng", "85 g")
    candidate_score = score_product(product, "Indomie Goreng Mie Instan Special 85g", "Indomie Goreng Mie Instan Special 85g", 85)
    assert candidate_score is not None and candidate_score >= 70
    assert score_product(beras, "Beras Ramos Premium 5kg", "Beras Ramos Premium 5kg", 85) is not None
    assert score_product(beras, "Beras Ramos Premium 10kg", "Beras Ramos Premium 10kg", 85) is None
    assert score_product(
        InputProduct("Minuman", "Air Mineral", "Aqua", "1.5 L"),
        "Aqua Air Mineral 1.5 L",
        "Aqua Air Mineral 1.5 L",
        85,
    ) is not None
    assert score_product(
        InputProduct("Minuman", "Air Mineral", "Aqua", "1.5 L"),
        "Aqua Air Mineral 5 L",
        "Aqua Air Mineral 5 L",
        85,
    ) is None

    scraper = AlfagiftScraper(browser=None, headless=True, timeout_ms=1000, min_score=85, rotate_context_every=25)
    strict_product = InputProduct("Minuman Tambahan", "Air Mineral", "Le Minerale", "600 ml")
    strict_candidate = scraper.build_candidate(
        strict_product,
        {"productName": "Le Minerale Air Mineral 600ML", "sku": "LM600", "finalPrice": 4500},
        "exact",
    )
    assert strict_candidate is not None
    assert strict_candidate.match_type == "exact"
    assert scraper.build_candidate(
        strict_product,
        {"productName": "Cleo Air Mineral 600ML", "sku": "CL600", "finalPrice": 4000},
        "exact",
    ) is None
    assert scraper.build_candidate(
        strict_product,
        {"productName": "Le Minerale Air Mineral 1.5L", "sku": "LM1500", "finalPrice": 7500},
        "exact",
    ) is None
    alternative_candidate = scraper.build_candidate(
        strict_product,
        {"productName": "Cleo Air Mineral 1.5L", "sku": "CL1500", "finalPrice": 7000},
        "alternative",
    )
    assert alternative_candidate is not None
    assert alternative_candidate.match_type == "alternative"
    assert "brand differs" in alternative_candidate.match_reason
    assert scraper.build_candidate(
        strict_product,
        {"productName": "Baterai AA Alkaline 2PCS", "sku": "BATT2", "finalPrice": 18000},
        "alternative",
    ) is None
    assert scraper.build_candidate(
        strict_product,
        {"productName": "Le Minerale Air Mineral 600ML", "finalPrice": 4500},
        "exact",
    ) is None
    unavailable_exact = scraper.build_candidate(
        strict_product,
        {"productName": "Le Minerale Air Mineral 600ML", "sku": "LM600", "finalPrice": 4500, "stock": False},
        "exact",
    )
    assert unavailable_exact is not None
    unavailable_alternative = scraper.build_candidate(
        strict_product,
        {
            "productName": "Cleo Air Mineral 1.5L",
            "sku": "CL1500",
            "finalPrice": 7000,
            "status": "Produk Tidak Tersedia",
        },
        "alternative",
    )
    assert unavailable_alternative is not None
    assert unavailable_alternative.match_type == "alternative"
    assert scraper.build_candidate(
        strict_product,
        {"productName": "Le Minerale Air Mineral 600ML", "sku": "LM600"},
        "exact",
    ) is None
    assert scraper.build_candidate(
        strict_product,
        {"sku": "LM600", "finalPrice": 4500},
        "exact",
    ) is None

    payloads = [
        [
            {"productName": "Cleo Air Mineral 1.5L", "sku": "CL1500", "finalPrice": 7000},
            {"productName": "Club Air Mineral 1.5L", "sku": "CLUB1500", "finalPrice": 6500},
        ]
    ]
    used_candidates = {result_dedupe_key("CL1500", "Cleo Air Mineral 1.5L", "1.5 L")}
    next_candidate = scraper.choose_best_candidate(
        strict_product,
        payloads,
        match_type="alternative",
        used_result_keys=used_candidates,
    )
    assert next_candidate is not None
    assert next_candidate.sku_id == "CLUB1500"
    assert scraper.choose_best_candidate(
        strict_product,
        payloads,
        match_type="alternative",
        used_result_keys={
            result_dedupe_key("CL1500", "Cleo Air Mineral 1.5L", "1.5 L"),
            result_dedupe_key("CLUB1500", "Club Air Mineral 1.5L", "1.5 L"),
        },
    ) is None

    out = Path("/private/tmp/price_comparison_self_test.csv")
    if out.exists():
        out.unlink()
    writer = PandasAppendWriter(out)
    assert writer.write(ScrapeResult("A", "alfagift", "B", 1000, "1 kg", 90, "SKU1", "exact", "brand and size match"))
    assert not writer.write(ScrapeResult(" A ", "alfagift", "B2", 1100, "1 kg", 91, "SKU2", "exact", "duplicate"))
    assert not writer.write(ScrapeResult("C", "alfagift", "B", 1000, "1 kg", 90, "SKU1", "alternative", "duplicate result"))
    assert writer.write(ScrapeResult("C", "alfagift", "D", 2000, "2 kg", 80, "SKU3", "alternative", "keyword overlap"))
    df = pd.read_csv(out)
    assert list(df.columns) == CSV_COLUMNS
    assert len(df) == 2

    missing_out = Path("/private/tmp/price_comparison_missing_self_test.csv")
    if missing_out.exists():
        missing_out.unlink()
    missing_state = prepare_output_file(missing_out)
    assert missing_state.input_keys == set()
    assert missing_state.result_keys == set()

    old_out = Path("/private/tmp/price_comparison_old_schema_self_test.csv")
    pd.DataFrame(
        [
            {
                "input_name": "A",
                "source": "alfagift",
                "found_name": "B",
                "price": "1000",
                "unit": "1 kg",
                "image_url": "https://x/y.jpg",
                "fuzzy_score": "90",
                "sku_id": "SKU1",
            },
            {
                "input_name": " a ",
                "source": "alfagift",
                "found_name": "B Duplicate",
                "price": "1100",
                "unit": "1 kg",
                "image_url": "https://x/y2.jpg",
                "fuzzy_score": "91",
                "sku_id": "SKU2",
            },
            {
                "input_name": "C",
                "source": "alfagift",
                "found_name": "B Same Result",
                "price": "1200",
                "unit": "1 kg",
                "image_url": "https://x/y3.jpg",
                "fuzzy_score": "92",
                "sku_id": "SKU1",
            },
        ]
    ).to_csv(old_out, index=False)
    old_state = prepare_output_file(old_out)
    assert old_state.input_keys == {"a"}
    assert old_state.result_keys == {"sku:sku1"}
    migrated = pd.read_csv(old_out, keep_default_na=False)
    assert list(migrated.columns) == CSV_COLUMNS
    assert "image_url" not in migrated.columns
    assert len(migrated) == 1
    assert migrated.loc[0, "match_type"] == ""
    assert migrated.loc[0, "match_reason"] == ""
    sys.stderr.write("self-test ok\n")


def main() -> int:
    args = parse_args()
    if args.self_test:
        self_test()
        return 0
    try:
        return asyncio.run(run(args))
    except KeyboardInterrupt:
        sys.stderr.write("Dihentikan oleh user.\n")
        return 130
    except Exception as exc:
        sys.stderr.write(f"fatal: {exc}\n")
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
