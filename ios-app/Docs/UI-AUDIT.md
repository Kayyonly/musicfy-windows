# Audit UI Musicfy — Android sebagai Referensi, iOS sebagai Implementasi

## Ruang lingkup dan cara membaca bukti

Audit ini membandingkan sumber Android pada `app/src/main/kotlin/com/example/musicfy` dengan implementasi SwiftUI iOS yang saat ini **source-import-ready**. Implementasi iOS menargetkan iOS 17, memakai system `SF` sebagai adaptasi Inter, tidak menyalin font/artwork, dan tidak memakai pihak ketiga.

Status dalam tabel:

- **Sumber Android** — fakta yang terlihat langsung pada Kotlin beserta file/baris rujukannya.
- **Screenshot** — hanya terlihat pada enam screenshot yang tersedia; bukan kontrak perilaku atau ukuran runtime.
- **Estimasi/adaptasi iOS** — keputusan visual iOS yang diperlukan untuk mendekati referensi, bukan fakta Android.
- **Runtime belum diverifikasi** — belum ada jaminan bahwa perilaku/visual cocok ketika aplikasi dijalankan; khususnya HEAD sumber belum dibuktikan sama dengan aplikasi yang menghasilkan screenshot.

Tidak ada screenshot untuk expanded player, Queue, atau Lyrics. Karena itu, kecocokan visual ketiga layar tersebut **tidak dapat diterima sebagai terverifikasi**.

## Ringkasan keputusan lintas aplikasi

| Elemen | Referensi Android | Implementasi iOS | Bukti/status |
|---|---|---|---|
| Tema gelap | Latar hitam; `primary #E0E0E0`, `secondary #B0B0B0`, `primaryContainer #333333`, `secondaryContainer #2C2C2C`, `surfaceVariant #1A1A1A` (`Theme.kt:27–67`) | Palet gelap SwiftUI yang memetakan peran warna, bukan angka baru yang dianggap kontrak | **Sumber Android**; warna iOS = **adaptasi**, runtime belum diverifikasi |
| Tipografi | Inter tersedia dari thin sampai bold; seluruh `AppTypography` memakai semibold dan tracking `-0.05em` (`Type.kt:14–25`, gaya `27–132`) | System `SF` iOS sebagai pengganti Inter; bobot/kerning didekatkan per gaya | **Sumber Android** + **estimasi/adaptasi iOS**; tidak ada font Inter/artwork yang disalin |
| Navigasi bawah | Capsule tinggi 64, radius 32, inset horizontal 24, padding vertikal 8; border putih 0,1; indikator aktif 0,2 (`AppNavigation.kt:325–449`) | Tab bar/capsule SwiftUI dengan geometri setara dan state aktif | **Sumber Android**; screenshot mendukung bentuk umum; runtime belum diverifikasi |
| Chrome kaca | Tint `#0F0F12`, blur 48, opacity/tint 0,65 (`GlassKit.kt:177–213`) | Material/translucency SwiftUI yang mendekati, dengan fallback solid gelap | **Sumber Android**; hasil iOS **estimasi/adaptasi** |
| Dimensi global | Mini player 64, bottom inset 4, nav 80, slim 64 (`Dimensions.kt:17–36`) | Konstanta layout iOS yang mempertahankan hierarki tinggi tersebut | **Sumber Android**; runtime belum diverifikasi |
| Cover | `MorphingCover.kt:680–701` menunjukkan mini cover; radius mini tidak terbukti eksplisit dari sumber yang diaudit | Container mini-player SwiftUI radius 28; artwork generik radius 16 untuk adaptasi screenshot | Radius iOS **estimasi screenshot**, bukan fakta Android |
| Gambar | Sumber Android mengambil artwork runtime/dynamic; screenshot hanya menunjukkan hasil | Placeholder/katalog demo iOS untuk kesiapan import sumber; tidak mengklaim paritas data backend | **Runtime belum diverifikasi** |

## Pemetaan tujuh layar

