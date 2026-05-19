from __future__ import annotations

"""
engine/scoring.py — WorthIt Price Scoring Engine (Python Layer)

Mengimplementasikan pipeline skoring multi-komponen yang mengevaluasi apakah
harga sebuah produk layak dibeli berdasarkan data historis harga bulanan.

Pipeline Skoring (total maksimum 100 poin):
┌─────────────────────────────────────────────────────────────────────────┐
│ Komponen              │ Bobot (poin) │ Sumber Data                     │
├─────────────────────────────────────────────────────────────────────────┤
│ WMA Score             │ 0 – 60       │ Deviasi harga vs WMA historis    │
│ S/R Position Score    │ 0 – 25       │ Posisi dalam kisaran S/R         │
│ Urgency Score         │ 0 – 15       │ Input user (urgensi pembelian)   │
│ Anomaly Penalty (PRO) │ -5 – -25     │ Deteksi harga abnormal / shrink  │
└─────────────────────────────────────────────────────────────────────────┘

Keputusan akhir:
  - WorthIt  (≥75 poin) — harga di bawah atau wajar terhadap normal price
  - Waspada  (50–74 poin) — harga sedikit di atas normal, perlu pertimbangan
  - Mahal    (<50 poin)  — harga signifikan di atas normal, hindari beli

Komputasi berat (WMA, S/R) didelegasikan ke C-Engine via ctypes bridge
(engine/c_bridge.py) untuk efisiensi runtime pada skala data produksi.
"""

from math import sqrt

from engine.c_bridge import (
    compute_resistance,
    compute_sr_position,
    compute_support,
    compute_wma,
)

# Batas maksimum data historis yang dipertimbangkan (6 bulan terakhir).
# Membatasi look-back window mencegah data lama yang tidak relevan
# memengaruhi WMA — harga 2 tahun lalu tidak representatif untuk pasar kini.
MAX_HISTORY_MONTHS = 6

# Fitur analitik yang dikunci untuk pengguna Free tier.
# Fitur ini tetap dihitung secara internal namun tidak dikembalikan ke client.
FREE_LOCKED_FEATURES = ["shrinkflation_detection", "price_anomaly_detection"]


# ─── Utility Helpers ──────────────────────────────────────────────────────────

def _round(value: float, digits: int = 2) -> float:
    """Konversi nilai ke float dan bulatkan ke `digits` desimal."""
    return round(float(value or 0), digits)


def _pct_change(current: float, reference: float) -> float:
    """
    Hitung persentase perubahan (current − reference) / reference × 100.

    Mengembalikan 0.0 jika reference ≤ 0 untuk menghindari pembagian nol
    pada produk baru yang belum memiliki harga referensi valid.
    """
    if reference <= 0:
        return 0.0
    return (current - reference) / reference * 100


def _volatility_percent(prices: list[float], normal_price: float) -> float:
    """
    Hitung volatilitas harga historis sebagai persentase dari normal price.

    Menggunakan Population Standard Deviation (σ) — bukan sample std dev —
    karena kita bekerja dengan seluruh data historis yang tersedia, bukan
    sampel dari populasi yang lebih besar.

    Formula: σ / normal_price × 100

    Kompleksitas Waktu: O(n) — dua pass linear (mean, lalu variance)
    Kompleksitas Ruang: O(1)

    Returns 0.0 jika kurang dari 2 data poin atau normal_price ≤ 0.
    """
    if len(prices) < 2 or normal_price <= 0:
        return 0.0

    mean = sum(prices) / len(prices)
    variance = sum((p - mean) ** 2 for p in prices) / len(prices)
    return sqrt(variance) / normal_price * 100


# ─── Scoring Components ───────────────────────────────────────────────────────

