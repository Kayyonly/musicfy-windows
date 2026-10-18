# Musicfy iPhone — laporan prototipe UI

Source prototipe SwiftUI untuk **tujuh halaman** sudah disiapkan di `ios-app/`, tanpa mengubah berkas lama. Prototipe menggunakan data lokal dan artwork geometris buatan SwiftUI. **Belum ada build iOS atau pengujian simulator/iPhone**, sehingga statusnya siap diimpor untuk review di Xcode, bukan milestone yang seluruh kriteria penerimaannya sudah terbukti terpenuhi.

## Baseline dan keputusan aman

Repository: `/workspace/musicfy-windows`. Branch tetap `feat/windows-playback-poc`, HEAD tetap `13decf68298ed88ab895551ff3c43b97d398af40`. Folder `ios-app/` semula tidak ada; lokasi diperiksa dapat ditulis dan bukan konflik/symlink sebelum dibuat. Tidak ada project sebelumnya yang ditimpa, reset, checkout branch, commit, atau operasi destruktif.

Working tree sudah mempunyai enam tracked file yang dimodifikasi dan sejumlah untracked file di `windows-poc/` sebelum pekerjaan ini. Semua dipertahankan. Pemeriksaan SHA-256 membandingkan **2.605 berkas awal** di luar `ios-app/`: tidak ditemukan perubahan, kehilangan, atau tambahan di luar folder proyek baru. Artinya source Android, provider, konfigurasi build/release/database, serta perubahan Windows sebelumnya tidak disentuh oleh pekerjaan ini. Bukti tersimpan di `baseline-files.json`, `baseline-git-status.txt`, dan `STATIC-CHECKS.json`.

## Yang dibuat

- **Home:** hero Random plays/Gacha, tombol Roll untuk memilih mock track, Recently Played, Most Played, More like, dan Jump Back In dengan carousel lokal.
- **Search:** field kapsul, grid dua kolom Moods & moments, riwayat pencarian lokal, filter metadata All/Music/Artist/Album, top-result card, daftar lagu, serta no-result state. Mood tiles hanya membuka penjelasan demo, bukan pencarian provider.
- **Library:** field pencarian library kosong, banner provider generik dengan penjelasan keterbatasan, kartu Add local music, dan empty state. Tidak ada impor atau koneksi provider sungguhan.
- **Profile:** branding/greeting demonstrasi, kartu identitas nonpersonal `DEMO-0001`, statistik waktu contoh, kartu Version bertuliskan UI Prototype, dan penjelasan About/Settings. Tidak ada foto, nama, ID akun, atau tanggal bergabung pemilik yang disalin.
- **Now Playing:** artwork dominan, latar tonal/blur, metadata, favorite, slider progres, transport, serta akses Queue/Lyrics. Semua state senyap.
- **Queue:** selected track dan daftar Continue Playing lokal; pemilihan row mengubah track. Reorder/swipe-remove/autoplay Android belum diport.
- **Lyrics:** empat baris teks orisinal yang dapat disorot dengan tap; tidak memakai lirik berhak cipta dan tidak tersinkron ke audio.

Design system, model, state, dan komponen reusable dipisahkan. Minimum target **iOS 17.0**, Swift 5 language mode, tanpa dependency pihak ketiga. Tidak ada network request, API provider, login, token/cookie, stream resolver, relay, AVPlayer, MusicKit, backend, signing, atau CI baru.

Daftar lengkap setiap berkas beserta fungsi ada di [FILE-LIST.md](FILE-LIST.md). Petunjuk impor ada di [README.md](../README.md).

## Source Android dan keputusan visual

Audit tim membaca implementasi nyata `App.kt`, `MainActivity.kt`, `Screens.kt`, Home/Search/Library/Profile beserta desainnya, theme/type/font, AppNavigation, GlassKit, PinnedBottomScaffold, HeroCarousel, HomeCards, SearchBar, BottomSheet, BottomSheetPlayer, MorphingCover, PlayerControls, PlayerUiState, QueueScreen, LyricsScreen, serta constants/Dimensions. Inventaris path lengkap dan referensi baris ada di [UI-AUDIT.md](UI-AUDIT.md).

Yang dipertahankan secara struktur: latar hitam, typography berat, artwork persegi membulat, carousel horizontal, field kapsul, mini-player di atas navigasi, active state navigasi, serta layering player. Beberapa token source digunakan sebagai dasar: navigasi tinggi 64/radius 32, mini-player tinggi 64, inset 24, gap kartu 15, dan artwork besar 137. Angka SwiftUI merupakan adaptasi pt, bukan klaim dp/sp identik secara fisik.

Perbedaan penting yang dicatat:

