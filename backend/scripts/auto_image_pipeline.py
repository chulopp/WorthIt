#!/usr/bin/env python3
"""
auto_image_pipeline.py — Automasi pipeline gambar produk WorthIt

Pipeline per produk:
  1. Fetch gambar dari CDN alfagift (ekstrak SKU dari image_url atau kolom id)
  2. rembg → hapus background (template merah-kuning alfagift)
  3. Crop ke bounding box produk, letterbox ke 800x800 background putih
  4. Kompres ke ≤500 KB JPEG
  5. Upload ke Supabase Storage bucket "product-images"
  6. Update products.image_url → public URL Supabase
  7. Catat ke log JSON (resume-friendly)

Usage:
  python auto_image_pipeline.py                    # proses semua
  python auto_image_pipeline.py --limit 10         # batch pertama 10 produk
  python auto_image_pipeline.py --dry-run          # preview tanpa upload
  python auto_image_pipeline.py --limit 10 --skip 0
"""
from __future__ import annotations

import argparse
import io
import json
import os
import re
import ssl
import sys
import time
import urllib.request
from datetime import datetime, timezone
from pathlib import Path
from uuid import uuid4

# ── Paths & Config ────────────────────────────────────────────────────────────
SCRIPT_DIR   = Path(__file__).resolve().parent
PROJECT_ROOT = SCRIPT_DIR.parent
LOG_PATH     = PROJECT_ROOT / "data" / "image_pipeline_log.json"

SUPABASE_URL  = "https://nyjojldhvpufxesplrtk.supabase.co"
SUPABASE_SKEY = (
    "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9"
    ".eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im55am9qbGRodnB1Znhlc3BscnRrIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc3ODQxMTY1OCwiZXhwIjoyMDkzOTg3NjU4fQ"
    ".KlXI_YpE58JL3cZX6MfaYNzr08UvQ9aOXhBeWLDbw5M"
)
BUCKET        = "product-images"
TARGET_SIZE   = (800, 800)
MAX_KB        = 500
CDN_DELAY_S   = 0.6   # delay antar request CDN untuk hindari rate limit
RETRY_DELAY_S = 5.0   # delay sebelum retry
MAX_RETRIES   = 3

# SSL context (shared)
_CTX = ssl.create_default_context()

# ── Logging utils ─────────────────────────────────────────────────────────────
def log(msg: str) -> None:
    ts = datetime.now(timezone.utc).strftime("%H:%M:%S")
    safe = msg.encode("ascii", "replace").decode("ascii")
    print(f"[{ts}] {safe}", flush=True)


# ── Supabase REST helpers ──────────────────────────────────────────────────────
def _sb_headers(extra: dict | None = None) -> dict:
    h = {
        "apikey":        SUPABASE_SKEY,
        "Authorization": f"Bearer {SUPABASE_SKEY}",
        "Accept":        "application/json",
        "Content-Type":  "application/json",
    }
    if extra:
        h.update(extra)
    return h


def sb_get(path: str) -> list | dict:
    req = urllib.request.Request(
        f"{SUPABASE_URL}/rest/v1/{path}",
        headers=_sb_headers(),
    )
    with urllib.request.urlopen(req, timeout=30, context=_CTX) as r:
        return json.loads(r.read())


def sb_patch(table: str, match_filter: str, payload: dict) -> None:
    data = json.dumps(payload).encode()
    req = urllib.request.Request(
        f"{SUPABASE_URL}/rest/v1/{table}?{match_filter}",
        data=data,
        headers=_sb_headers({"Prefer": "return=minimal"}),
        method="PATCH",
    )
    with urllib.request.urlopen(req, timeout=30, context=_CTX) as r:
        pass  # 204 No Content


