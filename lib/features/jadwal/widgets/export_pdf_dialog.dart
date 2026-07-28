import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_notifier.dart';
import '../models/jadwal_model.dart';
import '../models/realisasi_model.dart';
import '../providers/jadwal_provider.dart';
import '../services/pdf_report_service.dart';

class ExportPdfDialog extends StatefulWidget {
  final List<RealisasiModel> realisasiList;
  final List<JadwalModel> jadwalList;

  const ExportPdfDialog({
    super.key,
    required this.realisasiList,
    required this.jadwalList,
  });

  static Future<void> show(
    BuildContext context, {
    required List<RealisasiModel> realisasiList,
    required List<JadwalModel> jadwalList,
  }) async {
    await AppNotifier.showWarning(
      context,
      'Fitur ini akan rilis di versi selanjutnya. Info lebih lanjut silahkan hubungi divisi IT.',
    );
  }

  @override
  State<ExportPdfDialog> createState() => _ExportPdfDialogState();
}

class _ExportPdfDialogState extends State<ExportPdfDialog> {
  String _selectedDivisi = 'Semua Divisi';
  late int _selectedMonth;
  late int _selectedYear;

  final List<String> _divisiOptions = [
    'Semua Divisi',
    'GA',
    'Teknisi',
    'Driver',
    'IT',
    'Produksi',
    'Workshop',
  ];

  final List<String> _monthNames = [
    'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
    'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember'
  ];

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedMonth = now.month;
    _selectedYear = now.year;
  }

  Future<void> _generateAndPreviewPdf() async {
    final provider = context.read<JadwalProvider>();
    final selectedDivisi = _selectedDivisi;
    final selectedMonth = _selectedMonth;
    final selectedYear = _selectedYear;
    final realisasiList = widget.realisasiList.isNotEmpty
        ? widget.realisasiList
        : provider.realisasiList;
    final jadwalList = widget.jadwalList.isNotEmpty
        ? widget.jadwalList
        : provider.jadwalList;

    Navigator.pop(context); // Tutup dialog filter

    try {
      await Printing.layoutPdf(
        onLayout: (format) async {
          return await PdfReportService.generateRealisasiPdf(
            divisiFilter: selectedDivisi,
            month: selectedMonth,
            year: selectedYear,
            realisasiList: realisasiList,
            jadwalList: jadwalList,
          );
        },
        name:
            'Laporan_Maintenance_${selectedDivisi.replaceAll(" ", "_")}_${_monthNames[selectedMonth - 1]}_$selectedYear.pdf',
      );
    } catch (e) {
      if (mounted) {
        await AppNotifier.showError(context, 'Gagal membuat file PDF: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 420),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.picture_as_pdf_rounded,
                    color: AppColors.primary,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Export Laporan PDF',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Text(
                        'Filter divisi dan periode laporan',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 20),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 16),

            // Dropdown Divisi
            const Text(
              'Pilih Divisi Target',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 6),
            DropdownButtonFormField<String>(
              value: _selectedDivisi,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.business_rounded, size: 18),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
              items: _divisiOptions.map((div) {
                return DropdownMenuItem(
                  value: div,
                  child: Text(div, style: const TextStyle(fontSize: 13)),
                );
              }).toList(),
              onChanged: (val) {
                if (val != null) setState(() => _selectedDivisi = val);
              },
            ),
            const SizedBox(height: 14),

            // Filter Periode (Bulan & Tahun)
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Bulan',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<int>(
                        value: _selectedMonth,
                        decoration: InputDecoration(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        items: List.generate(12, (i) {
                          return DropdownMenuItem(
                            value: i + 1,
                            child: Text(_monthNames[i], style: const TextStyle(fontSize: 12.5)),
                          );
                        }),
                        onChanged: (val) {
                          if (val != null) setState(() => _selectedMonth = val);
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Tahun',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<int>(
                        value: _selectedYear,
                        decoration: InputDecoration(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        items: [2024, 2025, 2026, 2027].map((yr) {
                          return DropdownMenuItem(
                            value: yr,
                            child: Text('$yr', style: const TextStyle(fontSize: 12.5)),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) setState(() => _selectedYear = val);
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Batal'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: ElevatedButton.icon(
                    onPressed: _generateAndPreviewPdf,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                    ),
                    icon: const Icon(Icons.print_rounded, size: 16),
                    label: const Text('Pratinjau PDF'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