def compute_wma_score(price_delta_percent: float) -> int:
    """
    Hitung komponen WMA Score (0–60 poin) berdasarkan deviasi harga scan
    terhadap normal price (WMA historis 6 bulan terakhir).

    Tabel mapping deviasi → skor:
      ≤ -10%  → 60 poin  (harga sangat murah, beli sekarang)
      ≤  -5%  → 56 poin  (harga di bawah normal)
      ≤  +5%  → 52 poin  (harga wajar, dalam toleransi)
      ≤ +10%  → 42 poin  (sedikit di atas normal)
      ≤ +15%  → 34 poin  (cukup mahal)
      ≤ +25%  → 20 poin  (mahal)
      > +25%  →  8 poin  (sangat mahal, kemungkinan anomali)

    Bobot 60% dari total skor menjadikan komponen ini sebagai sinyal utama.
    """
    if price_delta_percent <= -10: return 60
    if price_delta_percent <=  -5: return 56
    if price_delta_percent <=   5: return 52
    if price_delta_percent <=  10: return 42
    if price_delta_percent <=  15: return 34
    if price_delta_percent <=  25: return 20
    return 8


def compute_sr_score(sr_position: float) -> int:
    """
    Hitung komponen S/R Score (0–25 poin) berdasarkan posisi harga
    relatif terhadap Support dan Resistance level historis.

    sr_position = 0%   → harga tepat di Support (paling murah secara historis)
    sr_position = 100% → harga tepat di Resistance (paling mahal secara historis)

    Tabel mapping posisi S/R → skor:
      ≤ 15%  → 25 poin  (mendekati support, kesempatan beli)
      ≤ 35%  → 22 poin  (di bawah midpoint, harga relatif baik)
      ≤ 60%  → 17 poin  (di midpoint, harga normal)
      ≤ 80%  → 10 poin  (mendekati resistance, harga tinggi)
      > 80%  →  3 poin  (di zona resistance, harga puncak)
    """
    if sr_position <= 15: return 25
    if sr_position <= 35: return 22
    if sr_position <= 60: return 17
    if sr_position <= 80: return 10
    return 3


def compute_urgency_score(urgency: int, price_delta_percent: float) -> int:
    """
    Hitung komponen Urgency Score (0–15 poin) berdasarkan urgensi pembelian
    yang diinput pengguna.

    Urgency Level:
      1 = Tidak mendesak (bisa ditunda)
      2 = Biasa saja
      3 = Sangat mendesak (perlu beli hari ini)

    Proteksi: jika harga sudah sangat mahal (delta > 25%), urgency score
    dibatasi maksimum 3 poin sehingga urgensi tidak "menyelamatkan" skor
    produk yang secara objektif tidak WorthIt.
    """
    base_score = {1: 3, 2: 8, 3: 15}.get(urgency, 8)
    if price_delta_percent > 25: return min(base_score, 3)
    if price_delta_percent > 15: return min(base_score, 6)
    return base_score


def get_decision(score: int) -> tuple[str, str]:
    """
    Tentukan keputusan akhir dan warna UI berdasarkan total skor.

    Returns tuple (decision_label, ui_color):
      ≥ 75 → ("WorthIt", "green")  — layak dibeli
      ≥ 50 → ("Waspada", "yellow") — pertimbangkan ulang
      < 50 → ("Mahal",   "red")    — hindari
    """
    if score >= 75: return "WorthIt", "green"
    if score >= 50: return "Waspada", "yellow"
    return "Mahal", "red"


# ─── PRO Feature: Price Anomaly Detection ─────────────────────────────────────

