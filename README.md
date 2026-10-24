# Tertata v5 (Flutter + SQLite + Asisten AI)

Founder: Muhammad Ikhsan · ican3192@gmail.com · Instagram @tertata.app

Aplikasi ini hanya mencatat dan mengelola keuangan; tidak membayar atau memindahkan uang sungguhan.

Kebijakan privasi: [PRIVACY.md](PRIVACY.md)

## Cara tercepat: otomatis
Syarat: Flutter SDK terpasang (`flutter doctor` hijau) dan Python 3.

```
python3 tool/bootstrap.py            # buat android/ & ios/, terapkan konfigurasi native, flutter pub get
flutter run                          # jalankan di HP/emulator
python3 tool/bootstrap.py --build    # atau sekalian build APK rilis
```
APK: `build/app/outputs/flutter-apk/app-release.apk` (ditandatangani kunci debug, cukup untuk dipasang pribadi).
Skrip aman dijalankan berulang kali. Isinya sama dengan langkah manual di `SETUP_NATIVE.md`.

## Tanpa memasang Flutter: build di GitHub
1. Buat repositori GitHub baru, unggah seluruh isi folder ini (termasuk folder `.github`).
2. Buka tab **Actions** > **Build APK** > **Run workflow** (juga jalan otomatis setiap push).
3. Setelah selesai, unduh APK dari bagian **Artifacts** (`tertata-apk`).
Log juga memuat hasil `flutter analyze` dan `flutter test`. Jika ada error, salin log-nya untuk diperbaiki.

## Tanda tangan APK & tautan unduhan (penting sebelum dibagikan)
Build cabang/PR tanpa secret ditandatangani kunci debug acak: **jangan dibagikan**, karena pengguna tidak bisa memperbarui
aplikasi (harus uninstall dan datanya hilang). Untuk APK yang dibagikan, pakai kunci rilis tetap:
1. Buat keystore (sekali saja, simpan berkasnya baik-baik di luar repositori; kalau hilang, pembaruan tidak mungkin lagi):
   `keytool -genkeypair -v -keystore release.jks -alias tertata -keyalg RSA -keysize 2048 -validity 10000`
2. Ubah ke teks: `base64 -w0 release.jks` (macOS: `base64 -i release.jks`).
3. Di GitHub: **Settings > Secrets and variables > Actions**, buat 4 secret: `RELEASE_KEYSTORE_BASE64`,
   `RELEASE_STORE_PASSWORD`, `RELEASE_KEY_ALIAS`, `RELEASE_KEY_PASSWORD`.
4. Tandai versi: `git tag v5.10.0 && git push origin v5.10.0`. APK muncul di halaman **Releases** beserta `apk-sha256.txt`.
`tool/setup_native.py` kini menghubungkan `android/key.properties` ke `signingConfigs.release` di Gradle (sebelumnya file itu
ditulis tetapi tidak dipakai). Build bertag gagal bila secret kurang atau Gradle belum membaca kunci. Setelah build, cek sertifikat
di artefak `apk-certs.txt`. Pengguna yang memasang APK berkunci acak harus uninstall sekali (cadangkan data dulu).

## Cara manual
Ikuti `SETUP_NATIVE.md`, lalu `flutter create .`, `flutter pub get`, `flutter run`.
Tes logika: `flutter test`.

## Baru di v5.10.0
- **Kalkulator di kolom nominal** (form transaksi): ketik hitungan seperti `25.000 + 7.500 × 2`, lihat hasilnya langsung, lalu Pakai. Mendukung + - × ÷, tanda kurung, dan minus; titik = ribuan, koma = desimal (`lib/core/calc.dart`).
- **Panduan di dalam aplikasi** (Lainnya > Panduan): ringkasan mencatat, notifikasi bank, anggaran, cadangan, PIN, AI, dan pembaruan.
- Tes baru: `calc_test.dart` dan dua tes tampilan (Panduan, Kalkulator) di `widgets_test.dart`. Belum dikompilasi; jalankan `flutter analyze` dan `flutter test`.

## Baru di v5.9.2 (hanya pengujian)
- **Tes tampilan pertama** (`test/widgets_test.dart`): halaman Laporan masalah (kosong dan berisi, angka panjang tersamarkan) dan halaman Cadangan otomatis.
- **Tes alur utuh cadangan** (`test/backup_flow_test.dart`): data > ekspor terenkripsi > berkas cadangan otomatis > dekripsi > pulihkan; kata sandi salah; gabungkan tanpa duplikat; berkas bukan Tertata ditolak; Hapus semua data mematikan jadwal; hapus transaksi mengembalikan saldo.
- Halaman Cadangan otomatis tidak lagi crash bila penyimpanan tidak tersedia.
- Belum dikompilasi; jalankan `flutter analyze` dan `flutter test`.

