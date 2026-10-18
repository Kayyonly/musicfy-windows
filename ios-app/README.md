# Musicfy iPhone — prototipe UI SwiftUI

Prototipe offline yang mempertahankan karakter Musicfy Android: latar hitam, artwork membulat, carousel padat, mini-player mengambang, dan navigasi kapsul. Semua track, progres, favorite, antrean, serta interaksi play/pause adalah **state demonstrasi tanpa suara**, bukan layanan musik yang terhubung.

## Status

Source SwiftUI siap **diimpor untuk build/review di Xcode**, bukan aplikasi iOS yang sudah terbukti berjalan. Tidak ada `.xcodeproj` buatan tangan, signing, CI, backend, login, jaringan, maupun playback. Sandbox Linux ini tidak memiliki `swift`, `swiftc`, `xcodebuild`, SDK Apple, atau simulator. Kompilasi, navigasi runtime, fidelity visual, VoiceOver, dan Dynamic Type belum diuji pada iPhone.

Minimum **iOS 17.0**, Swift 5 language mode, Xcode 15 atau lebih baru. iOS 17 dipilih untuk baseline SwiftUI modern dan API `onChange` yang konsisten. State menggunakan `ObservableObject` + `@StateObject` tanpa dependency pihak ketiga. SF/system font adalah adaptasi Inter Android; font Android dan artwork komersial tidak disalin.

## Buka di Xcode pada Mac

1. Buat project baru: **iOS → App**. Product Name **MusicfyIOS**, Interface **SwiftUI**, Language **Swift**, tanpa storage/persistence tambahan. Simpan project di direktori kosong terpisah agar source ini tidak tertimpa. Gunakan Swift 5 language mode; deployment target iOS 17.0. Simulator tidak perlu signing/publikasi.
2. Hapus kedua file template `MusicfyIOSApp.swift` dan `ContentView.swift` dari target baru; source di sini sudah mempunyai satu `@main`.
3. Tambahkan folder `App`, `Theme`, `Models`, `State`, `Components`, dan `Screens` menggunakan **Add Files to MusicfyIOS**, pilih **Create groups** dan target membership aplikasi. Jangan tambahkan `Tests`, `Scripts`, atau `Docs` ke target aplikasi.
4. Tidak perlu menambahkan asset eksternal: artwork placeholder digambar SwiftUI. Jangan mengaktifkan network capability, background audio, MusicKit, atau login. Tidak perlu key/token.
5. Pilih simulator iPhone, lalu **Product → Build** dan **Run**. Bila ada error compiler, catat apa adanya; source ini belum dikompilasi di Linux.
6. Untuk unit test, tambahkan **iOS Unit Testing Bundle**, gunakan host app MusicfyIOS, dan tambahkan `Tests/MusicfyDemoStateTests.swift` hanya ke target test. Import `@testable import MusicfyIOS` mengasumsikan nama module aplikasi itu. Jalankan **Product → Test**. Test source disediakan, belum pernah dijalankan di lingkungan ini.

## Halaman dan interaksi lokal

Home, Search, Library, Profile, Now Playing, Queue, dan Lyrics tersedia sebagai source. App root memiliki custom capsule navigation, bukan tab bar Apple Music. Pemilihan track mengubah metadata mini-player; mini-player membuka player. Play/pause hanya mengubah ikon dan state, tidak menjalankan audio. Previous/next berpindah di katalog mock. Favorite tersimpan di memori per track. Slider mengubah progres demonstrasi tanpa timer. Queue memilih track lokal; Lyrics berisi empat baris teks orisinal, bukan lirik rekaman yang ditampilkan.

Search memfilter data lokal berdasarkan metadata dan menampilkan empty/no-result state. Tidak ada pencarian provider. Library dimulai kosong; banner provider dan tombol tambah musik adalah penjelasan demo, **bukan** koneksi atau impor berkas sungguhan. Profil memakai identitas nonpersonal. Seluruh state di-reset saat aplikasi dihentikan; tidak ada persistence.

## Struktur

- `App/`: entry point dan komposisi tab/mini-player/sheet.
- `Theme/`: warna, typography, spacing.
- `Models/`: track/album/playlist/lyrics mock dan katalog demonstrasi.
- `State/`: sumber state bersama tanpa service player.
- `Components/`: artwork, row, card, header, field, glass, mini-player, navigation.
- `Screens/`: tujuh halaman target.
- `Tests/`: XCTest untuk state; dijalankan di Xcode, bukan Linux.
- `Scripts/verify_static.py`: pemeriksaan struktural dan checksum preservasi repo, bukan compiler Swift.
- `Docs/UI-AUDIT.md`: bukti source, pemetaan visual, perbedaan dengan screenshot.
- `Docs/FINAL-REPORT.md`: hasil, daftar file, batas verifikasi.

## Pemeriksaan yang tersedia di Linux

Dari root repository, jalankan `python3 ios-app/Scripts/verify_static.py`. Hasilnya `Docs/STATIC-CHECKS.json`. Pemeriksaan membandingkan checksum seluruh berkas awal di luar `ios-app/` termasuk perubahan lokal Windows yang sudah ada. Jika source lama memang diubah setelah baseline, hasil akan gagal dan harus ditinjau, bukan baseline diganti diam-diam.

## Checklist review pada iPhone/simulator

- Uji empat tab, query pencarian/clear/no result/history, pemilihan track, favorite per track, next/previous dan wrap-around, player close/back, Queue dan Lyrics.
- Uji iPhone kecil dan besar, portrait/landscape, keyboard terbuka, scroll terakhir tidak tertutup kontrol bawah, serta safe area/notch/home indicator.
- Uji semua ukuran Dynamic Type termasuk accessibility, VoiceOver order/focus/label, Reduce Transparency, dan kontras kartu mood.
- Bandingkan dua state Home, Search browse/hasil, Library, dan Profile dengan enam screenshot pemilik. Artwork generik dan SF font adalah perbedaan yang disengaja. Tidak tersedia screenshot referensi expanded player/Queue/Lyrics; ketiganya hanya adaptasi source.
- Jangan menandai UI accepted sebelum review visual yang benar-benar dijalankan. Jangan menyebut kontrol demo menghasilkan audio.

## Lisensi dan atribusi

Referensi berasal dari Musicfy pada repository induk, commit `13decf68298ed88ab895551ff3c43b97d398af40`. Repository induk menyediakan GNU GPL v3 di `../LICENSE`; notice asli tetap utuh dan berlaku sesuai lisensi repository. Berkas ini tidak menggantikan atau menghapus notice pihak ketiga. Tidak ada artwork komersial, foto profil pemilik, font Android, credential, atau token yang dibundel. SF Symbols dirender oleh framework sistem Apple; distribusi aplikasi tetap harus memenuhi syarat Apple yang berlaku.

## Titik berhenti

Tahap ini berhenti pada source prototipe UI dan laporan. InnerTube, MusicKit, AVPlayer, autentikasi, backend, serta playback tidak diimplementasikan. Integrasi berikutnya memerlukan persetujuan terpisah setelah UI diterima.
