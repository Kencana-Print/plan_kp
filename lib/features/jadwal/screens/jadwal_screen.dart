// ignore_for_file: curly_braces_in_flow_control_structures, duplicate_ignore, deprecated_member_use

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/widgets/app_notifier.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/shimmer_loading.dart';
import '../../auth/providers/auth_provider.dart';
import '../../../features/master/providers/master_provider.dart';
import '../../../features/master/widgets/jenis_lookup_sheet.dart';
import '../../../features/master/models/jenis_model.dart';
import '../models/jadwal_model.dart';
import '../models/realisasi_model.dart';
import '../providers/jadwal_provider.dart';

const _kPageBg = AppColors.surface;

class JadwalScreen extends StatefulWidget {
  final int initialIndex;

  const JadwalScreen({super.key, this.initialIndex = 0});
  @override
  State<JadwalScreen> createState() => _JadwalScreenState();
}

class _JadwalScreenState extends State<JadwalScreen> {
  String? _selectedFrekuensi;
  bool _isGapGuideExpanded = false;
  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = '';


  // Logika pembantu periode (dipertahankan)
  int _isoWeekNumber(DateTime date) {
    final d = DateTime.utc(date.year, date.month, date.day);
    final day = d.weekday == 7 ? 7 : d.weekday;
    final thursday = d.add(Duration(days: 4 - day));
    final yearStart = DateTime.utc(thursday.year, 1, 1);
    return ((thursday.difference(yearStart).inDays) / 7).floor() + 1;
  }

  DateTime _dateOnly(DateTime date) =>
      DateTime(date.year, date.month, date.day);

  bool _isSameCurrentPeriod(RealisasiModel r, JadwalModel jadwal) {
    final now = DateTime.now();
    final frequency = jadwal.jdwFrekuensi;
    if (frequency == 'Harian') {
      final realDate = DateTime.tryParse(r.realTgl);
      return realDate != null && _dateOnly(realDate) == _dateOnly(now);
    }
    if (frequency == 'Mingguan') {
      return r.realTahun == now.year && r.realWeekNumber == _isoWeekNumber(now);
    }
    if (frequency == 'Bulanan') {
      return r.realTahun == now.year && r.realBulan == now.month;
    }
    return false;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadData());
    _searchCtrl.addListener(() {
      setState(() {
        _searchQuery = _searchCtrl.text.trim();
      });
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final auth = context.read<AuthProvider>();
    final jadwalProvider = context.read<JadwalProvider>();
    final masterProvider = context.read<MasterProvider>();
    final role = auth.user?['user_jabatan'];
    final isAdmin = role == 'admin' || role == 'manager';
    if (isAdmin) {
      await jadwalProvider.fetchJadwalByDivisi(status: 'Draft');
    } else {
      await jadwalProvider.fetchJadwalByUser(status: 'Draft');
    }
    if (!mounted) return;
    await masterProvider.fetchJenis();
    await masterProvider.fetchInventaris(showLoading: false);
  }

  // --- Logika Form & Action (Dipertahankan) ---
  Future<void> _openForm([JadwalModel? item]) async {
    final master = context.read<MasterProvider>();
    final auth = context.read<AuthProvider>();
    await master.fetchJenis(showLoading: false);
    await master.fetchPabrik();
    final role = auth.user?['user_jabatan'];
    final isManager = role == 'manager';
    final userDivisi = isManager ? null : (auth.user?['user_divisi'] ?? '');
    await master.fetchUsers(divisi: userDivisi, showLoading: false);
    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _JadwalForm(item: item),
    );
  }

  Future<void> _confirmSelesaikanJadwal(JadwalModel item) async {
    await AppNotifier.showConfirm(
      context,
      title: 'Hapus Jadwal',
      message: '${item.jdwJudul}?',
      onConfirm: () async {
        final ok = await context
            .read<JadwalProvider>()
            .updateStatusJadwal(item.jdwId, 'Selesai');
        if (ok && mounted) {
          await AppNotifier.showSuccess(
              context, 'Status jadwal berhasil diubah ke Selesai');
        }
      },
    );
  }

  void _openJadwalDetail(JadwalModel jadwal) {
    Navigator.pushNamed(context, AppRoutes.jadwalDetail,
        arguments: jadwal.jdwId);
  }

  Future<void> _handleRealisasiTap(JadwalModel jadwal) async {
    final p = context.read<JadwalProvider>();
    await p.fetchJadwalDetail(jadwal.jdwId);
    await p.fetchRealisasi(jadwalId: jadwal.jdwId);
    if (!mounted) return;

    final inventarisList = p.inventarisByJenis
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
    final terpakaiInvIds = p.realisasiList
        .where((r) => _isSameCurrentPeriod(r, jadwal))
        .map((r) => r.realInvId)
        .toSet();
    final belumSelesaiList = inventarisList
        .where((inv) =>
            !terpakaiInvIds.contains(inv['inv_id']) &&
            inv['inv_is_gap_eligible'] != false)
        .toList();

    if (inventarisList.isEmpty) {
      AppNotifier.showError(context, 'Inventaris untuk jadwal ini belum ada');
      return;
    }
    if (belumSelesaiList.isEmpty) {
      AppNotifier.showWarning(
          context, 'Semua unit sudah direalisasi periode ini');
      return;
    }
    _showInventarisPicker(jadwal, belumSelesaiList);
  }