## Baru di v5.9.1
- **Pulihkan langsung** dari daftar cadangan otomatis (ikon pulihkan). Memakai kata sandi tersimpan; bila gagal, aplikasi menanyakannya.
- Cadangan otomatis juga dicek setiap aplikasi kembali ke layar depan, bukan hanya saat dibuka dari nol.
- **AAB untuk Google Play**: CI membuat `Tertata-v<versi>.aab` di artefak (tidak ikut Release publik). Bila langkah ini gagal, APK tetap diterbitkan.
- Belum dikompilasi; jalankan `flutter analyze` dan `flutter test`.

## Baru di v5.9.0
- **Cadangan otomatis terjadwal** (Pengaturan > Data): cadangan terenkripsi dibuat tiap 1/3/7 hari saat aplikasi dibuka, disimpan di penyimpanan privat aplikasi (5 terbaru), dan bisa dibagikan ke Drive lewat tombol bagikan. Kata sandi disimpan di penyimpanan aman Android; dihapus oleh Hapus semua data/Lupa PIN. Tanpa layanan latar belakang dan tanpa akun Google.
- Tes baru: `auto_backup_test.dart`. Belum dikompilasi; jalankan `flutter analyze` dan `flutter test`.

## Baru di v5.8.0
- **Cek versi terbaru di dalam aplikasi**: satu permintaan GET ke GitHub Releases, paling sering sekali sehari (bisa dimatikan), tanpa data pribadi. Spanduk "Versi X tersedia" muncul di Lainnya, dan Pengaturan punya tombol Periksa pembaruan. Tautan unduh memakai `Tertata.apk` dari rilis.
- **Catatan error lokal + Laporan masalah** (Pengaturan): error ditangkap (`FlutterError`, `PlatformDispatcher`, gagal mulai), disimpan maksimal 20 di perangkat dengan angka panjang disamarkan, dan hanya dibagikan bila pengguna menekan Bagikan. Tidak memakai layanan pihak ketiga.
- `kAppVersion` (`lib/core/app_info.dart`) harus sama dengan `version:` di `pubspec.yaml`; `test/app_info_test.dart` menjaganya. Ubah keduanya setiap rilis.
- Dependensi baru: `url_launcher`. Tes baru: `update_check_test.dart`, `crash_log_test.dart`, `app_info_test.dart`.
- Belum dikompilasi; jalankan `flutter analyze` dan `flutter test`.

## Baru di v5.7.3 (perbaikan build, tes, dan penandatanganan rilis)
- **Penandatanganan rilis benar-benar dipakai**: `setup_native.py` memasang `signingConfigs.release` yang membaca `android/key.properties`.
- **CI**: `bootstrap.py` kini jalan sebelum keystore ditulis (sebelumnya folder `android/` yang dibuat lebih dulu membuat `flutter create` terlewati dan build gagal), izin dasar `contents: read` (Release di job terpisah), pembatalan build ganda, batas waktu, verifikasi `apksigner`, dan Dependabot (`.github/dependabot.yml`).
- **Penyaring OTP diperbaiki** (`NotifInbox.kt.tmpl`): kata `OTP` berdiri sendiri sebelumnya tidak pernah cocok karena escape regex salah. Deret 10+ angka (nomor rekening/kartu/referensi) kini disamarkan menjadi ••••1234 sebelum disimpan.
- **Cadangan**: validasi isi file sebelum database disentuh (versi, tipe, ID ganda, nominal negatif); PBKDF2 naik ke 300.000 putaran (tercatat di header, cadangan lama 100.000 tetap terbuka); kata sandi minimal 8 karakter.
- **AI**: alamat API publik wajib `https://` (http hanya untuk jaringan lokal) agar kunci API tidak terkirim tanpa enkripsi.
- Folder `tool/native/` (salinan lama yang tidak dipakai) dihapus; yang dipakai hanya `tool/android/`.
- **Blokir tangkapan layar** (Pengaturan, Android): saklar opsional memakai `FLAG_SECURE`; layar tidak bisa difoto/direkam dan kosong di aplikasi terbaru. Bawaan: mati.
- **Tampilan lebih natural**: palet kertas hangat (latar, kartu, garis), kartu lebih bulat dengan bayangan tipis, tombol/chip/sheet lebih membulat, riak sentuhan biasa (bukan kilau), dan ikon kilau "AI" diganti gelembung obrolan. Logo AI NACI tetap.
- **Beranda dipoles**: sapaan dengan tanggal, kartu saldo lebih besar (radius 26, bayangan sewarna, angka 36) dengan panel Masuk/Keluar di dalamnya, aksi cepat lebih besar, daftar transaksi dengan pemisah halus, judul bagian lebih tegas, dan bilah navigasi dengan garis atas serta indikator pil.
- **Layar lain disamakan**: judul halaman bersama (`PageTitle`) dengan keterangan kecil di Transaksi, Analisis, dan Lainnya; pemisah halus antar baris di daftar Transaksi dan menu Lainnya; header hari lebih tegas; kartu profil di Lainnya bernuansa aksen; gelembung chat Asisten lebih membulat.
- Tes baru: `backup_validation_test.dart`, `ai_endpoint_test.dart`, `db_migration_test.dart`.
- Belum dikompilasi; jalankan `flutter analyze` dan `flutter test`.

