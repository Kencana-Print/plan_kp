import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:printing/printing.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/constants/app_constants.dart';
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
    await showDialog(
      context: context,
      builder: (_) => ExportPdfDialog(
        realisasiList: realisasiList,
        jadwalList: jadwalList,
      ),
    );
  }

  @override
  State<ExportPdfDialog> createState() => _ExportPdfDialogState();
}

class _ExportPdfDialogState extends State<ExportPdfDialog> {
  String _selectedDivisi = 'Semua Divisi';
  String _selectedPelaksana = 'Semua Pelaksana';
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
    'Januari',
    'Februari',
    'Maret',
    'April',
    'Mei',
    'Juni',
    'Juli',
    'Agustus',
    'September',
    'Oktober',
    'November',
    'Desember'
  ];

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedMonth = now.month;
    _selectedYear = now.year;
  }

  List<String> _getPelaksanaOptions(JadwalProvider provider) {
    final list = widget.realisasiList.isNotEmpty
        ? widget.realisasiList
        : provider.realisasiList;
    final setNames = <String>{};
    for (final r in list) {
      final name =
          (r.teknisi?['user_nama'] ?? r.realTtdPicNama ?? '').toString().trim();
      if (name.isNotEmpty) setNames.add(name);
    }
    final sorted = setNames.toList()..sort();
    return ['Semua Pelaksana', ...sorted];
  }

  Future<void> _downloadExcel() async {
    const baseUrl = ApiConfig.baseUrl;

    final queryParams = <String, String>{
      'bulan': '$_selectedMonth',
      'tahun': '$_selectedYear',
    };
    if (_selectedDivisi != 'Semua Divisi') {
      queryParams['divisi'] = _selectedDivisi;
    }
    if (_selectedPelaksana != 'Semua Pelaksana') {
      final provider = context.read<JadwalProvider>();
      final list = widget.realisasiList.isNotEmpty
          ? widget.realisasiList
          : provider.realisasiList;
      for (final r in list) {
        final name = (r.teknisi?['user_nama'] ?? r.realTtdPicNama ?? '').toString().trim();
        if (name == _selectedPelaksana) {
          queryParams['teknisi_id'] = '${r.realTeknisiId}';
          break;
        }
      }
    }

    final queryString = Uri(queryParameters: queryParams).query;
    final downloadUrl = '$baseUrl/realisasi/export-excel?$queryString';

    Navigator.pop(context);

    try {
      final uri = Uri.parse(downloadUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) {
          await AppNotifier.showError(context, 'Tidak dapat membuka tautan unduhan Excel');
        }
      }
    } catch (e) {
      if (mounted) {
        await AppNotifier.showError(context, 'Gagal mengunduh Excel: $e');
      }
    }
  }

  Future<void> _generateAndPreviewPdf() async {
    final provider = context.read<JadwalProvider>();
    final selectedDivisi = _selectedDivisi;
    final selectedPelaksana = _selectedPelaksana;
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
            pelaksanaFilter: selectedPelaksana,
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
    final provider = context.watch<JadwalProvider>();
    final pelaksanaOptions = _getPelaksanaOptions(provider);
    final safePelaksana = pelaksanaOptions.contains(_selectedPelaksana)
        ? _selectedPelaksana
        : pelaksanaOptions.first;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 440),
        padding: const EdgeInsets.all(20),
        child: SingleChildScrollView(
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
                          'Export Laporan (PDF / Excel)',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        Text(
                          'Filter divisi, pelaksana, dan periode',
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
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10)),
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

              // Dropdown Pelaksana (Teknisi / User)
              const Text(
                'Pilih Pelaksana (Teknisi)',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 6),
              DropdownButtonFormField<String>(
                value: safePelaksana,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.person_outline, size: 18),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                items: pelaksanaOptions.map((p) {
                  return DropdownMenuItem(
                    value: p,
                    child: Text(p,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 13)),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _selectedPelaksana = val);
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
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 10),
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10)),
                          ),
                          items: List.generate(12, (i) {
                            return DropdownMenuItem(
                              value: i + 1,
                              child: Text(_monthNames[i],
                                  style: const TextStyle(fontSize: 12.5)),
                            );
                          }),
                          onChanged: (val) {
                            if (val != null) {
                              setState(() => _selectedMonth = val);
                            }
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
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 10),
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10)),
                          ),
                          items: [2024, 2025, 2026, 2027].map((yr) {
                            return DropdownMenuItem(
                              value: yr,
                              child: Text('$yr',
                                  style: const TextStyle(fontSize: 12.5)),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) {
                              setState(() => _selectedYear = val);
                            }
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
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _downloadExcel,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF16A34A),
                        side: const BorderSide(color: Color(0xFF16A34A)),
                      ),
                      icon: const Icon(Icons.table_chart_rounded, size: 16),
                      label: const Text('Excel', style: TextStyle(fontSize: 12.5)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _generateAndPreviewPdf,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                      ),
                      icon: const Icon(Icons.print_rounded, size: 16),
                      label: const Text('PDF', style: TextStyle(fontSize: 12.5)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