def detect_price_anomaly(
    scanned_price: float,
    normal_price: float,
    volatility_percent: float,
    price_delta_percent: float,
) -> dict:
    """
    Deteksi apakah harga scan melampaui batas kewajaran historis (PRO tier).

    Toleransi batas atas dihitung secara adaptif berdasarkan volatilitas produk:
      - Produk stabil (volatilitas rendah): toleransi minimum 8%
      - Produk volatil (volatilitas tinggi): toleransi maksimum 20%

    Formula toleransi: max(8%, min(20%, 5% + volatility × 1.5))

    Anomali terkonfirmasi hanya jika DUA kondisi terpenuhi sekaligus:
      1. scanned_price > fair_upper_bound  (melampaui batas kewajaran)
      2. price_delta_percent > 12%         (deviasi signifikan dari WMA)

    Penalti skor dihitung proporsional terhadap seberapa jauh harga melampaui
    batas kewajaran (overshoot), di-clamp pada rentang [5, 15] poin.

    Returns:
        dict dengan keys: detected, fair_upper_bound, penalty, tolerance_percent
    """
    if normal_price <= 0:
        return {"detected": False, "fair_upper_bound": 0.0, "penalty": 0, "tolerance_percent": 0.0}

    tolerance_percent = max(8.0, min(20.0, 5.0 + volatility_percent * 1.5))
    fair_upper_bound = normal_price * (1 + tolerance_percent / 100)
    detected = scanned_price > fair_upper_bound and price_delta_percent > 12

    penalty = 0
    if detected:
        overshoot_percent = _pct_change(scanned_price, fair_upper_bound)
        penalty = max(5, min(15, int(round(overshoot_percent * 1.4))))

    return {
        "detected": detected,
        "fair_upper_bound": fair_upper_bound,
        "penalty": penalty,
        "tolerance_percent": tolerance_percent,
    }


# ─── PRO Feature: Shrinkflation Detection ─────────────────────────────────────

def detect_shrinkflation(
    current_weight: float,
    reference_weight: float,
    scanned_price: float,
    normal_price: float,
) -> dict:
    """
    Deteksi shrinkflation — penurunan berat produk dengan harga per unit lebih mahal
    dibanding referensi historis (PRO tier).

    Shrinkflation adalah praktik produsen mengurangi isi/berat produk tanpa
    menurunkan harga, sehingga secara efektif menaikkan harga per satuan berat.

    Deteksi terkonfirmasi jika DUA kondisi terpenuhi sekaligus:
      1. weight_delta_percent < -3%        (berat berkurang > 3%)
      2. unit_price_delta_percent > 3%     (harga per gram naik > 3%)

    Penalti dihitung dari severity gabungan:
      severity = |weight_delta| × 0.6 + unit_price_delta × 0.25
    di-clamp pada rentang [3, 10] poin.

    Returns:
        dict dengan keys: detected, weight_delta_percent,
                          unit_price_delta_percent, penalty
    """
    if current_weight <= 0 or reference_weight <= 0 or normal_price <= 0:
        return {"detected": False, "weight_delta_percent": 0.0, "unit_price_delta_percent": 0.0, "penalty": 0}

    weight_delta_percent = _pct_change(current_weight, reference_weight)

    # Harga per gram: scanned_price/current_weight vs normal_price/reference_weight
    current_unit_price = scanned_price / current_weight
    normal_unit_price = normal_price / reference_weight
    unit_price_delta_percent = _pct_change(current_unit_price, normal_unit_price)

    detected = weight_delta_percent < -3 and unit_price_delta_percent > 3
    penalty = 0
    if detected:
        severity = abs(weight_delta_percent) * 0.6 + unit_price_delta_percent * 0.25
        penalty = max(3, min(10, int(round(severity))))

    return {
        "detected": detected,
        "weight_delta_percent": weight_delta_percent,
        "unit_price_delta_percent": unit_price_delta_percent,
        "penalty": penalty,
    }


# ─── Main Analysis Pipeline ───────────────────────────────────────────────────

