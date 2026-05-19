/*
 * worthit_engine.c — WorthIt Core Scoring Engine
 *
 * Low-level computation module yang di-compile menjadi shared library (.so)
 * dan di-bridge ke Python via ctypes. Memisahkan kalkulasi numerik intensif
 * dari Python runtime untuk efisiensi maksimal pada hot path scoring.
 *
 * Algoritma yang diimplementasi:
 *  - Weighted Moving Average (WMA)   — bobot linear terhadap recency data
 *  - Support / Resistance detection  — price floor & ceiling dari historis
 *  - S/R Position calculation        — posisi relatif 0–100% dalam range harga
 *  - Binary Search pada PriceRecord  — O(log n) lookup pada sorted array
 *  - Case-insensitive fuzzy match    — substring search untuk nama produk
 *
 * Compile:
 *   gcc -shared -fPIC -O2 -o worthit_engine.so worthit_engine.c -lm
 *
 * Dependencies: <string.h>, <ctype.h> (C standard library only)
 */

#include <string.h>
#include <ctype.h>

/* ─── Data Structures ──────────────────────────────────────────────────────── */

/**
 * PriceRecord — unit data harga untuk satu produk pada satu titik waktu.
 *
 * Digunakan oleh binary_search_price() dan harus disimpan dalam keadaan
 * terurut (sorted) berdasarkan product_id ASC, timestamp ASC agar binary
 * search memberikan hasil O(log n) yang benar.
 *
 * Fields:
 *   product_id   — UUID produk (max 63 karakter + null terminator)
 *   price        — harga dalam IDR (float, presisi cukup untuk range Rp500–Rp1jt)
 *   weight_gram  — berat produk dalam gram, dipakai oleh shrinkflation detector
 *   timestamp    — Unix timestamp (detik) waktu pencatatan harga
 */
typedef struct {
    char  product_id[64];
    float price;
    float weight_gram;
    long  timestamp;
} PriceRecord;


/* ─── Weighted Moving Average ──────────────────────────────────────────────── */

/**
 * calculate_wma — Menghitung Weighted Moving Average dengan bobot arbitrer.
 *
 * Berbeda dari Simple Moving Average (SMA) yang memberi bobot sama pada semua
 * data, WMA memberi bobot lebih tinggi pada data yang lebih baru sehingga
 * sinyal harga terkini lebih dominan dalam menentukan "normal price".
 *
 * Kompleksitas Waktu  : O(n) — satu pass linear atas seluruh data
 * Kompleksitas Ruang  : O(1) — tidak ada alokasi heap; akumulasi inline
 *
 * Formula:
 *   WMA = Σ(prices[i] × weights[i]) / Σ(weights[i])
 *
 * @param prices   Array harga per-bulan, urutan TERLAMA → TERBARU
 * @param weights  Array bobot paralel dengan prices (bobot 1,2,...,n untuk WMA linear)
 * @param count    Jumlah elemen (harus sama antara prices dan weights)
 * @return         Nilai WMA, atau 0.0f jika count == 0 atau total bobot == 0
 */
float calculate_wma(float* prices, float* weights, int count) {
    if (count <= 0) return 0.0f;

    float weighted_sum = 0.0f;
    float weight_total = 0.0f;

    for (int i = 0; i < count; i++) {
        weighted_sum += prices[i] * weights[i];
        weight_total += weights[i];
    }

    /* Guard terhadap pembagian nol jika semua bobot adalah 0 */
    if (weight_total == 0.0f) return 0.0f;
    return weighted_sum / weight_total;
}


/* ─── Support / Resistance Detection ──────────────────────────────────────── */

/**
 * calculate_support — Menentukan Support Level (harga terendah historis).
 *
 * Support merepresentasikan price floor — titik di mana harga secara historis
 * cenderung "memantul" naik. Dipakai bersama resistance untuk menghitung
 * S/R Position yang menjadi komponen skor ke-2 (bobot 0–25 poin).
 *
 * Kompleksitas Waktu  : O(n) — linear scan mencari minimum
 * Kompleksitas Ruang  : O(1)
 *
 * @param prices  Array harga historis
 * @param count   Jumlah elemen
 * @return        Harga minimum, atau 0.0f jika count == 0
 */
float calculate_support(float* prices, int count) {
    if (count <= 0) return 0.0f;

    float min_price = prices[0];
    for (int i = 1; i < count; i++) {
        if (prices[i] < min_price) min_price = prices[i];
    }
    return min_price;
}

/**
 * calculate_resistance — Menentukan Resistance Level (harga tertinggi historis).
 *
 * Resistance merepresentasikan price ceiling — batas atas di mana harga secara
 * historis sulit ditembus. Harga scanned yang mendekati resistance mengindikasikan
 * produk sedang berada di puncak siklus harga.
 *
 * Kompleksitas Waktu  : O(n) — linear scan mencari maksimum
 * Kompleksitas Ruang  : O(1)
 *
 * @param prices  Array harga historis
 * @param count   Jumlah elemen
 * @return        Harga maksimum, atau 0.0f jika count == 0
 */