## Baru di v5.6 (setelah v5.5)
- **Tema gelap terbaca**: kartu saldo, gelembung chat pengguna, dan tombol kirim memakai `fillOf`/`onFillOf` (`core/theme.dart`), sehingga teks di atasnya selalu kontras. Sebelumnya teks putih berada di atas warna primer yang terang di tema gelap.
- `withOpacity` (usang) diganti `withValues(alpha:)`.
- Kontak founder: nomor telepon dihapus dari aplikasi dan README, diganti Instagram.
- **Palet baru**: pengeluaran biasa jingga-bata (`kExpense`), merah (`kDanger`) hanya untuk bahaya (anggaran terlewati, tenggat lewat, hapus, defisit), pindah dana biru-abu, peringatan kuning tua, latar sedikit hangat kehijauan, teal lebih tua sebagai aksen bawaan.
- **Font bawaan aplikasi** (offline, lisensi OFL di `assets/fonts`): Plus Jakarta Sans untuk judul, Inter untuk isi dan angka tabular.
- **Beranda lebih ringkas**: urutan saldo, aksi cepat, Perlu perhatian, denyut bulan ini (dengan ringkasan perubahan), lalu Asisten dan Kesehatan sebagai dua kartu kecil. "Perlu perhatian" kini juga memberi peringatan dini anggaran (80% dan terlewati).
- **Langganan** (Lainnya): mendeteksi tagihan rutin bulanan/mingguan dari pola catatan, menampilkan biaya per bulan dan per tahun, dan bisa dijadikan transaksi berulang satu ketuk (`services/subscriptions.dart`).
- **Anggaran 50/30/20** (Analisis > Anggaran > Susun otomatis): membagi penghasilan ke kategori kebutuhan dan keinginan sesuai kebiasaan belanja 3 bulan terakhir (`services/budget_plan.dart`).
- **Tempel Notifikasi** (Beranda > Tempel, atau Lainnya): tempel teks SMS/notifikasi bank atau e-wallet (beberapa sekaligus, dipisah baris kosong); aplikasi menebak jenis, nominal (mengabaikan saldo dan biaya admin), pihak lawan, dompet, kategori, dan tanggal, menandai yang mirip transaksi sudah ada, lalu menyimpan yang Anda centang. Dibaca di perangkat tanpa AI (`services/notif_parser.dart`). Top up e-wallet dikenali sebagai pindah dana.
- Kartu cepat "Tanya AI" di Beranda diganti "Tempel" karena kartu Asisten sudah ada di bawahnya.
- Tes baru: `subscriptions_test.dart`, `budget_plan_test.dart`, `notif_parser_test.dart`.
- **Deteksi otomatis dari notifikasi (Android)**: layanan native menyimpan notifikasi transaksi dari aplikasi bank/e-wallet (dan SMS bila diaktifkan) ke kotak masuk lokal; banner di Beranda mengajak memeriksa dan mencatatnya lewat layar Tempel Notifikasi. Aktifkan di Lainnya > Deteksi Otomatis & Widget. Hanya paket aplikasi yang dikenal yang dibaca, tanpa internet dan tanpa AI.
- **Widget layar utama (Android)**: saldo (disembunyikan secara bawaan), pengeluaran bulan ini, "aman per hari", dan tombol "+ Catat" yang langsung membuka form transaksi baru.
- Kode native ada di `tool/android/` dan dipasang otomatis oleh `tool/bootstrap.py`; belum pernah dikompilasi atau diuji di HP asli. Lihat `SETUP_NATIVE.md`.
- - CI kini ketat: `flutter analyze --no-fatal-infos` dan `flutter test` harus lulus sebelum APK dibuat. Perbaikan v5.7.1: error sintaks di `theme.dart` (penyebab build dan 2 tes gagal), impor yang tidak terpakai, dan saran const.
- **Aksesibilitas**: cincin skor dan bar progres kini terbaca pembaca layar (nama + persen), ikon dekoratif disembunyikan, tombol ikon tanpa label diberi tooltip, dan pembesaran font sistem dibatasi 90%-130% agar kartu dan angka tidak terpotong.
- Belum dikompilasi; jalankan `flutter analyze` dan `flutter test`.

