#!/usr/bin/env python3
"""
process_revisi_images.py
Ekstrak dan unggah gambar revisi terakhir secara langsung (tanpa pemrosesan/letterboxing) ke Supabase.
"""
from __future__ import annotations

import argparse
import io
import json
import ssl
import sys
import zipfile
from datetime import datetime, timezone
from pathlib import Path
from uuid import uuid4
import urllib.request

# ── Config ──────────────────────────────────────────────────────────────────
SCRIPT_DIR    = Path(__file__).resolve().parent
PROJECT_ROOT  = SCRIPT_DIR.parent
LOG_PATH      = PROJECT_ROOT / "data" / "revisi_images_log.json"
ZIP_PATH      = PROJECT_ROOT.parent / "REVISIGAMBARTERAKHIR.zip"

SUPABASE_URL  = "https://nyjojldhvpufxesplrtk.supabase.co"
SUPABASE_SKEY = (
    "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9"
    ".eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im55am9qbGRodnB1Znhlc3BscnRrIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc3ODQxMTY1OCwiZXhwIjoyMDkzOTg3NjU4fQ"
    ".KlXI_YpE58JL3cZX6MfaYNzr08UvQ9aOXhBeWLDbw5M"
)
BUCKET = "product-images"
_CTX = ssl.create_default_context()

# ── 28 Products Mapping ───────────────────────────────────────────────────────
REVISI_MAPPING = {
    1: {"name": "Alfamart Gula Pasir Lokal Putih 1 kg", "id": "89e5453c-53d0-40b5-9e99-8b5d780f7f04"},
    2: {"name": "Alfamart Minyak Goreng Pouch 2 L", "id": "17f87c23-9605-4623-8d80-d09af19b84b2"},
    3: {"name": "MAMA Instant Pad Thai Instant Noodle 70 g", "id": "cfc4f8fc-d7fc-4cf3-bb79-ed5908be8e5e"},
    4: {"name": "Samyang Mi Instan Ramen Ayam Pedas Original 140 g", "id": "c896f8a9-51db-42ee-a274-b9afb484f682"},
    5: {"name": "Bika Crackers Rasa Udang 70 g", "id": "136a4d2b-22f0-431b-82ae-e882df7b03f8"},
    6: {"name": "Biskuat Biskuit Original 106.4 g", "id": "08b10ec0-3275-4fbb-8204-f8c2b213de40"},
    7: {"name": "Cadbury Dairy Milk Cokelat Susu 22 g", "id": "f2d552ae-ad6f-4e16-93bd-a48d8e16b01d"},
    8: {"name": "Cadbury Dairy Milk Cokelat Susu 52 g", "id": "f016a9ae-b23f-4aaa-b998-e017767ad167"},
    9: {"name": "Cadbury Dairy Milk Cokelat Susu Aerasi Bubbly 46 g", "id": "aa176033-6b4d-43ce-b7a5-ec3e201e5d44"},
    10: {"name": "Cadbury Dairy Milk Cokelat Susu Almond Panggang 52 g", "id": "a2856978-67f1-4eee-b507-3b0859e7c18f"},
    11: {"name": "Cadbury Dairy Milk Cokelat Susu Black Forest 52 g", "id": "77285a76-08ad-43d4-bf95-479a79a4e2b7"},
    12: {"name": "Cadbury Dairy Milk Cokelat Susu Cashew Nut 22 g", "id": "680f0b0f-fee9-4f68-b6f4-f7640d21c6ae"},
    13: {"name": "Cadbury Dairy Milk Cokelat Susu Cashew Nut 52 g", "id": "255d697a-a9e6-46ad-8cb8-fabcdba2d99f"},
    14: {"name": "Cadbury Dairy Milk Cokelat Susu Cashew Nut 85 g", "id": "b1a1dad3-4c64-4f70-8ac2-e90a620a6da1"},
    15: {"name": "Cadbury Dairy Milk Cokelat Susu Fruit & Nut 52 g", "id": "b833fb7a-7af7-4d18-83a8-8c4cd6a1b804"},
    16: {"name": "Cadbury Dairy Milk Cokelat Susu Hazelnut 52 g", "id": "7aadb576-edea-4f55-be42-5dabfa384721"},
    17: {"name": "Cadbury Dairy Milk Mini Bars Cokelat Susu Oreo 80.5 g", "id": "51842a9e-8820-48c1-abe9-8f1356cbb25e"},
    18: {"name": "Faber-Castell Krayon Oil Pastel 12 pcs", "id": "52aaa44d-22ed-4b4e-9d1b-96b14ace62ff"},
    19: {"name": "Cimory Yogurt Squeeze Brown Sugar 120 g", "id": "9fc59375-9e7c-4572-a464-32a5030915ff"},
    20: {"name": "Diamond Susu UHT All Purpose Milk Plain 1 L", "id": "85fa9c4a-28c8-4cf6-beaa-606212faf3e0"},
    21: {"name": "Fruit Tea Minuman Teh Apel 500 ml", "id": "f02b8772-f305-4192-9440-4edca4f16c34"},
    22: {"name": "Ichitan Candy Cloud Milk Minuman Susu Cotton Candy 300 ml", "id": "6c443faa-0011-453f-a4ea-0859fa0aea6c"},
    23: {"name": "Kopi Kenangan Minuman Kopi Banana Milk Latte 210 ml", "id": "aab6cda7-0e89-4fbf-861d-48fce8065ba4"},
    24: {"name": "SariWangi Teh Celup Hitam Asli 50 s", "id": "6ed25aa8-b56c-4101-8dc4-3fce3faf7fa0"},
    25: {"name": "SariWangi Minuman Serbuk Teh Earl Grey Milk Tea 5 x 22 g", "id": "ed573885-4b80-4b5e-b7c6-f7923307d9ca"},
    26: {"name": "Tropicana Slim Minuman White Coffee Sachet 4 x 15 g", "id": "26cae464-5c2b-4071-bb06-fbf9eb837120"},
    27: {"name": "Ultra Milk Susu UHT Rendah Lemak Kotak 250 ml", "id": "5e80bdbe-dd62-40f3-8135-679b92690923"},
    28: {"name": "Ultra Milk Susu UHT Taro Kotak 200 ml", "id": "0f31d5d0-48fc-43ec-9a7a-48b804ad2513"},
}

