# Musicfy iPhone — Proyek Xcode dan CI manual siap ditinjau

**Persiapan selesai; belum ada build atau XCTest di macOS.** Konfigurasi proyek, path source, target membership, shared scheme, dan rancangan workflow sudah diaudit statis. Ini bukan klaim bahwa Xcode telah menerima proyek atau bahwa aplikasi berhasil dikompilasi.

## Fase A — Checkout asli tetap utuh

Pekerjaan berada di clone lokal baru yang terisolasi:

`/workspace/musicfy-ios-ci-review-nzjvvs87/repo`

Clone dibuat pada detached HEAD `13decf68298ed88ab895551ff3c43b97d398af40`, bukan dengan memindahkan branch checkout asli. Hanya 37 file `ios-app/` disalin dari working tree pemilik; semuanya tetap identik byte dan mode file-nya. Perubahan lokal Windows tidak ikut disalin. Baseline tracked Android/Windows tetap berasal dari HEAD tersebut.

Checkout asli `/workspace/musicfy-windows` tetap pada `feat/windows-playback-poc`, HEAD yang sama. Sebelum pekerjaan ada 6 file tracked Windows berubah dan 80 file untracked terlihat oleh Git, termasuk 36 file iOS; satu helper iOS lain tersembunyi oleh aturan global repo `*.py`. Snapshot menginventarisasi seluruh 37 file iOS tersebut.

Pemeriksaan akhir membandingkan **1.519 entri konten/mode**, inventaris file, status Git lengkap, diff tracked dan staged sebelum/sesudah: tidak berubah. Di clone, seluruh **1.438 file tracked baseline** juga tetap identik dengan HEAD. Tidak ada source Android atau Windows diubah. Tidak ada commit, push, merge, atau operasi destruktif.

## Fase B — Proyek dan target

Dua file Xcode baru:

- `ios-app/MusicfyIOS.xcodeproj/project.pbxproj`
- `ios-app/MusicfyIOS.xcodeproj/xcshareddata/xcschemes/MusicfyIOS.xcscheme`

Target **MusicfyIOS** adalah aplikasi iPhone dengan 31 source Swift dari App, Components, Models, Screens, State, dan Theme. Target **MusicfyIOSTests** adalah hosted unit-test bundle dengan `Tests/MusicfyDemoStateTests.swift` (12 metode XCTest) dan `Tests/PlayerControllerTests.swift` (16 metode XCTest); yang sudah ada tidak diubah. Test menggunakan `@testable import MusicfyIOS`, `TEST_HOST`, `BUNDLE_LOADER`, dan dependency/proxy ke aplikasi. Source app tidak diduplikasi ke target test.

Kedua target memiliki Debug/Release, minimum **iOS 17.0**, Swift language mode **5.0**, `iphoneos iphonesimulator`, dan device family iPhone. Info.plist dihasilkan oleh Xcode; app memakai generated launch screen dan scene manifest. Debug mengaktifkan testability. Shared scheme **MusicfyIOS** membangun kedua target untuk testing dan memasukkan unit-test target dalam TestAction Debug. Tidak ada archive action atau build-for-archiving.

Signing dinonaktifkan di konfigurasi project/target dan perintah CI melalui `CODE_SIGNING_ALLOWED=NO` serta `CODE_SIGNING_REQUIRED=NO`. Tidak ada team, signing identity, provisioning profile, package, API, audio playback, atau target distribusi baru.

Audit awal menemukan path fileRef dan ID build phase yang salah pada draf pertama. Keduanya diperbaiki sebelum serah terima; audit akhir memeriksa path nyata, semua referensi objek, dependency, konfigurasi, dan scheme.

## Fase C — Workflow manual saja

File baru: `.github/workflows/ios-ui-ci.yml`.

