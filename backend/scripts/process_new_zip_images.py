#!/usr/bin/env python3
"""
process_new_zip_images.py
Ekstrak, optimasi (letterbox 800x800 + kompresi JPEG), dan unggah gambar baru dari 5 berkas ZIP ke Supabase.
"""
from __future__ import annotations

import argparse
import io
import json
import os
import re
import ssl
import sys
import zipfile
from datetime import datetime, timezone
from pathlib import Path
from uuid import uuid4
import urllib.request
from PIL import Image

# ── Config ──────────────────────────────────────────────────────────────────
SCRIPT_DIR    = Path(__file__).resolve().parent
PROJECT_ROOT  = SCRIPT_DIR.parent
LOG_PATH      = PROJECT_ROOT / "data" / "new_zip_images_log.json"

ZIP_PATHS = [
    PROJECT_ROOT.parent / "kebutuhan rumah.zip",
    PROJECT_ROOT.parent / "kesehatan dan kebersihan.zip",
    PROJECT_ROOT.parent / "makanan ringan makanan beku bumbu dapur.zip",
    PROJECT_ROOT.parent / "minuman.zip",
    PROJECT_ROOT.parent / "sembako.zip"
]

SUPABASE_URL  = "https://nyjojldhvpufxesplrtk.supabase.co"
SUPABASE_SKEY = (
    "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9"
    ".eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im55am9qbGRodnB1Znhlc3BscnRrIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc3ODQxMTY1OCwiZXhwIjoyMDkzOTg3NjU4fQ"
    ".KlXI_YpE58JL3cZX6MfaYNzr08UvQ9aOXhBeWLDbw5M"
)
BUCKET = "product-images"
TARGET_SIZE = (800, 800)
MAX_KB = 500
_CTX = ssl.create_default_context()

# ── Manual Mapping for typos ──────────────────────────────────────────────────
MANUAL_MAPPING = {
    "duogo minyak goreng jagung botol 1 l": "Dougo Minyak Goreng Jagung Botol 1 L",
    "mama shrimp creamy tom yum flavour instand noodle 90 g": "MAMA Shrimp Creamy Tom Yum Flavour Instant Noodle 90 g",
    "samyang mi instan ramen buldak karbonara ayam pedas 140 g": "Samyang Mi Instan Ramen Buldak Krim Karbonara Ayam Pedas 140 g",
    "naraya salted cheese cookies 90 g": "Naraya Salted Chese Cookies 90 g",
    "bokashi minyak oles 12 ml": "Bokasi Minyak Oles 12 ml",
    "bean spot es kopi capuccino": "Bean Spot Es Kopi Cappuccino",
    "ultra milk susu uht coklat kotak 750 ml": "Ultra Milk Susu UHT Cokelat Kotak 750 ml",
    "ultra milk susu uht rendah lemah cokelat kotak 1 l": "Ultra Milk Susu UHT Rendah Lemak Cokelat Kotak 1 L",
    "ultra milk susu uht rendah lemah cokelat kotak 250 ml": "Ultra Milk Susu UHT Rendah Lemak Cokelat Kotak 250 ml",
}

# ── Logging utils ─────────────────────────────────────────────────────────────
def log(msg: str) -> None:
    ts = datetime.now(timezone.utc).strftime("%H:%M:%S")
    safe = msg.encode("ascii", "replace").decode("ascii")
    print(f"[{ts}] {safe}", flush=True)

# ── Supabase helpers ──────────────────────────────────────────────────────────
def get_all_products() -> list:
    url = f"{SUPABASE_URL}/rest/v1/products?select=id,name,category"
    req = urllib.request.Request(url, headers={
        "apikey": SUPABASE_SKEY,
        "Authorization": f"Bearer {SUPABASE_SKEY}",
        "Accept": "application/json",
    })
    try:
        with urllib.request.urlopen(req, timeout=30, context=_CTX) as r:
            return json.loads(r.read())
    except Exception as e:
        log(f"[ERROR] Failed fetching products: {e}")
        return []

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

# ── Text helpers ──────────────────────────────────────────────────────────────
def clean_name(name: str) -> str:
    n = name.split("/")[-1].split("\\")[-1]
    n = re.sub(r"\.(png|jpg|jpeg)$", "", n, flags=re.IGNORECASE)
    n = n.lower().strip()
    n = re.sub(r"[^a-z0-9\s]", " ", n)
    return " ".join(n.split())

# ── Image processing (letterbox + compress only, no rembg) ────────────────────
def letterbox_image(img: Image.Image) -> bytes:
    """
    Menyusun gambar agar pas di canvas 800x800 putih dengan menjaga aspect ratio
    tanpa merusak/merentangkan (stretch) gambar.
    """
    img_w, img_h = img.size
    
    # Hitung rasio skala yang pas
    scale = min(TARGET_SIZE[0] / img_w, TARGET_SIZE[1] / img_h)
    new_w = max(1, int(img_w * scale))
    new_h = max(1, int(img_h * scale))
    
    # Resize menggunakan resampling berkualitas tinggi (LANCZOS)
    img_resized = img.resize((new_w, new_h), Image.Resampling.LANCZOS)
    
    # Buat canvas putih
    canvas = Image.new("RGBA", TARGET_SIZE, (255, 255, 255, 255))
    
    # Hitung posisi tengah (center)
    offset_x = (TARGET_SIZE[0] - new_w) // 2
    offset_y = (TARGET_SIZE[1] - new_h) // 2
    
    # Tempelkan ke canvas (gunakan alpha channel sebagai mask jika ada)
    if img_resized.mode == 'RGBA':
        canvas.paste(img_resized, (offset_x, offset_y), img_resized)
    else:
        canvas.paste(img_resized, (offset_x, offset_y))
        
    canvas_rgb = canvas.convert("RGB")
    
    # Kompresi berkualitas tinggi (mulai dari 95 agar kualitas tetap maksimal)
    quality = 95
    while quality >= 40:
        buf = io.BytesIO()
        canvas_rgb.save(buf, format="JPEG", quality=quality, optimize=True)
        if buf.tell() <= MAX_KB * 1024:
            return buf.getvalue()
        quality -= 5
        
    buf = io.BytesIO()
    canvas_rgb.save(buf, format="JPEG", quality=40)
    return buf.getvalue()

