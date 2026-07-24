#!/usr/bin/env python3
"""
restore_original_images.py
Mengembalikan 151 produk yang sempat diproses di fix_red_banner.py
kembali ke image_url asli mereka dari banner_detected.json.
"""
from __future__ import annotations

import json
import ssl
import sys
import urllib.request
from pathlib import Path

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
_CTX = ssl.create_default_context()

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
    if not DETECT_PATH.exists():
        print(f"ERROR: {DETECT_PATH} tidak ditemukan. Tidak ada data untuk restore.")
        sys.exit(1)

    with open(DETECT_PATH, encoding="utf-8") as f:
        flagged = json.load(f)

    if not flagged:
        print("Tidak ada produk dalam list banner_detected.json untuk dikembalikan.")
        sys.exit(0)

    print(f"============================================================")
    print(f"Memulai pemulihan {len(flagged)} produk ke gambar asli...")
    print(f"============================================================\n")

    restored = 0
    errors = 0
    total = len(flagged)

    for idx, (pid, info) in enumerate(flagged.items(), 1):
        name = info["name"]
        old_url = info["image_url"]

        print(f"[{idx}/{total}] Restoring: {name}")
        print(f"  ID: {pid}")
        print(f"  Old URL: {old_url}")

        try:
            sb_patch("products", f"id=eq.{pid}", {"image_url": old_url})
            print(f"  [SUCCESS] Berhasil dikembalikan.")
            restored += 1
        except Exception as e:
            print(f"  [ERROR] Gagal melakukan restore: {e}")
            errors += 1

    # Bersihkan file log fix
    if FIX_LOG_PATH.exists():
        try:
            FIX_LOG_PATH.unlink()
            print("\nBerkas banner_fix_log.json berhasil dihapus.")
        except Exception as e:
            print(f"\nGagal menghapus banner_fix_log.json: {e}")

    print(f"\n============================================================")
    print(f"PEMULIHAN SELESAI")
    print(f"  Berhasil dikembalikan : {restored}")
    print(f"  Gagal                 : {errors}")
    print(f"============================================================")

if __name__ == "__main__":
    main()
