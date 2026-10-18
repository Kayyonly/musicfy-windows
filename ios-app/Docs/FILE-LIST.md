# Daftar file baru Musicfy iOS

Semua **37 berkas baru** berada di `ios-app/`. Terdapat 28 source Swift produksi, 1 source XCTest, serta 8 berkas dokumentasi/bukti/skrip. Tidak ada file lama diubah.

| Path relatif terhadap ios-app/ | Fungsi |
|---|---|
| `App/AppRootView.swift` | Komposisi empat tab, safe-area bottom controls, dan sheet player. |
| `App/MusicfyIOSApp.swift` | Entry point @main dan lifecycle state demonstrasi. |
| `Components/AlbumArtworkView.swift` | Artwork geometris lokal, tanpa aset komersial. |
| `Components/AlbumCard.swift` | Kartu carousel artwork dan metadata. |
| `Components/MiniPlayerView.swift` | Mini-player mengambang dan kontrol demo. |
| `Components/MoodCard.swift` | Tile mood tonal dengan aksi penjelasan demo. |
| `Components/MusicfyBottomNavigation.swift` | Navigasi kapsul empat tab dan active state. |
| `Components/MusicfyGlass.swift` | Material kaca dengan fallback Reduce Transparency. |
| `Components/MusicfySearchField.swift` | TextField kapsul, clear, dan binding focus. |
| `Components/PageHeader.swift` | Judul halaman dan shortcut profil generik. |
| `Components/SectionHeader.swift` | Judul/subjudul section reusable. |
| `Components/TrackRow.swift` | Baris track, rank opsional, dan selected state. |
| `Docs/FILE-LIST.md` | Daftar lengkap setiap berkas baru dan fungsi. |
| `Docs/FINAL-REPORT.md` | Laporan hasil dan batas verifikasi, status fase, langkah berikutnya. |
| `Docs/STATIC-CHECKS.json` | Hasil aktual pemeriksaan struktural/preservasi; bukan build iOS. |
| `Docs/UI-AUDIT.md` | Audit source Android, tokens, screenshot, asumsi dan pemetaan. |
| `Docs/baseline-files.json` | SHA-256 semua 2.605 berkas awal di luar proyek iOS. |
| `Docs/baseline-git-status.txt` | Snapshot status Git ketika folder baru mulai dibuat. |
| `Models/DemoCatalog.swift` | Tujuh metadata track contoh, album dan playlist lokal. |
| `Models/MockAlbum.swift` | Model album demonstrasi. |
| `Models/MockLyrics.swift` | Model dan empat baris lirik orisinal demonstrasi. |
| `Models/MockPlaylist.swift` | Model playlist demonstrasi. |
| `Models/MockTrack.swift` | Model track dan formatter durasi. |
| `README.md` | Instruksi impor source di Xcode, pengujian dan lisensi. |
| `Screens/HomeView.swift` | Hero random plays dan section/carousel lokal. |
| `Screens/LibraryView.swift` | Pencarian library kosong, provider/local cards informasional. |
| `Screens/LyricsView.swift` | Lirik orisinal dengan highlight manual dan backdrop. |
| `Screens/NowPlayingView.swift` | Player senyap, metadata, favorite, progress dan transport. |
| `Screens/ProfileView.swift` | Kartu identitas nonpersonal, statistik demo, versi/About. |
| `Screens/QueueView.swift` | Antrean lokal dan pemilihan track. |
| `Screens/SearchView.swift` | Browse mood, query/filter metadata, history dan hasil lokal. |
| `Scripts/verify_static.py` | Pemeriksaan offline struktural dan checksum baseline. |
| `State/MusicfyDemoState.swift` | State tab, track, favorite, progres, history, kontrol demo. |
| `Tests/MusicfyDemoStateTests.swift` | Tujuh metode XCTest, disediakan tetapi belum dijalankan. |
| `Theme/MusicfySpacing.swift` | Token spacing, radius, control heights dan minimum touch. |
| `Theme/MusicfyTheme.swift` | Token warna dan palet placeholder. |
| `Theme/MusicfyTypography.swift` | Typography SF/system sebagai adaptasi Inter Android. |
