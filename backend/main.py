"""
main.py — WorthIt Backend Application Entry Point

FastAPI application yang mendaftarkan semua router, middleware, dan
global exception handler untuk WorthIt API v1.0.

Jalankan (development):
    cd backend && uvicorn main:app --reload --port 8000

Swagger UI:
    http://localhost:8000/docs

Arsitektur Error Response:
    Semua error — baik dari validation, HTTP, maupun unhandled exception —
    dinormalisasi ke satu format konsisten:
    {
        "status": "error",
        "error": {
            "code":       "SNAKE_CASE_ERROR_CODE",
            "message":    "Pesan yang human-readable",
            "suggestion": "Langkah pemulihan untuk client/developer"
        }
    }
    Konsistensi ini memudahkan error handling di sisi Flutter client.
"""

from __future__ import annotations

import logging
import traceback

from fastapi import FastAPI, HTTPException, Request
from fastapi.exceptions import RequestValidationError
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from starlette.exceptions import HTTPException as StarletteHTTPException

from routers import (
    analyze,
    dashboard,
    favorites,
    history,
    products,
    scanner,
    shopping,
    tracker,
    users,
)

# ─── Application Instance ─────────────────────────────────────────────────────

app = FastAPI(
    title="WorthIt API",
    description="""\
## 🛒 WorthIt — Asisten Validasi Keputusan Belanja In-Store

API Backend untuk aplikasi WorthIt yang membantu konsumen memvalidasi harga
produk secara real-time saat berada di toko supermarket.

### Fitur Utama
- **POST /v1/analyze** — Pipeline analisis harga: WMA + S/R + Anomaly + Shrinkflation
- **POST /v1/scan** — OCR struk/label harga via Gemini Vision AI
- **GET /v1/dashboard** — Ringkasan budget dan aktivitas belanja
- **GET /v1/tracker** — Portofolio pengeluaran per kategori (bulanan)

### Authentication
Gunakan `Authorization: Bearer <Supabase JWT>` pada header request.
Token diperoleh dari Supabase Google OAuth flow di sisi Flutter client.

### Tier Pengguna
| Tier | Scan/minggu | WMA Window | Fitur PRO |
|------|-------------|------------ |-----------|
| FREE | 10x         | 3 bulan     | ✗         |
| PRO  | Unlimited   | 6 bulan     | Anomaly + Shrinkflation |
""",
    version="1.0.0",
    contact={
        "name": "WorthIt Team",
        "url":  "https://github.com/worthit",
    },
    docs_url="/docs",
    redoc_url="/redoc",
)

# ─── CORS Middleware ───────────────────────────────────────────────────────────
# TODO (production): Ganti allow_origins=["*"] dengan daftar domain spesifik
# (Dev Tunnel URL, domain production) untuk mencegah cross-origin abuse.

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# ─── Exception Handlers ───────────────────────────────────────────────────────

@app.exception_handler(RequestValidationError)
async def validation_exception_handler(request: Request, exc: RequestValidationError):
    """
    Handler untuk error validasi Pydantic (422 Unprocessable Entity).
    Mengembalikan daftar field errors dalam field "suggestion" untuk
    memudahkan debugging di sisi Flutter/developer.
    """
    return JSONResponse(
        status_code=422,
        content={
            "status": "error",
            "error": {
                "code":       "INVALID_INPUT",
                "message":    "Input tidak valid.",
                "suggestion": str(exc.errors()),
            },
        },
    )


