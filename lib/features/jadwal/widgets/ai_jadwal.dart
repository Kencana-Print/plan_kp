import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_notifier.dart';
import '../../../core/utils/date_formatter.dart';
import '../../master/providers/master_provider.dart';
import '../providers/jadwal_provider.dart';

class AiJadwalWizardSheet extends StatefulWidget {
  final Function(Map<String, dynamic> draftData) onOpenFullForm;
  final VoidCallback onSaved;

  const AiJadwalWizardSheet({
    super.key,
    required this.onOpenFullForm,
    required this.onSaved,
  });

  @override
  State<AiJadwalWizardSheet> createState() => _AiJadwalWizardSheetState();
}

class _AiJadwalWizardSheetState extends State<AiJadwalWizardSheet> {
  int _currentStep = 1;
  bool _isSaving = false;

  // Step 1: Jenis
  int? _selectedJenisId;
  String _selectedJenisNama = '';
  int _currentJenisGapHari = 0;

  // Step 2: Lokasi / Pabrik
  final List<String> _selectedPabrikList = [];

  // Step 3: Pelaksana / User
  int? _selectedUserId;
  String _selectedUserNama = 'Semua User / Teknisi';

  // Step 4: Frekuensi
  String? _frekuensi;

  // Step 5: Gap Jadwal
  int _jdwGapHari = 90;
  String _jdwGapLabel = '3 Bulan sekali (90 hari)';
  bool _isCustomJdwGap = false;
  final TextEditingController _customJdwGapCtrl = TextEditingController();

  // Step 5B: Gap Jenis Unit (Opsional)
  int _jenisGapHari = 0;
  String _jenisGapLabel = 'Gunakan Gap bawaan Master';
  bool _shouldUpdateJenisGap = false;
  final TextEditingController _customJenisGapCtrl = TextEditingController();
  bool _isCustomJenisGap = false;

  // Step 6: Tanggal Mulai & Tanggal Selesai
  DateTime _tglMulai = DateTime.now();
  DateTime? _tglSelesai;

  // Step 7: Target Unit
  bool _isAutoTarget = true;
  int _targetManual = 1;
  int _maxTargetUnit = 0;
  final TextEditingController _targetManualCtrl = TextEditingController(text: '1');

