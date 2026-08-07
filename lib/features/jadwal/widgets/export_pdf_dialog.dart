import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:printing/printing.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/api_client.dart';
import '../../../core/widgets/app_notifier.dart';
import '../../auth/providers/auth_provider.dart';
import '../../master/providers/master_provider.dart';
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

  bool _isLoadingPdf = false;
  bool _isLoadingExcel = false;

  bool get _isProcessing => _isLoadingPdf || _isLoadingExcel;

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

    final auth = context.read<AuthProvider>();
    final role = (auth.user?['user_jabatan'] ?? '').toString().toLowerCase();
    final divisi = (auth.user?['user_divisi'] ?? '').toString().trim();
    final nama = (auth.user?['user_nama'] ?? '').toString().trim();

    final isManager = role == 'manager';
    final isAdmin = role == 'admin';

    if (isAdmin && divisi.isNotEmpty) {
      _selectedDivisi = _normalizeDivisi(divisi);
      _selectedPelaksana = 'Semua Pelaksana';
    } else if (!isManager && !isAdmin) {
      if (divisi.isNotEmpty) _selectedDivisi = _normalizeDivisi(divisi);
      if (nama.isNotEmpty) _selectedPelaksana = nama;
    } else {
      _selectedDivisi = 'Semua Divisi';
      _selectedPelaksana = 'Semua Pelaksana';
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final master = context.read<MasterProvider>();
      if (master.divisiMetadata.isEmpty) {
        master.fetchMetadata(showLoading: false);
      }
      if (master.jenisMaster.isEmpty) {
        master.fetchJenis(showLoading: false);
      }
    });
  }

  String _normalizeDivisi(String input) {
    final trimmed = input.trim();
    if (trimmed.isEmpty) return '';
    final lower = trimmed.toLowerCase();
    if (lower == 'ga') return 'GA';
    if (lower == 'it') return 'IT';
    return trimmed[0].toUpperCase() + trimmed.substring(1).toLowerCase();
  }

  List<String> _getDivisiOptions(MasterProvider master, AuthProvider auth) {
    final role = (auth.user?['user_jabatan'] ?? '').toString().toLowerCase();
    final divisi = (auth.user?['user_divisi'] ?? '').toString().trim();
    final isManager = role == 'manager';

    if (!isManager && divisi.isNotEmpty) {
      // Admin Divisi & User biasa terkunci ke divisinya sendiri (dinormalisasi)
      return [_normalizeDivisi(divisi)];
    }

    // Manager dapat melihat Semua Divisi (Deduplikasi Case-Insensitive)
    final mapDivisi = <String, String>{};

    void addDivisi(String raw) {
      final norm = _normalizeDivisi(raw);
      if (norm.isNotEmpty) {
        mapDivisi[norm.toLowerCase()] = norm;
      }
    }

    for (final div in master.divisiMetadata) {
      addDivisi(div);
    }

    for (final j in master.jenisMaster) {
      addDivisi(j.jenisKategori);
    }

    if (mapDivisi.isEmpty) {
      for (final d in ['GA', 'Teknisi', 'Driver', 'IT', 'Produksi', 'Workshop']) {
        addDivisi(d);
      }
    }

    final sorted = mapDivisi.values.toList()..sort();
    return ['Semua Divisi', ...sorted];
  }

  List<int> _getYearOptions() {
    final currentYear = DateTime.now().year;
    final endYear = currentYear < 2026 ? 2026 : currentYear + 1;
    final years = <int>[];
    for (int y = 2026; y <= endYear; y++) {
      years.add(y);
    }
    return years;
  }

  List<String> _getPelaksanaOptions(
      JadwalProvider provider, MasterProvider master, AuthProvider auth) {
    final role = (auth.user?['user_jabatan'] ?? '').toString().toLowerCase();
    final nama = (auth.user?['user_nama'] ?? '').toString().trim();
    final isManager = role == 'manager';
    final isAdmin = role == 'admin';

    if (!isManager && !isAdmin && nama.isNotEmpty) {
      // User / Teknisi biasa terkunci hanya ke akun dirinya sendiri
      return [nama];
    }

    final setNames = <String>{};

    // 1. Ambil dari Master User database yang tersaring berdasarkan Divisi Target & Jabatan (user/teknisi/it_support)
    for (final u in master.userList) {
      final uNama = u.userNama.trim();
      final uDiv = u.userDivisi.trim();
      final uJabatan = u.userJabatan.trim().toLowerCase();

      if (uNama.isEmpty) continue;

      // Filter hanya user berjabatan user, teknisi, atau it_support (non-admin & non-manager)
      final isUserRole =
          uJabatan == 'user' || uJabatan == 'teknisi' || uJabatan == 'it_support';
      if (!isUserRole) continue;

      if (_selectedDivisi != 'Semua Divisi') {
        if (_normalizeDivisi(uDiv) == _normalizeDivisi(_selectedDivisi)) {
          setNames.add(uNama);
        }
      } else {
        setNames.add(uNama);
      }
    }

    // 2. Tambahkan pelaksana dari data realisasi (jika role user/teknisi)
    final list = widget.realisasiList.isNotEmpty
        ? widget.realisasiList
        : provider.realisasiList;
    for (final r in list) {
      final rDiv = (r.jadwal?['jdw_divisi'] ?? '').toString().trim();
      final rNama =
          (r.teknisi?['user_nama'] ?? r.realTtdPicNama ?? '').toString().trim();
      final rJabatan =
          (r.teknisi?['user_jabatan'] ?? '').toString().trim().toLowerCase();

      if (rNama.isEmpty) continue;

      // Kecualikan jika tercatat sebagai admin atau manager
      if (rJabatan == 'admin' || rJabatan == 'manager') continue;

      if (_selectedDivisi != 'Semua Divisi') {
        if (_normalizeDivisi(rDiv) == _normalizeDivisi(_selectedDivisi)) {
          setNames.add(rNama);
        }
      } else {
        setNames.add(rNama);
      }
    }

    final sorted = setNames.toList()..sort();
    return ['Semua Pelaksana', ...sorted];
  }

  bool _hasMatchingRealisasiData({
    required List<RealisasiModel> realisasiList,
    required String divisiFilter,
    required String pelaksanaFilter,
    required int month,
    required int year,
  }) {
    for (final r in realisasiList) {
      if (r.realStatus != 'Selesai') continue;
      final tgl = DateTime.tryParse(r.realTgl);
      if (tgl == null) continue;
      if (tgl.year != year || tgl.month != month) continue;

      // Filter Divisi
      if (divisiFilter != 'Semua Divisi') {
        final jdwDiv =
            (r.jadwal?['jdw_divisi'] ?? '').toString().trim().toUpperCase();
        final filterDiv = divisiFilter.trim().toUpperCase();
        if (jdwDiv.isNotEmpty && jdwDiv != filterDiv) continue;
      }

      // Filter Pelaksana
      if (pelaksanaFilter != 'Semua Pelaksana' && pelaksanaFilter.isNotEmpty) {
        final teknisiNama = (r.teknisi?['user_nama'] ?? r.realTtdPicNama ?? '')
            .toString()
            .trim()
            .toLowerCase();
        final targetNama = pelaksanaFilter.trim().toLowerCase();
        if (!teknisiNama.contains(targetNama)) continue;
      }

      return true; // Ditemukan setidaknya 1 data realisasi yang cocok
    }
    return false;
  }

  Future<void> _downloadExcel() async {
    if (_isProcessing) return;

    final provider = context.read<JadwalProvider>();
    final realisasiList = widget.realisasiList.isNotEmpty
        ? widget.realisasiList
        : provider.realisasiList;

    // Verifikasi ketersediaan data sebelum mengunduh Excel
    final hasData = _hasMatchingRealisasiData(
      realisasiList: realisasiList,
      divisiFilter: _selectedDivisi,
      pelaksanaFilter: _selectedPelaksana,
      month: _selectedMonth,
      year: _selectedYear,
    );

    if (!hasData) {
      final bulanNama = _monthNames[_selectedMonth - 1];
      final targetStr = _selectedPelaksana != 'Semua Pelaksana'
          ? 'user $_selectedPelaksana'
          : 'divisi $_selectedDivisi';
      await AppNotifier.showWarning(
        context,
        'Tidak ditemukan data laporan realisasi untuk $targetStr pada bulan $bulanNama $_selectedYear.',
      );
      return;
    }

    setState(() => _isLoadingExcel = true);
    AppNotifier.showInfo(context, 'Memproses unduhan berkas Excel Laporan Maintenance...');

    try {
      const baseUrl = ApiConfig.baseUrl;
      final token = await ApiClient.getToken();

      final queryParams = <String, String>{
        'bulan': '$_selectedMonth',
        'tahun': '$_selectedYear',
        'status': 'Selesai',
      };
      if (token != null && token.isNotEmpty) {
        queryParams['token'] = token;
      }
      if (_selectedDivisi != 'Semua Divisi') {
        queryParams['divisi'] = _selectedDivisi;
      }
      if (_selectedPelaksana != 'Semua Pelaksana') {
        for (final r in realisasiList) {
          final name = (r.teknisi?['user_nama'] ?? r.realTtdPicNama ?? '').toString().trim();
          if (name == _selectedPelaksana) {
            queryParams['teknisi_id'] = '${r.realTeknisiId}';
            break;
          }
        }
      }

      final queryString = Uri(queryParameters: queryParams).query;
      final downloadUrl =
          '$baseUrl${ApiConfig.realisasi}/export-excel?$queryString';

      final uri = Uri.parse(downloadUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        if (mounted) Navigator.pop(context);
      } else {
        if (mounted) {
          await AppNotifier.showError(context, 'Tidak dapat membuka tautan unduhan Excel');
        }
      }
    } catch (e) {
      if (mounted) {
        await AppNotifier.showError(context, 'Gagal mengunduh Excel: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoadingExcel = false);
      }
    }
  }

  Future<void> _generateAndPreviewPdf() async {
    if (_isProcessing) return;

    final provider = context.read<JadwalProvider>();
    final selectedDivisi = _selectedDivisi;
    final selectedPelaksana = _selectedPelaksana;
    final selectedMonth = _selectedMonth;
    final selectedYear = _selectedYear;

    setState(() => _isLoadingPdf = true);
    AppNotifier.showInfo(context, 'Menyiapkan dokumen PDF Laporan Realisasi...');

    try {
      // Ambil ID teknisi jika pelaksana spesifik dipilih
      int? teknisiId;
      if (selectedPelaksana != 'Semua Pelaksana') {
        for (final r in provider.realisasiList) {
          final name = (r.teknisi?['user_nama'] ?? r.realTtdPicNama ?? '').toString().trim();
          if (name == selectedPelaksana) {
            teknisiId = r.realTeknisiId;
            break;
          }
        }
      }

      // Ambil data realisasi resmi langsung dari backend agar 100% SINKRON DENGAN EXCEL
      final fetchedRealisasi = await provider.fetchRealisasiForReport(
        bulan: selectedMonth,
        tahun: selectedYear,
        divisi: selectedDivisi,
        teknisiId: teknisiId,
      );

      final realisasiList = fetchedRealisasi.isNotEmpty
          ? fetchedRealisasi
          : (widget.realisasiList.isNotEmpty ? widget.realisasiList : provider.realisasiList);

      // Pastikan jadwalList juga terisi dari provider
      if (provider.jadwalList.isEmpty) {
        await provider.fetchJadwal();
      }
      final jadwalList = provider.jadwalList;

      final hasData = realisasiList.isNotEmpty;

      if (!hasData) {
        if (!mounted) return;
        final bulanNama = _monthNames[selectedMonth - 1];
        final targetStr = selectedPelaksana != 'Semua Pelaksana'
            ? 'user $selectedPelaksana'
            : 'divisi $selectedDivisi';
        await AppNotifier.showWarning(
          context,
          'Tidak ditemukan data laporan realisasi untuk $targetStr pada bulan $bulanNama $selectedYear.',
        );
        return;
      }

      final pdfBytes = await PdfReportService.generateRealisasiPdf(
        divisiFilter: selectedDivisi,
        pelaksanaFilter: selectedPelaksana,
        month: selectedMonth,
        year: selectedYear,
        realisasiList: realisasiList,
        jadwalList: jadwalList,
      );

      if (!mounted) return;
      Navigator.pop(context); // Tutup dialog filter setelah PDF siap

      await Printing.layoutPdf(
        onLayout: (format) async => pdfBytes,
        name:
            'Laporan_Maintenance_${selectedDivisi.replaceAll(" ", "_")}_${_monthNames[selectedMonth - 1]}_$selectedYear.pdf',
      );
    } catch (e) {
      if (mounted) {
        await AppNotifier.showError(context, 'Gagal membuat file PDF: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoadingPdf = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
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
                      Icons.download,
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
                          'Export Laporan (Excel / PDF)',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        Text(
                          'By divisi / pelaksana / periode',
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
                'Pilih Divisi',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 6),
              Builder(
                builder: (context) {
                  final master = context.watch<MasterProvider>();
                  final auth = context.watch<AuthProvider>();
                  final divisiList = _getDivisiOptions(master, auth);
                  final safeSelectedDivisi = divisiList.contains(_selectedDivisi)
                      ? _selectedDivisi
                      : divisiList.first;
                  final isDivisiLocked = divisiList.length == 1;

                  return DropdownButtonFormField<String>(
                    value: safeSelectedDivisi,
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.business_rounded, size: 18),
                      contentPadding:
                          const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10)),
                      filled: isDivisiLocked,
                      fillColor: isDivisiLocked ? Colors.grey[100] : null,
                    ),
                    items: divisiList.map((div) {
                      return DropdownMenuItem(
                        value: div,
                        child: Text(div, style: const TextStyle(fontSize: 13)),
                      );
                    }).toList(),
                    onChanged: isDivisiLocked
                        ? null
                        : (val) {
                            if (val != null) setState(() => _selectedDivisi = val);
                          },
                  );
                },
              ),
              const SizedBox(height: 14),

              // Dropdown Pelaksana 
              const Text(
                'Pilih Pelaksana',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 6),
              Builder(
                builder: (context) {
                  final provider = context.watch<JadwalProvider>();
                  final master = context.watch<MasterProvider>();
                  final auth = context.watch<AuthProvider>();
                  final pelaksanaOptions =
                      _getPelaksanaOptions(provider, master, auth);
                  final safePelaksana =
                      pelaksanaOptions.contains(_selectedPelaksana)
                          ? _selectedPelaksana
                          : pelaksanaOptions.first;
                  final isPelaksanaLocked = pelaksanaOptions.length == 1;

                  return DropdownButtonFormField<String>(
                    value: safePelaksana,
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.person_outline, size: 18),
                      contentPadding:
                          const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10)),
                      filled: isPelaksanaLocked,
                      fillColor: isPelaksanaLocked ? Colors.grey[100] : null,
                    ),
                    items: pelaksanaOptions.map((p) {
                      return DropdownMenuItem(
                        value: p,
                        child: Text(
                          p,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 13),
                        ),
                      );
                    }).toList(),
                    onChanged: isPelaksanaLocked
                        ? null
                        : (val) {
                            if (val != null) setState(() => _selectedPelaksana = val);
                          },
                  );
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
                        Builder(
                          builder: (context) {
                            final years = _getYearOptions();
                            final safeYear = years.contains(_selectedYear)
                                ? _selectedYear
                                : years.first;

                            return DropdownButtonFormField<int>(
                              value: safeYear,
                              decoration: InputDecoration(
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 10),
                                border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10)),
                              ),
                              items: years.map((yr) {
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
                            );
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
                      onPressed: _isProcessing ? null : () => Navigator.pop(context),
                      child: const Text('Batal'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _isProcessing ? null : _downloadExcel,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF16A34A),
                        foregroundColor: Colors.white,
                      ),
                      icon: _isLoadingExcel
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.table_chart_rounded, size: 16),
                      label: Text(
                        _isLoadingExcel ? 'Proses...' : 'Excel',
                        style: const TextStyle(fontSize: 12.5),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _isProcessing ? null : _generateAndPreviewPdf,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                      ),
                      icon: _isLoadingPdf
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.print_rounded, size: 16),
                      label: Text(
                        _isLoadingPdf ? 'Proses...' : 'PDF',
                        style: const TextStyle(fontSize: 12.5),
                      ),
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
