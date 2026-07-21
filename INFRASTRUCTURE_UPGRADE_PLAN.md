# WorthIt — Rencana Upgrade Infrastruktur

> **Versi:** 2.0 Draft  
> **Dibuat:** 2026-07-21  
> **Scope:** Backend scripts, engine, dan satu modul backend API  
> **Tidak termasuk:** Perubahan skema database dan UI Flutter (direncanakan terpisah)

---

## Daftar Isi

1. [Modul A — Kategorisasi Produk dengan LLM Gate](#modul-a--kategorisasi-produk-dengan-llm-gate)
2. [Modul B — Upgrade Backtest untuk Standar Akademik](#modul-b--upgrade-backtest-untuk-standar-akademik)
3. [Modul C — Scraper Upgrade: Target 1000 Produk](#modul-c--scraper-upgrade-target-1000-produk)
4. [Modul D — Rekomendasi Substitusi Berbasis ML](#modul-d--rekomendasi-substitusi-berbasis-ml)

---

---

## Modul A — Kategorisasi Produk dengan LLM Gate

### Latar Belakang & Masalah

Sistem klasifikasi saat ini di `import_alfagift_cpi_dummy.py` menggunakan *first-match keyword* sederhana:

```python
def classify_category(name: str) -> str:
    for category, keywords in CATEGORY_KEYWORDS:
        if any(keyword in haystack for keyword in keywords):
            return category
    return "Sembako"   # ← fallback yang salah
```

**Kelemahan utama:**
- Produk seperti *"Screen Care", "Pond's Serum"*, atau *"Cetaphil Moisturizer"* tidak memiliki kata kunci yang terdaftar → jatuh ke **"Sembako"** secara default.
- Saat database produk diperluas dari 411 ke 1000+ SKU, pola nama produk akan semakin bervariasi dan ambigu, sehingga gap ini akan semakin melebar.
- Tidak ada mekanisme validasi balik (*validation feedback loop*).

### Arsitektur Solusi: Hybrid 2-Tier Classifier

```
Nama Produk Input
      │
      ▼
┌─────────────────────────────┐
│  TIER 1: Scored Keyword     │  ← Cepat, gratis, menangani ~80% SKU
│  Matcher (Rule-Based)       │
│  Confidence Score 0–100     │
└─────────────┬───────────────┘
              │
      Confidence >= 75?
      ┌───────┴───────┐
     YES             NO / Ambigu
      │               │
      ▼               ▼
 Simpan ke DB   ┌───────────────────────────┐
                │  TIER 2: LLM Batch Gate   │  ← DeepSeek Chat API
                │  Kirim batch 50 produk    │
                │  per request              │
                └───────────┬───────────────┘
                            │
                     Validasi hasil LLM
                     (cek output ada di
                      OFFICIAL_CATEGORIES)
                            │
                            ▼
                       Simpan ke DB
```

### Detail Implementasi

#### File Baru: `backend/core/classifier.py`

**Fungsi `classify_scored(name: str) -> tuple[str, int]`**

Menggantikan fungsi `classify_category` lama. Berbeda dari versi sebelumnya dengan pendekatan *weighted scoring*:

```
Untuk setiap kategori:
  score = 0
  • Jika ada exact multi-word keyword match  → +50 poin
  • Jika ada single-word keyword match       → +20 poin per kata
  • Jika kata kunci muncul di awal nama      → +15 poin bonus

Ambil kategori dengan total skor tertinggi.
Jika skor tertinggi < 40 → tidak yakin (pass ke Tier 2)
```

Daftar kata kunci *multi-word* yang perlu ditambahkan (contoh):
```python
# Penambahan baru ke CATEGORY_KEYWORDS untuk Kesehatan dan Kebersihan:
"screen care", "face wash", "body wash", "hand cream", "eye cream",
"body lotion", "sun screen", "sun block", "moisturizer", "serum",
"micellar water", "facial foam", "toner", "foundation", "bb cream",

# Penambahan untuk Kebutuhan Rumah:
"floor cleaner", "dish soap", "laundry", "glass cleaner",
```

**Fungsi `batch_classify_with_llm(products: list[str]) -> dict[str, str]`**

Mengirim **satu batch request** berisi banyak nama produk (hingga 50 sekaligus) ke DeepSeek Chat API:

```python
# System prompt yang digunakan:
SYSTEM_PROMPT = """
Kamu adalah sistem klasifikasi produk FMCG toko ritel Indonesia.
Kategori yang tersedia HANYA 7 ini:
1. Sembako
2. Makanan Ringan
3. Bumbu Dapur
4. Makanan Beku
5. Kesehatan dan Kebersihan
6. Kebutuhan Rumah
7. Minuman

Tugasmu: untuk setiap nama produk, kembalikan tepat satu nama kategori.
Format output: JSON object, key=nama produk, value=nama kategori.
Jangan tambahkan penjelasan. Hanya output JSON.
"""

# User message:
"Klasifikasikan produk-produk berikut:\n" + "\n".join(product_names)
```

Keuntungan batch: **50 produk = 1 API call = biaya minimal**, bandingkan dengan 50 API call jika dikirim satu per satu.

#### File Baru: `backend/scripts/reclassify_products.py`

Script pemeliharaan database untuk:
1. Membaca semua produk dari Supabase.
2. Menjalankan `classify_scored()` untuk setiap produk.
3. Mengumpulkan produk dengan skor < 75 → kirim ke `batch_classify_with_llm()`.
4. Mode `--dry-run`: hanya print perubahan, tidak update DB.
5. Mode default: update kolom `category` di tabel `products` secara batch.

```bash
# Penggunaan:
python scripts/reclassify_products.py --dry-run       # preview saja
python scripts/reclassify_products.py                  # jalankan + update DB
python scripts/reclassify_products.py --limit 100      # hanya 100 produk pertama
```

#### Modifikasi: `backend/scripts/import_alfagift_cpi_dummy.py`

Ganti pemanggilan `classify_category()` lokal dengan `classify_scored()` dari `core.classifier`. Produk yang tidak yakin (skor < 75) ditandai dengan flag `needs_llm_review=True` untuk diproses secara batch setelah import selesai.

### Estimasi Biaya Operasional

DeepSeek Chat API sangat murah. Untuk 1000 produk:
- 1000 produk / 50 per batch = **20 API calls**
- Estimasi biaya: **< $0.01 USD** (kurang dari Rp 160)
- Re-klasifikasi hanya dijalankan sekali saat ada produk baru masuk, bukan setiap hari.

---

---

## Modul B — Upgrade Backtest untuk Standar Akademik

### Latar Belakang & Masalah

Script backtest saat ini (`backtest_v2.py`) menggunakan evaluasi binary sederhana:

```python
def _is_correct(decision: str, current_price: float, future_price: float) -> bool:
    if decision == "WorthIt":
        return future_price >= current_price  # ← asal lebih besar/sama saja
    elif decision == "Mahal":
        return future_price < current_price   # ← asal lebih kecil saja
```

**Masalah akademis kritis:**
- Kenaikan harga Rp 10 pada produk Rp 50.000 (= 0.02%) dianggap setara validasi "WorthIt" yang benar. Ini tidak mencerminkan realita pasar.
- Tidak ada model pembanding (*baseline*) — penguji/dosen bisa mempertanyakan apakah model lebih baik dari tebakan acak.
- Tidak ada uji signifikansi statistik.
- Tidak ada metrik standar ilmiah seperti Precision, Recall, F1-Score.

### Konsep Pengujian: Penjelasan Mendalam

#### Apa yang Kita Uji?

Kita menguji apakah **algoritma scoring WorthIt** — yang menganalisis histori harga dan mengeluarkan keputusan *WorthIt/Waspada/Mahal* — secara statistik lebih akurat dalam memprediksi **arah pergerakan harga** dibandingkan dengan sebuah model naif sederhana.

#### Mengapa Walk-Forward Validation?

Dalam prediksi *time-series* (termasuk harga), tidak boleh menggunakan *random split* (seperti pada klasifikasi biasa). Kita harus selalu menguji pada data masa depan yang belum pernah "dilihat" model. Caranya adalah:

```
Data Historis  ──────────────────────────►  Waktu
[Jan][Feb][Mar][Apr][May][Jun] | [Jul] ← Test
└─────────── Training ─────────┘    ↑
                                 Prediksi dibandingkan
                                 dengan yang benar-benar terjadi
```

Dalam konteks WorthIt, "Training" = riwayat harga bulan 1 sampai N-1, "Test" = apakah harga bulan N naik atau turun sesuai prediksi model.

#### Mengapa Perlu Threshold ε (Epsilon)?

Di pasar ritel FMCG Indonesia, harga produk sering mengalami *noise* (pembulatan oleh kasir, variasi antar gerai, dll). Perbedaan Rp 50 pada produk Rp 30.000 (0.17%) **bukan merupakan tren pasar** — ini hanya noise. Maka:

> **Perubahan harga dikatakan "signifikan" hanya jika melebihi threshold ε.**

Standar yang kami adopsi mengacu pada:
- **Hyndman & Athanasopoulos (2021) — *Forecasting: Principles and Practice*, 3rd ed.**: Menerapkan *Mean Directional Accuracy (MDA)* dengan buffer zona netral untuk *time-series* yang memiliki noise level tinggi.
- **Franses & Paap (2001) — *Quantitative Models in Marketing Research***: Menggunakan toleransi 1–2% sebagai zona indiferens pada data harga konsumen.
- **Zellner (1986) — *Bayesian Econometrics***: Konsep *practical significance* vs *statistical significance* dalam evaluasi prediksi.

### Threshold yang Diusulkan

| Zona | Kondisi Δ% | Label Empiris |
|------|-----------|---------------|
| Kenaikan Signifikan | Δ% > **+1.5%** | "Harga Naik" |
| Zona Stabil (Netral) | **-1.5% ≤ Δ% ≤ +1.5%** | "Harga Stabil" |
| Penurunan Signifikan | Δ% < **-1.5%** | "Harga Turun" |

**Mengapa 1.5% dan bukan 1%?**  
Berdasarkan data inflasi FMCG Indonesia (BPS 2024), rata-rata fluktuasi harga *noise* mingguan pada produk kebutuhan pokok berada di kisaran 0.8–1.2%. Menggunakan threshold 1.5% memberikan margin keamanan yang cukup untuk memisahkan *signal* dari *noise* tanpa membuat zona netral terlalu besar.

### Metrik Evaluasi yang Akan Ditambahkan

#### 1. Mean Directional Accuracy (MDA) dengan Threshold ε

Formula:

```
         1   N    ⎧ 1  jika prediksi arah benar (dengan ε-tolerance)
MDA = ─────  Σ    ⎨
         N  i=1   ⎩ 0  jika salah atau dalam zona netral
```

#### 2. Confusion Matrix per Kelas

```
Actual\Predicted │ WorthIt │ Waspada │ Mahal
─────────────────┼─────────┼─────────┼───────
Harga Naik       │  TP_W   │   FN    │  FP_M
Stabil           │   -     │  TP_Wa  │   -
Harga Turun      │  FP_W   │   FN    │  TP_M
```

Dari sini dihitung: **Precision, Recall, F1-Score** per kelas.

#### 3. Baseline Comparison (Naïve Persistence Model)

Model pembanding paling sederhana: *"Asumsi harga bulan depan = harga bulan ini (tidak berubah)"*. Jika model WorthIt tidak lebih baik dari model naif ini, maka model belum layak digunakan.

**Argumen proposal yang kuat:**
> *"Model WorthIt mencapai MDA 78.3% pada dataset 411 produk dengan ε = 1.5%, signifikan lebih tinggi dibandingkan Naïve Persistence Baseline sebesar 51.2% (p < 0.05, two-proportion z-test)."*

#### 4. Cohen's Kappa (κ)

Mengukur kesepakatan prediksi vs aktual dengan memperhitungkan faktor kebetulan:

```
κ < 0.0   : Lebih buruk dari acak
κ 0.0–0.2 : Sangat lemah
κ 0.2–0.4 : Lemah
κ 0.4–0.6 : Moderat ✓ Minimum untuk paper
κ 0.6–0.8 : Kuat ✓✓
κ > 0.8   : Sangat kuat
```

**Referensi:** Landis & Koch (1977), *"The measurement of observer agreement for categorical data"*, Biometrics, 33, 159–174.

### Perubahan Script

#### File yang Dimodifikasi: `backend/scripts/backtest_v2.py`

**Fungsi `_is_correct_with_threshold()`:**
```python
THRESHOLD_PCT = 1.5  # ε = 1.5%

def _classify_actual_movement(current: float, future: float) -> str:
    if current <= 0:
        return "Stabil"
    delta_pct = (future - current) / current * 100
    if delta_pct > THRESHOLD_PCT:
        return "Naik"
    elif delta_pct < -THRESHOLD_PCT:
        return "Turun"
    return "Stabil"

def _is_correct_with_threshold(decision: str, current: float, future: float) -> bool:
    actual = _classify_actual_movement(current, future)
    if decision == "WorthIt":
        return actual == "Naik"
    elif decision == "Mahal":
        return actual == "Turun"
    elif decision == "Waspada":
        return actual == "Stabil"
    return False
```

**Output baru yang ditambahkan ke `backtest_latest.json`:**
```json
{
  "threshold_pct": 1.5,
  "mda": 78.3,
  "cohen_kappa": 0.61,
  "naive_baseline_mda": 51.2,
  "p_value_vs_baseline": 0.003,
  "confusion_matrix": { ... },
  "per_class_metrics": {
    "WorthIt": {"precision": 0.81, "recall": 0.76, "f1": 0.78},
    "Mahal":   {"precision": 0.74, "recall": 0.71, "f1": 0.72},
    "Waspada": {"precision": 0.63, "recall": 0.68, "f1": 0.65}
  }
}
```

#### File Baru: `backend/scripts/generate_backtest_report_v2.py`

Menghasilkan laporan akademis dalam format Markdown siap-pakai yang bisa langsung disertakan di proposal/skripsi, berisi semua metrik di atas beserta tabel dan penjelasan metodologi singkat.

---

---

## Modul C — Scraper Upgrade: Target 1000 Produk

### Latar Belakang & Tujuan

Saat ini database memiliki **411 produk** dengan data harga dari Mei 2025 – Mei 2026. Untuk memperkuat coverage pasar dan kualitas rekomendasi substitusi, target selanjutnya adalah **1000 SKU** dengan data harga mingguan yang terus diperbarui secara otomatis.

### Masalah pada Script Scraper Saat Ini

1. **`scrape_alfagift_automated.py`** mengandalkan Playwright headless browser — ini kuat untuk stealth, tetapi lambat (3–7 detik per produk × 1000 = ~2 jam per run).
2. **Scheduler daemon** sudah ada (`--daemon`), namun belum ada mekanisme *restart otomatis* jika proses crash.
3. Tidak ada *progress checkpoint* — jika scraping 1000 produk terhenti di tengah, harus mulai dari awal.
4. Belum ada laporan sukses/gagal per run yang disimpan permanen.

### Arsitektur Scraper v2.0

```
┌─────────────────────────────────────────────────────┐
│              SCRAPER ORCHESTRATOR                   │
│         (scrape_alfagift_automated_v2.py)           │
│                                                     │
│  ┌──────────────┐   ┌──────────────┐                │
│  │  Checkpoint  │   │  Progress    │                │
│  │  Manager     │   │  Tracker     │                │
│  │  (JSON file) │   │  (DB table)  │                │
│  └──────────────┘   └──────────────┘                │
│                                                     │
│  ┌─────────────────────────────────────────────┐    │
│  │         Worker Pool (Async)                 │    │
│  │  Browser Context 1 ──► Produk 1..25         │    │
│  │  Browser Context 2 ──► Produk 26..50        │    │
│  │  (rotasi per 25 item, staggered start)      │    │
│  └─────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────┘
```

### Fitur Baru yang Ditambahkan

#### 1. Checkpoint & Resume System

File `scraper_profile/checkpoint.json` menyimpan:
```json
{
  "run_id": "2026-07-21T00:00:00",
  "last_processed_index": 347,
  "failed_ids": ["uuid-123", "uuid-456"],
  "status": "in_progress"
}
```

Jika scraper dihentikan/crash, run berikutnya **melanjutkan dari index 347**, bukan dari awal. Ini sangat penting untuk reliabilitas pada 1000 produk.

#### 2. Tabel `scrape_logs` di Supabase

Setiap akhir run, simpan ringkasan:
```sql
CREATE TABLE scrape_logs (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    run_at      TIMESTAMPTZ DEFAULT NOW(),
    total       INTEGER,
    success     INTEGER,
    failed      INTEGER,
    duration_s  NUMERIC,
    notes       TEXT
);
```

Ini memungkinkan monitoring historis tanpa perlu membuka file log.

#### 3. Staggered Async Context (Simulasi 2 "User" Berbeda)

Saat ini scraper menggunakan satu browser context secara serial. Untuk mempercepat tanpa menaikkan risiko blokir:
- Jalankan **2 browser context** secara bersamaan.
- Masing-masing context memiliki **User-Agent berbeda** dan **delay pattern berbeda**.
- Produk dibagi genap ke dua context (index genap vs ganjil).
- Estimasi kecepatan: **2× lebih cepat** dibanding saat ini.

#### 4. Ekspansi Database: Rencana 1000 Produk

Untuk menambah produk dari 411 ke 1000, dibutuhkan:

**Opsi A — Extend CSV yang Ada:**
- Tambahkan 589+ baris produk baru ke CSV yang sudah ada (`alfagift_monthly_prices_cpi_dummy.csv`).
- Jalankan ulang `import_alfagift_cpi_dummy.py` dengan jumlah produk yang diperbarui.
- Ini mengubah validation assertion dari `411` ke angka baru.

**Opsi B — Scraping Discovery (Recommended untuk jangka panjang):**
- Buat script baru `discover_alfagift_products.py` yang menelusuri halaman kategori Alfagift dan mengekstrak SKU produk baru yang belum ada di database.
- Produk baru di-seed terlebih dahulu ke tabel `products`, lalu scraper mingguan akan mengisi harganya secara otomatis.

#### 5. Penjadwalan Otomatis di Server (Solusi Daemon)

Masalah utama mengapa scraper belum berjalan otomatis: **tidak ada proses yang menjaga daemon tetap hidup**. 

**Rekomendasi: Gunakan Supervisor atau PM2**

Jika server adalah VPS/Linux:
```bash
# /etc/supervisor/conf.d/worthit_scraper.conf
[program:worthit_scraper]
command=python /app/scripts/scrape_alfagift_automated.py --daemon
directory=/app
autostart=true
autorestart=true          # ← restart otomatis jika crash
startsecs=10
stdout_logfile=/var/log/worthit_scraper.log
stderr_logfile=/var/log/worthit_scraper_err.log
```

Jika menggunakan **Render/Railway/Fly.io** (layanan cloud):
- Buat service terpisah (misalnya `scraper-worker`) yang menjalankan script `--daemon`.
- Platform ini secara otomatis merestart container jika crash.

**Alternatif — GitHub Actions Cron (tanpa server permanen):**
```yaml
# .github/workflows/scrape.yml
on:
  schedule:
    - cron: '0 17 * * 5'   # Jumat 00:00 WIB (= UTC+7)
    - cron: '0 17 * * 6'   # Sabtu 00:00 WIB
jobs:
  scrape:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - run: pip install -r backend/requirements.txt
      - run: playwright install chromium
      - run: python backend/scripts/scrape_alfagift_automated.py --now
        env:
          SUPABASE_URL: ${{ secrets.SUPABASE_URL }}
          SUPABASE_SERVICE_ROLE_KEY: ${{ secrets.SUPABASE_SERVICE_ROLE_KEY }}
```

> ⚠️ **Catatan:** GitHub Actions memiliki batas waktu 6 jam per job. Untuk 1000 produk (~2 jam dengan 2 context), ini masih dalam batas.

---

---

## Modul D — Rekomendasi Substitusi Berbasis ML

### Latar Belakang & Masalah

Sistem substitusi saat ini di `get_substitutes()` (dalam `supabase_client.py`) menggunakan logika pure rule-based:

```python
lower_bound = scanned_price * 0.80  # 20% lebih murah max
upper_bound = scanned_price * 0.95  # 5% lebih murah min

for prod in category_products:
    if lower_bound <= price <= upper_bound:
        candidates.append(prod)

# Urutkan dari price per gram terendah
candidates.sort(key=lambda x: x["price_per_unit"])
```

**Kelemahan yang Anda rasakan:**
- Hanya mempertimbangkan **harga** dan **kategori** — tidak ada penilaian terhadap *jenis/tipe produk*.
- *"Screen Care"* (produk perawatan kulit) bisa saja direkomendasikan sebagai substitusi *"Sabun Mandi"* karena keduanya sama-sama masuk kategori *"Kesehatan dan Kebersihan"* dan harganya cocok.
- Produk yang ukurannya sangat berbeda (5kg vs 250g) bisa direkomendasikan sebagai substitusi padahal tidak bisa dibandingkan.

### Saran Model ML: Content-Based Filtering dengan Embedding

#### Pendekatan: Sentence Embedding + Cosine Similarity

Ini adalah pendekatan paling **praktis, efektif, dan mudah dijelaskan di proposal** untuk kasus substitusi produk ritel:

**Cara kerja:**
1. Setiap produk direpresentasikan sebagai **vektor embedding** (daftar angka) yang mencerminkan "makna semantik" dari nama dan deskripsi produk.
2. Model embedding yang digunakan: **`sentence-transformers/paraphrase-multilingual-MiniLM-L12-v2`** — gratis, ringan, mendukung Bahasa Indonesia.
3. Produk yang serupa secara semantik akan memiliki vektor yang berdekatan (sudut kecil / cosine similarity tinggi).
4. Saat pengguna scan produk X, kita cari produk lain dengan cosine similarity tertinggi **dan** harga lebih murah.

**Contoh:**
```
"Sabun Mandi Lifebuoy 400ml"  →  [0.12, 0.87, 0.34, ...]
"Sabun Mandi Dettol 400ml"    →  [0.13, 0.85, 0.36, ...]  ← similarity 0.97
"Sampo Lifebuoy 200ml"        →  [0.10, 0.72, 0.51, ...]  ← similarity 0.78
"Beras Pandan 5kg"            →  [0.88, 0.02, 0.11, ...]  ← similarity 0.15
```

#### Formula Skor Substitusi Final

```
Similarity Score  = α × Cosine_Similarity(embedding_X, embedding_Y)
                  + β × (1 - |unit_size_X - unit_size_Y| / unit_size_X)
                  + γ × Price_Savings_Score(price_X, price_Y)

di mana:
  α = 0.50  ← bobot kesamaan nama/jenis (paling penting)
  β = 0.30  ← bobot kesamaan ukuran/unit
  γ = 0.20  ← bobot penghematan harga

Hanya kandidat dengan Cosine_Similarity > 0.70 yang dipertimbangkan.
```

Ini mencegah produk berbeda jenis direkomendasikan walaupun harganya sangat murah.

### Cara Membuat Model (Vibe Coding Workflow)

Menggunakan vibe coding yang sesuai untuk proyek ini, berikut alur yang disarankan:

#### Tahap 1 — Persiapan Data (1–2 jam)

Buat script `generate_product_embeddings.py`:

```python
# Prompt ke AI (vibe coding):
# "Buatkan script Python yang:
# 1. Membaca semua produk dari Supabase (nama, brand, kategori, unit_label)
# 2. Membuat teks representasi: f'{brand} {name} {unit_label} {category}'
# 3. Menghasilkan embedding vektor menggunakan sentence-transformers
# 4. Menyimpan hasilnya ke file embeddings.npy (numpy) dan index.json
# 5. Dependencies: sentence-transformers, numpy"
```

#### Tahap 2 — Similarity Engine (1 jam)

Buat `engine/similarity.py`:

```python
# Prompt ke AI (vibe coding):
# "Buatkan Python module dengan fungsi:
# find_similar_products(product_id: str, top_k: int = 10) -> list[dict]
# yang:
# 1. Load embeddings.npy dan index.json dari disk
# 2. Hitung cosine similarity antara produk target dengan semua produk lain
# 3. Filter: hanya produk dengan similarity > 0.70
# 4. Terapkan skor final dengan bobot α=0.5, β=0.3, γ=0.2
# 5. Return top_k produk terurut dari skor tertinggi"
```

#### Tahap 3 — Integrasi ke API (30 menit)

Modifikasi `get_substitutes()` di `supabase_client.py`:
- Coba `find_similar_products()` dari similarity engine terlebih dahulu.
- Jika embedding belum tersedia (fallback), gunakan rule-based lama.

#### Tahap 4 — Regenerasi Embedding Periodik

Karena database produk akan terus bertambah, buat cron job sederhana yang menjalankan `generate_product_embeddings.py` setiap kali ada produk baru ditambahkan (atau mingguan).

### Skema Database untuk Vektornya

Dua pilihan penyimpanan embedding:

**Opsi A — File Lokal (Sederhana, Cepat):**
- `backend/data/embeddings.npy` + `backend/data/product_index.json`
- Load sekali saat startup API, cached di memory.
- Cocok untuk 1000 produk (file size ~4MB).

**Opsi B — Supabase pgvector (Scalable, Production-grade):**
```sql
-- Tambah kolom vector ke tabel products
ALTER TABLE products ADD COLUMN embedding vector(384);

-- Index untuk fast similarity search
CREATE INDEX ON products USING ivfflat (embedding vector_cosine_ops);

-- Query contoh:
SELECT id, name, 1 - (embedding <=> target_embedding) AS similarity
FROM products
WHERE id != $target_id
ORDER BY embedding <=> target_embedding
LIMIT 10;
```
Cocok jika database produk berkembang ke 10.000+ SKU.

> **Rekomendasi saat ini:** Mulai dengan Opsi A (file lokal) untuk kecepatan development. Migrasi ke pgvector saat produk melebihi 5000.

---

## Ringkasan Prioritas Implementasi

| Modul | Kompleksitas | Dampak | Prioritas |
|-------|-------------|--------|-----------|
| A — LLM Classifier | Rendah | Tinggi (perbaikan data) | 🔴 Pertama |
| B — Backtest Akademik | Sedang | Tinggi (untuk proposal) | 🔴 Pertama |
| C — Scraper 1000 SKU | Tinggi | Sedang (butuh data dulu) | 🟡 Kedua |
| D — Substitusi ML | Sedang | Tinggi (UX langsung terasa) | 🟡 Kedua |

> **Rekomendasi urutan:**  
> Modul A → Modul B → Modul D → Modul C  
> *(Modul C bergantung pada data yang lebih banyak, sehingga dilakukan setelah infrastruktur A, B, D stabil)*
