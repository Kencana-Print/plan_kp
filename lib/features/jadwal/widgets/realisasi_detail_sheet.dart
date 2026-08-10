import 'dart:convert';

import 'package:flutter/material.dart';

import '../../../core/utils/api_client.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/utils/responsive_sheet.dart';
import '../models/realisasi_model.dart';


class RealisasiDetailSheet {
  static Future<void> show(
    BuildContext context, {
    required RealisasiModel detail,
    required String title,
    List<RealisasiModel> riwayatRealisasi = const [],
    void Function(RealisasiModel)? onTapRiwayat,
  }) async {
    await showResponsiveSheet(
      context,
      maxDesktopWidth: 600,
      builder: (_) => _RealisasiDetailContent(
        detail: detail,
        title: title,
        riwayatRealisasi: riwayatRealisasi,
        onTapRiwayat: onTapRiwayat,
      ),
    );

  }

  static Widget _detailRow(String label, String value) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 110,
              child: Text(
                label,
                style: const TextStyle(
                    fontSize: 12, color: AppColors.textSecondary),
              ),
            ),
            Expanded(
              child: Text(
                value,
                style:
                    const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
      );

  static Widget _ttdRow(String? ttdData) {
    final raw = (ttdData ?? '').trim();
    if (raw.isEmpty) return _detailRow('TTD', 'Belum ada');

    final normalized = raw.contains(',') ? raw.split(',').last : raw;
    try {
      final bytes = base64Decode(normalized);
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(
              width: 110,
              child: Text(
                'TTD',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
            ),
            Expanded(
              child: Container(
                height: 100,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.border),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Image.memory(bytes, fit: BoxFit.contain),
              ),
            ),
          ],
        ),
      );
    } catch (_) {
      return _detailRow('TTD', 'Data TTD tidak valid');
    }
  }

  static Widget _fotoRow(String? realFoto) {
    final url = (realFoto ?? '').trim();
    if (url.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(
            width: 110,
            child: Text(
              'Foto Bukti',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
          ),
          Expanded(
            child: Container(
              height: 180,
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.border),
                borderRadius: BorderRadius.circular(12),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(11),
                child: Image.network(
                  url,
                  fit: BoxFit.cover,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return const Center(
                      child: CircularProgressIndicator(strokeWidth: 2),
                    );
                  },
                  errorBuilder: (context, error, stackTrace) {
                    return const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.broken_image_outlined, color: Colors.grey, size: 36),
                          SizedBox(height: 4),
                          Text(
                            'Gagal memuat gambar',
                            style: TextStyle(fontSize: 11, color: Colors.grey),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Stateful widget agar bisa navigate riwayat tanpa menutup sheet
class _RealisasiDetailContent extends StatefulWidget {
  final RealisasiModel detail;
  final String title;
  final List<RealisasiModel> riwayatRealisasi;
  final void Function(RealisasiModel)? onTapRiwayat;

  const _RealisasiDetailContent({
    required this.detail,
    required this.title,
    required this.riwayatRealisasi,
    this.onTapRiwayat,
  });

  @override
  State<_RealisasiDetailContent> createState() =>
      _RealisasiDetailContentState();
}

class _RealisasiDetailContentState extends State<_RealisasiDetailContent> {
  late RealisasiModel _currentDetail;
  bool _loadingDetail = false;

  @override
  void initState() {
    super.initState();
    _currentDetail = widget.detail;
    if (_currentDetail.hasilChecklist.isEmpty) {
      _loadFullDetail();
    }
  }

  Future<void> _loadFullDetail() async {
    if (_loadingDetail) return;
    setState(() => _loadingDetail = true);
    try {
      final res = await ApiClient.get('${ApiConfig.realisasi}/${widget.detail.realId}');
      if (res['data'] != null && mounted) {
        setState(() {
          _currentDetail = RealisasiModel.fromJson(res['data']);
        });
      }
    } catch (_) {
      // Ignored
    } finally {
      if (mounted) {
        setState(() => _loadingDetail = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final detail = _currentDetail;
    final riwayat = widget.riwayatRealisasi;

    return DraggableScrollableSheet(
      initialChildSize: 0.8,
      maxChildSize: 0.95,
      minChildSize: 0.5,
      builder: (_, ctrl) => Container(
        decoration: const BoxDecoration(
          color: AppColors.bgGray,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: ListView(
          controller: ctrl,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            // Drag handle
            Center(
              child: Container(
                width: 42,
                height: 4,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Title
            Text(
              widget.title,
              style:
                  const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),

            // === Detail Realisasi Terakhir ===
            RealisasiDetailSheet._detailRow(
                'Jadwal', detail.jadwal?['jdw_judul'] ?? '-'),
            RealisasiDetailSheet._detailRow(
              'Unit',
              '${detail.invNama} (${detail.invSerialNumber})',
            ),
            RealisasiDetailSheet._detailRow(
                'Tanggal', DateFormatter.toDisplay(detail.realTgl)),

            RealisasiDetailSheet._detailRow('Status', detail.realStatus),
            if (detail.realJamMulai != null && detail.realJamMulai!.isNotEmpty)
              RealisasiDetailSheet._detailRow(
                  'Jam Mulai', detail.realJamMulai ?? ''),
            if (detail.realJamSelesai != null && detail.realJamSelesai!.isNotEmpty)
              RealisasiDetailSheet._detailRow(
                  'Jam Selesai', detail.realJamSelesai ?? ''),
            if (detail.realKondisiAkhir != null && detail.realKondisiAkhir!.isNotEmpty)
              RealisasiDetailSheet._detailRow(
                  'Kondisi Akhir', detail.realKondisiAkhir ?? ''),
            if (detail.realKeterangan != null && detail.realKeterangan!.isNotEmpty)
              RealisasiDetailSheet._detailRow(
                  'Keterangan', detail.realKeterangan ?? ''),
            RealisasiDetailSheet._detailRow(
              'PIC',
              (detail.realTtdPicNama ?? '').trim().isEmpty
                  ? '-'
                  : (detail.realTtdPicNama ?? '').trim(),
            ),
            RealisasiDetailSheet._ttdRow(detail.realTtdData),
            RealisasiDetailSheet._fotoRow(detail.realFoto),
            const SizedBox(height: 12),

            // === Checklist ===
            const Text(
              'Checklist',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            if (_loadingDetail)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
              )
            else if (detail.hasilChecklist.isEmpty)
              const Text('-',
                  style: TextStyle(color: AppColors.textSecondary))
            else
              ...([...detail.hasilChecklist]
                    ..sort((a, b) => a.urutan.compareTo(b.urutan)))
                  .map(
                (h) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '• ${h.itemNama} (${h.hcHasil})${(h.hcKondisi ?? '').isNotEmpty ? ' - ${h.hcKondisi}' : ''}',
                        style: const TextStyle(fontSize: 13),
                      ),
                      if ((h.hcKeterangan ?? '').trim().isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(left: 12, top: 2),
                          child: Text(
                            'Keterangan: ${(h.hcKeterangan ?? '').trim()}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),

            // === Riwayat Realisasi Sebelumnya ===
            if (riwayat.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Divider(color: AppColors.border),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(Icons.history_rounded,
                      size: 18, color: AppColors.primary),
                  const SizedBox(width: 8),
                  Text(
                    'Riwayat Realisasi (${riwayat.length})',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              ...riwayat.asMap().entries.map((entry) {
                final idx = entry.key;
                final item = entry.value;
                final isCurrentlyViewed = item.realId == detail.realId;
                final teknisiNama =
                    (item.teknisi?['user_nama'] ?? '-').toString();

                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: isCurrentlyViewed
                        ? AppColors.primarySoft
                        : AppColors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isCurrentlyViewed
                          ? AppColors.primary.withOpacity(0.3)
                          : AppColors.border,
                    ),
                  ),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: isCurrentlyViewed
                        ? null
                        : () {
                            if (widget.onTapRiwayat != null) {
                              widget.onTapRiwayat!(item);
                            }
                          },
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          // Nomor urut
                          Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              color: isCurrentlyViewed
                                  ? AppColors.primary
                                  : AppColors.bgGray,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Center(
                              child: Text(
                                '${idx + 1}',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: isCurrentlyViewed
                                      ? AppColors.white
                                      : AppColors.textSecondary,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      DateFormatter.toDisplay(item.realTgl),
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: isCurrentlyViewed
                                            ? AppColors.primary
                                            : AppColors.textPrimary,
                                      ),
                                    ),
                                    if (isCurrentlyViewed) ...[
                                      const SizedBox(width: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 6, vertical: 1),
                                        decoration: BoxDecoration(
                                          color: AppColors.primary
                                              .withOpacity(0.15),
                                          borderRadius:
                                              BorderRadius.circular(4),
                                        ),
                                        child: const Text(
                                          'DILIHAT',
                                          style: TextStyle(
                                            fontSize: 8,
                                            fontWeight: FontWeight.w800,
                                            color: AppColors.primary,
                                            letterSpacing: 0.5,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Oleh: $teknisiNama',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // Status + Kondisi
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: item.realStatus == 'Selesai'
                                      ? AppColors.success.withOpacity(0.1)
                                      : AppColors.warning.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  item.realStatus,
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: item.realStatus == 'Selesai'
                                        ? AppColors.success
                                        : AppColors.warning,
                                  ),
                                ),
                              ),
                              if ((item.realKondisiAkhir ?? '').isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Text(
                                  item.realKondisiAkhir ?? '',
                                  style: const TextStyle(
                                    fontSize: 10,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ],
                          ),
                          if (!isCurrentlyViewed)
                            const Padding(
                              padding: EdgeInsets.only(left: 4),
                              child: Icon(
                                Icons.chevron_right_rounded,
                                size: 18,
                                color: AppColors.textSecondary,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
            ],
          ],
        ),
      ),
    );
  }
}