| Layar | Elemen | Referensi Android | Implementasi iOS | Bukti/status |
|---|---|---|---|---|
| 1. Home | Kartu dan section | Inset 36, gap 15, cover besar 137 atau compact 104; judul section 16/19 bold; page 24/28; kartu 14/17; subtitle 12/15; rank 22; row 54; radius 14 (`HomeCards.kt:53–113`). Home memiliki section kondisional (`HomeScreen.kt:1054–1100`); “More Like” dinamis (`1391–1449`). Tidak ada literal “Jump Back” yang terbukti. | Home SwiftUI memetakan kartu, section, dan row; label “Jump Back” diperlakukan sebagai adaptasi screenshot, bukan data Android wajib | Angka = **sumber Android**; label/isi = **screenshot atau runtime dinamis**; runtime iOS belum diverifikasi |
| 2. Search (browse) | Search field dan mood tiles | Field `#141416`, focused `#1E1E21`, tile `#121214`, divider `#232326`, secondary `#9A9AA0`, placeholder `#77777D`; field tinggi 48, avatar 36, title 62 (`SearchDesign.kt:83–108`). Search mood berupa backend dinamis dua kolom, inset 24, gap 10 (`SearchScreen.kt:295–371`). | Browse SwiftUI memakai field 48 dan grid dua kolom; mood adalah katalog/demo atau data runtime sesuai sumber yang tersedia | Warna/ukuran = **sumber Android**; keberadaan mood/isi = **runtime dinamis**, belum diverifikasi |
| 3. Search (hasil/local) | Filter dan hasil lokal | `LocalSearchScreen.kt:129–294` memiliki All Songs, Albums, Artists, Playlists. Screenshot memperlihatkan chip All Music, Artist, Video, Album; keduanya tidak boleh dianggap identik. | iOS mempertahankan istilah/struktur yang tampak pada target screenshot sambil memisahkan mode hasil dari browse | Perbedaan chip = **fakta sumber vs screenshot**; parity perilaku **runtime belum diverifikasi** |
| 4. Library | Import, kategori, section | Banner import dan satu keadaan kosong (`LibraryHomeScreen.kt:134–153`); kategori Songs, Albums, Artists, Playlists serta recently/liked/downloaded kondisional (`156–251`). Provider/library dinamis; sumber tidak membuktikan “import” sebagai provider tertentu. | iOS menyediakan search, banner informasional, kartu musik lokal, dan empty state. Kategori/library berisi belum didemonstrasikan karena library sengaja kosong | Struktur = **sumber Android**; isi/provider = **runtime dinamis**; screenshot hanya memvalidasi tampilan Library yang tersedia |
| 5. Profile | Header dan kartu statistik | Greeting/nama/id adalah runtime, sehingga jangan menyalin data personal dari screenshot. Kartu radius 22, title 23, stats 44, unit 18, label mono 14 (`ProfileScreen.kt:169–239`, kartu `795–912`). “About app” Android runtime; screenshot menampilkan “Star repo 8.0.0”, bukan bukti implementasi Android. | iOS memakai placeholder aman/nonpersonal dan kartu statistik yang sama secara visual; teks versi/aksi tidak dianggap fakta Android | Geometri = **sumber Android**; nama/ID/versi/label = **runtime atau screenshot**, belum diverifikasi |
| 6. Expanded player | Cover, metadata, progress, transport | Kontrol pemain memisahkan info dengan gap 16; slider dan transport 24 (`PlayerControls.kt:64–79`). `MainActivity.kt` mengelola koneksi pemain, metadata, progress, lyrics, dan state navigasi/bottom sheet. | iOS menyediakan layar pemain SwiftUI dengan kontrol dan state lokal/demo yang setara secara struktur | **Sumber Android**; tidak ada screenshot layar ini, jadi visual **tidak terverifikasi** |
| 7. Queue dan Lyrics | Daftar antrian serta lirik | Queue: row 60, artwork 44 dengan radius 8 (`QueueScreen.kt:74–81`). Lyrics: komentar 40sp dengan padding vertikal 16 (`LyricsScreen.kt:166–172`), top max 5,5%/72 dan bottom 55% (`123–130`). Helper akhir lirik belum terbukti. | iOS mengadaptasi queue row/artwork dan lirik asli; helper/fallback tidak dianggap selesai sebelum runtime diuji | Ukuran = **sumber Android**; tidak ada screenshot Queue/Lyrics; helper akhir **runtime belum diverifikasi** |

