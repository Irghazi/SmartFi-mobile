# SmartFi Mobile (Android)
> **Catat Keuangan + Mentor AI Pribadi**  
> *"Cukup tulis seperti ngobrol, AI yang urus sisanya."*

Aplikasi Android native berbasis **Flutter** yang mengimplementasikan antarmuka khas **Neobrutalism** (kontras tinggi, border tegas 2–4px, hard solid shadow, blueprint grid background, dan respon mekanik tombol).

---

## 🚀 Cara Menjalankan Aplikasi

Aplikasi ini menggunakan konfigurasi lingkungan aman via `env.json` (OpenAI-compatible BangunWeb) untuk fitur kecerdasan AI.

### 1. Prasyarat
- Flutter SDK (3.24+ / Dart 3.13+)
- Android SDK & Perangkat Android / Emulator yang terhubung

### 2. Konfigurasi Lingkungan (`env.json`)
Pastikan file `env.json` telah berada di direktori root `smartfi-mobile` (berisi variabel lingkungan aman tanpa hardcode di repositori):
```json
{
  "AI_BASE_URL": "https://router.bangunweb.com/v1",
  "AI_MODEL": "deepseek-v4.1-flash",
  "AI_API_KEY": "YOUR_API_KEY"
}
```
> Template cadangan tersedia di berkas `env.example.json`.

### 3. Perintah Menjalankan Aplikasi
Jalankan perintah berikut di terminal:
```bash
flutter run --dart-define-from-file=env.json
```
Aplikasi berjalan dengan backend **Firebase (Auth + Cloud Firestore dengan Offline Persistence)** secara otomatis apabila `android/app/google-services.json` dan `lib/firebase_options.dart` tersedia, serta otomatis fallback ke **Mode Offline (Dummy Repository)** apabila Firebase belum terkonfigurasi. Untuk Mentor AI & Smart Input AI, aplikasi menggunakan **Real API** ketika `AI_API_KEY` diisi (dengan fallback parser lokal jika offline).

---

## 🧠 Fitur & Arsitektur Utama

1. **Dashboard & Visualisasi Finansial**:
   - 3 Kartu Ringkasan (Saldo Terkini, Pemasukan, Pengeluaran).
   - Widget 2x2 Circular Progress (Saldo vs Target Tabungan, Pemasukan, Pengeluaran, Kategori Terbesar).
   - Grafik Batang Tren 7 Hari Terakhir & Diagram Lingkaran Distribusi Kategori (`fl_chart`).
   - Riwayat 5 Transaksi Terkini berstatus Selesai.
   - Modal Saldo Awal (Onboarding) minimal Rp 100.000 jika data baru.
2. **Transaksi & Smart Input AI**:
   - Natural Language Parser (NLP regex Indonesia: "Makan siang 25 ribu", "Gaji 5 juta", "Kopi 20k").
   - Pratinjau interaktif hasil ekstraksi sebelum disimpan.
   - Tambah manual, ubah, dan hapus dengan modal konfirmasi.
   - Filter rentang tanggal dan pencarian instan.
3. **Mentor AI (Penasihat Finansial Pribadi)**:
   - Integrasi API OpenAI-compatible via BangunWeb (`deepseek-v4.1-flash`).
   - System prompt keuangan ketat (tanpa emoji, kasual aku/kamu, titik Rupiah, bold angka/nama).
   - Konteks keuangan dinamis real-time (saldo, total arus kas, pos pengeluaran terbesar, 15 transaksi terakhir).
   - Tombol pintas pertanyaan: *Analisis Otomatis*, *Pengeluaran Terbesar*, *Saran Hemat*.
   - Dukungan Markdown render, tombol *Muat Ulang Respon (Regenerate)*, tombol Refresh, pembersih riwayat obrolan, dan efek audio obrolan.
