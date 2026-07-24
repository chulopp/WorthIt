#!/usr/bin/env python3
"""
fix_red_banner.py
Fase 2: Re-process gambar yang terdeteksi punya banner merah.
- Re-fetch gambar segar dari Alfagift CDN menggunakan Playwright (berdasarkan SKU)
- Enhanced pipeline: pre-crop merah sebelum rembg + post-rembg cleanup merah
- Upload ke Supabase Storage, update DB image_url
"""
from __future__ import annotations

import asyncio
import io
import json
import re
import ssl
import sys
import time
import urllib.request
from datetime import datetime, timezone
from pathlib import Path
from uuid import uuid4

# ── Config ──────────────────────────────────────────────────────────────────
SCRIPT_DIR    = Path(__file__).resolve().parent
PROJECT_ROOT  = SCRIPT_DIR.parent
DETECT_PATH   = PROJECT_ROOT / "data" / "banner_detected.json"
FIX_LOG_PATH  = PROJECT_ROOT / "data" / "banner_fix_log.json"

SUPABASE_URL  = "https://nyjojldhvpufxesplrtk.supabase.co"
SUPABASE_SKEY = (
    "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9"
    ".eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im55am9qbGRodnB1Znhlc3BscnRrIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc3ODQxMTY1OCwiZXhwIjoyMDkzOTg3NjU4fQ"
    ".KlXI_YpE58JL3cZX6MfaYNzr08UvQ9aOXhBeWLDbw5M"
)
BUCKET     = "product-images"
TARGET_SIZE = (800, 800)
MAX_KB      = 500
_CTX        = ssl.create_default_context()
ALFAGIFT_CDN = "c.alfagift.id"

IMG_URL_KEYS = (
    "imageUrl", "image_url", "image", "img", "thumbnail",
    "thumbnailUrl", "thumbnail_url", "photo", "picture",
    "productImage", "product_image",
)

# ── Helpers ──────────────────────────────────────────────────────────────────
def log(msg: str) -> None:
    ts = datetime.now(timezone.utc).strftime("%H:%M:%S")
    safe = msg.encode("ascii", "replace").decode("ascii")
    print(f"[{ts}] {safe}", flush=True)

def sb_storage_upload(storage_path: str, img_bytes: bytes, content_type: str) -> str:
    url = f"{SUPABASE_URL}/storage/v1/object/{BUCKET}/{storage_path}"
    req = urllib.request.Request(url, data=img_bytes, headers={
        "apikey": SUPABASE_SKEY,
        "Authorization": f"Bearer {SUPABASE_SKEY}",
        "Content-Type": content_type,
        "x-upsert": "true",
    }, method="POST")
    with urllib.request.urlopen(req, timeout=60, context=_CTX) as r:
        pass
    return f"{SUPABASE_URL}/storage/v1/object/public/{BUCKET}/{storage_path}"

def sb_patch(table: str, match_filter: str, payload: dict) -> None:
    data = json.dumps(payload).encode()
    headers = {
        "apikey": SUPABASE_SKEY,
        "Authorization": f"Bearer {SUPABASE_SKEY}",
        "Accept": "application/json",
        "Content-Type": "application/json",
        "Prefer": "return=minimal",
    }
    req = urllib.request.Request(
        f"{SUPABASE_URL}/rest/v1/{table}?{match_filter}",
        data=data, headers=headers, method="PATCH"
    )
    with urllib.request.urlopen(req, timeout=30, context=_CTX) as r:
        pass

def http_get_image(url: str) -> bytes | None:
    try:
        req = urllib.request.Request(url, headers={
            "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36"
        })
        with urllib.request.urlopen(req, timeout=30, context=_CTX) as r:
            data = r.read()
        log(f"  [OK] Fetched {len(data)//1024}KB")
        return data
    except Exception as e:
        log(f"  [WARN] HTTP fetch failed: {e}")
        return None