## Bukti screenshot yang tersedia

Enam screenshot yang diaudit mencakup: **dua Home**, **Search browse**, **Search result**, **Library**, dan **Profile**. Screenshot berguna untuk bentuk, hierarki, crop artwork, spacing yang tampak, dan label visual; screenshot tidak membuktikan backend, state kosong/berisi, navigasi, audio, personalisasi, atau ukuran dp/sp yang presisi. Expanded player, Queue, dan Lyrics tidak ada dalam set bukti.

## Inventory sumber yang benar-benar diperiksa

Daftar berikut adalah file Android yang dibaca/diinspeksi untuk audit ini; daftar ini sengaja tidak menyatakan seluruh repository telah dibaca:

```text
app/src/main/kotlin/com/example/musicfy/MainActivity.kt
app/src/main/kotlin/com/example/musicfy/App.kt
app/src/main/kotlin/com/example/musicfy/ui/theme/Font.kt
app/src/main/kotlin/com/example/musicfy/ui/component/HeroCarousel.kt
app/src/main/kotlin/com/example/musicfy/ui/component/PinnedBottomScaffold.kt
app/src/main/kotlin/com/example/musicfy/ui/component/SearchBar.kt
app/src/main/kotlin/com/example/musicfy/ui/component/BottomSheet.kt
app/src/main/kotlin/com/example/musicfy/ui/player/BottomSheetPlayer.kt
app/src/main/kotlin/com/example/musicfy/ui/player/PlayerUiState.kt
app/src/main/kotlin/com/example/musicfy/ui/screens/Screens.kt
app/src/main/kotlin/com/example/musicfy/ui/screens/search/OnlineSearchScreen.kt
app/src/main/kotlin/com/example/musicfy/ui/screens/library/LibraryDesign.kt
app/src/main/kotlin/com/example/musicfy/constants/Dimensions.kt
app/src/main/kotlin/com/example/musicfy/ui/theme/Theme.kt
app/src/main/kotlin/com/example/musicfy/ui/theme/Type.kt
app/src/main/kotlin/com/example/musicfy/ui/component/HomeCards.kt
app/src/main/kotlin/com/example/musicfy/ui/component/AppNavigation.kt
app/src/main/kotlin/com/example/musicfy/ui/component/GlassKit.kt
app/src/main/kotlin/com/example/musicfy/ui/player/MorphingCover.kt
app/src/main/kotlin/com/example/musicfy/ui/player/PlayerControls.kt
app/src/main/kotlin/com/example/musicfy/ui/player/QueueScreen.kt
app/src/main/kotlin/com/example/musicfy/ui/player/LyricsScreen.kt
app/src/main/kotlin/com/example/musicfy/ui/screens/HomeScreen.kt
app/src/main/kotlin/com/example/musicfy/ui/screens/library/LibraryHomeScreen.kt
app/src/main/kotlin/com/example/musicfy/ui/screens/search/SearchDesign.kt
app/src/main/kotlin/com/example/musicfy/ui/screens/search/SearchScreen.kt
app/src/main/kotlin/com/example/musicfy/ui/screens/search/LocalSearchScreen.kt
app/src/main/kotlin/com/example/musicfy/ui/screens/settings/ProfileScreen.kt
```

Pada sisi iOS, audit ini hanya mencatat artefak source-import-ready yang tersedia di `ios-app`; belum ada `xcodeproj`, belum memakai Xcode, dan belum ada klaim bahwa aplikasi iOS telah dibuild atau dijalankan.

## Baseline dan batas penerimaan

- Baseline branch: `feat/windows-playback-poc`.
- HEAD yang diaudit: `13decf68298ed88ab895551ff3c43b97d398af40`.
- Perubahan/dirty state `windows-poc` yang sudah ada dipertahankan; audit ini tidak mengubahnya.
- Tidak ada jaminan HEAD tersebut sama dengan build/runtime yang menghasilkan screenshot.
- Penerimaan parity akhir harus mencakup build iOS, navigasi antar tujuh layar, state data kosong dan berisi, expanded player, Queue, Lyrics, serta verifikasi screenshot baru pada runtime yang sama.
