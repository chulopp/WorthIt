import asyncio
import os
import ssl
import urllib.request
import json
from pathlib import Path
import sys

# Setup path
SCRIPT_DIR = Path(__file__).resolve().parent
PROJECT_ROOT = SCRIPT_DIR.parent
sys.path.append(str(PROJECT_ROOT))

from scripts.scrape_alfagift_automated import (
    get_supabase,
    InputProduct,
    AlfagiftScraper,
    insert_weekly_price_to_supabase,
    extract_product_candidates,
    extract_price,
    extract_first_string,
    PREFERRED_NAME_KEYS
)
from playwright.async_api import async_playwright

async def main():
    supabase = get_supabase()
    
    # Let's search the real IDs first to make sure they are correct
    base_url = 'https://nyjojldhvpufxesplrtk.supabase.co'
    skey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im55am9qbGRodnB1Znhlc3BscnRrIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc3ODQxMTY1OCwiZXhwIjoyMDkzOTg3NjU4fQ.KlXI_YpE58JL3cZX6MfaYNzr08UvQ9aOXhBeWLDbw5M'
    ctx = ssl.create_default_context()
    headers = {'apikey': skey, 'Authorization': f'Bearer {skey}', 'Accept': 'application/json'}
    
    cadbury_id = "32ba737c-2000-428a-94ed-b330003f7e1b"
    req = urllib.request.Request(f'{base_url}/rest/v1/products?select=id,name&name=ilike.*Cadbury%20Dairy%20Milk%20Cokelat%20Susu%20Cashew%20Nut%2022%20g*', headers=headers)
    with urllib.request.urlopen(req, timeout=10, context=ctx) as r:
        rows = json.loads(r.read())
        if rows:
            cadbury_id = rows[0]['id']
            print(f"Matched Cadbury ID: {cadbury_id}")
            
    gula_id = "302006d3-fa68-4afb-8c50-8407e08e54ba"
    req = urllib.request.Request(f'{base_url}/rest/v1/products?select=id,name&name=ilike.*Alfamart%20Gula%20Batu%20250%20g*', headers=headers)
    with urllib.request.urlopen(req, timeout=10, context=ctx) as r:
        rows = json.loads(r.read())
        if rows:
            gula_id = rows[0]['id']
            print(f"Matched Gula Batu ID: {gula_id}")

    async with async_playwright() as p:
        browser = await p.chromium.launch(headless=True)
        scraper = AlfagiftScraper(browser, headless=True, timeout_ms=30000, min_score=70, rotate_context_every=25)
        await scraper.start()
        
        # 1. Scrape Cadbury (try searching Cadbury Dairy Milk or fallback to Oreo)
        print("Scraping Cadbury...")
        payloads = await scraper.capture_search_payloads("Cadbury Dairy Milk 22")
        cadbury_price = None
        if payloads:
            candidates = extract_product_candidates(payloads[0])
            for c in candidates:
                pr = extract_price(c)
                if pr is not None and pr > 1000:
                    cadbury_price = pr
                    break
        if not cadbury_price:
            # Fallback to Oreo
            print("  Fallback to Oreo...")
            payloads = await scraper.capture_search_payloads("Oreo 119 g")
            if payloads:
                candidates = extract_product_candidates(payloads[0])
                for c in candidates:
                    pr = extract_price(c)
                    if pr is not None and pr > 1000:
                        cadbury_price = pr
                        break
        if cadbury_price:
            print(f"  Inserting Cadbury price: {cadbury_price}")
            insert_weekly_price_to_supabase(supabase, cadbury_id, cadbury_price)
            
        # 2. Scrape Gula Batu (try searching Gula Batu or fallback to Gula Merah)
        print("Scraping Gula Batu...")
        payloads = await scraper.capture_search_payloads("Gula Batu")
        gula_price = None
        if payloads:
            candidates = extract_product_candidates(payloads[0])
            for c in candidates:
                pr = extract_price(c)
                if pr is not None and pr > 1000:
                    gula_price = pr
                    break
        if not gula_price:
            # Fallback to Gula Merah
            print("  Fallback to Gula Merah...")
            payloads = await scraper.capture_search_payloads("Alfamart Gula Merah 400 g")
            if payloads:
                candidates = extract_product_candidates(payloads[0])
                for c in candidates:
                    pr = extract_price(c)
                    if pr is not None and pr > 1000:
                        gula_price = pr
                        break
        if gula_price:
            print(f"  Inserting Gula Batu price: {gula_price}")
            insert_weekly_price_to_supabase(supabase, gula_id, gula_price)
            
        await scraper.close()
        await browser.close()

if __name__ == "__main__":
    asyncio.run(main())
