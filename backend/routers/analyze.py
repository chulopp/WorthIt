"""
routers/analyze.py — WorthIt Core Analysis Endpoint

Mengekspos POST /v1/analyze sebagai entry point utama pipeline analisis harga.
Endpoint ini mengorkestrasikan validasi request, kalkulasi scoring engine,
dan persistensi hasil ke scan_history dalam satu transaksi request.

Alur Eksekusi:
  1. Autentikasi JWT via Supabase Auth API (get_current_user)
  2. Validasi user + cek scan quota (FREE: 10x/minggu, PRO: unlimited)
  3. Validasi produk + cek kesesuaian berat kemasan
  4. Ambil price history (min. 3 bulan) → group by month
  5. Jalankan scoring engine (WMA + S/R + Urgency ± Anomaly Penalty)
  6. Build natural-language explanations
  7. Persist ke scan_history (non-blocking error: tetap return hasil)
  8. Return AnalyzeResponse ke client
"""

import logging

from fastapi import APIRouter, Depends, HTTPException

from core.security import get_current_user
from engine.scoring import run_analysis
from engine.templates import build_explanations
from models.request import AnalyzeRequest
from models.response import (
    AnalyzeData,
    AnalyzeMetrics,
    AnalyzeResponse,
    AnalyzeTierData,
)
from utils.supabase_client import (
    add_scan_record,
    check_scan_limit,
    get_price_history,
    get_product,
    get_scan_quota_status,
    get_user,
    group_history_by_month,
    weights_match,
)

router = APIRouter(prefix="/v1", tags=["Analyze"])