4. **Kategori Finansial**:
   - Kategori bawaan: Makanan, Transportasi, Hiburan, Gaji.
   - Tambah/edit kategori kustom dengan pilihan 20 ikon Neobrutalism dan 15 warna palet.
5. **Laporan & Ekspor Dokumen**:
   - Filter tanggal mulai, akhir, dan jenis transaksi.
   - Pratinjau tabel rincian transaksi lengkap dengan baris TOTAL & SALDO BERSIH.
   - **Ekspor Dokumen PDF**: Menggunakan generator PDF Neobrutalism resmi via paket `pdf` dan `printing`.
   - **Ekspor Spreadsheet CSV / Excel**: Disimpan ke cache perangkat dan dapat dibagikan langsung ke aplikasi lain via `share_plus`.
6. **Pengaturan & Preferensi**:
   - Ubah profil nama pengguna.
   - Target tabungan bulanan (langsung sinkron ke Widget 2x2 Dashboard).
   - Pilihan tema tampilan Terang vs Gelap.
   - Pengingat harian pencatatan jam harian.
   - Kontrol suara (Mute klik & Mute AI).
   - Koreksi saldo riil otomatis (*Penyesuaian Saldo*).
   - Zona Bahaya: Hapus riwayat transaksi per rentang waktu (Bulan Ini, Tahun Ini, Semua Waktu).
7. **Widget Beranda Android 4×2 (Neobrutalism)**:
   - Menampilkan Saldo Terkini, Progress Bar Target Tabungan, Pemasukan & Pengeluaran Bulan Ini secara otomatis tersinkron.
   - Tombol 1-ketukan untuk **Sensor Saldo (Privasi)**, **`+ CATAT`** (langsung ke tab Transaksi Smart Input AI), dan **`AI`** (langsung ke Mentor AI), adaptif tema Terang/Gelap.
8. **Auto-Update Dalam Aplikasi (Cloud Firestore)**:
   - Deteksi versi baru *real-time* dari dokumen `app_config/android`, unduh APK langsung dengan progress bar, dan pemicu installer Android.

---

## 🔒 Konfigurasi Firebase (Aktif)

Aplikasi sudah terintegrasi penuh dengan **Firebase Authentication** (Email/Password & Google Sign-In) serta **Cloud Firestore** (dengan *offline persistence*) di `lib/data/repositories/firebase/`, dengan aturan keamanan di `firebase/firestore.rules`. Jika Anda ingin memindahkan ke proyek Firebase baru, ikuti langkah berikut:

### Langkah 1: Buat Proyek di Firebase Console
1. Buka [Firebase Console](https://console.firebase.google.com/) dan buat proyek baru (Paket **Spark** / Gratis).
2. Daftarkan aplikasi Android dengan:
   - **Application ID / Package name**: `smartfi.app.mobile` (namespace Kotlin: `com.smartfi.mobile`)
   - **SHA-1 Fingerprint**: Dapatkan melalui perintah terminal `cd android && ./gradlew signingReport` (wajib untuk Google Sign-In).

### Langkah 2: Aktifkan Layanan Firebase
1. **Authentication**: Aktifkan penyedia *Email/Password* dan *Google*.
2. **Cloud Firestore**:
   - Buat database di lokasi terdekat (misal `asia-southeast2` Jakarta).
   - Deploy aturan keamanan dan index yang tersedia pada folder `firebase/`:
     ```bash
     firebase deploy --only firestore:rules,firestore:indexes
     ```

### Langkah 3: Konfigurasi FlutterFire
1. Pasang FlutterFire CLI di sistem Anda jika belum ada:
   ```bash
   dart pub global activate flutterfire_cli
   ```
2. Jalankan perintah konfigurasi otomatis di folder proyek:
   ```bash
   flutterfire configure
   ```
   Perintah ini akan menghasilkan `android/app/google-services.json` dan `lib/firebase_options.dart` (keduanya diabaikan dari Git lewat `.gitignore`).

---

## 🔄 Panduan Rilis & Auto-Update Aplikasi via Firebase

SmartFi Mobile dilengkapi fitur **In-App Auto-Update** yang terhubung secara *real-time* ke Cloud Firestore (dokumen `app_config/android`). Saat Anda merilis versi baru, aplikasi akan otomatis mendeteksi pembaruan, menampilkan catatan rilis, mengunduh APK langsung di dalam aplikasi dengan progress bar, dan membuka installer Android.

### Langkah Merilis Versi Baru
1. Naikkan versi pada `pubspec.yaml`, contoh dari `version: 1.0.0+1` menjadi `version: 1.1.0+2` (`1.1.0` = `latestVersion`, `2` = `latestBuildNumber`).
2. Build APK release bertanda tangan yang sama (`android/key.properties`):
   ```bash
   flutter build apk --release --dart-define-from-file=env.json
   ```
3. Unggah file `build/app/outputs/flutter-apk/app-release.apk` ke hosting direct-link (misal **GitHub Releases**, **Firebase Storage**, atau server pribadi Anda) dan salin direct URL `.apk`.
4. Pastikan aturan keamanan terbaru (`app_config/{docId}`) sudah di-deploy ke Firestore:
   ```bash
   firebase deploy --only firestore:rules
   ```
5. Di **Firebase Console → Cloud Firestore**, buat/perbarui dokumen `app_config/android` dengan field:
   ```json
   {
     "latestVersion": "1.1.0",
     "latestBuildNumber": 2,
     "minSupportedBuildNumber": 1,
     "forceUpdate": false,
     "releaseNotes": "- Perbaikan performa & tampilan\n- Fitur baru SmartFi",
     "downloadUrl": "https://github.com/ORG/REPO/releases/download/v1.1.0/app-release.apk"
   }
   ```
   - Set `forceUpdate: true` atau naikkan `minSupportedBuildNumber` untuk mewajibkan pengguna lama memperbarui sebelum melanjutkan.
   - Pengguna juga dapat memeriksa pembaruan secara manual lewat menu **Pengaturan → Pembaruan Aplikasi**.

---

## 📁 Struktur Direktori

```text
smartfi-mobile/
├── assets/
│   ├── images/logo.png
│   └── sounds/click.mp3, chat.mp3
├── docs/
│   └── PARITY_MATRIX.md
├── firebase/
│   ├── firestore.rules
│   └── firestore.indexes.json
├── lib/
│   ├── core/
│   │   ├── config/ (ai_config.dart, ai_prompts.dart)
│   │   ├── router/ (app_router.dart)
│   │   ├── services/ (audio_service.dart, notification_service.dart)
│   │   ├── theme/ (neo_colors.dart, neo_theme.dart)
│   │   └── utils/ (currency_formatter.dart, date_formatter.dart, validators.dart)
│   ├── data/
│   │   ├── models/ (user_model.dart, category_model.dart, transaction_model.dart)
│   │   ├── repositories/
│   │   │   ├── dummy/ (dummy_auth, dummy_transaction, dummy_category, dummy_ai)
│   │   │   ├── firebase/ (firebase_auth, firebase_transaction, firebase_category)
│   │   │   └── openai/ (openai_ai_repository.dart)
│   │   └── services/ (pdf_export_service.dart, csv_export_service.dart)
│   ├── features/
│   │   ├── main/
│   │   ├── auth/
│   │   ├── dashboard/
│   │   ├── transactions/
│   │   ├── categories/
│   │   ├── ai_advisor/
│   │   ├── reports/
│   │   └── settings/
│   ├── shared/
│   │   └── widgets/ (neo_app_bar, neo_button, neo_card, neo_input, neo_modal, neo_badge, blueprint_background)
│   ├── app.dart
│   ├── firebase_options.dart
│   └── main.dart
├── env.example.json
└── pubspec.yaml
```