# ── Supabase Storage upload ────────────────────────────────────────────────────
def sb_storage_upload(storage_path: str, img_bytes: bytes, content_type: str) -> str:
    """Upload ke Supabase Storage, return public URL."""
    url = f"{SUPABASE_URL}/storage/v1/object/{BUCKET}/{storage_path}"
    req = urllib.request.Request(
        url,
        data=img_bytes,
        headers={
            "apikey":        SUPABASE_SKEY,
            "Authorization": f"Bearer {SUPABASE_SKEY}",
            "Content-Type":  content_type,
            "x-upsert":      "true",
        },
        method="POST",
    )
    with urllib.request.urlopen(req, timeout=60, context=_CTX) as r:
        pass
    public_url = f"{SUPABASE_URL}/storage/v1/object/public/{BUCKET}/{storage_path}"
    return public_url


# ── CDN URL & SKU extraction ───────────────────────────────────────────────────
# Pattern: https://c.alfagift.id/product/1/1_{SKU}_{timestamp}_base.jpg
CDN_SKU_PATTERN = re.compile(r"/1_([A-Za-z0-9\-]+)_\d+_base\.")
ALFAGIFT_CDN    = "c.alfagift.id"


def extract_sku_from_url(image_url: str | None) -> str | None:
    """Ekstrak SKU dari existing c.alfagift.id URL."""
    if not image_url:
        return None
    m = CDN_SKU_PATTERN.search(image_url)
    return m.group(1) if m else None


def _http_get_image(url: str, retries: int = MAX_RETRIES) -> bytes | None:
    """Low-level: fetch bytes dari URL gambar. Return None jika gagal."""
    for attempt in range(retries):
        try:
            req = urllib.request.Request(
                url,
                headers={
                    "User-Agent": (
                        "Mozilla/5.0 (Windows NT 10.0; Win64; x64) "
                        "AppleWebKit/537.36 (KHTML, like Gecko) "
                        "Chrome/125.0.0.0 Safari/537.36"
                    ),
                    "Accept": "image/webp,image/apng,image/*,*/*;q=0.8",
                    "Referer": "https://alfagift.id/",
                },
            )
            with urllib.request.urlopen(req, timeout=20, context=_CTX) as r:
                if r.status == 200:
                    content_type = r.headers.get("Content-Type", "")
                    if "image" in content_type or "webp" in content_type or "octet" in content_type:
                        data = r.read()
                        if len(data) > 1000:
                            return data
        except urllib.error.HTTPError as e:
            if e.code in (404, 403):
                return None
            if e.code == 429:
                log(f"  [WARN] Rate limit (429), retry in {RETRY_DELAY_S}s...")
                time.sleep(RETRY_DELAY_S * (attempt + 1))
        except Exception:
            if attempt < retries - 1:
                time.sleep(1.0)
    return None


def fetch_image_from_existing_url(existing_url: str) -> bytes | None:
    """
    Untuk produk yang sudah punya c.alfagift.id URL di DB:
    fetch langsung dari URL itu. URL sudah lengkap dengan timestamp.
    """
    log(f"  [CDN] Fetching from existing URL...")
    data = _http_get_image(existing_url)
    if data:
        log(f"  [OK] Fetched {len(data)//1024}KB dari existing URL")
    return data


