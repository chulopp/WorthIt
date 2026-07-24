#!/usr/bin/env python3
import os
import sys
import zipfile
import uuid
from pathlib import Path

# Add scripts directory to path to import from auto_image_pipeline
SCRIPT_DIR = Path(__file__).resolve().parent
sys.path.append(str(SCRIPT_DIR))

# Import constants and helpers from auto_image_pipeline
import auto_image_pipeline as pipeline

ZIP_PATH = Path(r"d:\Fallah's File\Code\Personal Project\WorthIt\GAMBAR38PRODUK.zip")
TEMP_EXTRACT_DIR = SCRIPT_DIR / "temp_gambar38"

PRODUCT_IDS = [
    "25299298-bc24-4062-bcbf-c61f1660d828", # 1. ABC Kecap Manis Pouch 520 ml
    "4b68071a-4e07-4b3d-9418-83cf57b56187", # 2. Aqua Air Mineral Botol 600 ml
    "0f21cdf5-d0b9-4f6c-b02e-ab6bc807d25b", # 3. Bango Kecap Manis Pouch 520 ml
    "23376710-0794-4426-a9d9-462e3a3a7ea1", # 4. Bear Brand Susu Steril Kaleng 189 ml Unique
    "ff416a83-ceb7-428f-a604-591db98ec680", # 5. Beng-Beng Chocolate Wafer Double Caramel 32 g
    "9060c28d-bcde-491e-8734-d78f2ca6b821", # 6. Bertolli Minyak Zaitun Ekstra Virgin 250 ml
    "7ea9ec86-427b-4a80-9285-b5b038a9ed95", # 7. Bimoli Minyak Goreng Pouch 2 L Unique
    "1799f6e1-f155-474a-9aa3-d01b4faa3218", # 8. Chitato Keripik Kentang Sapi Panggang 68 g
    "851e594b-d0ef-41db-8c8a-539681f36416", # 9. Ekonomi Sabun Cuci Piring Jeruk Nipis 670 g
    "a29be617-8f4b-4174-b2d7-87d9575c783c", # 10. Hydro Coco Air Kelapa Original Tetrapak 250 ml
    "9f8d2e9b-b000-4db2-9392-6ed7db0b20c3", # 11. Indofood Bumbu Racik Nasi Goreng 20 g
    "75d5e387-f61f-4470-8d6b-b88fe90b7b89", # 12. Indomie Mi Instan Goreng Spesial 85 g
    "10fd6732-d03f-45a6-884c-28510e4984a3", # 13. Kopiko Lucky Day Kopi Susu Botol 250 ml
    "4d653722-c319-4387-917e-01957e8d76d3", # 14. Kusuka Keripik Singkong Barbeque 180 g
    "1aa0d92f-dc9e-463e-8b50-e346efd7e602", # 15. Luwak White Koffie Premium Less Sugar 9 s
    "26627b9b-a850-4b1e-a1f8-3b0bd27f8256", # 16. Mama Lemon Sabun Pencuci Piring Cair Jeruk Nipis 680 ml
    "00be95f1-1a6f-4535-b958-106252dd95b8", # 17. Masako Kaldu Sapi Pouch 250 g
    "39e404c7-1ff7-432b-9c82-2a99cc302b78", # 18. Mentos Permen Anggur Roll 37 g
    "dfb38087-5f0c-47f0-92ff-20f7451c5efd", # 19. Milo Minuman Cokelat UHT Kotak 180 ml
    "ce57de05-23a7-47e3-9659-994a527185c8", # 20. Molto Trika Pelicin & Pewangi Pakaian Pure Refill 300 ml
    "ff0dfc5d-90a4-4e2e-8801-535742abfe19", # 21. Motherlove Eazy Baby Oil 2 in 1 Minyak Aromaterapi Bayi Organik 10 ml
    "ff6aabcc-6a8d-4f4a-a393-c95ca8daf032", # 22. Oreo Biskuit Sandwich Chocolate Cream 119 g
    "72c62dce-3472-4e70-a052-c4e1ebcea975", # 23. Pepsodent Pasta Gigi Pencegah Gigi Berlubang 190 g
    "83105906-c5a9-4d54-acd7-a693373fd2d7", # 24. Pocari Sweat Isotonik Botol 500 ml
    "6b4a8f11-ace7-4193-a350-c6b686003674", # 25. Rexona Roll On Men Invisible Dry 50 ml
    "3326fba6-2ca6-4cd9-ad72-11d3605d71d4", # 26. Rinso Deterjen Bubuk Anti Noda Classic 770 g
    "df40c567-ab73-43f1-9796-30c4ca7f34f8", # 27. Roma Biskuit Kelapa 300 g
    "48dddcf6-d3c5-4f58-812b-810d05163fb0", # 28. Roma Wafer Wafello Caramel Blast 117 g
    "623d3e24-afa1-4b75-a98e-9b469c224ca0", # 29. Royco Kaldu Ayam Pouch 220 g
    "8f4bbb42-b24f-43ac-a8d0-103c5a7b4cd9", # 30. Sasa Tepung Bumbu Serbaguna Pouch 225 g
    "6189f9b0-99e5-4aee-8388-10d2d8772e65", # 31. Sedaap Mie Instan Goreng 90 g
    "8b624c83-2573-42d1-8250-afcaaf44016e", # 32. Sedaap Mie Instan Kari Ayam 75 g
    "b1fc09ef-7270-41b9-a44c-1fe96843a990", # 33. Sedaap Mie Instan Soto 75 g
    "3a65d661-6538-45f1-bbdf-19a7e3f83da9", # 34. So Klin Deterjen Cair Antiseptic Pouch 700 ml
    "cb83ae41-7fb3-408a-b7f3-1a612eb7d0fe", # 35. Sprite Minuman Soda Lemon Lime Botol 250 ml
    "0ce30071-f912-4aab-87ed-e60584d037d0", # 36. Sunlight Sabun Pencuci Piring Cair Jeruk Nipis 700 ml
    "a3cd7f5f-207e-4c1b-a14d-cba7ee47e916", # 37. Teh Botol Sosro Kotak 250 ml
    "bc2dd289-a7cc-4cd9-9c5b-f43c5e4326da"  # 38. Teh Pucuk Harum Minuman Teh Melati Botol 350 ml
]