@router.post(
    "/analyze",
    response_model=AnalyzeResponse,
    summary="Analisis Harga Produk",
    description=(
        "Menjalankan pipeline analisis harga lengkap: WMA scoring, "
        "Support/Resistance positioning, deteksi anomali harga, dan "
        "deteksi shrinkflation (PRO). Hasil disimpan ke scan_history."
    ),
)
async def analyze_product(
    body: AnalyzeRequest,
    user_id: str = Depends(get_current_user),
):
    """
    Pipeline analisis harga produk WorthIt.

    Guard layer berjalan secara serial sebelum scoring:
      - User existence check       → 404 jika user belum terdaftar di DB
      - Scan quota enforcement     → 403 jika melebihi limit tier
      - Product existence check    → 404 jika product_id tidak valid
      - Weight mismatch guard      → 422 jika berat kemasan tidak cocok
      - Minimum history check      → 422 jika data historis < 3 bulan

    Semua error dikembalikan dalam format terstruktur {code, message, suggestion}
    untuk memudahkan debugging di sisi client/Flutter.
    """

    # ── Guard 1: Validasi keberadaan user di tabel users ──────────────────────
    user = get_user(user_id)
    if not user:
        raise HTTPException(
            status_code=404,
            detail={
                "code": "USER_NOT_FOUND",
                "message": "User tidak ditemukan.",
                "suggestion": "Login ulang dengan Google lalu kirim Authorization: Bearer <Supabase JWT>.",
            },
        )

    user_tier = user.get("subscription_tier", "FREE").upper()
    is_pro    = user_tier == "PRO"

    # ── Guard 2: Cek scan quota berdasarkan tier ───────────────────────────────
    # FREE tier: 10 scan/minggu (rolling 7 hari)
    # PRO tier: unlimited
    can_scan, limit_msg = check_scan_limit(user_id)
    if not can_scan:
        raise HTTPException(
            status_code=403,
            detail={
                "code": "SCAN_LIMIT_REACHED",
                "message": limit_msg,
                "suggestion": "Upgrade ke PRO atau tunggu reset limit mingguan.",
            },
        )

    # ── Guard 3: Validasi produk dari database ─────────────────────────────────
    product = get_product(body.db_product_id)
    if not product:
        raise HTTPException(
            status_code=404,
            detail={
                "code": "PRODUCT_NOT_FOUND",
                "message": "Produk tidak ditemukan di database.",
                "suggestion": "Pastikan db_product_id berasal dari endpoint scan atau daftar produk.",
            },
        )

    # ── Guard 4: Validasi kesesuaian berat kemasan ────────────────────────────
    # Mencegah analisis cross-variant (misal: indomie 85g vs indomie 75g)
    product_id      = product["id"]
    database_weight = float(product.get("base_weight_gram") or 0)
    if not weights_match(body.weight_gram, database_weight):
        raise HTTPException(
            status_code=422,
            detail={
                "code": "PRODUCT_WEIGHT_MISMATCH",
                "message": "Ukuran produk tidak cocok dengan data produk.",
                "suggestion": "Pastikan varian barang yang dianalisis sama persis dengan produk hasil scan/database.",
            },
        )

    # ── Guard 5: Validasi kecukupan data historis ─────────────────────────────
    # WMA membutuhkan minimal 3 titik data untuk menghasilkan sinyal yang reliable
    history_raw = get_price_history(product_id, months=6)
    if not history_raw:
        raise HTTPException(
            status_code=422,
            detail={
                "code": "INSUFFICIENT_HISTORY",
                "message": "Data harga tidak tersedia.",
                "suggestion": "Tambahkan price_history untuk produk ini sebelum analisis.",
            },
        )

    monthly_buckets = group_history_by_month(history_raw)
    if len(monthly_buckets) < 3:
        raise HTTPException(
            status_code=422,
            detail={
                "code": "INSUFFICIENT_HISTORY",
                "message": "Data historis kurang dari 3 bulan.",
                "suggestion": "Tambahkan minimal 3 bulan price_history untuk produk ini.",
            },
        )

    # ── Core: Jalankan scoring engine ─────────────────────────────────────────
    # Komputasi berat (WMA, S/R) dieksekusi di C-Engine via ctypes bridge
    analysis = run_analysis(
        scanned_price=body.scanned_price,
        current_weight=body.weight_gram,
        urgency=body.urgency,
        monthly_buckets=monthly_buckets,
        user_tier=user_tier,
    )

    # Build natural-language explanations untuk ditampilkan di UI Flutter
    explanations = build_explanations(
        scanned_price=body.scanned_price,
        normal_price=analysis["normal_price"],
        urgency=body.urgency,
        analysis=analysis,
        is_pro=is_pro,
    )

    # ── Assemble Response Payload ──────────────────────────────────────────────
    quota = get_scan_quota_status(user_id)
    analyze_data = AnalyzeData(
        product_id=product_id,
        image_url=product.get("image_url"),
        score=analysis["score"],
        decision=analysis["decision"],
        product_name=product["name"],
        scanned_price=body.scanned_price,
        normal_price=analysis["normal_price"],
        category=product.get("category", "Lainnya"),
        urgency=body.urgency,
        weight_gram=body.weight_gram,
        explanations=explanations,
        metrics=AnalyzeMetrics(
            wma_price=analysis["wma_price"],
            support=analysis["support"],
            resistance=analysis["resistance"],
            sr_position=analysis["sr_position"],
            price_delta_percent=analysis["price_delta_percent"],
            price_per_unit=analysis["price_per_unit"],
            history_points=len(history_raw),
            history_months=analysis["history_months"],
            volatility_percent=analysis["volatility_percent"],
            fair_upper_bound=analysis["fair_upper_bound"],
            shrinkflation=(
                analysis["shrinkflation"]["detected"]
                if analysis.get("shrinkflation") else None
            ),
            price_anomaly=(
                analysis["price_anomaly"]["detected"]
                if analysis.get("price_anomaly") else None
            ),
        ),
        tier=AnalyzeTierData(
            name=analysis["tier_used"],
            scan_limit=quota["limit"],
            scan_period=quota["period"],
            remaining_scans=quota["remaining"],
            locked_features=analysis["locked_features"],
        ),
    )

    # ── Persist ke scan_history (fire-and-handle) ─────────────────────────────
    # Strategi: kegagalan persistensi tidak membatalkan hasil analisis yang
    # sudah dihitung — raise 500 agar client tahu record tidak tersimpan,
    # namun skor yang valid sudah dikembalikan di error detail jika perlu retry.
    try:
        add_scan_record(
            user_id=user_id,
            product_id=product_id,
            scan_result_score=analysis["score"],
            decision=analysis["decision"],
            scanned_price=body.scanned_price,
            normal_price=analysis["normal_price"],
            urgency=body.urgency,
            weight_gram=body.weight_gram,
            analysis_snapshot=analyze_data.model_dump(),
        )
    except Exception as exc:
        logging.error("Gagal mencatat scan_history untuk user %s: %s", user_id, exc)
        raise HTTPException(
            status_code=500,
            detail={
                "code": "SCAN_HISTORY_INSERT_FAILED",
                "message": "Analisis berhasil dihitung, tetapi gagal disimpan ke riwayat.",
                "suggestion": "Coba ulangi analisis atau periksa konfigurasi database scan_history.",
            },
        ) from exc

    return AnalyzeResponse(data=analyze_data)