# ── Main logic ────────────────────────────────────────────────────────────────
def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--dry-run", action="store_true", help="Simulasi pemetaan saja tanpa upload/update database")
    args = parser.parse_args()

    log("Fetching all products from Supabase...")
    products = get_all_products()
    log(f"Fetched {len(products)} products from database.")

    # Create clean DB map {clean_name: product_info}
    db_map = {}
    for p in products:
        c = clean_name(p["name"])
        db_map[c] = p

    # Find ZIP contents
    log("Scanning ZIP files...")
    matched_jobs = []
    unmatched_files = []

    for z_path in ZIP_PATHS:
        if not z_path.exists():
            log(f"[WARN] ZIP file not found: {z_path}")
            continue
        
        log(f"Reading {z_path.name}...")
        with zipfile.ZipFile(z_path, 'r') as z:
            for zip_member_path in z.namelist():
                # Skip directory entries
                if zip_member_path.endswith('/'):
                    continue
                
                c_file = clean_name(zip_member_path)
                
                # Check manual mapping first
                db_name = MANUAL_MAPPING.get(c_file)
                db_prod = None
                
                if db_name:
                    c_db_mapped = clean_name(db_name)
                    db_prod = db_map.get(c_db_mapped)
                else:
                    db_prod = db_map.get(c_file)
                    # If not exact match, try fuzzy matching (is clean file name contained in any clean DB name or vice-versa)
                    if not db_prod:
                        for c_db, p in db_map.items():
                            if c_file == c_db or (len(c_file) > 8 and (c_file in c_db or c_db in c_file)):
                                db_prod = p
                                break
                
                if db_prod:
                    matched_jobs.append({
                        "zip_path": z_path,
                        "zip_member": zip_member_path,
                        "product_id": db_prod["id"],
                        "product_name": db_prod["name"],
                        "product_category": db_prod["category"]
                    })
                else:
                    # Ignore cigarette products from unmatched files output (since they're deleted)
                    if "rokok" not in c_file and "kretek" not in c_file and "caffe latte 12" not in c_file:
                        unmatched_files.append((z_path.name, zip_member_path))

    log(f"\nAudit Summary:")
    log(f"  Total matched jobs : {len(matched_jobs)}")
    log(f"  Unmatched files    : {len(unmatched_files)}")

    if unmatched_files:
        log("\nUnmatched files details (excluding cigarettes):")
        for z_name, member in unmatched_files:
            log(f"  - [{z_name}] {member}")

    if args.dry_run:
        log("\nDry-run complete. No changes were made.")
        return

    # Execute uploads and DB patches
    log("\nExecuting image processing, upload and DB update...")
    success_count = 0
    error_count = 0
    processed_log = {}

    for idx, job in enumerate(matched_jobs, 1):
        z_path = job["zip_path"]
        zip_member = job["zip_member"]
        pid = job["product_id"]
        pname = job["product_name"]

        log(f"[{idx}/{len(matched_jobs)}] Processing: {pname}")
        log(f"  ZIP: {z_path.name} | File: {zip_member}")

        # Extract file in memory
        try:
            with zipfile.ZipFile(z_path, 'r') as z:
                raw_bytes = z.read(zip_member)
        except Exception as e:
            log(f"  [ERROR] Failed reading file from ZIP: {e}")
            error_count += 1
            continue

        # Load with PIL
        try:
            img = Image.open(io.BytesIO(raw_bytes))
            # Force load image pixels
            img.verify()
            # Reopen because verify() makes image unusable
            img = Image.open(io.BytesIO(raw_bytes))
        except Exception as e:
            log(f"  [ERROR] Image file is corrupt or unreadable: {e}")
            error_count += 1
            continue

        # Process image
        try:
            processed_bytes = letterbox_image(img)
        except Exception as e:
            log(f"  [ERROR] Failed to letterbox/compress image: {e}")
            error_count += 1
            continue

        # Upload to Supabase Storage
        storage_path = f"products/{pid}/{uuid4().hex}.jpg"
        log(f"  [UPLOAD] Uploading to {storage_path}...")
        try:
            public_url = sb_storage_upload(storage_path, processed_bytes, "image/jpeg")
        except Exception as e:
            log(f"  [ERROR] Storage upload failed: {e}")
            error_count += 1
            continue

        # Update DB
        log(f"  [DB] Updating image_url...")
        try:
            sb_patch("products", f"id=eq.{pid}", {"image_url": public_url})
            log(f"  [SUCCESS] Updated image URL to {public_url}")
            success_count += 1
            processed_log[pid] = {
                "name": pname,
                "status": "SUCCESS",
                "image_url": public_url,
                "processed_at": datetime.now(timezone.utc).isoformat()
            }
        except Exception as e:
            log(f"  [ERROR] Database update failed: {e}")
            error_count += 1
            continue

    # Write log
    LOG_PATH.parent.mkdir(parents=True, exist_ok=True)
    with open(LOG_PATH, "w", encoding="utf-8") as f:
        json.dump(processed_log, f, indent=2, ensure_ascii=False)

    log(f"\nProcess Complete:")
    log(f"  Success : {success_count}")
    log(f"  Errors  : {error_count}")
    log(f"Log written to {LOG_PATH}")

if __name__ == "__main__":
    main()
