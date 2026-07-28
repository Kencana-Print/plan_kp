import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';

import '../models/jadwal_model.dart';
import '../models/realisasi_model.dart';

class PdfReportService {
  static Future<Uint8List> generateRealisasiPdf({
    required String divisiFilter,
    required int month,
    required int year,
    required List<RealisasiModel> realisasiList,
    required List<JadwalModel> jadwalList,
  }) async {
    final pdf = pw.Document();

    // 1. Load Logo Image Asset
    Uint8List? logoBytes;
    try {
      final logoData = await rootBundle.load('assets/images/logo.png');
      logoBytes = logoData.buffer.asUint8List();
    } catch (_) {}

    final logoImage = logoBytes != null ? pw.MemoryImage(logoBytes) : null;

    // 2. Filter Realisasi berdasarkan status 'Selesai', bulan, tahun, & divisi
    final filteredRealisasi = realisasiList.where((r) {
      if (r.realStatus != 'Selesai') return false;
      final tgl = DateTime.tryParse(r.realTgl);
      if (tgl == null) return false;
      if (tgl.year != year || tgl.month != month) return false;

      if (divisiFilter != 'Semua Divisi') {
        final jdwDiv = (r.jadwal?['jdw_divisi'] ?? '').toString().trim().toUpperCase();
        final filterDiv = divisiFilter.trim().toUpperCase();
        if (jdwDiv.isNotEmpty && jdwDiv != filterDiv) return false;
      }
      return true;
    }).toList();

    // Sortir urut tanggal realisasi terbaru
    filteredRealisasi.sort((a, b) => b.realTgl.compareTo(a.realTgl));

    // Filter Jadwal untuk menghitung Total Target Unit
    final filteredJadwal = jadwalList.where((j) {
      if (divisiFilter != 'Semua Divisi') {
        if (j.jdwDivisi.trim().toUpperCase() != divisiFilter.trim().toUpperCase()) {
          return false;
        }
      }
      return true;
    }).toList();

    // 3. Agregasi Statistik & Metrik
    int totalTargetUnit = 0;
    for (final j in filteredJadwal) {
      totalTargetUnit += (j.jdwTarget ?? j.jdwTotalUnit ?? 1);
    }

    final totalRealisasi = filteredRealisasi.length;
    final targetVal = totalTargetUnit > 0 ? totalTargetUnit : (totalRealisasi > 0 ? totalRealisasi : 1);
    final percentage = ((totalRealisasi / targetVal) * 100).round().clamp(0, 100);

    // Breakdown Kondisi Inventaris
    int countBaik = 0;
    int countPerluCek = 0;
    int countRusak = 0;
    final List<RealisasiModel> temuanList = [];

    for (final r in filteredRealisasi) {
      final kondisi = (r.realKondisiAkhir ?? 'Baik').trim().toLowerCase();
      if (kondisi == 'rusak') {
        countRusak++;
        temuanList.add(r);
      } else if (kondisi.contains('perhatian') || kondisi.contains('cek') || kondisi.contains('perlu')) {
        countPerluCek++;
        temuanList.add(r);
      } else {
        countBaik++;
      }
    }

    final monthNames = [
      'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
      'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember'
    ];
    final periodeStr = '${monthNames[month - 1]} $year';
    final printDateStr = DateFormat('dd MMMM yyyy', 'id_ID').format(DateTime.now());

    // 4. Build PDF Pages
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        header: (context) => _buildKopSuratHeader(
          logoImage: logoImage,
          divisiFilter: divisiFilter,
          periodeStr: periodeStr,
          printDateStr: printDateStr,
        ),
        footer: (context) => _buildFooter(context),
        build: (context) => [
          pw.SizedBox(height: 12),

          // ── 1. RINGKASAN METRIK & CAPAIAN (%) ──────────────────
          _buildSummarySection(
            percentage: percentage,
            totalRealisasi: totalRealisasi,
            totalTarget: targetVal,
            countBaik: countBaik,
            countPerluCek: countPerluCek,
            countRusak: countRusak,
          ),
          pw.SizedBox(height: 14),

          // ── 2. SEKSI TEMUAN KHUSUS (RUSAK / PERLU PERHATIAN) ────
          if (temuanList.isNotEmpty) ...[
            _buildTemuanSection(temuanList),
            pw.SizedBox(height: 14),
          ],

          // ── 3. TABEL DETAIL REALISASI MAINTENANCE ──────────────
          pw.Text(
            'Detail Hasil Pemeliharaan Maintenance (${filteredRealisasi.length} Realisasi Unit)',
            style: const pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: PdfColors.blueGrey900),
          ),
          pw.SizedBox(height: 6),
          _buildDetailTable(filteredRealisasi),

          pw.SizedBox(height: 20),

          // ── 4. COLOM TANDA TANGAN / PENGESAHAN ─────────────────
          _buildSignatureSection(),
        ],
      ),
    );

    return pdf.save();
  }

  // ── KOP SURAT HEADER ──────────────────────────────────────────────
  static pw.Widget _buildKopSuratHeader({
    pw.MemoryImage? logoImage,
    required String divisiFilter,
    required String periodeStr,
    required String printDateStr,
  }) {
    return pw.Column(
      children: [
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: [
            if (logoImage != null)
              pw.Container(
                width: 55,
                height: 55,
                margin: const pw.EdgeInsets.only(right: 12),
                child: pw.Image(logoImage, fit: pw.BoxFit.contain),
              ),
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'PT. KENCANA PRINT',
                    style: const pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900),
                  ),
                  pw.SizedBox(height: 2),
                  pw.Text(
                    'Sistem Penjadwalan & Pemeliharaan Infrastruktur (PlanKP)',
                    style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
                  ),
                  pw.Text(
                    'LAPORAN RESMI REALISASI MAINTENANCE',
                    style: const pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: PdfColors.black),
                  ),
                ],
              ),
            ),
          ],
        ),
        pw.SizedBox(height: 6),
        pw.Divider(thickness: 1.5, color: PdfColors.blue900),
        pw.SizedBox(height: 4),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.RichText(
              text: pw.TextSpan(
                style: const pw.TextStyle(fontSize: 9, color: PdfColors.black),
                children: [
                  const pw.TextSpan(text: 'Divisi Target: '),
                  pw.TextSpan(text: divisiFilter, style: const pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                  const pw.TextSpan(text: '  |  Periode: '),
                  pw.TextSpan(text: periodeStr, style: const pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                ],
              ),
            ),
            pw.Text(
              'Tgl Cetak: $printDateStr',
              style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
            ),
          ],
        ),
        pw.SizedBox(height: 6),
      ],
    );
  }

  // ── METRIK RINGKASAN KINERJA & CAPAIAN (%) ─────────────────────────
  static pw.Widget _buildSummarySection({
    required int percentage,
    required int totalRealisasi,
    required int totalTarget,
    required int countBaik,
    required int countPerluCek,
    required int countRusak,
  }) {
    final pctColor = percentage >= 80
        ? PdfColors.green800
        : (percentage >= 50 ? PdfColors.orange800 : PdfColors.red800);

    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey100,
        borderRadius: pw.BorderRadius.circular(6),
        border: pw.Border.all(color: PdfColors.grey300),
      ),
      child: pw.Row(
        children: [
          // Capaian Persentase Box
          pw.Expanded(
            flex: 2,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('Persentase Capaian Realisasi', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
                pw.SizedBox(height: 2),
                pw.Row(
                  children: [
                    pw.Text(
                      '$percentage%',
                      style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: pctColor),
                    ),
                    pw.SizedBox(width: 8),
                    pw.Text(
                      '($totalRealisasi dari $totalTarget unit target)',
                      style: const pw.TextStyle(fontSize: 9, color: PdfColors.black),
                    ),
                  ],
                ),
              ],
            ),
          ),
          pw.Container(height: 30, width: 1, color: PdfColors.grey300),
          pw.SizedBox(width: 12),
          // Breakdown Kondisi Unit
          pw.Expanded(
            flex: 3,
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
              children: [
                _metricPill('Baik', countBaik, PdfColors.green800, PdfColors.green50),
                _metricPill('Perlu Cek', countPerluCek, PdfColors.orange800, PdfColors.orange50),
                _metricPill('Rusak', countRusak, PdfColors.red800, PdfColors.red50),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _metricPill(String label, int val, PdfColor textColor, PdfColor bgColor) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: pw.BoxDecoration(
        color: bgColor,
        borderRadius: pw.BorderRadius.circular(4),
        border: pw.Border.all(color: textColor, width: 0.5),
      ),
      child: pw.Column(
        children: [
          pw.Text('$val Unit', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: textColor)),
          pw.Text(label, style: pw.TextStyle(fontSize: 7, color: textColor)),
        ],
      ),
    );
  }

  // ── SEKSI TEMUAN KHUSUS (RUSAK / PERLU PERHATIAN) ─────────────────
  static pw.Widget _buildTemuanSection(List<RealisasiModel> temuanList) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(8),
      decoration: pw.BoxDecoration(
        color: PdfColors.amber50,
        borderRadius: pw.BorderRadius.circular(6),
        border: pw.Border.all(color: PdfColors.amber400, width: 0.8),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            children: [
              pw.Text(
                '⚠️ HIGHLIGHT TEMUAN MAINTENANCE (${temuanList.length} Unit Perlu Tindakan)',
                style: const pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.amber900),
              ),
            ],
          ),
          pw.SizedBox(height: 6),
          ...temuanList.take(5).map((r) {
            final invNama = (r.inventaris?['inv_nama'] ?? 'Inventaris #${r.realInvId}').toString();
            final pabrik = (r.inventaris?['inv_pabrik_kode'] ?? '-').toString();
            final kondisi = r.realKondisiAkhir ?? 'Perlu Perhatian';
            final catatan = (r.realKeterangan ?? 'Tidak ada catatan').trim();

            return pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 3),
              child: pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('• ', style: const pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.amber900)),
                  pw.Expanded(
                    child: pw.RichText(
                      text: pw.TextSpan(
                        style: const pw.TextStyle(fontSize: 8, color: PdfColors.black),
                        children: [
                          pw.TextSpan(text: '$invNama ($pabrik) - ', style: const pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                          pw.TextSpan(text: 'Kondisi: $kondisi. ', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: kondisi.toLowerCase() == 'rusak' ? PdfColors.red800 : PdfColors.orange800)),
                          pw.TextSpan(text: 'Catatan: $catatan'),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  // ── TABEL DETAIL REALISASI ────────────────────────────────────────
  static pw.Widget _buildDetailTable(List<RealisasiModel> list) {
    if (list.isEmpty) {
      return pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 20),
        child: pw.Center(
          child: pw.Text('Tidak ada data realisasi selesai untuk periode ini.', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
        ),
      );
    }

    final headers = ['No', 'Tgl Realisasi', 'Nama Inventaris', 'Lokasi', 'Kondisi', 'Pelaksana', 'Catatan Temuan'];

    final data = List.generate(list.length, (i) {
      final r = list[i];
      final tglStr = r.realTgl.isNotEmpty ? DateFormat('dd/MM/yyyy').format(DateTime.tryParse(r.realTgl) ?? DateTime.now()) : '-';
      final invNama = (r.inventaris?['inv_nama'] ?? 'Inv #${r.realInvId}').toString();
      final pabrik = (r.inventaris?['inv_pabrik_kode'] ?? '-').toString();
      final kondisi = r.realKondisiAkhir ?? 'Baik';
      final teknisi = (r.teknisi?['user_nama'] ?? r.realTtdPicNama ?? 'Teknisi').toString();
      final catatan = (r.realKeterangan ?? '-').trim();

      return [
        '${i + 1}',
        tglStr,
        invNama,
        pabrik,
        kondisi,
        teknisi,
        catatan.isEmpty ? '-' : catatan,
      ];
    });

    return pw.TableHelper.fromTextArray(
      headers: headers,
      data: data,
      border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
      headerStyle: const pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
      headerDecoration: const pw.BoxDecoration(color: PdfColors.blue900),
      cellStyle: const pw.TextStyle(fontSize: 7.5, color: PdfColors.black),
      cellHeight: 20,
      columnWidths: {
        0: const pw.FixedColumnWidth(24),  // No
        1: const pw.FixedColumnWidth(55),  // Tgl
        2: const pw.FlexColumnWidth(2.5),  // Inventaris
        3: const pw.FixedColumnWidth(45),  // Lokasi
        4: const pw.FixedColumnWidth(55),  // Kondisi
        5: const pw.FlexColumnWidth(1.8),  // Pelaksana
        6: const pw.FlexColumnWidth(3.0),  // Catatan
      },
      cellAlignment: pw.Alignment.centerLeft,
      cellAlignments: {
        0: pw.Alignment.center,
        1: pw.Alignment.center,
        3: pw.Alignment.center,
        4: pw.Alignment.center,
      },
    );
  }

  // ── PENGESAHAN & TANDA TANGAN ──────────────────────────────────────
  static pw.Widget _buildSignatureSection() {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: [
            pw.Text('Dibuat Oleh (Pelaksana),', style: const pw.TextStyle(fontSize: 8.5, color: PdfColors.black)),
            pw.SizedBox(height: 35),
            pw.Container(width: 110, height: 0.8, color: PdfColors.black),
            pw.SizedBox(height: 2),
            pw.Text('Teknisi / Staff Maintenance', style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey700)),
          ],
        ),
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: [
            pw.Text('Disetujui Oleh,', style: const pw.TextStyle(fontSize: 8.5, color: PdfColors.black)),
            pw.SizedBox(height: 35),
            pw.Container(width: 110, height: 0.8, color: PdfColors.black),
            pw.SizedBox(height: 2),
            pw.Text('Manager / Supervisor', style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey700)),
          ],
        ),
      ],
    );
  }

  // ── FOOTER PAGE NUMBERING ──────────────────────────────────────────
  static pw.Widget _buildFooter(pw.Context context) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(top: 8),
      padding: const pw.EdgeInsets.only(top: 4),
      decoration: const pw.BoxDecoration(
        border: pw.Border(top: pw.BorderSide(color: PdfColors.grey300, width: 0.5)),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text('PlanKP System - PT. Kencana Print', style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey600)),
          pw.Text('Halaman ${context.pageNumber} dari ${context.pagesCount}', style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey600)),
        ],
      ),
    );
  }
}
