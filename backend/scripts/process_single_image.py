#!/usr/bin/env python3
"""
process_single_image.py
Membaca gambar lokal NEO Coffee Tiramisu dan langsung mengunggahnya ke Supabase Storage, lalu mengupdate link DB.
"""
from __future__ import annotations

import json
import ssl
import sys
from pathlib import Path
from uuid import uuid4
import urllib.request

# ── Config ──────────────────────────────────────────────────────────────────
SCRIPT_DIR    = Path(__file__).resolve().parent
PROJECT_ROOT  = SCRIPT_DIR.parent
IMAGE_PATH    = PROJECT_ROOT.parent / "NEO Coffee 3 in 1 Kopi Tiramisu Sachet 9 x 20 g.jpg"

SUPABASE_URL  = "https://nyjojldhvpufxesplrtk.supabase.co"
SUPABASE_SKEY = (
    "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9"
    ".eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im55am9qbGRodnB1Znhlc3BscnRrIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc3ODQxMTY1OCwiZXhwIjoyMDkzOTg3NjU4fQ"
    ".KlXI_YpE58JL3cZX6MfaYNzr08UvQ9aOXhBeWLDbw5M"
)
BUCKET = "product-images"
_CTX = ssl.create_default_context()

PRODUCT_ID = "2586d09b-2dfe-475a-adb2-7a552358a742"
PRODUCT_NAME = "NEO Coffee 3 in 1 Kopi Tiramisu Sachet 9 x 20 g"

# ── Logging utils ─────────────────────────────────────────────────────────────
def log(msg: str) -> None:
    print(f"[{datetime.now().strftime('%H:%M:%S') if 'datetime' in globals() else 'LOG'}] {msg}", flush=True)

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

def main():
    if not IMAGE_PATH.exists():
        print(f"ERROR: Image file not found at {IMAGE_PATH}")
        sys.exit(1)

    print(f"Processing single image migration for: {PRODUCT_NAME}")
    print(f"  Source file: {IMAGE_PATH}")
    print(f"  Target ID  : {PRODUCT_ID}")

    # Read bytes directly
    try:
        raw_bytes = IMAGE_PATH.read_bytes()
        print(f"  Successfully read {len(raw_bytes)//1024}KB raw bytes.")
    except Exception as e:
        print(f"  ERROR: Failed to read image file: {e}")
        sys.exit(1)

    # Upload to Supabase Storage
    storage_path = f"products/{PRODUCT_ID}/{uuid4().hex}.jpg"
    print(f"  Uploading directly to Storage path: {storage_path}...")
    try:
        public_url = sb_storage_upload(storage_path, raw_bytes, "image/jpeg")
        print(f"  [SUCCESS] Uploaded to public URL: {public_url}")
    except Exception as e:
        print(f"  ERROR: Supabase Storage upload failed: {e}")
        sys.exit(1)

    # Update database
    print("  Updating image_url in DB products table...")
    try:
        sb_patch("products", f"id=eq.{PRODUCT_ID}", {"image_url": public_url})
        print(f"  [SUCCESS] Database image_url updated successfully.")
    except Exception as e:
        print(f"  ERROR: Database update failed: {e}")
        sys.exit(1)

    print("\nMigration completed successfully!")
    print(f"Verify new image link: {public_url}")

if __name__ == "__main__":
    main()