def _find_image_url_in_json(payload, sku: str, depth: int = 0) -> str | None:
    if depth > 8:
        return None
    if isinstance(payload, dict):
        for key in IMG_URL_KEYS:
            val = payload.get(key) or payload.get(key.lower())
            if isinstance(val, str) and val.startswith("http") and (
                ".jpg" in val or ".png" in val or ".webp" in val or "image" in val
            ):
                if sku in val or ALFAGIFT_CDN in val:
                    return val
        for v in payload.values():
            found = _find_image_url_in_json(v, sku, depth + 1)
            if found:
                return found
    elif isinstance(payload, list):
        for item in payload:
            found = _find_image_url_in_json(item, sku, depth + 1)
            if found:
                return found
    return None

async def _fetch_url_playwright(product_name: str, sku: str) -> str | None:
    from playwright.async_api import async_playwright
    from urllib.parse import quote

    queries = [product_name]
    cleaned = [w for w in re.sub(r"[^a-zA-Z0-9\s]", "", product_name).split() if len(w) > 2]
    if len(cleaned) > 2:
        queries.append(" ".join(cleaned[:3]))
    queries = list(dict.fromkeys(queries))

    log(f"  [playwright] Launching browser. Queries: {queries}")
    try:
        async with async_playwright() as p:
            browser = await p.chromium.launch(headless=True)
            context = await browser.new_context(
                user_agent="Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/125.0.0.0 Safari/537.36",
                locale="id-ID"
            )
            page = await context.new_page()

            payloads = []
            async def handle_resp(response):
                if "webcommerce-gw.alfagift.id/v2/products/searches" in response.url:
                    try:
                        payloads.append(await response.json())
                    except Exception:
                        pass

            page.on("response", handle_resp)

            for q in queries:
                log(f"  [playwright] Query: {q}")
                payloads.clear()
                try:
                    await page.goto(f"https://alfagift.id/find/{quote(q)}", wait_until="domcontentloaded", timeout=20000)
                    await page.wait_for_timeout(2000)
                except Exception as e:
                    log(f"  [WARN] Navigation failed: {e}")
                    continue

                for payload in payloads:
                    img_url = _find_image_url_in_json(payload, sku)
                    if img_url:
                        log(f"  [OK] Found image URL for SKU {sku}")
                        await context.close()
                        await browser.close()
                        return img_url

            await context.close()
            await browser.close()
    except Exception as e:
        log(f"  [playwright] Browser failed: {e}")
    return None

def fetch_from_alfagift(product_name: str, sku: str) -> bytes | None:
    """Fetch fresh image from Alfagift via Playwright."""
    log(f"  [SEARCH] Fetching from Alfagift for SKU {sku}...")
    try:
        loop = asyncio.get_event_loop()
    except RuntimeError:
        loop = asyncio.new_event_loop()
        asyncio.set_event_loop(loop)

    img_url = loop.run_until_complete(_fetch_url_playwright(product_name, sku))
    if img_url:
        return http_get_image(img_url)
    return None

def detect_red_rows(arr_rgb) -> int:
    """
    Return the row index from the top that marks the start of the red banner.
    If no significant red band found, returns arr height (no crop needed).
    """
    import numpy as np
    h, w = arr_rgb.shape[:2]
    r = arr_rgb[:, :, 0].astype(float) / 255.0
    g = arr_rgb[:, :, 1].astype(float) / 255.0
    b = arr_rgb[:, :, 2].astype(float) / 255.0

    cmax = np.maximum(np.maximum(r, g), b)
    cmin = np.minimum(np.minimum(r, g), b)
    delta = cmax - cmin

    sat = np.where(cmax > 0, delta / cmax, 0)
    val = cmax

    with np.errstate(divide='ignore', invalid='ignore'):
        hue = np.where(
            delta == 0, 0,
            np.where(
                cmax == r, ((g - b) / delta) % 6,
                np.where(cmax == g, (b - r) / delta + 2, (r - g) / delta + 4)
            )
        ) * 60

    bright_sat = (sat > 0.40) & (val > 0.30)
    is_red = ((hue < 20) | (hue > 340)) & bright_sat

    # Find topmost row where majority of row is red
    red_banner_start = h  # default: no crop
    # Scan from bottom up to find contiguous red rows
    consecutive = 0
    for row_idx in range(h - 1, max(h - 120, 0), -1):
        row_red_ratio = np.sum(is_red[row_idx]) / w
        if row_red_ratio > 0.25:
            consecutive += 1
            red_banner_start = row_idx
        else:
            if consecutive > 3:
                # Found the start of the banner
                break
            consecutive = 0
            red_banner_start = h  # reset if not contiguous

    return red_banner_start

