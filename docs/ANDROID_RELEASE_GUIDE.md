# Panduan Pembuatan Keystore, Rilis Produksi, Sentry, & Google Play Billing (WorthIt App)

Dokumen ini menjelaskan langkah-langkah praktis untuk mempersiapkan aplikasi Android WorthIt menuju rilis produksi, mulai dari penandatanganan aplikasi (*App Signing*), monitoring error menggunakan Sentry, proses rilis di Google Play Store, hingga integrasi sistem pembayaran langganan menggunakan Google Play Billing dan verifikasi backend Supabase.

---

## Daftar Isi
1. [Langkah 1: Pembuatan Android Keystore & Rilis Produksi](#langkah-1-pembuatan-android-keystore--rilis-produksi)
2. [Langkah 2: Integrasi Sentry untuk Error Monitoring](#langkah-2-integrasi-sentry-untuk-error-monitoring)
3. [Langkah 3: Persiapan Akun & Deploy ke Google Play Store](#langkah-3-persiapan-akun--deploy-ke-google-play-store)
4. [Langkah 4: Integrasi Google Play Billing di Frontend (Flutter)](#langkah-4-integrasi-google-play-billing-di-frontend-flutter)
5. [Langkah 5: Validasi Pembayaran Sisi Backend (Supabase Edge Functions)](#langkah-5-validasi-pembayaran-sisi-backend-supabase-edge-functions)

---

## Langkah 1: Pembuatan Android Keystore & Rilis Produksi

Langkah ini diperlukan untuk menandatangani aplikasi (*App Signing*) agar sistem Android dan Google Play Store mempercayai berkas aplikasi Anda.

### 1.1 Buat File Keystore (.jks)
Buka terminal Anda (baik Command Prompt, PowerShell, atau WSL) dan jalankan perintah `keytool` bawaan Java SDK/Flutter.

**Di Windows (Command Prompt / PowerShell):**
```bash
keytool -genkey -v -keystore D:\worthit-release-key.jks -storetype PKCS12 -keyalg RSA -keysize 2048 -validity 10000 -alias worthit-key
```
*(Catatan: Anda bisa mengubah `D:\worthit-release-key.jks` ke direktori aman mana saja).*

**Di macOS / Linux:**
```bash
keytool -genkey -v -keystore ~/worthit-release-key.jks -storetype PKCS12 -keyalg RSA -keysize 2048 -validity 10000 -alias worthit-key
```

**Yang akan ditanyakan saat pembuatan:**
1. **Password**: Buat password yang kuat dan **catat password ini** (jangan sampai lupa!).
2. **Data diri**: Isi nama, unit organisasi, kota, provinsi, dan kode negara (misal: ID untuk Indonesia).
3. **Konfirmasi**: Ketik `y` atau `yes` jika data sudah benar.

Simpan file `worthit-release-key.jks` dan backup di tempat aman.

### 1.2 Buat File Kredensial (`key.properties`)
Di dalam folder `frontend/android/` proyek Anda, buat file baru bernama `key.properties`. File ini digunakan oleh script build Gradle untuk membaca kunci penandatanganan secara otomatis.

> [!WARNING]
> File `key.properties` berisi password rahasia dan sudah terdaftar di `.gitignore` agar tidak terunggah ke Git publik. **Jangan pernah menghapus baris ignore untuk file ini**.

Isi file `key.properties` dengan format berikut:
```properties
storePassword=PASSWORD_KEYSTORE_ANDA
keyPassword=PASSWORD_KEYSTORE_ANDA
keyAlias=worthit-key
storeFile=C:\\path\\to\\your\\worthit-release-key.jks
```
*(Catatan untuk Windows: Gunakan double backslash `\\` untuk pemisah folder pada property `storeFile`).*

### 1.3 Lakukan Build Rilis Produksi
Jalankan perintah berikut di folder `frontend/`:
```bash
# 1. Bersihkan sisa build lama
flutter clean
flutter pub get

# 2. Build rilis produksi (.aab untuk Play Store)
flutter build appbundle --obfuscate --split-debug-info=./build/app/outputs/symbols --release
```
Hasil build berupa berkas `.aab` akan terbentuk di folder:
`frontend/build/app/outputs/bundle/release/app-release.aab`

---

## Langkah 2: Integrasi Sentry untuk Error Monitoring

Sentry digunakan untuk melacak bug dan crash yang dialami pengguna secara real-time.

### 2.1 Registrasi & Pembuatan Project di Sentry
1. Daftar atau masuk ke akun Anda di [Sentry.io](https://sentry.io/).
2. Klik **Create Project** di dashboard Sentry.
3. Pilih platform **Flutter**.
4. Beri nama project (misal: `worthit-app`) dan tentukan tim pengelola.
5. Setelah project dibuat, Sentry akan menampilkan **DSN (Data Source Name)**. Salin URL DSN tersebut. DSN akan berbentuk seperti ini:
   `https://randomhash@o000000.ingest.us.sentry.io/0000000`

### 2.2 Konfigurasi DSN di Flutter
Tambahkan nilai DSN Sentry Anda ke dalam konfigurasi lokal di [local_config.dart](file:///d:/Fallah's%20File/Code/Personal%20Project/WorthIt/frontend/lib/config/local_config.dart):
```dart
class LocalConfig {
  // ... konfigurasi lainnya ...
  
  // Sentry production error monitoring DSN key
  static const sentryDsn = 'ISI_DSN_SENTRY_ANDA_DISINI';
}
```
Aplikasi secara otomatis mendeteksi DSN ini di [main.dart](file:///d:/Fallah's%20File/Code/Personal%20Project/WorthIt/frontend/lib/main.dart) dan mengaktifkan Sentry jika DSN diisi.

### 2.3 Upload Mapping Files (De-obfuscation)
Karena kita melakukan build menggunakan flag `--obfuscate` (untuk menyamarkan kode dari reverse-engineering), stack trace di Sentry akan sulit dibaca (hanya menampilkan alamat memori seperti `main.dart: obfuscated`).

Untuk memperbaikinya, kita harus mengunggah file simbol debug secara otomatis setiap kali build rilis:
1. Pasang Sentry CLI di komputer Anda (atau gunakan integrasi Gradle).
2. Di dalam file `frontend/android/app/build.gradle`, tambahkan konfigurasi plugin Sentry:
   ```gradle
   apply plugin: 'io.sentry.android.gradle'
   
   sentry {
       // Secara otomatis mengunggah ProGuard/R8 mapping files ke Sentry
       uploadNativeSymbols = true
       includeProguardMapping = true
   }
   ```
3. Buat berkas `sentry.properties` di folder `frontend/android/` berisi auth token Anda dari akun Sentry:
   ```properties
   defaults.project=worthit-app
   defaults.org=nama-organisasi-sentry-anda
   auth.token=SENTRY_AUTH_TOKEN_ANDA
   ```
   *(Pastikan `sentry.properties` ditambahkan ke `.gitignore` Anda!)*

---

## Langkah 3: Persiapan Akun & Deploy ke Google Play Store

### 3.1 Pendaftaran Akun Google Play Console
1. Buka [Google Play Console](https://play.google.com/console/signup).
2. Masuk menggunakan akun Google Anda.
3. Pilih tipe akun (**Developer Pribadi** atau **Organisasi**).
4. Lakukan verifikasi identitas (KTP/Paspor/SIM) dan lakukan pembayaran biaya registrasi sekali seumur hidup sebesar **$25 USD**.
5. Tunggu proses review identitas dari pihak Google (biasanya memakan waktu 1–3 hari kerja).

### 3.2 Membuat Aplikasi Baru di Dashboard Console
1. Klik tombol **Create app**.
2. Isi detail dasar aplikasi:
   * **App name**: WorthIt
   * **Default language**: Indonesian (id-ID)
   * **App or game**: App
   * **Free or paid**: Free (karena monetisasi lewat In-App Billing)
3. Setujui ketentuan kebijakan Google Developer, lalu klik **Create app**.

### 3.3 Menyelesaikan App Setup Checklist
Google mewajibkan pengisian deklarasi konten aplikasi sebelum Anda bisa merilisnya. Masuk ke menu **Dashboard** aplikasi Anda, lalu isi bagian **Set up your app**:
* **Privacy Policy**: Sediakan URL kebijakan privasi WorthIt (misal halaman statis di Supabase hosting / website Anda).
* **App Access**: Pilih "All functionality is available without special access" (atau buat akun testing jika perlu login khusus).
* **Ads**: Pilih "No, my app does not contain ads".
* **Content Rating**: Isi kuesioner rating umur (biasanya masuk kategori rating 3+ / Everyone).
* **Target Audience**: Pilih target usia pengguna (misal: 13 tahun ke atas).
* **Financial Features**: Deklarasikan bahwa aplikasi adalah alat finansial/informasi harga konsumen.

### 3.4 Mengunggah Berkas ke Testing Track (Rekomendasi: Internal Testing)
Jangan langsung merilis ke Production. Gunakan **Internal Testing** untuk menguji coba billing dan tracking crash secara aman.
1. Di menu sidebar kiri, buka **Testing** > **Internal testing**.
2. Klik **Create new release**.
3. Unggah file `app-release.aab` yang telah di-build di Langkah 1.
4. Isi **Release notes** (misal: "Rilis versi awal WorthIt dengan integrasi Sentry dan Google Play Billing").
5. Klik **Save** > **Review release** > **Start rollout to Internal testing**.
6. Tambahkan alamat email penguji Anda ke daftar **Testers** di tab terpisah agar mereka mendapat link untuk mengunduh aplikasi lewat Play Store.

---

## Langkah 4: Integrasi Google Play Billing di Frontend (Flutter)

Kita menggunakan model **Subscription (Langganan)** bulanan/tahunan untuk fitur WorthIt PRO.

### 4.1 Membuat Produk Langganan di Google Play Console
1. Buka Google Play Console > Aplikasi Anda > **Monetize** > **Products** > **Subscriptions**.
2. Klik **Create subscription**.
3. Isi kolom yang diperlukan:
   * **Product ID**: `worthit_pro_monthly` (catat ID ini untuk kode Flutter)
   * **Name**: WorthIt PRO Bulanan
4. Tambahkan **Base Plan**:
   * Klik **Add base plan**.
   * Pilih tipe **Auto-renewing**.
   * Tentukan siklus penagihan (misal: Monthly/Bulanan).
   * Tentukan harga (misal: Rp 15.000).
   * Aktifkan base plan tersebut.
5. Klik **Save** > **Activate**.

### 4.2 Tambahkan Dependencies ke `pubspec.yaml`
Tambahkan package resmi Flutter untuk in-app purchase:
```yaml
dependencies:
  in_app_purchase: ^3.2.0
```
Lalu jalankan `flutter pub get` di terminal.

### 4.3 Implementasi Flutter Client-Side

Buat file baru di `frontend/lib/services/purchase_service.dart`:

```dart
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

class PurchaseService {
  final InAppPurchase _inAppPurchase = InAppPurchase.instance;
  late StreamSubscription<List<PurchaseDetails>> _subscription;
  
  // ID langganan yang didaftarkan di Google Play Console
  static const String proSubscriptionId = 'worthit_pro_monthly';

  // Callback untuk memberi tahu UI atau backend saat transaksi sukses
  Function(PurchaseDetails)? onPurchaseSuccess;
  Function(String)? onPurchaseError;

  void initialize() {
    final Stream<List<PurchaseDetails>> purchaseUpdated = _inAppPurchase.purchaseStream;
    _subscription = purchaseUpdated.listen(
      _listenToPurchaseUpdated,
      onDone: () => _subscription.cancel(),
      onError: (error) {
        if (onPurchaseError != null) onPurchaseError!(error.toString());
      },
    );
  }

  void dispose() {
    _subscription.cancel();
  }

  // Fungsi untuk memulai proses pembelian
  Future<void> buyProSubscription() async {
    final bool available = await _inAppPurchase.isAvailable();
    if (!available) {
      if (onPurchaseError != null) onPurchaseError!('Google Play Billing tidak tersedia.');
      return;
    }

    // Load detail produk dari Google Play Store
    final ProductDetailsResponse response = await _inAppPurchase.queryProductDetails({proSubscriptionId});
    if (response.notFoundIDs.contains(proSubscriptionId) || response.productDetails.isEmpty) {
      if (onPurchaseError != null) onPurchaseError!('Produk langganan tidak ditemukan.');
      return;
    }

    final ProductDetails productDetails = response.productDetails.first;
    final PurchaseParam purchaseParam = PurchaseParam(productDetails: productDetails);
    
    // Panggil UI Billing Google Play
    await _inAppPurchase.buyNonConsumable(purchaseParam: purchaseParam);
  }

  // Handler event stream dari Google Play
  void _listenToPurchaseUpdated(List<PurchaseDetails> purchaseDetailsList) async {
    for (final PurchaseDetails purchaseDetails in purchaseDetailsList) {
      if (purchaseDetails.status == PurchaseStatus.pending) {
        // Pembelian sedang diproses (misal: pembayaran via kasir Indomaret/Alfamart belum dibayar)
        debugPrint('Pembelian pending...');
      } else if (purchaseDetails.status == PurchaseStatus.error) {
        if (onPurchaseError != null) onPurchaseError!(purchaseDetails.error?.message ?? 'Terjadi kesalahan transaksi.');
      } else if (purchaseDetails.status == PurchaseStatus.purchased || 
                 purchaseDetails.status == PurchaseStatus.restored) {
        
        // Transaksi berhasil! 
        // PENTING: Jangan langsung membuka fitur PRO. Kirim token ke backend untuk validasi terlebih dahulu.
        if (onPurchaseSuccess != null) {
          onPurchaseSuccess!(purchaseDetails);
        }
      }
      
      // Selesaikan transaksi di Google Play agar tidak di-refund otomatis
      if (purchaseDetails.pendingCompletePurchase) {
        await _inAppPurchase.completePurchase(purchaseDetails);
      }
    }
  }
}
```

---

## Langkah 5: Validasi Pembayaran Sisi Backend (Supabase Edge Functions)

Untuk mencegah kecurangan (misalnya menggunakan aplikasi patcher/cheat untuk memalsukan status pembayaran), backend Supabase harus melakukan validasi ke server API Google secara langsung menggunakan **Google Play Developer API**.

### 5.1 Membuat Google Cloud Service Account
1. Masuk ke [Google Cloud Console](https://console.cloud.google.com/).
2. Buat project baru atau pilih project yang terhubung dengan Google Play Console Anda.
3. Buka **IAM & Admin** > **Service Accounts**.
4. Klik **Create Service Account**:
   * Nama: `worthit-billing-validator`
   * Role: Berikan akses **Viewer** ke project.
5. Setelah dibuat, klik nama service account tersebut > buka tab **Keys** > **Add Key** > **Create new key** > pilih format **JSON**.
6. Simpan file JSON yang terunduh. File ini berisi kredensial aman (kunci privat).
7. Hubungkan ke Play Console:
   * Masuk ke Google Play Console > **Setup** > **API access**.
   * Hubungkan project Google Cloud tadi ke Play Console.
   * Pastikan Service Account yang Anda buat muncul di daftar dengan izin **View financial data and manage orders and subscriptions**.

### 5.2 Menambahkan Kredensial ke Supabase Vault / Env
Salin isi file JSON Service Account tadi dan simpan sebagai environment variable di Supabase:
```bash
# Set secret di Supabase CLI atau dashboard Supabase
supabase secrets set GOOGLE_SERVICE_ACCOUNT_JSON='{... isi JSON key ...}'
```

### 5.3 Membuat Supabase Edge Function untuk Validasi Token
Buat function baru bernama `verify-purchase` di Supabase backend:

```typescript
// supabase/functions/verify-purchase/index.ts
import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { google } from "npm:googleapis@126"

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const { purchaseToken, subscriptionId, packageName } = await req.json()

    // 1. Ambil kredensial Service Account dari Env
    const serviceAccount = JSON.parse(Deno.env.get('GOOGLE_SERVICE_ACCOUNT_JSON') || '{}')

    // 2. Lakukan otentikasi menggunakan googleapis
    const auth = new google.auth.JWT(
      serviceAccount.client_email,
      null,
      serviceAccount.private_key,
      ['https://www.googleapis.com/auth/androidpublisher']
    )

    const playDeveloperApi = google.androidpublisher({
      version: 'v3',
      auth: auth
    })

    // 3. Verifikasi status langganan ke API Google Play
    const result = await playDeveloperApi.purchases.subscriptions.get({
      packageName: packageName, // misal: com.example.worthit_app
      subscriptionId: subscriptionId, // misal: worthit_pro_monthly
      token: purchaseToken
    })

    const subscriptionState = result.data

    // 4. Periksa apakah langganan aktif
    // expiryTimeMillis menunjukkan kapan langganan berakhir
    const expiryTime = parseInt(subscriptionState.expiryTimeMillis || '0')
    const now = Date.now()

    if (expiryTime > now) {
      // Langganan VALID! Update status user di database Supabase Anda menjadi PRO
      // Contoh: update tabel profiles set is_pro = true where user_id = ...
      
      return new Response(
        JSON.stringify({ success: true, message: "Subscription is active", expiryTime }),
        { headers: { ...corsHeaders, "Content-Type": "application/json" }, status: 200 }
      )
    } else {
      return new Response(
        JSON.stringify({ success: false, message: "Subscription has expired" }),
        { headers: { ...corsHeaders, "Content-Type": "application/json" }, status: 400 }
      )
    }

  } catch (error) {
    return new Response(
      JSON.stringify({ error: error.message }),
      { headers: { ...corsHeaders, "Content-Type": "application/json" }, status: 500 }
    )
  }
})
```

### 5.4 Penanganan Perubahan Status Langganan via Webhook (Google RTDN)
Agar status user di database langsung berubah menjadi non-PRO saat mereka membatalkan langganan di Play Store (atau sukses auto-renew), setup **Real-Time Developer Notifications (RTDN)**:
1. Buka Google Cloud Console > **Pub/Sub** > **Topics**.
2. Buat Topic baru (misal: `rtdn-worthit-subscriptions`).
3. Berikan izin kepada Google Play service account (`google-play-developer-notifications@system.gserviceaccount.com`) untuk mempublikasikan pesan ke topic tersebut sebagai **Pub/Sub Publisher**.
4. Buat **Pub/Sub Subscription** dengan tipe **Push** yang mengarah ke URL endpoint Supabase Edge Function Anda lainnya (misal: `https://your-project.supabase.co/functions/v1/rtdn-webhook`).
5. Daftarkan nama Topic lengkap Anda (`projects/project-id/topics/rtdn-worthit-subscriptions`) ke dashboard Google Play Console > **Setup** > **API access** > **Real-time developer notifications**.
6. Edge Function `rtdn-webhook` Anda akan menerima payload berformat JSON setiap kali status langganan berubah. Anda tinggal menguraikan payload tersebut untuk memproses perpanjangan (*renew*) atau pembatalan (*cancellation*).