Runner direncanakan **`macos-15` dengan Xcode 16.4**, dipilih eksplisit melalui `DEVELOPER_DIR=/Applications/Xcode_16.4.app/Contents/Developer`. [Inventaris resmi runner](https://github.com/actions/runner-images/blob/main/images/macos/macos-15-Readme.md) mencantumkan versi ini dan SDK iOS/simulator 18.5. SDK yang lebih baru dapat menargetkan minimum iOS 17; ini tidak membuktikan perilaku pada runtime iOS 17. Image hosted tetap dapat berubah: jika Xcode tersebut tidak lagi tersedia, workflow berhenti tanpa mengunduh toolchain atau mengganti versi diam-diam.

Satu-satunya event adalah **`workflow_dispatch`**. Tidak ada push, pull_request, schedule, atau deployment. Permission hanya **`contents: read`**. Checkout resmi dipin ke SHA, mengambil satu commit dengan sparse checkout iOS/workflow, tanpa menyimpan kredensial, tags, submodules, atau LFS. Token baca otomatis GitHub bukan repository secret yang perlu dibuat pengguna.

Urutan yang baru akan berjalan setelah persetujuan: catat versi toolchain/SDK dan inventaris simulator; jalankan audit offline; validasi target/scheme dengan Xcode; pilih UDID iPhone yang tersedia pada runtime iOS >=17 dan diterima scheme; jalankan `build-for-testing`, kemudian `test-without-building`, dengan signing dimatikan. Tidak ada nama simulator yang ditebak. Jika tidak ada kandidat, langkah gagal dengan jelas, tanpa membuat atau mengunduh simulator.

Tidak ada pengunduhan dependency aplikasi atau tooling pihak ketiga; dua action resmi GitHub adalah checkout dan unggah diagnosis, keduanya dipin SHA. Log terpilih, inventaris, dan result bundle `.xcresult` disimpan selama **3 hari**; tidak ada unggahan DerivedData, aplikasi, signed archive, IPA, atau dump environment.

## File pendukung baru

- `ios-app/.gitignore`: membuka ignore untuk helper Python yang disetujui; mengabaikan state Xcode, cache Python, dan keluaran diagnosis.
- `ios-app/CI/check_project.py`: audit struktur project, semua path dan target membership, signing, dependency, dan shared scheme; hanya Python standard library.
- `ios-app/CI/select_destination.py`: memilih simulator dari JSON inventaris dan daftar destination scheme, tanpa menjalankan simulator.
- `ios-app/CI/test_ci_helpers.py`: 16 tes fixture offline untuk pemilihan dan penolakan simulator yang tidak memenuhi syarat.
- `ios-app/Docs/CI-PREPARATION-REPORT.md`: laporan ini. Dokumen prototipe lama dipertahankan sebagai riwayat tanpa ditulis ulang.

## Fase D — Hasil pemeriksaan dan diff

**Lulus:** parsing OpenStep project, parsing XML scheme, audit graph/referensi dan source membership 31+2, konfigurasi target, sintaks Python, 16 unit test helper Python, parsing YAML 1.2 memakai parser yang sudah tersedia, pemeriksaan kontrak workflow, serta `bash -n` pada semua blok shell. Tidak ada toolchain yang dipasang. Helper prototipe lama tidak dijalankan karena menulis ulang laporan dan memakai asumsi working tree historis.

**Belum dibuktikan:** penerimaan file oleh Xcode/GitHub Actions, kompilasi Swift, linking, hosted XCTest discovery/execution, boot atau instalasi simulator, tampilan tujuh layar, aksesibilitas, dan kompatibilitas runtime iOS 17. `actionlint` dan Xcode tidak tersedia. Tes Python yang lulus bukan XCTest iOS.

Diff dan bukti lengkap berada di `/workspace/musicfy-ios-ci-review-nzjvvs87/evidence/`:

- `full-new-files.diff`: seluruh **45 file tambahan** relatif terhadap HEAD, termasuk 37 file prototipe salinan yang belum tracked di checkout asli.
- `ci-preparation-only.diff`: hanya **8 file baru** tahap persiapan ini; tidak mengulang prototipe yang sudah disetujui.
- `isolation-checks.json`, `source-manifest-before.json`, `ios-source-manifest.json`, log audit project/workflow/helper, dan snapshot Git: bukti batas perubahan serta preservasi checkout asli. Snapshot Windows hanya bukti internal, bukan bagian patch.

Kedua patch hanya memuat `ios-app/` dan `.github/workflows/ios-ui-ci.yml`. Isi patch lengkap, bukan sekadar statistik. Gunakan full patch hanya pada baseline bersih tanpa `ios-app/`; focused patch hanya pada salinan yang sudah memuat 37 file prototipe. Jangan menerapkan keduanya sekaligus atau menerapkannya ke working tree Windows yang sedang berubah.

## Tahap berikutnya — menunggu pemilik

1. Tinjau proyek, workflow, dan focused diff pada clone terisolasi. Audit offline dapat diulang tanpa Xcode dengan `python3 ios-app/CI/check_project.py` dan `python3 -m unittest discover -s ios-app/CI -p 'test_*.py' -v`.
2. Berikan persetujuan eksplisit tersendiri sebelum publikasi/commit/push atau pemindahan workflow ke default branch. Belum ada tindakan tersebut dilakukan.
3. [GitHub mensyaratkan workflow dispatch tersedia pada default branch](https://docs.github.com/en/actions/how-tos/manage-workflow-runs/manually-run-a-workflow). Ini bukan izin memindahkannya sekarang. Setelah publikasi yang disetujui, pemilik perlu menyetujui revisi yang akan diuji dan eksekusi manual sebelum Run workflow dilakukan.
4. Sesudah run macOS yang disetujui, tinjau log dan XCTest result bundle sebelum menyatakan build/test berhasil.

**Berhenti pada tahap tinjauan. Workflow tidak dikirim atau dijalankan, secrets tidak dibuat/digunakan, signing/instalasi tidak dilakukan, dan tidak ada IPA yang dibuat.**
