# WorthIt — Rencana Implementasi Backtest Akademik + Kalibrasi Parameter

> **Scope:** Modul B dari INFRASTRUCTURE_UPGRADE_PLAN.md — diperluas dengan Bayesian Parameter Optimization
> **Target:** 1000 produk di database Supabase production
> **Metode kalibrasi:** Optuna (Bayesian Optimization, 500 trials)
> **Output:** Parameter engine yang terbukti empiris + Laporan Akademik Markdown (Bahasa Indonesia)

---

## Ringkasan Keputusan Desain

| Keputusan | Pilihan |
|---|---|
| Tujuan akhir | Kalibrasi parameter dulu → laporan akademik final |
| Metode optimasi | Bayesian Optimization (Optuna) |
| Objective function | MDA (Mean Directional Accuracy) |
| Parameter yang dioptimalkan | 4 parameter Python-side engine |
| Jumlah trials | 500 trials |
| Data sumber | Supabase production (1000 produk) |
| Struktur script | 3 script terpisah |
| Format laporan | Markdown (.md) — Bahasa Indonesia |
| Metrik laporan | Full academic suite + parameter sensitivity table |
| Strategi validasi | Walk-forward (N-1 training, 1 bulan test) |
| Resume capability | SQLite persistence via Optuna |

---

## Konteks: Parameter Engine yang Dioptimalkan

Berdasarkan kode `engine/scoring.py`, terdapat 4 parameter Python-side yang dikalibrasi:

### Parameter 1 — WMA Look-back Window (`MAX_HISTORY_MONTHS`)

```python
# Saat ini: MAX_HISTORY_MONTHS = 6
# Search space: int ∈ [2, 6]
```

Menentukan berapa bulan historis yang dipakai menghitung WMA (harga normal referensi).

### Parameter 2 — Epsilon Threshold (`THRESHOLD_PCT`)

```python
# Saat ini: belum ada di backtest, akan ditambahkan
# Search space: float ∈ [0.5, 3.0]  (dalam persen)
```

Menentukan batas minimum perubahan harga untuk diklasifikasikan sebagai "Naik" atau "Turun" (bukan noise).

### Parameter 3 — Decision Boundaries (skor WorthIt dan Waspada)

```python
# Saat ini: WorthIt ≥ 75, Waspada ≥ 50, Mahal < 50
# Search space: worthit_min ∈ [65, 85], waspada_min ∈ [40, 60]
# Constraint: waspada_min < worthit_min
```

### Parameter 4 — Urgency Score Values (Semua 3 Level)

```python
# Saat ini: {1: 3, 2: 8, 3: 15}
# Search space:
#   urgency_low    ∈ [1, 5]    ← nilai untuk urgency=1 (tidak mendesak)
#   urgency_neutral ∈ [5, 12]  ← nilai untuk urgency=2 (biasa saja)
#   urgency_high   ∈ [10, 15]  ← nilai untuk urgency=3 (sangat mendesak)
# Constraint: urgency_low < urgency_neutral < urgency_high
```

Ketiga level urgency dioptimalkan sekaligus dengan constraint monoton (urgensi lebih tinggi = skor lebih tinggi). Hasil optimal akan diterapkan ke `compute_urgency_score()` di `engine/scoring.py`.

> [!NOTE]
> WMA computation (rumus matematis weighted moving average) ada di C-engine (`worthit_engine.c`) dan **tidak diubah**. Yang dioptimalkan hanya parameter Python-side di atas.

---

## Arsitektur: 3-Script Pipeline

```
Supabase (1000 produk)
        │
        ▼
┌────────────────────────────┐
│  TAHAP 1: tune_parameters.py│   ← Optuna 500 trials + SQLite
│  Objective: max MDA        │
│  Output: best_params.json  │
└────────────────────────────┘
        │
        ▼ best_params.json
┌────────────────────────────────┐
│  TAHAP 2: backtest_academic.py │   ← Full pipeline dengan best params
│  Metrik: MDA, κ, F1, matrix   │
│  Output: backtest_academic.json│
└────────────────────────────────┘
        │
        ▼ backtest_academic.json
┌─────────────────────────────────────┐
│  TAHAP 3: generate_academic_report.py│   ← Laporan Markdown siap pakai
│  Output: backtest_academic_report.md │
└─────────────────────────────────────┘
```

---

## Proposed Changes

### Dependency Baru

#### [MODIFY] `backend/requirements.txt`

Tambahkan:

```
optuna>=3.6.1
scikit-learn>=1.5.0   # untuk confusion_matrix, cohen_kappa_score, classification_report
scipy>=1.13.0         # untuk two-proportion z-test
```

---

### Tahap 1 — Kalibrasi Parameter

#### [NEW] `backend/scripts/tune_parameters.py`

**Docstring / usage:**