- Screenshot menampilkan hasil data/runtime; source memiliki section Home dan mood/provider yang dinamis. Katalog mock dan urutan konten tidak menyatakan personalisasi nyata.
- Label **Jump Back In** mengikuti screenshot; literal itu belum ditemukan pada HomeScreen yang diperiksa. “More like” memakai pilihan lokal, bukan rekomendasi.
- Chip Search di source lokal berbeda dari screenshot. Demo hanya menyediakan filter metadata yang dapat didukung katalog; Video/Playlist tidak dipalsukan.
- Font SF/system menggantikan Inter; tidak ada font Android atau artwork komersial dibundel. Ikon memakai SF Symbols, bukan salinan ikon Musicfy; logo/avatar/provider visual generik.
- Radius mini-player 28 adalah adaptasi visual screenshot, bukan nilai Android yang sudah terbukti. Artwork generik memakai radius 16. Material SwiftUI tidak identik dengan blur RenderEffect Android.
- Hero dibatasi 320 pt, bukan carousel 60% tinggi layar dengan transisi Android. Profile tidak mengimplementasikan flip/barcode/scratch/recap. Nilai statistik dan versi diberi label demo.
- Tidak ada screenshot referensi expanded player, Queue, atau Lyrics. Ketiganya adaptasi source dan belum dapat dinilai kesesuaian visualnya.

## Interaksi yang terhubung di source

Empat tab memilih halaman; state tab dipertahankan selama aplikasi hidup. Field Search memfilter metadata lokal; submit menyimpan maksimal lima query; clear menghapus input. Memilih track memperbarui mini-player, dan mengetuknya membuka sheet player. Player menyediakan previous/next dengan wrap-around, favorite per track, slider, dan play/pause demo. Queue dan Lyrics terhubung melalui NavigationStack dengan back. Focus Search/Library diarahkan untuk dilepas ketika tab berubah.

**Ini hasil inspeksi wiring source, bukan bukti interaksi berhasil pada perangkat.** Shuffle/repeat hanya mengubah state/tampilan, tidak mengubah urutan atau menjalankan loop audio. Progres tidak memiliki timer; app tidak menghasilkan suara. Provider/import/stats/settings menampilkan keterangan demo, bukan fitur lengkap.

## Pemeriksaan yang benar-benar dilakukan

`python3 ios-app/Scripts/verify_static.py` dijalankan dan **11 pemeriksaan lulus**: preservasi berkas lama, branch, HEAD, keberadaan tujuh screen, whitelist framework Apple, ketiadaan API jaringan/audio yang diperiksa, satu entry point, tanpa manifest dependency, berkas Swift lengkap/newline, screening delimiter, serta keberadaan source XCTest. Hasil terstruktur ada di [STATIC-CHECKS.json](STATIC-CHECKS.json).

`git diff --check` dijalankan tanpa temuan. Perlu dicatat Git belum melacak `ios-app/`, sehingga perintah ini terutama memeriksa perubahan tracked lama; berkas baru diperiksa terpisah oleh skrip statis dan inspeksi source. Semua berkas baru tetap untracked agar tidak mencampurkan commit dengan pekerjaan Windows sebelumnya.

Disediakan **tujuh metode XCTest** untuk initial state/play-pause, pencarian, reset pemilihan track, next/previous wrap-around, favorite, selected track kosong, dan riwayat query. **XCTest belum dijalankan.** Tidak ada pengujian Python yang diklaim sebagai eksekusi Swift.

## Yang belum dapat diverifikasi

Sandbox ini Linux tanpa `swift`, `swiftc`, `xcodebuild`, Apple SDK, dan iOS Simulator. Pemeriksaan teks tidak dapat memastikan type-checking SwiftUI, target membership Xcode, rendering, hit testing, transisi, keyboard focus, VoiceOver, kontras akhir material, ataupun layout pada semua ukuran layar dan Dynamic Type.

Tidak dibuat `.xcodeproj` yang belum dapat divalidasi; alternatif source siap impor memang diperbolehkan spesifikasi. Belum ada screenshot hasil aplikasi iOS. Tidak ada klaim build berhasil, UI berjalan di iPhone, atau desain telah diterima. Library berisi, loading/error provider, persistence, animasi morphing player, gesture player Android, serta integrasi musik bukan hasil tahap ini.

## Status fase dan langkah berikutnya

| Fase | Status |
|---|---|
| 0 — reconnaissance | Audit source/baseline selesai; kesamaan commit dengan build Android pada screenshot belum terbukti |
| 1 — prototype | Source tujuh screen, komponen, model, state, dokumentasi siap diimpor; belum dikompilasi |
| 2 — interaksi | Wiring dan review statis dilakukan; pengujian runtime belum dilakukan |
| 3 — visual acceptance | Pemetaan ke referensi disusun; acceptance visual masih tertunda |
| 4 — stop | Berhenti pada prototipe UI; tidak melanjutkan integrasi |

Langkah selanjutnya cukup membuka Mac dengan Xcode yang sah, mengikuti README untuk membuat target **MusicfyIOS**, mengimpor source, lalu build/run/test dan membandingkan enam state screenshot. Perbaikan compiler/layout bila ditemukan dan persetujuan visual harus mendahului integrasi musik. Tidak ada instalasi toolchain besar atau tindakan lanjutan otomatis yang dilakukan di komputer pemilik.
