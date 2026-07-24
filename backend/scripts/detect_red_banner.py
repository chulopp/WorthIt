#!/usr/bin/env python3
"""
detect_red_banner.py
Fase 1: Scan 507 gambar dari Supabase Storage, deteksi yang masih punya banner merah di bawah.
Output: banner_detected.json — list product_id yang bermasalah.
"""
from __future__ import annotations

import io
import json
import ssl
import time
import sys
import urllib.request
from pathlib import Path

# ── Config ──────────────────────────────────────────────────────────────────
SCRIPT_DIR    = Path(__file__).resolve().parent
PROJECT_ROOT  = SCRIPT_DIR.parent
LOG_PATH      = PROJECT_ROOT / "data" / "image_pipeline_log.json"
OUT_PATH      = PROJECT_ROOT / "data" / "banner_detected.json"

SUPABASE_URL  = "https://nyjojldhvpufxesplrtk.supabase.co"
SUPABASE_SKEY = (
    "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9"
    ".eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im55am9qbGRodnB1Znhlc3BscnRrIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc3ODQxMTY1OCwiZXhwIjoyMDkzOTg3NjU4fQ"
    ".KlXI_YpE58JL3cZX6MfaYNzr08UvQ9aOXhBeWLDbw5M"
)
_CTX = ssl.create_default_context()

# Scan settings
SCAN_BOTTOM_ROWS  = 60    # scan bottom N rows
RED_PIXEL_RATIO   = 0.08  # if >8% of pixels in bottom rows are red → flagged
DOWNLOAD_TIMEOUT  = 20    # seconds per image download

def get_products_from_log() -> dict:
    """Load pipeline log, return {product_id: {sku, image_url}} for SUCCESS entries only."""
    with open(LOG_PATH, encoding="utf-8") as f:
        log_data = json.load(f)
    
    result = {}
    for pid, entry in log_data.items():
        if entry.get("status") == "SUCCESS" and entry.get("image_url"):
            url = entry["image_url"]
            # Only include Supabase-hosted JPEGs (not the 38 manual PNGs)
            if "supabase.co" in url and url.endswith(".jpg"):
                result[pid] = {
                    "sku": entry.get("sku", "-"),
                    "image_url": url
                }
    return result

def get_product_names(pids: list[str]) -> dict:
    """Fetch product names from Supabase in chunks."""
    name_map = {}
    chunk_size = 50
    for i in range(0, len(pids), chunk_size):
        chunk = pids[i:i+chunk_size]
        ids_str = ",".join(chunk)
        url = f"{SUPABASE_URL}/rest/v1/products?select=id,name&id=in.({ids_str})"
        req = urllib.request.Request(url, headers={
            "apikey": SUPABASE_SKEY,
            "Authorization": f"Bearer {SUPABASE_SKEY}",
            "Accept": "application/json",
        })
        try:
            with urllib.request.urlopen(req, timeout=30, context=_CTX) as r:
                for p in json.loads(r.read()):
                    name_map[p["id"]] = p["name"]
        except Exception as e:
            print(f"  [WARN] Failed fetching names chunk {i}: {e}")
    return name_map

def download_image(url: str) -> bytes | None:
    """Download image bytes from URL."""
    try:
        req = urllib.request.Request(url, headers={
            "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36"
        })
        with urllib.request.urlopen(req, timeout=DOWNLOAD_TIMEOUT, context=_CTX) as r:
            return r.read()
    except Exception as e:
        return None

def has_red_banner(img_bytes: bytes) -> tuple[bool, float]:
    """
    Returns (is_flagged, red_ratio) by checking bottom SCAN_BOTTOM_ROWS rows for red pixels.
    Red defined in HSV: Hue 0-15 or 165-180, Saturation>80, Value>60.
    """
    from PIL import Image
    import numpy as np

    img = Image.open(io.BytesIO(img_bytes)).convert("RGB")
    arr = np.array(img)

    h, w = arr.shape[:2]
    # Take bottom SCAN_BOTTOM_ROWS rows
    bottom = arr[max(0, h - SCAN_BOTTOM_ROWS):h]

    # Normalize to float [0,1]
    r = bottom[:, :, 0].astype(float) / 255.0
    g = bottom[:, :, 1].astype(float) / 255.0
    b = bottom[:, :, 2].astype(float) / 255.0

    # Calculate HSV-like hue from RGB
    cmax = np.maximum(np.maximum(r, g), b)
    cmin = np.minimum(np.minimum(r, g), b)
    delta = cmax - cmin

    # Only consider pixels with enough saturation (colorful) and brightness
    sat = np.where(cmax > 0, delta / cmax, 0)
    val = cmax

    bright_and_sat = (sat > 0.35) & (val > 0.25)

    # Hue calculation for red
    with np.errstate(divide='ignore', invalid='ignore'):
        hue = np.where(
            delta == 0, 0,
            np.where(
                cmax == r, ((g - b) / delta) % 6,
                np.where(cmax == g, (b - r) / delta + 2, (r - g) / delta + 4)
            )
        ) * 60  # Convert to 0-360

    # Red is hue 0-20 or 340-360
    is_red = ((hue < 20) | (hue > 340)) & bright_and_sat

    red_pixel_count = np.sum(is_red)
    total_pixels = bottom.shape[0] * bottom.shape[1]
    red_ratio = red_pixel_count / total_pixels if total_pixels > 0 else 0.0

    return red_ratio > RED_PIXEL_RATIO, red_ratio

def main():
    print("=" * 60)
    print("PHASE 1: Detecting Red Banner in Product Images")
    print("=" * 60)

    # Load pipeline log (only SUCCESS .jpg from Supabase)
    products = get_products_from_log()
    print(f"\nScanning {len(products)} auto-processed JPEG images from Supabase Storage...")

    # Fetch names
    print("Fetching product names...")
    name_map = get_product_names(list(products.keys()))

    flagged = {}
    clean = 0
    errors = 0
    total = len(products)

    for idx, (pid, info) in enumerate(products.items(), 1):
        name = name_map.get(pid, "Unknown")
        url  = info["image_url"]
        sku  = info["sku"]

        sys.stdout.write(f"\r[{idx}/{total}] Checking: {name[:50]:<50}")
        sys.stdout.flush()

        img_bytes = download_image(url)
        if not img_bytes:
            errors += 1
            continue

        try:
            is_flagged, red_ratio = has_red_banner(img_bytes)
        except Exception as e:
            errors += 1
            continue

        if is_flagged:
            flagged[pid] = {
                "name": name,
                "sku": sku,
                "image_url": url,
                "red_ratio": round(red_ratio, 4)
            }
        else:
            clean += 1

        time.sleep(0.1)  # light throttle

    print(f"\n\n{'='*60}")
    print(f"DETECTION COMPLETE")
    print(f"  Flagged (banner detected) : {len(flagged)}")
    print(f"  Clean                     : {clean}")
    print(f"  Errors (download/parse)   : {errors}")
    print(f"  Total scanned             : {total}")
    print(f"{'='*60}")

    if flagged:
        print(f"\nFlagged products:")
        for pid, info in sorted(flagged.items(), key=lambda x: x[1]["name"]):
            print(f"  - {info['name']} (red_ratio={info['red_ratio']:.1%})")

    # Save output
    OUT_PATH.parent.mkdir(parents=True, exist_ok=True)
    with open(OUT_PATH, "w", encoding="utf-8") as f:
        json.dump(flagged, f, indent=2, ensure_ascii=False)
    print(f"\nResults saved to: {OUT_PATH}")

if __name__ == "__main__":
    main()