async def _fetch_url_playwright_async(product_name: str, sku: str, brand: str | None) -> str | None:
    """Async helper to launch Playwright and search for product image URL with query fallback."""
    from playwright.async_api import async_playwright
    from urllib.parse import quote

    # Build search queries
    queries = [product_name]
    if brand and brand != "-" and product_name.lower().startswith(brand.lower()):
        queries.append(product_name[len(brand):].strip())
    
    # Simple clean query: keep first 3 words
    cleaned_words = [w for w in re.sub(r"[^a-zA-Z0-9\s]", "", product_name).split() if len(w) > 2]
    if len(cleaned_words) > 2:
        queries.append(" ".join(cleaned_words[:3]))
    
    # Deduplicate queries
    queries = list(dict.fromkeys(queries))

    log(f"  [playwright] Launching browser to search. Candidate queries: {queries}")
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

            # Try queries sequentially
            for q in queries:
                log(f"  [playwright] Trying query: {q}")
                payloads.clear()
                query_encoded = quote(q)
                search_url = f"https://alfagift.id/find/{query_encoded}"
                try:
                    await page.goto(search_url, wait_until="domcontentloaded", timeout=20000)
                    await page.wait_for_timeout(2000)  # Wait for AJAX
                except Exception as e:
                    log(f"    [WARN] Navigation failed for query '{q}': {e}")
                    continue

                # Check if we intercepted the SKU in the search results
                for payload in payloads:
                    img_url = _find_image_url_in_json(payload, sku)
                    if img_url:
                        log(f"    [OK] Found image URL for SKU {sku} using query '{q}'")
                        await context.close()
                        await browser.close()
                        return img_url

            await context.close()
            await browser.close()
    except Exception as e:
        log(f"  [playwright] Browser search failed: {e}")
    return None


def fetch_image_for_null_product(product_name: str, sku: str, brand: str | None = None) -> bytes | None:
    """
    Untuk produk yang image_url-nya NULL:
    Cari via Playwright search interception -> ambil image URL dari response JSON.
    """
    import asyncio
    log(f"  [SEARCH] Mencari gambar via Playwright untuk: {product_name}")
    try:
        # Run the async Playwright search in the current thread's loop or a new one
        loop = asyncio.get_event_loop()
    except RuntimeError:
        loop = asyncio.new_event_loop()
        asyncio.set_event_loop(loop)

    img_url = loop.run_until_complete(_fetch_url_playwright_async(product_name, sku, brand))
    if img_url:
        log(f"  [SEARCH] Found image URL: {img_url}")
        # Update database products.image_url first so we don't have to search next time!
        return _http_get_image(img_url)
    return None


IMG_URL_KEYS = (
    "imageUrl", "image_url", "image", "img", "thumbnail",
    "thumbnailUrl", "thumbnail_url", "photo", "picture",
    "productImage", "product_image",
)


def _find_image_url_in_json(payload, sku: str, depth: int = 0) -> str | None:
    """Rekursif cari URL gambar dari payload JSON alfagift."""
    if depth > 8:
        return None
    if isinstance(payload, dict):
        # Cari di preferred keys dulu
        for key in IMG_URL_KEYS:
            val = payload.get(key) or payload.get(key.lower())
            if isinstance(val, str) and val.startswith("http") and (
                ".jpg" in val or ".png" in val or ".webp" in val or "image" in val
            ):
                # Preferensikan URL yang mengandung SKU kita
                if sku in val:
                    return val
                # Atau URL CDN alfagift apapun
                if ALFAGIFT_CDN in val:
                    return val
        # Rekursi ke values
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


# ── Image processing ───────────────────────────────────────────────────────────
def remove_background(img_bytes: bytes) -> bytes:
    """
    Hapus background menggunakan rembg.
    Return PNG bytes dengan transparency.
    """
    from rembg import remove
    return remove(img_bytes)


