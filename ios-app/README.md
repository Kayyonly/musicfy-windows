# Musicfy iPhone — SwiftUI UI Prototype

Prototipe UI iPhone yang terinspirasi dari Musicfy Android. Aplikasi menggunakan SwiftUI, latar gelap, artwork geometris, carousel, mini-player, dan navigasi kapsul.

Ini masih prototipe berbasis data lokal, bukan layanan streaming musik yang sudah terhubung.

## Status

- Platform: iPhone, minimum iOS 17.0.
- Swift language mode: 5.0.
- Xcode project: `MusicfyIOS.xcodeproj`.
- Shared scheme: `MusicfyIOS`.
- App target: `MusicfyIOS`.
- Test target: `MusicfyIOSTests`.
- Tidak menggunakan dependency pihak ketiga.
- Source Swift dan tes tersedia, tetapi build Xcode dan XCTest belum terverifikasi di macOS.

## Halaman

Tujuh halaman tersedia sebagai source:

- Home
- Search
- Library
- Profile
- Now Playing
- Queue
- Lyrics

Pencarian hanya memfilter katalog lokal. Pemilihan lagu, favorite, antrean, progres, dan tombol play/pause menggunakan state demonstrasi.

**Tidak ada audio yang diputar.** Belum ada integrasi MusicKit, AVPlayer, InnerTube, backend, autentikasi, atau pencarian provider musik. Data demonstrasi juga tidak disimpan secara permanen.

Artwork adalah placeholder yang digambar dengan SwiftUI. Font sistem Apple digunakan sebagai adaptasi tampilan iOS.

## Struktur proyek

- `App/`: entry point dan komposisi aplikasi.
- `Components/`: komponen UI yang digunakan bersama.
- `Models/`: model dan katalog demonstrasi.
- `State/`: state untuk interaksi lokal.
- `Screens/`: tujuh halaman aplikasi.
- `Theme/`: warna, typography, dan spacing.
- `Tests/`: source XCTest.
- `CI/`: audit struktur proyek, pemilihan simulator, dan tes helper Python.
- `Docs/`: catatan audit dan laporan persiapan.

## Pemeriksaan lokal

Jalankan dari root repository:

```bash
python3 ios-app/CI/check_project.py
python3 -m unittest discover -s ios-app/CI -p 'test_*.py' -v
