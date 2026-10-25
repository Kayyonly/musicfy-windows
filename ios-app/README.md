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
- Engine playback native: `AVPlayer` melalui `State/PlayerController.swift` (play/pause/stop/seek, durasi aktual, buffering, error, `AVAudioSession`).
- Belum ada provider audio legal yang tersambung, jadi hasil YouTube Music hanya menampilkan metadata dan status "audio source unavailable".
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

Pencarian hanya memfilter katalog lokal. Pemilihan lagu, favorite, antrean, progres, dan tombol play/pause menggunakan state demonstrasi untuk katalog lokal, dan engine playback native `AVPlayer` untuk sumber audio yang benar-benar disediakan.

**Belum ada sumber audio yang terhubung.** `PlayerController` (AVFoundation) sudah memutar `PlaybackSource` nyata dengan play/pause/seek, durasi aktual, status buffering/error, konfigurasi `AVAudioSession`, dan penanganan interupsi. Namun tidak ada provider audio legal yang tersambung, jadi hasil pencarian YouTube Music tetap menampilkan status "audio source unavailable" dan tidak memutar apa pun. Tidak ada URL audio yang direkayasa dari video id, tidak ada WebView YouTube, dan tidak ada backend.


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