## Penyederhanaan tampilan (setelah v5.5)
- Palet netral dan kartu datar bergaris tipis tanpa bayangan; sudut lebih kecil; bobot huruf lebih ringan.
- Beranda: kartu saldo satu warna (tanpa gradien, lingkaran dekorasi, sparkline, atau animasi hitung); lencana streak dihapus.
- Asisten, layar kunci, Lainnya, dan Kesehatan: gradien latar dihapus; gelembung chat dan tombol kirim satu warna.
- Animasi masuk (`FadeSlideIn`) dinonaktifkan; kartu tidak lagi mengecil saat ditekan. Fungsi dan data tidak berubah.
- Belum dikompilasi; jalankan `flutter analyze` dan `flutter test`.

## Baru di v5.5 (perbaikan sebelum rilis)
- **Reset total lebih bersih**: "Lupa PIN" kini juga menghapus riwayat chat asisten, favorit, persetujuan AI, dan kunci API. Sebelumnya hanya database yang dihapus, sehingga orang lain bisa membaca chat lama atau memakai kunci API Anda.
- **Lupa PIN lebih aman dari salah ketuk**: harus mencentang pernyataan paham sebelum tombol hapus aktif.
- **Auto-backup Android dimatikan** (`allowBackup=false`): sebelumnya data bisa ikut tersalin ke cloud dan, di HP baru, PIN hasil pulihan tidak bisa diverifikasi (terkunci). Pindah HP: pakai fitur Cadangan bawaan aplikasi.
- **Pipeline rilis**: kunci tanda tangan tetap (secret `DEBUG_KEYSTORE_BASE64`), APK diberi nama versi, dan tag `v*` otomatis menerbitkan Release dengan tautan unduhan.
- Tes baru untuk reset total. Belum dikompilasi; jalankan `flutter analyze` dan `flutter test`.

## Baru di v5.4
- **Logo asisten AI baru**: simbol dua bintang kilau buatan sendiri (`core/ai_mark.dart`: `AiMark` lencana bergradien, `AiSparkle` ikon polos). Dipakai di navigasi, Beranda, Pengaturan, onboarding, dan halaman asisten, menggantikan ikon bawaan.
- **Halaman asisten dirombak**: header dengan logo yang berdenyut saat berpikir dan status aktif/tidak, sapaan sesuai waktu, ide dalam kartu 2 kolom, contoh kalimat siap ketuk, gelembung pesan bergradien dengan avatar asisten, animasi titik "berpikir", kolom ketik melayang dengan tombol kirim yang hidup saat ada teks, tekan lama pesan untuk menyalin.
- **Lupa PIN**: tombol di layar kunci dengan konfirmasi, menghapus semua data dan PIN agar aplikasi bisa dipakai lagi (pulihkan dari cadangan setelahnya).
- **Penutup privasi**: saat aplikasi ke latar belakang atau dibuka di tampilan aplikasi terbaru, isi layar ditutup logo bila PIN aktif, sehingga saldo tidak terlihat.
- Belum dikompilasi; jalankan `flutter analyze` dan `flutter test`.

