<div align="center">
  <h1>🛒 WorthIt</h1>
  <p><strong>Asisten Validasi Keputusan Belanja Real-Time</strong></p>
  <p>
    <img alt="Flutter" src="https://img.shields.io/badge/Flutter-3.x-02569B?logo=flutter&logoColor=white"/>
    <img alt="FastAPI" src="https://img.shields.io/badge/FastAPI-0.128-009688?logo=fastapi&logoColor=white"/>
    <img alt="Supabase" src="https://img.shields.io/badge/Supabase-2.x-3ECF8E?logo=supabase&logoColor=white"/>
    <img alt="Python" src="https://img.shields.io/badge/Python-3.11+-3776AB?logo=python&logoColor=white"/>
    <img alt="Status" src="https://img.shields.io/badge/Status-In%20Development-orange"/>
  </p>
</div>

---

## 📖 Deskripsi Singkat

**WorthIt** adalah aplikasi mobile yang membantu konsumen memvalidasi keputusan belanja secara real-time di dalam toko. Pengguna dapat memindai struk atau label harga, lalu sistem akan menganalisis apakah harga tersebut **Worth It** (wajar), **Waspada** (sedikit mahal), atau **Mahal** — berdasarkan data historis harga dari Alfagift menggunakan algoritma Weighted Moving Average (WMA) dan Support/Resistance.

### Fitur Utama

| Fitur | Deskripsi |
|-------|-----------|
| 📸 **OCR Scan** | Scan struk/label harga via Gemini Vision AI |
| 📊 **Price Analysis** | Keputusan BUY / SUBSTITUTE / DONT_BUY berbasis WMA |
| 🛍️ **Shopping List** | Daftar belanja bulanan dengan estimasi budget |
| 📈 **Expense Tracker** | Riwayat pengeluaran per kategori |
| ⭐ **Favorites** | Simpan produk favorit untuk pantau harga |
| 🔔 **Notifications** | Alert harga produk dalam pantauan |

---

## 🏗️ Tech Stack

```
┌─────────────────────────────────────────────────────────┐
│                    FRONTEND (Mobile)                    │
│   Flutter 3.x  ·  Riverpod  ·  Dio  ·  Supabase SDK   │
├─────────────────────────────────────────────────────────┤
│                    BACKEND (Python)                     │
│   FastAPI  ·  Uvicorn  ·  PyJWT  ·  Supabase Python   │
├─────────────────────────────────────────────────────────┤
│                      C-ENGINE                           │
│   worthit_engine.c  ·  ctypes bridge (c_bridge.py)    │
│   WMA · Support · Resistance · SR Position            │
├─────────────────────────────────────────────────────────┤
│                    INFRASTRUCTURE                       │
│   Supabase (Auth + PostgreSQL + Storage)               │
│   WSL2 (Ubuntu)  ·  Microsoft Dev Tunnels              │
│   Gemini 2.5 Flash (OCR/Vision)                       │
│   Playwright + APScheduler (Alfagift Scraper)         │
└─────────────────────────────────────────────────────────┘
```

---

## 📋 Persyaratan Sistem

### Untuk Semua Anggota Tim