def main():
    if not ZIP_PATH.exists():
        print(f"Error: ZIP file not found at {ZIP_PATH}")
        sys.exit(1)

    print("Extracting ZIP contents...")
    TEMP_EXTRACT_DIR.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(ZIP_PATH, 'r') as zip_ref:
        zip_ref.extractall(TEMP_EXTRACT_DIR)
        file_list = zip_ref.namelist()

    process_count = min(len(file_list), len(PRODUCT_IDS))
    print(f"Ready to upload {process_count} raw images directly.")
    
    log_data = pipeline.load_log()
    success = 0
    errors = 0

    for idx in range(process_count):
        filename = file_list[idx]
        pid = PRODUCT_IDS[idx]
        file_path = TEMP_EXTRACT_DIR / filename

        print(f"\n============================================================")
        print(f"[{idx+1}/{process_count}] Uploading Raw File: '{filename}'")
        print(f"  Target Product ID: {pid}")

        if not file_path.exists():
            print(f"  [ERROR] File not found: {file_path}")
            pipeline.log_entry(log_data, pid, "-", "ERROR_FILE_NOT_FOUND", error="File tidak ditemukan")
            errors += 1
            continue

        # 1. Read local image bytes
        try:
            with open(file_path, 'rb') as f:
                raw_bytes = f.read()
            print(f"  [OK] Read {len(raw_bytes)//1024}KB raw image")
        except Exception as e:
            print(f"  [ERROR] Gagal membaca file: {e}")
            pipeline.log_entry(log_data, pid, "-", "ERROR_FILE_READ", error=str(e))
            errors += 1
            continue

        # 2. Determine file extension and content type
        ext = file_path.suffix.lower()
        content_type = "image/png" if ext == ".png" else "image/jpeg"

        # 3. Upload to Supabase Storage as raw file
        storage_path = f"products/{pid}/{uuid.uuid4().hex}{ext}"
        print(f"  [UPLOAD] Uploading raw to Supabase Storage: {storage_path} ({content_type})")
        try:
            public_url = pipeline.sb_storage_upload(storage_path, raw_bytes, content_type)
        except Exception as e:
            print(f"  [ERROR] Upload ke Storage gagal: {e}")
            pipeline.log_entry(log_data, pid, "-", "ERROR_UPLOAD", error=str(e))
            errors += 1
            continue

        # 4. Update Database
        print(f"  [DB] Updating products.image_url...")
        try:
            pipeline.sb_patch("products", f"id=eq.{pid}", {"image_url": public_url})
        except Exception as e:
            print(f"  [ERROR] Update DB gagal: {e}")
            pipeline.log_entry(log_data, pid, "-", "ERROR_DB_UPDATE", image_url=public_url, error=str(e))
            errors += 1
            continue

        print(f"  [SUCCESS] {public_url}")
        pipeline.log_entry(log_data, pid, "-", "SUCCESS", image_url=public_url)
        success += 1

    # Cleanup temp folder
    print("\nCleaning up temporary files...")
    for filename in file_list:
        file_path = TEMP_EXTRACT_DIR / filename
        if file_path.exists():
            try:
                os.remove(file_path)
            except Exception:
                pass
    try:
        os.rmdir(TEMP_EXTRACT_DIR)
    except Exception:
        pass

    print(f"\nFINISHED UPLOADING RAW IMAGES!")
    print(f"  SUCCESS: {success}")
    print(f"  ERRORS : {errors}")

if __name__ == "__main__":
    main()
