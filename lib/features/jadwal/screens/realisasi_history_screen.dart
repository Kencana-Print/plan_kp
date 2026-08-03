// ignore_for_file: prefer_const_constructors, deprecated_member_use, curly_braces_in_flow_control_structures, dead_null_aware_expression, control_flow_in_finally

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/shimmer_loading.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/jadwal_model.dart';
import '../models/realisasi_model.dart';
import '../providers/jadwal_provider.dart';
import '../../../core/widgets/app_notifier.dart';
import '../widgets/realisasi_detail_sheet.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/utils/date_formatter.dart';
import '../widgets/export_pdf_dialog.dart';

class RealisasiHistoryScreen extends StatefulWidget {
  final String? initialTab;
  const RealisasiHistoryScreen({super.key, this.initialTab});

  @override
  State<RealisasiHistoryScreen> createState() => _RealisasiHistoryScreenState();
}

class _RealisasiHistoryScreenState extends State<RealisasiHistoryScreen> {
  DateTime _selectedMonth = DateTime(DateTime.now().year, DateTime.now().month);
  int? _selectedDay;
  int? _selectedUserId;
  String _activeTab = 'Selesai'; // 'Selesai' atau 'Draft' (Menunggu TTD)
  List<RealisasiModel> _draftRealisasiList = [];
  bool _loadingDraft = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialTab != null) {
      _activeTab = widget.initialTab!;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadData());
  }

  Future<void> _loadDraftData() async {
    setState(() => _loadingDraft = true);
    try {
      final auth = context.read<AuthProvider>();
      final role = auth.user?['user_jabatan'];
      final isManager = role == 'manager';
      final provider = context.read<JadwalProvider>();
      final drafts = await provider.fetchDraftRealisasi(
        byDivisi: isManager ? false : true,
      );
      setState(() {
        _draftRealisasiList = drafts;
      });
    } catch (e) {
      debugPrint('[LOAD DRAFT ERROR] $e');
    } finally {
      setState(() => _loadingDraft = false);
    }
  }

  Future<void> _loadData() async {
    final auth = context.read<AuthProvider>();
    final role = auth.user?['user_jabatan'];
    final isAdmin = role == 'admin';
    final isManager = role == 'manager';
    final provider = context.read<JadwalProvider>();

    if (_activeTab == 'Selesai') {
      if (isManager) {
        await provider.fetchJadwal();
        await provider.fetchRealisasi(status: 'Selesai');
      } else if (isAdmin) {
        await provider.fetchJadwalByDivisi();
        await provider.fetchRealisasi(status: 'Selesai', byDivisi: true);
      } else {
        await provider.fetchJadwalByUser();
        await provider.fetchRealisasi(status: 'Selesai');
      }
      await provider.fetchHariLiburForMonth(_selectedMonth);
    } else {
      await _loadDraftData();
    }
  }

  void _previousMonth() {
    setState(() {
      _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month - 1);
      _selectedDay = null;
    });
    context.read<JadwalProvider>().fetchHariLiburForMonth(_selectedMonth);
  }

  void _nextMonth() {
    setState(() {
      _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month + 1);
      _selectedDay = null;
    });
    context.read<JadwalProvider>().fetchHariLiburForMonth(_selectedMonth);
  }

  Future<void> _showRealisasiDetail(RealisasiModel item) async {
    final provider = context.read<JadwalProvider>();
    await provider.fetchRealisasiDetail(item.realId);
    if (!mounted) return;

    final detail = provider.realisasiDetail;
    if (detail == null) {
      await AppNotifier.showError(context, 'Detail realisasi tidak ditemukan');
      return;
    }

    await RealisasiDetailSheet.show(
      context,
      detail: detail,
      title: 'Detail Realisasi Unit',
    );
  }

  // Meta item untuk popup detail hari
  Widget _buildCompactMetaItem({required String label, required String value}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: RichText(
        text: TextSpan(
          style: const TextStyle(
            fontSize: 11,
            color: AppColors.textSecondary,
            height: 1.2,
          ),
          children: [
            TextSpan(
              text: '$label: ',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            TextSpan(text: value),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: AppColors.textSecondary),
          const SizedBox(width: 8),
          SizedBox(
            width: 90,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          const Text(
            ': ',
            style: TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showDayRealisasiPopup({
    required int day,
    required List<RealisasiModel> filteredMonthRealisasi,
  }) async {
    final selectedDate =
        DateTime(_selectedMonth.year, _selectedMonth.month, day);
    final dayRealisasi =
        _filterRealisasiBySelectedDay(filteredMonthRealisasi, day);

    setState(() {
      _selectedDay = day;
    });

    try {
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        builder: (context) {
          final media = MediaQuery.of(context);
          return SafeArea(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxHeight: media.size.height * 0.8),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Detail Realisasi ${selectedDate.day.toString().padLeft(2, '0')}/${selectedDate.month.toString().padLeft(2, '0')}/${selectedDate.year}',
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 4),
                    Text('${dayRealisasi.length} realisasi',
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.textSecondary)),
                    const SizedBox(height: 12),
                    if (dayRealisasi.isEmpty)
                      const Expanded(
                          child: Center(
                              child: EmptyState(
                                  message:
                                      'Tidak ada realisasi pada tanggal ini')))
                    else
                      Expanded(
                        child: ListView.separated(
                          itemCount: dayRealisasi.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            final item = dayRealisasi[index];
                            final title = (item.jadwal?['jdw_judul'] ?? '')
                                .toString()
                                .trim();
                            final teknisi = (item.teknisi?['user_nama'] ?? '')
                                .toString()
                                .trim();

                            return Container(
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: AppColors.border),
                              ),
                              child: ListTile(
                                dense: true,
                                onTap: () => _showRealisasiDetail(item),
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 4),
                                leading: const Icon(Icons.task_alt_rounded,
                                    color: AppColors.success),
                                title: Text(
                                    title.isEmpty
                                        ? 'Jadwal #${item.realJadwalId}'
                                        : title,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 13)),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const SizedBox(height: 4),
                                    Wrap(
                                      spacing: 8,
                                      runSpacing: 6,
                                      children: [
                                        _buildCompactMetaItem(
                                            label: 'Inv',
                                            value: item.invNama ?? '-'),
                                        _buildCompactMetaItem(
                                            label: 'Teknisi',
                                            value: teknisi.isEmpty
                                                ? '-'
                                                : teknisi),
                                        _buildCompactMetaItem(
                                            label: 'PIC',
                                            value: item.realTtdPicNama ?? '-'),
                                      ],
                                    ),
                                  ],
                                ),
                                trailing: OutlinedButton(
                                  onPressed: () => _showRealisasiDetail(item),
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    minimumSize: Size.zero,
                                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                    foregroundColor: AppColors.textSecondary,
                                    side: const BorderSide(color: AppColors.border),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                  ),
                                  child: const Text('Detail', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                                ),
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
    } finally {
      if (!mounted) return;
      setState(() {
        _selectedDay = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final role = auth.user?['user_jabatan'];
    final isAdmin = role == 'admin' || role == 'manager';
    final isDesktop = AppBreakpoints.isDesktop(context);
    final isTablet = AppBreakpoints.isTablet(context);
    final horizontalPadding = isDesktop
        ? 24.0
        : isTablet
            ? 20.0
            : 16.0;
    final maxContentWidth = isDesktop ? 1180.0 : 860.0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Realisasi'),
        actions: [
          IconButton(
            tooltip: 'Export Laporan PDF',
            icon: const Icon(Icons.picture_as_pdf_rounded),
            onPressed: () {
              final p = context.read<JadwalProvider>();
              ExportPdfDialog.show(
                context,
                realisasiList: p.realisasiList,
                jadwalList: p.jadwalList,
              );
            },
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: Consumer<JadwalProvider>(
          builder: (_, p, __) {
            final isLoading = _activeTab == 'Selesai' ? p.loading : _loadingDraft;
            if (isLoading) {
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

            List<RealisasiModel> monthRealisasi = [];
            List<JadwalModel> filteredJadwal = [];
            List<RealisasiModel> filteredMonthRealisasi = [];
            Set<int> holidayDays = {};
            _MonthlyHistoryMetrics metrics = _MonthlyHistoryMetrics(targetCount: 0, doneCount: 0);
            List<_UserFilterItem> userItems = [];
            _MonthlyRecapData recapData = _MonthlyRecapData(groups: []);
            List<int> sortedCrossMonthWeeks = [];

            if (_activeTab == 'Selesai') {
              monthRealisasi = _filterRealisasiByMonth(p.realisasiList, _selectedMonth);
              filteredJadwal = _filterJadwalBySelectedUser(p.jadwalList, _selectedUserId);
              filteredMonthRealisasi = _filterRealisasiBySelectedUser(monthRealisasi, _selectedUserId);
              holidayDays = p.getHolidayDaysForMonth(_selectedMonth);

              metrics = _buildMonthlyMetrics(
                jadwalList: filteredJadwal,
                realisasiList: filteredMonthRealisasi,
                month: _selectedMonth,
                holidayDays: holidayDays,
              );

              userItems = _buildUserFilterItems(p.jadwalList, p.realisasiList);
              recapData = _buildRecapData(
                jadwalList: filteredJadwal,
                realisasiList: filteredMonthRealisasi,
                month: _selectedMonth,
                holidayDays: holidayDays,
              );

              final crossMonthWeeks = <int>{};
              for (final r in filteredMonthRealisasi) {
                final frekuensi = (r.jadwal?['jdw_frekuensi'] ?? '').toString();
                if (frekuensi == 'Mingguan') {
                  final hasOtherMonth = p.realisasiList.any((other) =>
                      other.realWeekNumber == r.realWeekNumber &&
                      other.realTahun == r.realTahun &&
                      other.realBulan != r.realBulan);
                  if (hasOtherMonth) {
                    crossMonthWeeks.add(r.realWeekNumber);
                  }
                }
              }
              sortedCrossMonthWeeks = crossMonthWeeks.toList()..sort();
            }

            return Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxContentWidth),
                child: CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    // Tab Selector
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(
                            horizontalPadding, 16, horizontalPadding, 8),
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: InkWell(
                                  onTap: () {
                                    setState(() {
                                      _activeTab = 'Selesai';
                                    });
                                    _loadData();
                                  },
                                  borderRadius: BorderRadius.circular(9),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(vertical: 10),
                                    decoration: BoxDecoration(
                                      color: _activeTab == 'Selesai'
                                          ? AppColors.primary
                                          : Colors.transparent,
                                      borderRadius: BorderRadius.circular(9),
                                    ),
                                    child: Center(
                                      child: Text(
                                        'Selesai',
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                          color: _activeTab == 'Selesai'
                                              ? Colors.white
                                              : AppColors.textSecondary,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              Expanded(
                                child: InkWell(
                                  onTap: () {
                                    setState(() {
                                      _activeTab = 'Draft';
                                    });
                                    _loadData();
                                  },
                                  borderRadius: BorderRadius.circular(9),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(vertical: 10),
                                    decoration: BoxDecoration(
                                      color: _activeTab == 'Draft'
                                          ? AppColors.primary
                                          : Colors.transparent,
                                      borderRadius: BorderRadius.circular(9),
                                    ),
                                    child: Center(
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Text(
                                            'Menunggu TTD',
                                            style: TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w700,
                                              color: _activeTab == 'Draft'
                                                  ? Colors.white
                                                  : AppColors.textSecondary,
                                            ),
                                          ),
                                          if (_draftRealisasiList.isNotEmpty) ...[
                                            const SizedBox(width: 6),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: _activeTab == 'Draft'
                                                    ? Colors.white
                                                    : AppColors.primary,
                                                borderRadius: BorderRadius.circular(10),
                                              ),
                                              child: Text(
                                                '${_draftRealisasiList.length}',
                                                style: TextStyle(
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.bold,
                                                  color: _activeTab == 'Draft'
                                                      ? AppColors.primary
                                                      : Colors.white,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    if (_activeTab == 'Selesai') ...[
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: EdgeInsets.fromLTRB(
                              horizontalPadding, 16, horizontalPadding, 10),
                          child: LayoutBuilder(
                            builder: (_, constraints) {
                              final canUseSingleRow =
                                  isAdmin && constraints.maxWidth >= 840;

                              if (!isAdmin) {
                                return _MonthSwitcher(
                                  monthLabel: _monthLabel(_selectedMonth),
                                  onPrevious: _previousMonth,
                                  onNext: _nextMonth,
                                );
                              }

                               if (canUseSingleRow) {
                                return IntrinsicHeight(
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.stretch,
                                    children: [
                                      Expanded(
                                        flex: 6,
                                        child: _MonthSwitcher(
                                          monthLabel: _monthLabel(_selectedMonth),
                                          onPrevious: _previousMonth,
                                          onNext: _nextMonth,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        flex: 5,
                                        child: _UserFilterCard(
                                          selectedUserId: _selectedUserId,
                                          users: userItems,
                                          onChanged: (value) {
                                            setState(() {
                                              _selectedUserId = value;
                                              _selectedDay = null;
                                            });
                                          },
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }

                              return Wrap(
                                spacing: 10,
                                runSpacing: 10,
                                children: [
                                  SizedBox(
                                    width: constraints.maxWidth,
                                    child: _MonthSwitcher(
                                      monthLabel: _monthLabel(_selectedMonth),
                                      onPrevious: _previousMonth,
                                      onNext: _nextMonth,
                                    ),
                                  ),
                                  SizedBox(
                                    width: constraints.maxWidth,
                                    child: _UserFilterCard(
                                      selectedUserId: _selectedUserId,
                                      users: userItems,
                                      onChanged: (value) {
                                        setState(() {
                                          _selectedUserId = value;
                                          _selectedDay = null;
                                        });
                                      },
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                        ),
                      ),
                      if (sortedCrossMonthWeeks.isNotEmpty)
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: EdgeInsets.fromLTRB(
                                horizontalPadding, 0, horizontalPadding, 10),
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFF7ED),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: const Color(0xFFFED7AA)),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Padding(
                                    padding: EdgeInsets.only(top: 2, right: 6),
                                    child: Icon(
                                      Icons.warning_amber_rounded,
                                      size: 16,
                                      color: Color(0xFF92400E),
                                    ),
                                  ),
                                  Expanded(
                                    child: Text(
                                      'Catatan: Terdapat realisasi jadwal Mingguan pada minggu ke-${sortedCrossMonthWeeks.join(', ')} yang dicatat lintas bulan. Progress mingguan tetap dihitung sebagai 1 periode.',
                                      style: const TextStyle(
                                          fontSize: 12,
                                          color: Color(0xFF92400E),
                                          height: 1.5),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: EdgeInsets.fromLTRB(
                              horizontalPadding, 10, horizontalPadding, 10),
                          child: _SummaryCard(
                              monthLabel: _monthLabel(_selectedMonth),
                              metrics: metrics),
                        ),
                      ),
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: EdgeInsets.fromLTRB(
                              horizontalPadding, 4, horizontalPadding, 10),
                          child: _MonthlyDatePreview(
                            month: _selectedMonth,
                            realisasiList: filteredMonthRealisasi,
                            holidayDays: holidayDays,
                            selectedDay: _selectedDay,
                            onDayTap: (day) => _showDayRealisasiPopup(
                              day: day,
                              filteredMonthRealisasi: filteredMonthRealisasi,
                            ),
                          ),
                        ),
                      ),
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: EdgeInsets.fromLTRB(
                              horizontalPadding, 16, horizontalPadding, 8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              SizedBox(
                                width: double.infinity,
                                child: Text(
                                    'Penilaian ${_selectedUserId == null ? 'Semua User' : userItems.firstWhere((u) => u.userId == _selectedUserId, orElse: () => _UserFilterItem(userId: _selectedUserId ?? 0, userName: 'User')).userName} ${_monthLabel(_selectedMonth)}',
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 15)),
                              ),
                            ],
                          ),
                        ),
                      ),
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: EdgeInsets.fromLTRB(
                              horizontalPadding, 4, horizontalPadding, 100),
                          child: _MonthlyRecapTableCard(
                            data: recapData,
                          ),
                        ),
                      ),
                    ],

                    if (_activeTab == 'Draft') ...[
                      if (_draftRealisasiList.isEmpty)
                        const SliverFillRemaining(
                          hasScrollBody: false,
                          child: Center(
                            child: EmptyState(
                              message: 'Tidak ada realisasi yang menunggu TTD PIC',
                            ),
                          ),
                        )
                      else
                        SliverPadding(
                          padding: EdgeInsets.fromLTRB(
                              horizontalPadding, 8, horizontalPadding, 100),
                          sliver: SliverList(
                            delegate: SliverChildBuilderDelegate(
                              (context, index) {
                                final item = _draftRealisasiList[index];
                                final title = (item.jadwal?['jdw_judul'] ?? '')
                                    .toString()
                                    .trim();
                                final tglString = DateFormatter.toDisplay(item.realTgl);
                                final jamMulai = item.realJamMulai ?? '-';
                                final invNama = item.invNama ?? '-';
                                final jdwId = item.realJadwalId;
                                final invJenisId = item.jadwal?['jdw_inv_jenis_id'] ?? 0;
                                final invId = item.realInvId;
                                final teknisi = (item.teknisi?['user_nama'] ?? '').toString().trim();
                                final kondisiAkhir = item.realKondisiAkhir ?? '-';
                                final keterangan = item.realKeterangan ?? '-';

                                return Card(
                                  margin: const EdgeInsets.only(bottom: 12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(AppRadius.lg),
                                    side: BorderSide(
                                        color: AppColors.border.withValues(alpha: 0.8)),
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.symmetric(
                                                  horizontal: 8, vertical: 4),
                                              decoration: BoxDecoration(
                                                color: AppColors.warning
                                                    .withValues(alpha: 0.1),
                                                borderRadius:
                                                    BorderRadius.circular(AppRadius.sm),
                                              ),
                                              child: const Text(
                                                'Menunggu TTD PIC',
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w700,
                                                  color: AppColors.warning,
                                                ),
                                              ),
                                            ),
                                            Text(
                                              tglString,
                                              style: const TextStyle(
                                                fontSize: 12,
                                                color: AppColors.textSecondary,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 12),
                                        Text(
                                          title.isEmpty
                                              ? 'Jadwal #$jdwId'
                                              : title,
                                          style: const TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w700,
                                            color: AppColors.textPrimary,
                                          ),
                                        ),
                                        if (isAdmin) ...[
                                          const SizedBox(height: 8),
                                          const Divider(height: 1, color: AppColors.border),
                                          const SizedBox(height: 8),
                                          _buildDetailRow(Icons.person_outline_rounded, 'Teknisi', teknisi.isEmpty ? '-' : teknisi),
                                          _buildDetailRow(Icons.inventory_2_outlined, 'Aset', invNama),
                                          _buildDetailRow(Icons.access_time_rounded, 'Jam', jamMulai),
                                          _buildDetailRow(Icons.info_outline_rounded, 'Kondisi Akhir', kondisiAkhir),
                                          _buildDetailRow(Icons.description_outlined, 'Keterangan', keterangan),
                                        ] else ...[
                                          const SizedBox(height: 8),
                                          Row(
                                            children: [
                                              const Icon(Icons.inventory_2_outlined,
                                                  size: 14,
                                                  color: AppColors.textSecondary),
                                              const SizedBox(width: 6),
                                              Expanded(
                                                child: Text(
                                                  'Aset: $invNama',
                                                  style: const TextStyle(
                                                      fontSize: 13,
                                                      color: AppColors.textSecondary),
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 4),
                                          Row(
                                            children: [
                                              const Icon(Icons.access_time,
                                                  size: 14,
                                                  color: AppColors.textSecondary),
                                              const SizedBox(width: 6),
                                              Text(
                                                'Jam Mulai: $jamMulai',
                                                style: const TextStyle(
                                                    fontSize: 13,
                                                    color: AppColors.textSecondary),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 16),
                                          SizedBox(
                                            width: double.infinity,
                                            child: ElevatedButton.icon(
                                              onPressed: () async {
                                                await Navigator.pushNamed(
                                                  context,
                                                  AppRoutes.realisasiForm,
                                                  arguments: {
                                                    'realId': item.realId,
                                                    'jadwalId': jdwId,
                                                    'invJenisId': invJenisId,
                                                    'invId': invId,
                                                    'invNama': invNama,
                                                  },
                                                );
                                                _loadData();
                                              },
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: AppColors.primary,
                                                padding: const EdgeInsets.symmetric(
                                                    vertical: 12),
                                                shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(10),
                                                ),
                                              ),
                                              icon: const Icon(Icons.border_color,
                                                  size: 16),
                                              label: const Text(
                                                'Lanjutkan & TTD PIC',
                                                style: TextStyle(
                                                    fontSize: 13,
                                                    fontWeight: FontWeight.bold),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                );
                              },
                              childCount: _draftRealisasiList.length,
                            ),
                          ),
                        ),
                    ],
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  // --- Helper Methods (Filter & Logic) ---
  List<RealisasiModel> _filterRealisasiByMonth(
      List<RealisasiModel> list, DateTime month) {
    return list.where((item) {
      final tgl = DateTime.tryParse(item.realTgl);
      return tgl != null && tgl.year == month.year && tgl.month == month.month;
    }).toList();
  }

  List<RealisasiModel> _filterRealisasiBySelectedDay(
      List<RealisasiModel> list, int? day) {
    if (day == null) return list;
    return list.where((item) {
      final tgl = DateTime.tryParse(item.realTgl);
      return tgl != null && tgl.day == day;
    }).toList();
  }

  List<JadwalModel> _filterJadwalBySelectedUser(
      List<JadwalModel> list, int? selectedUserId) {
    if (selectedUserId == null) return list;
    return list.where((item) => item.jdwAssignedTo == selectedUserId).toList();
  }

  List<RealisasiModel> _filterRealisasiBySelectedUser(
      List<RealisasiModel> list, int? selectedUserId) {
    if (selectedUserId == null) return list;
    return list.where((item) => item.realTeknisiId == selectedUserId).toList();
  }

  List<_UserFilterItem> _buildUserFilterItems(
      List<JadwalModel> jadwalList, List<RealisasiModel> realisasiList) {
    final byId = <int, String>{};
    for (final item in jadwalList) {
      final id = item.jdwAssignedTo;
      if (id == null || id <= 0) continue;
      final name = (item.assignedUser?['user_nama'] ?? '').toString().trim();
      byId[id] = name.isEmpty ? 'User #$id' : name;
    }
    for (final item in realisasiList) {
      final id = item.realTeknisiId;
      if (id <= 0) continue;
      final name = (item.teknisi?['user_nama'] ?? '').toString().trim();
      byId[id] = name.isEmpty ? (byId[id] ?? 'User #$id') : name;
    }
    return byId.entries
        .map((e) => _UserFilterItem(userId: e.key, userName: e.value))
        .toList()
      ..sort((a, b) => a.userName.compareTo(b.userName));
  }

  _MonthlyRecapData _buildRecapData({
    required List<JadwalModel> jadwalList,
    required List<RealisasiModel> realisasiList,
    required DateTime month,
    required Set<int> holidayDays,
  }) {
    final monthStart = DateTime(month.year, month.month, 1);
    final monthEnd = DateTime(month.year, month.month + 1, 0);

    final targetByJdwId = <int, int>{};
    final targetPerPeriodByJdwId = <int, int>{};
    final realisasiByJdwId = <int, int>{};
    final frequencyByJdwId = <int, String>{};
    final taskNameByJdwId = <int, String>{};

    for (final j in jadwalList) {
      if (j.jdwStatus != 'Draft') continue;
      frequencyByJdwId[j.jdwId] = j.jdwFrekuensi;
      taskNameByJdwId[j.jdwId] =
          j.jdwJudul.isEmpty ? 'Jadwal #${j.jdwId}' : j.jdwJudul;

      final appearances =
          _effectiveScheduleDatesInMonth(j, monthStart, monthEnd, holidayDays)
              .length;
      final perTarget =
          (j.jdwTarget ?? 0) > 0 ? (j.jdwTarget ?? 0) : (j.jdwTotalUnit ?? 0);

      targetByJdwId[j.jdwId] = appearances * perTarget;
      targetPerPeriodByJdwId[j.jdwId] = perTarget;
    }

    for (final r in realisasiList) {
      realisasiByJdwId.update(r.realJadwalId, (val) => val + 1,
          ifAbsent: () => 1);
      if (!taskNameByJdwId.containsKey(r.realJadwalId)) {
        taskNameByJdwId[r.realJadwalId] =
            (r.jadwal?['jdw_judul'] ?? '').toString();
        frequencyByJdwId[r.realJadwalId] =
            (r.jadwal?['jdw_frekuensi'] ?? '').toString();
      }
    }

    final freqs = ['Harian', 'Mingguan', 'Bulanan'];
    final groups = freqs.map((f) {
      final ids = frequencyByJdwId.entries
          .where((e) => e.value.toLowerCase() == f.toLowerCase())
          .map((e) => e.key)
          .toList();
      final details = ids
          .map((id) => _RekapDetailRow(
                namaTugas: taskNameByJdwId[id] ?? 'Jadwal #$id',
                totalTargetPerPeriod: targetPerPeriodByJdwId[id] ?? 0,
                target: targetByJdwId[id] ?? 0,
                realisasi: realisasiByJdwId[id] ?? 0,
              ))
          .toList()
        ..sort((a, b) => a.namaTugas.compareTo(b.namaTugas));

      return _RekapFrequencyGroup(frequency: f, details: details);
    }).toList();

    return _MonthlyRecapData(groups: groups);
  }

  _MonthlyHistoryMetrics _buildMonthlyMetrics({
    required List<JadwalModel> jadwalList,
    required List<RealisasiModel> realisasiList,
    required DateTime month,
    required Set<int> holidayDays,
  }) {
    int target = 0;
    final start = DateTime(month.year, month.month, 1);
    final end = DateTime(month.year, month.month + 1, 0);
    for (final j in jadwalList) {
      if (j.jdwStatus != 'Draft') continue;
      final count =
          _effectiveScheduleDatesInMonth(j, start, end, holidayDays).length;
      target += count *
          ((j.jdwTarget ?? 0) > 0 ? (j.jdwTarget ?? 0) : (j.jdwTotalUnit ?? 0));
    }
    return _MonthlyHistoryMetrics(
        targetCount: target, doneCount: realisasiList.length);
  }

  static const List<String> _divisiSixDays = ['GA', 'TEKNISI', 'MAINTENANCE', 'PRODUKSI', 'WORKSHOP'];

  bool _isWorkingDay(DateTime date, String? divisi, Set<int> holidays) {
    if (holidays.contains(date.day)) return false;
    if (date.weekday == DateTime.sunday) return false;
    if (date.weekday == DateTime.saturday) {
      final norm = (divisi ?? '').trim().toUpperCase();
      return _divisiSixDays.any((d) => d.toUpperCase() == norm);
    }
    return true;
  }

  DateTime? _findNextWorkingDay(DateTime date, DateTime limit, String? divisi, Set<int> holidays) {
    var d = date;
    while (!_isWorkingDay(d, divisi, holidays)) {
      d = d.add(const Duration(days: 1));
      if (d.isAfter(limit)) return null;
    }
    return d;
  }

  List<DateTime> _effectiveScheduleDatesInMonth(
      JadwalModel j, DateTime start, DateTime end, Set<int> holidays) {
    final jStart = DateTime.tryParse(j.jdwTglMulai);
    if (jStart == null) return [];
    final rangeStart = jStart.isAfter(start) ? jStart : start;
    final jEndStr = j.jdwTglSelesai;
    final jEnd = (jEndStr == null || jEndStr.isEmpty)
        ? end
        : (DateTime.tryParse(jEndStr) ?? end);
    final rangeEnd = jEnd.isBefore(end) ? jEnd : end;

    if (rangeEnd.isBefore(rangeStart)) return [];
    List<DateTime> dates = [];
    final divisi = j.jdwDivisi;

    if (j.jdwFrekuensi == 'Harian') {
      for (var d = rangeStart;
          !d.isAfter(rangeEnd);
          d = d.add(const Duration(days: 1))) {
        if (_isWorkingDay(d, divisi, holidays)) dates.add(d);
      }
    } else if (j.jdwFrekuensi == 'Mingguan') {
      var curr = jStart;
      while (!curr.isAfter(rangeEnd)) {
        if (!curr.isBefore(rangeStart)) {
          final nextWork = _findNextWorkingDay(curr, rangeEnd, divisi, holidays);
          if (nextWork != null) {
            dates.add(nextWork);
          }
        }
        curr = curr.add(const Duration(days: 7));
      }
    } else if (j.jdwFrekuensi == 'Bulanan') {
      final nextWork = _findNextWorkingDay(rangeStart, rangeEnd, divisi, holidays);
      if (nextWork != null) {
        dates.add(nextWork);
      }
    }
    return dates;
  }

  String _monthLabel(DateTime m) {
    const names = [
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
    return '${names[m.month - 1]} ${m.year}';
  }
}

String _monthLabel(DateTime m) {
  const names = [
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
  return '${names[m.month - 1]} ${m.year}';
}

// --- REFINED RECAP COMPONENTS ---

class _MonthlyRecapTableCard extends StatefulWidget {
  final _MonthlyRecapData data;
  const _MonthlyRecapTableCard({required this.data});

  @override
  State<_MonthlyRecapTableCard> createState() => _MonthlyRecapTableCardState();
}

class _MonthlyRecapTableCardState extends State<_MonthlyRecapTableCard> {
  final Set<String> _expandedFrequencies = <String>{};

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: AppColors.border.withValues(alpha: 0.8)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildTopStats(),
            const SizedBox(height: 14),
            const Divider(height: 32),
            ...widget.data.groups
                .map((group) => _buildFrequencyBlock(context, group)),
          ],
        ),
      ),
    );
  }

  Widget _buildTopStats() {
    final summary = _summaryLabel(widget.data.totalNilaiPercent);
    final summaryColor = _summaryColor(widget.data.totalNilaiPercent);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _statItem(
                'Target', '${widget.data.totalTarget}', AppColors.primary),
            _statItem('Realisasi', '${widget.data.totalRealisasi}',
                AppColors.success),
            _statItem(
                'Presentase',
                '${widget.data.totalNilaiPercent.toStringAsFixed(1)}%',
                AppColors.warning),
          ],
        ),
        const SizedBox(height: 10),
        Align(
          alignment: Alignment.center,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              color: summaryColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: summaryColor.withValues(alpha: 0.28)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.insights_rounded, size: 14, color: summaryColor),
                const SizedBox(width: 6),
                Text(
                  'Skor: $summary',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: summaryColor,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  String _summaryLabel(double percent) {
    if (percent >= 90) return 'Sempurna';
    if (percent >= 80) return 'Baik';
    if (percent >= 70) return 'Cukup';
    return 'Buruk';
  }

  Color _summaryColor(double percent) {
    if (percent >= 90) return AppColors.success;
    if (percent >= 80) return AppColors.primary;
    if (percent >= 70) return AppColors.warning;
    return AppColors.danger;
  }

  Widget _statItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(value,
            style: TextStyle(
                fontSize: 18, fontWeight: FontWeight.w800, color: color)),
        Text(label,
            style:
                const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
      ],
    );
  }

  Widget _buildFrequencyBlock(
      BuildContext context, _RekapFrequencyGroup group) {
    final isExpanded = _expandedFrequencies.contains(group.frequency);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.8)),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
          childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          initiallyExpanded: false,
          onExpansionChanged: (expanded) {
            setState(() {
              if (expanded) {
                _expandedFrequencies.add(group.frequency);
              } else {
                _expandedFrequencies.remove(group.frequency);
              }
            });
          },
          title: Row(
            children: [
              Container(
                width: 4,
                height: 14,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                group.frequency,
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
            ],
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${group.nilaiPercent.toStringAsFixed(1)}%',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(width: 6),
              Icon(
                isExpanded
                    ? Icons.expand_less_rounded
                    : Icons.expand_more_rounded,
                color: AppColors.textSecondary,
              ),
            ],
          ),
          children: group.details.isEmpty
              ? const [
                  Padding(
                    padding: EdgeInsets.only(top: 4, bottom: 4),
                    child: Text(
                      'Jadwal tidak ada',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ]
              : group.details
                  .asMap()
                  .entries
                  .map((entry) =>
                      _recapItem(entry.value, group.frequency, entry.key))
                  .toList(),
        ),
      ),
    );
  }

  Widget _recapItem(_RekapDetailRow detail, String frequency, int index) {
    final percent = detail.nilaiPercent;
    final color = percent >= 90
        ? AppColors.success
        : (percent >= 70 ? AppColors.warning : AppColors.danger);
    final orderNumber = index + 1;
    final periodLabel = _periodLabelByFrequency(frequency);

    final bg = _detailCardBackground(frequency, index);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      width: 20,
                      height: 20,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.92),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: AppColors.border.withValues(alpha: 0.9),
                        ),
                      ),
                      child: Text(
                        '$orderNumber',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        detail.namaTugas,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Text('${percent.toStringAsFixed(0)}%',
                  style: TextStyle(
                      fontSize: 13, fontWeight: FontWeight.bold, color: color)),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: (percent / 100).clamp(0.0, 1.0),
              minHeight: 6,
              backgroundColor: Colors.white,
              color: color,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _metricBadge(
                  label: 'Total Target',
                  value: '${detail.target}',
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _metricBadge(
                  label: 'Realisasi',
                  value: '${detail.realisasi}',
                  color: AppColors.success,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              'Target per $periodLabel: ${detail.totalTargetPerPeriod}',
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _metricBadge({
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Color _detailCardBackground(String frequency, int index) {
    final isEven = index.isEven;
    if (frequency == 'Harian') {
      return isEven ? const Color(0xFFEAF4FF) : const Color(0xFFF1F8FF);
    }
    if (frequency == 'Mingguan') {
      return isEven ? const Color(0xFFF1FBEF) : const Color(0xFFF7FCF5);
    }
    return isEven ? const Color(0xFFFFF6E8) : const Color(0xFFFFFAF1);
  }

  String _periodLabelByFrequency(String frequency) {
    switch (frequency) {
      case 'Harian':
        return 'hari';
      case 'Mingguan':
        return 'minggu';
      case 'Bulanan':
        return 'bulan';
      default:
        return 'periode';
    }
  }
}

// --- SHARED UI COMPONENTS (MonthSwitcher, SummaryCard, etc.) ---

class _MonthSwitcher extends StatelessWidget {
  final String monthLabel;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  const _MonthSwitcher(
      {required this.monthLabel,
      required this.onPrevious,
      required this.onNext});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        child: Row(
          children: [
            IconButton(
                onPressed: onPrevious,
                icon: const Icon(Icons.chevron_left, color: AppColors.primary)),
            Expanded(
                child: Center(
                    child: Text(monthLabel,
                        style: const TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w700)))),
            IconButton(
                onPressed: onNext,
                icon:
                    const Icon(Icons.chevron_right, color: AppColors.primary)),
          ],
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String monthLabel;
  final _MonthlyHistoryMetrics metrics;
  const _SummaryCard({required this.monthLabel, required this.metrics});

  @override
  Widget build(BuildContext context) {
    final rate = metrics.completionRate;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            _DonutChart(
                progress: rate,
                size: 100,
                doneColor: const Color(0xFF059669),
                remainingColor: const Color(0xFFE2E8F0)),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Capaian $monthLabel',
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  _rowMetric('Target', '${metrics.targetCount}',
                      const Color(0xFF059669)),
                  _rowMetric(
                      'Realisasi', '${metrics.doneCount}', const Color(0xFF0052FF)),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _rowMetric(String l, String v, Color c) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
          const SizedBox(width: 8),
          Text(l,
              style: const TextStyle(
                  fontSize: 12, color: AppColors.textSecondary)),
          const Spacer(),
          Text(v,
              style:
                  const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

class _UserFilterCard extends StatelessWidget {
  final int? selectedUserId;
  final List<_UserFilterItem> users;
  final ValueChanged<int?> onChanged;
  const _UserFilterCard(
      {required this.selectedUserId,
      required this.users,
      required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: DropdownButtonFormField<int?>(
          value: selectedUserId,
          style: const TextStyle(fontSize: 13, color: AppColors.textPrimary),
          decoration: const InputDecoration(
              labelText: 'Pilih User',
              prefixIcon: Icon(Icons.person_outline),
              border: InputBorder.none),
          items: [
            const DropdownMenuItem(
                value: null,
                child: Text('Semua User',
                    style: TextStyle(fontSize: 13, color: AppColors.textPrimary))),
            ...users.map((u) => DropdownMenuItem(
                value: u.userId,
                child: Text(u.userName,
                    style:
                        const TextStyle(fontSize: 13, color: AppColors.textPrimary)))),
          ],
          onChanged: onChanged,
        ),
      ),
    );
  }
}

class _MonthlyDatePreview extends StatelessWidget {
  final DateTime month;
  final List<RealisasiModel> realisasiList;
  final Set<int> holidayDays;
  final int? selectedDay;
  final ValueChanged<int> onDayTap;

  const _MonthlyDatePreview(
      {required this.month,
      required this.realisasiList,
      required this.holidayDays,
      required this.selectedDay,
      required this.onDayTap});

  @override
  Widget build(BuildContext context) {
    final firstDay = DateTime(month.year, month.month, 1);
    final totalDays = DateTime(month.year, month.month + 1, 0).day;
    final leadingEmpty = firstDay.weekday - 1; // Senin = 1
    final counts = <int, int>{};
    for (var r in realisasiList) {
      final d = DateTime.tryParse(r.realTgl);
      if (d != null) counts.update(d.day, (v) => v + 1, ifAbsent: () => 1);
    }

    final cells = <Widget>[];
    for (int i = 0; i < leadingEmpty; i++) {
      cells.add(const SizedBox.shrink());
    }

    for (int day = 1; day <= totalDays; day++) {
      final count = counts[day] ?? 0;
      cells.add(
        _dayCell(
          day: day,
          count: count,
          isHoliday: holidayDays.contains(day),
          isToday: _isToday(day),
          isSelected: selectedDay == day,
          onTap: () => onDayTap(day),
        ),
      );
    }

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Kalender Realisasi ${_monthLabel(month)}',
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 4),
            Wrap(
              spacing: 10,
              runSpacing: 4,
              children: const [
                _LegendDot(color: AppColors.success, label: 'Realisasi'),
                _LegendDot(color: AppColors.danger, label: 'Hari libur'),
              ],
            ),
            const SizedBox(height: 12),
            LayoutBuilder(
              builder: (_, constraints) {
                final ratio = constraints.maxWidth < 430
                    ? 0.95
                    : constraints.maxWidth > 980
                        ? 1.25
                        : 1.05;

                return GridView.count(
                  physics: const NeverScrollableScrollPhysics(),
                  shrinkWrap: true,
                  crossAxisCount: 7,
                  crossAxisSpacing: 6,
                  mainAxisSpacing: 6,
                  childAspectRatio: ratio,
                  children: [
                    ..._weekdayHeaders(),
                    ...cells,
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  bool _isToday(int day) {
    final now = DateTime.now();
    return now.year == month.year && now.month == month.month && now.day == day;
  }

  List<Widget> _weekdayHeaders() {
    const names = ['Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Min'];
    return names
        .map(
          (name) => Center(
            child: Text(
              name,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        )
        .toList();
  }

  Widget _dayCell({
    required int day,
    required int count,
    required bool isHoliday,
    required bool isToday,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final hasRealisasi = count > 0;
    final bg = isSelected
        ? AppColors.primary
        : isHoliday
            ? const Color(0xFFFEE2E2)
            : hasRealisasi
                ? AppColors.success.withValues(alpha: 0.14)
                : Colors.white;
    final fg = isSelected
        ? Colors.white
        : isHoliday
            ? AppColors.danger
            : hasRealisasi
                ? AppColors.success
                : AppColors.textPrimary;
    final borderColor = isSelected
        ? AppColors.primary
        : isToday
            ? AppColors.primary
            : AppColors.border;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: borderColor, width: isSelected ? 1.8 : 1),
          ),
          child: Stack(
            children: [
              Center(
                child: Text(
                  '$day',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: fg,
                  ),
                ),
              ),
              if (count > 1)
                Positioned(
                  right: 3,
                  top: 3,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? Colors.white.withValues(alpha: 0.9)
                          : (isHoliday ? AppColors.danger : AppColors.success),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '$count',
                      style: TextStyle(
                        color: isSelected ? AppColors.primary : Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
        ),
      ],
    );
  }
}

class _DonutChart extends StatelessWidget {
  final double progress;
  final double size;
  final Color doneColor;
  final Color remainingColor;
  const _DonutChart(
      {required this.progress,
      required this.size,
      required this.doneColor,
      required this.remainingColor});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: Size(size, size),
            painter: _DonutPainter(
                progress: progress,
                doneColor: doneColor,
                remainingColor: remainingColor),
          ),
          Text('${(progress * 100).toStringAsFixed(0)}%',
              style:
                  const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        ],
      ),
    );
  }
}

class _DonutPainter extends CustomPainter {
  final double progress;
  final Color doneColor;
  final Color remainingColor;
  _DonutPainter(
      {required this.progress,
      required this.doneColor,
      required this.remainingColor});

  @override
  void paint(Canvas canvas, Size size) {
    final strokeWidth = size.width * 0.12;
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;

    final bgPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..color = remainingColor;
    canvas.drawCircle(center, radius, bgPaint);

    final fgPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..color = doneColor
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(Rect.fromCircle(center: center, radius: radius),
        -math.pi / 2, 2 * math.pi * progress, false, fgPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

// --- DATA MODELS ---

class _MonthlyHistoryMetrics {
  final int targetCount;
  final int doneCount;
  _MonthlyHistoryMetrics({required this.targetCount, required this.doneCount});
  double get completionRate =>
      targetCount > 0 ? (doneCount / targetCount).clamp(0.0, 1.0) : 0.0;
}

class _UserFilterItem {
  final int userId;
  final String userName;
  _UserFilterItem({required this.userId, required this.userName});
}

class _RekapDetailRow {
  final String namaTugas;
  final int totalTargetPerPeriod;
  final int realisasi;
  final int target;
  _RekapDetailRow(
      {required this.namaTugas,
      required this.totalTargetPerPeriod,
      required this.realisasi,
      required this.target});
  double get nilaiPercent => target > 0 ? (realisasi / target) * 100 : 0.0;
}

class _RekapFrequencyGroup {
  final String frequency;
  final List<_RekapDetailRow> details;
  _RekapFrequencyGroup({required this.frequency, required this.details});
  int get totalTarget => details.fold(0, (s, i) => s + i.target);
  int get totalRealisasi => details.fold(0, (s, i) => s + i.realisasi);
  double get nilaiPercent =>
      totalTarget > 0 ? (totalRealisasi / totalTarget) * 100 : 0.0;
}

class _MonthlyRecapData {
  final List<_RekapFrequencyGroup> groups;
  _MonthlyRecapData({required this.groups});
  int get totalTarget => groups.fold(0, (s, i) => s + i.totalTarget);
  int get totalRealisasi => groups.fold(0, (s, i) => s + i.totalRealisasi);
  int get totalDetailRows => groups.fold(0, (s, i) => s + i.details.length);
  double get totalNilaiPercent =>
      totalTarget > 0 ? (totalRealisasi / totalTarget) * 100 : 0.0;
}
