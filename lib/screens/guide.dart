import 'package:flutter/material.dart';
import '../common.dart';

class _Topic {
  const _Topic(this.icon, this.title, this.lines);
  final IconData icon;
  final String title;
  final List<String> lines;
}

const _topics = <_Topic>[
  _Topic(Icons.edit_note, 'Mencatat transaksi', [
    'Ketuk tombol Catat, pilih Keluar, Masuk, atau Pindah dana, isi nominal, dompet, dan kategori.',
    'Ketuk Kalkulator di bawah nominal untuk menghitung, misalnya 25.000 + 7.500 × 2. Titik adalah pemisah ribuan, koma untuk desimal.',
    'Transaksi yang sering diulang bisa disimpan sebagai favorit supaya sekali ketuk.',
    'Geser transaksi di daftar untuk menghapus. Ada tombol Urungkan sebentar setelahnya.',
  ]),
  _Topic(Icons.content_paste_go_outlined, 'Dari SMS atau notifikasi bank', [
    'Lainnya > Tempel Notifikasi: tempel teks SMS atau notifikasi bank/e-wallet, aplikasi menebak nominal, jenis, dan kategorinya, lalu Anda centang yang mau disimpan.',
    'Lainnya > Deteksi Otomatis & Widget (Android) menyimpan notifikasi transaksi ke kotak masuk lokal. Perlu izin akses notifikasi yang Anda nyalakan sendiri di pengaturan sistem, dan bisa dicabut kapan saja.',
    'Impor Mutasi (CSV) memasukkan banyak transaksi sekaligus dari rekening bank.',
  ]),
  _Topic(Icons.pie_chart_outline, 'Anggaran, target, dan hutang', [
    'Analisis > Anggaran: batasi pengeluaran per kategori. Susun otomatis membagi penghasilan memakai pola 50/30/20 sesuai kebiasaan belanja Anda.',
    'Target Tabungan menghitung progres menuju tujuan Anda.',
    'Hutang & Piutang mencatat siapa yang berhutang dan cicilannya, lengkap dengan tenggat.',
    'Transaksi Berulang dan Langganan mengingatkan tagihan rutin. Langganan terdeteksi otomatis dari pola catatan.',
  ]),
  _Topic(Icons.favorite_outline, 'Kesehatan keuangan dan wawasan', [
    'Kesehatan Keuangan memberi skor 0-100 dari tingkat tabungan, dana darurat, disiplin anggaran, dan beban hutang, plus saran langkah paling berdampak.',
    'Analisis > Wawasan menunjukkan pola belanja per hari, perubahan per kategori, dan pengeluaran terbesar.',
  ]),
  _Topic(Icons.backup_outlined, 'Cadangan data', [
    'Pengaturan > Cadangkan data membuat file cadangan. Isi kata sandi agar terenkripsi (disarankan), lalu simpan file itu di luar HP, misalnya Google Drive.',
    'Pengaturan > Cadangan otomatis membuat cadangan terenkripsi berkala di HP. Bagikan berkasnya ke Drive secara rutin, karena cadangan di HP ikut hilang bila aplikasi dicopot.',
    'Pindah HP: pasang Tertata di HP baru, lalu Pulihkan data dengan file cadangan dan kata sandinya. Kata sandi tidak bisa dipulihkan bila lupa.',
  ]),
  _Topic(Icons.lock_outline, 'PIN dan keamanan', [
    'Atur PIN 6 digit dan biometrik di Pengaturan > Keamanan. Salah PIN berulang membuat aplikasi terkunci sementara.',
    'Blokir tangkapan layar (Pengaturan, Android) menyembunyikan isi aplikasi dari foto layar dan tampilan aplikasi terbaru.',
    'Lupa PIN menghapus semua data, PIN, riwayat chat, dan kunci API di HP ini. Pulihkan dari cadangan setelahnya.',
  ]),
  _Topic(Icons.auto_awesome_outlined, 'Asisten AI (opsional)', [
    'Aktif setelah Anda memasukkan kunci API milik sendiri dan menyetujui pengiriman data di Pengaturan AI. Google Gemini punya paket gratis dan bisa memindai struk.',
    'Saat dipakai, pertanyaan dan data yang relevan dikirim langsung dari HP ke penyedia AI pilihan Anda. Cabut persetujuan kapan saja di Pengaturan AI.',
  ]),
  _Topic(Icons.system_update_alt, 'Pembaruan dan masalah', [
    'Aplikasi memeriksa versi baru sekali sehari ke GitHub (bisa dimatikan). Bila ada, muncul spanduk di Lainnya dengan tombol Unduh.',
    'Bila aplikasi bermasalah, lihat Pengaturan > Laporan masalah. Catatan error hanya ada di HP, dan Anda yang memutuskan membagikannya.',
  ]),
];

class GuidePage extends StatelessWidget {
  const GuidePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Panduan')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          AppCard(
            child: Text(
              'Ringkasan cara memakai Tertata. Ketuk topik untuk membukanya.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
          for (final t in _topics)
            AppCard(
              padding: EdgeInsets.zero,
              child: Theme(
                data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                child: ExpansionTile(
                  leading: Icon(t.icon, color: Theme.of(context).colorScheme.primary),
                  title: Text(t.title, style: const TextStyle(fontWeight: FontWeight.w600)),
                  childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                  expandedCrossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final l in t.lines)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          const Padding(padding: EdgeInsets.only(top: 7, right: 10), child: Icon(Icons.circle, size: 5)),
                          Expanded(child: Text(l)),
                        ]),
                      ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
