import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';

import '../models/jadwal_model.dart';
import '../models/realisasi_model.dart';

// ─── Warna korporat ────────────────────────────────────────────────────────
class _C {
  static const primary    = PdfColor.fromInt(0xFF0D3B6E);
  static const accent     = PdfColor.fromInt(0xFF1976D2);
  static const accentBg   = PdfColor.fromInt(0xFFE3F2FD);
  static const good       = PdfColor.fromInt(0xFF1B5E20);
  static const goodBg     = PdfColor.fromInt(0xFFE8F5E9);
  static const warn       = PdfColor.fromInt(0xFFE65100);
  static const warnBg     = PdfColor.fromInt(0xFFFFF3E0);
  static const bad        = PdfColor.fromInt(0xFFB71C1C);
  static const badBg      = PdfColor.fromInt(0xFFFFEBEE);
  static const textDark   = PdfColor.fromInt(0xFF212121);
  static const textMid    = PdfColor.fromInt(0xFF616161);
  static const textLight  = PdfColor.fromInt(0xFF9E9E9E);
  static const borderLight= PdfColor.fromInt(0xFFE0E0E0);
  static const bgAlt      = PdfColor.fromInt(0xFFF5F5F5);
  static const white      = PdfColors.white;
  static const amber      = PdfColor.fromInt(0xFFFF8F00);
  static const amberBg    = PdfColor.fromInt(0xFFFFF8E1);
}

