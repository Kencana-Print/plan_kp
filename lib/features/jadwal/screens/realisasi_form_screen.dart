import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/utils/responsive_sheet.dart';
import '../../../core/widgets/app_notifier.dart';

import '../models/checklist_hasil_model.dart';
import '../models/realisasi_model.dart';
import '../providers/jadwal_provider.dart';

// ═══════════════════════════════════════════════════════════════
//  REALISASI FORM SCREEN
//  args: { jadwalId, invJenis, invId?, invNama? }
// ═══════════════════════════════════════════════════════════════
class RealisasiFormScreen extends StatefulWidget {
  final Map<String, dynamic> args;
  const RealisasiFormScreen({super.key, required this.args});
  @override
  State<RealisasiFormScreen> createState() => _RealisasiFormScreenState();
}

class _RealisasiFormScreenState extends State<RealisasiFormScreen> {
  final _ketCtrl = TextEditingController();
  String _kondisi = 'Baik';
  List<ChecklistInputModel> _checklistItems = [];
  bool _loadingTemplate = true;
  bool _submitting = false;
  String? _invNo;
  String? _invMerk;
  String? _invKondisiAwal;
  String? _invPicNama;
  List<int>? _imageBytes;
  String? _imageName;
  int? _realId;

  RealisasiModel? _lastTemuan;

  static const _kondisiList = ['Baik', 'Perlu Perhatian', 'Rusak'];
  static const _allowedImageExt = ['jpg', 'jpeg', 'png', 'webp'];

  int get _jadwalId => widget.args['jadwalId'];
  int get _invJenisId => widget.args['invJenisId'] ?? widget.args['invJenis'];
  int? get _invId => widget.args['invId'];
  String get _invNama => widget.args['invNama'] ?? '';

