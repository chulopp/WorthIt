import asyncio
import base64
import io
import json
import logging
import os
import re
from pathlib import Path

import google.generativeai as genai
import requests
from dotenv import load_dotenv
from fastapi import APIRouter, Depends, File, HTTPException, UploadFile, status

from core.security import get_current_user
from models.scanner import ScanErrorResponse, ScanSuccessResponse
from utils.supabase_client import search_products, weights_match


router = APIRouter()

load_dotenv(Path(__file__).resolve().parents[1] / ".env")

GEMINI_API_KEY = os.environ.get("GEMINI_API_KEY")
OPENROUTER_API_KEY = os.environ.get("OPENROUTER_API_KEY", "")

if not GEMINI_API_KEY:
    raise RuntimeError("GEMINI_API_KEY tidak ditemukan di environment.")

genai.configure(api_key=GEMINI_API_KEY)

ALLOWED_IMAGE_EXTENSIONS = {".jpg", ".jpeg", ".png", ".webp"}
GEMINI_MODEL = os.environ.get("GEMINI_MODEL", "gemini-2.5-flash")
GEMINI_TIMEOUT_SECONDS = int(os.environ.get("GEMINI_TIMEOUT_SECONDS", "25"))
MAX_SCAN_IMAGE_SIDE = int(os.environ.get("MAX_SCAN_IMAGE_SIDE", "1280"))

OPENROUTER_FALLBACK_MODELS = [
    "nvidia/nemotron-nano-12b-v2-vl:free",
    "nvidia/nemotron-3-nano-omni-30b-a3b-reasoning:free",
    "google/gemma-4-26b-a4b-it:free",
    "google/gemma-4-31b-it:free",
    "nvidia/nemotron-3.5-content-safety:free",
]


def _clean_json_string(text: str) -> str:
    """Bersihkan markdown code fences dan ekstraksi substring JSON."""
    cleaned = text.strip()
    cleaned = re.sub(r"^```(?:json)?", "", cleaned, flags=re.IGNORECASE).strip()
    cleaned = re.sub(r"```$", "", cleaned).strip()
    match = re.search(r"\{.*\}", cleaned, re.DOTALL)
    if match:
        return match.group(0)
    return cleaned


def _parse_scan_json(raw_text: str) -> dict | None:
    try:
        cleaned = _clean_json_string(raw_text)
        data = json.loads(cleaned)
        if isinstance(data, dict) and "product_name" in data:
            return data
    except Exception as exc:
        logging.warning("Gagal parse OCR JSON: %s (raw text: %s)", exc, raw_text[:100])
    return None


def _try_openrouter_scan(file_bytes: bytes, prompt_text: str) -> dict | None:
    if not OPENROUTER_API_KEY:
        logging.warning("OPENROUTER_API_KEY tidak dikonfigurasi di environment.")
        return None

    b64_image = base64.b64encode(file_bytes).decode("utf-8")
    data_url = f"data:image/jpeg;base64,{b64_image}"

    headers = {
        "Authorization": f"Bearer {OPENROUTER_API_KEY}",
        "Content-Type": "application/json",
        "HTTP-Referer": "https://worthit.app",
        "X-Title": "WorthIt Scan OCR",
    }

    messages = [
        {
            "role": "user",
            "content": [
                {"type": "text", "text": prompt_text},
                {"type": "image_url", "image_url": {"url": data_url}},
            ],
        }
    ]

    for model_name in OPENROUTER_FALLBACK_MODELS:
        logging.info("Mencoba OCR scan fallback via OpenRouter model: %s", model_name)
        payload = {
            "model": model_name,
            "messages": messages,
            "max_tokens": 500,
            "temperature": 0.2,
        }
        try:
            resp = requests.post(
                "https://openrouter.ai/api/v1/chat/completions",
                json=payload,
                headers=headers,
                timeout=10,
            )
            if resp.status_code == 200:
                result_json = resp.json()
                content = (
                    result_json.get("choices", [{}])[0]
                    .get("message", {})
                    .get("content", "")
                )
                parsed = _parse_scan_json(content)
                if parsed:
                    logging.info("Fallback OpenRouter berhasil menggunakan model: %s", model_name)
                    return parsed
            else:
                logging.warning(
                    "OpenRouter model %s mengembalikan HTTP %s: %s",
                    model_name,
                    resp.status_code,
                    resp.text[:150],
                )
        except Exception as exc:
            logging.warning("OpenRouter model %s error: %s", model_name, exc)

    return None


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
        '{"product_name": "nama", "price": 15000, "weight_gram": 100}. '
        "ATURAN PENTING: "
        "1. Harga wajib integer murni tanpa pemisah ribuan. "
        "2. Untuk 'weight_gram', ekstrak ANGKA dari SEMUA jenis satuan ukur yang "
        "ada di nama produk atau label (contoh: ml, liter, gram, kg, watt, pcs, "
        "lembar). Misal jika nama produk 'Bear Brand 189 ml' atau 'Lampu 8 watt', "
        "isi 'weight_gram' dengan angka 189 atau 8. Jika 1.5 Liter, jadikan 1500. "
        "Jika benar-benar tidak ada angka satuan, set 0."
    )

    parsed_json = None

    # Step 1: Coba Gemini Vision
    try:
        model = genai.GenerativeModel(GEMINI_MODEL)
        generation_config = genai.types.GenerationConfig(response_mime_type="application/json")
        response = await asyncio.wait_for(
            asyncio.to_thread(
                model.generate_content,
                [prompt_text, image_parts[0]],
                generation_config=generation_config,
            ),
            timeout=GEMINI_TIMEOUT_SECONDS,
        )
        parsed_json = _parse_scan_json(response.text)
    except Exception as exc:
        logging.warning("Gemini Vision OCR gagal/limit: %s. Melakukan fallback ke OpenRouter...", exc)

    # Step 2: Fallback ke OpenRouter jika Gemini gagal
    if not parsed_json:
        parsed_json = await asyncio.to_thread(_try_openrouter_scan, file_bytes, prompt_text)

    if not parsed_json:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Gagal memproses OCR gambar dari semua model AI.",
        )

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