// ─── Service ────────────────────────────────────────────────────────────────
class PdfReportService {
  static Future<Uint8List> generateRealisasiPdf({
    required String divisiFilter,
    String? pelaksanaFilter,
    required int month,
    required int year,
    required List<RealisasiModel> realisasiList,
    required List<JadwalModel> jadwalList,
  }) async {
    final pdf = pw.Document(
      title: 'Laporan Realisasi Maintenance',
      author: 'PlanKP | CV. Kencana Print',
    );

    // Muat logo
    Uint8List? logoBytes;
    try {
      final d = await rootBundle.load('assets/images/logo.png');
      logoBytes = d.buffer.asUint8List();
    } catch (_) {}
    final logoImage = logoBytes != null ? pw.MemoryImage(logoBytes) : null;

    final selectedPelaksana = (pelaksanaFilter ?? 'Semua Pelaksana').trim();

    // ── Filter realisasi ─────────────────────────────────────────────────────
    final filteredRealisasi = realisasiList.where((r) {
      final tgl = DateTime.tryParse(r.realTgl);
      if (tgl == null || tgl.year != year || tgl.month != month) return false;

      if (divisiFilter != 'Semua Divisi') {
        final jdwDiv = (r.jadwal?['jdw_divisi'] ?? '').toString().trim().toUpperCase();
        if (jdwDiv.isNotEmpty && jdwDiv != divisiFilter.trim().toUpperCase()) return false;
      }

      if (selectedPelaksana != 'Semua Pelaksana' && selectedPelaksana.isNotEmpty) {
        final nama = (r.teknisi?['user_nama'] ?? r.realTtdPicNama ?? '')
            .toString().trim().toLowerCase();
        if (!nama.contains(selectedPelaksana.toLowerCase())) return false;
      }

      return true;
    }).toList()
      ..sort((a, b) => b.realTgl.compareTo(a.realTgl));

    // ── Hitung statistik target (selaras dengan rumus sistem) ────────────────
    int totalTargetUnit = 0;
    final monthStart = DateTime(year, month, 1);
    final monthEnd = DateTime(year, month + 1, 0);

    final realisasiJadwalIds = filteredRealisasi.map((r) => r.realJadwalId).toSet();

    for (final j in jadwalList) {
      if (j.jdwStatus != 'Draft') continue;

      if (divisiFilter != 'Semua Divisi') {
        if (j.jdwDivisi.trim().toUpperCase() != divisiFilter.trim().toUpperCase()) {
          continue;
        }
      }

      // Filter Rentang Keaktifan Jadwal (jdwTglMulai & jdwTglSelesai) terhadap bulan laporan
      final tglMulai = DateTime.tryParse(j.jdwTglMulai);
      if (tglMulai != null && tglMulai.isAfter(monthEnd)) {
        continue; // Belum berjalan di bulan ini
      }
      if (j.jdwTglSelesai != null && j.jdwTglSelesai!.isNotEmpty) {
        final tglSelesai = DateTime.tryParse(j.jdwTglSelesai!);
        if (tglSelesai != null && tglSelesai.isBefore(monthStart)) {
          continue; // Sudah selesai sebelum bulan ini
        }
      }

      // Filter Pelaksana jika spesifik dipilih
      if (selectedPelaksana != 'Semua Pelaksana' && selectedPelaksana.isNotEmpty) {
        final assignedNama = (j.assignedUser?['user_nama'] ?? '').toString().trim().toLowerCase();
        final matchAssigned = assignedNama.isNotEmpty && assignedNama.contains(selectedPelaksana.toLowerCase());
        final matchRealisasi = realisasiJadwalIds.contains(j.jdwId);

        if (!matchAssigned && !matchRealisasi) {
          continue;
        }
      }

      final perTarget = (j.jdwTarget ?? 0) > 0
          ? (j.jdwTarget ?? 0)
          : ((j.jdwTotalUnit ?? 0) > 0 ? (j.jdwTotalUnit ?? 0) : 1);
      final appearances = _calculateScheduleAppearancesInMonth(j, monthStart, monthEnd);

      totalTargetUnit += (appearances * perTarget);
    }

    final totalRealisasi = filteredRealisasi.length;
    final targetVal = totalTargetUnit > 0 ? totalTargetUnit : (totalRealisasi > 0 ? totalRealisasi : 1);
    final percentage = ((totalRealisasi / targetVal) * 100).round().clamp(0, 100);

    int countBaik = 0, countPerluCek = 0, countRusak = 0;
    final temuanList = <RealisasiModel>[];

    for (final r in filteredRealisasi) {
      final k = (r.realKondisiAkhir ?? 'Baik').trim().toLowerCase();
      if (k == 'rusak') {
        countRusak++;
        temuanList.add(r);
      } else if (k.contains('perhatian') || k.contains('cek') || k.contains('perlu')) {
        countPerluCek++;
        temuanList.add(r);
      } else {
        countBaik++;
      }
    }

    // ── String meta ──────────────────────────────────────────────────────────
    final periodeStr   = '${_bulan(month)} $year';
    final printStr     = DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now());
    final pctColor     = percentage >= 80 ? _C.good : (percentage >= 50 ? _C.warn : _C.bad);
    final pctBg        = percentage >= 80 ? _C.goodBg : (percentage >= 50 ? _C.warnBg : _C.badBg);

