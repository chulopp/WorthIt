<div align="center">
  <h1>WorthIt</h1>
  <p><strong>Real-Time Shopping Decision Validation Assistant</strong></p>
  <p>
    <img alt="Flutter" src="https://img.shields.io/badge/Flutter-3.x-02569B?logo=flutter&logoColor=white"/>
    <img alt="FastAPI" src="https://img.shields.io/badge/FastAPI-0.128-009688?logo=fastapi&logoColor=white"/>
    <img alt="Supabase" src="https://img.shields.io/badge/Supabase-2.x-3ECF8E?logo=supabase&logoColor=white"/>
    <img alt="Python" src="https://img.shields.io/badge/Python-3.11+-3776AB?logo=python&logoColor=white"/>
    <img alt="Status" src="https://img.shields.io/badge/Status-Production%20Ready-brightgreen"/>
    <img alt="License" src="https://img.shields.io/badge/License-All%20Rights%20Reserved-red"/>
  </p>
</div>

---

## Overview

**WorthIt** is a mobile application designed to assist consumers in validating shopping decisions in real-time while in-store. By scanning receipts or price tags, the system evaluates whether a product's price is **Worth It** (Fair), **Caution** (Slightly High), or **Expensive** — based on historical pricing data processed using Weighted Moving Average (WMA) and Support/Resistance algorithms.

### Key Features

| Feature | Description |
|---------|-------------|
| OCR Scan | Instant receipt and price tag scanning via Gemini Vision AI |
| Price Analysis | Real-time BUY / SUBSTITUTE / DONT_BUY decision engine backed by WMA |
| Shopping List | Monthly shopping lists with dynamic budget estimations |
| Expense Tracker | Categorized spending history and analytics |
| Favorites | Saved product tracking with historical price monitoring |
| Push Notifications | In-app alerts for price changes and product updates |

---

## System Architecture

```text
+───────────────────────────────────────────────────────────+
|                     FRONTEND (Mobile)                     |
|    Flutter 3.x  -  Riverpod  -  Dio  -  Supabase SDK      |
+───────────────────────────────────────────────────────────+
|                     BACKEND (Python)                      |
|    FastAPI  -  Uvicorn  -  PyJWT  -  Supabase Python      |
+───────────────────────────────────────────────────────────+
|                        C-ENGINE                           |
|    worthit_engine.c  -  ctypes bridge (c_bridge.py)      |
|    WMA  -  Support  -  Resistance  -  SR Position         |
+───────────────────────────────────────────────────────────+
|                      INFRASTRUCTURE                       |
|    Supabase (Auth + PostgreSQL + Storage)                 |
|    WSL2 (Ubuntu)  -  Microsoft Dev Tunnels                |
|    Gemini 2.5 Flash (OCR/Vision)                          |
|    Playwright + APScheduler (Alfagift Scraper)            |
+───────────────────────────────────────────────────────────+
```

---

## System Requirements

### Prerequisites for All Team Members