  void _showInventarisPicker(
      JadwalModel jadwal, List<Map<String, dynamic>> inventarisList) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _InventarisPickerSheet(
        inventarisList: inventarisList,
        onSelected: (inv) => _openRealisasiFromInventaris(jadwal, inv),
      ),
    );
  }

  Future<void> _openRealisasiFromInventaris(
      JadwalModel jadwal, Map<String, dynamic> inv) async {
    final invJenisId = inv['inv_jenis_id'] ?? jadwal.jdwJenisId;
    final invId = inv['inv_id'];

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    final p = context.read<JadwalProvider>();
    final today = DateFormatter.toApi(DateTime.now());
    final isEligible =
        await p.checkRealisasiEligibility(jadwal.jdwId, invId, today);

    if (!mounted) return;
    Navigator.pop(context); // Tutup loading

    if (!isEligible) {
      if (p.error != null) {
        AppNotifier.showWarning(context, p.error!);
      }
      return;
    }

    final jenis = context.read<MasterProvider>().jenisById(invJenisId);
    await Navigator.pushNamed(context, AppRoutes.realisasiForm, arguments: {
      'jadwalId': jadwal.jdwId,
      'invJenisId': invJenisId,
      'invJenisNama': jenis?.jenisNama ?? 'ID $invJenisId',
      'invId': invId,
      'invNama': inv['inv_nama'],
      'invNo': inv['inv_serial_number'] ?? inv['inv_no'],
      'invKondisi': inv['inv_kondisi'],
      'invPicNama': inv['pic_user']?['user_nama'] ?? inv['inv_pic'],
    });
    if (mounted) _loadData();
  }

  // --- Widget Ringkasan (Style Utama Dipertahankan) ---
  Widget _buildSummaryTable(List<JadwalModel> aktifList) {
    const freqs = ['Harian', 'Mingguan', 'Bulanan'];
    final summary = freqs.map((f) {
      final items = aktifList.where((j) => j.jdwFrekuensi == f).toList();
      final targetCount = items.fold<int>(
          0, (sum, j) => sum + (j.jdwTarget ?? j.jdwTotalUnit ?? 0));
      final realisasiCount =
          items.fold<int>(0, (sum, j) => sum + (j.jdwSelesaiUnit ?? 0));
      final pct =
          targetCount > 0 ? (realisasiCount / targetCount * 100).round() : 0;
      return {
        'freq': f,
        'target': targetCount,
        'realisasi': realisasiCount,
        'pct': pct
      };
    }).toList();

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.6)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Progres per Frekuensi',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              if (_selectedFrekuensi != null)
                TextButton.icon(
                  onPressed: () => setState(() => _selectedFrekuensi = null),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  ),
                  icon: const Icon(Icons.filter_alt_off_rounded, size: 14),
                  label: const Text('Reset',
                      style:
                          TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                ),
            ],
          ),
          const SizedBox(height: 10),
          ...summary.map((row) {
            final f = row['freq'] as String;
            final isSelected = _selectedFrekuensi == f;
            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: InkWell(
                onTap: () =>
                    setState(() => _selectedFrekuensi = isSelected ? null : f),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.primary.withValues(alpha: 0.08)
                        : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected
                          ? AppColors.primary.withValues(alpha: 0.2)
                          : AppColors.border.withValues(alpha: 0.6),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color:
                                  isSelected ? AppColors.primary : Colors.grey[300],
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              f,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight:
                                    isSelected ? FontWeight.w800 : FontWeight.w600,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ),
                          Text(
                            '${row['realisasi']}/${row['target']}',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            '${row['pct']}%',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: isSelected
                                  ? AppColors.primary
                                  : AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(99),
                        child: LinearProgressIndicator(
                          value: (row['target'] as int) > 0
                              ? ((row['realisasi'] as int) / (row['target'] as int)).clamp(0.0, 1.0)
                              : 0.0,
                          minHeight: 4,
                          backgroundColor: isSelected
                              ? AppColors.primary.withValues(alpha: 0.1)
                              : AppColors.border.withValues(alpha: 0.5),
                          valueColor: AlwaysStoppedAnimation<Color>(
                            (row['pct'] as int) >= 100
                                ? AppColors.success
                                : ((row['pct'] as int) > 50
                                    ? AppColors.primary
                                    : AppColors.warning),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildGapGuideCard() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.6)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () =>
                setState(() => _isGapGuideExpanded = !_isGapGuideExpanded),
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.help_outline_rounded,
                        size: 16, color: AppColors.primary),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Fitur Gap Penjadwalan (Panduan Singkat)',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  Icon(
                    _isGapGuideExpanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    size: 20,
                    color: AppColors.textSecondary,
                  ),
                ],
              ),
            ),
          ),
          if (_isGapGuideExpanded) ...[
            const Divider(height: 1, indent: 14, endIndent: 14),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // -- Penjelasan singkat --
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: AppColors.primary.withValues(alpha: 0.12),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.info_outline_rounded,
                            size: 16,
                            color:
                                AppColors.primary.withValues(alpha: 0.7)),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            '"Gap Penjadwalan" adalah aturan jarak waktu minimal '
                            'antar maintenance. Tujuannya agar maintenance '
                            'tidak dilakukan terlalu dekat waktunya.',
                            style: TextStyle(
                              fontSize: 11.5,
                              color: AppColors.textSecondary,
                              height: 1.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // -- Header tabel --
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(10),
                        topRight: Radius.circular(10),
                      ),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Padding(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                      child: IntrinsicHeight(
                        child: Row(
                          children: [
                            const Expanded(
                              flex: 5,
                              child: Text(
                                'Fungsi',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.textSecondary,
                                  letterSpacing: 0.3,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              width: 1,
                              color: const Color(0xFFCBD5E1),
                            ),
                            const SizedBox(width: 8),
                            const Expanded(
                              flex: 4,
                              child: Text(
                                'Cara Mengatur',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.textSecondary,
                                  letterSpacing: 0.3,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // -- Baris 1: Jeda per Alat --
                  _buildGuideTableRow(
                    title: 'Gap per Unit Inventaris (Mesin)',
                    description:
                        'Mencegah satu unit/mesin di-maintenance berulang dalam waktu berdekatan',
                    example:
                        'Contoh: Laptop, jeda 30 hari → unit yang sama tidak '
                        'dapat di-maintenance lagi sebelum 30 hari sejak maintenance terakhir',
                    settingLocation: 'Menu Master Jenis\n→ Pilih jenis\n→ Atur "GAP Hari Realisasi per Inventaris"',
                    isFirst: true,
                  ),

                  // -- Baris 2: Jeda per Jadwal --
                  _buildGuideTableRow(
                    title: 'Gap per Jadwal (Jeda Periode)',
                    description:
                        'Memberikan jeda waktu antar siklus periode maintenance (misal: 3 bulan sekali)',
                    example:
                        'Contoh: Maintenance Laptop, jeda 90 hari → setelah diservis di bulan ke-1, '
                        'target bulan ke-2 & ke-3 otomatis 0 (tidak merusak % target)',
                    settingLocation: 'Buat/Edit Jadwal\n→ Isi kolom\n→ "GAP Realisasi (hari)"',
                    isLast: true,
                  ),

                  const SizedBox(height: 10),

                  // -- Ringkasan singkat --
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.success.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: AppColors.success.withValues(alpha: 0.15),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.lightbulb_outline_rounded,
                            size: 14,
                            color:
                                AppColors.success.withValues(alpha: 0.8)),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            'Singkatnya: "Gap per Unit Inventaris" membatasi jeda waktu antar servis untuk unit yang sama. '
                            '"Gap per Jadwal" membatasi jeda periode siklus jadwal (misal: 90 hari / 3 bulan sekali). '
                            'Keduanya dapat dipakai bersamaan.',
                            style: TextStyle(
                              fontSize: 11,
                              color: AppColors.textSecondary,
                              height: 1.5,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildGuideTableRow({
    required String title,
    required String description,
    required String example,
    required String settingLocation,
    bool isFirst = false,
    bool isLast = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          left: const BorderSide(color: Color(0xFFE2E8F0)),
          right: const BorderSide(color: Color(0xFFE2E8F0)),
          bottom: const BorderSide(color: Color(0xFFE2E8F0)),
          top: isFirst
              ? BorderSide.none
              : const BorderSide(color: Color(0xFFE2E8F0), width: 0.5),
        ),
        borderRadius: isLast
            ? const BorderRadius.only(
                bottomLeft: Radius.circular(10),
                bottomRight: Radius.circular(10),
              )
            : null,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Kolom Fungsi
              Expanded(
                flex: 5,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      description,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(5),
                        border: Border.all(
                          color: const Color(0xFFE2E8F0),
                          width: 0.5,
                        ),
                      ),
                      child: Text(
                        example,
                        style: TextStyle(
                          fontSize: 10.5,
                          color:
                              AppColors.textSecondary.withValues(alpha: 0.8),
                          height: 1.4,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),

              // Garis Pemisah Antar Kolom
              Container(
                width: 1,
                color: const Color(0xFFE2E8F0),
              ),
              const SizedBox(width: 8),

              // Kolom Cara Mengatur
              Expanded(
                flex: 4,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.04),
                    borderRadius: BorderRadius.circular(7),
                    border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.1),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          settingLocation,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primary,
                            height: 1.45,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final role = auth.user?['user_jabatan'];
    final isAdmin = role == 'admin' || role == 'manager';
    final isUser =
        role == 'user' || role == 'teknisi' || role == 'it_support';
    final isDesktop = AppBreakpoints.isDesktop(context);
    final maxContentWidth = isDesktop ? 1180.0 : 860.0;

    return Scaffold(
      backgroundColor: _kPageBg,
      appBar: AppBar(title: const Text('Penjadwalan'), elevation: 0),
      floatingActionButton: isAdmin
          ? FloatingActionButton(
              onPressed: () => _openForm(),
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.white,
              child: const Icon(Icons.add),
            )
          : null,
      body: Consumer<JadwalProvider>(
        builder: (_, p, __) {
          // Search Bar
          final Widget searchBar = SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: TextField(
                controller: _searchCtrl,
                onChanged: (val) {
                  setState(() {
                    _searchQuery = val.trim();
                  });
                },
                decoration: InputDecoration(
                  hintText: 'Cari By Judul, Nama Inventaris, atau Jenis...',
                  prefixIcon: const Icon(Icons.search, color: AppColors.primary),
                  suffixIcon: _searchCtrl.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, color: Colors.grey),
                          onPressed: () {
                            _searchCtrl.clear();
                            setState(() {
                              _searchQuery = '';
                            });
                          },
                        )
                      : null,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
              ),
            ),
          );

          if (p.loading) {
            return const AppShimmer(
              child: SingleChildScrollView(
                physics: NeverScrollableScrollPhysics(),
                padding: EdgeInsets.fromLTRB(16, 16, 16, 120),
                child: Column(
                  children: [
                    AppSkeletonListCard(),
                    AppSkeletonListCard(),
                    AppSkeletonListCard(),
                    AppSkeletonListCard(),
                  ],
                ),
              ),
            );
          }

          final jadwalAktif = p.jadwalList.where((j) => j.jdwStatus == 'Draft').toList();
          // Filter by frekuensi selection
          List<JadwalModel> filtered = _selectedFrekuensi != null
              ? jadwalAktif.where((j) => j.jdwFrekuensi == _selectedFrekuensi).toList()
              : jadwalAktif;
          // Filter by search query
          if (_searchQuery.isNotEmpty) {
            final query = _searchQuery.toLowerCase();
            final master = context.read<MasterProvider>();
            filtered = filtered.where((j) {
              final judul = j.jdwJudul.toLowerCase();
              final invJenis = (j.jdwInvJenis ?? '').toLowerCase();
              final jenisNama = (j.jdwInvJenis?.trim().isNotEmpty == true)
                  ? invJenis
                  : master.jenisById(j.jdwJenisId)?.jenisNama.toLowerCase() ?? '';

              // Pencarian ke daftar unit inventaris spesifik di bawah jenis ini
              final matchingInv = master.inventarisList.where((inv) {
                if (inv.invJenisId != j.jdwJenisId) return false;
                final invNama = inv.invNama.toLowerCase();
                final invNo = inv.invNo.toLowerCase();
                final invSn = (inv.invSerialNumber ?? '').toLowerCase();
                return invNama.contains(query) || invNo.contains(query) || invSn.contains(query);
              });

              return judul.contains(query) ||
                  invJenis.contains(query) ||
                  jenisNama.contains(query) ||
                  matchingInv.isNotEmpty;
            }).toList();
          }

          return Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxContentWidth),
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  // Ringkasan menggunakan Sliver agar scroll bersama list
                  SliverToBoxAdapter(
                    child: Column(
                      children: [
                        _buildSummaryTable(jadwalAktif),
                        if (isAdmin) _buildGapGuideCard(),
                        const SizedBox(height: 8),
                      ],
                    ),
                  ),
                  searchBar,
                  const SliverToBoxAdapter(
                    child: SizedBox(height: 8),
                  ),

                  // List Jadwal
                  if (filtered.isEmpty)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: EmptyState(
                          message: _searchQuery.isNotEmpty
                              ? 'Jadwal "$_searchQuery" tidak ditemukan'
                              : (_selectedFrekuensi != null
                                  ? 'Tidak ada jadwal $_selectedFrekuensi yang aktif'
                                  : 'Belum ada jadwal yang aktif')),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, i) {
                            final item = filtered[i];
                            final master = context.read<MasterProvider>();
                            final jenisNama =
                                (item.jdwInvJenis ?? '').trim().isNotEmpty
                                    ? item.jdwInvJenis!.trim()
                                    : master
                                            .jenisById(item.jdwJenisId)
                                            ?.jenisNama ??
                                        'Jenis tidak diketahui';
                            final pabrikLabel = item.jdwPabrikList.isEmpty
                                ? null
                                : item.jdwPabrikList
                                    .map((c) => master.displayPabrik(c))
                                    .join(', ');
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: _JadwalCard(
                                jadwal: item,
                                jenisNama: jenisNama,
                                pabrikLabel: pabrikLabel,
                                isAdmin: isAdmin,
                                isUser: isUser,
                                onTap: () => _openJadwalDetail(item),
                                onRealisasi: () => _handleRealisasiTap(item),
                                onEdit: () => _openForm(item),
                                onDelete: () =>
                                    _confirmSelesaikanJadwal(item),
                                onStatusChange: (st) => context
                                    .read<JadwalProvider>()
                                    .updateStatusJadwal(item.jdwId, st),
                              ),
                            );
                          },
                          childCount: filtered.length,
                        ),
                      ),
                    ),
                  const SliverToBoxAdapter(child: SizedBox(height: 100)),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// --- SUB-WIDGETS (Sesuai Style Utama Anda) ---

class _InventarisPickerSheet extends StatefulWidget {
  final List<Map<String, dynamic>> inventarisList;
  final Function(Map<String, dynamic>) onSelected;
  const _InventarisPickerSheet(
      {required this.inventarisList, required this.onSelected});

  @override
  State<_InventarisPickerSheet> createState() => _InventarisPickerSheetState();
}

class _InventarisPickerSheetState extends State<_InventarisPickerSheet> {
  late final TextEditingController _searchCtrl;
  late final FocusNode _focusNode;
  late final DraggableScrollableController _sheetController;
  String searchQuery = '';

  @override
  void initState() {
    super.initState();
    _searchCtrl = TextEditingController();
    _focusNode = FocusNode();
    _sheetController = DraggableScrollableController();

    _focusNode.addListener(() {
      if (_focusNode.hasFocus) {
        _sheetController.animateTo(
          0.95,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _focusNode.dispose();
    _sheetController.dispose();
    super.dispose();
  }

  String _resolvePicName(Map<String, dynamic> inv) {
    final picUser = inv['pic_user'];
    if (picUser is Map && picUser['user_nama'] != null) {
      return picUser['user_nama'].toString();
    }
    return (inv['inv_pic'] ?? '-').toString();
  }

  bool _matchesSearch(Map<String, dynamic> inv, String query) {
    final normalizedQuery = query.trim().toLowerCase();
    if (normalizedQuery.isEmpty) return true;

    final sn = (inv['inv_serial_number'] ?? '').toString().toLowerCase();
    final nama = (inv['inv_nama'] ?? '').toString().toLowerCase();
    final pic = _resolvePicName(inv).toLowerCase();

    return sn.contains(normalizedQuery) ||
        nama.contains(normalizedQuery) ||
        pic.contains(normalizedQuery);
  }

  @override
  Widget build(BuildContext context) {
    final filtered = widget.inventarisList
        .where((inv) => _matchesSearch(inv, searchQuery))
        .toList();

    return DraggableScrollableSheet(
      controller: _sheetController,
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
              color: _kPageBg,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                16,
                12,
                16,
                16 + MediaQuery.of(context).viewInsets.bottom,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 42,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Pilih unit yang akan diperiksa',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _searchCtrl,
                    focusNode: _focusNode,
                    textInputAction: TextInputAction.search,
                    onSubmitted: (value) {
                      FocusScope.of(context).unfocus();
                      setState(() {
                        searchQuery = value.trim();
                      });
                    },
                    decoration: InputDecoration(
                      hintText: 'Cari nama, serial number, atau PIC...',
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.search, size: 20, color: AppColors.primary),
                        onPressed: () {
                          FocusScope.of(context).unfocus();
                          setState(() {
                            searchQuery = _searchCtrl.text.trim();
                          });
                        },
                      ),
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding:
                          const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide:
                            const BorderSide(color: AppColors.primary, width: 1.5),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Flexible(
                    child: filtered.isEmpty
                        ? const Center(
                            child: Text(
                              'Data inventaris tidak ditemukan',
                              style: TextStyle(
                                color: AppColors.textSecondary,
                              ),
                            ),
                          )
                        : ListView.separated(
                            controller: scrollController,
                            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                            shrinkWrap: true,
                            itemCount: filtered.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 8),
                            itemBuilder: (_, i) {
                              final inv = filtered[i];
                              final merk =
                                  (inv['inv_merk'] ?? '-').toString();
                              final pabrik = inv['inv_pabrik_kode'] ?? '-';
                              final sn = inv['inv_serial_number'] ?? '-';
                              final picName = _resolvePicName(inv);

                              return Card(
                                margin: EdgeInsets.zero,
                                child: ListTile(
                                  contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 14, vertical: 10),
                                  leading: CircleAvatar(
                                    radius: 20,
                                    backgroundColor:
                                        AppColors.primary.withValues(alpha: 0.12),
                                    child: const Icon(
                                      Icons.inventory_2_outlined,
                                      color: AppColors.primary,
                                      size: 20,
                                    ),
                                  ),
                                  title: Text(
                                    inv['inv_nama'] ?? '-',
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                  subtitle: Padding(
                                    padding: const EdgeInsets.only(top: 6),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'No: ${inv['inv_no'] ?? '-'}',
                                          style: const TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                            color: AppColors.primary,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          '$merk · $sn',
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: AppColors.textSecondary,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Row(
                                          children: [
                                            const Icon(
                                              Icons.person_outline,
                                              size: 14,
                                              color: AppColors.textSecondary,
                                            ),
                                            const SizedBox(width: 4),
                                            Expanded(
                                              child: Text(
                                                'PIC: $picName',
                                                style: const TextStyle(
                                                  fontSize: 12,
                                                  color: AppColors.textSecondary,
                                                ),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 2),
                                        Row(
                                          children: [
                                            const Icon(
                                              Icons.factory_outlined,
                                              size: 14,
                                              color: AppColors.textSecondary,
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              pabrik,
                                              style: const TextStyle(
                                                fontSize: 12,
                                                color: AppColors.textSecondary,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 8, vertical: 3),
                                          decoration: BoxDecoration(
                                            color: Colors.orange
                                                .withValues(alpha: 0.12),
                                            borderRadius:
                                                BorderRadius.circular(999),
                                          ),
                                          child: const Text(
                                            'Belum realisasi',
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w600,
                                              color: Colors.orange,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  trailing: const Icon(Icons.chevron_right),
                                  onTap: () {
                                    Navigator.pop(context);
                                    widget.onSelected(inv);
                                  },
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _JadwalCard extends StatelessWidget {
  final JadwalModel jadwal;
  final String jenisNama;
  final String? pabrikLabel;
  final bool isAdmin;
  final bool isUser;
  final VoidCallback onTap;
  final VoidCallback? onRealisasi;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final void Function(String) onStatusChange;

  const _JadwalCard({
    required this.jadwal,
    required this.jenisNama,
    this.pabrikLabel,
    required this.isAdmin,
    required this.isUser,
    required this.onTap,
    this.onRealisasi,
    required this.onEdit,
    required this.onDelete,
    required this.onStatusChange,
  });

  Color _colorForDivisi(String? divisiRaw) {
    return AppDivisiColors.getColor(divisiRaw);
  }

  IconData _iconForDivisi(String? divisiRaw) {
    return AppDivisiColors.getIcon(divisiRaw);
  }

  String _getRemainingDays(JadwalModel j) {
    final diff = _getRemainingDaysDiff(j);
    if (diff < 0) return 'Terlambat ${-diff}h';
    if (diff == 0) return 'Hari ini!';
    if (diff == 1) return 'Besok';
    return '$diff hari lagi';
  }

  int _getRemainingDaysDiff(JadwalModel j) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    
    final startDate = DateTime.tryParse(j.jdwTglMulai);
    if (startDate != null && startDate.isAfter(today)) {
      return startDate.difference(today).inDays;
    }
    
    if (!j.jdwPeriodFulfilled && (j.jdwFrekuensi == 'Mingguan' || j.jdwFrekuensi == 'Bulanan')) {
      return 0;
    }
    
    if (j.jdwDaysRemaining != null) return j.jdwDaysRemaining!;
    
    final fallbackDate = DateTime.tryParse(j.jdwNextDueDate ?? j.jdwTglMulai);
    if (fallbackDate == null) return 0;
    
    return fallbackDate.difference(today).inDays;
  }

  @override
  Widget build(BuildContext context) {
    final rem = _getRemainingDays(jadwal);
    final divisiColor = _colorForDivisi(jadwal.jdwDivisi);
    final icon = _iconForDivisi(jadwal.jdwDivisi);

    Color badgeBg;
    Color badgeText;
    if (rem.contains('Terlewat')) {
      badgeBg = AppColors.danger.withValues(alpha: 0.08);
      badgeText = AppColors.danger;
    } else if (rem == 'Hari ini') {
      badgeBg = AppColors.warning.withValues(alpha: 0.08);
      badgeText = AppColors.warning;
    } else {
      badgeBg = AppColors.success.withValues(alpha: 0.08);
      badgeText = AppColors.success;
    }

    final target = jadwal.jdwTarget ?? jadwal.jdwTotalUnit ?? 0;
    final selesai = jadwal.jdwSelesaiUnit ?? 0;
    final double progressPercent = target > 0 ? (selesai / target).clamp(0.0, 1.0) : 0.0;





    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.6)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: divisiColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(icon, size: 20, color: divisiColor),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              jadwal.jdwJudul,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 13.5,
                                height: 1.25,
                                color: AppColors.textPrimary,
                              ),
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 9, vertical: 3.5),
                        decoration: BoxDecoration(
                          color: badgeBg,
                          borderRadius: BorderRadius.circular(99),
                        ),
                        child: Text(
                          rem,
                          style: TextStyle(
                            color: badgeText,
                            fontWeight: FontWeight.w800,
                            fontSize: 10.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 2.5),
                        decoration: BoxDecoration(
                          color: divisiColor.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'Divisi ${jadwal.jdwDivisi}',
                          style: TextStyle(
                            fontSize: 10.5,
                            color: divisiColor,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Target: ${jadwal.jdwTarget ?? 1} unit',
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Progres Unit',
                        style: TextStyle(
                          fontSize: 11.5,
                          color: Colors.grey.shade600,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        '$selesai / $target selesai (${(progressPercent * 100).round()}%)',
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(99),
                    child: LinearProgressIndicator(
                      value: progressPercent,
                      minHeight: 6,
                      backgroundColor: Colors.grey.shade100,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        progressPercent == 1.0
                            ? AppColors.success
                            : (progressPercent > 0.5
                                ? AppColors.primary
                                : AppColors.warning),
                      ),
                    ),
                  ),

                  if (isUser) ...[
                    const SizedBox(height: 10),
                    _actionBtn(
                      Icons.playlist_add_check_circle_outlined,
                      'Lakukan Realisasi',
                      AppColors.primary,
                      onRealisasi ?? onTap,
                    ),
                  ],

                  if (isAdmin) ...[
                    const Padding(
                      padding: EdgeInsets.only(top: 8),
                      child: Divider(height: 1, color: AppColors.border),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton.icon(
                          onPressed: onEdit,
                          style: TextButton.styleFrom(
                            foregroundColor: AppColors.warning,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          icon: const Icon(Icons.edit_rounded, size: 14),
                          label: const Text(
                            'Edit',
                            style: TextStyle(
                                fontSize: 11.5, fontWeight: FontWeight.w700),
                          ),
                        ),
                        const SizedBox(width: 4),
                        TextButton.icon(
                          onPressed: onDelete,
                          style: TextButton.styleFrom(
                            foregroundColor: AppColors.danger,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          icon: const Icon(Icons.delete_rounded, size: 14),
                          label: const Text(
                            'Hapus',
                            style: TextStyle(
                                fontSize: 12, fontWeight: FontWeight.w700),
                          ),
                        ),
                      ],
                    )
                  ]
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _actionBtn(
      IconData icon, String label, Color color, VoidCallback onPressed) {
    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 16),
        label: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              label,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.arrow_forward_rounded, size: 14),
          ],
        ),
        style: FilledButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          elevation: 0,
          minimumSize: const Size.fromHeight(40),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }
}

class _JadwalForm extends StatefulWidget {
  final JadwalModel? item;
  const _JadwalForm({this.item});
  @override
  State<_JadwalForm> createState() => _JadwalFormState();
}

class _JadwalFormState extends State<_JadwalForm> {
  final _form = GlobalKey<FormState>();
  bool _targetAutoAll = true;
  final _targetCtrl = TextEditingController();
  final _autoTargetCtrl = TextEditingController();
  final _gapCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  final TextEditingController _jenisCtrl = TextEditingController();
  int? _jenisId;
  String? _divisi;
  final List<String> _pabrikCodes = [];
  String? _selectedPabrikValue;
  final _pabrikDropdownKey = GlobalKey<FormFieldState<String>>();
  int? _assignedToUserId;
  bool _showAllDivisiPelaksana = false;
  String _frekuensi = 'Harian';
  DateTime? _tglMulai;
  DateTime? _tglSelesai;
  int? _maxTargetUnit;
  bool _loadingTargetLimit = false;
  String? _targetLimitError;

  static const _frekuensiList = ['Harian', 'Mingguan', 'Bulanan'];
  bool get _showGapField => _frekuensi == 'Mingguan' || _frekuensi == 'Bulanan';

  Widget _buildJadwalSummaryWidget(BuildContext context) {
    final master = context.read<MasterProvider>();

    final missingFields = <String>[];
    if (_jenisId == null) missingFields.add('Jenis Inventaris');
    if (_pabrikCodes.isEmpty) missingFields.add('Pabrik / Lokasi');
    if (_assignedToUserId == null) missingFields.add('Pelaksana');
    if (_tglMulai == null) missingFields.add('Tanggal Mulai');

    if (missingFields.isNotEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.amber.shade50,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.amber.shade200),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.info_outline_rounded, size: 18, color: Colors.amber.shade800),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Ringkasan Belum Tersedia',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: Colors.amber.shade900,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'Lengkapi data wajib berikut: ${missingFields.join(', ')}.',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.amber.shade900,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    final jenis = _jenisCtrl.text.trim().isEmpty ? '-' : _jenisCtrl.text.trim();
    final jenisGapHari = master.jenisById(_jenisId!)?.jenisGapHari ?? 0;
    final target = _targetAutoAll ? 0 : (int.tryParse(_targetCtrl.text.trim()) ?? 0);
    final lokasi = _pabrikCodes.map((code) => master.displayPabrik(code)).join(', ');
    final mulai = _fmtDateDisplay(_tglMulai);
    final selesai = _tglSelesai != null ? _fmtDateDisplay(_tglSelesai) : 'Tanpa batas akhir';
    final jadwalGap = _showGapField ? (int.tryParse(_gapCtrl.text.trim()) ?? 0) : 0;

    final userList = master.userList;
    final pelaksana = userList
            .where((u) => u.userId == _assignedToUserId)
            .map((u) => u.userNama)
            .firstOrNull ??
        '#$_assignedToUserId';

    final generatedJudul = _getGeneratedJudul();

    return _SummaryWidget(
      judul: generatedJudul,
      jenis: jenis,
      frekuensi: _frekuensi,
      target: target,
      lokasi: lokasi,
      mulai: mulai,
      selesai: selesai,
      jadwalGapHari: jadwalGap,
      jenisGapHari: jenisGapHari,
      pelaksana: pelaksana,
    );
  }

  @override
  void dispose() {
    _autoTargetCtrl.dispose();
    _targetCtrl.dispose();
    _gapCtrl.dispose();
    _notesCtrl.dispose();
    _jenisCtrl.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _autoTargetCtrl.text = 'Semua Unit (${_maxTargetUnit ?? 0} unit aktif)';
    final d = widget.item;
    if (d != null) {
      _targetAutoAll = d.jdwTarget == null || d.jdwTarget == 0;
      _targetCtrl.text = _targetAutoAll ? '0' : '${d.jdwTarget}';
      _gapCtrl.text = '${d.jdwGapHari}';
      _notesCtrl.text = d.jdwNotes ?? '';
      _jenisId = d.jdwJenisId;
      _divisi = d.jdwDivisi;
      _pabrikCodes
        ..clear()
        ..addAll(d.jdwPabrikList);
      _assignedToUserId = d.jdwAssignedTo;
      _frekuensi = d.jdwFrekuensi;
      _tglMulai = DateTime.tryParse(d.jdwTglMulai);
      _tglSelesai =
          d.jdwTglSelesai != null ? DateTime.tryParse(d.jdwTglSelesai!) : null;
      final jenis = context.read<MasterProvider>().jenisById(d.jdwJenisId);
      _jenisCtrl.text = jenis?.jenisNama ?? 'ID ${d.jdwJenisId}';
    } else {
      _targetAutoAll = true;
      _targetCtrl.text = '0';
      _gapCtrl.text = '0';
      // Untuk create, set divisi dari auth user
      final auth = context.read<AuthProvider>();
      _divisi = auth.user?['user_divisi'] ?? '';
    }

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final master = context.read<MasterProvider>();
      await master.fetchJenisWithInventaris(showLoading: false);
      await master.fetchUsers(scope: 'all', showLoading: false);
      if (!mounted) return;
      if (_assignedToUserId != null && _divisi != null && _divisi!.isNotEmpty) {
        final assignedUser = master.userList
            .where((u) => u.userId == _assignedToUserId)
            .firstOrNull;
        if (assignedUser != null &&
            assignedUser.userDivisi.trim().toLowerCase() !=
                _divisi!.trim().toLowerCase()) {
          setState(() => _showAllDivisiPelaksana = true);
        }
      }
      if (_jenisId != null) {
        _syncTargetLimitForJenis(_jenisId!);
      }
    });
  }

  String _fmtDateApi(DateTime? d) => DateFormatter.toApi(d);

  String _fmtDateDisplay(DateTime? d) =>
      DateFormatter.toDisplayFromDate(d, fallback: '');

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

  int get _currentTargetValue => int.tryParse(_targetCtrl.text.trim()) ?? 1;

  void _setTargetValue(int value) {
    _targetCtrl.text = '$value';
    _targetCtrl.selection = TextSelection.fromPosition(
      TextPosition(offset: _targetCtrl.text.length),
    );
  }

  Future<void> _syncTargetLimitForJenis(int jenisId) async {
    setState(() => _loadingTargetLimit = true);
    final master = context.read<MasterProvider>();
    await master.fetchInventaris(
      jenis: '$jenisId',
      showLoading: false,
      updateKategoriMap: false,
    );
    if (!mounted) return;

    final matchingInventaris = master.inventarisList.where((inv) {
      if (_pabrikCodes.isEmpty) return true;
      return _pabrikCodes.contains(inv.invPabrikKode);
    }).toList();

    final maxTarget = matchingInventaris.length;
    _autoTargetCtrl.text = 'Semua Unit ($maxTarget unit aktif)';
    setState(() {
      _maxTargetUnit = maxTarget;
      _loadingTargetLimit = false;
      _targetLimitError = null;
    });

    if (maxTarget < 1) {
      _setTargetValue(1);
      return;
    }

    final current = _currentTargetValue;
    if (current > maxTarget) {
      _setTargetValue(maxTarget);
    } else if (current < 1) {
      _setTargetValue(1);
    }
  }

  void _adjustTarget(int delta) {
    final max = _maxTargetUnit;
    if (max == null || max < 1) return;
    final current = _currentTargetValue;
    if (delta > 0 && current >= max) {
      setState(() {
        _targetLimitError = 'Inventaris ${_jenisCtrl.text} hanya $max unit';
      });
      return;
    }

    final next = (current + delta).clamp(1, max);
    _setTargetValue(next);
    if (_targetLimitError != null) {
      setState(() {
        _targetLimitError = null;
      });
    }
  }

  Future<void> _pickDate(bool isMulai) async {
    final now = DateTime.now();
    final firstDate = DateTime(2024);
    final lastDate = DateTime(2030);
    final initialRaw =
        isMulai ? (_tglMulai ?? now) : (_tglSelesai ?? _tglMulai ?? now);
    final initialDate = isMulai && !_isDateAllowedForFrekuensi(initialRaw)
        ? _nextAllowedDate(initialRaw)
        : initialRaw;

    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: firstDate,
      lastDate: lastDate,
      selectableDayPredicate:
          isMulai ? (day) => _isDateAllowedForFrekuensi(day) : null,
    );
    if (picked != null) {
      setState(() {
        if (isMulai) {
          _tglMulai = picked;
        } else {
          _tglSelesai = picked;
        }
      });
    }
  }

  Future<void> _pickJenis() async {
    final master = context.read<MasterProvider>();
    if (master.jenisMaster.isEmpty) {
      await master.fetchJenis(showLoading: false);
    }
    await master.fetchJenisWithInventaris(showLoading: false);
    if (!mounted) return;

    final availableJenis =
        master.jenisAvailableForJadwal(includeJenisId: _jenisId);
    if (availableJenis.isEmpty) {
      await AppNotifier.showWarning(
        context,
        'Belum ada inventaris aktif. Tambahkan data inventaris dulu sebelum membuat jadwal.',
      );
      return;
    }

    final result = await showModalBottomSheet<JenisModel>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => JenisLookupSheet(
        items: availableJenis,
        initialId: _jenisId,
      ),
    );
    if (result != null) {
      if (_jenisId != result.jenisId) {
        setState(() {
          _jenisId = result.jenisId;
          _jenisCtrl.text = result.jenisNama;
          _pabrikCodes.clear();
          _selectedPabrikValue = null;
          _divisi = result.jenisKategori;
          _assignedToUserId = null;
        });
        _pabrikDropdownKey.currentState?.didChange(null);
        await _syncTargetLimitForJenis(result.jenisId);
        _autoGenerateJudul();
      }
    }
  }

  String _getGeneratedJudul() {
    final master = context.read<MasterProvider>();

    final freqUpper = _frekuensi.toUpperCase();
    final jenisPart = _jenisCtrl.text.trim();

    String userPart = '';
    if (_assignedToUserId != null) {
      final match = master.userList.where((u) => u.userId == _assignedToUserId);
      if (match.isNotEmpty) {
        userPart = '(${match.first.userNama.trim()})';
      }
    }

    String lokasiPart = '';
    if (_pabrikCodes.isNotEmpty) {
      final names = _pabrikCodes.map((code) => master.displayPabrik(code)).join(', ');
      lokasiPart = '| $names';
    }

    var title = 'MTC $freqUpper';
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

  void _autoGenerateJudul() {
    setState(() {});
  }

  Widget _requiredLabel(String label) {
    return RichText(
      text: TextSpan(
        text: label,
        style: const TextStyle(
            fontSize: 13,
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w400),
        children: const [
          TextSpan(
            text: ' *',
            style: TextStyle(color: Colors.red, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }

  Widget _pabrikSelector(MasterProvider master) {
    String labelForCode(String code) {
      final match = master.pabrikList.where((p) => p.pabKode == code);
      if (match.isNotEmpty) return match.first.displayLabel;
      return code;
    }

    final allowedCodes = master.inventarisList
        .map((inv) => inv.invPabrikKode)
        .whereType<String>()
        .toSet();

    final filteredPabrikList = master.pabrikList.where((p) {
      if (_jenisId != null && allowedCodes.isNotEmpty) {
        if (!allowedCodes.contains(p.pabKode)) return false;
      }
      return !_pabrikCodes.contains(p.pabKode);
    }).toList();

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DropdownButtonFormField<String>(
            key: _pabrikDropdownKey,
            // ignore: deprecated_member_use
            value: _selectedPabrikValue,
            decoration: InputDecoration(
              label: _requiredLabel('Pabrik / Lokasi'),
              prefixIcon: const Icon(Icons.factory_outlined),
            ),
            hint: Text(
              _jenisId == null
                  ? 'Pilih jenis inventaris dahulu'
                  : 'Pilih pabrik/lokasi',
              style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
            items: _jenisId == null
                ? null
                : filteredPabrikList
                    .map((p) => DropdownMenuItem(
                          value: p.pabKode,
                          child: Text(
                            p.displayLabel,
                            style: const TextStyle(
                                fontSize: 13, color: AppColors.textPrimary),
                          ),
                        ))
                    .toList(),
            onChanged: _jenisId == null
                ? null
                : (value) {
                    if (value == null) return;
                    setState(() {
                      if (!_pabrikCodes.contains(value)) {
                        _pabrikCodes.add(value);
                      }
                      _selectedPabrikValue = null;
                      _autoGenerateJudul();
                    });
                    if (_jenisId != null) {
                      _syncTargetLimitForJenis(_jenisId!);
                    }
                    _pabrikDropdownKey.currentState?.didChange(null);
                  },
            validator: (_) {
              if (_pabrikCodes.isEmpty) {
                return 'Pilih minimal satu pabrik';
              }
              return null;
            },
          ),
          const SizedBox(height: 10),
          if (_pabrikCodes.isEmpty)
            const Padding(
              padding: EdgeInsets.only(left: 4),
              child: Text(
                'Belum ada pabrik yang dipilih',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _pabrikCodes.map((code) {
                final label = labelForCode(code);
                return InputChip(
                  label: Text(label),
                  deleteIcon: const Icon(Icons.close, size: 16),
                  onDeleted: () {
                    setState(() {
                      _pabrikCodes.remove(code);
                      _autoGenerateJudul();
                    });
                    if (_jenisId != null) {
                      _syncTargetLimitForJenis(_jenisId!);
                    }
                  },
                );
              }).toList(),
            ),
        ],
      ),
    );
  }

  Widget _jenisPickerField() {
    final divisiLabel =
        (_divisi != null && _divisi!.isNotEmpty) ? _divisi! : '-';
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextFormField(
            controller: _jenisCtrl,
            readOnly: true,
            decoration: InputDecoration(
              label: _requiredLabel('Jenis Inventaris'),
              hintText: 'Cari jenis yang sudah punya inventaris...',
              prefixIcon: const Icon(Icons.label_outline),
              suffixIcon: IconButton(
                icon: const Icon(Icons.search),
                onPressed: _pickJenis,
              ),
            ),
            validator: (_) {
              if (_jenisId == null) return 'Jenis wajib dipilih';
              final master = context.read<MasterProvider>();
              if (!master.isJenisActive(_jenisId!)) {
                return 'Jenis inventaris nonaktif';
              }
              final hasActiveInv = (_maxTargetUnit != null && _maxTargetUnit! > 0) || master.hasInventarisForJenis(_jenisId!);
              if (!hasActiveInv) {
                return 'Jenis belum punya inventaris aktif';
              }
              return null;
            },
            onTap: _pickJenis,
          ),
          if (_divisi != null && _divisi!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4, left: 12),
              child: Row(
                children: [
                  const Icon(Icons.account_tree_outlined,
                      size: 13, color: AppColors.textSecondary),
                  const SizedBox(width: 4),
                  Text(
                    'Divisi Pelaksana: $divisiLabel',
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) {
      await AppNotifier.showWarning(
          context, 'Lengkapi data jadwal terlebih dahulu');
      return;
    }
    if (_jenisId == null) {
      await AppNotifier.showWarning(context, 'Jenis inventaris wajib dipilih');
      return;
    }
    final master = context.read<MasterProvider>();
    if (!master.isJenisActive(_jenisId!)) {
      await AppNotifier.showWarning(
        context,
        'Jenis inventaris nonaktif. Pilih jenis yang aktif.',
      );
      return;
    }
    final hasActiveInv = (_maxTargetUnit != null && _maxTargetUnit! > 0) || master.hasInventarisForJenis(_jenisId!);
    if (!hasActiveInv) {
      await AppNotifier.showWarning(
        context,
        'Jenis yang dipilih belum punya inventaris aktif.',
      );
      return;
    }
    if (_tglMulai == null) {
      await AppNotifier.showWarning(context, 'Tanggal mulai wajib dipilih');
      return;
    }
    if (!_isDateAllowedForFrekuensi(_tglMulai!)) {
      final msg = _frekuensi == 'Mingguan'
          ? 'Tanggal mulai untuk frekuensi Mingguan harus hari Senin'
          : _frekuensi == 'Bulanan'
              ? 'Tanggal mulai untuk frekuensi Bulanan harus tanggal 1'
              : 'Tanggal mulai tidak valid untuk frekuensi yang dipilih';
      await AppNotifier.showWarning(context, msg);
      return;
    }
    if (_assignedToUserId == null) {
      await AppNotifier.showWarning(context, 'Pelaksana wajib dipilih');
      return;
    }
    if (_pabrikCodes.isEmpty) {
      await AppNotifier.showWarning(
          context, 'Pilih minimal satu pabrik/lokasi jadwal');
      return;
    }
    final parsedTarget = _targetAutoAll
        ? (_maxTargetUnit != null && _maxTargetUnit! > 0 ? _maxTargetUnit! : 1)
        : (int.tryParse(_targetCtrl.text.trim()) ?? 1);
    if (!_targetAutoAll) {
      if (parsedTarget < 1) {
        await AppNotifier.showWarning(context, 'Target manual wajib angka minimal 1');
        return;
      }
      if (_maxTargetUnit != null && parsedTarget > _maxTargetUnit!) {
        await AppNotifier.showWarning(
          context,
          'Target tidak boleh melebihi total inventaris jenis ($_maxTargetUnit unit)',
        );
        return;
      }
    }
    final parsedGapHari = int.tryParse(_gapCtrl.text.trim());
    if (_showGapField && (parsedGapHari == null || parsedGapHari < 0)) {
      await AppNotifier.showWarning(
          context, 'Gap realisasi wajib angka minimal 0');
      return;
    }
    final p = context.read<JadwalProvider>();
    final body = {
      'jdw_judul': _getGeneratedJudul(),
      'jdw_jenis_id': _jenisId!,
      'jdw_target': parsedTarget,
      'jdw_divisi': _divisi,
      'jdw_pabrik_kode': _pabrikCodes.join(','),
      'jdw_assigned_to': _assignedToUserId,
      'jdw_frekuensi': _frekuensi,
      'jdw_gap_hari': _showGapField ? (parsedGapHari ?? 0) : 0,
      'jdw_tgl_mulai': _fmtDateApi(_tglMulai),
      'jdw_tgl_selesai': _tglSelesai != null ? _fmtDateApi(_tglSelesai) : null,
      'jdw_notes':
          _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
    };
    final isEdit = widget.item != null;
    final ok = await p.saveJadwal(body, id: widget.item?.jdwId);
    if (ok && mounted) {
      await AppNotifier.showSuccess(context,
          isEdit ? 'Jadwal berhasil diperbarui' : 'Jadwal berhasil dibuat');
      if (!mounted) return;
      Navigator.pop(context);
    } else if (mounted) {
      await AppNotifier.showError(context, p.error ?? 'Gagal menyimpan jadwal');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.item != null;
    final master = context.watch<MasterProvider>();
    final jadwalP = context.watch<JadwalProvider>();
    if (_jenisId != null && _jenisCtrl.text.isEmpty) {
      final jenis = master.jenisById(_jenisId!);
      if (jenis != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) setState(() => _jenisCtrl.text = jenis.jenisNama);
        });
      }
    }

    return DraggableScrollableSheet(
      initialChildSize: 0.92,
      maxChildSize: 0.95,
      minChildSize: 0.5,
      builder: (_, ctrl) => Container(
        decoration: const BoxDecoration(
          color: _kPageBg,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Form(
          key: _form,
          child: ListView(
            controller: ctrl,
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
            children: [
              Center(
                  child: Container(
                margin: const EdgeInsets.only(top: 8, bottom: 16),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2)),
              )),
              Text(isEdit ? 'Edit Jadwal' : 'Buat Jadwal Baru',
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 20),
              _jenisPickerField(),
              const SizedBox(height: 14),
              _pabrikSelector(master),
              const SizedBox(height: 14),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DropdownButtonFormField<int>(
                    initialValue: _assignedToUserId,
                    style: const TextStyle(fontSize: 13, color: AppColors.textPrimary),
                    decoration: InputDecoration(
                      label: _requiredLabel('Pelaksana / User'),
                      prefixIcon: const Icon(Icons.person_outlined),
                    ),
                    hint: const Text(
                      'Pilih pelaksana',
                      style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                    ),
                    items: master.userList
                        .where((u) {
                          final targetDivisi = (_divisi ?? '').trim().toLowerCase();
                          final userDiv = u.userDivisi.trim().toLowerCase();
                          final matchDivisi = _showAllDivisiPelaksana ||
                              targetDivisi.isEmpty ||
                              userDiv == targetDivisi ||
                              u.userId == _assignedToUserId;
                          final matchJabatan = u.userJabatan == 'user' ||
                              u.userJabatan == 'teknisi' ||
                              u.userJabatan == 'it_support';
                          return matchDivisi && matchJabatan && u.userIsActive;
                        })
                        .map((u) {
                          final isDiffDivisi = _divisi != null &&
                              _divisi!.isNotEmpty &&
                              u.userDivisi.trim().toLowerCase() !=
                                  _divisi!.trim().toLowerCase();
                          return DropdownMenuItem(
                            value: u.userId,
                            child: Text(
                              isDiffDivisi
                                  ? '${u.userNama} (${u.userDivisi})'
                                  : u.userNama,
                              style: const TextStyle(
                                  fontSize: 13, color: AppColors.textPrimary),
                            ),
                          );
                        })
                        .toList(),
                    onChanged: (v) {
                      setState(() => _assignedToUserId = v);
                      _autoGenerateJudul();
                    },
                    validator: (v) =>
                        v == null ? 'Pelaksana wajib dipilih' : null,
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 4, left: 4),
                    child: InkWell(
                      onTap: () => setState(
                          () => _showAllDivisiPelaksana = !_showAllDivisiPelaksana),
                      borderRadius: BorderRadius.circular(4),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                              height: 20,
                              width: 20,
                              child: Checkbox(
                                value: _showAllDivisiPelaksana,
                                activeColor: AppColors.primary,
                                materialTapTargetSize:
                                    MaterialTapTargetSize.shrinkWrap,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(4)),
                                onChanged: (v) => setState(
                                    () => _showAllDivisiPelaksana = v ?? false),
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              'Tampilkan User Lintas Divisi',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(
                initialValue: _frekuensi,
                style: const TextStyle(fontSize: 13, color: AppColors.textPrimary),
                decoration: InputDecoration(
                  label: _requiredLabel('Frekuensi'),
                  prefixIcon: const Icon(Icons.repeat_outlined),
                ),
                items: _frekuensiList
                    .map((f) => DropdownMenuItem(
                          value: f,
                          child: Text(
                            f,
                            style: const TextStyle(
                                fontSize: 13, color: AppColors.textPrimary),
                          ),
                        ))
                    .toList(),
                onChanged: (v) {
                  if (v == null) return;
                  setState(() {
                    _frekuensi = v;
                    if (!_showGapField) {
                      _gapCtrl.text = '0';
                    }
                    if (_tglMulai != null &&
                        !_isDateAllowedForFrekuensi(_tglMulai!)) {
                      _tglMulai = _nextAllowedDate(_tglMulai!);
                    }
                  });
                },
              ),
              if (_showGapField) ...[
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0F4FF),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: AppColors.primary.withValues(alpha: 0.2)),
                  ),
                  child: const Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.info_outline,
                          size: 16, color: AppColors.primary),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Atur jeda hari antar realisasi jadwal ini.',
                          style: TextStyle(
                              fontSize: 12,
                              color: AppColors.primary,
                              height: 1.5),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _gapCtrl,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    label: _requiredLabel('Gap Realisasi (hari)'),
                    prefixIcon: const Icon(Icons.timelapse_outlined),
                    hintText: 'Contoh: 2',
                    helperText:
                        'Jarak minimal antar pelaksanaan jadwal. Isi 0 jika ingin memeriksa banyak unit dalam periode yang sama.',
                    helperMaxLines: 2,
                  ),
                  validator: (v) {
                    if (!_showGapField) return null;
                    final n = int.tryParse((v ?? '').trim());
                    if (n == null || n < 0) {
                      return 'Gap wajib angka bulat minimal 0';
                    }
                    return null;
                  },
                ),
              ],
              const SizedBox(height: 14),
              TextFormField(
                key: ValueKey<bool>(_targetAutoAll),
                controller: _targetAutoAll ? _autoTargetCtrl : _targetCtrl,
                readOnly: _targetAutoAll,
                keyboardType: TextInputType.number,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: _targetAutoAll
                      ? const Color(0xFF15803D)
                      : AppColors.textPrimary,
                ),
                onChanged: (_) {
                  if (_targetLimitError != null) {
                    setState(() => _targetLimitError = null);
                  }
                },
                decoration: InputDecoration(
                  label: _requiredLabel('Target Unit per Jadwal'),
                  prefixIcon: Icon(
                    _targetAutoAll ? Icons.auto_awesome : Icons.flag_outlined,
                    color: _targetAutoAll
                        ? const Color(0xFF16A34A)
                        : AppColors.textSecondary,
                  ),
                  suffixIcon: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (!_targetAutoAll)
                        SizedBox(
                          width: 32,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              InkWell(
                                onTap: (_loadingTargetLimit ||
                                        _maxTargetUnit == null)
                                    ? null
                                    : () => setState(() => _adjustTarget(1)),
                                child: const Icon(Icons.keyboard_arrow_up,
                                    size: 16),
                              ),
                              InkWell(
                                onTap: (_loadingTargetLimit ||
                                        _maxTargetUnit == null)
                                    ? null
                                    : () => setState(() => _adjustTarget(-1)),
                                child: const Icon(Icons.keyboard_arrow_down,
                                    size: 16),
                              ),
                            ],
                          ),
                        ),
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(20),
                          onTap: () {
                            setState(() {
                              _targetAutoAll = !_targetAutoAll;
                              if (_targetAutoAll) {
                                _targetCtrl.text = '0';
                                _targetLimitError = null;
                              } else {
                                if (_targetCtrl.text == '0' ||
                                    _targetCtrl.text.isEmpty) {
                                  _targetCtrl.text =
                                      '${_maxTargetUnit ?? 1}';
                                }
                              }
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: _targetAutoAll
                                  ? const Color(0xFFDCFCE7)
                                  : AppColors.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: _targetAutoAll
                                    ? const Color(0xFF86EFAC)
                                    : AppColors.primary.withValues(alpha: 0.3),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  _targetAutoAll
                                      ? Icons.auto_awesome
                                      : Icons.tune_outlined,
                                  size: 12,
                                  color: _targetAutoAll
                                      ? const Color(0xFF15803D)
                                      : AppColors.primary,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  _targetAutoAll ? 'Otomatis' : 'Manual',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: _targetAutoAll
                                        ? const Color(0xFF15803D)
                                        : AppColors.primary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  helperText: _targetAutoAll
                      ? '✨ Mode Otomatis: Mencakup seluruh unit aktif (${_maxTargetUnit ?? 0} unit) & unit baru yang ditambahkan nanti.'
                      : '⚙️ Mode Manual: Membatasi kuota target maintenance per siklus (maksimal ${_maxTargetUnit ?? 0} unit).',
                  helperMaxLines: 2,
                  errorText: _targetLimitError,
                ),
                validator: (v) {
                  if (_targetAutoAll) return null;
                  final n = int.tryParse((v ?? '').trim());
                  if (n == null || n < 1) {
                    return 'Target manual wajib angka minimal 1';
                  }
                  if (_maxTargetUnit != null && n > _maxTargetUnit!) {
                    return 'Target maksimal $_maxTargetUnit unit';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 14),
              InkWell(
                onTap: () => _pickDate(true),
                child: InputDecorator(
                  decoration: InputDecoration(
                    label: _requiredLabel('Tanggal Mulai'),
                    prefixIcon: const Icon(Icons.calendar_today_outlined),
                  ),
                  child: Text(
                    _tglMulai != null
                        ? _fmtDateDisplay(_tglMulai)
                        : 'Pilih tanggal',
                    style: TextStyle(
                      color: _tglMulai != null
                          ? AppColors.textPrimary
                          : AppColors.textSecondary,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              InkWell(
                onTap: () => _pickDate(false),
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: 'Tanggal Selesai (opsional)',
                    prefixIcon: const Icon(Icons.event_outlined),
                    suffixIcon: _tglSelesai != null
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () => setState(() => _tglSelesai = null))
                        : null,
                  ),
                  child: Text(
                    _tglSelesai != null
                        ? _fmtDateDisplay(_tglSelesai)
                        : 'Tidak ada batas',
                    style: const TextStyle(color: AppColors.textSecondary),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _notesCtrl,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Catatan (opsional)',
                  prefixIcon: Icon(Icons.notes_outlined),
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.summarize_outlined,
                            size: 16, color: AppColors.primary),
                        SizedBox(width: 6),
                        Text(
                          'Ringkasan Jadwal',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    _buildJadwalSummaryWidget(context),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              if (jadwalP.error != null)
                Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                      color: const Color(0xFFFEE2E2),
                      borderRadius: BorderRadius.circular(8)),
                  child: Row(children: [
                    const Icon(Icons.error_outline,
                        color: AppColors.danger, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                        child: Text(jadwalP.error!,
                            style: const TextStyle(
                                color: AppColors.danger, fontSize: 13))),
                  ]),
                ),
              Consumer<JadwalProvider>(
                builder: (_, p, __) => ElevatedButton(
                  onPressed: p.loading ? null : _submit,
                  child: p.loading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2))
                      : Text(isEdit ? 'Simpan Perubahan' : 'Buat Jadwal'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
// ═══════════════════════════════════════════════════════════════
//  RINGKASAN JADWAL WIDGET (Visual Preview Realtime)
// ═══════════════════════════════════════════════════════════════
class _SummaryWidget extends StatelessWidget {
  final String judul;
  final String jenis;
  final String frekuensi;
  final int target;
  final String lokasi;
  final String mulai;
  final String selesai;
  final int jadwalGapHari;
  final int jenisGapHari;
  final String pelaksana;

  const _SummaryWidget({
    required this.judul,
    required this.jenis,
    required this.frekuensi,
    required this.target,
    required this.lokasi,
    required this.mulai,
    required this.selesai,
    required this.jadwalGapHari,
    required this.jenisGapHari,
    required this.pelaksana,
  });

  @override
  Widget build(BuildContext context) {
    final showJadwalGap = frekuensi == 'Mingguan' || frekuensi == 'Bulanan';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.primary.withValues(alpha: 0.15)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.title_outlined, size: 16, color: AppColors.primary),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  judul,
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                    height: 1.3,
                  ),
                ),
              ),
            ],
          ),
        ),
        _row(Icons.category_outlined, 'Jenis Inventaris', jenis),
        _row(Icons.person_outline, 'Pelaksana', pelaksana),
        _row(Icons.repeat_outlined, 'Frekuensi', frekuensi),
        _row(Icons.flag_outlined, 'Target',
            target > 0 ? '$target unit per $frekuensi' : 'Semua unit (Otomatis) per $frekuensi'),
        _row(Icons.location_on_outlined, 'Lokasi / Pabrik', lokasi),
        _row(Icons.calendar_today_outlined, 'Mulai', mulai),
        _row(Icons.event_outlined, 'Selesai', selesai),
        if (showJadwalGap)
          _rowWithNote(
            Icons.timelapse_outlined,
            'Gap Jadwal',
            jadwalGapHari == 0
                ? 'Tidak ada (jadwal bisa dikerjakan kapan saja)'
                : 'Jadwal akan diperbaharui setiap $jadwalGapHari hari',
            jadwalGapHari > 0
                ? 'Jadwal berikutnya muncul konsisten $jadwalGapHari hari'
                : null,
            jadwalGapHari > 0
                ? const Color(0xFFF97316)
                : const Color(0xFF16A34A),
          ),
        _rowWithNote(
          Icons.schedule_outlined,
          'Gap per Jenis Inventaris',
          jenisGapHari == 0
              ? 'Tidak ada (Inventaris jenis ini bisa di-maintenance kapan saja)'
              : 'Inventaris jenis ini memiliki jeda $jenisGapHari hari untuk maintenance selanjutnya',
          null,
          jenisGapHari > 0 ? AppColors.primary : AppColors.textSecondary,
        ),
      ],
    );
  }

  Widget _row(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 14, color: AppColors.textSecondary),
          const SizedBox(width: 6),
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                  fontSize: 12, color: AppColors.textPrimary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _rowWithNote(
      IconData icon, String label, String value, String? note, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: TextStyle(
                  fontSize: 12,
                  color: color,
                  fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w600),
                ),
                if (note != null)
                  Text(
                    note,
                    style: const TextStyle(
                        fontSize: 11, color: Colors.orange, height: 1.4),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