| Komponen | Versi Minimum | Catatan |
|----------|---------------|---------|
| Flutter SDK | 3.11.5+ | Install via [flutter.dev](https://docs.flutter.dev/get-started/install) |
| Dart SDK | 3.11.5+ | Sudah bundled dengan Flutter |
| Android SDK | API 21+ | via Android Studio |
| Git | Terbaru | |

### Untuk Menjalankan Backend (Developer)

| Komponen | Versi Minimum | Catatan |
|----------|---------------|---------|
| WSL2 (Ubuntu 22.04+) | - | Wajib untuk menjalankan backend |
| Python | 3.11+ | Di dalam WSL |
| pip / venv | Terbaru | |
| Microsoft Dev Tunnels CLI | Terbaru | [Install dev tunnels](https://learn.microsoft.com/en-us/azure/developer/dev-tunnels/get-started) |
| GCC (build tools) | - | Untuk compile C-Engine: `sudo apt install build-essential` |

---

## 🚀 Cara Menjalankan Secara Lokal

### A. Setup Frontend (Flutter)

**1. Clone repository**
```bash
git clone https://github.com/<your-org>/worthit.git
cd worthit/frontend
```

**2. Buat file konfigurasi lokal**

File `local_config.dart` **tidak ada di Git** (sengaja dihapus demi keamanan). Buat manual dari template:

```bash
cp lib/config/local_config.example.dart lib/config/local_config.dart
```

Lalu isi dengan kredensial yang diperoleh dari lead developer:
```dart
// lib/config/local_config.dart
class LocalConfig {
  static const supabaseUrl = 'https://YOUR_PROJECT.supabase.co';
  static const supabaseAnonKey = 'sb_publishable_XXXX...';
  static const supabaseAuthRedirectUrl = 'com.example.worthit_app://login-callback';

  // URL dari Dev Tunnel yang aktif (tanya ke developer yang menjalankan backend)
  static const apiBaseUrl = 'https://XXXX-XXXX.devtunnels.ms';
}
```

**3. Install dependencies dan jalankan**
```bash
flutter pub get
flutter run
```

---

### B. Setup Backend (Python / FastAPI di WSL)

> [!IMPORTANT]
> Seluruh langkah ini dijalankan **di dalam terminal WSL2**, bukan PowerShell Windows.

**1. Masuk ke WSL dan navigasi ke folder backend**
```bash
# Di PowerShell Windows:
wsl

# Kemudian di WSL:
cd "/mnt/d/Fallah's File/Code/Personal Project/WorthIt/backend"
```

**2. Buat virtual environment dan install dependencies**
```bash
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
```

**3. Buat file `.env`**

Minta file `.env` dari lead developer. **JANGAN commit file ini ke Git.**

```bash
# Isi file backend/.env:
SUPABASE_URL=https://YOUR_PROJECT.supabase.co
SUPABASE_SERVICE_ROLE_KEY=eyJhbG...
SUPABASE_JWT_SECRET=YOUR_JWT_SECRET
GEMINI_API_KEY=AIza...
```

**4. Build C-Engine (jika belum ada `worthit_engine.so`)**
```bash
cd engine
gcc -shared -fPIC -o worthit_engine.so worthit_engine.c -lm
cd ..
```

**5. Jalankan Backend**
```bash
uvicorn main:app --reload --host 0.0.0.0 --port 8000
```

Backend akan berjalan di `http://localhost:8000`. Swagger UI tersedia di `http://localhost:8000/docs`.

---

### C. Expose Backend via Microsoft Dev Tunnels

Dev Tunnels diperlukan agar perangkat Android fisik bisa mengakses backend yang berjalan di WSL.

**1. Login ke Dev Tunnels (sekali saja)**
```bash
devtunnel user login
```

**2. Buat dan aktifkan tunnel (jalankan di terminal WSL terpisah)**
```bash
devtunnel host -p 8000 --allow-anonymous
```

Salin URL yang diberikan (format: `https://XXXX-8000.devtunnels.ms`) dan masukkan sebagai `apiBaseUrl` di `local_config.dart` frontend.

---

## 🗃️ Struktur Proyek

```
WorthIt/
├── frontend/                   # Flutter App
│   └── lib/
│       ├── config/             # Konfigurasi (Supabase URL, API URL)
│       ├── controllers/        # Riverpod Notifiers
│       ├── models/             # Data models (API response)
│       ├── repositories/       # Data access layer
│       ├── screens/            # Halaman-halaman UI
│       ├── services/           # Auth, Notification, Privacy
│       ├── utils/              # PDF, Snackbar, Image helpers
│       └── widgets/            # Reusable UI components
│
├── backend/                    # Python FastAPI Backend
│   ├── core/                   # Security (JWT), Categories
│   ├── engine/                 # C-Engine bridge, WMA scoring
│   ├── models/                 # Pydantic request/response models
│   ├── routers/                # API endpoints (analyze, scan, shopping, dll.)
│   ├── scripts/                # Alfagift scraper & data import tools
│   ├── utils/                  # Supabase client singleton
│   ├── main.py                 # FastAPI app entrypoint
│   └── requirements.txt
│
└── supabase_*.sql              # Schema & migration SQL files
```

---

## 🗄️ Database (Supabase)

Proyek menggunakan **Supabase (PostgreSQL)**. Tabel utama:

| Tabel | Deskripsi |
|-------|-----------|
| `users` | Profil user + subscription tier + monthly budget |
| `products` | Katalog produk |
| `price_history` | Riwayat harga per produk per bulan |
| `scan_history` | Log setiap scan yang dilakukan user |
| `purchase_history` | Barang yang benar-benar dibeli |
| `monthly_shopping_lists` | Daftar belanja bulanan |
| `shopping_list_items` | Item dalam daftar belanja |
| `favorite_products` | Produk favorit user |
| `notifications` | Notifikasi in-app |

Untuk setup database baru, jalankan file SQL migrasi di folder root secara berurutan di Supabase SQL Editor.

---

## 🤝 Panduan untuk Anggota Tim Baru

1. **Fork & Clone** repository ini
2. Minta akses dari lead developer ke:
   - Supabase project (untuk mendapatkan Anon Key & URL)
   - File `backend/.env` (berisi service role key & secret)
3. Setup frontend ikuti **Langkah A** di atas
4. Untuk development yang memerlukan backend lokal, ikuti **Langkah B & C**
5. Jika hanya perlu akses frontend, cukup gunakan URL Dev Tunnel yang sudah aktif dari developer lain

> [!TIP]
> Tidak perlu menjalankan backend sendiri untuk sekadar mengembangkan UI. Koordinasi dengan developer backend untuk mendapatkan URL Dev Tunnel yang sedang aktif, lalu masukkan ke `local_config.dart`.

---

## 📊 Status Proyek

| Komponen | Status |
|----------|--------|
| Flutter Frontend | 🟡 In Development |
| FastAPI Backend | 🟡 In Development |
| C-Engine (Scoring) | ✅ Selesai |
| Alfagift Scraper | 🟡 In Development |
| OCR (Gemini Vision) | ✅ Selesai |
| Supabase Auth (Google Sign-In) | ✅ Selesai |
| Shopping List | ✅ Selesai |
| Expense Tracker | ✅ Selesai |
| Push Notifications | 🔴 Belum |
| Production Deployment | 🔴 Belum |

---

## ⚠️ Catatan Keamanan untuk Tim

- **JANGAN commit `backend/.env` atau `local_config.dart` ke Git**
- **JANGAN share URL Dev Tunnel secara publik** — tunnel tidak terproteksi password di mode development
- JWT verification saat ini dalam **mode development** — wajib diaktifkan sebelum deployment production

---

## 📬 Kontak Tim

| Role | Nama |
|------|------|
| Fullstack Lead | Fallah |
| Backend / Engine | Tim Backend |
| Frontend / UI | Tim Frontend |

---

<div align="center">
  <sub>Built with ❤️ by WorthIt Team · 2026</sub>
</div>