  @override
  void initState() {
    super.initState();
    _realId = widget.args['realId'];
    _invNo = widget.args['invNo'];
    _invMerk = widget.args['invMerk'];
    _invKondisiAwal = widget.args['invKondisi'];
    _invPicNama = widget.args['invPicNama'];
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadTemplate();
      _fetchLastTemuan();
    });
  }

  Future<void> _fetchLastTemuan() async {
    if (_invId == null) return;
    final p = context.read<JadwalProvider>();
    final temuan = await p.fetchLastTemuanByInventaris(_invId!);
    if (mounted && temuan != null) {
      setState(() {
        _lastTemuan = temuan;
      });
    }
  }

  final _scrollController = ScrollController();
  static const _kScrollbarThickness = 8.0;
  static const _kScrollbarRadius = Radius.circular(100);
  static const _kScrollbarMargin = 3.0;

  @override
  void dispose() {
    _scrollController.dispose();
    _ketCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadTemplate() async {
    final p = context.read<JadwalProvider>();
    try {
      if (_realId != null) {
        // Melanjutkan draft realisasi yang sudah ada
        await p.fetchRealisasiDetail(_realId!);
        final detail = p.realisasiDetail;
        if (detail != null && mounted) {
          setState(() {
            _kondisi = detail.realKondisiAkhir ?? 'Baik';
            _ketCtrl.text = detail.realKeterangan ?? '';
            _checklistItems = detail.hasilChecklist.map((hc) {
              return ChecklistInputModel(
                ctId: hc.hcCtId,
                ctItem: hc.itemNama,
                ctUrutan: hc.urutan,
              )
                ..hasil = hc.hcHasil
                ..kondisi = hc.hcKondisi
                ..keterangan = hc.hcKeterangan;
            }).toList();
            _loadingTemplate = false;
          });
          return;
        }
      }

      // Alur normal: load template checklist baru
      final items = await p.fetchTemplate(_invJenisId);

      if (!mounted) return;
      setState(() {
        _checklistItems = items;
        _loadingTemplate = false;
      });

      final templateError = p.error;
      if (items.isEmpty && templateError != null && templateError.isNotEmpty) {
        await AppNotifier.showError(
            context, 'Gagal memuat template checklist: $templateError');
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loadingTemplate = false;
        _checklistItems = [];
      });
      await AppNotifier.showError(context, 'Gagal memuat data realisasi');
    }
  }

  Future<void> _retryLoadTemplate() async {
    if (_loadingTemplate) return;
    setState(() => _loadingTemplate = true);
    await _loadTemplate();
  }

  Future<void> _proceedToTtd() async {
    if (_checklistItems.isEmpty) {
      await AppNotifier.showWarning(context, 'Template checklist kosong');
      return;
    }

    final belumDipilih = _checklistItems.where((item) =>
        item.hasil != 'OK' && item.hasil != 'NK' && item.hasil != 'N/A');
    if (belumDipilih.isNotEmpty) {
      await AppNotifier.showWarning(context,
          'Pilih hasil OK/NK/Tidak Ada untuk semua item checklist terlebih dahulu');
      return;
    }

    final nkTanpaKondisi = _checklistItems.where((item) =>
        item.hasil == 'NK' && (item.kondisi == null || item.kondisi!.isEmpty));
    if (nkTanpaKondisi.isNotEmpty) {
      await AppNotifier.showWarning(
          context, 'Pilih kondisi untuk setiap item yang tidak sesuai (NK)');
      return;
    }

    final ttdData = await _openTtdPopup();
    if (ttdData == null || !mounted) {
      return;
    }

    final p = context.read<JadwalProvider>();
    final now = DateTime.now();
    final tgl = DateFormatter.toApi(now);
    final jamMulai =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:00';

    final body = {
      'real_jadwal_id': _jadwalId,
      'real_inv_id': _invId,
      'real_tgl': tgl,
      'real_jam_mulai': jamMulai,
      'real_kondisi_akhir': _kondisi,
      'real_keterangan':
          _ketCtrl.text.trim().isEmpty ? null : _ketCtrl.text.trim(),
    };

    setState(() => _submitting = true);

    int targetRealId;
    if (_realId != null) {
      targetRealId = _realId!;
      final okUpdate = await p.updateRealisasi(targetRealId, {
        'real_kondisi_akhir': _kondisi,
        'real_keterangan': _ketCtrl.text.trim().isEmpty ? null : _ketCtrl.text.trim(),
      });
      if (!okUpdate) {
        if (!mounted) return;
        setState(() => _submitting = false);
        await AppNotifier.showError(context, p.error ?? 'Gagal memperbarui realisasi');
        return;
      }
    } else {
      final real = await p.createRealisasi(body);
      if (real == null) {
        if (!mounted) return;
        setState(() => _submitting = false);
        await AppNotifier.showError(context, p.error ?? 'Gagal membuat data realisasi');
        return;
      }
      targetRealId = real.realId;
    }

    final okChecklist = await p.saveChecklist(targetRealId, _checklistItems);
    if (!mounted) return;
    if (!okChecklist) {
      setState(() => _submitting = false);
      await AppNotifier.showError(
          context, p.error ?? 'Gagal menyimpan checklist realisasi');
      return;
    }

    // Jika user mengupload foto bukti (lakukan sebelum TTD agar status masih 'Draft')
    if (_imageBytes != null && _imageName != null) {
      final okFoto = await p.uploadRealisasiFoto(
        targetRealId,
        bytes: _imageBytes,
        filename: _imageName,
      );
      if (!mounted) return;
      if (!okFoto) {
        setState(() => _submitting = false);
        await AppNotifier.showError(
            context, p.error ?? 'Gagal mengunggah foto bukti realisasi');
        return;
      }
    }

    final okTtd = await p.saveTtd(
      targetRealId,
      ttdData.picNama,
      'data:image/png;base64,${ttdData.signatureBase64}',
    );
    if (!mounted) return;
    if (!okTtd) {
      setState(() => _submitting = false);
      await AppNotifier.showError(
          context, p.error ?? 'Gagal menyimpan tanda tangan');
      return;
    }

    setState(() => _submitting = false);
    await AppNotifier.showSuccess(context, 'Realisasi berhasil diselesaikan');
    if (!mounted) return;
    Navigator.pop(context);
  }

  Future<void> _saveAsDraft() async {
    if (_checklistItems.isEmpty) {
      await AppNotifier.showWarning(context, 'Template checklist kosong');
      return;
    }

    final belumDipilih = _checklistItems.where((item) =>
        item.hasil != 'OK' && item.hasil != 'NK' && item.hasil != 'N/A');
    if (belumDipilih.isNotEmpty) {
      await AppNotifier.showWarning(context,
          'Pilih hasil OK/NK/Tidak Ada untuk semua item checklist terlebih dahulu');
      return;
    }

    final nkTanpaKondisi = _checklistItems.where((item) =>
        item.hasil == 'NK' && (item.kondisi == null || item.kondisi!.isEmpty));
    if (nkTanpaKondisi.isNotEmpty) {
      await AppNotifier.showWarning(
          context, 'Pilih kondisi untuk setiap item yang tidak sesuai (NK)');
      return;
    }

    final p = context.read<JadwalProvider>();
    final now = DateTime.now();
    final tgl = DateFormatter.toApi(now);
    final jamMulai =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:00';

    final body = {
      'real_jadwal_id': _jadwalId,
      'real_inv_id': _invId,
      'real_tgl': tgl,
      'real_jam_mulai': jamMulai,
      'real_kondisi_akhir': _kondisi,
      'real_keterangan':
          _ketCtrl.text.trim().isEmpty ? null : _ketCtrl.text.trim(),
    };

    setState(() => _submitting = true);

    int targetRealId;
    if (_realId != null) {
      targetRealId = _realId!;
      final okUpdate = await p.updateRealisasi(targetRealId, {
        'real_kondisi_akhir': _kondisi,
        'real_keterangan': _ketCtrl.text.trim().isEmpty ? null : _ketCtrl.text.trim(),
      });
      if (!okUpdate) {
        if (!mounted) return;
        setState(() => _submitting = false);
        await AppNotifier.showError(context, p.error ?? 'Gagal memperbarui realisasi');
        return;
      }
    } else {
      final real = await p.createRealisasi(body);
      if (real == null) {
        if (!mounted) return;
        setState(() => _submitting = false);
        await AppNotifier.showError(context, p.error ?? 'Gagal membuat data realisasi');
        return;
      }
      targetRealId = real.realId;
    }

    final okChecklist = await p.saveChecklist(targetRealId, _checklistItems);
    if (!mounted) return;
    if (!okChecklist) {
      setState(() => _submitting = false);
      await AppNotifier.showError(
          context, p.error ?? 'Gagal menyimpan checklist realisasi');
      return;
    }

    if (_imageBytes != null && _imageName != null) {
      final okFoto = await p.uploadRealisasiFoto(
        targetRealId,
        bytes: _imageBytes,
        filename: _imageName,
      );
      if (!mounted) return;
      if (!okFoto) {
        setState(() => _submitting = false);
        await AppNotifier.showError(
            context, p.error ?? 'Gagal mengunggah foto bukti realisasi');
        return;
      }
    }

    setState(() => _submitting = false);
    await AppNotifier.showSuccess(context, 'Realisasi berhasil disimpan sebagai Draft');
    if (!mounted) return;
    Navigator.pop(context);
  }

  Future<_TtdSubmitData?> _openTtdPopup() async {
    return showDialog<_TtdSubmitData>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _TtdDialog(
        defaultPicNama: _invPicNama,
        checklistItems: _checklistItems,
      ),
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: source,
        maxWidth: 1280,
        maxHeight: 1280,
        imageQuality: 80,
      );
      if (picked != null) {
        final ext = picked.name.split('.').last.toLowerCase();
        if (!_allowedImageExt.contains(ext)) {
          if (mounted) {
            AppNotifier.showWarning(context, 'Format gambar harus .jpg, .jpeg, .png, atau .webp');
          }
          return;
        }
        final bytes = await picked.readAsBytes();
        final safeName = picked.name.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
        setState(() {
          _imageBytes = bytes.toList();
          _imageName = safeName.contains('.') ? safeName : '$safeName.$ext';
        });
      }
    } catch (e) {
      debugPrint('[PICK IMAGE ERROR] $e');
      if (mounted) {
        AppNotifier.showError(context, 'Gagal mengambil gambar: $e');
      }
    }
  }

  void _showImageSourceDialog() {
    showResponsiveSheet(
      context,
      maxDesktopWidth: 420,
      builder: (_) => Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'Pilih Sumber Foto Bukti',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt_outlined,
                    color: AppColors.primary),
                title: const Text('Kamera (Ambil Foto Langsung)'),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.camera);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined,
                    color: AppColors.primary),
                title: const Text('Galeri (Pilih dari Foto Perangkat)'),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.gallery);
                },
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLastTemuanBanner() {
    if (_lastTemuan == null) return const SizedBox.shrink();

    final tglStr = _lastTemuan!.realTgl.isNotEmpty
        ? DateFormatter.formatMessageDates(_lastTemuan!.realTgl)
        : '';
    final ketStr = (_lastTemuan!.realKeterangan ?? '').trim();
    final kondisiStr = _lastTemuan!.realKondisiAkhir ?? 'Perlu Perhatian';

    const warningColor = Color(0xFFB45309);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.history_rounded, color: warningColor, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Temuan Terakhir Inventaris ${tglStr.isNotEmpty ? "($tglStr)" : ""}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: warningColor,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  kondisiStr,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: warningColor,
                  ),
                ),
              ),
            ],
          ),
          if (ketStr.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              '"$ketStr"',
              style: const TextStyle(
                fontSize: 11.5,
                fontStyle: FontStyle.italic,
                color: AppColors.textPrimary,
              ),
            ),
          ],
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: InkWell(
              onTap: () {
                final copyText = ketStr.isNotEmpty
                    ? ketStr
                    : 'Temuan sebelumnya belum teratasi: $kondisiStr';

                if (_ketCtrl.text.trim().isEmpty) {
                  _ketCtrl.text = copyText;
                } else if (!_ketCtrl.text.contains(copyText)) {
                  _ketCtrl.text = '${_ketCtrl.text.trim()}\n\n[Temuan Sebelumnya]: $copyText';
                }

                if (kondisiStr == 'Perlu Perhatian' || kondisiStr == 'Rusak') {
                  setState(() => _kondisi = kondisiStr);
                }

                AppNotifier.showInfo(
                  context,
                  'Catatan temuan sebelumnya berhasil disalin!',
                );
              },
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.warning,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.content_copy_rounded, size: 13, color: Colors.white),
                    SizedBox(width: 6),
                    Text(
                      'Gunakan Catatan Temuan Ini',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPhotoSection() {
    return _buildSectionCard(
      title: 'Bukti Foto Realisasi (opsional)',
      subtitle:
          'Tambahkan foto kondisi unit sebagai bukti pendukung penyelesaian maintenance.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_imageBytes == null)
            InkWell(
              onTap: _showImageSourceDialog,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(vertical: 36, horizontal: 16),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.border,
                    style: BorderStyle.solid,
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: const BoxDecoration(
                        color: AppColors.primarySoft,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.camera_alt_outlined,
                        color: AppColors.primary,
                        size: 28,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Pilih / Ambil Foto Bukti',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Mendukung Kamera langsung atau Unggah dari Galeri',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            Stack(
              children: [
                Container(
                  width: double.infinity,
                  height: 240,
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(11),
                    child: Image.memory(
                      Uint8List.fromList(_imageBytes!),
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                Positioned(
                  top: 10,
                  right: 10,
                  child: Row(
                    children: [
                      // Ganti foto button
                      Material(
                        color: Colors.black.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(30),
                        child: InkWell(
                          onTap: _showImageSourceDialog,
                          borderRadius: BorderRadius.circular(30),
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            child: const Icon(
                              Icons.refresh,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Hapus foto button
                      Material(
                        color: Colors.red.withValues(alpha: 0.8),
                        borderRadius: BorderRadius.circular(30),
                        child: InkWell(
                          onTap: () {
                            setState(() {
                              _imageBytes = null;
                              _imageName = null;
                            });
                          },
                          borderRadius: BorderRadius.circular(30),
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            child: const Icon(
                              Icons.delete_outline,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Positioned(
                  bottom: 10,
                  left: 10,
                  right: 10,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.image_outlined,
                          color: Colors.white,
                          size: 14,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            _imageName ?? 'Foto Realisasi',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                        Text(
                          '${(_imageBytes!.length / 1024).toStringAsFixed(1)} KB',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: Text(_invNama.isNotEmpty ? _invNama : 'Form Realisasi'),
        centerTitle: false,
      ),
      body: _loadingTemplate
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _buildProgressHeader(),
                Expanded(child: _buildForm()),
              ],
            ),
    );
  }

  Widget _buildProgressHeader() {
    if (_checklistItems.isEmpty) return const SizedBox.shrink();
    int total = _checklistItems.length;
    int filled = _checklistItems.where((item) => item.hasil == 'OK' || item.hasil == 'NK' || item.hasil == 'N/A').length;
    double progress = total == 0 ? 0 : filled / total;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Checklist',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
              ),
              Text(
                '$filled dari $total terisi',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.primary),
              ),
            ],
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: progress,
            backgroundColor: AppColors.primarySoft,
            color: progress == 1.0 ? AppColors.success : AppColors.primary,
            minHeight: 6,
            borderRadius: BorderRadius.circular(3),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtonsCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Consumer<JadwalProvider>(
        builder: (_, p, __) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Pilih simpan sebagai Draft (Tunda TTD) atau lanjutkan Tanda Tangan PIC untuk menyelesaikan maintenance.',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: p.loading || _submitting ? null : _saveAsDraft,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      minimumSize: const Size(double.infinity, 48),
                      side: const BorderSide(color: AppColors.primary, width: 1.5),
                      foregroundColor: AppColors.primary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: p.loading || _submitting
                        ? const SizedBox(
                            height: 16,
                            width: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.save_outlined, size: 18),
                    label: const Text('Simpan Draft', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: p.loading || _submitting ? null : _proceedToTtd,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.success,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      minimumSize: const Size(double.infinity, 48),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    icon: p.loading || _submitting
                        ? const SizedBox(
                            height: 16,
                            width: 16,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                          )
                        : const Icon(Icons.draw_outlined, size: 18),
                    label: const Text('Tanda Tangan PIC', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildForm() {
    final templateError = context.watch<JadwalProvider>().error;
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxContentWidth = AppBreakpoints.responsiveValue(
          context,
          mobile: constraints.maxWidth,
          tablet: constraints.maxWidth > 880 ? 860.0 : constraints.maxWidth,
          desktop: 1080.0,
        );
        return Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxContentWidth),
            child: RawScrollbar(
              controller: _scrollController,
              thumbVisibility: true,
              trackVisibility: false,
              thickness: _kScrollbarThickness,
              radius: _kScrollbarRadius,
              thumbColor: AppColors.primary.withValues(alpha: 0.55),
              minThumbLength: 48,
              crossAxisMargin: _kScrollbarMargin,
              mainAxisMargin: 10.0,
              interactive: true,
              child: ListView(
                controller: _scrollController,
                physics: const BouncingScrollPhysics(
                  parent: AlwaysScrollableScrollPhysics(),
                ),
                // Padding kanan lebih besar agar konten tidak tertutup thumb scrollbar
                padding: const EdgeInsets.fromLTRB(16, 16, 26, 32),
                children: [
                  _buildHeroCard(),
                  const SizedBox(height: 16),
                  _buildSectionCard(
                    title: 'Checklist Pemeriksaan',
                    subtitle:
                        'Centang hasil pemeriksaan sebelum realisasi diselesaikan.',
                    child: Column(
                      children: [
                        if (_checklistItems.isEmpty)
                          Card(
                            margin: EdgeInsets.zero,
                            color: AppColors.surface,
                            child: Padding(
                              padding: const EdgeInsets.all(20),
                              child: Column(children: [
                                const Icon(Icons.checklist_outlined,
                                    size: 36, color: AppColors.textSecondary),
                                const SizedBox(height: 8),
                                Text(
                                  (templateError != null &&
                                          templateError.isNotEmpty)
                                      ? 'Gagal memuat template checklist'
                                      : 'Tidak ada template checklist untuk jenis ini',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                      color: AppColors.textSecondary),
                                ),
                                if (templateError != null &&
                                    templateError.isNotEmpty) ...[
                                  const SizedBox(height: 6),
                                  Text(
                                    templateError,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                        fontSize: 12,
                                        color: AppColors.textSecondary),
                                  ),
                                ],
                                const SizedBox(height: 12),
                                OutlinedButton.icon(
                                  onPressed: _loadingTemplate
                                      ? null
                                      : _retryLoadTemplate,
                                  icon: _loadingTemplate
                                      ? const SizedBox(
                                          height: 14,
                                          width: 14,
                                          child: CircularProgressIndicator(
                                              strokeWidth: 2),
                                        )
                                      : const Icon(Icons.refresh_outlined,
                                          size: 16),
                                  label: Text(_loadingTemplate
                                      ? 'Memuat...'
                                      : 'Muat Ulang'),
                                ),
                              ]),
                            ),
                          )
                        else
                          ..._checklistItems.asMap().entries.map(
                                (e) => _ChecklistItemCard(
                                  item: e.value,
                                  index: e.key,
                                  onChanged: () => setState(() {}),
                                ),
                              ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildSectionCard(
                    title: 'Hasil Realisasi',
                    subtitle:
                        'Tentukan kondisi akhir unit dan tambahkan catatan bila ada temuan.',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Kondisi Akhir',
                            style: TextStyle(
                                fontWeight: FontWeight.w700, fontSize: 14)),
                        const SizedBox(height: 10),
                        Row(
                          children: _kondisiList.map((k) {
                            final selected = _kondisi == k;
                            return Expanded(
                              child: Padding(
                                padding: EdgeInsets.only(
                                    right: k == _kondisiList.last ? 0 : 8),
                                child: InkWell(
                                  onTap: () => setState(() => _kondisi = k),
                                  borderRadius: BorderRadius.circular(14),
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 180),
                                    padding:
                                        const EdgeInsets.symmetric(vertical: 12),
                                    decoration: BoxDecoration(
                                      color: selected
                                          ? _kondisiColor(k)
                                          : _kondisiColor(k)
                                              .withValues(alpha: 0.08),
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(
                                        color: selected
                                            ? _kondisiColor(k)
                                            : Colors.transparent,
                                      ),
                                    ),
                                    child: Center(
                                      child: Text(
                                        k,
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          color: selected
                                              ? Colors.white
                                              : _kondisiColor(k),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 18),
                        _buildLastTemuanBanner(),
                        const Text('Catatan',
                            style: TextStyle(
                                fontWeight: FontWeight.w700, fontSize: 14)),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _ketCtrl,
                          maxLines: 4,
                          decoration: const InputDecoration(
                            hintText:
                                'Tuliskan catatan atau temuan selama maintenance...',
                            alignLabelWithHint: true,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildPhotoSection(),
                  const SizedBox(height: 20),
                  _buildActionButtonsCard(),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeroCard() {
    final metaItems = <Widget>[];
    if ((_invNo ?? '').trim().isNotEmpty) {
      final displayNo = _invNo!.trim();
      metaItems.add(_metaChip(
        Icons.format_list_numbered_rounded,
        displayNo.toLowerCase().startsWith('sn:') ? displayNo : 'SN: $displayNo',
      ));
    }
    if ((_invMerk ?? '').trim().isNotEmpty) {
      metaItems.add(
        _metaChip(
            Icons.branding_watermark_outlined, _invMerk!.trim()),
      );
    }
    if ((_invKondisiAwal ?? '').trim().isNotEmpty) {
      metaItems.add(
          _metaChip(Icons.health_and_safety_outlined, _invKondisiAwal!.trim()));
    }

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppColors.primarySoft,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.fact_check_outlined,
                      color: AppColors.primary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _invNama.isNotEmpty ? _invNama : 'Form Realisasi',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            if (metaItems.isNotEmpty)
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: metaItems,
              ),
            const SizedBox(height: 14),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    String? subtitle,
    required Widget child,
  }) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(11),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
            const SizedBox(height: 14),
            child,
          ],
        ),
      ),
    );
  }

  Widget _metaChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.primary),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Color _kondisiColor(String k) {
    switch (k) {
      case 'Baik':
        return AppColors.success;
      case 'Perlu Perhatian':
        return const Color(0xFFF59E0B);
      case 'Rusak':
        return AppColors.danger;
      default:
        return AppColors.primary;
    }
  }
}

// ═══════════════════════════════════════════════════════════════
//  CHECKLIST ITEM CARD
// ═══════════════════════════════════════════════════════════════
class _ChecklistItemCard extends StatefulWidget {
  final ChecklistInputModel item;
  final int index;
  final VoidCallback onChanged;
  const _ChecklistItemCard(
      {required this.item, required this.index, required this.onChanged});
  @override
  State<_ChecklistItemCard> createState() => _ChecklistItemCardState();
}

class _ChecklistItemCardState extends State<_ChecklistItemCard> {
  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: AppColors.primarySoft,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                  child: Text('${item.ctUrutan}',
                      style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary))),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.ctItem,
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 14)),
                  if ((item.ctKeterangan ?? '').isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(item.ctKeterangan!,
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.textSecondary)),
                  ],
                ],
              ),
            ),
          ]),
          const SizedBox(height: 12),
          Row(
              children: ['OK', 'NK', 'N/A'].map((h) {
            final sel = item.hasil == h;
            Color color;
            String label;
            if (h == 'OK') {
              color = AppColors.success;
              label = 'OK';
            } else if (h == 'NK') {
              color = AppColors.danger;
              label = 'NK';
            } else {
              color = Colors.grey.shade600;
              label = 'Tidak Ada';
            }
            return Expanded(
                child: Padding(
              padding: const EdgeInsets.only(right: 6),
              child: InkWell(
                onTap: () {
                  setState(() {
                    item.hasil = h;
                    if (h != 'NK') item.kondisi = null;
                  });
                  widget.onChanged();
                },
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: sel ? color : color.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: sel ? color : Colors.transparent),
                  ),
                  child: Center(
                      child: Text(label,
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: sel ? Colors.white : color))),
                ),
              ),
            ));
          }).toList()),
          if (item.hasil != 'OK' && item.hasil != 'NK' && item.hasil != 'N/A') ...[
            const SizedBox(height: 8),
            const Text(
              'Pilih hasil pemeriksaan (OK/NK/Tidak Ada).',
              style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
            ),
          ],
          if (item.hasil == 'N/A') ...[
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: Colors.grey.shade600.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.remove_circle_outline,
                      size: 14, color: Colors.grey.shade600),
                  const SizedBox(width: 4),
                  Text('Item tidak ada di lapangan (N/A)',
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                ],
              ),
            ),
          ],
          if (item.hasil == 'OK') ...[
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: AppColors.success.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.check_circle_outline,
                      size: 14, color: AppColors.success),
                  SizedBox(width: 4),
                  Text('Sudah diperiksa dan sesuai standar',
                      style: TextStyle(fontSize: 11, color: AppColors.success)),
                ],
              ),
            ),
          ],
          if (item.hasil == 'NK') ...[
            const SizedBox(height: 10),
            const Text('Kondisi:',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
            const SizedBox(height: 6),
            Row(
                children: ['Baik', 'Sedang', 'Buruk'].map((k) {
              final sel = item.kondisi == k;
              return Padding(
                padding: const EdgeInsets.only(right: 6),
                child: InkWell(
                  onTap: () {
                    setState(() => item.kondisi = k);
                    widget.onChanged();
                  },
                  borderRadius: BorderRadius.circular(6),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                    decoration: BoxDecoration(
                      color: sel
                          ? AppColors.warning
                          : AppColors.warning.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                          color: sel ? AppColors.warning : Colors.transparent),
                    ),
                    child: Text(k,
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: sel ? Colors.white : AppColors.warning)),
                  ),
                ),
              );
            }).toList()),
          ],
        ]),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