  // Step 8: Catatan / Notes
  final TextEditingController _notesCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _initData());
  }

  @override
  void dispose() {
    _customJdwGapCtrl.dispose();
    _customJenisGapCtrl.dispose();
    _targetManualCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _initData() async {
    final master = context.read<MasterProvider>();

    await master.fetchJenis(showLoading: false);
    await master.fetchPabrik();
    await master.fetchUsers(showLoading: false);
    await master.fetchInventaris(showLoading: false);

    final availables = master.jenisAvailableForJadwal();
    final listJenis = availables.isNotEmpty ? availables : master.jenisMaster;

    if (listJenis.isNotEmpty) {
      final j = listJenis.first;
      _selectedJenisId = j.jenisId;
      _selectedJenisNama = j.jenisNama;
      _currentJenisGapHari = j.jenisGapHari;
      _jenisGapHari = j.jenisGapHari;
      _shouldUpdateJenisGap = false;
      _updateJenisGapLabel();
      _updateMaxTargetUnit();
    }

    if (!mounted) return;
  }

  void _updateJenisGapLabel() {
    if (!_shouldUpdateJenisGap) {
      _jenisGapLabel = '$_currentJenisGapHari hari (Bawaan Master)';
    } else {
      _jenisGapLabel = '$_jenisGapHari hari (Perbarui Master Jenis)';
    }
  }

  void _updateMaxTargetUnit() {
    if (_selectedJenisId == null) return;
    final master = context.read<MasterProvider>();
    final count = master.inventarisList.where((inv) {
      if (inv.invJenisId != _selectedJenisId) return false;
      if (!inv.invIsActive) return false;
      if (_selectedPabrikList.isEmpty) return true;
      return _selectedPabrikList.contains(inv.invPabrikKode);
    }).length;

    setState(() {
      _maxTargetUnit = count;
      if (_targetManual > count && count > 0) {
        _targetManual = count;
      }
      _targetManualCtrl.text = _targetManual.toString();
    });
  }

  bool _isDateAllowedForFrekuensi(DateTime date) {
    if (_frekuensi == 'Mingguan') return date.weekday == DateTime.monday;
    if (_frekuensi == 'Bulanan') return date.day == 1;
    return true;
  }

  DateTime _nextAllowedDate(DateTime from) {
    final base = DateTime(from.year, from.month, from.day);
    if (_frekuensi == 'Mingguan') {
      final diff = (DateTime.monday - base.weekday + 7) % 7;
      return base.add(Duration(days: diff));
    }
    if (_frekuensi == 'Bulanan') {
      if (base.day == 1) return base;
      return DateTime(base.year, base.month + 1, 1);
    }
    return base;
  }

  void _setValidStartDateForFrekuensi(String freq) {
    setState(() {
      _frekuensi = freq;
      if (!_isDateAllowedForFrekuensi(_tglMulai)) {
        _tglMulai = _nextAllowedDate(_tglMulai);
      }
      _isCustomJdwGap = false;
      if (freq == 'Harian') {
        _jdwGapHari = 0;
        _jdwGapLabel = 'Setiap Hari Kerja';
      } else if (freq == 'Mingguan') {
        _jdwGapHari = 0;
        _jdwGapLabel = 'Setiap 1 Minggu';
      } else {
        _jdwGapHari = 90;
        _jdwGapLabel = 'Setiap 3 Bulan (90 hari)';
      }
    });
  }

  String _getGeneratedJudul() {
    final master = context.read<MasterProvider>();

    final freqUpper = (_frekuensi ?? '').toUpperCase();
    final jenisPart = _selectedJenisNama.trim();

    String userPart = '';
    if (_selectedUserId != null &&
        _selectedUserNama.isNotEmpty &&
        _selectedUserNama != 'Semua User / Teknisi') {
      userPart = '(${_selectedUserNama.trim()})';
    }

    String lokasiPart = '';
    if (_selectedPabrikList.isNotEmpty) {
      final names = _selectedPabrikList.map((code) {
        final match = master.pabrikList.where((p) => p.pabKode == code);
        if (match.isNotEmpty) return match.first.displayLabel;
        return code;
      }).join(', ');
      lokasiPart = '| $names';
    }

    var title = freqUpper.isNotEmpty ? 'MTC $freqUpper' : 'MTC';
    if (jenisPart.isNotEmpty) {
      title += ' - $jenisPart';
    }
    if (userPart.isNotEmpty) {
      title += ' $userPart';
    }
    if (lokasiPart.isNotEmpty) {
      title += ' $lokasiPart';
    }

    return title;
  }

  Map<String, dynamic> _buildDraftData() {
    final master = context.read<MasterProvider>();
    final lokasiDisplay = _selectedPabrikList.isEmpty
        ? 'Semua Pabrik / Lokasi'
        : _selectedPabrikList.join(', ');

    final targetVal = _isAutoTarget
        ? (_maxTargetUnit > 0 ? _maxTargetUnit : 1)
        : _targetManual;

    final jenisMatch =
        master.jenisMaster.where((j) => j.jenisId == _selectedJenisId);
    final divisiVal =
        jenisMatch.isNotEmpty ? jenisMatch.first.jenisKategori : 'GA';

    return {
      'jdwJenisId': _selectedJenisId,
      'jdwJenisNama': _selectedJenisNama,
      'jdwInvJenis': _selectedJenisNama,
      'jdwDivisi': divisiVal,
      'jdwJudul': _getGeneratedJudul(),
      'jdwPabrikList': List<String>.from(_selectedPabrikList),
      'jdwPabrikDisplay': lokasiDisplay,
      'jdwUserId': _selectedUserId,
      'jdwUserNama': _selectedUserNama,
      'jdwFrekuensi': _frekuensi ?? 'Bulanan',
      'jdwGapHari': _jdwGapHari,
      'jenisGapHari': _jenisGapHari,
      'jenisGapLabel': _jenisGapLabel,
      'shouldUpdateJenisGap': _shouldUpdateJenisGap,
      'jdwTglMulai': DateFormatter.toApi(_tglMulai),
      'jdwTglMulaiDisplay': DateFormatter.toDisplayFromDate(_tglMulai),
      'jdwTglSelesai':
          _tglSelesai != null ? DateFormatter.toApi(_tglSelesai!) : null,
      'jdwTglSelesaiDisplay': _tglSelesai != null
          ? DateFormatter.toDisplayFromDate(_tglSelesai!)
          : 'Tanpa batas selesai',
      'jdwNotes':
          _notesCtrl.text.trim().isNotEmpty ? _notesCtrl.text.trim() : null,
      'jdwTarget': targetVal,
      'isAutoTarget': _isAutoTarget,
      'maxTargetUnit': _maxTargetUnit,
    };
  }

  Future<void> _handleSaveDirect() async {
    setState(() => _isSaving = true);
    try {
      final master = context.read<MasterProvider>();
      final jadwal = context.read<JadwalProvider>();

      if (_shouldUpdateJenisGap &&
          _selectedJenisId != null &&
          _jenisGapHari != _currentJenisGapHari) {
        await master.saveJenis(
          {'jenis_gap_hari': _jenisGapHari},
          id: _selectedJenisId!,
        );
      }

      final draft = _buildDraftData();
      final payload = {
        'jdw_judul': draft['jdwJudul'],
        'jdw_jenis_id': draft['jdwJenisId'],
        'jdw_frekuensi': draft['jdwFrekuensi'],
        'jdw_tgl_mulai': draft['jdwTglMulai'],
        'jdw_tgl_selesai': draft['jdwTglSelesai'],
        'jdw_notes': draft['jdwNotes'],
        'jdw_target': draft['jdwTarget'],
        'jdw_gap_hari': draft['jdwGapHari'],
        'jdw_user_id': draft['jdwUserId'],
        'jdw_pabrik_kode': (draft['jdwPabrikList'] as List<String>).join(','),
      };

      final ok = await jadwal.saveJadwal(payload);
      if (!mounted) return;

      if (ok) {
        final judulBaru = draft['jdwJudul'];
        widget.onSaved();
        Navigator.pop(context);

        // Berikan notifikasi sukses UI di halaman utama setelah modal tertutup
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            AppNotifier.showSuccess(
              context,
              'Jadwal "$judulBaru" berhasil dibuat!',
            );
          }
        });
      } else {
        AppNotifier.showError(
          context,
          jadwal.error ?? 'Gagal membuat jadwal baru',
        );
      }
    } catch (e) {
      if (mounted) {
        AppNotifier.showError(context, 'Terjadi kesalahan: $e');
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  bool _validateCurrentStep() {
    if (_currentStep == 1) {
      if (_selectedJenisId == null) {
        AppNotifier.showWarning(
          context,
          'Jenis inventaris wajib dipilih',
        );
        return false;
      }
    } else if (_currentStep == 2) {
      if (_selectedPabrikList.isEmpty) {
        AppNotifier.showWarning(
          context,
          'Pilih minimal satu pabrik/lokasi',
        );
        return false;
      }
    } else if (_currentStep == 3) {
      if (_selectedUserId == null) {
        AppNotifier.showWarning(
          context,
          'Pelaksana wajib dipilih',
        );
        return false;
      }
    } else if (_currentStep == 4) {
      if (_frekuensi == null || _frekuensi!.isEmpty) {
        AppNotifier.showWarning(
          context,
          'Frekuensi wajib dipilih',
        );
        return false;
      }
    } else if (_currentStep == 7) {
      if (!_isAutoTarget) {
        if (_targetManual < 1) {
          setState(() {
            _targetManual = 1;
            _targetManualCtrl.text = '1';
          });
          AppNotifier.showWarning(
            context,
            'Target unit harus lebih dari 0 (minimal 1 unit)',
          );
          return false;
        }
        if (_maxTargetUnit > 0 && _targetManual > _maxTargetUnit) {
          setState(() {
            _targetManual = _maxTargetUnit;
            _targetManualCtrl.text = _maxTargetUnit.toString();
          });
          AppNotifier.showWarning(
            context,
            'Target unit disesuaikan ke maksimal $_maxTargetUnit unit (sesuai inventaris aktif)',
          );
          return false;
        }
      }
    }
    return true;
  }

  void _handleNextStep() {
    if (_validateCurrentStep()) {
      setState(() => _currentStep++);
    }
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final bottomInset = mediaQuery.viewInsets.bottom;
    final bottomPadding = mediaQuery.padding.bottom;

    return AnimatedPadding(
      duration: const Duration(milliseconds: 150),
      curve: Curves.easeOut,
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: mediaQuery.size.height * 0.92,
        ),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: SafeArea(
          top: false,
          bottom: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Top Header & Progress
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 14),
                child: Column(
                  children: [
                    Container(
                      width: 44,
                      height: 5,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                AppColors.primary,
                                AppColors.primary.withValues(alpha: 0.82),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.primary.withValues(alpha: 0.25),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.auto_awesome,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Asisten AI Penjadwalan',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.textPrimary,
                                  letterSpacing: -0.2,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: AppColors.primary.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      'Langkah $_currentStep dari 8',
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: AppColors.primary,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          style: IconButton.styleFrom(
                            backgroundColor: Colors.grey[100],
                            padding: const EdgeInsets.all(8),
                          ),
                          icon: const Icon(Icons.close, size: 20),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(99),
                      child: LinearProgressIndicator(
                        value: _currentStep / 8,
                        minHeight: 6,
                        backgroundColor: Colors.grey[200],
                        valueColor:
                            const AlwaysStoppedAnimation<Color>(AppColors.primary),
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: AppColors.border),

              // Step Content
              Expanded(
                child: SingleChildScrollView(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: const EdgeInsets.all(20),
                  child: _buildStepContent(),
                ),
              ),

              // Navigation Buttons
              Container(
                padding: EdgeInsets.fromLTRB(
                  20,
                  14,
                  20,
                  16 + (bottomInset > 0 ? 0 : bottomPadding),
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 10,
                      offset: const Offset(0, -4),
                    ),
                  ],
                  border: const Border(top: BorderSide(color: AppColors.border)),
                ),
              child: Row(
                children: [
                  if (_currentStep > 1)
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          setState(() => _currentStep--);
                        },
                        icon: const Icon(Icons.arrow_back, size: 16),
                        label: const Text('Sebelumnya'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.textPrimary,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          side: BorderSide(color: Colors.grey[300]!),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  if (_currentStep > 1) const SizedBox(width: 12),
                  Expanded(
                    child: _currentStep == 8
                        ? ElevatedButton.icon(
                            onPressed: _isSaving ? null : _handleSaveDirect,
                            icon: _isSaving
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.check_circle, size: 18),
                            label: Text(_isSaving ? 'Menyimpan...' : 'Buat Jadwal'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              elevation: 2,
                              shadowColor: AppColors.primary.withValues(alpha: 0.4),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          )
                        : ElevatedButton(
                            onPressed: _handleNextStep,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              elevation: 2,
                              shadowColor: AppColors.primary.withValues(alpha: 0.3),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  'Lanjut',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                                SizedBox(width: 6),
                                Icon(Icons.arrow_forward, size: 16),
                              ],
                            ),
                          ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
    );
  }

  Widget _buildStepContent() {
    switch (_currentStep) {
      case 1:
        return _buildStep1Jenis();
      case 2:
        return _buildStep2Lokasi();
      case 3:
        return _buildStep3User();
      case 4:
        return _buildStep4Frekuensi();
      case 5:
        return _buildStep5JdwGap();
      case 6:
        return _buildStep5BJenisGap();
      case 7:
        return _buildStep6TglMulaiAndTarget();
      case 8:
        return _buildStep8Summary();
      default:
        return const SizedBox.shrink();
    }
  }

  // --- STEP 1: Jenis Inventaris ---
  Widget _buildStep1Jenis() {
    final master = context.watch<MasterProvider>();
    final list = master.jenisAvailableForJadwal();
    final displayList = list.isNotEmpty ? list : master.jenisMaster;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _questionHeader(
          '1. Jenis Inventaris apa yang akan di-maintenance?',
          subtitle: 'Pilih jenis inventaris yang akan dijadwalkan maintenance.',
          icon: Icons.category,
        ),
        const SizedBox(height: 16),
        if (displayList.isEmpty)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: CircularProgressIndicator()),
          )
        else
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: displayList.map((j) {
              final isSelected = _selectedJenisId == j.jenisId;
              return InkWell(
                onTap: () {
                  setState(() {
                    _selectedJenisId = j.jenisId;
                    _selectedJenisNama = j.jenisNama;
                    _currentJenisGapHari = j.jenisGapHari;
                    _jenisGapHari = j.jenisGapHari;
                    _shouldUpdateJenisGap = false;
                    _updateJenisGapLabel();
                    _updateMaxTargetUnit();
                  });
                },
                borderRadius: BorderRadius.circular(14),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.primary.withValues(alpha: 0.1)
                        : Colors.grey[50],
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isSelected ? AppColors.primary : Colors.grey[300]!,
                      width: isSelected ? 1.5 : 1,
                    ),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: AppColors.primary.withValues(alpha: 0.12),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ]
                        : null,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isSelected
                            ? Icons.check_circle
                            : Icons.category,
                        size: 18,
                        color: isSelected ? AppColors.primary : Colors.grey[500],
                      ),
                      const SizedBox(width: 8),
                      Text(
                        j.jenisNama,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                          color: isSelected
                              ? AppColors.primary
                              : AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
      ],
    );
  }

  // --- STEP 2: Lokasi Pabrik ---
  Widget _buildStep2Lokasi() {
    final master = context.watch<MasterProvider>();

    final allowedCodes = master.inventarisList
        .where((inv) =>
            _selectedJenisId == null || inv.invJenisId == _selectedJenisId)
        .map((inv) => inv.invPabrikKode)
        .whereType<String>()
        .toSet();

    final filteredPabrikList = master.pabrikList.where((p) {
      if (_selectedJenisId != null && allowedCodes.isNotEmpty) {
        return allowedCodes.contains(p.pabKode);
      }
      return true;
    }).toList();

    final displayPabrikList =
        filteredPabrikList.isNotEmpty ? filteredPabrikList : master.pabrikList;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _questionHeader(
          '2. Pilih pabrik tempat unit inventaris berada?',
          subtitle: 'Pilih satu atau beberapa pabrik/lokasi target $_selectedJenisNama.',
          icon: Icons.location_on,
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: displayPabrikList.map((p) {
            final isSelected = _selectedPabrikList.contains(p.pabKode);
            return InkWell(
              onTap: () {
                setState(() {
                  if (isSelected) {
                    _selectedPabrikList.remove(p.pabKode);
                  } else {
                    _selectedPabrikList.add(p.pabKode);
                  }
                  _updateMaxTargetUnit();
                });
              },
              borderRadius: BorderRadius.circular(14),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppColors.primary.withValues(alpha: 0.1)
                      : Colors.grey[50],
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isSelected ? AppColors.primary : Colors.grey[300]!,
                    width: isSelected ? 1.5 : 1,
                  ),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.12),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isSelected
                          ? Icons.check_circle
                          : Icons.location_on,
                      size: 18,
                      color: isSelected ? AppColors.primary : Colors.grey[500],
                    ),
                    const SizedBox(width: 8),
                    Text(
                      p.displayLabel,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                        color: isSelected
                            ? AppColors.primary
                            : AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  // --- STEP 3: Pelaksana / Teknisi ---
  Widget _buildStep3User() {
    final master = context.watch<MasterProvider>();
    final lokasiDisplay = _selectedPabrikList.isEmpty
        ? 'Semua Pabrik / Lokasi'
        : _selectedPabrikList.join(', ');

    final jenisMatch =
        master.jenisMaster.where((j) => j.jenisId == _selectedJenisId);
    final userDivisi =
        jenisMatch.isNotEmpty ? jenisMatch.first.jenisKategori : '';

    final filteredUsers = master.userList.where((u) {
      final targetDiv = userDivisi.trim().toLowerCase();
      final userDiv = u.userDivisi.trim().toLowerCase();
      final matchDiv = targetDiv.isEmpty || userDiv == targetDiv;
      final matchJabatan = u.userJabatan == 'user' ||
          u.userJabatan == 'teknisi' ||
          u.userJabatan == 'it_support';
      return matchDiv && matchJabatan && u.userIsActive;
    }).toList();

    final displayUsers = filteredUsers.isNotEmpty
        ? filteredUsers
        : master.userList.where((u) {
            final matchJabatan = u.userJabatan == 'user' ||
                u.userJabatan == 'teknisi' ||
                u.userJabatan == 'it_support';
            return matchJabatan && u.userIsActive;
          }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _questionHeader(
          '3. Siapa teknisi/pelaksana yang ditugaskan?',
          subtitle: 'Pilih teknisi/pelaksana jadwal maintenance $_selectedJenisNama di $lokasiDisplay.',
          icon: Icons.person,
        ),
        const SizedBox(height: 16),
        if (displayUsers.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: Center(
              child: Text(
                'Tidak ada user/teknisi aktif ditemukan.',
                style: TextStyle(color: Colors.grey),
              ),
            ),
          )
        else
          ...displayUsers.map((u) {
            final isSelected = _selectedUserId == u.userId;
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppColors.primary.withValues(alpha: 0.06)
                      : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isSelected ? AppColors.primary : Colors.grey[200]!,
                    width: isSelected ? 1.5 : 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.02),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: ListTile(
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                  leading: CircleAvatar(
                    radius: 20,
                    backgroundColor: isSelected
                        ? AppColors.primary
                        : AppColors.primary.withValues(alpha: 0.1),
                    child: Text(
                      u.userNama.isNotEmpty ? u.userNama[0].toUpperCase() : 'U',
                      style: TextStyle(
                        color: isSelected ? Colors.white : AppColors.primary,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                  ),
                  title: Text(
                    u.userNama,
                    style: TextStyle(
                      fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                      fontSize: 13.5,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  subtitle: Row(
                    children: [
                      Container(
                        margin: const EdgeInsets.only(top: 4),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'Jabatan: ${u.userJabatan} · Divisi: ${u.userDivisi}',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey[700],
                          ),
                        ),
                      ),
                    ],
                  ),
                  trailing: Icon(
                    isSelected ? Icons.check_circle : Icons.person,
                    color: isSelected ? AppColors.primary : Colors.grey[400],
                    size: 22,
                  ),
                  onTap: () {
                    setState(() {
                      _selectedUserId = u.userId;
                      _selectedUserNama = u.userNama;
                    });
                  },
                ),
              ),
            ),
          );
          }),
      ],
    );
  }

  // --- STEP 4: Siklus Frekuensi ---
  Widget _buildStep4Frekuensi() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _questionHeader(
          '4. Tentukan frekuensi jadwal maintenance $_selectedJenisNama?',
          subtitle: 'Pilih periode rutin maintenance untuk $_selectedJenisNama.',
          icon: Icons.event,
        ),
        const SizedBox(height: 16),
        _optionCard(
          title: 'Harian',
          desc: 'Jadwal Harian. Pelaksana wajib merealisasikan inventaris setiap hari.',
          isSelected: _frekuensi == 'Harian',
          onTap: () => _setValidStartDateForFrekuensi('Harian'),
        ),
        const SizedBox(height: 10),
        _optionCard(
          title: 'Mingguan',
          desc: 'Jadwal Mingguan. Pelaksana dapat merealisasi bertahap inventaris dalam rentang mingguan.',
          isSelected: _frekuensi == 'Mingguan',
          onTap: () => _setValidStartDateForFrekuensi('Mingguan'),
        ),
        const SizedBox(height: 10),
        _optionCard(
          title: 'Bulanan',
          desc: 'Jadwal Bulanan. Pelaksana dapat merealisasikan bertahap inventaris dalam rentang bulanan.',
          isSelected: _frekuensi == 'Bulanan',
          onTap: () => _setValidStartDateForFrekuensi('Bulanan'),
        ),
      ],
    );
  }

  // --- STEP 5: Jeda Siklus Jadwal ---
  Widget _buildStep5JdwGap() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _questionHeader(
          '5. Berapa jeda pengulangan jadwal?',
          subtitle:
              'Atur jarak jeda antar periode pemeliharaan (misal: 2 minggu sekali, 3 bulan sekali, dsb).',
          icon: Icons.schedule,
        ),
        const SizedBox(height: 16),
        if (_frekuensi == 'Harian') ...[
          _optionCard(
            title: 'Setiap Hari Kerja (Tanpa Jeda)',
            desc: 'Jadwal berjalan setiap hari tanpa jeda periode.',
            isSelected: !_isCustomJdwGap && _jdwGapHari == 0,
            onTap: () => setState(() {
              _isCustomJdwGap = false;
              _jdwGapHari = 0;
              _jdwGapLabel = 'Setiap Hari Kerja';
            }),
          ),
        ] else if (_frekuensi == 'Mingguan') ...[
          _optionCard(
            title: '1 Minggu sekali (Tanpa Jeda)',
            desc: 'Jadwal Rutin per 1 minggu sekali.',
            isSelected: !_isCustomJdwGap && _jdwGapHari == 0,
            onTap: () => setState(() {
              _isCustomJdwGap = false;
              _jdwGapHari = 0;
              _jdwGapLabel = '1 Minggu sekali';
            }),
          ),
          const SizedBox(height: 10),
          _optionCard(
            title: '2 Minggu sekali (Jeda 14 Hari)',
            desc: 'Jadwal rutin per 2 minggu sekali.',
            isSelected: !_isCustomJdwGap && _jdwGapHari == 14,
            onTap: () => setState(() {
              _isCustomJdwGap = false;
              _jdwGapHari = 14;
              _jdwGapLabel = '2 Minggu sekali (14 hari)';
            }),
          ),
        ] else ...[
          _optionCard(
            title: '1 Bulan sekali (Jeda 30 Hari)',
            desc: 'Rutin setiap bulan.',
            isSelected: !_isCustomJdwGap && _jdwGapHari == 30,
            onTap: () => setState(() {
              _isCustomJdwGap = false;
              _jdwGapHari = 30;
              _jdwGapLabel = '1 Bulan sekali (30 hari)';
            }),
          ),
          const SizedBox(height: 10),
          _optionCard(
            title: '3 Bulan sekali (Jeda 90 Hari)',
            desc: 'Pemeriksaan berkala per triwulan.',
            isSelected: !_isCustomJdwGap && _jdwGapHari == 90,
            onTap: () => setState(() {
              _isCustomJdwGap = false;
              _jdwGapHari = 90;
              _jdwGapLabel = '3 Bulan sekali (90 hari)';
            }),
          ),
          const SizedBox(height: 10),
          _optionCard(
            title: '6 Bulan sekali (Jeda 180 Hari)',
            desc: 'Pemeriksaan berkala per semester.',
            isSelected: !_isCustomJdwGap && _jdwGapHari == 180,
            onTap: () => setState(() {
              _isCustomJdwGap = false;
              _jdwGapHari = 180;
              _jdwGapLabel = '6 Bulan sekali (180 hari)';
            }),
          ),
        ],
        const SizedBox(height: 10),
        _optionCard(
          title: 'Tentukan Manual Custom (hari)',
          desc: 'Isi durasi jeda hari pengulangan jadwal spesifik.',
          isSelected: _isCustomJdwGap,
          onTap: () => setState(() {
            _isCustomJdwGap = true;
            _customJdwGapCtrl.text = _jdwGapHari.toString();
            _jdwGapLabel = '$_jdwGapHari hari sekali (Custom)';
          }),
        ),
        if (_isCustomJdwGap) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.grey[300]!),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Durasi Jeda Pengulangan:',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.remove, color: AppColors.primary),
                      onPressed: _jdwGapHari > 0
                          ? () => setState(() {
                                _jdwGapHari--;
                                _customJdwGapCtrl.text = _jdwGapHari.toString();
                                _jdwGapLabel = '$_jdwGapHari hari sekali (Custom)';
                              })
                          : null,
                    ),
                    SizedBox(
                      width: 85,
                      child: TextField(
                        controller: _customJdwGapCtrl,
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                          color: AppColors.primary,
                        ),
                        decoration: InputDecoration(
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 8,
                          ),
                          filled: true,
                          fillColor: AppColors.primary.withValues(alpha: 0.1),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide.none,
                          ),
                          suffixText: 'Hari',
                          suffixStyle: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primary,
                          ),
                        ),
                        onChanged: (val) {
                          final trimmed = val.trim();
                          if (trimmed.isEmpty) {
                            setState(() {
                              _jdwGapHari = 0;
                              _jdwGapLabel = '0 hari sekali (Custom)';
                            });
                            return;
                          }
                          final parsed = int.tryParse(trimmed);
                          if (parsed != null && parsed >= 0) {
                            setState(() {
                              _jdwGapHari = parsed;
                              _jdwGapLabel = '$parsed hari sekali (Custom)';
                            });
                          }
                        },
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.add, color: AppColors.primary),
                      onPressed: () => setState(() {
                        _jdwGapHari++;
                        _customJdwGapCtrl.text = _jdwGapHari.toString();
                        _jdwGapLabel = '$_jdwGapHari hari sekali (Custom)';
                      }),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  // --- STEP 5B: Jeda Fisik Unit Inventaris (jenis_gap_hari - Opsional) ---
  Widget _buildStep5BJenisGap() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _questionHeader(
          '6. Berapa GAP Hari per unit Inventaris $_selectedJenisNama?',
          subtitle: 'Batas minimal unit inventaris $_selectedJenisNama yang SAMA dapat di maintenance lagi.',
          icon: Icons.schedule,
        ),
        const SizedBox(height: 16),
        _optionCard(
          title: 'Gunakan Gap bawaan Master Jenis $_selectedJenisNama: ($_currentJenisGapHari hari)',
          desc: 'Gunakan Gap Hari Realisasi bawaan Master Jenis $_selectedJenisNama.',
          isSelected: !_shouldUpdateJenisGap,
          onTap: () => setState(() {
            _shouldUpdateJenisGap = false;
            _jenisGapHari = _currentJenisGapHari;
            _updateJenisGapLabel();
          }),
        ),
        const SizedBox(height: 10),
        _optionCard(
          title: 'Perbarui Gap Hari di Master Jenis',
          desc: 'Opsional: Ubah nilai Gap Hari Realisasi di Master Jenis ($_selectedJenisNama).',
          isSelected: _shouldUpdateJenisGap,
          onTap: () => setState(() {
            _shouldUpdateJenisGap = true;
            if (_jenisGapHari == 0) _jenisGapHari = 30;
            _updateJenisGapLabel();
          }),
        ),
        if (_shouldUpdateJenisGap) ...[
          const SizedBox(height: 14),
          const Divider(height: 1),
          const SizedBox(height: 14),
          const Text(
            'Pilih Nilai Gap Hari Baru untuk Master Jenis:',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5),
          ),
          const SizedBox(height: 10),
          _optionCard(
            title: '2 Hari sekali (2 hari)',
            desc: 'Inventaris $_selectedJenisNama yang sama dapat di maintenance lagi setelah 2 hari.',
            isSelected: !_isCustomJenisGap && _jenisGapHari == 2,
            onTap: () => setState(() {
              _isCustomJenisGap = false;
              _jenisGapHari = 2;
              _updateJenisGapLabel();
            }),
          ),
          const SizedBox(height: 8),
          _optionCard(
            title: '1 Minggu sekali (7 hari)',
            desc: 'Inventaris $_selectedJenisNama yang sama dapat di maintenance lagi setelah 7 hari.',
            isSelected: !_isCustomJenisGap && _jenisGapHari == 7,
            onTap: () => setState(() {
              _isCustomJenisGap = false;
              _jenisGapHari = 7;
              _updateJenisGapLabel();
            }),
          ),
          const SizedBox(height: 8),
          _optionCard(
            title: '1 Bulan sekali (30 hari)',
            desc: 'Inventaris $_selectedJenisNama yang sama dapat di maintenance lagi setelah 30 hari.',
            isSelected: !_isCustomJenisGap && _jenisGapHari == 30,
            onTap: () => setState(() {
              _isCustomJenisGap = false;
              _jenisGapHari = 30;
              _updateJenisGapLabel();
            }),
          ),
          const SizedBox(height: 8),
          _optionCard(
            title: '2 Bulan sekali (60 hari)',
            desc: 'Inventaris $_selectedJenisNama yang sama dapat di maintenance lagi setelah 60 hari.',
            isSelected: !_isCustomJenisGap && _jenisGapHari == 60,
            onTap: () => setState(() {
              _isCustomJenisGap = false;
              _jenisGapHari = 60;
              _updateJenisGapLabel();
            }),
          ),
          const SizedBox(height: 8),
          _optionCard(
            title: 'Tentukan Manual (hari)',
            desc: 'Isi durasi Gap hari realisasi Jenis Inventaris $_selectedJenisNama.',
            isSelected: _isCustomJenisGap,
            onTap: () => setState(() {
              _isCustomJenisGap = true;
              _customJenisGapCtrl.text = _jenisGapHari.toString();
              _updateJenisGapLabel();
            }),
          ),
          if (_isCustomJenisGap) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Gap Hari Realisasi:',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.remove, color: AppColors.primary),
                        onPressed: _jenisGapHari > 0
                            ? () => setState(() {
                                  _jenisGapHari--;
                                  _customJenisGapCtrl.text = _jenisGapHari.toString();
                                  _updateJenisGapLabel();
                                })
                            : null,
                      ),
                      SizedBox(
                        width: 85,
                        child: TextField(
                          controller: _customJenisGapCtrl,
                          keyboardType: TextInputType.number,
                          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
                            color: AppColors.primary,
                          ),
                          decoration: InputDecoration(
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 8,
                            ),
                            filled: true,
                            fillColor: AppColors.primary.withValues(alpha: 0.1),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide.none,
                            ),
                            suffixText: 'Hari',
                            suffixStyle: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppColors.primary,
                            ),
                          ),
                          onChanged: (val) {
                            final trimmed = val.trim();
                            if (trimmed.isEmpty) {
                              setState(() {
                                _jenisGapHari = 0;
                                _updateJenisGapLabel();
                              });
                              return;
                            }
                            final parsed = int.tryParse(trimmed);
                            if (parsed != null && parsed >= 0) {
                              setState(() {
                                _jenisGapHari = parsed;
                                _updateJenisGapLabel();
                              });
                            }
                          },
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.add, color: AppColors.primary),
                        onPressed: () => setState(() {
                          _jenisGapHari++;
                          _customJenisGapCtrl.text = _jenisGapHari.toString();
                          _updateJenisGapLabel();
                        }),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ],
      ],
    );
  }

  // --- STEP 7: Tanggal Mulai, Tanggal Selesai, Target Unit & Catatan ---
  Widget _buildStep6TglMulaiAndTarget() {
    final pabrikDisplay = _selectedPabrikList.isEmpty
        ? 'Semua Pabrik'
        : _selectedPabrikList.join(', ');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _questionHeader(
          '7. Kapan jadwal berjalan, target & catatannya?',
          subtitle: 'Atur tanggal mulai, tanggal selesai (opsional), target unit, dan instruksi khusus.',
          icon: Icons.event,
        ),
        const SizedBox(height: 16),
        const Text(
          'Tanggal Mulai Pertama:',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
        ),
        const SizedBox(height: 8),
        InkWell(
          onTap: () async {
            final initialRaw = _tglMulai;
            final initialDate = !_isDateAllowedForFrekuensi(initialRaw)
                ? _nextAllowedDate(initialRaw)
                : initialRaw;

            final picked = await showDatePicker(
              context: context,
              initialDate: initialDate,
              firstDate: DateTime.now().subtract(const Duration(days: 30)),
              lastDate: DateTime.now().add(const Duration(days: 730)),
              selectableDayPredicate: (day) => _isDateAllowedForFrekuensi(day),
            );
            if (picked != null) {
              setState(() => _tglMulai = picked);
            }
          },
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.event,
                        color: AppColors.primary, size: 18),
                    const SizedBox(width: 10),
                    Text(
                      DateFormatter.toDisplayFromDate(_tglMulai),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
                const Icon(Icons.edit,
                    color: AppColors.primary, size: 18),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Tanggal Selesai (Opsional):',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
            if (_tglSelesai != null)
              GestureDetector(
                onTap: () => setState(() => _tglSelesai = null),
                child: const Text(
                  'Hapus Batas Selesai',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: Colors.red,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        InkWell(
          onTap: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: _tglSelesai ?? _tglMulai.add(const Duration(days: 90)),
              firstDate: _tglMulai,
              lastDate: DateTime.now().add(const Duration(days: 730)),
            );
            if (picked != null) {
              setState(() => _tglSelesai = picked);
            }
          },
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: _tglSelesai != null
                  ? AppColors.primary.withValues(alpha: 0.05)
                  : Colors.grey[50],
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: _tglSelesai != null
                    ? AppColors.primary
                    : Colors.grey[300]!,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.event,
                      color: _tglSelesai != null
                          ? AppColors.primary
                          : Colors.grey[600],
                      size: 18,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      _tglSelesai != null
                          ? DateFormatter.toDisplayFromDate(_tglSelesai!)
                          : 'Tidak ada batas selesai (Berjalan terus)',
                      style: TextStyle(
                        fontWeight: _tglSelesai != null
                            ? FontWeight.bold
                            : FontWeight.w500,
                        fontSize: 13.5,
                        color: _tglSelesai != null
                            ? AppColors.textPrimary
                            : Colors.grey[600],
                      ),
                    ),
                  ],
                ),
                Icon(
                  Icons.edit,
                  color: _tglSelesai != null
                      ? AppColors.primary
                      : Colors.grey[500],
                  size: 18,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        const Text(
          'Target Unit per Jadwal:',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
        ),
        const SizedBox(height: 8),
        _optionCard(
          title: '(Otomatis) Semua Unit Aktif',
          desc:
              'Mencakup seluruh unit aktif ($_maxTargetUnit unit) & unit baru yang ditambahkan nanti.',
          isSelected: _isAutoTarget,
          onTap: () => setState(() => _isAutoTarget = true),
        ),
        const SizedBox(height: 6),
        _optionCard(
          title: '(Manual) target konstan',
          desc:
              'Target maintenance per jadwal (maksimal $_maxTargetUnit unit).',
          isSelected: !_isAutoTarget,
          onTap: () => setState(() => _isAutoTarget = false),
        ),
        if (!_isAutoTarget) ...[
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.grey[300]!),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Jumlah Target Unit:',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.remove, color: AppColors.primary),
                      onPressed: _targetManual > 1
                          ? () => setState(() {
                                _targetManual--;
                                _targetManualCtrl.text = _targetManual.toString();
                              })
                          : null,
                    ),
                    SizedBox(
                      width: 75,
                      child: TextField(
                        controller: _targetManualCtrl,
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                          color: AppColors.primary,
                        ),
                        decoration: InputDecoration(
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 8,
                          ),
                          filled: true,
                          fillColor: AppColors.primary.withValues(alpha: 0.1),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide.none,
                          ),
                        ),
                        onChanged: (val) {
                          final trimmed = val.trim();
                          if (trimmed.isEmpty) {
                            setState(() {
                              _targetManual = 1;
                            });
                            return;
                          }
                          final parsed = int.tryParse(trimmed);
                          if (parsed != null) {
                            if (parsed <= 0) {
                              _targetManualCtrl.text = '1';
                              _targetManualCtrl.selection = TextSelection.fromPosition(
                                const TextPosition(offset: 1),
                              );
                              AppNotifier.showWarning(
                                context,
                                'Target unit harus lebih dari 0 (minimal 1 unit)',
                              );
                              setState(() {
                                _targetManual = 1;
                              });
                            } else if (_maxTargetUnit > 0 && parsed > _maxTargetUnit) {
                              final textVal = _maxTargetUnit.toString();
                              _targetManualCtrl.text = textVal;
                              _targetManualCtrl.selection = TextSelection.fromPosition(
                                TextPosition(offset: textVal.length),
                              );
                              AppNotifier.showWarning(
                                context,
                                'Target unit tidak boleh melebihi jumlah inventaris aktif ($_maxTargetUnit unit)',
                              );
                              setState(() {
                                _targetManual = _maxTargetUnit;
                              });
                            } else {
                              setState(() {
                                _targetManual = parsed;
                              });
                            }
                          }
                        },
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.add, color: AppColors.primary),
                      onPressed: (_maxTargetUnit > 0 && _targetManual < _maxTargetUnit) || _maxTargetUnit == 0
                          ? () => setState(() {
                                _targetManual++;
                                _targetManualCtrl.text = _targetManual.toString();
                              })
                          : null,
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (_maxTargetUnit > 0) ...[
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                '* Jumlah unit $_selectedJenisNama pada pabrik $pabrikDisplay: $_maxTargetUnit.',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey[600],
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          ],
        ],
        const SizedBox(height: 20),
        const Text(
          'Catatan Jadwal (Opsional):',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _notesCtrl,
          maxLines: 3,
          style: const TextStyle(fontSize: 13, color: AppColors.textPrimary),
          decoration: InputDecoration(
            hintText:
                'Misal: Wajib foto kondisi fisik sebelum & sesudah, gunakan oli standar, dan lain-lain...',
            hintStyle: TextStyle(fontSize: 12, color: Colors.grey[400]),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
            ),
            filled: true,
            fillColor: Colors.grey[50],
            contentPadding: const EdgeInsets.all(14),
          ),
        ),
      ],
    );
  }

  // --- STEP 8: Ringkasan AI & Reviu ---
  Widget _buildStep8Summary() {
    final draft = _buildDraftData();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _questionHeader(
          '8. Ringkasan & Konfirmasi Jadwal',
          subtitle: 'Periksa kembali seluruh detail jadwal sebelum disimpan.',
          icon: Icons.check_circle,
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.05),
                blurRadius: 14,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.primary.withValues(alpha: 0.12),
                      AppColors.primary.withValues(alpha: 0.04),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: const BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.auto_awesome,
                          color: Colors.white, size: 16),
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Ringkasan Jadwal (AI Assistant)',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: AppColors.primary,
                            ),
                          ),
                          Text(
                            'Periksa kembali data sebelum menyimpan',
                            style: TextStyle(
                              fontSize: 11,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _summaryRowWithIcon(
                icon: Icons.notes,
                label: 'Judul Jadwal',
                value: draft['jdwJudul'],
              ),
              _summaryRowWithIcon(
                icon: Icons.category,
                label: 'Divisi Pelaksana',
                value: draft['jdwDivisi'] ?? 'GA',
              ),
              _summaryRowWithIcon(
                icon: Icons.category,
                label: 'Jenis Inventaris',
                value: (draft['jdwInvJenis'] ?? draft['jdwJenisNama'] ?? '-')
                    .toString(),
              ),
              _summaryRowWithIcon(
                icon: Icons.location_on,
                label: 'Pabrik / Lokasi',
                value: draft['jdwPabrikDisplay'],
              ),
              _summaryRowWithIcon(
                icon: Icons.person,
                label: 'Pelaksana / User',
                value: draft['jdwUserNama'],
              ),
              _summaryRowWithIcon(
                icon: Icons.event,
                label: 'Frekuensi',
                value: draft['jdwFrekuensi'],
              ),
              _summaryRowWithIcon(
                icon: Icons.schedule,
                label: 'Gap Realisasi',
                value: _jdwGapLabel,
              ),
              _summaryRowWithIcon(
                icon: Icons.tune,
                label: 'Gap per Inventaris',
                value: _shouldUpdateJenisGap
                    ? '$_jenisGapHari hari (Akan memperbarui Master)'
                    : '$_currentJenisGapHari hari (Bawaan Master)',
              ),
              _summaryRowWithIcon(
                icon: Icons.event,
                label: 'Tanggal Mulai',
                value: draft['jdwTglMulaiDisplay'],
              ),
              _summaryRowWithIcon(
                icon: Icons.event,
                label: 'Tanggal Selesai',
                value: draft['jdwTglSelesaiDisplay'],
              ),
              _summaryRowWithIcon(
                icon: Icons.tune,
                label: 'Target Unit',
                value: _isAutoTarget
                    ? 'Mode Otomatis ($_maxTargetUnit unit)'
                    : 'Mode Manual (${draft['jdwTarget']} unit)',
              ),
              if (draft['jdwNotes'] != null)
                _summaryRowWithIcon(
                  icon: Icons.notes,
                  label: 'Catatan Jadwal',
                  value: draft['jdwNotes'],
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  widget.onOpenFullForm(draft);
                },
                icon: const Icon(Icons.edit, size: 18),
                label: const Text('Edit Jadwal Manual'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  side: const BorderSide(color: AppColors.primary),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _questionHeader(
    String title, {
    String? subtitle,
    required IconData icon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 18, color: AppColors.primary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  height: 1.3,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          ],
        ),
        if (subtitle != null && subtitle.isNotEmpty) ...[
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.only(left: 42),
            child: Text(
              subtitle,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
                height: 1.35,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _optionCard({
    required String title,
    required String desc,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withValues(alpha: 0.08)
              : Colors.grey[50],
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? AppColors.primary : Colors.grey[300]!,
            width: isSelected ? 1.5 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.08),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 4,
              height: 36,
              decoration: BoxDecoration(
                color: isSelected ? AppColors.primary : Colors.transparent,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                      color: isSelected
                          ? AppColors.primary
                          : AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    desc,
                    style: TextStyle(
                      fontSize: 11.5,
                      color: Colors.grey[600],
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              isSelected
                  ? Icons.check_circle
                  : Icons.circle_outlined,
              color: isSelected ? AppColors.primary : Colors.grey[400],
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  Widget _summaryRowWithIcon({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: AppColors.primary),
          const SizedBox(width: 8),
          SizedBox(
            width: 130,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[700],
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const Text(': ', style: TextStyle(fontWeight: FontWeight.bold)),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