@app.exception_handler(HTTPException)
async def http_exception_handler(request: Request, exc: HTTPException):
    """
    Handler untuk HTTPException yang di-raise secara eksplisit oleh router.

    Endpoint /v1/scan menggunakan format response berbeda (scanner-compatible)
    sehingga mendapat penanganan khusus.
    """
    detail = exc.detail

    # Scanner endpoint menggunakan flat format untuk kompatibilitas OCR client
    if request.url.path == "/v1/scan":
        return JSONResponse(
            status_code=exc.status_code,
            content={"status": "error", "message": str(detail)},
        )

    code       = "ERROR"
    message    = str(detail)
    suggestion = "Hubungi tim jika masalah berlanjut."

    if isinstance(detail, dict):
        code       = detail.get("code", code)
        message    = detail.get("message", message)
        suggestion = detail.get("suggestion", suggestion)

    return JSONResponse(
        status_code=exc.status_code,
        content={
            "status": "error",
            "error": {"code": code, "message": message, "suggestion": suggestion},
        },
    )


@app.exception_handler(Exception)
async def global_exception_handler(request: Request, exc: Exception):
    """
    Catch-all handler untuk exception yang tidak tertangani di router.

    Log full traceback ke server log (tidak dikirim ke client untuk
    mencegah kebocoran informasi internal stack trace ke end-user).
    """
    logging.error("Unhandled exception at %s: %s", request.url.path, exc)
    logging.error(traceback.format_exc())

    # StarletteHTTPException yang lolos dari http_exception_handler
    if isinstance(exc, StarletteHTTPException):
        detail     = exc.detail
        code       = "ERROR"
        message    = str(detail)
        suggestion = "Hubungi tim jika masalah berlanjut."

        if isinstance(detail, dict):
            code       = detail.get("code", code)
            message    = detail.get("message", message)
            suggestion = detail.get("suggestion", suggestion)

        return JSONResponse(
            status_code=exc.status_code,
            content={
                "status": "error",
                "error": {"code": code, "message": message, "suggestion": suggestion},
            },
        )

    # Generic 500 — internal detail tidak diekspos ke client
    return JSONResponse(
        status_code=500,
        content={
            "status": "error",
            "error": {
                "code":       "INTERNAL_ERROR",
                "message":    "Terjadi kesalahan internal pada server.",
                "suggestion": "Coba lagi dalam beberapa saat. Hubungi tim jika masalah berlanjut.",
            },
        },
    )

# ─── Router Registration ──────────────────────────────────────────────────────

app.include_router(analyze.router)
app.include_router(dashboard.router)
app.include_router(tracker.router)
app.include_router(products.router)
app.include_router(favorites.router)
app.include_router(users.router)
app.include_router(shopping.router)
app.include_router(history.router)
app.include_router(scanner.router, prefix="/v1", tags=["Scanner"])

# ─── Health Endpoints ─────────────────────────────────────────────────────────

@app.get("/", tags=["Health"], summary="Health Check")
def health_check():
    """Endpoint dasar untuk memverifikasi bahwa server aktif dan menerima request."""
    return {
        "status":  "ok",
        "service": "WorthIt API",
        "version": "1.0.0",
        "message": "Backend is running! Buka /docs untuk Swagger UI.",
    }


@app.get("/health", tags=["Health"], summary="Detailed System Health")
def health_detail():
    """
    Endpoint diagnostik yang melaporkan status C-Engine dan daftar endpoint aktif.
    Berguna untuk infrastructure monitoring dan CI/CD health checks.
    """
    from engine.c_bridge import _lib_loaded
    return {
        "status":          "ok",
        "c_engine_loaded": _lib_loaded,
        "endpoints": [
            "POST /v1/analyze",
            "GET  /v1/dashboard",
            "GET  /v1/tracker",
            "GET  /v1/shopping-list/current",
            "GET  /v1/products/search",
            "GET  /v1/products/{product_id}",
            "GET  /v1/products/{product_id}/price-history",
            "POST /v1/products/{product_id}/image",
            "GET  /v1/favorites",
            "POST /v1/favorites",
            "DELETE /v1/favorites/{product_id}",
            "PATCH /v1/users/me/budget",
            "GET  /v1/history/scans",
            "POST /v1/history/purchases",
            "GET  /v1/history/purchases",
        ],
    }