//  TTD DIALOG
// ═══════════════════════════════════════════════════════════════
class _SignatureController extends ChangeNotifier {
  final List<List<Offset>> _strokes = [];
  List<Offset> _currentStroke = [];

  List<List<Offset>> get strokes => List.unmodifiable(_strokes);
  List<Offset> get currentStroke => List.unmodifiable(_currentStroke);
  bool get isEmpty => _strokes.isEmpty && _currentStroke.isEmpty;
  bool get isNotEmpty => !isEmpty;

  void startStroke(Offset point) {
    _currentStroke = [point];
    notifyListeners();
  }

  void updateStroke(Offset point) {
    if (_currentStroke.isNotEmpty) {
      final last = _currentStroke.last;
      if ((point - last).distanceSquared < 1.0) return;
    }
    _currentStroke.add(point);
    notifyListeners();
  }

  void endStroke() {
    if (_currentStroke.isNotEmpty) {
      _strokes.add(List.from(_currentStroke));
      _currentStroke = [];
      notifyListeners();
    }
  }

  void clear() {
    _strokes.clear();
    _currentStroke.clear();
    notifyListeners();
  }
}

class _TtdDialog extends StatefulWidget {
  final String? defaultPicNama;
  final List<ChecklistInputModel> checklistItems;
  const _TtdDialog({
    this.defaultPicNama,
    required this.checklistItems,
  });
  @override
  State<_TtdDialog> createState() => _TtdDialogState();
}