def process_image_enhanced(raw_bytes: bytes) -> bytes:
    """
    Enhanced pipeline:
    1. Pre-crop: detect & remove red banner rows BEFORE rembg
    2. rembg → remove background
    3. Post-rembg: zero out remaining red pixels in alpha
    4. Connected-components filter
    5. Crop + letterbox 800x800 + JPEG ≤ 500KB
    """
    from PIL import Image
    import numpy as np
    from rembg import remove
    import scipy.ndimage as ndimage

    # --- STEP 0: Pre-crop red banner rows ---
    img_raw = Image.open(io.BytesIO(raw_bytes)).convert("RGB")
    arr = np.array(img_raw)
    h, w = arr.shape[:2]

    banner_start_row = detect_red_rows(arr)
    if banner_start_row < h:
        log(f"  [PRE-CROP] Red banner detected at row {banner_start_row}/{h}, cropping...")
        arr_cropped = arr[:banner_start_row, :, :]
        img_precropped = Image.fromarray(arr_cropped)
        buf = io.BytesIO()
        img_precropped.save(buf, format="PNG")
        raw_bytes = buf.getvalue()
        log(f"  [PRE-CROP] Image cropped from {h}px to {banner_start_row}px height")
    else:
        log(f"  [PRE-CROP] No red banner row detected via pre-crop scan")

    # --- STEP 1: rembg ---
    log(f"  [rembg] Removing background...")
    try:
        no_bg_bytes = remove(raw_bytes)
        img = Image.open(io.BytesIO(no_bg_bytes)).convert("RGBA")
    except Exception as e:
        log(f"  [WARN] rembg failed ({e}), fallback to original...")
        img = Image.open(io.BytesIO(raw_bytes)).convert("RGBA")

    # --- STEP 2: Post-rembg red pixel cleanup ---
    try:
        arr_rgba = np.array(img)
        r = arr_rgba[:, :, 0].astype(float) / 255.0
        g = arr_rgba[:, :, 1].astype(float) / 255.0
        b = arr_rgba[:, :, 2].astype(float) / 255.0
        a = arr_rgba[:, :, 3]

        # Only check visible pixels (alpha > 10)
        visible = a > 10
        cmax = np.maximum(np.maximum(r, g), b)
        cmin = np.minimum(np.minimum(r, g), b)
        delta = cmax - cmin
        sat = np.where(cmax > 0, delta / cmax, 0)
        val = cmax

        with np.errstate(divide='ignore', invalid='ignore'):
            hue = np.where(
                delta == 0, 0,
                np.where(
                    cmax == r, ((g - b) / delta) % 6,
                    np.where(cmax == g, (b - r) / delta + 2, (r - g) / delta + 4)
                )
            ) * 60

        bright_sat = (sat > 0.40) & (val > 0.25)
        is_red_visible = ((hue < 20) | (hue > 340)) & bright_sat & visible

        # Zero out alpha for red pixels, but only in bottom 30% of image
        img_h = arr_rgba.shape[0]
        bottom_start = int(img_h * 0.70)
        mask_bottom_red = np.zeros_like(is_red_visible, dtype=bool)
        mask_bottom_red[bottom_start:, :] = is_red_visible[bottom_start:, :]

        red_count = np.sum(mask_bottom_red)
        if red_count > 0:
            new_alpha = arr_rgba[:, :, 3].copy()
            new_alpha[mask_bottom_red] = 0
            arr_rgba[:, :, 3] = new_alpha
            img = Image.fromarray(arr_rgba)
            log(f"  [POST-CLEAN] Zeroed {red_count} red pixels in bottom 30% of image")
    except Exception as e:
        log(f"  [WARN] Post-rembg red cleanup failed: {e}")

    # --- STEP 3: Connected-components filter ---
    try:
        alpha = np.array(img.split()[-1])
        mask = alpha > 10
        labeled_mask, num_features = ndimage.label(mask)

        if num_features > 1:
            component_sizes = ndimage.sum(mask, labeled_mask, range(1, num_features + 1))
            slices = ndimage.find_objects(labeled_mask)
            img_h, img_w = mask.shape
            center_y, center_x = img_h / 2, img_w / 2

            scored = []
            for idx, sl in enumerate(slices):
                if sl is None:
                    continue
                label = idx + 1
                size = component_sizes[idx]
                slice_y, slice_x = sl
                cy = (slice_y.start + slice_y.stop) / 2
                cx = (slice_x.start + slice_x.stop) / 2
                dist_x = (cx - center_x) / center_x
                dist_y = (cy - center_y) / center_y
                dist = (dist_x**2 + dist_y**2) ** 0.5
                centrality = max(0.0, 1.0 - (dist / 1.414))
                score = size * centrality
                scored.append({"label": label, "score": score})

            if scored:
                scored.sort(key=lambda x: -x["score"])
                best_label = scored[0]["label"]
                clean_alpha = (labeled_mask == best_label).astype("uint8") * alpha
                r_ch, g_ch, b_ch, _ = img.split()
                img = Image.merge("RGBA", (r_ch, g_ch, b_ch, Image.fromarray(clean_alpha)))
                log(f"  [CC] Cleared {num_features - 1} isolated components")
    except Exception as e:
        log(f"  [WARN] Connected-components failed: {e}")

    # --- STEP 4: Crop to content bounding box ---
    r_ch, g_ch, b_ch, a_ch = img.split()
    bbox = a_ch.getbbox()
    if bbox:
        img_w, img_h = img.size
        pad_x = int(img_w * 0.02)
        pad_y = int(img_h * 0.02)
        img = img.crop((
            max(0, bbox[0] - pad_x),
            max(0, bbox[1] - pad_y),
            min(img_w, bbox[2] + pad_x),
            min(img_h, bbox[3] + pad_y),
        ))

    # --- STEP 5: Letterbox to 800x800 white ---
    canvas = Image.new("RGBA", TARGET_SIZE, (255, 255, 255, 255))
    img_w, img_h = img.size
    scale = min(TARGET_SIZE[0] / img_w, TARGET_SIZE[1] / img_h)
    new_w, new_h = int(img_w * scale), int(img_h * scale)
    img_resized = img.resize((new_w, new_h), Image.Resampling.LANCZOS)
    offset_x = (TARGET_SIZE[0] - new_w) // 2
    offset_y = (TARGET_SIZE[1] - new_h) // 2
    canvas.paste(img_resized, (offset_x, offset_y), img_resized)
    canvas_rgb = canvas.convert("RGB")

    # --- STEP 6: Compress to ≤ 500KB JPEG ---
    quality = 90
    while quality >= 40:
        buf = io.BytesIO()
        canvas_rgb.save(buf, format="JPEG", quality=quality, optimize=True)
        if buf.tell() <= MAX_KB * 1024:
            log(f"  [IMG] Output: 800x800 JPEG, {buf.tell()//1024}KB (quality={quality})")
            return buf.getvalue()
        quality -= 10

    buf = io.BytesIO()
    canvas_rgb.save(buf, format="JPEG", quality=40)
    log(f"  [IMG] Output (fallback): {buf.tell()//1024}KB")
    return buf.getvalue()