def process_image(raw_bytes: bytes) -> bytes:
    """
    Pipeline image processing:
    1. rembg → hapus background
    2. Crop ke bounding box non-transparent
    3. Letterbox ke 800x800 (background putih)
    4. Kompres ke ≤500KB JPEG
    Return JPEG bytes.
    """
    from PIL import Image

    # Step 1: Remove background → RGBA PNG
    log(f"  [rembg] Removing background...")
    try:
        no_bg_bytes = remove_background(raw_bytes)
        img = Image.open(io.BytesIO(no_bg_bytes)).convert("RGBA")
    except Exception as e:
        log(f"  [WARN] rembg failed ({e}), falling back to original...")
        img = Image.open(io.BytesIO(raw_bytes)).convert("RGBA")

    # Step 1.5: Filter out template components (banners/sidebars) using connected components analysis
    try:
        import numpy as np
        import scipy.ndimage as ndimage

        alpha = np.array(img.split()[-1])
        mask = alpha > 10  # binary mask threshold

        labeled_mask, num_features = ndimage.label(mask)
        if num_features > 1:
            slices = ndimage.find_objects(labeled_mask)
            component_sizes = ndimage.sum(mask, labeled_mask, range(1, num_features + 1))

            img_h, img_w = mask.shape
            center_y, center_x = img_h / 2, img_w / 2

            scored_components = []
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
                dist = np.sqrt(dist_x**2 + dist_y**2)

                centrality = max(0.0, 1.0 - (dist / 1.414))
                score = size * centrality

                scored_components.append({
                    "label": label,
                    "score": score,
                    "slice": sl
                })

            if scored_components:
                scored_components.sort(key=lambda x: -x["score"])
                best_label = scored_components[0]["label"]
                log(f"  [rembg] Cleared {num_features - 1} isolated template components")

                # Keep only the best component's alpha values, discard the rest
                clean_alpha = np.where(labeled_mask == best_label, alpha, 0).astype(np.uint8)
                r, g, b, _ = img.split()
                img = Image.merge("RGBA", (r, g, b, Image.fromarray(clean_alpha)))
    except Exception as e:
        log(f"  [WARN] Connected component filtering failed: {e}")

    # Step 2: Crop ke bounding box konten (hapus whitespace/transparent border)
    # Gunakan alpha channel sebagai mask; jika tidak ada alpha, convert dulu
    r, g, b, a = img.split()
    bbox = a.getbbox()
    if bbox:
        # Tambah sedikit padding (2% dari ukuran)
        w, h = img.size
        pad_x = int(w * 0.02)
        pad_y = int(h * 0.02)
        x0 = max(0, bbox[0] - pad_x)
        y0 = max(0, bbox[1] - pad_y)
        x1 = min(w, bbox[2] + pad_x)
        y1 = min(h, bbox[3] + pad_y)
        img = img.crop((x0, y0, x1, y1))

    # Step 3: Letterbox ke 800x800 dengan background putih
    canvas = Image.new("RGBA", TARGET_SIZE, (255, 255, 255, 255))
    img_w, img_h = img.size
    scale = min(TARGET_SIZE[0] / img_w, TARGET_SIZE[1] / img_h)
    new_w = int(img_w * scale)
    new_h = int(img_h * scale)
    img_resized = img.resize((new_w, new_h), Image.Resampling.LANCZOS)
    offset_x = (TARGET_SIZE[0] - new_w) // 2
    offset_y = (TARGET_SIZE[1] - new_h) // 2
    canvas.paste(img_resized, (offset_x, offset_y), img_resized)

    # Konversi ke RGB (JPEG tidak support alpha)
    canvas_rgb = canvas.convert("RGB")

    # Step 4: Kompres ke ≤500KB
    quality = 90
    while quality >= 40:
        buf = io.BytesIO()
        canvas_rgb.save(buf, format="JPEG", quality=quality, optimize=True)
        if buf.tell() <= MAX_KB * 1024:
            log(f"  [IMG] Output: 800x800 JPEG, {buf.tell()//1024}KB (quality={quality})")
            return buf.getvalue()
        quality -= 10

    # Fallback: terima ukuran berapapun di quality=40
    buf = io.BytesIO()
    canvas_rgb.save(buf, format="JPEG", quality=40)
    log(f"  [IMG] Output (fallback): {buf.tell()//1024}KB")
    return buf.getvalue()


# ── Log management ─────────────────────────────────────────────────────────────
def load_log() -> dict:
    if LOG_PATH.exists():
        try:
            return json.loads(LOG_PATH.read_text(encoding="utf-8"))
        except Exception:
            return {}
    return {}


def save_log(log_data: dict) -> None:
    LOG_PATH.parent.mkdir(parents=True, exist_ok=True)
    LOG_PATH.write_text(json.dumps(log_data, indent=2, ensure_ascii=False), encoding="utf-8")


