"""
core/security.py — WorthIt Authentication & Authorization Layer

Mengimplementasikan JWT verification berbasis Supabase Auth API dan
FastAPI dependency injection untuk proteksi seluruh endpoint terautentikasi.

Pendekatan Verifikasi:
  Alih-alih verifikasi JWT secara lokal (yang membutuhkan JWKS/public key
  untuk algoritma ES256 yang dipakai Supabase), modul ini mendelegasikan
  validasi ke Supabase Auth API via supabase.auth.get_user(token).

  Keuntungan pendekatan ini:
    - Algorithm-agnostic: bekerja untuk ES256, HS256, RS256
    - Selalu up-to-date dengan kebijakan Supabase (revoke, session expiry)
    - Satu sumber kebenaran untuk state autentikasi

  Trade-off: satu network round-trip per request ke Supabase Auth API.
  Untuk skala produksi tinggi, pertimbangkan Redis cache pada validated tokens.

Dependency Injection:
  get_current_user() digunakan sebagai FastAPI Depends() pada semua
  endpoint yang memerlukan autentikasi, mengekstrak user_id dari JWT payload.
"""

from __future__ import annotations

import logging
import os

from dotenv import load_dotenv
from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer

# Muat .env dari lokasi file ini (core/) dan dari direktori backend/
load_dotenv()
load_dotenv(os.path.join(os.path.dirname(__file__), "..", ".env"))

# HTTPBearer dengan auto_error=False agar kita bisa memberikan error
# terstruktur {code, message, suggestion} alih-alih respons 403 default FastAPI
security = HTTPBearer(auto_error=False)


def verify_token(token: str) -> dict:
    """
    Verifikasi JWT via Supabase Auth API.

    Memanggil supabase.auth.get_user(token) yang secara internal mem-forward
    token ke endpoint /auth/v1/user Supabase untuk validasi server-side.
    Pendekatan ini mendukung semua algoritma signing (ES256, HS256) tanpa
    perlu menyimpan atau merotasi public key secara manual.

    Args:
        token: Raw JWT string dari Authorization header

    Returns:
        dict {"sub": user_id, "email": user_email}

    Raises:
        HTTPException 401: jika token tidak valid, kedaluwarsa, atau revoked
        RuntimeError:      jika Supabase client tidak dapat diinisialisasi
    """
    try:
        from utils.supabase_client import get_supabase
        sb = get_supabase()
        response = sb.auth.get_user(token)
        user = response.user
        if not user:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Token tidak valid atau user tidak ditemukan.",
            )
        return {"sub": str(user.id), "email": user.email}
    except HTTPException:
        raise
    except Exception as exc:
        logging.error("Token verification error: %s", exc)
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Token tidak valid atau kedaluwarsa.",
        )


async def get_current_user(
    credentials: HTTPAuthorizationCredentials | None = Depends(security),
) -> str:
    """
    FastAPI dependency: ekstrak dan validasi user_id dari Bearer token.

    Digunakan sebagai Depends() pada semua endpoint terautentikasi:
        user_id: str = Depends(get_current_user)

    Validasi berlapis:
      1. Cek keberadaan credentials dan scheme "Bearer"
      2. Verifikasi token via verify_token() → Supabase Auth API
      3. Ekstrak claim "sub" (user UUID) dari payload

    Returns:
        str: User UUID (primary key di tabel users Supabase)

    Raises:
        HTTPException 401: pada setiap kondisi autentikasi gagal
    """
    if credentials is None or credentials.scheme.lower() != "bearer":
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Token tidak valid atau kedaluwarsa",
        )

    token = credentials.credentials
    payload = verify_token(token)
    user_id = payload.get("sub") or payload.get("user_id")

    if not user_id:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Token error: sub/user_id tidak ditemukan dalam payload",
        )

    return str(user_id)