float calculate_resistance(float* prices, int count) {
    if (count <= 0) return 0.0f;

    float max_price = prices[0];
    for (int i = 1; i < count; i++) {
        if (prices[i] > max_price) max_price = prices[i];
    }
    return max_price;
}

/**
 * calculate_sr_position — Menghitung posisi harga dalam range Support/Resistance.
 *
 * Menghasilkan nilai persentase (0–100%) yang merepresentasikan di mana
 * posisi harga scan berada relatif terhadap kisaran harga historis:
 *   - 0%   = tepat di Support (harga terbaik)
 *   - 50%  = di tengah range (harga normal)
 *   - 100% = tepat di Resistance (harga paling mahal)
 *
 * Kompleksitas Waktu  : O(1)
 * Kompleksitas Ruang  : O(1)
 *
 * Edge case: jika support == resistance (harga selalu stabil), kembalikan 50.0f
 * untuk menghindari pembagian nol dan mengindikasikan posisi netral.
 *
 * @param current_price  Harga yang di-scan pengguna
 * @param support        Support level dari calculate_support()
 * @param resistance     Resistance level dari calculate_resistance()
 * @return               Posisi dalam [0.0f, 100.0f]
 */
float calculate_sr_position(float current_price, float support, float resistance) {
    float range = resistance - support;

    /* Edge case: pasar flat (tidak ada volatilitas), posisi netral */
    if (range <= 0.0f) return 50.0f;

    float position = (current_price - support) / range * 100.0f;

    /* Clamp ke [0, 100] untuk harga di luar range historis */
    if (position < 0.0f)   position = 0.0f;
    if (position > 100.0f) position = 100.0f;

    return position;
}


/* ─── Binary Search — O(log n) Price Lookup ───────────────────────────────── */

/**
 * binary_search_price — Pencarian O(log n) pada array PriceRecord yang terurut.
 *
 * Menggunakan composite key (product_id, timestamp) untuk mencari data harga
 * historis secara efisien. Array HARUS terurut secara ascending berdasarkan
 * product_id, kemudian timestamp — jika tidak, hasil tidak dijamin benar.
 *
 * Perbandingan kunci dilakukan dalam dua tahap:
 *   1. strcmp()   untuk product_id  (leksikografis)
 *   2. long ==    untuk timestamp    (numerik)
 *
 * Kompleksitas Waktu  : O(log n) — binary search standar
 * Kompleksitas Ruang  : O(1) — tidak ada rekursi atau alokasi
 *
 * @param records     Pointer ke array PriceRecord yang terurut
 * @param n           Jumlah elemen dalam array
 * @param product_id  Product UUID yang dicari (null-terminated string)
 * @param target_ts   Unix timestamp target
 * @return            Indeks record yang cocok, atau -1 jika tidak ditemukan
 */
int binary_search_price(PriceRecord* records, int n, const char* product_id, long target_ts) {
    int low = 0, high = n - 1;

    while (low <= high) {
        /* Midpoint dihitung sebagai low + (high-low)/2 untuk menghindari
         * integer overflow pada array berukuran sangat besar */
        int mid = low + (high - low) / 2;
        int product_cmp = strcmp(records[mid].product_id, product_id);

        if (product_cmp == 0 && records[mid].timestamp == target_ts) return mid;

        /* Geser batas berdasarkan urutan composite key */
        if (product_cmp < 0 || (product_cmp == 0 && records[mid].timestamp < target_ts)) {
            low = mid + 1;
        } else {
            high = mid - 1;
        }
    }
    return -1; /* tidak ditemukan */
}


/* ─── Fuzzy String Matching ────────────────────────────────────────────────── */

/**
 * sequential_search_fuzzy — Case-insensitive substring match untuk nama produk.
 *
 * Menerapkan normalisasi lowercase pada kedua string sebelum melakukan
 * pencarian substring via strstr(). Dipakai sebagai fast pre-filter sebelum
 * fuzzy matching berbasis Levenshtein di Python layer.
 *
 * Kompleksitas Waktu  : O(n × m) — strstr() pada worst case, dengan n = |name|, m = |query|
 * Kompleksitas Ruang  : O(1) — buffer stack fixed-size 256 byte
 *
 * Buffer Safety: kedua string dipotong pada 255 karakter untuk mencegah
 * stack overflow; karakter ke-256 selalu di-null-terminate secara eksplisit.
 *
 * @param name   String nama produk dari database (null-terminated)
 * @param query  String query pengguna (null-terminated)
 * @return       1 jika query ditemukan dalam name (case-insensitive), 0 jika tidak
 */
int sequential_search_fuzzy(const char* name, const char* query) {
    if (!name || !query) return 0;

    char name_lower[256];
    char query_lower[256];

    int i;
    for (i = 0; name[i] && i < 255; i++) name_lower[i] = (char)tolower((unsigned char)name[i]);
    name_lower[i] = '\0';

    for (i = 0; query[i] && i < 255; i++) query_lower[i] = (char)tolower((unsigned char)query[i]);
    query_lower[i] = '\0';

    return strstr(name_lower, query_lower) != NULL;
}
