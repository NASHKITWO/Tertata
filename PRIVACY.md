# Kebijakan Privasi Tertata

Berlaku sejak 21 Oktober 2026 · Versi aplikasi 5.10.0

Tertata adalah aplikasi pencatat keuangan pribadi. Aplikasi ini hanya mencatat dan mengelola keuangan; tidak membayar atau memindahkan uang sungguhan.

## 1. Data tersimpan di perangkat Anda
Transaksi, dompet, anggaran, target, hutang, dan pengaturan disimpan **lokal** (SQLite) di perangkat Anda. Kami tidak punya server, akun pengguna, iklan, atau analitik, sehingga kami tidak menerima, melihat, atau menyimpan data keuangan Anda.

- PIN disimpan sebagai hash di penyimpanan aman Android, bukan teks asli.
- Cadangan (backup) hanya dibuat saat Anda memintanya dan disimpan ke tempat yang Anda pilih. Anda dapat mengenkripsinya dengan kata sandi (minimal 8 karakter).
- **Cadangan otomatis (opsional)** membuat cadangan terenkripsi secara berkala dan menyimpannya di penyimpanan privat aplikasi di perangkat. Kata sandinya disimpan terenkripsi di penyimpanan aman Android. Hapus semua data, Lupa PIN, atau mematikan fitur ini menghapus kata sandi tersebut; berkas ikut terhapus bila Anda memilihnya atau memakai Hapus semua data/Lupa PIN. Berkas tidak dikirim ke mana pun kecuali Anda membagikannya sendiri.
- Auto-backup Android dimatikan, sehingga data tidak ikut tersalin ke cloud secara otomatis.

## 2. Fitur AI (opsional)
Asisten AI dan scan struk **tidak aktif** sampai Anda memasukkan kunci API milik Anda sendiri dari penyedia AI pilihan Anda (Google Gemini, Groq, OpenRouter, atau layanan lain yang kompatibel) dan menyetujui pengiriman data di dalam aplikasi.

Saat Anda bertanya ke asisten atau memindai struk, aplikasi mengirim langsung dari perangkat Anda ke penyedia AI yang Anda pilih:
- pertanyaan atau pesan yang Anda ketik;
- ringkasan dan transaksi yang relevan dengan pertanyaan itu (mis. jumlah, kategori, catatan, dompet, tanggal);
- foto struk, bila Anda memakai scan struk.

Data ini tidak melewati server kami. Pemrosesannya oleh penyedia tunduk pada kebijakan penyedia tersebut; paket gratis umumnya boleh memakai data untuk meningkatkan produk mereka, dan penggunaan kunci API mengikuti kuota/biaya akun Anda di penyedia. Anda dapat mencabut persetujuan kapan saja di Pengaturan AI; setelah itu tidak ada data yang dikirim.

Kunci API disimpan terenkripsi di perangkat dan tidak ikut dalam file cadangan.

## 3. Izin aplikasi
- **Akses notifikasi (opsional, Android)**: hanya aktif bila Anda menyalakannya sendiri di pengaturan sistem. Fitur ini memeriksa notifikasi dari aplikasi bank/e-wallet yang dikenali (dan aplikasi SMS yang didukung bila Anda mengaktifkannya), lalu menyimpan secara lokal notifikasi yang cocok dengan pola nominal rupiah dan kata transaksi. Deret 10+ angka (mis. nomor rekening) disamarkan sebelum disimpan. Notifikasi yang tidak cocok diabaikan. Penyaring juga menolak teks yang terdeteksi mengandung istilah OTP, kata sandi, PIN, atau kode verifikasi; penyaringan berbasis pola tidak sempurna dan Anda tetap harus menghindari membagikan kode rahasia. Isi kotak masuk tidak dikirim ke server Tertata atau penyedia AI, dihapus otomatis setelah 14 hari atau saat Anda mengosongkannya, dan akses bisa dicabut kapan saja di pengaturan Android. Sebelum mengaktifkan akses, pahami bahwa izin sistem memungkinkan layanan melihat notifikasi perangkat, bukan hanya notifikasi bank.
- **Widget layar utama (opsional)**: menampilkan ringkasan dari data lokal. Saldo disembunyikan secara bawaan; bila Anda menyalakannya, saldo terlihat di layar utama tanpa PIN.
- **Internet**: untuk fitur AI di atas dan pemeriksaan versi terbaru (lihat bagian 3a).
- **Kamera / galeri**: hanya saat Anda memilih foto struk.
- **Biometrik**: untuk membuka kunci aplikasi; data biometrik dikelola sistem Android dan tidak dapat dibaca aplikasi.
- **Notifikasi (kirim)**: untuk pengingat tagihan dan catatan berulang.

### 3a. Pemeriksaan pembaruan dan catatan error
- Aplikasi memeriksa rilis terbaru lewat satu permintaan GET ke `api.github.com`, paling sering sekali dalam 24 jam. Tidak ada data pribadi atau keuangan yang dikirim; GitHub tetap dapat melihat alamat IP perangkat. Dapat dimatikan di Pengaturan > Pembaruan & masalah.
- Error aplikasi dicatat **hanya di perangkat** (maksimal 20 catatan; deret angka panjang disamarkan; tanpa transaksi atau saldo). Tidak dikirim otomatis. Anda yang memutuskan membagikannya lewat Pengaturan > Laporan masalah, dan dapat menghapusnya kapan saja.

## 4. Menghapus data
- **Hapus semua data** (Pengaturan) menghapus seluruh catatan keuangan di perangkat.
- **Lupa PIN** menghapus data, PIN, riwayat chat asisten, persetujuan AI, dan kunci API.
- Mencopot aplikasi menghapus data lokalnya. Cadangan yang Anda simpan sendiri tetap menjadi tanggung jawab Anda.
- Data yang sudah dikirim ke penyedia AI diatur oleh kebijakan penyedia; kami tidak dapat menghapusnya dari sisi mereka.

## 5. Anak-anak
Tertata tidak ditujukan bagi anak di bawah 13 tahun.

## 6. Perubahan
Perubahan kebijakan akan dicantumkan di berkas ini beserta tanggal berlakunya.

## 7. Kontak
Muhammad Ikhsan · ican3192@gmail.com
