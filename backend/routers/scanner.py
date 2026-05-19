import asyncio
import io
import json
import logging
import os
from pathlib import Path

import google.generativeai as genai
from dotenv import load_dotenv
from fastapi import APIRouter, Depends, File, HTTPException, UploadFile, status

from core.security import get_current_user
from models.scanner import ScanErrorResponse, ScanSuccessResponse
from utils.supabase_client import search_products, weights_match


router = APIRouter()

load_dotenv(Path(__file__).resolve().parents[1] / ".env")

GEMINI_API_KEY = os.environ.get("GEMINI_API_KEY")

if not GEMINI_API_KEY:
    raise RuntimeError("GEMINI_API_KEY tidak ditemukan di environment.")

genai.configure(api_key=GEMINI_API_KEY)

ALLOWED_IMAGE_EXTENSIONS = {".jpg", ".jpeg", ".png", ".webp"}
GEMINI_MODEL = os.environ.get("GEMINI_MODEL", "gemini-2.5-flash")
GEMINI_TIMEOUT_SECONDS = int(os.environ.get("GEMINI_TIMEOUT_SECONDS", "25"))
MAX_SCAN_IMAGE_SIDE = int(os.environ.get("MAX_SCAN_IMAGE_SIDE", "1280"))


@router.post(
    "/scan",
    response_model=ScanSuccessResponse,
    responses={
        404: {"model": ScanErrorResponse},
        400: {"model": ScanErrorResponse},
        500: {"model": ScanErrorResponse},
    },
)
async def scan_receipt(
    file: UploadFile = File(...),
    user_id: str = Depends(get_current_user),
):
    filename = file.filename or ""
    _, extension = os.path.splitext(filename.lower())
    if extension not in ALLOWED_IMAGE_EXTENSIONS:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="File harus berupa gambar JPG, JPEG, PNG, atau WebP.",
        )

    file_bytes = _prepare_image_bytes(await file.read())
    image_parts = [{"mime_type": "image/jpeg", "data": file_bytes}]

    prompt_text = (
        "Ekstrak data dari struk/label harga ini. Kembalikan format JSON murni: "
        "{'product_name': 'nama', 'price': 15000, 'weight_gram': 100}. "
        "ATURAN PENTING: "
        "1. Harga wajib integer murni tanpa pemisah ribuan. "
        "2. Untuk 'weight_gram', ekstrak ANGKA dari SEMUA jenis satuan ukur yang "
        "ada di nama produk atau label (contoh: ml, liter, gram, kg, watt, pcs, "
        "lembar). Misal jika nama produk 'Bear Brand 189 ml' atau 'Lampu 8 watt', "
        "isi 'weight_gram' dengan angka 189 atau 8. Jika 1.5 Liter, jadikan 1500. "
        "Jika benar-benar tidak ada angka satuan, set 0."
    )

    model = genai.GenerativeModel(GEMINI_MODEL)
    generation_config = genai.types.GenerationConfig(response_mime_type="application/json")
    try:
        response = await asyncio.wait_for(
            asyncio.to_thread(
                model.generate_content,
                [prompt_text, image_parts[0]],
                generation_config=generation_config,
            ),
            timeout=GEMINI_TIMEOUT_SECONDS,
        )
    except asyncio.TimeoutError as exc:
        raise HTTPException(
            status_code=status.HTTP_504_GATEWAY_TIMEOUT,
            detail="OCR membutuhkan waktu terlalu lama. Coba gambar yang lebih jelas atau lebih kecil.",
        ) from exc
    except Exception as exc:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Gagal menghubungi Gemini Vision.",
        ) from exc

    try:
        parsed_json = json.loads(response.text)
    except (json.JSONDecodeError, TypeError) as exc:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Gagal membaca respons JSON dari Gemini.",
        ) from exc

    extracted_name = parsed_json.get("product_name", "")
    if not extracted_name:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Produk tidak terdeteksi pada gambar",
        )

    try:
        candidates = search_products(extracted_name, limit=5)
    except Exception as exc:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Gagal menghubungi database produk.",
        ) from exc

    scanned_price = parsed_json.get("price", 0)
    scanned_weight = parsed_json.get("weight_gram", 0)
    db_item = _best_weight_match(candidates, scanned_weight)

    return {
        "status": "success",
        "data": {
            "product_name": db_item["name"] if db_item else extracted_name,
            "price": scanned_price,
            "scanned_price": scanned_price,
            "weight_gram": scanned_weight,
            "category": db_item.get("category") if db_item else None,
            "db_product_id": db_item["id"] if db_item else "",
            "candidates": [
                {
                    "id": product["id"],
                    "name": product["name"],
                    "category": product.get("category"),
                    "brand": product.get("brand"),
                    "image_url": product.get("image_url"),
                }
                for product in candidates
            ],
        },
    }


def _best_weight_match(candidates: list[dict], scanned_weight: float) -> dict | None:
    if not candidates:
        return None
    if scanned_weight <= 0:
        return candidates[0]
    for product in candidates:
        if weights_match(float(scanned_weight), float(product.get("base_weight_gram") or 0)):
            return product
    return None


def _prepare_image_bytes(file_bytes: bytes) -> bytes:
    try:
        from PIL import Image

        with Image.open(io.BytesIO(file_bytes)) as image:
            image = image.convert("RGB")
            image.thumbnail((MAX_SCAN_IMAGE_SIDE, MAX_SCAN_IMAGE_SIDE))
            output = io.BytesIO()
            image.save(output, format="JPEG", quality=82, optimize=True)
            return output.getvalue()
    except Exception as exc:
        logging.info("Scan image compression skipped: %s", exc)
        return file_bytes