## Baru di v5.3
- **Login**: layar kunci dirombak. Tombol keypad bulat, titik PIN beranimasi dan bergetar saat salah, sapaan sesuai waktu, serta tombol **Masuk dengan biometrik** yang jelas di samping keypad PIN (biometrik tetap otomatis muncul saat aplikasi dibuka).
- **PIN 6 digit baku**: pilihan 4 digit dihapus. PIN lama 4 digit tetap bisa dipakai, dan Pengaturan menampilkan ajakan "Perkuat PIN menjadi 6 digit".
- **Keamanan PIN (pembaruan setelah v5.4)**: PIN kini disimpan sebagai hash PBKDF2-SHA256 (100.000 putaran, salt acak) di penyimpanan aman Android (`flutter_secure_storage`), bukan lagi SHA-256 di SharedPreferences. PIN lama dimigrasikan otomatis saat pertama kali berhasil dipakai. Hitungan salah dan sisa waktu kunci juga di penyimpanan aman dan dihitung dengan stopwatch monoton, jadi mengubah jam HP atau menutup aplikasi tidak memendekkan kunci. Waktu kunci hanya berkurang saat aplikasi berjalan. Pengunci otomatis juga memakai stopwatch, bukan jam dinding.
- **Keamanan**: kunci sementara (30 dtk, 1, 2, lalu 5 menit) kini tersimpan sehingga tidak bisa dilewati dengan menutup aplikasi. Setelah PIN dibuat, aplikasi menawarkan mengaktifkan biometrik. Di Pengaturan, saklar biometrik selalu terlihat (nonaktif sampai PIN dibuat).
- **Logo tanpa latar**: `logo_full.png` kini transparan dan dipangkas, plus `logo_full_dark.png` (teks terang) yang dipakai otomatis di mode gelap lewat widget `BrandLogo`.
- **Tampilan lebih luwes**: kartu mengecil halus saat ditekan, kartu Beranda muncul berurutan, angka saldo berubah dengan animasi hitung, tombol Catat muncul/hilang halus, latar Beranda bergradien aksen, judul bagian lebih ringan, tipografi lebih berkarakter.
- Belum dikompilasi; jalankan `flutter analyze` dan `flutter test`.

## Baru di v5.2
- **Kesehatan Keuangan** (Lainnya dan kartu di Beranda): skor 0-100 dari tingkat tabungan, dana darurat, disiplin anggaran, dan beban hutang, lengkap dengan saran langkah paling berdampak.
- **Akan Datang**: tagihan, transaksi berulang, dan hutang/piutang jatuh tempo 30 hari ke depan, dikelompokkan per tanggal, plus ringkasan 14 hari di Beranda.
- **Wawasan** (Analisis > Wawasan): pola belanja per hari dalam seminggu, perubahan per kategori dibanding bulan lalu, rata-rata harian, hari tanpa belanja, dan 5 pengeluaran terbesar.
- File baru: `services/insights.dart`, `screens/health.dart`, `screens/upcoming.dart`, `screens/insights.dart`. Belum dikompilasi; jalankan `flutter analyze` dan `flutter test`.

## Baru di v5.1 (penyempurnaan tampilan)
- Palet semantik lebih halus, latar halaman bernuansa aksen, 2 warna aksen baru (Zamrud, Delima).
- Transisi halaman, switch, daftar, dan indikator progres kini seragam dengan tema.
- Kartu dengan bayangan berlapis; judul bagian memakai penanda aksen.
- Beranda: kartu "Aman dipakai per hari" (cincin progres anggaran/pemasukan, tingkat tabungan, bar kategori terbesar).
- Komponen baru: `RingGauge`, `SoftChip`. Umpan haptik pada navigasi bawah.
- Perbaikan crash "Aplikasi gagal dimulai ... NoSuchMethodError SharedPreferencesApiRegistrar.getAll" pada APK rilis: R8/minify dimatikan lewat `tool/setup_native.py`.
- Catatan: perubahan ini belum dikompilasi; jalankan `flutter analyze` dan `flutter test`.

## Baru di v5
Desain:
- Sistem tema baru: palet warna semantik yang lebih segar, kartu dengan sudut 20 dan bayangan lembut, gradien aksen turunan otomatis, tombol/chip/bottom sheet/snackbar yang seragam, serta angka berlebar tetap agar rapi sejajar.
- Beranda: kartu saldo bergradien dengan grafik mini tren 6 bulan, indikator naik/turun bulan ini, aksi cepat berbentuk kartu, kartu asisten bergradien.
- Navigasi periode berbentuk pill; header hari di daftar transaksi berwarna sesuai arus; kartu ringkasan di menu Lainnya.
Fitur:
- Favorit transaksi: simpan transaksi yang sering dipakai (ikon bintang di form), pilih lewat chip; tekan lama untuk menghapus.
- Streak hari berturut-turut mencatat.
- Proyeksi pengeluaran akhir bulan di Laporan.
- Pengingat cadangan: peringatan jika tidak ada cadangan 30+ hari; tanggal cadangan terakhir tampil di Pengaturan.
Sistem:
- Cache agregat (total & per kategori) yang otomatis dibersihkan saat data berubah, agar laporan tetap cepat saat transaksi banyak.
- Tes tambahan: cache, streak, favorit.