    // ════════════════════════════════════════════════════════════════════════
    //  SATU HALAMAN A4
    // ════════════════════════════════════════════════════════════════════════
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(28, 20, 28, 20),
        header: (_) => _header(
          logoImage: logoImage,
          periodeStr: periodeStr,
          divisiFilter: divisiFilter,
          pelaksanaFilter: selectedPelaksana,
          printStr: printStr,
        ),
        footer: (ctx) => _footer(ctx),
        build: (_) => [
          pw.SizedBox(height: 8),

          // ── RINGKASAN ─────────────────────────────────────────────────────
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: pw.BoxDecoration(
              color: _C.bgAlt,
              border: pw.Border.all(color: _C.borderLight, width: 0.7),
              borderRadius: pw.BorderRadius.circular(5),
            ),
            child: pw.Row(
              children: [
                // Persentase
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: pw.BoxDecoration(
                    color: pctBg,
                    border: pw.Border.all(color: pctColor, width: 0.7),
                    borderRadius: pw.BorderRadius.circular(5),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.center,
                    children: [
                      pw.Text('$percentage%',
                          style: pw.TextStyle(
                              fontSize: 22, fontWeight: pw.FontWeight.bold, color: pctColor)),
                      pw.Text('Capaian',
                          style: pw.TextStyle(fontSize: 6.5, color: pctColor)),
                    ],
                  ),
                ),
                pw.SizedBox(width: 10),

                // Teks ringkas
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'Realisasi: $totalRealisasi Unit  |  Target: $targetVal Unit',
                        style: pw.TextStyle(
                            fontSize: 8.5, fontWeight: pw.FontWeight.bold, color: _C.textDark),
                      ),
                      pw.SizedBox(height: 3),
                      pw.Text(
                        'Divisi: $divisiFilter  |  Periode: $periodeStr',
                        style: const pw.TextStyle(fontSize: 7.5, color: _C.textMid),
                      ),
                    ],
                  ),
                ),

                pw.SizedBox(width: 8),

                // 3 pill kondisi
                _pill('Baik', countBaik, _C.good, _C.goodBg),
                pw.SizedBox(width: 5),
                _pill('Perlu Cek', countPerluCek, _C.warn, _C.warnBg),
                pw.SizedBox(width: 5),
                _pill('Rusak', countRusak, _C.bad, _C.badBg),
              ],
            ),
          ),

          pw.SizedBox(height: 8),

          // ── TEMUAN (hanya jika ada) ───────────────────────────────────────
          if (temuanList.isNotEmpty) ...[
            _sectionLabel('Temuan Unit Perlu Tindak Lanjut'),
            pw.SizedBox(height: 4),
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: pw.BoxDecoration(
                color: _C.amberBg,
                border: pw.Border.all(color: _C.amber, width: 0.6),
                borderRadius: pw.BorderRadius.circular(4),
              ),
              child: pw.Column(
                children: temuanList.take(5).toList().asMap().entries.map((e) {
                  final r = e.value;
                  final rawNamaInv = (r.inventaris?['inv_nama'] ?? 'Inv #${r.realInvId}').toString().trim();
                  final jenisNama = (r.inventaris?['jenis']?['jenis_nama'] ?? r.inventaris?['inv_jenis']?['jenis_nama'] ?? '').toString().trim();
                  String invNama = rawNamaInv;
                  if (jenisNama.isNotEmpty && rawNamaInv.isNotEmpty) {
                    if (!rawNamaInv.toLowerCase().startsWith(jenisNama.toLowerCase())) {
                      invNama = '$jenisNama $rawNamaInv';
                    }
                  } else if (jenisNama.isNotEmpty) {
                    invNama = jenisNama;
                  }

                  final kode = (r.inventaris?['inv_pabrik_kode'] ?? '-').toString();
                  final kondisi = r.realKondisiAkhir ?? 'Perlu Perhatian';
                  final catatan = (r.realKeterangan ?? '-').trim();
                  final k = kondisi.trim().toLowerCase();
                  final colorKondisi = k == 'baik'
                      ? _C.good
                      : (k == 'rusak' ? _C.bad : _C.warn);

                  return pw.Padding(
                    padding: const pw.EdgeInsets.only(bottom: 2),
                    child: pw.Row(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('${e.key + 1}. ',
                            style: pw.TextStyle(
                                fontSize: 7.5,
                                fontWeight: pw.FontWeight.bold,
                                color: _C.amber)),
                        pw.Expanded(
                          child: pw.RichText(
                            text: pw.TextSpan(
                              style: const pw.TextStyle(fontSize: 7.5, color: _C.textDark),
                              children: [
                                pw.TextSpan(text: '$invNama ($kode) ',
                                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                                pw.TextSpan(
                                    text: '[$kondisi] ',
                                    style: pw.TextStyle(
                                        fontWeight: pw.FontWeight.bold,
                                        color: colorKondisi)),
                                pw.TextSpan(text: catatan),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
            pw.SizedBox(height: 8),
          ],

          // ── TABEL DETAIL ──────────────────────────────────────────────────
          _sectionLabel(
              'Detail Hasil Pelaksanaan Maintenance  (${filteredRealisasi.length} Data)'),
          pw.SizedBox(height: 4),
          _detailTable(filteredRealisasi),
        ],
      ),
    );

    return pdf.save();
  }

  // ── HEADER ──────────────────────────────────────────────────────────────
  static pw.Widget _header({
    pw.MemoryImage? logoImage,
    required String periodeStr,
    required String divisiFilter,
    required String pelaksanaFilter,
    required String printStr,
  }) {
    return pw.Column(
      children: [
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: [
            // Logo
            if (logoImage != null)
              pw.Container(
                width: 44, height: 44,
                margin: const pw.EdgeInsets.only(right: 8),
                child: pw.Image(logoImage, fit: pw.BoxFit.contain),
              ),

            // Nama & judul
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('CV. KENCANA PRINT',
                      style: pw.TextStyle(
                          fontSize: 12, fontWeight: pw.FontWeight.bold, color: _C.primary)),
                  pw.Text('Aplikasi Mobile PlanKP | Sistem Penjadwalan Maintenance Kencana Print',
                      style: const pw.TextStyle(fontSize: 7.5, color: _C.textMid)),
                  pw.Text('LAPORAN HASIL REALISASI MAINTENANCE',
                      style: pw.TextStyle(
                          fontSize: 9, fontWeight: pw.FontWeight.bold, color: _C.textDark)),
                ],
              ),
            ),

            // Tanggal & Jam Cetak di Kanan
            pw.Text(
              'Dicetak: $printStr',
              style: const pw.TextStyle(fontSize: 7.5, color: _C.textMid),
            ),
          ],
        ),
        pw.SizedBox(height: 5),
        pw.Container(height: 1.5, color: _C.primary),
        pw.SizedBox(height: 3),
      ],
    );
  }

  // ── FOOTER ──────────────────────────────────────────────────────────────
  static pw.Widget _footer(pw.Context ctx) => pw.Container(
        margin: const pw.EdgeInsets.only(top: 5),
        padding: const pw.EdgeInsets.only(top: 4),
        decoration: const pw.BoxDecoration(
          border: pw.Border(top: pw.BorderSide(color: _C.borderLight, width: 0.5)),
        ),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text('CV. Kencana Print | Aplikasi Mobile PlanKP',
                style: const pw.TextStyle(fontSize: 6.5, color: _C.textLight)),
            pw.Text('Halaman ${ctx.pageNumber} dari ${ctx.pagesCount}',
                style: pw.TextStyle(
                    fontSize: 7, fontWeight: pw.FontWeight.bold, color: _C.primary)),
          ],
        ),
      );

  // ── PILL KONDISI ─────────────────────────────────────────────────────────
  static pw.Widget _pill(String label, int val, PdfColor color, PdfColor bg) =>
      pw.Container(
        padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: pw.BoxDecoration(
          color: bg,
          border: pw.Border.all(color: color, width: 0.5),
          borderRadius: pw.BorderRadius.circular(4),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: [
            pw.Text('$val',
                style: pw.TextStyle(
                    fontSize: 11, fontWeight: pw.FontWeight.bold, color: color)),
            pw.Text(label, style: pw.TextStyle(fontSize: 6.5, color: color)),
          ],
        ),
      );

  // ── LABEL SEKSI ──────────────────────────────────────────────────────────
  static pw.Widget _sectionLabel(String text) => pw.Text(
        text,
        style: pw.TextStyle(
            fontSize: 8.5, fontWeight: pw.FontWeight.bold, color: _C.primary),
      );

  // ── TABEL DETAIL ─────────────────────────────────────────────────────────
  static pw.Widget _detailTable(List<RealisasiModel> list) {
    if (list.isEmpty) {
      return pw.Container(
        padding: const pw.EdgeInsets.symmetric(vertical: 18),
        decoration: pw.BoxDecoration(
            border: pw.Border.all(color: _C.borderLight),
            borderRadius: pw.BorderRadius.circular(4)),
        child: pw.Center(
          child: pw.Text(
            'Tidak ada data realisasi selesai untuk kriteria filter ini.',
            style: const pw.TextStyle(fontSize: 8, color: _C.textMid),
          ),
        ),
      );
    }

    const headers = [
      'No', 'Tgl Realisasi', 'Nama Inventaris', 'Lokasi',
      'Kondisi', 'Pelaksana', 'Catatan',
    ];

    return pw.Table(
      border: pw.TableBorder.all(color: _C.borderLight, width: 0.5),
      columnWidths: const {
        0: pw.FixedColumnWidth(18),   // No
        1: pw.FixedColumnWidth(60),   // Tanggal
        2: pw.FlexColumnWidth(2.0),   // Nama Inventaris
        3: pw.FixedColumnWidth(36),   // Lokasi
        4: pw.FixedColumnWidth(48),   // Kondisi
        5: pw.FlexColumnWidth(1.4),   // Pelaksana
        6: pw.FlexColumnWidth(4.5),   // Catatan (Ekstra Luas)
      },
      children: [
        // Header Row
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: _C.primary),
          children: headers.map((h) {
            return pw.Container(
              padding: const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 4),
              alignment: pw.Alignment.center,
              child: pw.Text(
                h,
                style: pw.TextStyle(
                  fontSize: 7.5,
                  fontWeight: pw.FontWeight.bold,
                  color: _C.white,
                ),
              ),
            );
          }).toList(),
        ),

        // Data Rows
        ...list.asMap().entries.map((entry) {
          final i = entry.key;
          final r = entry.value;
          final tgl = r.realTgl.isNotEmpty
              ? DateFormat('dd/MM/yyyy').format(DateTime.tryParse(r.realTgl) ?? DateTime.now())
              : '-';

          final rawNamaInv = (r.inventaris?['inv_nama'] ?? 'Inv #${r.realInvId}').toString().trim();
          final jenisNama = (r.inventaris?['jenis']?['jenis_nama'] ?? r.inventaris?['inv_jenis']?['jenis_nama'] ?? '').toString().trim();
          String invNama = rawNamaInv;
          if (jenisNama.isNotEmpty && rawNamaInv.isNotEmpty) {
            if (!rawNamaInv.toLowerCase().startsWith(jenisNama.toLowerCase())) {
              invNama = '$jenisNama $rawNamaInv';
            }
          } else if (jenisNama.isNotEmpty) {
            invNama = jenisNama;
          }

          final lokasi  = (r.inventaris?['inv_pabrik_kode'] ?? '-').toString();
          final kondisi = r.realKondisiAkhir ?? 'Baik';
          final teknisi = (r.teknisi?['user_nama'] ?? r.realTtdPicNama ?? '-').toString();
          final catatan = (r.realKeterangan ?? '-').trim();

          final k = kondisi.trim().toLowerCase();
          PdfColor colorKondisi = _C.textDark;
          if (k == 'baik') {
            colorKondisi = _C.good;
          } else if (k == 'rusak') {
            colorKondisi = _C.bad;
          } else if (k.contains('perhatian') || k.contains('cek') || k.contains('perlu')) {
            colorKondisi = _C.warn;
          }

          final bg = i % 2 == 0 ? _C.white : _C.bgAlt;

          return pw.TableRow(
            decoration: pw.BoxDecoration(color: bg),
            children: [
              // 0. No
              pw.Container(
                padding: const pw.EdgeInsets.all(4),
                alignment: pw.Alignment.center,
                child: pw.Text('${i + 1}', style: const pw.TextStyle(fontSize: 7.5, color: _C.textDark)),
              ),
              // 1. Tanggal
              pw.Container(
                padding: const pw.EdgeInsets.all(4),
                alignment: pw.Alignment.center,
                child: pw.Text(tgl, style: const pw.TextStyle(fontSize: 7.5, color: _C.textDark)),
              ),
              // 2. Nama Inventaris
              pw.Container(
                padding: const pw.EdgeInsets.all(4),
                alignment: pw.Alignment.centerLeft,
                child: pw.Text(invNama, style: const pw.TextStyle(fontSize: 7.5, color: _C.textDark)),
              ),
              // 3. Lokasi
              pw.Container(
                padding: const pw.EdgeInsets.all(4),
                alignment: pw.Alignment.center,
                child: pw.Text(lokasi, style: const pw.TextStyle(fontSize: 7.5, color: _C.textDark)),
              ),
              // 4. Kondisi (BERWARNA sesuai kondisi: Baik = Hijau, Perlu Perhatian = Orange, Rusak = Merah)
              pw.Container(
                padding: const pw.EdgeInsets.all(4),
                alignment: pw.Alignment.center,
                child: pw.Text(
                  kondisi,
                  style: pw.TextStyle(
                    fontSize: 7.5,
                    fontWeight: pw.FontWeight.bold,
                    color: colorKondisi,
                  ),
                ),
              ),
              // 5. Pelaksana
              pw.Container(
                padding: const pw.EdgeInsets.all(4),
                alignment: pw.Alignment.centerLeft,
                child: pw.Text(teknisi, style: const pw.TextStyle(fontSize: 7.5, color: _C.textDark)),
              ),
              // 6. Catatan
              pw.Container(
                padding: const pw.EdgeInsets.all(4),
                alignment: pw.Alignment.centerLeft,
                child: pw.Text(catatan.isEmpty ? '-' : catatan, style: const pw.TextStyle(fontSize: 7.5, color: _C.textDark)),
              ),
            ],
          );
        }),
      ],
    );
  }

  // ── HELPER ───────────────────────────────────────────────────────────────
  static String _bulan(int m) {
    const n = [
      'Januari','Februari','Maret','April','Mei','Juni',
      'Juli','Agustus','September','Oktober','November','Desember',
    ];
    return n[(m - 1).clamp(0, 11)];
  }

  static const List<String> _divisiSixDays = [
    'GA',
    'TEKNISI',
    'MAINTENANCE',
    'PRODUKSI',
    'WORKSHOP'
  ];

  static bool _isWorkingDay(DateTime date, String? divisi) {
    if (date.weekday == DateTime.sunday) return false;
    if (date.weekday == DateTime.saturday) {
      final norm = (divisi ?? '').trim().toUpperCase();
      return _divisiSixDays.any((d) => d.toUpperCase() == norm);
    }
    return true;
  }

  static DateTime? _findNextWorkingDay(DateTime date, DateTime limit, String? divisi) {
    var d = date;
    while (!_isWorkingDay(d, divisi)) {
      d = d.add(const Duration(days: 1));
      if (d.isAfter(limit)) return null;
    }
    return d;
  }

  static int _calculateScheduleAppearancesInMonth(
    JadwalModel j,
    DateTime start,
    DateTime end,
  ) {
    final jStart = DateTime.tryParse(j.jdwTglMulai);
    if (jStart == null) return 1;
    final rangeStart = jStart.isAfter(start) ? jStart : start;
    final jEndStr = j.jdwTglSelesai;
    final jEnd = (jEndStr == null || jEndStr.isEmpty)
        ? end
        : (DateTime.tryParse(jEndStr) ?? end);
    final rangeEnd = jEnd.isBefore(end) ? jEnd : end;

    if (rangeEnd.isBefore(rangeStart)) return 0;
    int appearances = 0;
    final divisi = j.jdwDivisi;
    final frekuensi = j.jdwFrekuensi.trim().toLowerCase();

    if (frekuensi == 'harian') {
      for (var d = rangeStart;
          !d.isAfter(rangeEnd);
          d = d.add(const Duration(days: 1))) {
        if (_isWorkingDay(d, divisi)) appearances++;
      }
      return appearances;
    } else if (frekuensi == 'mingguan') {
      var curr = jStart;
      while (!curr.isAfter(rangeEnd)) {
        if (!curr.isBefore(rangeStart)) {
          final nextWork = _findNextWorkingDay(curr, rangeEnd, divisi);
          if (nextWork != null) {
            appearances++;
          }
        }
        curr = curr.add(const Duration(days: 7));
      }
      return appearances;
    } else if (frekuensi == 'bulanan') {
      final nextWork = _findNextWorkingDay(rangeStart, rangeEnd, divisi);
      if (nextWork != null) {
        appearances = 1;
      }
      return appearances;
    }

    return 1;
  }
}
