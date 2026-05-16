# Algoritma Synthetic Dummy Price Berbasis IHK/CPI

Dokumen ini menjelaskan algoritma yang digunakan oleh `synthetic_data_generator.py` untuk membuat data harga historis dummy/sintetis bulanan dari `Nov 25` sampai `May 26`.

Output utama yang dihasilkan:

- `alfagift_monthly_prices_cpi_dummy.csv`

Data ini adalah **synthetic estimated historical prices**, bukan data harga historis aktual.

## Dasar Data

Algoritma memakai dua jenis sumber data:

1. **Harga retail saat ini dari Alfagift**
   - File: `docs/alfagift.csv`
   - Kolom utama:
     - `found_name`: nama produk hasil matching Alfagift
     - `price`: harga saat ini
     - `unit`, `sku_id`, `match_type`, `match_reason`: metadata audit

2. **Data IHK/CPI nasional bulanan**
   - Folder: `testing/`
   - File:
     - `tabel_ihk_inflasi_november_2025.xlsx`
     - `tabel_ihk_inflasi_desember_2025.xlsx`
     - `tabel_ihk_inflasi_januari_2026.xlsx`
     - `tabel_ihk_inflasi_februari_2026.xlsx`
     - `tabel_ihk_inflasi_maret_2026.xlsx`
     - `tabel_ihk_inflasi_april_2026.xlsx`
   - Data yang dipakai adalah nilai **IHK** per `Kelompok Pengeluaran`.

## Prinsip Utama

Harga `May 26` selalu menjadi anchor dan harus sama persis dengan `current_price` dari Alfagift.

Karena data IHK yang tersedia baru sampai `Apr 26`, maka `Apr 26` digunakan sebagai **CPI anchor month** untuk menghitung bulan historis `Nov 25` sampai `Apr 26`.

Rumus dasar:

```text
estimated_price_month = current_price * (cpi_index_month / cpi_index_apr_2026)
```

Contoh interpretasi:

- Jika IHK suatu kelompok pada `Nov 25` lebih rendah dibanding `Apr 26`, maka estimasi harga `Nov 25` akan lebih rendah dari harga saat ini.
- Jika IHK suatu kelompok pada bulan tertentu mendekati `Apr 26`, maka estimasi harga bulan tersebut akan mendekati `current_price`.

## Mapping Produk ke CPI Group

Setiap produk dipetakan ke `cpi_group` berdasarkan keyword dari `input_name` dan `found_name`.

Mapping utama:

| Jenis produk | CPI group |
|---|---|
| Beras, minyak goreng, gula, tepung, telur, susu, mie, bihun, sarden, kornet, bumbu, makanan/minuman | `Makanan, Minuman dan Tembakau` |
| Pasta gigi, sabun, shampo, deodorant, lotion, skincare, tisu, pembalut | `Perawatan Pribadi dan Jasa Lainnya` |
| Deterjen, pewangi, pembersih rumah, sabun cuci, karbol, produk household cleaning | `Perlengkapan, Peralatan dan Pemeliharaan Rutin Rumah Tangga` |
| Produk lain yang tidak masuk mapping spesifik | `Umum (Headline)` |

Selain `cpi_group`, script juga memberi kategori bisnis:

| Category | Kriteria |
|---|---|
| `SEMBAKO` | Produk dengan keyword kebutuhan pokok seperti beras, minyak goreng, gula, tepung, telur, susu, mie, bihun, sarden, kornet, bumbu |
| `FMCG` | Produk lain di luar mapping SEMBAKO |

## Promo Retail untuk FMCG

Untuk produk `FMCG`, algoritma menambahkan simulasi promo toko setelah harga berbasis CPI dihitung.

Aturan promo:

```text
if random.random() < 0.2:
    price = price * (1 - random_discount)
```

Dengan:

```text
random_discount = angka acak antara 2% sampai 5%
```

Artinya:

- Probabilitas promo: 20%
- Besaran diskon promo: 2%-5%
- Promo hanya diterapkan pada bulan `Nov 25` sampai `Apr 26`
- `May 26` tetap exact sama dengan `current_price`

Promo ini dipertahankan karena CPI menggambarkan tren harga agregat, sedangkan promo retail adalah efek mikro pada level toko/SKU.

## Pembulatan Harga

Semua harga hasil perhitungan dibulatkan ke ratusan terdekat.

Rumus:

```python
round(price / 100) * 100
```

Contoh:

| Harga awal | Harga hasil pembulatan |
|---:|---:|
| 73142 | 73100 |
| 11480 | 11500 |

Pengecualian:

- `May 26` tidak dihitung ulang dari CPI.
- `May 26` langsung memakai `current_price` dari Alfagift.

## Validasi Output

Script melakukan validasi berikut sebelum menyimpan CSV:

1. `May 26` harus sama persis dengan `current_price`.
2. Semua kolom bulan harus terisi.
3. Semua harga bulanan harus kelipatan 100.
4. Semua harga bulanan harus lebih besar dari 0.
5. Semua produk harus memiliki `category`.
6. Semua produk harus memiliki `cpi_group`.

Jika salah satu validasi gagal, script akan berhenti dan menampilkan error.

## Kenapa Metode Ini Lebih Ilmiah

Versi awal menggunakan tren linear dan random kecil untuk membuat harga historis. Metode tersebut cukup untuk dummy sederhana, tetapi dasar historisnya lemah.

Versi CPI-based lebih kuat karena:

- Menggunakan data IHK aktual per bulan.
- Menghubungkan perubahan harga dummy ke indikator ekonomi resmi.
- Memakai anchor harga retail nyata dari Alfagift.
- Menyimpan metadata produk dan matching untuk audit.
- Menyimpan `cpi_group` agar asumsi mapping dapat diperiksa.
- Tetap menjaga volatilitas rendah sesuai karakter data modern retail.

## Batasan Metode

Walaupun lebih kuat, hasil ini tetap bukan data historis aktual.

Batasan utama:

1. IHK tersedia pada level kelompok pengeluaran, bukan level SKU.
2. Harga retail spesifik bisa dipengaruhi promo, stok, lokasi toko, margin, campaign, dan strategi platform.
3. Data IHK baru tersedia sampai `Apr 26`, sementara anchor harga retail adalah `May 26`.
4. Mapping produk ke CPI group masih berbasis keyword, bukan klasifikasi manual per SKU.
5. Produk dengan `match_type = alternative` bisa memiliki risiko mismatch brand atau ukuran.

Karena itu, output harus disebut sebagai:

```text
synthetic estimated historical prices
```

bukan:

```text
actual historical retail prices
```

## Rekomendasi Peningkatan Berikutnya

Untuk meningkatkan akurasi lebih jauh:

1. Tambahkan data IHK `May 26` jika sudah tersedia, lalu jadikan `May 26` sebagai CPI anchor.
2. Gunakan data harga komoditas dari BPS, PIHPS, Bapanas, atau SP2KP untuk produk SEMBAKO.
3. Buat mapping manual per SKU untuk `cpi_group`.
4. Pisahkan produk makanan, minuman, personal care, dan household care secara lebih detail.
5. Tandai confidence score berdasarkan `match_type`, `fuzzy_score`, dan kesesuaian unit.
6. Simpan kolom tambahan seperti `method`, `cpi_anchor_month`, dan `is_synthetic` jika data akan dipakai untuk analisis lanjutan.