def run_analysis(
    scanned_price: float,
    current_weight: float,
    urgency: int,
    monthly_buckets: list[dict],
    user_tier: str,
) -> dict:
    """
    Jalankan pipeline analisis harga WorthIt secara lengkap.

    Fungsi ini mengorkestrasikan seluruh komponen scoring — dari normalisasi data
    historis, kalkulasi WMA via C-Engine, hingga deteksi anomali dan shrinkflation —
    menjadi satu keputusan terstruktur yang dikembalikan ke API layer.

    Args:
        scanned_price    : Harga produk yang di-scan pengguna (IDR)
        current_weight   : Berat produk yang di-scan (gram)
        urgency          : Urgensi pembelian user (1=rendah, 2=sedang, 3=tinggi)
        monthly_buckets  : List data bulanan [{month_offset, avg_price, avg_weight}],
                           urutan TERLAMA → TERBARU (max 6 entri digunakan)
        user_tier        : Tier pengguna ("FREE" atau "PRO")

    Returns:
        dict komprehensif berisi: decision, color, score, tier_used,
        locked_features, normal_price, wma_price, support, resistance,
        sr_position, price_delta_percent, price_per_unit, history_months,
        volatility_percent, fair_upper_bound, price_anomaly (PRO),
        shrinkflation (PRO), dan breakdown komponen skor.
    """
    is_pro = user_tier.upper() == "PRO"

    # Batasi window historis ke MAX_HISTORY_MONTHS bulan terakhir
    buckets = monthly_buckets[-MAX_HISTORY_MONTHS:]

    # Ekstraksi series harga dan berat dari bucket bulanan
    monthly_prices  = [float(b["avg_price"])  for b in buckets if b.get("avg_price")]
    monthly_weights = [float(b["avg_weight"]) for b in buckets if b.get("avg_weight")]
    history_months  = len(monthly_prices)

    # Bobot linear 1, 2, ..., n — memberi bobot lebih besar pada data terbaru
    weights = list(range(1, history_months + 1))

    # Delegasi kalkulasi intensif ke C-Engine untuk performa O(n) native
    normal_price = compute_wma(monthly_prices, weights) if monthly_prices else 0.0
    support      = compute_support(monthly_prices)      if monthly_prices else 0.0
    resistance   = compute_resistance(monthly_prices)   if monthly_prices else 0.0
    sr_position  = compute_sr_position(scanned_price, support, resistance)

    # Referensi berat: ambil dari bulan terakhir historis (atau berat saat ini jika tidak ada)
    reference_weight      = monthly_weights[-1] if monthly_weights else current_weight
    price_delta_percent   = _pct_change(scanned_price, normal_price)
    volatility_percent    = _volatility_percent(monthly_prices, normal_price)

    # Hitung ketiga komponen skor utama
    wma_score     = compute_wma_score(price_delta_percent)
    sr_score      = compute_sr_score(sr_position)
    urgency_score = compute_urgency_score(urgency, price_delta_percent)

    # Deteksi anomali (hanya relevan untuk PRO; kalkulasi tetap dilakukan untuk konsistensi)
    price_anomaly = detect_price_anomaly(
        scanned_price=scanned_price,
        normal_price=normal_price,
        volatility_percent=volatility_percent,
        price_delta_percent=price_delta_percent,
    )
    shrinkflation = detect_shrinkflation(
        current_weight=current_weight,
        reference_weight=reference_weight,
        scanned_price=scanned_price,
        normal_price=normal_price,
    )

    # Penalti anomali hanya diterapkan pada PRO tier
    anomaly_penalty = (price_anomaly["penalty"] + shrinkflation["penalty"]) if is_pro else 0

    # Agregasi skor final dan clamp ke [0, 100]
    raw_score   = wma_score + sr_score + urgency_score - anomaly_penalty
    final_score = max(0, min(100, int(round(raw_score))))
    decision, color = get_decision(final_score)

    # Harga per gram: metrik normalisasi untuk perbandingan lintas ukuran kemasan
    price_per_unit = scanned_price / current_weight if current_weight > 0 else 0.0

    return {
        "decision":           decision,
        "color":              color,
        "score":              final_score,
        "tier_used":          "pro" if is_pro else "free",
        "locked_features":    [] if is_pro else FREE_LOCKED_FEATURES,
        "normal_price":       _round(normal_price),
        "wma_price":          _round(normal_price),   # alias untuk kompatibilitas client
        "support":            _round(support),
        "resistance":         _round(resistance),
        "sr_position":        _round(sr_position),
        "price_delta_percent": _round(price_delta_percent),
        "price_per_unit":     _round(price_per_unit, 4),
        "history_months":     history_months,
        "volatility_percent": _round(volatility_percent),
        "fair_upper_bound":   _round(price_anomaly["fair_upper_bound"]),
        "price_anomaly":      price_anomaly if is_pro else None,
        "shrinkflation":      shrinkflation if is_pro else None,
        "components": {
            "wma":               wma_score,
            "support_resistance": sr_score,
            "urgency":           urgency_score,
            "anomaly_penalty":   anomaly_penalty,
        },
    }