class _TtdDialogState extends State<_TtdDialog> {
  final _formKey = GlobalKey<FormState>();
  final _picCtrl = TextEditingController();
  final _sigController = _SignatureController();
  bool _submitting = false;
  bool _confirmSummary = false;

  @override
  void initState() {
    super.initState();
    _picCtrl.text = (widget.defaultPicNama ?? '').trim();
  }

  @override
  void dispose() {
    _picCtrl.dispose();
    _sigController.dispose();
    super.dispose();
  }

  void _clearCanvas() {
    _sigController.clear();
  }

  void _handleClose() {
    if (_submitting) {
      return;
    }
    Navigator.pop(context);
  }

  Future<String> _captureBase64() async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    const size = Size(320, 160);

    // background putih
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = Colors.white,
    );

    final linePaint = Paint()
      ..color = Colors.black
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    final dotPaint = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.fill;

    for (final stroke in _sigController.strokes) {
      if (stroke.isEmpty) continue;
      if (stroke.length == 1) {
        canvas.drawCircle(stroke.first, 1.5, dotPaint);
        continue;
      }
      final path = Path();
      path.moveTo(stroke.first.dx, stroke.first.dy);
      if (stroke.length == 2) {
        path.lineTo(stroke.last.dx, stroke.last.dy);
      } else {
        for (int i = 1; i < stroke.length - 1; i++) {
          final p0 = stroke[i];
          final p1 = stroke[i + 1];
          final midX = (p0.dx + p1.dx) / 2;
          final midY = (p0.dy + p1.dy) / 2;
          path.quadraticBezierTo(p0.dx, p0.dy, midX, midY);
        }
        path.lineTo(stroke.last.dx, stroke.last.dy);
      }
      canvas.drawPath(path, linePaint);
    }

    final picture = recorder.endRecording();
    final img = await picture.toImage(size.width.toInt(), size.height.toInt());
    final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
    return base64Encode(bytes!.buffer.asUint8List());
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    if (!_confirmSummary) {
      await AppNotifier.showWarning(
        context,
        'Harap setujui konfirmasi pemeriksaan dan kesiapan PIC sebelum menandatangani',
      );
      return;
    }
    if (_sigController.isEmpty) {
      await AppNotifier.showWarning(context, 'Tanda tangan belum dibuat');
      return;
    }

    setState(() => _submitting = true);
    final base64 = await _captureBase64();
    if (!mounted) {
      return;
    }
    setState(() => _submitting = false);
    Navigator.pop(
      context,
      _TtdSubmitData(
        picNama: _picCtrl.text.trim(),
        signatureBase64: base64,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_submitting,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop && _submitting) {
          setState(() => _submitting = false);
        }
      },
      child: Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                // header
                Row(children: [
                  const Expanded(
                      child: Text('Tanda Tangan PIC',
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.w700))),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: _submitting ? null : _handleClose,
                  ),
                ]),
                const SizedBox(height: 4),
                const Text(
                    'Isi nama PIC dan tanda tangan untuk menyelesaikan realisasi.',
                    style: TextStyle(
                        fontSize: 13, color: AppColors.textSecondary)),
                const SizedBox(height: 16),

                TextFormField(
                  controller: _picCtrl,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Nama PIC *',
                    hintText: 'Masukkan nama PIC',
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Nama PIC wajib diisi';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Rangkuman hasil checklist pemeriksaan (Hanya di FE)
                const Text(
                  'Rangkuman Hasil Pemeriksaan',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  constraints: const BoxConstraints(maxHeight: 140),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Scrollbar(
                    thumbVisibility: true,
                    child: ListView.separated(
                      shrinkWrap: true,
                      padding: const EdgeInsets.all(12),
                      itemCount: widget.checklistItems.length,
                      separatorBuilder: (_, __) => const Divider(height: 8),
                      itemBuilder: (context, index) {
                        final item = widget.checklistItems[index];
                        Color badgeColor;
                        String statusText;
                        if (item.hasil == 'OK') {
                          badgeColor = AppColors.success;
                          statusText = 'OK';
                        } else if (item.hasil == 'NK') {
                          badgeColor = AppColors.warning;
                          statusText = 'NK (${item.kondisi ?? "Sedang"})';
                        } else {
                          badgeColor = Colors.grey.shade600;
                          statusText = 'N/A';
                        }

                        return Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                item.ctItem,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textPrimary,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: badgeColor.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                statusText,
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w800,
                                  color: badgeColor,
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Checkbox Persetujuan Tunggal
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.primarySoft,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.15),
                    ),
                  ),
                  child: CheckboxListTile(
                    value: _confirmSummary,
                    onChanged: (val) {
                      setState(() => _confirmSummary = val ?? false);
                    },
                    title: const Text(
                      'Pernyataan Persetujuan PIC',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    subtitle: const Text(
                      'Saya menyatakan bahwa seluruh rangkuman pemeriksaan di atas telah sesuai.',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                        height: 1.3,
                      ),
                    ),
                    activeColor: AppColors.primary,
                    dense: true,
                    controlAffinity: ListTileControlAffinity.leading,
                  ),
                ),
                const SizedBox(height: 16),

                // canvas TTD
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Area Tanda Tangan',
                        style: TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w600)),
                    TextButton.icon(
                      onPressed: _clearCanvas,
                      icon: const Icon(Icons.refresh, size: 16),
                      label:
                          const Text('Ulang', style: TextStyle(fontSize: 12)),
                    ),
                  ],
                ),
                const SizedBox(height: 6),

                Container(
                  width: double.infinity,
                  height: 160,
                  decoration: BoxDecoration(
                    color: AppColors.white,
                    border: Border.all(color: AppColors.primary, width: 1.5),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Listener(
                      behavior: HitTestBehavior.opaque,
                      onPointerDown: (event) {
                        _sigController.startStroke(event.localPosition);
                      },
                      onPointerMove: (event) {
                        _sigController.updateStroke(event.localPosition);
                      },
                      onPointerUp: (_) {
                        _sigController.endStroke();
                      },
                      onPointerCancel: (_) {
                        _sigController.endStroke();
                      },
                      child: ListenableBuilder(
                        listenable: _sigController,
                        builder: (context, _) {
                          return CustomPaint(
                            painter: _SignaturePainter(
                              strokes: _sigController.strokes,
                              currentStroke: _sigController.currentStroke,
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),

                ListenableBuilder(
                  listenable: _sigController,
                  builder: (context, _) {
                    if (_sigController.isNotEmpty) return const SizedBox.shrink();
                    return const Padding(
                      padding: EdgeInsets.only(top: 6),
                      child: Center(
                        child: Text(
                          'Tanda tangan di area atas',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 20),

                Consumer<JadwalProvider>(
                  builder: (_, p, __) => ElevatedButton.icon(
                    onPressed: p.loading || _submitting ? null : _submit,
                    style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.success),
                    icon: p.loading || _submitting
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2))
                        : const Icon(Icons.check_circle_outline),
                    label: const Text('Selesaikan Realisasi'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
}

class _TtdSubmitData {
  final String picNama;
  final String signatureBase64;

  const _TtdSubmitData({
    required this.picNama,
    required this.signatureBase64,
  });
}

// ── Custom painter untuk TTD ───────────────────────────────────
class _SignaturePainter extends CustomPainter {
  final List<List<Offset>> strokes;
  final List<Offset> currentStroke;

  _SignaturePainter({
    required this.strokes,
    required this.currentStroke,
  });

  final _linePaint = Paint()
    ..color = Colors.black
    ..strokeWidth = 2.5
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round
    ..style = PaintingStyle.stroke;

  final _dotPaint = Paint()
    ..color = Colors.black
    ..style = PaintingStyle.fill;

  void _drawStrokePoints(Canvas canvas, List<Offset> points) {
    if (points.isEmpty) return;

    if (points.length == 1) {
      canvas.drawCircle(points.first, 1.5, _dotPaint);
      return;
    }

    final path = Path();
    path.moveTo(points.first.dx, points.first.dy);

    if (points.length == 2) {
      path.lineTo(points.last.dx, points.last.dy);
    } else {
      for (int i = 1; i < points.length - 1; i++) {
        final p0 = points[i];
        final p1 = points[i + 1];
        final midX = (p0.dx + p1.dx) / 2;
        final midY = (p0.dy + p1.dy) / 2;
        path.quadraticBezierTo(p0.dx, p0.dy, midX, midY);
      }
      path.lineTo(points.last.dx, points.last.dy);
    }

    canvas.drawPath(path, _linePaint);
  }

  @override
  void paint(Canvas canvas, Size size) {
    // garis panduan
    canvas.drawLine(
      Offset(16, size.height * 0.75),
      Offset(size.width - 16, size.height * 0.75),
      Paint()
        ..color = AppColors.border
        ..strokeWidth = 0.8,
    );
    for (final s in strokes) {
      _drawStrokePoints(canvas, s);
    }
    _drawStrokePoints(canvas, currentStroke);
  }

  @override
  bool shouldRepaint(covariant _SignaturePainter oldDelegate) => true;
}