```python
"""
tune_parameters.py — Bayesian Hyperparameter Optimization untuk WorthIt Engine

Menggunakan Optuna untuk mencari kombinasi parameter engine yang menghasilkan
MDA (Mean Directional Accuracy) tertinggi pada dataset 1000 produk Supabase.

Persistence: Optuna menyimpan progress ke SQLite (data/optuna_study.db)
sehingga bisa di-resume jika proses terhenti.

Usage:
  python scripts/tune_parameters.py             # jalankan 500 trials
  python scripts/tune_parameters.py --trials 50 # custom jumlah trials
  python scripts/tune_parameters.py --resume    # lanjut dari trial terakhir
"""
```

**Search Space yang didefinisikan:**

```python
def objective(trial, product_data_cache):
    # Parameter 1: WMA look-back window
    wma_window = trial.suggest_int("wma_window", 2, 6)

    # Parameter 2: Epsilon threshold (%)
    epsilon_pct = trial.suggest_float("epsilon_pct", 0.5, 3.0, step=0.1)

    # Parameter 3: Decision boundaries
    worthit_min = trial.suggest_int("worthit_min", 65, 85)
    waspada_min = trial.suggest_int("waspada_min", 40, 60)
    if waspada_min >= worthit_min:    # constraint
        raise optuna.exceptions.TrialPruned()

    # Parameter 4: Urgency score — semua 3 level dioptimalkan
    urgency_low     = trial.suggest_int("urgency_low",     1,  5)
    urgency_neutral = trial.suggest_int("urgency_neutral", 5, 12)
    urgency_high    = trial.suggest_int("urgency_high",   10, 15)
    if not (urgency_low < urgency_neutral < urgency_high):   # constraint monoton
        raise optuna.exceptions.TrialPruned()

    # Jalankan walk-forward backtest dengan parameter ini
    # (backtest menggunakan urgency=2 → urgency_neutral sebagai skor)
    mda = _run_backtest_with_params(
        product_data_cache,
        wma_window, epsilon_pct, worthit_min, waspada_min,
        urgency_low, urgency_neutral, urgency_high
    )
    return mda
```

**Cache strategy:**
- Semua data produk + price_history di-fetch dari Supabase **sekali di awal**, disimpan di memory sebagai `product_data_cache`.
- Setiap trial Optuna menggunakan cache ini → tidak ada overhead network per trial.
- Estimasi ukuran cache: ~50–100 MB RAM untuk 1000 produk dengan 12 bulan historis.

**SQLite persistence:**

```python
storage = optuna.storages.RDBStorage("sqlite:///data/optuna_study.db")
study = optuna.create_study(
    study_name="worthit_param_tuning",
    storage=storage,
    load_if_exists=True,    # ← resume dari trial terakhir jika ada
    direction="maximize",   # ← maximize MDA
)
study.optimize(objective_fn, n_trials=500, show_progress_bar=True)
```

**Output: `data/best_params.json`**

```json
{
  "best_mda": 0.823,
  "best_params": {
    "wma_window": 4,
    "epsilon_pct": 1.5,
    "worthit_min": 72,
    "waspada_min": 48,
    "urgency_low": 3,
    "urgency_neutral": 9,
    "urgency_high": 15
  },
  "n_trials_completed": 500,
  "study_name": "worthit_param_tuning",
  "generated_at": "2026-07-22T...",
  "parameter_importance": {
    "epsilon_pct": 0.38,
    "worthit_min": 0.24,
    "wma_window": 0.16,
    "urgency_high": 0.09,
    "waspada_min": 0.07,
    "urgency_neutral": 0.04,
    "urgency_low": 0.02
  }
}
```

> [!IMPORTANT]
> `parameter_importance` dihitung otomatis oleh Optuna menggunakan **fANOVA** (functional ANOVA) — ini yang akan jadi dasar **parameter sensitivity table** di laporan akademik.

---

### Tahap 2 — Backtest Akademik

#### [NEW] `backend/scripts/backtest_academic.py`

**Beda dari `backtest_v2.py`:**
- Membaca `best_params.json`, apply parameter optimal ke engine
- Mengganti `_is_correct()` lama dengan `_classify_actual_movement()` berbasis ε-threshold
- Menghitung semua metrik akademik (bukan hanya hit_rate sederhana)
- Menghitung Naïve Persistence Baseline untuk perbandingan
- Menghitung p-value (two-proportion z-test)

**Fungsi kunci baru:**

```python
THRESHOLD_PCT = best_params["epsilon_pct"]  # ← dari best_params.json

def _classify_actual_movement(current: float, future: float) -> str:
    """Label aktual: 'Naik', 'Turun', atau 'Stabil' berdasarkan ε-threshold."""
    if current <= 0:
        return "Stabil"
    delta_pct = (future - current) / current * 100
    if delta_pct > THRESHOLD_PCT:
        return "Naik"
    elif delta_pct < -THRESHOLD_PCT:
        return "Turun"
    return "Stabil"

def _get_naive_prediction(prev_prices: list[float]) -> str:
    """Naïve Persistence: prediksi harga bulan depan = harga bulan ini."""
    # Selalu prediksi "Stabil" — model naif tidak mampu prediksi arah
    return "Stabil"
```

