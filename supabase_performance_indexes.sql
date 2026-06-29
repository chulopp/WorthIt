-- =============================================================================
-- WorthIt - Performance Index Migration
-- Jalankan di Supabase SQL Editor (satu kali).
-- idx_purchase_history_user_purchased_at sudah ada — TIDAK di-duplicate.
-- =============================================================================

-- 1. Index scan_history per user + waktu (untuk riwayat & filtering)
CREATE INDEX IF NOT EXISTS idx_scan_history_user_created_at
    ON scan_history (user_id, created_at DESC);

-- 2. Index price_history per produk + waktu (untuk WMA, S/R, dan market insight)
CREATE INDEX IF NOT EXISTS idx_price_history_product_recorded_at
    ON price_history (product_id, recorded_at DESC);

-- 3. Index favorite_products per user + produk (untuk toggle & fetch favorit)
CREATE INDEX IF NOT EXISTS idx_favorite_products_user_product
    ON favorite_products (user_id, product_id);

-- 4. Kolom display_name di tabel users (untuk custom username)
--    Jalankan hanya jika kolom belum ada.
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'users' AND column_name = 'display_name'
    ) THEN
        ALTER TABLE users ADD COLUMN display_name TEXT;
        COMMENT ON COLUMN users.display_name IS 'Nama tampilan kustom yang bisa diubah user.';
    END IF;
END $$;
