from __future__ import annotations

import ctypes
import logging
import os

# ─── Load Shared Library ───────────────────────────────────────────────────────
_base_path = os.path.dirname(__file__)
_lib_path  = os.path.join(_base_path, "worthit_engine.so")

try:
    _lib = ctypes.CDLL(_lib_path)

    # float calculate_wma(float* prices, float* weights, int count)
    _lib.calculate_wma.argtypes = [
        ctypes.POINTER(ctypes.c_float),
        ctypes.POINTER(ctypes.c_float),
        ctypes.c_int,
    ]
    _lib.calculate_wma.restype = ctypes.c_float

    # float calculate_support(float* prices, int count)
    _lib.calculate_support.argtypes = [
        ctypes.POINTER(ctypes.c_float),
        ctypes.c_int,
    ]
    _lib.calculate_support.restype = ctypes.c_float

    # float calculate_resistance(float* prices, int count)
    _lib.calculate_resistance.argtypes = [
        ctypes.POINTER(ctypes.c_float),
        ctypes.c_int,
    ]
    _lib.calculate_resistance.restype = ctypes.c_float

    # float calculate_sr_position(float current, float support, float resistance)
    _lib.calculate_sr_position.argtypes = [
        ctypes.c_float,
        ctypes.c_float,
        ctypes.c_float,
    ]
    _lib.calculate_sr_position.restype = ctypes.c_float

    # PriceRecord struct
    class PriceRecord(ctypes.Structure):
        _fields_ = [
            ("product_id", ctypes.c_char * 64),
            ("price", ctypes.c_float),
            ("weight_gram", ctypes.c_float),
            ("timestamp", ctypes.c_long),
        ]

    # int binary_search_price(PriceRecord* records, int n, const char* product_id, long target_ts)
    _lib.binary_search_price.argtypes = [
        ctypes.POINTER(PriceRecord),
        ctypes.c_int,
        ctypes.c_char_p,
        ctypes.c_long,
    ]
    _lib.binary_search_price.restype = ctypes.c_int

    # int sequential_search_fuzzy(const char* name, const char* query)
    _lib.sequential_search_fuzzy.argtypes = [
        ctypes.c_char_p,
        ctypes.c_char_p,
    ]
    _lib.sequential_search_fuzzy.restype = ctypes.c_int

    _lib_loaded = True
    logging.info("[C Engine] Shared library loaded from: %s", _lib_path)

except OSError as e:
    _lib_loaded = False
    logging.warning("[C Engine] Gagal load .so — fallback ke Python murni. (%s)", e)


# ─── Public Python Wrappers ────────────────────────────────────────────────────

def compute_wma(prices: list[float], weights: list[float]) -> float:
    """
    Hitung Weighted Moving Average.
    prices  : list harga per-bulan, TERLAMA → TERBARU
    weights : list bobot sesuai urutan prices
    """
    if not prices:
        return 0.0

    if _lib_loaded:
        n = len(prices)
        c_prices  = (ctypes.c_float * n)(*prices)
        c_weights = (ctypes.c_float * n)(*weights)
        return float(_lib.calculate_wma(c_prices, c_weights, ctypes.c_int(n)))

    # Fallback Python
    total_w = sum(weights)
    if total_w == 0:
        return 0.0
    return sum(p * w for p, w in zip(prices, weights)) / total_w


def compute_support(prices: list[float]) -> float:
    """Hitung Support Level (harga terendah dalam periode)."""
    if not prices:
        return 0.0

    if _lib_loaded:
        n = len(prices)
        c_prices = (ctypes.c_float * n)(*prices)
        return float(_lib.calculate_support(c_prices, ctypes.c_int(n)))

    return min(prices)


def compute_resistance(prices: list[float]) -> float:
    """Hitung Resistance Level (harga tertinggi dalam periode)."""
    if not prices:
        return 0.0

    if _lib_loaded:
        n = len(prices)
        c_prices = (ctypes.c_float * n)(*prices)
        return float(_lib.calculate_resistance(c_prices, ctypes.c_int(n)))

    return max(prices)


def compute_sr_position(current: float, support: float, resistance: float) -> float:
    """
    Hitung posisi harga relatif terhadap Support/Resistance.
    Return: 0.0 (di support) → 100.0 (di resistance)
    """
    if _lib_loaded:
        return float(_lib.calculate_sr_position(
            ctypes.c_float(current),
            ctypes.c_float(support),
            ctypes.c_float(resistance),
        ))

    # Fallback Python
    if resistance == support:
        return 50.0
    pos = (current - support) / (resistance - support) * 100.0
    return max(0.0, min(100.0, pos))


def search_price_record(records: list[dict], product_id: str, target_ts: int) -> int:
    """
    Binary search pada list records.
    records: list of dict {price, weight_gram, timestamp, product_id}
    Records must be sorted by product_id then timestamp.
    """
    if not records:
        return -1

    if _lib_loaded:
        n = len(records)
        c_records = (PriceRecord * n)()
        for i, r in enumerate(records):
            c_records[i].product_id = r["product_id"].encode("utf-8")
            c_records[i].price = float(r["price"])
            c_records[i].weight_gram = float(r["weight_gram"])
            c_records[i].timestamp = int(r["timestamp"])
        
        return int(_lib.binary_search_price(
            c_records,
            ctypes.c_int(n),
            product_id.encode("utf-8"),
            ctypes.c_long(target_ts),
        ))

    # Fallback Python (Binary Search)
    import bisect
    keys = [(r["product_id"], r["timestamp"]) for r in records]
    idx = bisect.bisect_left(keys, (product_id, target_ts))
    if idx < len(keys) and keys[idx] == (product_id, target_ts):
        return idx
    return -1


def fuzzy_match(name: str, query: str) -> bool:
    """Fuzzy match nama produk."""
    if _lib_loaded:
        return bool(_lib.sequential_search_fuzzy(
            name.encode("utf-8"),
            query.encode("utf-8")
        ))
    
    return query.lower() in name.lower()