**Output: `data/backtest_academic.json`**

```json
{
  "params_used": { "...": "isi dari best_params.json" },
  "threshold_pct": 1.5,
  "n_products_tested": 950,
  "n_products_skipped": 50,

  "model_metrics": {
    "mda": 0.823,
    "cohen_kappa": 0.61,
    "per_class": {
      "WorthIt": {"precision": 0.81, "recall": 0.76, "f1": 0.78, "support": 312},
      "Mahal":   {"precision": 0.74, "recall": 0.71, "f1": 0.72, "support": 198},
      "Waspada": {"precision": 0.63, "recall": 0.68, "f1": 0.65, "support": 440}
    },
    "confusion_matrix": [[265, 30, 17], [22, 287, 131], [15, 48, 135]]
  },

  "baseline_metrics": {
    "naive_persistence_mda": 0.512,
    "p_value_vs_baseline": 0.003,
    "is_significant": true,
    "significance_level": 0.05
  },

  "parameter_sensitivity": { "...": "dari best_params.json parameter_importance" },

  "raw_results": [ "..." ],
  "generated_at": "..."
}
```

---

### Tahap 3 — Laporan Akademik

#### [NEW] `backend/scripts/generate_academic_report.py`

Membaca `backtest_academic.json` dan menghasilkan **`data/backtest_academic_report.md`** — dokumen siap pakai untuk proposal/skripsi dalam **Bahasa Indonesia**.

**Struktur laporan Markdown yang dihasilkan:**

```markdown
# Laporan Evaluasi Algoritma Scoring WorthIt
## Metode: Walk-Forward Validation dengan Threshold ε

### 1. Ringkasan Parameter Optimal (Hasil Kalibrasi Bayesian)
[tabel parameter: nilai sebelum kalibrasi vs nilai optimal hasil Optuna]

### 2. Metrik Evaluasi Utama
[tabel: MDA, Cohen's κ, Baseline MDA, p-value, status signifikansi]

### 3. Perbandingan dengan Baseline (Naïve Persistence)
[narasi two-proportion z-test, interpretasi statistik dalam BI]

### 4. Confusion Matrix
[tabel 3×3: Actual (baris) vs Predicted (kolom) — WorthIt/Waspada/Mahal]

### 5. Precision / Recall / F1 per Kelas
[tabel per kelas dengan kolom support dan interpretasi dalam BI]

### 6. Parameter Sensitivity Analysis
[tabel importance score setiap parameter dari Optuna fANOVA]
[narasi otomatis: "Parameter ε (epsilon) memiliki pengaruh terbesar (38%) terhadap MDA..."]

### 7. Metodologi
[penjelasan Walk-Forward Validation, ε-threshold, referensi akademik]

### 8. Kesimpulan
[narasi otomatis berdasarkan nilai metrik — seluruhnya Bahasa Indonesia]
```

---

## Urutan Eksekusi (untuk teman via vibe coding)

```bash
# Step 0: Install dependency baru
pip install optuna scikit-learn scipy

# Step 1: Kalibrasi parameter (~30-45 menit, bisa diinterrupt & resume)
python backend/scripts/tune_parameters.py --trials 500

# Jika proses terhenti di tengah, lanjutkan dengan:
python backend/scripts/tune_parameters.py --resume

# Step 2: Jalankan backtest akademik dengan parameter terbaik (~5-10 menit)
python backend/scripts/backtest_academic.py

# Step 3: Generate laporan Markdown
python backend/scripts/generate_academic_report.py

# Output akhir ada di:
# backend/data/best_params.json              ← parameter optimal hasil kalibrasi
# backend/data/optuna_study.db               ← SQLite study (resume jika perlu)
# backend/data/backtest_academic.json        ← data backtest lengkap
# backend/data/backtest_academic_report.md   ← laporan siap pakai
```

---

## Verification Plan

### Automated Checks (dalam script)

- `tune_parameters.py` harus output `best_mda > 0.5` (lebih baik dari random)
- `backtest_academic.py` harus output `p_value < 0.05` (signifikan vs baseline)
- `backtest_academic.py` harus output `cohen_kappa >= 0.4` (minimal "moderat" untuk paper)

### Manual Verification

1. Buka `backtest_academic_report.md` dan pastikan semua 8 section terisi dengan data nyata
2. Verifikasi bahwa parameter di `best_params.json` masuk akal (tidak nilai ekstrem)
3. Pastikan constraint urgency terpenuhi: `urgency_low < urgency_neutral < urgency_high`
4. Pastikan constraint boundary terpenuhi: `waspada_min < worthit_min`
5. Pastikan confusion matrix baris dan kolom labelnya benar (WorthIt/Waspada/Mahal)
