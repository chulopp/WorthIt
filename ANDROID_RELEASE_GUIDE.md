# Panduan Pembuatan Android Keystore & Rilis Produksi (WorthIt App)

Dokumen ini menjelaskan langkah-langkah praktis untuk membuat kunci penandatanganan aplikasi (*Signing Key*) Android agar aplikasi siap diunggah ke Google Play Store.

---

## Langkah 1: Buat File Keystore (.jks)

Buka terminal Anda (baik Command Prompt, PowerShell, atau WSL) dan jalankan perintah `keytool` bawaan Java SDK/Flutter.

### Di Windows (Command Prompt / PowerShell):
```bash
keytool -genkey -v -keystore D:\worthit-release-key.jks -storetype PKCS12 -keyalg RSA -keysize 2048 -validity 10000 -alias worthit-key
```
*(Catatan: Anda bisa mengubah `D:\worthit-release-key.jks` ke direktori aman mana saja di komputer Anda).*

### Di macOS / Linux:
```bash
keytool -genkey -v -keystore ~/worthit-release-key.jks -storetype PKCS12 -keyalg RSA -keysize 2048 -validity 10000 -alias worthit-key
```

### Yang akan ditanyakan saat pembuatan:
1. **Password**: Buat password yang kuat dan **catat password ini** (jangan sampai lupa!).
2. **Data diri**: Isi nama, unit organisasi, kota, provinsi, dan kode negara (misal: ID untuk Indonesia).
3. **Konfirmasi**: Ketik `y` atau `yes` jika data sudah benar.

Setelah selesai, file kunci bernama `worthit-release-key.jks` akan terbentuk di lokasi yang Anda tentukan. **Simpan file ini baik-baik dan backup di tempat aman (misal Google Drive pribadi)**.

---

## Langkah 2: Buat File Kredensial (`key.properties`)

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
*(Catatan untuk pengguna Windows: Gunakan double backslash `\\` untuk pemisah folder pada property `storeFile`, misalnya `C:\\Users\\username\\worthit-release-key.jks`)*

---

## Langkah 3: Lakukan Build Rilis Produksi

Setelah file `key.properties` berada di folder `frontend/android/key.properties`, jalankan perintah berikut di folder `frontend/`:

```bash
# 1. Bersihkan sisa build
flutter clean
flutter pub get

# 2. Build rilis produksi (.aab untuk Play Store)
flutter build appbundle --obfuscate --split-debug-info=./build/app/outputs/symbols --release
```

Hasil build berupa berkas `.aab` akan terbentuk di folder:
`frontend/build/app/outputs/bundle/release/app-release.aab`

Berkas itulah yang akan Anda unggah ke Google Play Console!