# ── Logging utils ─────────────────────────────────────────────────────────────
def log(msg: str) -> None:
    ts = datetime.now(timezone.utc).strftime("%H:%M:%S")
    safe = msg.encode("ascii", "replace").decode("ascii")
    print(f"[{ts}] {safe}", flush=True)

# ── Supabase helpers ──────────────────────────────────────────────────────────
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

# ── Main logic ────────────────────────────────────────────────────────────────
def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--dry-run", action="store_true", help="Simulasi pemetaan saja tanpa upload/update database")
    args = parser.parse_args()

    if not ZIP_PATH.exists():
        log(f"[ERROR] ZIP file not found: {ZIP_PATH}")
        sys.exit(1)

    log(f"Scanning ZIP file {ZIP_PATH.name}...")
    with zipfile.ZipFile(ZIP_PATH, 'r') as z:
        zip_files = z.namelist()

    # Dry run / pre-check mapping
    jobs = []
    for idx in range(1, 29):
        filename = f"{idx}.jpg"
        if filename not in zip_files:
            log(f"[ERROR] File {filename} missing from ZIP!")
            sys.exit(1)
        
        info = REVISI_MAPPING.get(idx)
        if not info:
            log(f"[ERROR] Mapping missing for index {idx}!")
            sys.exit(1)
            
        jobs.append({
            "index": idx,
            "filename": filename,
            "product_id": info["id"],
            "product_name": info["name"]
        })

    log(f"All {len(jobs)} mappings verified successfully.")

    if args.dry_run:
        log("\nDry-run complete. No changes were made.")
        return

    # Process and upload directly (raw bytes)
    success_count = 0
    error_count = 0
    processed_log = {}

    log("\nExecuting raw upload to Supabase and DB update...")
    for job in jobs:
        idx = job["index"]
        filename = job["filename"]
        pid = job["product_id"]
        name = job["product_name"]

        log(f"[{idx}/28] Processing: {name} ({filename})")

        # Read original bytes directly
        try:
            with zipfile.ZipFile(ZIP_PATH, 'r') as z:
                raw_bytes = z.read(filename)
        except Exception as e:
            log(f"  [ERROR] Failed to read ZIP member: {e}")
            error_count += 1
            continue

        # Upload directly to Supabase
        storage_path = f"products/{pid}/{uuid4().hex}.jpg"
        log(f"  [UPLOAD] Uploading raw bytes to {storage_path}...")
        try:
            public_url = sb_storage_upload(storage_path, raw_bytes, "image/jpeg")
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
                "name": name,
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

    log(f"\nRevisions Complete:")
    log(f"  Success : {success_count} / 28")
    log(f"  Errors  : {error_count}")
    log(f"Log written to {LOG_PATH}")

if __name__ == "__main__":
    main()