def load_fix_log() -> dict:
    if FIX_LOG_PATH.exists():
        try:
            return json.loads(FIX_LOG_PATH.read_text(encoding="utf-8"))
        except Exception:
            return {}
    return {}

def save_fix_log(log_data: dict) -> None:
    FIX_LOG_PATH.parent.mkdir(parents=True, exist_ok=True)
    FIX_LOG_PATH.write_text(json.dumps(log_data, indent=2, ensure_ascii=False), encoding="utf-8")

def main():
    if not DETECT_PATH.exists():
        print(f"ERROR: Detection file not found at {DETECT_PATH}")
        print("Run detect_red_banner.py first!")
        sys.exit(1)

    with open(DETECT_PATH, encoding="utf-8") as f:
        flagged = json.load(f)

    if not flagged:
        print("No flagged products found. Nothing to fix!")
        sys.exit(0)

    fix_log = load_fix_log()
    print(f"{'='*60}")
    print(f"PHASE 2: Fixing {len(flagged)} Products with Red Banner")
    print(f"{'='*60}\n")

    success = 0
    errors = 0
    skipped = 0

    for idx, (pid, info) in enumerate(flagged.items(), 1):
        name = info["name"]
        sku  = info["sku"]

        print(f"\n{'='*60}")
        print(f"[{idx}/{len(flagged)}] {name}")
        print(f"  ID: {pid} | SKU: {sku} | Red ratio: {info.get('red_ratio', '?'):.1%}" if isinstance(info.get('red_ratio'), float) else f"  ID: {pid}")

        # Skip if already fixed successfully
        if pid in fix_log and fix_log[pid].get("status") == "FIXED":
            print(f"  [SKIP] Already fixed.")
            skipped += 1
            continue

        # 1. Fetch fresh from Alfagift
        if sku and sku != "-":
            raw_bytes = fetch_from_alfagift(name, sku)
        else:
            raw_bytes = None

        is_fallback = False
        if not raw_bytes:
            log(f"  [FALLBACK] Could not fetch fresh image from Alfagift. Trying fallback to existing Supabase image...")
            existing_url = info.get("image_url")
            if existing_url:
                raw_bytes = http_get_image(existing_url)
                if raw_bytes:
                    is_fallback = True
                    log(f"  [FALLBACK] Successfully downloaded existing image for processing")
                else:
                    log(f"  [ERROR] Fallback download failed for {existing_url}")
            else:
                log(f"  [ERROR] No existing image URL for fallback")

        if not raw_bytes:
            print(f"  [ERROR] Could not fetch image from Alfagift or fallback URL")
            fix_log[pid] = {"status": "ERROR_FETCH", "name": name}
            save_fix_log(fix_log)
            errors += 1
            continue

        # 2. Enhanced pipeline
        try:
            processed = process_image_enhanced(raw_bytes)
        except Exception as e:
            log(f"  [ERROR] Processing failed: {e}")
            fix_log[pid] = {"status": "ERROR_PROCESS", "name": name, "error": str(e)}
            save_fix_log(fix_log)
            errors += 1
            continue

        # 3. Upload to Supabase
        storage_path = f"products/{pid}/{uuid4().hex}.jpg"
        log(f"  [UPLOAD] Uploading: {storage_path}")
        try:
            public_url = sb_storage_upload(storage_path, processed, "image/jpeg")
        except Exception as e:
            log(f"  [ERROR] Upload failed: {e}")
            fix_log[pid] = {"status": "ERROR_UPLOAD", "name": name, "error": str(e)}
            save_fix_log(fix_log)
            errors += 1
            continue

        # 4. Update DB
        log(f"  [DB] Updating image_url...")
        try:
            sb_patch("products", f"id=eq.{pid}", {"image_url": public_url})
        except Exception as e:
            log(f"  [ERROR] DB update failed: {e}")
            fix_log[pid] = {"status": "ERROR_DB", "name": name, "image_url": public_url, "error": str(e)}
            save_fix_log(fix_log)
            errors += 1
            continue

        log(f"  [SUCCESS] {public_url}")
        fix_log[pid] = {"status": "FIXED", "name": name, "image_url": public_url}
        save_fix_log(fix_log)
        success += 1

    print(f"\n{'='*60}")
    print(f"FIX COMPLETE")
    print(f"  Fixed   : {success}")
    print(f"  Skipped : {skipped}")
    print(f"  Errors  : {errors}")
    print(f"{'='*60}")
    print(f"Fix log saved to: {FIX_LOG_PATH}")

if __name__ == "__main__":
    main()