def log_entry(
    log_data: dict,
    product_id: str,
    sku: str,
    status: str,
    image_url: str | None = None,
    error: str | None = None,
) -> None:
    entry: dict = {
        "sku": sku,
        "status": status,
        "processed_at": datetime.now(timezone.utc).isoformat(),
    }
    if image_url:
        entry["image_url"] = image_url
    if error:
        entry["error"] = error
    log_data[product_id] = entry
    save_log(log_data)


# ── Fetch products from DB ─────────────────────────────────────────────────────
def fetch_products_to_process() -> list[dict]:
    """
    Query semua produk dari DB lalu filter di Python:
    - image_url IS NULL
    - image_url == ""
    - image_url LIKE '%c.alfagift.id%'
    """
    log("Fetching all products from DB...")
    all_prods = sb_get("products?select=id,name,category,image_url,sku&limit=2000")
    
    combined = []
    for p in all_prods:
        url = p.get("image_url")
        if url is None or url == "" or "c.alfagift.id" in url:
            combined.append(p)
            
    combined.sort(key=lambda x: x["name"])
    log(f"Found {len(combined)} products to process out of {len(all_prods)} total products.")
    return combined


# ── Main pipeline ──────────────────────────────────────────────────────────────
def process_product(
    product: dict,
    log_data: dict,
    dry_run: bool = False,
) -> str:
    """
    Proses satu produk. Return status string.
    """
    pid = product["id"]
    name = product["name"]
    image_url = product.get("image_url")

    log(f"\n{'='*60}")
    log(f"Product: {name}")
    log(f"  ID: {pid}")

    # Ambil SKU langsung dari database, fallback ke image URL parsing
    sku = product.get("sku")
    if not sku or sku == "-":
        sku = extract_sku_from_url(image_url)

    if not sku or sku == "-":
        # Coba ekstrak dari product ID jika formatnya seperti SKU alfagift
        # Format product ID di DB bisa berupa UUID atau SKU
        if re.match(r'^A\d+', pid):
            sku = pid
        else:
            log(f"  [SKIP] Tidak bisa ekstrak SKU")
            log_entry(log_data, pid, "-", "SKIPPED_NO_SKU",
                      error="Tidak bisa ekstrak SKU dari DB, image_url maupun product ID")
            return "SKIPPED"

    log(f"  SKU: {sku or '(unknown)'}")

    if dry_run:
        log(f"  [DRY RUN] Would process")
        return "DRY_RUN"

    # 1. Fetch gambar
    # Strategi: jika produk sudah punya c.alfagift.id URL → fetch langsung (URL sudah ada timestamp)
    #           jika image_url NULL → cari via alfagift search API
    raw_bytes: bytes | None = None
    if image_url and "c.alfagift.id" in image_url:
        raw_bytes = fetch_image_from_existing_url(image_url)
    elif sku and sku != "-":
        raw_bytes = fetch_image_for_null_product(name, sku, product.get("brand"))

    if not raw_bytes:
        log(f"  [ERROR] Tidak bisa fetch gambar")
        log_entry(log_data, pid, sku or "-", "ERROR_NO_IMAGE",
                  error="Fetch gagal: tidak bisa ambil gambar dari CDN maupun search API")
        return "ERROR"

    # 2. Process image (rembg + crop + resize + compress)
    try:
        processed_bytes = process_image(raw_bytes)
    except Exception as e:
        log(f"  [ERROR] Image processing gagal: {e}")
        log_entry(log_data, pid, sku, "ERROR_PROCESSING", error=str(e))
        return "ERROR"

    # 3. Upload ke Supabase Storage
    storage_path = f"products/{pid}/{uuid4().hex}.jpg"
    log(f"  [UPLOAD] Uploading ke Supabase Storage: {storage_path}")
    try:
        public_url = sb_storage_upload(storage_path, processed_bytes, "image/jpeg")
    except Exception as e:
        log(f"  [ERROR] Upload ke Storage gagal: {e}")
        log_entry(log_data, pid, sku, "ERROR_UPLOAD", error=str(e))
        return "ERROR"

    # 4. Update DB
    log(f"  [DB] Updating products.image_url...")
    try:
        sb_patch("products", f"id=eq.{pid}", {"image_url": public_url})
    except Exception as e:
        log(f"  [ERROR] Update DB gagal: {e}")
        log_entry(log_data, pid, sku, "ERROR_DB_UPDATE",
                  image_url=public_url, error=str(e))
        return "ERROR"

    log(f"  [SUCCESS] {public_url}")
    log_entry(log_data, pid, sku, "SUCCESS", image_url=public_url)
    return "SUCCESS"