| Component | Minimum Version | Notes |
|-----------|-----------------|-------|
| Flutter SDK | 3.11.5+ | Install via [flutter.dev](https://docs.flutter.dev/get-started/install) |
| Dart SDK | 3.11.5+ | Bundled with Flutter |
| Android SDK | API 21+ | via Android Studio |
| Git | Latest | |

### Prerequisites for Backend Developers

| Component | Minimum Version | Notes |
|-----------|-----------------|-------|
| WSL2 (Ubuntu 22.04+) | - | Required for running backend services |
| Python | 3.11+ | Installed inside WSL |
| pip / venv | Latest | Standard virtual environment tools |
| Microsoft Dev Tunnels CLI | Latest | [Install Dev Tunnels](https://learn.microsoft.com/en-us/azure/developer/dev-tunnels/get-started) |
| GCC (build tools) | - | Required for C-Engine compilation: `sudo apt install build-essential` |

---

## Getting Started

### Local Setup (Flutter Frontend)

**1. Clone the repository**
```bash
git clone https://github.com/<your-org>/worthit.git
cd worthit/frontend
```

**2. Configure environment settings**

Create `local_config.dart` from the provided template:

```bash
cp lib/config/local_config.example.dart lib/config/local_config.dart
```

Update `lib/config/local_config.dart` with your Supabase credentials and backend API URL:

```dart
class LocalConfig {
  static const supabaseUrl = 'https://YOUR_PROJECT.supabase.co';
  static const supabaseAnonKey = 'sb_publishable_XXXX...';
  static const supabaseAuthRedirectUrl = 'com.example.worthit_app://login-callback';

  // Active Dev Tunnel URL
  static const apiBaseUrl = 'https://XXXX-XXXX.devtunnels.ms';
}
```

**3. Install dependencies and run**
```bash
flutter pub get
flutter run
```

---

### Backend Setup (Python / FastAPI in WSL2)

> [!IMPORTANT]
> The backend setup must be performed inside a **WSL2 terminal**, not Windows PowerShell.

**1. Navigate to backend directory inside WSL**
```bash
# In Windows PowerShell:
wsl

# Inside WSL:
cd "/mnt/d/Fallah's File/Code/Personal Project/WorthIt/backend"
```

**2. Setup virtual environment and install dependencies**
```bash
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
```

**3. Configure Environment Variables**

Create a `.env` file in the `backend/` directory:

```env
SUPABASE_URL=https://YOUR_PROJECT.supabase.co
SUPABASE_SERVICE_ROLE_KEY=eyJhbG...
SUPABASE_JWT_SECRET=YOUR_JWT_SECRET
GEMINI_API_KEY=AIza...
```

**4. Build the C-Engine shared library**
```bash
cd engine
gcc -shared -fPIC -o worthit_engine.so worthit_engine.c -lm
cd ..
```

**5. Start the API server**
```bash
uvicorn main:app --reload --host 0.0.0.0 --port 8000
```

The service will run at `http://localhost:8000`. Interactive API documentation is available at `http://localhost:8000/docs`.

---

### Exposing Backend via Microsoft Dev Tunnels

To enable physical Android devices to communicate with the local backend running in WSL:

**1. Log in to Dev Tunnels**
```bash
devtunnel user login
```

**2. Start hosting port 8000**
```bash
devtunnel host -p 8000 --allow-anonymous
```

Copy the generated URL (e.g., `https://XXXX-8000.devtunnels.ms`) and update `apiBaseUrl` in `local_config.dart`.

---

## Project Structure

```
WorthIt/
├── docs/                       # Android release guide & infrastructure specs
├── frontend/                   # Flutter Mobile Application
│   └── lib/
│       ├── config/             # Environment & API configurations
│       ├── controllers/        # State management (Riverpod Notifiers)
│       ├── models/             # Data models & DTOs
│       ├── repositories/       # Data access layer
│       ├── screens/            # UI screens & views
│       ├── services/           # Authentication, Notifications, Privacy
│       ├── utils/              # PDF generation, Snackbar, Image helpers
│       └── widgets/            # Reusable UI components
│
├── backend/                    # FastAPI Backend Service
│   ├── core/                   # Security (JWT), Categories, Embedding Engine
│   ├── engine/                 # C-Engine bindings, WMA scoring, Similarity
│   ├── models/                 # Pydantic schemas
│   ├── routers/                # API Endpoints (Analysis, Scan, Shopping, etc.)
│   ├── scripts/                # Price scrapers, Embeddings generation, Benchmarks
│   ├── utils/                  # Supabase client singleton
│   ├── main.py                 # FastAPI application entrypoint
│   └── requirements.txt
│
└── supabase/migrations/        # SQL Migration scripts (Database schemas & pgvector)
```

---

## Database Architecture

WorthIt utilizes **Supabase (PostgreSQL)** for data storage. Primary tables include:

| Table | Description |
|-------|-------------|
| `users` | User profiles, subscription tier, and monthly budget settings |
| `products` | Product catalog and metadata |
| `price_history` | Historical price tracking per product |
| `scan_history` | Receipt and price tag scan logs |
| `purchase_history` | Verified user purchase records |
| `monthly_shopping_lists` | User monthly shopping lists |
| `shopping_list_items` | Individual items in shopping lists |
| `favorite_products` | Bookmarked products for price monitoring |
| `notifications` | In-app notification delivery log |

---

## Team Onboarding

1. **Clone** the repository.
2. Request necessary environment credentials from project leads (`backend/.env` & Supabase keys).
3. Follow **Local Setup** instructions above.
4. For frontend-only development, connect to an active Dev Tunnel endpoint without launching a local backend instance.

---

## Project Status

| Component | Status |
|-----------|--------|
| Flutter Frontend | ✅ Completed |
| FastAPI Backend | ✅ Completed |
| C-Engine (Scoring Algorithm) | ✅ Completed |
| ML Substitution Engine | ✅ Completed |
| Alfagift Price Scraper | ✅ Completed |
| OCR (Gemini Vision AI) | ✅ Completed |
| Supabase Auth (Google Sign-In) | ✅ Completed |
| Shopping List Module | ✅ Completed |
| Expense Tracker Module | ✅ Completed |
| Push Notifications | ✅ Completed |
| Production Deployment Setup | ✅ Completed |

---

## Security Guidelines

- **Never commit environment configuration files (`backend/.env` or `local_config.dart`) to source control.**
- Keep Dev Tunnel endpoints confidential during active development sessions.
- Ensure production environments enforce strict JWT signature verification.

---

## Team & Contact

| Name | Role |
|------|------|
| **Fallah Iqbal Kurnianto** | Founder & CEO |
| **Wendi Adi Ardiansah** | Co-Founder & COO |
| **Jovan Amadeo Hutagalung** | Co-Founder & CTO |

---

## License

Copyright © 2026 WorthIt Team (Fallah Iqbal Kurnianto, Wendi Adi Ardiansah, Jovan Amadeo Hutagalung). All Rights Reserved.

This project is proprietary software. Unauthorized copying, distribution, or modification of any part of this repository is strictly prohibited. See [LICENSE](LICENSE) for details.