## Di v4.3
- Tampilan kalender di tab Transaksi: total masuk/keluar per hari, ketuk tanggal untuk melihat transaksinya.
- Perbaikan stabilitas: tombol aksi mengambang tidak lagi bentrok antar layar (error hero tag), dan penentuan warna aksen lebih aman secara tipe.

## Di v4.2
- Layar sambutan saat pertama kali dibuka: pengantar singkat, isi saldo awal dompet, pilihan mata uang, dan opsi PIN.
- Riwayat percakapan asisten tersimpan (40 pesan terakhir); AI sendiri tidak mengingat isinya.
- Tata letak tablet/landscape: isi dibatasi lebarnya agar nyaman dibaca.
- Penanganan error: layar pemulihan jika aplikasi gagal start dan tampilan error yang ramah di mode rilis.
- Cocokkan saldo kini mencatat koreksi netral (tidak dihitung sebagai pemasukan/pengeluaran) dan bisa dihapus dengan geser.
- Tooltip aksesibilitas pada tombol ikon utama.
- Tes baru `test/app_state_test.dart`: saldo, hutang netral, patungan, transaksi berulang, cadangan, rekonsiliasi.

## Menjalankan tes
`flutter test`. Tes database memakai `sqflite_common_ffi`, jadi butuh pustaka SQLite di komputer
(macOS sudah ada; Linux: `sudo apt install libsqlite3-dev`; Windows: letakkan `sqlite3.dll` di PATH).

## Di v4.1
- Hutang & piutang bisa terhubung ke dompet (opsional): saldo dompet ikut berubah, tetapi arus ini bertanda "netral" sehingga tidak dihitung sebagai pemasukan/pengeluaran di laporan, anggaran, dan ringkasan AI.
- Patungan (ikon grup di Hutang & Piutang): bagian Anda jadi pengeluaran, bagian teman jadi piutang otomatis.
- Migrasi database ke skema versi 4 (otomatis).

## Di v4
- Biometrik (sidik jari/wajah) dengan PIN sebagai cadangan.
- Pengingat lokal: tagihan/jatuh tempo (H-1 dan hari-H) dan pengingat catat harian.
- Scan struk: foto atau galeri, dibaca AI menjadi draf transaksi.
- Laporan PDF (Analisis > Laporan > Ekspor laporan PDF).
- Rollover anggaran: sisa bulan ini menambah batas bulan berikutnya.
- Cadangan terenkripsi kata sandi (AES-256-GCM), pemulihan "ganti semua" atau "gabungkan".
- Batas pemakaian AI per hari.
- Migrasi database ke skema versi 3 (otomatis, data lama aman).

## Asisten AI
Lainnya > Pengaturan > Asisten AI > pilih penyedia gratis (Google Gemini: aistudio.google.com/apikey, atau Groq/OpenRouter), tempel kunci API, lalu Simpan & uji.
Tanpa kunci, pencatatan cepat dari kalimat dan saran kategori tetap bekerja secara lokal.
Kunci disimpan terenkripsi di perangkat dan tidak masuk file cadangan.
Untuk aplikasi yang dibagikan ke banyak orang, gunakan server perantara; jangan menanam kunci di aplikasi.


## Keamanan build APK (GitHub Actions)

Workflow mengunggah laporan izin APK (`apk-permissions.txt`) dan SHA-256 (`apk-sha256.txt`) sebagai artefak audit. Untuk distribusi publik, gunakan keystore rilis khusus dan jangan pernah mengunggah keystore/password ke repositori.

Secrets yang disiapkan workflow untuk signing rilis:
- `RELEASE_KEYSTORE_BASE64`
- `RELEASE_STORE_PASSWORD`
- `RELEASE_KEY_ALIAS`
- `RELEASE_KEY_PASSWORD`

**Penting:** file `android/key.properties` saja tidak otomatis membuat Gradle memakai keystore tersebut. Pastikan konfigurasi `signingConfigs.release` pada `android/app/build.gradle` atau `build.gradle.kts` membaca `key.properties` dan mengaitkan `buildTypes.release.signingConfig` sebelum menganggap APK sudah ditandatangani dengan kunci rilis. Workflow menolak tag rilis jika secrets keystore tidak tersedia, tetapi pemeriksaan sertifikat APK tetap wajib sebelum distribusi.