def main():
    parser = argparse.ArgumentParser(
        description="Automasi pipeline gambar produk WorthIt"
    )
    parser.add_argument(
        "--limit", type=int, default=None,
        help="Batasi jumlah produk yang diproses (untuk batch/test)"
    )
    parser.add_argument(
        "--skip", type=int, default=0,
        help="Skip N produk pertama (untuk lanjut dari batch sebelumnya)"
    )
    parser.add_argument(
        "--dry-run", action="store_true",
        help="Preview produk yang akan diproses tanpa upload"
    )
    parser.add_argument(
        "--product-id", type=str, default=None,
        help="Proses hanya satu produk tertentu (by product_id)"
    )
    args = parser.parse_args()

    # Load resume log
    log_data = load_log()
    already_done = {pid for pid, e in log_data.items() if e["status"] == "SUCCESS"}
    log(f"Resume log: {len(already_done)} produk sudah SUCCESS, {len(log_data)} total entries")

    # Fetch products
    if args.product_id:
        products = [p for p in fetch_products_to_process() if p["id"] == args.product_id]
    else:
        products = fetch_products_to_process()

    # Filter yang sudah sukses (resume)
    products = [p for p in products if p["id"] not in already_done]
    log(f"Setelah filter resume: {len(products)} produk yang perlu diproses")

    # Apply skip & limit
    if args.skip:
        products = products[args.skip:]
    if args.limit:
        products = products[:args.limit]

    log(f"\nAkan memproses {len(products)} produk" +
        (" [DRY RUN]" if args.dry_run else ""))

    # Tampilkan daftar produk yang akan diproses
    log("\nDaftar produk:")
    for i, p in enumerate(products, 1):
        sku_from_url = extract_sku_from_url(p.get("image_url"))
        log(f"  {i:3}. {p['name'][:55]}")
        log(f"       ID={p['id'][:20]}... | SKU={sku_from_url or '?'} | category={p['category']}")

    if args.dry_run:
        log("\n[DRY RUN] Selesai. Tidak ada yang diupload.")
        return

    # Konfirmasi sebelum jalan (hanya untuk batch besar)
    if not args.limit or args.limit > 20:
        confirm = input(f"\nLanjut proses {len(products)} produk? (y/N): ")
        if confirm.lower() != 'y':
            log("Dibatalkan.")
            return

    # Process
    stats = {"SUCCESS": 0, "ERROR": 0, "SKIPPED": 0}
    for i, product in enumerate(products, 1):
        log(f"\n[{i}/{len(products)}]")
        status = process_product(product, log_data, dry_run=args.dry_run)
        if status in stats:
            stats[status] += 1
        time.sleep(CDN_DELAY_S)  # polite delay

    # Summary
    log(f"\n{'='*60}")
    log("SELESAI!")
    log(f"  SUCCESS : {stats['SUCCESS']}")
    log(f"  SKIPPED : {stats['SKIPPED']}")
    log(f"  ERROR   : {stats['ERROR']}")
    log(f"\nLog tersimpan di: {LOG_PATH}")


if __name__ == "__main__":
    main()
