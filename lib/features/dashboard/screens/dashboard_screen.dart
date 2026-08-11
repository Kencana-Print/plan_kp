import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:awesome_dialog/awesome_dialog.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/widgets/app_notifier.dart';
import '../../../core/utils/date_formatter.dart';
import '../../auth/providers/auth_provider.dart';
import '../../../features/master/providers/master_provider.dart';
import '../../jadwal/models/jadwal_model.dart';
import '../../jadwal/models/realisasi_model.dart';
import '../../jadwal/providers/jadwal_provider.dart';
import '../../jadwal/screens/jadwal_screen.dart' as jadwal_screen;
import '../../jadwal/screens/realisasi_history_screen.dart';
import '../../master/screens/inventaris_screen.dart';
import '../../master/screens/checklist_template_screen.dart';
import '../../master/screens/jenis_screen.dart';
import '../../master/screens/user_screen.dart';
import '../../jadwal/widgets/realisasi_detail_sheet.dart';
import '../../../core/widgets/shimmer_loading.dart';
import '../../../core/utils/responsive_sheet.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  static const _pageBg = AppColors.surface;
  static const List<String> _monthNames = [
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
  bool _hasCheckedPendingTtd = false;
  bool _isLoadingData = false;
  List<RealisasiModel> _pendingDrafts = [];
  int _heroCardPageIndex = 0;
  final PageController _heroCardPageController = PageController();
  int _managerChartPageIndex = 0;
  final PageController _managerChartPageController = PageController();
  DateTime _selectedTargetMonth = DateTime(DateTime.now().year, DateTime.now().month);
  String? _selectedDivisiHighlight;
  int? _activeMonthPopupIndex;
  Timer? _popoverDismissTimer;
  int? _activeSchedulingPopupIndex;
  Timer? _schedulingDismissTimer;
  bool _isManagerJadwalExpanded = false;

  @override
  void dispose() {
    _heroCardPageController.dispose();
    _managerChartPageController.dispose();
    _popoverDismissTimer?.cancel();
    _schedulingDismissTimer?.cancel();
    super.dispose();
  }

  void _startPopoverDismissTimer() {
    _popoverDismissTimer?.cancel();
    _popoverDismissTimer = Timer(const Duration(seconds: 4), () {
      if (mounted && _activeMonthPopupIndex != null) {
        setState(() {
          _activeMonthPopupIndex = null;
        });
      }
    });
  }

  void _startSchedulingDismissTimer() {
    _schedulingDismissTimer?.cancel();
    _schedulingDismissTimer = Timer(const Duration(seconds: 4), () {
      if (mounted && _activeSchedulingPopupIndex != null) {
        setState(() {
          _activeSchedulingPopupIndex = null;
        });
      }
    });
  }

  void _showPendingTtdDialog(List<RealisasiModel> drafts) {
    AwesomeDialog(
      context: context,
      dialogType: DialogType.warning,
      animType: AnimType.bottomSlide,
      title: 'Tanda Tangan Tertunda',
      desc: 'Anda memiliki ${drafts.length} realisasi pemeliharaan yang belum ditandatangani oleh PIC. Harap segera menyelesaikan tanda tangan.',
      btnCancelText: 'Nanti',
      btnOkText: 'Lihat Riwayat',
      btnCancelOnPress: () {},
      btnOkOnPress: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const RealisasiHistoryScreen(initialTab: 'Draft'),
            settings: const RouteSettings(name: '/realisasi/history'),
          ),
        );
      },
    ).show();
  }

  Future<void> _showMonthYearPicker(BuildContext context) async {
    int tempBulan = _selectedTargetMonth.month;
    int tempTahun = _selectedTargetMonth.year;

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: Colors.white,
              surfaceTintColor: Colors.transparent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              titlePadding: const EdgeInsets.fromLTRB(20, 18, 16, 8),
              title: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Pilih Periode',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded,
                        color: AppColors.textSecondary, size: 20),
                    onPressed: () => Navigator.pop(context),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Tahun:',
                        style: TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 13),
                      ),
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.chevron_left_rounded,
                                size: 20),
                            onPressed: () {
                              setDialogState(() {
                                tempTahun--;
                              });
                            },
                          ),
                          Text(
                            '$tempTahun',
                            style: const TextStyle(
                                fontWeight: FontWeight.w700, fontSize: 15),
                          ),
                          IconButton(
                            icon: const Icon(Icons.chevron_right_rounded,
                                size: 20),
                            onPressed: () {
                              setDialogState(() {
                                tempTahun++;
                              });
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                  const Divider(height: 16, color: AppColors.border),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: 280,
                    height: 180,
                    child: GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 4,
                        childAspectRatio: 1.5,
                        crossAxisSpacing: 8,
                        mainAxisSpacing: 8,
                      ),
                      itemCount: 12,
                      itemBuilder: (context, index) {
                        final bulanNum = index + 1;
                        final isSelected = tempBulan == bulanNum;
                        final name = _monthNames[index].substring(0, 3);

                        return InkWell(
                          onTap: () {
                            setDialogState(() {
                              tempBulan = bulanNum;
                            });
                          },
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? AppColors.primary
                                  : const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: isSelected
                                    ? AppColors.primary
                                    : AppColors.border,
                              ),
                            ),
                            child: Text(
                              name,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: isSelected
                                    ? FontWeight.bold
                                    : FontWeight.w500,
                                color: isSelected
                                    ? Colors.white
                                    : AppColors.textPrimary,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
              actions: [
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    setState(() {
                      _selectedTargetMonth = DateTime(tempTahun, tempBulan);
                    });
                    context
                        .read<JadwalProvider>()
                        .fetchHariLiburForMonth(_selectedTargetMonth);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    minimumSize: const Size(90, 36),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text('Pilih',
                      style: TextStyle(fontSize: 13, color: Colors.white)),
                ),
              ],
            );
          },
        );
      },
    );
  }

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
      if (realDate == null) return false;
      return _dateOnly(realDate) == _dateOnly(now);
    }

    if (frequency == 'Mingguan') {
      return r.realTahun == now.year && r.realWeekNumber == _isoWeekNumber(now);
    }

    if (frequency == 'Bulanan') {
      return r.realTahun == now.year && r.realBulan == now.month;
    }

    return false;
  }

  static const List<String> _divisiSixDays = ['GA'];

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
      JadwalModel j, DateTime start, DateTime end, Set<int> holidays,
      {DateTime? lastRealisasiDate}) {
    final jStart = DateTime.tryParse(j.jdwTglMulai);
    if (jStart == null) return [];

    final gapHari = j.jdwGapHari;
    if (gapHari > 0 && lastRealisasiDate != null) {
      final nextEligibleDate = lastRealisasiDate.add(Duration(days: gapHari));
      final endMonthDate = DateTime(end.year, end.month, end.day, 23, 59, 59);
      if (endMonthDate.isBefore(nextEligibleDate)) {
        return [];
      }
    }

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

  DateTime? _getLastRealisasiDateForJadwal(int jdwId, List<RealisasiModel> realisasiList) {
    final list = realisasiList.where((r) => r.realJadwalId == jdwId && r.realStatus == 'Selesai').toList();
    if (list.isEmpty) return null;
    list.sort((a, b) => b.realTgl.compareTo(a.realTgl));
    return DateTime.tryParse(list.first.realTgl);
  }

  BoxDecoration _surfaceCard({Color? borderColor}) => BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: borderColor ?? const Color(0xFFE2E8F0),
          width: 1,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A0F172A),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadData());
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() {
      _isLoadingData = true;
    });

    try {
      final auth = context.read<AuthProvider>();
      final role = auth.user?['user_jabatan']?.toString().toLowerCase();
      final isManager = role == 'manager';
      final isAdmin = role == 'admin' || role == 'manager';
      final p = context.read<JadwalProvider>();

      if (isManager) {
        await Future.wait([
          p.fetchJadwal(),
          p.fetchRealisasi(status: 'Selesai'),
          p.fetchDashboardSummary(),
          p.fetchMonitoringDivisi(),
        ]);
      } else if (role == 'admin') {
        await Future.wait([
          p.fetchJadwalByDivisi(),
          p.fetchRealisasi(status: 'Selesai'),
          p.fetchDashboardSummary(),
        ]);
      } else {
        await Future.wait([
          p.fetchJadwalByUser(),
          p.fetchRealisasi(status: 'Selesai'),
          p.fetchDashboardSummary(),
        ]);
      }
      await p.fetchHariLiburForMonth(DateTime.now());
      if (!mounted) return;
      await context.read<MasterProvider>().fetchJenis();

      if (!isAdmin) {
        final drafts = await p.fetchDraftRealisasi();
        if (mounted) {
          setState(() {
            _pendingDrafts = drafts;
          });
        }
        if (!_hasCheckedPendingTtd && drafts.isNotEmpty && mounted) {
          _hasCheckedPendingTtd = true;
          _showPendingTtdDialog(drafts);
        }
      }
    } catch (e) {
      debugPrint('[Dashboard] Error loading data: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingData = false;
        });
      }
    }
  }


  String _userName(Map<String, dynamic>? user) =>
      (user?['user_nama'] ?? 'User').toString().trim();
  String _userInitial(Map<String, dynamic>? user) =>
      _userName(user).isNotEmpty ? _userName(user)[0].toUpperCase() : 'U';

  Widget _buildHeaderUserSection({
    required AuthProvider auth,
    required bool isLoading,
  }) {
    final user = auth.user;
    final role = user?['user_jabatan']?.toString().toLowerCase();

    if (isLoading || user == null) {
      return AppShimmer(
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.25),
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.4),
                  width: 2,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 75,
                    height: 11,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(height: 5),
                  Container(
                    width: 130,
                    height: 15,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.45),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(height: 5),
                  Container(
                    width: 105,
                    height: 10,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  const SizedBox(height: 5),
                  Container(
                    width: 60,
                    height: 16,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Row(
      children: [
        // Avatar dengan Ring White Border & Initial
        Container(
          padding: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: Colors.white,
              width: 2.2,
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x26000000),
                blurRadius: 8,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: CircleAvatar(
            radius: 20,
            backgroundColor: const Color(0xFF0038FF),
            child: Text(
              _userInitial(user),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        // Nama, Greeting, Tanggal, dan Role Badge
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _greeting(),
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.9),
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 1),
              Text(
                _userName(user).toUpperCase(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.3,
                ),
              ),
              const SizedBox(height: 3),
              Row(
                children: [
                  const SizedBox(width: 4),
                  Text(
                    DateFormatter.toDisplayDateTime(DateTime.now()),
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.85),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(99),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.3),
                        width: 0.8,
                      ),
                    ),
                    child: Text(
                      role == 'manager'
                          ? 'MANAGER'
                          : '${user['user_divisi'] ?? 'Teknisi'}'.toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.4,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }


  void _showKendalaBottomSheet(
    BuildContext context,
    List<RealisasiModel> initialList, {
    String? userDivisi,
  }) {
    showResponsiveSheet(
      context,
      maxDesktopWidth: 680,
      builder: (ctx) {
        String currentTab = '0'; // '0': Belum, '1': Sudah, 'all': Semua
        String searchQuery = '';

        return StatefulBuilder(
          builder: (modalCtx, setModalState) {
            final provider = modalCtx.watch<JadwalProvider>();
            final allList = provider.kendalaList;

            final belumCount = allList.where((e) => !e.isTindakLanjut).length;
            final sudahCount = allList.where((e) => e.isTindakLanjut).length;
            final isBelumTab = currentTab == '0';

            const tabBelumColor = Color(0xFFDC1E32);
            const tabSudahColor = Color(0xFF009640);
            const tabSemuaColor = Color(0xFF285AC8);

            Color activeColor;
            if (currentTab == '0') {
              activeColor = tabBelumColor;
            } else if (currentTab == '1') {
              activeColor = tabSudahColor;
            } else {
              activeColor = tabSemuaColor;
            }

            // In-memory tab filter
            List<RealisasiModel> tabFiltered = allList;
            if (currentTab == '0') {
              tabFiltered = allList.where((e) => !e.isTindakLanjut).toList();
            } else if (currentTab == '1') {
              tabFiltered = allList.where((e) => e.isTindakLanjut).toList();
            }

            // Search filter
            final displayList = searchQuery.trim().isEmpty
                ? tabFiltered
                : tabFiltered.where((e) {
                    final q = searchQuery.trim().toLowerCase();
                    final inv = e.invNama.toLowerCase();
                    final sn = e.invSerialNumber.toLowerCase();
                    final jdw = (e.jadwal?['jdw_judul'] ?? '').toString().toLowerCase();
                    final tek = (e.teknisi?['user_nama'] ?? e.realTtdPicNama ?? '').toString().toLowerCase();
                    final ket = (e.realKeterangan ?? '').toLowerCase();
                    return inv.contains(q) || sn.contains(q) || jdw.contains(q) || tek.contains(q) || ket.contains(q);
                  }).toList();

            return Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(modalCtx).size.height * 0.9,
              ),
              decoration: const BoxDecoration(
                color: Color(0xFFF5F7FF),
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // ── Header Gradient ────────────────────────────────────
                  Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFF1A3A7C), Color(0xFF3B6FE0)],
                      ),
                      borderRadius: BorderRadius.vertical(
                          top: Radius.circular(28)),
                    ),
                    child: Column(
                      children: [
                        const SizedBox(height: 12),
                        Center(
                          child: Container(
                            width: 40,
                            height: 4,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.35),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        // Title Row
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: const Icon(
                                  Icons.report_problem_rounded,
                                  color: Colors.white,
                                  size: 22,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Kendala Maintenance',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w800,
                                        color: Colors.white,
                                        letterSpacing: -0.3,
                                      ),
                                    ),
                                    Text(
                                      userDivisi != null && userDivisi.isNotEmpty
                                          ? 'Divisi: $userDivisi'
                                          : 'Semua Divisi',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.white.withValues(alpha: 0.75),
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.15),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.close_rounded,
                                    color: Colors.white,
                                    size: 18,
                                  ),
                                ),
                                onPressed: () => Navigator.of(modalCtx).pop(),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        // ── Integrated Header Button Group ────────────────
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: Row(
                            children: [
                              _kendalaHeaderTabButton(
                                icon: Icons.warning_amber_rounded,
                                label: 'Perlu Perhatian/Rusak',
                                count: '$belumCount',
                                color: const Color(0xFFFF6B6B),
                                isActive: currentTab == '0',
                                onTap: () {
                                  if (currentTab != '0') {
                                    setModalState(() => currentTab = '0');
                                  }
                                },
                              ),
                              const SizedBox(width: 8),
                              _kendalaHeaderTabButton(
                                icon: Icons.check_circle_rounded,
                                label: 'Sudah Ditangani',
                                count: '$sudahCount',
                                color: const Color(0xFF4DD9AC),
                                isActive: currentTab == '1',
                                onTap: () {
                                  if (currentTab != '1') {
                                    setModalState(() => currentTab = '1');
                                  }
                                },
                              ),
                              const SizedBox(width: 8),
                              _kendalaHeaderTabButton(
                                icon: Icons.format_list_bulleted_rounded,
                                label: 'Semua Kendala',
                                count: '${allList.length}',
                                color: const Color(0xFF64B5F6),
                                isActive: currentTab == 'all',
                                onTap: () {
                                  if (currentTab != 'all') {
                                    setModalState(() => currentTab = 'all');
                                  }
                                },
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                        // ── Search Input ────────────────────────────────
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                          child: TextField(
                            onChanged: (val) => setModalState(() => searchQuery = val),
                            style: const TextStyle(fontSize: 13, color: Colors.white),
                            decoration: InputDecoration(
                              hintText: 'Cari nama unit, SN, teknisi, atau keterangan...',
                              hintStyle: TextStyle(
                                fontSize: 12,
                                color: Colors.white.withValues(alpha: 0.55),
                              ),
                              prefixIcon: const Icon(
                                Icons.search_rounded,
                                color: Colors.white70,
                                size: 18,
                              ),
                              suffixIcon: searchQuery.isNotEmpty
                                  ? IconButton(
                                      icon: const Icon(Icons.clear_rounded, color: Colors.white70, size: 16),
                                      onPressed: () => setModalState(() => searchQuery = ''),
                                    )
                                  : null,
                              filled: true,
                              fillColor: Colors.white.withValues(alpha: 0.14),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // ── List Area ──────────────────────────────────────────
                  Flexible(
                    child: provider.loadingKendala
                        ? const Padding(
                            padding: EdgeInsets.all(40),
                            child: Center(child: CircularProgressIndicator()),
                          )
                        : displayList.isEmpty
                            ? _kendalaEmptyState(isBelumTab)
                            : ListView.separated(
                                padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                                shrinkWrap: true,
                                itemCount: displayList.length,
                                separatorBuilder: (_, __) => const SizedBox(height: 12),
                                itemBuilder: (context, index) {
                                  final item = displayList[index];
                                  return _kendalaItemCard(
                                    context: modalCtx,
                                    item: item,
                                    activeColor: activeColor,
                                  );
                                },
                              ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  /// Integrated Tab & Stat Button di Header Kendala
  Widget _kendalaHeaderTabButton({
    required IconData icon,
    required String label,
    required String count,
    required Color color,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
            decoration: BoxDecoration(
              color: isActive
                  ? Colors.white.withValues(alpha: 0.22)
                  : Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isActive ? color : Colors.white.withValues(alpha: 0.2),
                width: isActive ? 1.8 : 1.0,
              ),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(icon, color: color, size: 16),
                    const SizedBox(width: 5),
                    Text(
                      count,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: isActive ? FontWeight.w800 : FontWeight.w500,
                    color: isActive
                        ? Colors.white
                        : Colors.white.withValues(alpha: 0.75),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }



  /// Empty state kendala
  Widget _kendalaEmptyState(bool isBelumTab) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: isBelumTab
                  ? const Color(0xFFDCFCE7)
                  : const Color(0xFFEFF6FF),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isBelumTab
                  ? Icons.check_circle_outline_rounded
                  : Icons.history_rounded,
              size: 36,
              color: isBelumTab
                  ? const Color(0xFF16A34A)
                  : const Color(0xFF285AC8),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            isBelumTab ? 'Semua Beres!' : 'Belum Ada Riwayat',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            isBelumTab
                ? 'Semua unit terkendala sudah berhasil ditindaklanjuti.'
                : 'Belum ada riwayat kendala yang ditindaklanjuti.',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  /// Card item kendala redesign
  Widget _kendalaItemCard({
    required BuildContext context,
    required RealisasiModel item,
    required Color activeColor,
  }) {
    final teknisiNama =
        item.teknisi?['user_nama'] ?? item.realTtdPicNama ?? 'Teknisi';
    final isRusak = item.isRusak;
    final isTindakLanjut = item.isTindakLanjut;
    final jadwalJudul =
        item.jadwal?['jdw_judul'] ?? 'Detail Kendala Realisasi';

    final Color severityColor = isTindakLanjut
        ? const Color(0xFF16A34A)
        : (isRusak ? const Color(0xFFDC1E32) : const Color(0xFFD97706));

    final Color severityBg = isTindakLanjut
        ? const Color(0xFFF0FDF4)
        : (isRusak ? const Color(0xFFFFF1F2) : const Color(0xFFFFFBEB));

    final String kondisiLabel =
        item.realKondisiAkhir ?? (isRusak ? 'Rusak' : 'Perlu Perhatian');

    final String unitLabel =
        item.invNama != '-' && item.invSerialNumber != '-'
            ? '${item.invNama}  ·  SN: ${item.invSerialNumber}'
            : (item.invNama != '-' ? item.invNama : item.invSerialNumber);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: severityColor.withValues(alpha: 0.22),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: severityColor.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Severity Strip ──────────────────────────────────────
              Container(
                width: 5,
                decoration: BoxDecoration(
                  color: severityColor,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(18),
                    bottomLeft: Radius.circular(18),
                  ),
                ),
              ),
              // ── Card Content ─────────────────────────────────────────
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header: icon + unit name + kondisi badge
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(9),
                            decoration: BoxDecoration(
                              color: severityBg,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              isRusak
                                  ? Icons.build_circle_rounded
                                  : Icons.warning_amber_rounded,
                              size: 18,
                              color: severityColor,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  unitLabel,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 14,
                                    color: AppColors.textPrimary,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  jadwalJudul,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: AppColors.textSecondary,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 9, vertical: 4),
                            decoration: BoxDecoration(
                              color: severityColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                  color:
                                      severityColor.withValues(alpha: 0.25)),
                            ),
                            child: Text(
                              kondisiLabel,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: severityColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      // Keterangan
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8F9FC),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.notes_rounded,
                              size: 14,
                              color: AppColors.textSecondary
                                  .withValues(alpha: 0.7),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                item.realKeterangan != null &&
                                        item.realKeterangan!.trim().isNotEmpty
                                    ? item.realKeterangan!.trim()
                                    : 'Tidak ada keterangan',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textPrimary,
                                  fontWeight: FontWeight.w500,
                                  height: 1.4,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                      // Meta info: teknisi + tanggal
                      Row(
                        children: [
                          Icon(
                            Icons.person_outline_rounded,
                            size: 13,
                            color: AppColors.textSecondary
                                .withValues(alpha: 0.7),
                          ),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              teknisiNama,
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.textSecondary,
                                fontWeight: FontWeight.w600,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Container(
                            margin:
                                const EdgeInsets.symmetric(horizontal: 8),
                            width: 3,
                            height: 3,
                            decoration: const BoxDecoration(
                              color: AppColors.textSecondary,
                              shape: BoxShape.circle,
                            ),
                          ),
                          Icon(
                            Icons.calendar_today_rounded,
                            size: 12,
                            color: AppColors.textSecondary
                                .withValues(alpha: 0.7),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            DateFormatter.toDisplay(item.realTgl),
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.textSecondary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      // Tindak lanjut info (jika ada)
                      if (isTindakLanjut) ...[
                        const SizedBox(height: 10),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [
                                Color(0xFFF0FDF4),
                                Color(0xFFDCFCE7)
                              ],
                            ),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                                color: const Color(0xFFBBF7D0)),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(
                                Icons.verified_rounded,
                                size: 15,
                                color: Color(0xFF16A34A),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  DateFormatter.formatMessageDates(
                                    item.realTindakLanjutCatatan ??
                                        'Unit telah direalisasikan kembali dengan kondisi Baik.',
                                  ),
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF15803D),
                                    height: 1.4,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 12),
                      // Action button
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () {
                            Navigator.of(context).pop();
                            RealisasiDetailSheet.show(
                              context,
                              detail: item,
                              title: jadwalJudul,
                            );
                          },
                          icon: const Icon(Icons.open_in_new_rounded,
                              size: 14),
                          label: const Text(
                            'Lihat Detail Realisasi',
                            style: TextStyle(
                                fontSize: 12, fontWeight: FontWeight.w700),
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.primary,
                            side: BorderSide(
                                color: AppColors.primary
                                    .withValues(alpha: 0.4)),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 10),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            backgroundColor:
                                AppColors.primary.withValues(alpha: 0.04),
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

  Future<void> _nav(Widget screen) async {
    if (_isLoadingData) {
      await AppNotifier.showWarning(context, 'Sedang memuat data, mohon tunggu...');
      return;
    }
    await Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
    if (mounted) {
      _loadData();
    }
  }

  Future<void> _openJadwalDetail(
    JadwalModel jadwal, {
    bool closeSheetFirst = false,
  }) async {
    if (closeSheetFirst) {
      Navigator.of(context).pop();
    }

    final auth = context.read<AuthProvider>();
    final role = auth.user?['user_jabatan']?.toString().toLowerCase();
    final isAdmin = role == 'admin' || role == 'manager';

    if (isAdmin) {
      await Navigator.pushNamed(
        context,
        AppRoutes.jadwalDetail,
        arguments: jadwal.jdwId,
      );
      if (mounted) {
        _loadData();
      }
      return;
    }

    if (jadwal.jdwStatus != 'Draft') {
      await AppNotifier.showError(
        context,
        'Jadwal harus dalam status Draft untuk direalisasi',
      );
      return;
    }

    final provider = context.read<JadwalProvider>();
    await provider.fetchJadwalDetail(
      jadwal.jdwId,
      affectGlobalLoading: false,
    );
    if (!mounted) {
      return;
    }

    final inventarisList = provider.inventarisByJenis
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();

    // Fetch realisasi for this specific jadwal WITHOUT overwriting realisasiList
    final jadwalRealisasi = await provider.fetchRealisasiByJadwal(jadwal.jdwId);
    if (!mounted) {
      return;
    }
    final selesaiInvIds = jadwalRealisasi
        .where((r) => _isSameCurrentPeriod(r, jadwal))
        .map((r) => r.realInvId)
        .toSet();
    final belumSelesaiList = inventarisList.where((inv) {
      final invIdRaw = inv['inv_id'];
      final invId = invIdRaw is int ? invIdRaw : int.tryParse('$invIdRaw');
      final isDone = inv['inv_is_done_current_period'] == true;
      return (invId == null || !selesaiInvIds.contains(invId)) && !isDone;
    }).toList();

    if (inventarisList.isEmpty) {
      await AppNotifier.showError(
        context,
        'Inventaris untuk jadwal ini belum ada',
      );
      return;
    }

    if (inventarisList.length == 1 && belumSelesaiList.isNotEmpty) {
      await _openRealisasiFromInventaris(jadwal, belumSelesaiList.first);
      return;
    }

    if (belumSelesaiList.isEmpty) {
      await AppNotifier.showWarning(
        context,
        'Semua unit pada jadwal ini sudah direalisasi dalam rentang saat ini',
      );
      return;
    }

    _showInventarisPicker(jadwal, belumSelesaiList);
  }

  void _showInventarisPicker(
    JadwalModel jadwal,
    List<Map<String, dynamic>> inventarisList,
  ) {
    showResponsiveSheet(
      context,
      maxDesktopWidth: 600,
      builder: (_) => _InventarisPickerSheet(
        jadwal: jadwal,
        inventarisList: inventarisList,
        onSelected: (inv) {
          Navigator.pop(context);
          _openRealisasiFromInventaris(jadwal, inv);
        },
      ),
    );
  }

  Future<void> _openRealisasiFromInventaris(
    JadwalModel jadwal,
    Map<String, dynamic> inv,
  ) async {
    final invJenisRaw =
        inv['inv_jenis_id'] ?? inv['inv_jenis'] ?? jadwal.jdwJenisId;
    final invJenisId = invJenisRaw is int
        ? invJenisRaw
        : int.tryParse('$invJenisRaw') ?? jadwal.jdwJenisId;
    final invIdRaw = inv['inv_id'];
    final invId = invIdRaw is int ? invIdRaw : int.tryParse('$invIdRaw');

    if (invId != null) {
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
    }

    final jenis = context.read<MasterProvider>().jenisById(invJenisId);

    await Navigator.pushNamed(
      context,
      AppRoutes.realisasiForm,
      arguments: {
        'jadwalId': jadwal.jdwId,
        'invJenisId': invJenisId,
        'invJenisNama': jenis?.jenisNama ?? 'ID $invJenisId',
        'invId': invId,
        'invNama': inv['inv_nama'],
        'invNo': inv['inv_serial_number'] ?? inv['inv_no'],
        'invMerk': inv['inv_merk'],
        'invKondisi': inv['inv_kondisi'],
        'invPicNama': inv['pic_user']?['user_nama'] ?? inv['inv_pic'],
        'invPicId': inv['pic_user']?['user_id'],
      },
    );
    if (!mounted) {
      return;
    }
    await _loadData();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final role = auth.user?['user_jabatan']?.toString().toLowerCase();
    final isDesktop = MediaQuery.of(context).size.width > 900;
    final p = context.watch<JadwalProvider>();

    final now = DateTime.now();
    final currentMonth = now.month;
    final currentYear = now.year;

    int jadwalAktif = 0;
    int pendingTasks = 0;
    int overdueTasks = 0;
    int dueTodayTasks = 0;
    int doneBulanIni = 0;
    int totalTargetBulanIni = 0;

    final isCurrentMonthSelected = _selectedTargetMonth.month == currentMonth &&
        _selectedTargetMonth.year == currentYear;

    final summary = isCurrentMonthSelected ? p.dashboardSummary['summary_cards'] : null;
    if (summary != null) {
      jadwalAktif = summary['jadwal_aktif'] ?? 0;
      pendingTasks = summary['pending_tasks'] ?? 0;
      doneBulanIni = summary['realisasi_bulan_ini'] ?? 0;
      totalTargetBulanIni = summary['total_target_bulan_ini'] ?? 0;
    } else {
      jadwalAktif = p.jadwalList.where((j) => j.jdwStatus == 'Draft').length;

      for (final j in p.jadwalList) {
        if (j.jdwStatus != 'Draft') continue;
        final diff = _getRemainingDaysDiff(j);
        if (diff < 0) {
          overdueTasks++;
        } else if (diff == 0) {
          dueTodayTasks++;
        }
      }
      pendingTasks = overdueTasks + dueTodayTasks;

      doneBulanIni = p.realisasiList.where((r) {
        return r.realBulan == _selectedTargetMonth.month && r.realTahun == _selectedTargetMonth.year;
      }).length;

      final startOfMonth = DateTime(_selectedTargetMonth.year, _selectedTargetMonth.month, 1);
      final endOfMonth = DateTime(_selectedTargetMonth.year, _selectedTargetMonth.month + 1, 0);
      final holidayDays = p.getHolidayDaysForMonth(_selectedTargetMonth);

      for (final j in p.jadwalList) {
        if (j.jdwStatus != 'Draft') continue;
        final lastRealDate = _getLastRealisasiDateForJadwal(j.jdwId, p.realisasiList);
        final count =
            _effectiveScheduleDatesInMonth(j, startOfMonth, endOfMonth, holidayDays, lastRealisasiDate: lastRealDate).length;
        final perTarget = (j.jdwTarget ?? 0) > 0 ? j.jdwTarget! : (j.jdwTotalUnit ?? 0);
        totalTargetBulanIni += count * perTarget;
      }
    }

    return Scaffold(
      backgroundColor: _pageBg,
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final maxContentWidth = AppBreakpoints.responsiveValue(
              context,
              mobile: constraints.maxWidth,
              tablet: constraints.maxWidth > 880 ? 860.0 : constraints.maxWidth,
              desktop: 1180.0,
            );
            return Center(
              child: SizedBox(
                width: maxContentWidth,
                child: CustomScrollView(
                  slivers: [
                    // 1. Modern Gradient Header Section
                    SliverToBoxAdapter(
                      child: Container(
                        padding: EdgeInsets.fromLTRB(16, MediaQuery.of(context).padding.top + 10, 16, 10),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF0A2257), Color(0xFF1847B0), Color(0xFF2B5FD4)],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomRight,
                            stops: [0.0, 0.5, 1.0],
                          ),
                          borderRadius: const BorderRadius.vertical(
                            bottom: Radius.circular(26),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF0A2257).withValues(alpha: 0.28),
                              blurRadius: 20,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.09),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.15),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: _buildHeaderUserSection(
                                  auth: auth,
                                  isLoading: _isLoadingData,
                                ),
                              ),
                              if (role == 'admin' || role == 'manager') ...[
                                _AnimatedNotificationBell(
                                  count: (p.dashboardSummary['summary_cards']?['total_kendala'] as num?)?.toInt() ?? 0,
                                  isLoading: _isLoadingData,
                                  onTap: () {
                                    final targetDiv = (role == 'manager') ? null : auth.user?['user_divisi']?.toString();
                                    p.fetchKendalaDivisi(divisi: targetDiv);
                                    _showKendalaBottomSheet(
                                      context,
                                      p.kendalaList,
                                      userDivisi: targetDiv,
                                    );
                                  },
                                ),
                                const SizedBox(width: 6),
                              ],
                              Container(
                                decoration: BoxDecoration(
                                  color: const Color(0xFFDC1E32).withValues(alpha: 0.18),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: const Color(0xFFFF6B6B).withValues(alpha: 0.35),
                                    width: 1,
                                  ),
                                ),
                                child: IconButton(
                                  icon: const Icon(
                                    Icons.logout_rounded,
                                    color: Color(0xFFFF6B6B),
                                    size: 19,
                                  ),
                                  tooltip: 'Logout',
                                  onPressed: _logout,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    // Pending Draft TTD Alert Banner (Jika Ada untuk Non-Admin)
                    if (role != 'admin' && _pendingDrafts.isNotEmpty)
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () => _nav(const RealisasiHistoryScreen(initialTab: 'Draft')),
                              borderRadius: BorderRadius.circular(14),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                decoration: BoxDecoration(
                                  color: AppColors.warning.withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: AppColors.warning.withValues(alpha: 0.4),
                                    width: 1.2,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(6),
                                      decoration: BoxDecoration(
                                        color: AppColors.warning.withValues(alpha: 0.15),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        Icons.draw_rounded,
                                        color: AppColors.warning,
                                        size: 20,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            '${_pendingDrafts.length} Realisasi Belum TTD PIC',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w800,
                                              fontSize: 13,
                                              color: AppColors.textPrimary,
                                            ),
                                          ),
                                          const SizedBox(height: 1),
                                          const Text(
                                            'Harap minta tanda tangan digital PIC lokasi.',
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w500,
                                              color: AppColors.textSecondary,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                                      decoration: BoxDecoration(
                                        color: AppColors.warning,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            'Lihat',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 12.5,
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                          SizedBox(width: 2),
                                          Icon(
                                            Icons.arrow_forward_rounded,
                                            color: Colors.white,
                                            size: 12,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),

                    // 2.5 Hero KPI Section (Target & Realisasi + Workload Status)
                    SliverToBoxAdapter(
                      child: _buildQuickStatsSection(
                        jadwalAktif: jadwalAktif,
                        pendingTasks: pendingTasks,
                        doneBulanIni: doneBulanIni,
                        totalTargetBulanIni: totalTargetBulanIni,
                        isLoading: _isLoadingData || p.loading,
                      ),
                    ),

                    if (role == 'manager')
                      SliverToBoxAdapter(
                        child: _buildManagerDivisiOverview(context, p),
                      ),

                    // 3. System Flow Section (Alur Persiapan & Data Master)
                    SliverToBoxAdapter(
                      child: _buildAdaptiveSystemFlow(isDesktop, role),
                    ),

                    // 4. Tasks Header Section
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
                        child: InkWell(
                          onTap: role == 'manager'
                              ? () {
                                  setState(() {
                                    _isManagerJadwalExpanded = !_isManagerJadwalExpanded;
                                  });
                                }
                              : null,
                          borderRadius: BorderRadius.circular(10),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    const Text(
                                      "Daftar Jadwal",
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w800,
                                        color: AppColors.textPrimary,
                                        letterSpacing: -0.2,
                                      ),
                                    ),
                                    if (role == 'manager') ...[
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: _isManagerJadwalExpanded
                                              ? AppColors.textPrimary.withValues(alpha: 0.08)
                                              : AppColors.textSecondary.withValues(alpha: 0.08),
                                          borderRadius: BorderRadius.circular(20),
                                          border: Border.all(
                                            color: _isManagerJadwalExpanded
                                                ? AppColors.textPrimary.withValues(alpha: 0.25)
                                                : AppColors.border,
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(
                                              _isManagerJadwalExpanded ? 'Tutup' : 'Buka',
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w700,
                                                color: _isManagerJadwalExpanded
                                                    ? AppColors.textPrimary
                                                    : AppColors.textSecondary,
                                              ),
                                            ),
                                            const SizedBox(width: 3),
                                            Icon(
                                              _isManagerJadwalExpanded
                                                  ? Icons.keyboard_arrow_up_rounded
                                                  : Icons.keyboard_arrow_down_rounded,
                                              size: 16,
                                              color: _isManagerJadwalExpanded
                                                  ? AppColors.textPrimary
                                                  : AppColors.textSecondary,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                if (role != 'manager' || _isManagerJadwalExpanded)
                                  TextButton(
                                    style: TextButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      minimumSize: Size.zero,
                                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                    ),
                                    onPressed: () {
                                      final sorted = [...p.jadwalList]..sort((a, b) =>
                                          _getRemainingDaysDiff(a)
                                              .compareTo(_getRemainingDaysDiff(b)));
                                      _showAllPlansBottomSheet(context, sorted, p);
                                    },
                                    child: const Text(
                                      'Lihat Semua',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF154BB8),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),

                    // 5. Plan Cards Section
                    Consumer<JadwalProvider>(
                      builder: (_, pProvider, __) {
                        // Khusus Manager: Sembunyikan list jika tertutup/collapsed!
                        if (role == 'manager' && !_isManagerJadwalExpanded) {
                          return const SliverToBoxAdapter(child: SizedBox.shrink());
                        }

                        final sorted = [...pProvider.jadwalList]..sort((a, b) =>
                            _getRemainingDaysDiff(a)
                                .compareTo(_getRemainingDaysDiff(b)));
                        final list = sorted.take(5).toList();
                        if (pProvider.loading || _isLoadingData) {
                          return SliverToBoxAdapter(
                            child: SizedBox(
                              height: 136,
                              child: AppShimmer(
                                child: ListView.separated(
                                  padding: const EdgeInsets.symmetric(horizontal: 16),
                                  scrollDirection: Axis.horizontal,
                                  itemCount: 3,
                                  physics: const NeverScrollableScrollPhysics(),
                                  separatorBuilder: (_, __) => const SizedBox(width: 10),
                                  itemBuilder: (_, i) => _buildJadwalItemSkeleton(width: 285),
                                ),
                              ),
                            ),
                          );
                        }

                        if (list.isEmpty) {
                          return SliverToBoxAdapter(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              child: Container(
                                padding: const EdgeInsets.all(14),
                                decoration: _surfaceCard(),
                                child: const Text(
                                  'Belum ada jadwal terdaftar',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ),
                          );
                        }
                        return SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Column(
                              children: [
                                for (int i = 0; i < list.length; i++) ...[
                                  _buildJadwalItem(
                                    list[i],
                                    pProvider,
                                    compact: true,
                                  ),
                                  if (i < list.length - 1)
                                    const SizedBox(height: 8),
                                ],
                              ],
                            ),
                          ),
                        );
                      },
                    ),

                    const SliverToBoxAdapter(child: SizedBox(height: 40)),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Future<void> _logout() async {
    await AppNotifier.showConfirm(
      context,
      title: 'Logout',
      message: 'Apakah anda yakin ?',
      onConfirm: () async {
        final auth = context.read<AuthProvider>();
        await auth.logout();
        if (!mounted) return;
        Navigator.pushReplacementNamed(context, AppRoutes.login);
      },
    );
  }

  int _toInt(dynamic v) => (v is num) ? v.toInt() : (int.tryParse(v?.toString() ?? '') ?? 0);

  List<Map<String, dynamic>> _getDivisiTargetRealisasiData(JadwalProvider p) {
    final Map<String, Map<String, dynamic>> divisiMap = {};

    final startOfMonth = DateTime(_selectedTargetMonth.year, _selectedTargetMonth.month, 1);
    final endOfMonth = DateTime(_selectedTargetMonth.year, _selectedTargetMonth.month + 1, 0);

    // 1. Calculate Target per Divisi from Jadwal
    for (final j in p.jadwalList) {
      final String div = j.jdwDivisi.trim().toUpperCase();
      if (div.isEmpty) continue;

      divisiMap.putIfAbsent(div, () => {
        'divisi': div,
        'target_unit': 0,
        'realisasi_unit': 0,
        'progress_percent': 0,
      });

      final holidayDays = p.getHolidayDaysForMonth(_selectedTargetMonth, divisi: div);
      final lastRealDate = _getLastRealisasiDateForJadwal(j.jdwId, p.realisasiList);
      final count = _effectiveScheduleDatesInMonth(
        j, startOfMonth, endOfMonth, holidayDays, lastRealisasiDate: lastRealDate
      ).length;
      final perTarget = (j.jdwTarget ?? 0) > 0 ? j.jdwTarget! : (j.jdwTotalUnit ?? 0);

      divisiMap[div]!['target_unit'] = (divisiMap[div]!['target_unit'] as int) + (count * perTarget);
    }

    // 2. Calculate Realisasi Selesai per Divisi
    for (final r in p.realisasiList) {
      if (r.realStatus != 'Selesai') continue;
      if (r.realBulan != _selectedTargetMonth.month || r.realTahun != _selectedTargetMonth.year) continue;

      final match = p.jadwalList.where((item) => item.jdwId == r.realJadwalId);
      final String div = (match.isNotEmpty ? match.first.jdwDivisi : '').trim().toUpperCase();
      if (div.isNotEmpty) {
        divisiMap.putIfAbsent(div, () => {
          'divisi': div,
          'target_unit': 0,
          'realisasi_unit': 0,
          'progress_percent': 0,
        });
        divisiMap[div]!['realisasi_unit'] = (divisiMap[div]!['realisasi_unit'] as int) + 1;
      }
    }

    // Fallback / merge with API monitoringDivisiList
    for (final item in p.monitoringDivisiList) {
      final div = (item['divisi'] ?? '').toString().trim().toUpperCase();
      if (div.isEmpty) continue;

      int divTarget = 0;
      int divRealisasi = 0;

      if (item['detail_jenis'] != null && item['detail_jenis'] is List) {
        for (final jen in (item['detail_jenis'] as List)) {
          if (jen['jadwal'] != null && jen['jadwal'] is List) {
            for (final jdw in (jen['jadwal'] as List)) {
              divTarget += _toInt(jdw['jdw_target']);
              divRealisasi += _toInt(jdw['jdw_realisasi']);
            }
          }
        }
      }

      divisiMap.putIfAbsent(div, () => {
        'divisi': div,
        'target_unit': 0,
        'realisasi_unit': 0,
        'progress_percent': 0,
      });

      if ((divisiMap[div]!['target_unit'] as int) == 0 && divTarget > 0) {
        divisiMap[div]!['target_unit'] = divTarget;
        divisiMap[div]!['realisasi_unit'] = divRealisasi;
      }
    }

    // 3. Compute Final Progress Percent per Divisi
    final List<Map<String, dynamic>> result = [];
    divisiMap.forEach((div, dataMap) {
      final target = dataMap['target_unit'] as int;
      final realisasi = dataMap['realisasi_unit'] as int;
      final pct = target > 0 ? ((realisasi / target) * 100).clamp(0, 100).round() : 0;
      dataMap['progress_percent'] = pct;
      result.add(dataMap);
    });

    return result;
  }

  Map<String, dynamic> _getDivisiMonthlyData(JadwalProvider p) {
    final now = _selectedTargetMonth;
    final int currentYear = now.year;

    final List<int> monthList = [];
    final List<String> monthLabels = [];
    const monthNames = ['Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun', 'Jul', 'Ags', 'Sep', 'Okt', 'Nov', 'Des'];

    for (int i = 5; i >= 0; i--) {
      final m = DateTime(currentYear, now.month - i, 1);
      monthList.add(m.month);
      monthLabels.add(monthNames[m.month - 1]);
    }

    final Set<String> divisions = {};
    for (final j in p.jadwalList) {
      final div = j.jdwDivisi.trim().toUpperCase();
      if (div.isNotEmpty) divisions.add(div);
    }
    for (final item in p.monitoringDivisiList) {
      final div = (item['divisi'] ?? '').toString().trim().toUpperCase();
      if (div.isNotEmpty) divisions.add(div);
    }

    if (divisions.isEmpty) {
      divisions.addAll(['UTILITY', 'BOILER', 'ELECTRICAL', 'MAINTENANCE', 'PRODUKSI']);
    }

    final Map<String, List<double>> seriesMap = {};

    for (final div in divisions) {
      final List<double> monthlyPctList = [];

      for (final monthNum in monthList) {
        final targetMonth = DateTime(currentYear, monthNum, 1);
        final startOfMonth = DateTime(currentYear, monthNum, 1);
        final endOfMonth = DateTime(currentYear, monthNum + 1, 0);

        int targetCount = 0;
        for (final j in p.jadwalList) {
          if (j.jdwDivisi.trim().toUpperCase() != div) continue;
          final holidayDays = p.getHolidayDaysForMonth(targetMonth, divisi: div);
          final count = _effectiveScheduleDatesInMonth(j, startOfMonth, endOfMonth, holidayDays).length;
          final perTarget = (j.jdwTarget ?? 0) > 0 ? j.jdwTarget! : (j.jdwTotalUnit ?? 0);
          targetCount += count * perTarget;
        }

        int realCount = 0;
        for (final r in p.realisasiList) {
          if (r.realStatus != 'Selesai') continue;
          if (r.realBulan == monthNum && r.realTahun == currentYear) {
            final match = p.jadwalList.where((item) => item.jdwId == r.realJadwalId);
            final String rDiv = (match.isNotEmpty ? match.first.jdwDivisi : '').trim().toUpperCase();
            if (rDiv == div) {
              realCount++;
            }
          }
        }

        final double pct = targetCount > 0
            ? ((realCount / targetCount) * 100).clamp(0.0, 100.0)
            : (realCount > 0 ? 100.0 : 0.0);

        monthlyPctList.add(pct);
      }

      seriesMap[div] = monthlyPctList;
    }

    return {
      'months': monthLabels,
      'series': seriesMap,
    };
  }

  Widget _buildChartDotIndicator(int index, String label) {
    final bool isSelected = _managerChartPageIndex == index;
    return InkWell(
      onTap: () {
        _managerChartPageController.animateToPage(
          index,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF2563EB).withValues(alpha: 0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              width: isSelected ? 14 : 6,
              height: 6,
              decoration: BoxDecoration(
                color: isSelected ? const Color(0xFF2563EB) : const Color(0xFFCBD5E1),
                borderRadius: BorderRadius.circular(99),
              ),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
                color: isSelected ? const Color(0xFF2563EB) : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Map<String, dynamic>> _getDivisiPenjadwalanData(JadwalProvider p) {
    final Map<String, Map<String, dynamic>> divisiMap = {};

    for (final item in p.monitoringDivisiList) {
      final div = (item['divisi'] ?? '').toString().trim().toUpperCase();
      if (div.isEmpty) continue;

      divisiMap[div] = {
        'divisi': div,
        'total_jenis': _toInt(item['total_jenis']),
        'jenis_dijadwalkan': _toInt(item['jenis_dijadwalkan']),
      };
    }

    if (p.jadwalList.isNotEmpty) {
      final Map<String, Set<int>> schedJenisMap = {};
      for (final j in p.jadwalList) {
        final div = j.jdwDivisi.trim().toUpperCase();
        if (div.isEmpty) continue;

        schedJenisMap.putIfAbsent(div, () => {});
        schedJenisMap[div]!.add(j.jdwJenisId);

        divisiMap.putIfAbsent(div, () => {
          'divisi': div,
          'total_jenis': 0,
          'jenis_dijadwalkan': 0,
        });
      }

      schedJenisMap.forEach((div, jenisSet) {
        if ((divisiMap[div]!['jenis_dijadwalkan'] as int) == 0) {
          divisiMap[div]!['jenis_dijadwalkan'] = jenisSet.length;
        }
        if ((divisiMap[div]!['total_jenis'] as int) == 0) {
          divisiMap[div]!['total_jenis'] = jenisSet.length;
        }
      });
    }

    return divisiMap.values.toList();
  }

  Widget _buildPenjadwalanChartCard(JadwalProvider p) {
    final data = _getDivisiPenjadwalanData(p);
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.8)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.event_note_rounded, size: 16, color: AppColors.primary),
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '1. Progres Penjadwalan Divisi',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      'Presentase Penjadwalan per Divisi',
                      style: TextStyle(fontSize: 10.5, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  'Penjadwalan',
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: AppColors.primary),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          LayoutBuilder(
            builder: (context, constraints) {
              final double totalW = constraints.maxWidth;
              const double leftPadding = 32.0;
              const double rightPadding = 20.0;
              final double chartWidth = totalW - leftPadding - rightPadding;
              final double groupWidth = data.isNotEmpty ? chartWidth / data.length : chartWidth;

              void handlePosition(Offset localPosition, {required bool isTap}) {
                final dx = localPosition.dx;
                int closestDivIdx = 0;
                double minDistance = double.infinity;

                for (int i = 0; i < data.length; i++) {
                  final centerX = leftPadding + (i + 0.5) * groupWidth;
                  final dist = (dx - centerX).abs();
                  if (dist < minDistance) {
                    minDistance = dist;
                    closestDivIdx = i;
                  }
                }

                setState(() {
                  if (isTap && _activeSchedulingPopupIndex == closestDivIdx) {
                    _activeSchedulingPopupIndex = null;
                  } else {
                    _activeSchedulingPopupIndex = closestDivIdx;
                  }
                });

                if (isTap && _activeSchedulingPopupIndex != null) {
                  _startSchedulingDismissTimer();
                }
              }

              final bool hasActiveDiv = _activeSchedulingPopupIndex != null && _activeSchedulingPopupIndex! < data.length;
              final Map<String, dynamic>? activeItem = hasActiveDiv ? data[_activeSchedulingPopupIndex!] : null;
              final double popoverLeft = hasActiveDiv
                  ? (leftPadding + (_activeSchedulingPopupIndex! + 0.5) * groupWidth - 62)
                      .clamp(4.0, totalW - 128.0)
                  : 0.0;

              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapDown: (details) => handlePosition(details.localPosition, isTap: true),
                child: MouseRegion(
                  onHover: (event) => handlePosition(event.localPosition, isTap: false),
                  onExit: (_) => setState(() => _activeSchedulingPopupIndex = null),
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      SizedBox(
                        height: 145,
                        width: double.infinity,
                        child: CustomPaint(
                          painter: _DivisiBarChartPainter(
                            data: data,
                            toInt: _toInt,
                            keyTotal: 'total_jenis',
                            keyCurrent: 'jenis_dijadwalkan',
                            activeDivIndex: _activeSchedulingPopupIndex,
                          ),
                        ),
                      ),
                      if (hasActiveDiv && activeItem != null) ...[
                        Positioned(
                          left: popoverLeft,
                          top: 0,
                          child: GestureDetector(
                            onTap: () {
                              setState(() {
                                _activeSchedulingPopupIndex = null;
                              });
                            },
                            child: Container(
                              width: 125,
                              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
                              decoration: BoxDecoration(
                                color: AppColors.white,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: AppColors.border.withValues(alpha: 0.9)),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.08),
                                    blurRadius: 12,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Builder(builder: (context) {
                                final String div = (activeItem['divisi'] ?? '-').toString();
                                final int totalVal = _toInt(activeItem['total_jenis']);
                                final int currentVal = _toInt(activeItem['jenis_dijadwalkan']);
                                final double pct = totalVal > 0 ? (currentVal / totalVal * 100) : 0.0;
                                final Color divColor = AppDivisiColors.getColor(div);

                                return Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Row(
                                          children: [
                                            Container(
                                              width: 6,
                                              height: 6,
                                              decoration: BoxDecoration(color: divColor, shape: BoxShape.circle),
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              div,
                                              style: TextStyle(
                                                fontSize: 10.5,
                                                fontWeight: FontWeight.w900,
                                                color: divColor,
                                              ),
                                            ),
                                          ],
                                        ),
                                        GestureDetector(
                                          onTap: () {
                                            setState(() {
                                              _activeSchedulingPopupIndex = null;
                                            });
                                          },
                                          child: const Padding(
                                            padding: EdgeInsets.all(2.0),
                                            child: Icon(Icons.close_rounded, size: 12, color: AppColors.textSecondary),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const Divider(color: AppColors.border, height: 6, thickness: 0.8),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        const Text('Total Jenis:', style: TextStyle(fontSize: 9, color: AppColors.textSecondary)),
                                        Text('$totalVal', style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                                      ],
                                    ),
                                    const SizedBox(height: 1.5),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        const Text('Dijadwalkan:', style: TextStyle(fontSize: 9, color: AppColors.textSecondary)),
                                        Text('$currentVal', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: divColor)),
                                      ],
                                    ),
                                    const SizedBox(height: 1.5),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        const Text('Progres:', style: TextStyle(fontSize: 9, color: AppColors.textSecondary)),
                                        Text('${pct.round()}%', style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w900, color: divColor)),
                                      ],
                                    ),
                                  ],
                                );
                              }),
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
        ],
      ),
    );
  }

  Widget _buildRealisasiChartCard(JadwalProvider p) {
    final monthlyData = _getDivisiMonthlyData(p);
    final List<String> months = (monthlyData['months'] as List).cast<String>();
    final Map<String, List<double>> series = (monthlyData['series'] as Map).cast<String, List<double>>();

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.8)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.show_chart_rounded, size: 16, color: AppColors.success),
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '2. Progres Realisasi per Divisi',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      'Presentase Realisasi per Divisi',
                      style: TextStyle(fontSize: 10.5, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  'Bulanan',
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF059669)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          LayoutBuilder(
            builder: (context, constraints) {
              final double totalW = constraints.maxWidth;
              const double leftPadding = 32.0;
              const double rightPadding = 20.0;
              final double chartWidth = totalW - leftPadding - rightPadding;
              final double stepX = months.length > 1 ? chartWidth / (months.length - 1) : chartWidth / 2;

              void handlePosition(Offset localPosition, {required bool isTap}) {
                final dx = localPosition.dx;
                int closestMonthIdx = 0;
                double minDistance = double.infinity;

                for (int i = 0; i < months.length; i++) {
                  final monthX = leftPadding + (months.length == 1 ? chartWidth / 2 : i * stepX);
                  final dist = (dx - monthX).abs();
                  if (dist < minDistance) {
                    minDistance = dist;
                    closestMonthIdx = i;
                  }
                }

                setState(() {
                  if (isTap && _activeMonthPopupIndex == closestMonthIdx) {
                    _activeMonthPopupIndex = null;
                  } else {
                    _activeMonthPopupIndex = closestMonthIdx;
                  }
                });

                if (isTap && _activeMonthPopupIndex != null) {
                  _startPopoverDismissTimer();
                }
              }

              final bool hasActiveMonth = _activeMonthPopupIndex != null && _activeMonthPopupIndex! < months.length;
              final double popoverLeft = hasActiveMonth
                  ? (leftPadding + (months.length == 1 ? chartWidth / 2 : _activeMonthPopupIndex! * stepX) - 60)
                      .clamp(4.0, totalW - 124.0)
                  : 0.0;

              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapDown: (details) => handlePosition(details.localPosition, isTap: true),
                child: MouseRegion(
                  onHover: (event) => handlePosition(event.localPosition, isTap: false),
                  onExit: (_) => setState(() => _activeMonthPopupIndex = null),
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      SizedBox(
                        height: 125,
                        width: double.infinity,
                        child: CustomPaint(
                          painter: _MultiLineDivisiChartPainter(
                            months: months,
                            series: series,
                            highlightedDivisi: _selectedDivisiHighlight,
                            activeMonthIndex: _activeMonthPopupIndex,
                          ),
                        ),
                      ),
                      // Popover Minimal Melayang Tepat di Atas Kolom Bulan Aktif
                      if (hasActiveMonth)
                        Positioned(
                          left: popoverLeft,
                          top: 0,
                          child: GestureDetector(
                            onTap: () {
                              setState(() {
                                _activeMonthPopupIndex = null;
                              });
                            },
                            child: Container(
                              width: 120,
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: AppColors.border.withValues(alpha: 0.9)),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.08),
                                    blurRadius: 12,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        months[_activeMonthPopupIndex!],
                                        style: const TextStyle(
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.w900,
                                          color: AppColors.primary,
                                        ),
                                      ),
                                      GestureDetector(
                                        onTap: () {
                                          setState(() {
                                            _activeMonthPopupIndex = null;
                                          });
                                        },
                                        child: const Padding(
                                          padding: EdgeInsets.all(2.0),
                                          child: Icon(Icons.close_rounded, size: 12, color: AppColors.textSecondary),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const Divider(color: AppColors.border, height: 6, thickness: 0.8),
                                  ...series.entries.map<Widget>((entry) {
                                    final String div = entry.key;
                                    final List<double> vals = entry.value;
                                    final double pct =
                                        (_activeMonthPopupIndex! < vals.length) ? vals[_activeMonthPopupIndex!] : 0.0;
                                    final Color divColor = AppDivisiColors.getColor(div);

                                    return Padding(
                                      padding: const EdgeInsets.only(bottom: 1.5),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Row(
                                            children: [
                                              Container(
                                                width: 5,
                                                height: 5,
                                                decoration: BoxDecoration(color: divColor, shape: BoxShape.circle),
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                div.length > 7 ? '${div.substring(0, 6)}.' : div,
                                                style: const TextStyle(
                                                  fontSize: 9.5,
                                                  color: AppColors.textSecondary,
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
                                            ],
                                          ),
                                          Text(
                                            '${pct.round()}%',
                                            style: TextStyle(
                                              fontSize: 9.5,
                                              color: divColor,
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  }),
                                ],
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 6),

          // Interactive Color Legend per Division
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: series.keys.map<Widget>((divisi) {
                final Color divColor = AppDivisiColors.getColor(divisi);
                final bool isSelected = _selectedDivisiHighlight == divisi;
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: InkWell(
                    onTap: () {
                      setState(() {
                        if (_selectedDivisiHighlight == divisi) {
                          _selectedDivisiHighlight = null;
                        } else {
                          _selectedDivisiHighlight = divisi;
                        }
                      });
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
                      decoration: BoxDecoration(
                        color: isSelected ? divColor.withValues(alpha: 0.15) : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected ? divColor : Colors.transparent,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 7,
                            height: 7,
                            decoration: BoxDecoration(color: divColor, shape: BoxShape.circle),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            divisi,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                              color: isSelected ? divColor : AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildManagerDivisiOverview(BuildContext context, JadwalProvider p) {
    final data = _getDivisiTargetRealisasiData(p);
    final isLoading = p.loading || _isLoadingData;
    final isDesktop = MediaQuery.of(context).size.width > 900;
    final cols = AppBreakpoints.gridColumns(context, mobile: 1, tablet: 2, desktop: 3);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Grafik Monitoring Divisi',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                        letterSpacing: -0.2,
                      ),
                    ),
                  ],
                ),
              ),
              TextButton.icon(
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                onPressed: () => Navigator.pushNamed(context, AppRoutes.monitoringDivisi),
                icon: const Icon(Icons.arrow_forward_rounded, size: 14, color: AppColors.primary),
                label: const Text(
                  'Monitoring Divisi',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (isLoading)
          const AppShimmer(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: AppSkeletonSquircle(width: double.infinity, height: 215, borderRadius: 16),
            ),
          )
        else if (data.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: _surfaceCard(),
              child: const Row(
                children: [
                  Icon(Icons.info_outline_rounded, color: AppColors.textSecondary, size: 20),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Belum ada data monitoring divisi. Klik "Detail Divisi" untuk memuat ulang.',
                      style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
                    ),
                  ),
                ],
              ),
            ),
          )
        else ...[
          // 1. Swipeable / Side-by-Side Chart Slider Area
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: isDesktop
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: _buildPenjadwalanChartCard(p)),
                      const SizedBox(width: 12),
                      Expanded(child: _buildRealisasiChartCard(p)),
                    ],
                  )
                : Column(
                    children: [
                      SizedBox(
                        height: 215,
                        child: PageView(
                          controller: _managerChartPageController,
                          onPageChanged: (idx) {
                            setState(() {
                              _managerChartPageIndex = idx;
                            });
                          },
                          children: [
                            _buildPenjadwalanChartCard(p),
                            _buildRealisasiChartCard(p),
                          ],
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _buildChartDotIndicator(0, '1. Penjadwalan'),
                          const SizedBox(width: 12),
                          _buildChartDotIndicator(1, '2. Realisasi'),
                        ],
                      ),
                    ],
                  ),
          ),

          const SizedBox(height: 14),

          // Sub-Header untuk Kartu Divisi + Filter Bulan
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Expanded(
                  child: Text(
                    'Target/Realisasi per Divisi',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                      letterSpacing: -0.2,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => _showMonthYearPicker(context),
                    borderRadius: BorderRadius.circular(99),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0F5FF),
                        borderRadius: BorderRadius.circular(99),
                        border: Border.all(color: AppColors.primary.withValues(alpha: 0.15)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '${_monthNames[_selectedTargetMonth.month - 1]} ${_selectedTargetMonth.year}',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primary,
                            ),
                          ),
                          const SizedBox(width: 3),
                          const Icon(
                            Icons.keyboard_arrow_down_rounded,
                            size: 14,
                            color: AppColors.primary,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // 2. Division Cards Grid
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final double cardWidth = (constraints.maxWidth - (10 * (cols - 1))) / cols;
                return Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: data.map((item) {
                    final String divisi = item['divisi'] ?? '-';
                    final int targetUnit = _toInt(item['target_unit']);
                    final int realisasiUnit = _toInt(item['realisasi_unit']);
                    final int progressPercent = _toInt(item['progress_percent']);
                    final Color divColor = AppDivisiColors.getColor(divisi);
                    final IconData divIcon = AppDivisiColors.getIcon(divisi);

                    return SizedBox(
                      width: cardWidth,
                      child: InkWell(
                        onTap: () => Navigator.pushNamed(context, AppRoutes.monitoringDivisi),
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: AppColors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: AppColors.border.withValues(alpha: 0.8)),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.02),
                                blurRadius: 10,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: divColor.withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Icon(divIcon, size: 18, color: divColor),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'DIVISI $divisi',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w800,
                                            fontSize: 12,
                                            color: AppColors.textPrimary,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          '$realisasiUnit / $targetUnit Unit Selesai',
                                          style: const TextStyle(
                                            fontSize: 11.5,
                                            color: AppColors.textSecondary,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: divColor.withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      '$progressPercent%',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w800,
                                        color: divColor,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: LinearProgressIndicator(
                                  value: targetUnit > 0 ? (realisasiUnit / targetUnit).clamp(0.0, 1.0) : 0.0,
                                  minHeight: 6,
                                  backgroundColor: divColor.withValues(alpha: 0.15),
                                  valueColor: AlwaysStoppedAnimation<Color>(divColor),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                );
              },
            ),
          ),
          const SizedBox(height: 10),
        ],
      ],
    );
  }

  // --- UI COMPONENTS ---
  Widget _buildAdaptiveSystemFlow(bool isDesktop, String? role) {
    final String r = (role ?? '').toLowerCase();
    final bool isAdmin = r == 'admin';
    final bool isManager = r == 'manager';

    List<Map<String, dynamic>> steps;
    String sectionTitle;

    if (isAdmin) {
      sectionTitle = "Alur Persiapan & Setup Data Master";
      steps = [
        {
          't': '1. Jenis',
          'd': 'Input kategori jenis inventaris',
          'i': Icons.category_rounded,
          'c': const Color(0xFF0D9488), // teal-600
          's': const JenisScreen()
        },
        {
          't': '2. Inventaris',
          'd': 'Daftarkan unit inventaris baru',
          'i': Icons.inventory_2_rounded,
          'c': const Color(0xFF7C3AED), // violet-600
          's': const InventarisScreen()
        },
        {
          't': '3. Checklist',
          'd': 'Buat template checklist item',
          'i': Icons.checklist_rounded,
          'c': const Color(0xFFDC2626), // red-600
          's': const ChecklistTemplateScreen()
        },
        {
          't': '4. Jadwal',
          'd': 'Susun jadwal pemeliharaan',
          'i': Icons.event_note_rounded,
          'c': AppColors.primary,
          's': const jadwal_screen.JadwalScreen()
        },
        {
          't': '5. Realisasi',
          'd': 'Pantau laporan yang masuk',
          'i': Icons.analytics_rounded,
          'c': const Color(0xFF059669), // emerald-600
          's': const RealisasiHistoryScreen()
        },
        {
          't': '6. User',
          'd': 'Kelola akun teknisi & admin',
          'i': Icons.people_outline_rounded,
          'c': const Color(0xFF2563EB), // blue-600
          's': const UserScreen()
        },
      ];
    } else if (isManager) {
      sectionTitle = "Alur Monitoring & Evaluasi Manager";
      steps = [
        {
          't': '1. Monitoring Divisi',
          'd': 'Pantau progress semua divisi',
          'i': Icons.monitor_heart_rounded,
          'c': const Color(0xFF2563EB),
          's': null,
          'onTap': () => Navigator.pushNamed(context, AppRoutes.monitoringDivisi),
        },
        {
          't': '2. Jadwal',
          'd': 'Kelola & pantau seluruh jadwal',
          'i': Icons.event_note_rounded,
          'c': AppColors.primary,
          's': const jadwal_screen.JadwalScreen()
        },
        {
          't': '3. Realisasi',
          'd': 'Lihat capaian & hasil pengerjaan',
          'i': Icons.analytics_rounded,
          'c': const Color(0xFF059669),
          's': const RealisasiHistoryScreen()
        },
        {
          't': '4. User',
          'd': 'Kelola akun pengguna & divisi',
          'i': Icons.people_outline_rounded,
          'c': const Color(0xFF7C3AED),
          's': const UserScreen()
        },
      ];
    } else {
      sectionTitle = "Menu Utama Teknisi";
      steps = [
        {
          't': '1. Jadwal',
          'd': 'Daftar jadwal pemeliharaan',
          'i': Icons.event_note_rounded,
          'c': AppColors.primary,
          's': const jadwal_screen.JadwalScreen()
        },
        {
          't': '2. Inventaris',
          'd': 'Daftar data unit inventaris',
          'i': Icons.inventory_2_rounded,
          'c': const Color(0xFF7C3AED),
          's': const InventarisScreen()
        },
        {
          't': '3. Realisasi',
          'd': 'Riwayat & status realisasi',
          'i': Icons.analytics_rounded,
          'c': const Color(0xFF059669),
          's': const RealisasiHistoryScreen()
        },
        {
          't': '4. User',
          'd': 'Informasi akun & pengguna',
          'i': Icons.people_outline_rounded,
          'c': const Color(0xFF2563EB),
          's': const UserScreen()
        },
      ];
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 2, 16, 0),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  sectionTitle,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                    letterSpacing: -0.2,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => _showSystemFlowInfoDialog(context),
                  borderRadius: BorderRadius.circular(99),
                  child: Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.08),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.info_outline_rounded,
                      size: 13,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x060F172A),
                  blurRadius: 16,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final int count = steps.length;
                if (count <= 4) {
                  return Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (int i = 0; i < count; i++)
                        Expanded(
                          child: _buildLargeStepCard(steps[i], i),
                        ),
                    ],
                  );
                } else {
                  return GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 16,
                      mainAxisExtent: 104,
                    ),
                    itemCount: count,
                    itemBuilder: (_, i) => _buildLargeStepCard(steps[i], i),
                  );
                }
              },
            ),
          ),
        ),
      ],
    );
  }

  void _showSystemFlowInfoDialog(BuildContext context) {
    final auth = context.read<AuthProvider>();
    final role = auth.user?['user_jabatan']?.toString().toLowerCase();

    showDialog(
      context: context,
      builder: (_) => _RoleBasedUserGuideDialog(initialRole: role),
    );
  }

  Widget _buildLargeStepCardSkeleton() {
    return AppShimmer(
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                Container(
                  width: 22,
                  height: 14,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ],
            ),
            Container(
              width: 70,
              height: 12,
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLargeStepCard(Map<String, dynamic> step, int index) {
    if (_isLoadingData) {
      return _buildLargeStepCardSkeleton();
    }

    final Color color = step['c'] as Color;
    final String title = step['t'] as String;
    final VoidCallback? customTap = step['onTap'] as VoidCallback?;
    final Widget? targetScreen = step['s'] as Widget?;

    // Extract step number "1. Jenis" → "01"
    final stepNum = title.split('.').first.trim();
    final formattedNum = stepNum.length == 1 ? '0$stepNum' : stepNum;
    final cleanTitle = title.contains('.')
        ? title.substring(title.indexOf('.') + 1).trim()
        : title;

    final softBg = color.withValues(alpha: 0.12);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _isLoadingData
            ? () {
                AppNotifier.showWarning(
                    context, 'Sedang memuat data, mohon tunggu...');
              }
            : () {
                if (customTap != null) {
                  customTap();
                } else if (targetScreen != null) {
                  _nav(targetScreen);
                }
              },
        borderRadius: BorderRadius.circular(18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // 1. Icon Box with Top-Right Floating Number Badge
            SizedBox(
              width: 60,
              height: 60,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  // Main Soft Rounded Icon Box
                  Center(
                    child: Container(
                      width: 54,
                      height: 54,
                      decoration: BoxDecoration(
                        color: softBg,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Icon(
                        step['i'] as IconData,
                        color: color,
                        size: 26,
                      ),
                    ),
                  ),

                  // Floating Number Badge (Top Right)
                  Positioned(
                    top: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(99),
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      child: Text(
                        formattedNum,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          color: color,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 6),

            // 2. Menu Title
            Text(
              cleanTitle,
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 13.5,
                color: Color(0xFF0F172A),
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 5),

            // 3. Bottom Accent Dash
            Container(
              width: 14,
              height: 3.5,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(99),
              ),
            ),
          ],
        ),
      ),
    );
  }



  void _showAllPlansBottomSheet(
    BuildContext context,
    List<JadwalModel> plans,
    JadwalProvider p,
  ) {
    showResponsiveSheet(
      context,
      maxDesktopWidth: 680,
      builder: (_) => Container(
        height: MediaQuery.of(context).size.height * 0.82,
        decoration: const BoxDecoration(
          color: _pageBg,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 10),
            Container(
              width: 42,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Semua Jadwal',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    '${plans.length} jadwal',
                    style: const TextStyle(color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
            Expanded(
              child: (p.loading || _isLoadingData)
                  ? AppShimmer(
                      child: ListView.builder(
                        padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
                        itemCount: 4,
                        itemBuilder: (_, i) => const Padding(
                          padding: EdgeInsets.only(bottom: 12),
                          child: AppSkeletonListCard(),
                        ),
                      ),
                    )
                  : plans.isEmpty
                      ? const Center(
                          child: Text(
                            'Belum ada jadwal terdaftar',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: AppColors.textSecondary),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
                          itemCount: plans.length,
                          itemBuilder: (_, i) => _buildJadwalItem(plans[i], p,
                              compact: false,
                              showDivisi: true,
                              closeSheetOnTap: true),
                        ),
            ),

          ],
        ),
      ),
    );
  }

  Widget _buildQuickStatsSkeleton() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      child: AppShimmer(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                AppSkeletonLine(width: 140, height: 16, borderRadius: 4),
                AppSkeletonSquircle(width: 70, height: 20, borderRadius: 8),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: _surfaceCard(),
                    child: const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            AppSkeletonSquircle(width: 32, height: 32, borderRadius: 10),
                            AppSkeletonLine(width: 36, height: 22, borderRadius: 4),
                          ],
                        ),
                        SizedBox(height: 12),
                        AppSkeletonLine(width: 80, height: 13, borderRadius: 4),
                        SizedBox(height: 6),
                        AppSkeletonLine(width: 100, height: 10, borderRadius: 3),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: _surfaceCard(),
                    child: const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            AppSkeletonSquircle(width: 32, height: 32, borderRadius: 10),
                            AppSkeletonLine(width: 45, height: 18, borderRadius: 4),
                          ],
                        ),
                        SizedBox(height: 12),
                        AppSkeletonLine(width: 80, height: 13, borderRadius: 4),
                        SizedBox(height: 6),
                        AppSkeletonSquircle(width: double.infinity, height: 6, borderRadius: 3),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTargetRealisasiCard({
    required int doneBulanIni,
    required int totalTargetBulanIni,
    required bool isLoading,
  }) {
    if (isLoading) {
      return _buildQuickStatsSkeleton();
    }

    final double percent = (totalTargetBulanIni > 0)
        ? (doneBulanIni / totalTargetBulanIni).clamp(0.0, 1.0)
        : 0.0;
    final int percentInt = (percent * 100).round();
    final bool isCompleted = percent >= 1.0;
    const Color primaryBlue = Color(0xFF0052FF);
    final Color themeColor = isCompleted ? AppColors.success : primaryBlue;
    final int sisaTarget = (totalTargetBulanIni > doneBulanIni) ? (totalTargetBulanIni - doneBulanIni) : 0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isCompleted ? AppColors.success.withValues(alpha: 0.4) : const Color(0xFFE2E8F0),
            width: 1,
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x060F172A),
              blurRadius: 16,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Header Row: Icon + Title & Month Dropdown Chip
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: const BoxDecoration(
                          color: Color(0xFFEEF2FF),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.track_changes_rounded,
                          size: 18,
                          color: primaryBlue,
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Flexible(
                        child: Text(
                          "Capaian Target / Realisasi",
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF0F172A),
                            letterSpacing: -0.3,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => _showMonthYearPicker(context),
                    borderRadius: BorderRadius.circular(99),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0F5FF),
                        borderRadius: BorderRadius.circular(99),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const SizedBox(width: 5),
                          Text(
                            '${_monthNames[_selectedTargetMonth.month - 1]} ${_selectedTargetMonth.year}',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: primaryBlue,
                            ),
                          ),
                          const SizedBox(width: 3),
                          const Icon(
                            Icons.keyboard_arrow_down_rounded,
                            size: 14,
                            color: primaryBlue,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),

            // Middle Layout: Donut Chart on Left + (3 Metrics Row + Progress Bar) on Right
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // 1. Donut Ring Chart on Left (Hijau)
                  SizedBox(
                    width: 95,
                    height: 95,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        SizedBox(
                          width: 95,
                          height: 95,
                          child: CircularProgressIndicator(
                            value: totalTargetBulanIni > 0 ? percent : 0.0,
                            strokeWidth: 9,
                            backgroundColor: const Color(0xFFE2E8F0),
                            color: const Color(0xFF059669),
                            strokeCap: StrokeCap.round,
                          ),
                        ),
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '$percentInt%',
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w900,
                                color: primaryBlue,
                                height: 1.0,
                              ),
                            ),
                            const SizedBox(height: 3),
                            const Text(
                              'Realisasi',
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 20),

                  // 2. Right Side: 3 Metric Blocks (Realisasi, Target, Sisa Target) + Progress Bar
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Row of 3 Metric Cards with Vertical Dividers
                      Row(
                        children: [
                          // Block 1: Realisasi
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(9),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFEEF2FF),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(
                                  Icons.trending_up_rounded,
                                  size: 18,
                                  color: primaryBlue,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Realisasi',
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w500,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.baseline,
                                    textBaseline: TextBaseline.alphabetic,
                                    children: [
                                      Text(
                                        '$doneBulanIni',
                                        style: const TextStyle(
                                          fontSize: 24,
                                          fontWeight: FontWeight.w900,
                                          color: Color(0xFF0F172A),
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      const Text(
                                        'Unit',
                                        style: TextStyle(
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.textSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ],
                          ),
                          Container(
                            width: 1,
                            height: 32,
                            margin: const EdgeInsets.symmetric(horizontal: 14),
                            color: const Color(0xFFE2E8F0),
                          ),

                          // Block 2: Target
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(9),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFDCFCE7),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(
                                  Icons.track_changes_rounded,
                                  size: 18,
                                  color: Color(0xFF059669),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Target',
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w500,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.baseline,
                                    textBaseline: TextBaseline.alphabetic,
                                    children: [
                                      Text(
                                        '$totalTargetBulanIni',
                                        style: const TextStyle(
                                          fontSize: 24,
                                          fontWeight: FontWeight.w900,
                                          color: Color(0xFF0F172A),
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      const Text(
                                        'Unit',
                                        style: TextStyle(
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.textSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ],
                          ),
                          Container(
                            width: 1,
                            height: 32,
                            margin: const EdgeInsets.symmetric(horizontal: 14),
                            color: const Color(0xFFE2E8F0),
                          ),

                          // Block 3: Sisa Target
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(9),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFEEF2FF),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(
                                  Icons.remove_rounded,
                                  size: 18,
                                  color: primaryBlue,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Sisa Target',
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w500,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.baseline,
                                    textBaseline: TextBaseline.alphabetic,
                                    children: [
                                      Text(
                                        '$sisaTarget',
                                        style: const TextStyle(
                                          fontSize: 24,
                                          fontWeight: FontWeight.w900,
                                          color: primaryBlue,
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      const Text(
                                        'Unit',
                                        style: TextStyle(
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.textSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Bottom Progress Bar & Percentage Text Row
                      SizedBox(
                        width: 380,
                        child: Row(
                          children: [
                            Expanded(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(99),
                                child: LinearProgressIndicator(
                                  value: totalTargetBulanIni > 0 ? percent : 0.0,
                                  minHeight: 8,
                                  backgroundColor: const Color(0xFFE2E8F0),
                                  valueColor: AlwaysStoppedAnimation<Color>(themeColor),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              '$percentInt%',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                                color: primaryBlue,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMonthlyComparisonChartCard({
    required int doneBulanIni,
    required int totalTargetBulanIni,
  }) {
    const Color primaryBlue = Color(0xFF0052FF);

    final p = context.read<JadwalProvider>();
    final rawList = (p.dashboardSummary['monthly_comparison'] as List<dynamic>?) ?? [];

    List<Map<String, dynamic>> months = [];
    if (rawList.isNotEmpty) {
      for (final item in rawList) {
        if (item is Map) {
          months.add({
            'm': (item['month'] ?? '').toString(),
            't': (item['target'] as num?)?.toInt() ?? 0,
            'r': (item['realisasi'] as num?)?.toInt() ?? 0,
          });
        }
      }
    }

    if (months.isEmpty) {
      months = [
        {'m': 'Mar', 't': 50, 'r': 42},
        {'m': 'Apr', 't': 60, 'r': 55},
        {'m': 'Mei', 't': 65, 'r': 62},
        {'m': 'Jun', 't': 70, 'r': 68},
        {'m': 'Jul', 't': totalTargetBulanIni > 0 ? totalTargetBulanIni : 76, 'r': doneBulanIni > 0 ? doneBulanIni : 64},
      ];
    }

    int maxVal = 10;
    for (final m in months) {
      if ((m['t'] as int) > maxVal) maxVal = m['t'] as int;
      if ((m['r'] as int) > maxVal) maxVal = m['r'] as int;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: const Color(0xFFE2E8F0),
            width: 1,
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x060F172A),
              blurRadius: 16,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Header Row: Icon + Title & Legend
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: const BoxDecoration(
                          color: Color(0xFFEEF2FF),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.bar_chart_rounded,
                          size: 18,
                          color: primaryBlue,
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Flexible(
                        child: Text(
                          "Grafik Bulanan",
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF0F172A),
                            letterSpacing: -0.3,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                Row(
                  children: [
                    // Legend Item: Realisasi (Biru)
                    Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: primaryBlue,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Text(
                          'Realisasi',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 10),
                    // Legend Item: Target (Hijau)
                    Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: Color(0xFF059669),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Text(
                          'Target',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Bar Chart Columns Row
            Expanded(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  for (final item in months) ...[
                    Builder(
                      builder: (_) {
                        final tVal = item['t'] as int;
                        final rVal = item['r'] as int;
                        final double tFactor = (tVal / maxVal).clamp(0.15, 1.0);
                        final double rFactor = (rVal / maxVal).clamp(0.15, 1.0);

                        return Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Text(
                              '$rVal/$tVal',
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            SizedBox(
                              height: 60,
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  // Bar Realisasi (Biru)
                                  FractionallySizedBox(
                                    heightFactor: rFactor,
                                    child: Container(
                                      width: 12,
                                      decoration: const BoxDecoration(
                                        color: primaryBlue,
                                        borderRadius: BorderRadius.vertical(top: Radius.circular(4)),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 3),
                                  // Bar Target (Hijau Emerald)
                                  FractionallySizedBox(
                                    heightFactor: tFactor,
                                    child: Container(
                                      width: 12,
                                      decoration: const BoxDecoration(
                                        color: Color(0xFF059669),
                                        borderRadius: BorderRadius.vertical(top: Radius.circular(4)),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              item['m'] as String,
                              style: const TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickStatsSection({
    required int jadwalAktif,
    required int pendingTasks,
    required int doneBulanIni,
    required int totalTargetBulanIni,
    bool isLoading = false,
  }) {
    if (isLoading) {
      return _buildQuickStatsSkeleton();
    }

    final isDesktop = AppBreakpoints.isDesktop(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        isDesktop
            ? SizedBox(
                height: 198,
                child: Row(
                  children: [
                    Expanded(
                      child: _buildTargetRealisasiCard(
                        doneBulanIni: doneBulanIni,
                        totalTargetBulanIni: totalTargetBulanIni,
                        isLoading: false,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildMonthlyComparisonChartCard(
                        doneBulanIni: doneBulanIni,
                        totalTargetBulanIni: totalTargetBulanIni,
                      ),
                    ),
                  ],
                ),
              )
            : SizedBox(
                height: 198,
                child: PageView(
                  controller: _heroCardPageController,
                  onPageChanged: (idx) {
                    setState(() {
                      _heroCardPageIndex = idx;
                    });
                  },
                  children: [
                    _buildTargetRealisasiCard(
                      doneBulanIni: doneBulanIni,
                      totalTargetBulanIni: totalTargetBulanIni,
                      isLoading: false,
                    ),
                    _buildMonthlyComparisonChartCard(
                      doneBulanIni: doneBulanIni,
                      totalTargetBulanIni: totalTargetBulanIni,
                    ),
                  ],
                ),
              ),
        if (!isDesktop) const SizedBox(height: 4),
        if (!isDesktop)
          // Dots Page Indicator
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                width: _heroCardPageIndex == 0 ? 18 : 6,
                height: 5,
                decoration: BoxDecoration(
                  color: _heroCardPageIndex == 0 ? const Color(0xFF0052FF) : const Color(0xFFCBD5E1),
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
              const SizedBox(width: 5),
              AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                width: _heroCardPageIndex == 1 ? 18 : 6,
                height: 5,
                decoration: BoxDecoration(
                  color: _heroCardPageIndex == 1 ? const Color(0xFF0052FF) : const Color(0xFFCBD5E1),
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ],
          ),
      ],
    );
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
            inv['inv_is_done_current_period'] != true &&
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

  Widget _buildJadwalItem(
    JadwalModel item,
    JadwalProvider p, {
    double? width,
    bool compact = false,
    bool showDivisi = false,
    bool closeSheetOnTap = false,
  }) {
    final rem = _getRemainingDays(item);
    final divisiColor = AppDivisiColors.getColor(item.jdwDivisi);
    final icon = AppDivisiColors.getIcon(item.jdwDivisi);
    Color badgeBg;
    Color badgeText;
    if (rem.contains('Terlewat')) {
      badgeBg = const Color(0xFFFEE2E2);
      badgeText = const Color(0xFFDC2626);
    } else if (rem == 'Hari ini!') {
      badgeBg = const Color(0xFFFEF3C7);
      badgeText = const Color(0xFFD97706);
    } else {
      badgeBg = const Color(0xFFE0F2FE);
      badgeText = const Color(0xFF0284C7);
    }

    // Hitung progres realisasi untuk periode berjalan
    final realisasiFromList = p.realisasiList.where((r) {
      return r.realJadwalId == item.jdwId &&
          r.realStatus == 'Selesai' &&
          _isSameCurrentPeriod(r, item);
    }).length;

    final realisasiSelesai = realisasiFromList > 0
        ? realisasiFromList
        : (item.jdwSelesaiUnit ?? 0);

    final totalTarget = (item.jdwTarget ?? 0) > 0 ? item.jdwTarget! : (item.jdwTotalUnit ?? 0);
    final double progressPercent = totalTarget > 0 ? (realisasiSelesai / totalTarget).clamp(0.0, 1.0) : 0.0;
    final int percentInt = (progressPercent * 100).round();

    final bool isCompleted = progressPercent >= 1.0;
    const Color statusGreen = Color(0xFF059669);
    const Color statusBlue = Color(0xFF0052FF);
    final Color progressColor = isCompleted ? statusGreen : statusBlue;

    return Container(
      width: width,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.8)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x04000000),
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => _openJadwalDetail(item, closeSheetFirst: closeSheetOnTap),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header: Divisi Badge (Left) + Urgency Pill & Chevron (Right)
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                          color: divisiColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(icon, size: 12, color: divisiColor),
                            const SizedBox(width: 4),
                            Text(
                              'Divisi ${item.jdwDivisi}',
                              style: TextStyle(
                                fontSize: 10.5,
                                color: divisiColor,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                        decoration: BoxDecoration(
                          color: badgeBg,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          rem == 'Hari ini!' ? 'Hari Ini' : (rem.contains('Terlewat') ? 'Terlewat' : rem),
                          style: TextStyle(
                            color: badgeText,
                            fontWeight: FontWeight.w800,
                            fontSize: 10,
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.chevron_right_rounded, size: 16, color: AppColors.textSecondary),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Title
                  Text(
                    item.jdwJudul,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 13.5,
                      height: 1.25,
                      color: AppColors.textPrimary,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),

                  // Compact Progress Row
                  Row(
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: progressPercent,
                            minHeight: 5,
                            backgroundColor: const Color(0xFFF1F5F9),
                            valueColor: AlwaysStoppedAnimation<Color>(progressColor),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        '$realisasiSelesai/$totalTarget Unit ($percentInt%)',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: progressColor,
                        ),
                      ),
                    ],
                  ),
                  () {
                    final auth = context.read<AuthProvider>();
                    final userRole = (auth.user?['user_jabatan'] ?? '').toString().trim().toLowerCase();
                    final isUser = userRole == 'user' || userRole == 'teknisi' || userRole == 'it_support';

                    if (isUser) {
                      return Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: _actionBtn(
                          Icons.playlist_add_check_circle_outlined,
                          'Lakukan Realisasi',
                          AppColors.primary,
                          () => _handleRealisasiTap(item),
                        ),
                      );
                    }
                    return const SizedBox.shrink();
                  }(),
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

  Widget _buildJadwalItemSkeleton({required double width}) {
    return Container(
      width: width,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              AppSkeletonSquircle(width: 32, height: 32, borderRadius: 9),
              SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AppSkeletonLine(width: 110, height: 12, borderRadius: 3),
                    SizedBox(height: 5),
                    Row(
                      children: [
                        AppSkeletonSquircle(width: 50, height: 14, borderRadius: 5),
                        SizedBox(width: 6),
                        AppSkeletonLine(width: 36, height: 9, borderRadius: 3),
                      ],
                    ),
                  ],
                ),
              ),
              AppSkeletonSquircle(width: 55, height: 18, borderRadius: 12),
            ],
          ),
          Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  AppSkeletonLine(width: 65, height: 10, borderRadius: 3),
                  AppSkeletonLine(width: 80, height: 10, borderRadius: 3),
                ],
              ),
              SizedBox(height: 4),
              AppSkeletonLine(width: double.infinity, height: 5, borderRadius: 3),
            ],
          ),
        ],
      ),
    );
  }

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 11) return 'Selamat Pagi';
    if (hour < 15) return 'Selamat Siang';
    if (hour < 18) return 'Selamat Sore';
    return 'Selamat Malam';
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
    
    // 1. Jika belum mulai (tanggal mulai di masa depan), hitung selisih ke tanggal mulai
    final startDate = _parseDateOnly(j.jdwTglMulai);
    if (startDate != null && startDate.isAfter(today)) {
      return startDate.difference(today).inDays;
    }

    // 2. Jika jadwal Mingguan/Bulanan dan belum terpenuhi, berarti harus dikerjakan periode ini
    if (!j.jdwPeriodFulfilled &&
        (j.jdwFrekuensi == 'Mingguan' || j.jdwFrekuensi == 'Bulanan')) {
      return 0;
    }

    // 3. Gunakan sisa hari dari backend jika ada
    if (j.jdwDaysRemaining != null) {
      return j.jdwDaysRemaining!;
    }

    // 4. Fallback jika tidak ada daysRemaining dari backend
    final fallbackDate = _parseDateOnly(j.effectiveNextDueDateStr ?? j.jdwTglMulai);
    if (fallbackDate == null) {
      return 0;
    }

    return fallbackDate.difference(today).inDays;
  }

  DateTime? _parseDateOnly(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    final dt = DateTime.tryParse(value);
    if (dt == null) return null;
    return DateTime(dt.year, dt.month, dt.day);
  }
}

class _InventarisPickerSheet extends StatefulWidget {
  final JadwalModel jadwal;
  final List<Map<String, dynamic>> inventarisList;
  final Function(Map<String, dynamic>) onSelected;

  const _InventarisPickerSheet({
    required this.jadwal,
    required this.inventarisList,
    required this.onSelected,
  });

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

    final no = (inv['inv_no'] ?? '').toString().toLowerCase();
    final sn = (inv['inv_serial_number'] ?? '').toString().toLowerCase();
    final nama = (inv['inv_nama'] ?? '').toString().toLowerCase();
    final pic = _resolvePicName(inv).toLowerCase();

    return no.contains(normalizedQuery) ||
        sn.contains(normalizedQuery) ||
        nama.contains(normalizedQuery) ||
        pic.contains(normalizedQuery);
  }

  @override
  Widget build(BuildContext context) {
    final filteredInventaris = widget.inventarisList
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
            color: _DashboardScreenState._pageBg,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
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
                      color: AppColors.border,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Pilih Unit untuk Realisasi',
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
                      hintText: 'Cari serial number, nama, atau PIC',
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.search, color: AppColors.primary),
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
                    child: filteredInventaris.isEmpty
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
                            itemCount: filteredInventaris.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 8),
                            itemBuilder: (_, i) {
                              final inv = filteredInventaris[i];
                              final merk = (inv['inv_merk'] ?? '-')
                                  .toString()
                                  .toUpperCase();
                              final pabrik = inv['inv_pabrik_kode'] ?? '-';
                              final sn = inv['inv_serial_number'] ?? '-';
                              final picName = _resolvePicName(inv);
                              return Card(
                                margin: EdgeInsets.zero,
                                child: ListTile(
                                  contentPadding:
                                      const EdgeInsets.symmetric(
                                          horizontal: 14, vertical: 10),
                                  leading: CircleAvatar(
                                    radius: 20,
                                    backgroundColor: AppColors.primary
                                        .withValues(alpha: 0.12),
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
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
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
                                        Text('$merk · $sn',
                                            style: const TextStyle(
                                                fontSize: 12,
                                                color:
                                                    AppColors.textSecondary,
                                                fontWeight:
                                                    FontWeight.w600)),
                                        const SizedBox(height: 2),
                                        Row(
                                          children: [
                                            const Icon(
                                              Icons.person_outline,
                                              size: 14,
                                              color:
                                                  AppColors.textSecondary,
                                            ),
                                            const SizedBox(width: 4),
                                            Expanded(
                                              child: Text(
                                                'PIC: $picName',
                                                style: const TextStyle(
                                                  fontSize: 12,
                                                  color: AppColors
                                                      .textSecondary,
                                                ),
                                                overflow:
                                                    TextOverflow.ellipsis,
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
                                              color:
                                                  AppColors.textSecondary,
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              pabrik,
                                              style: const TextStyle(
                                                fontSize: 12,
                                                color:
                                                    AppColors.textSecondary,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        Container(
                                          padding:
                                              const EdgeInsets.symmetric(
                                                  horizontal: 8,
                                                  vertical: 3),
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

class _RoleBasedUserGuideDialog extends StatefulWidget {
  final String? initialRole;

  const _RoleBasedUserGuideDialog({this.initialRole});

  @override
  State<_RoleBasedUserGuideDialog> createState() =>
      __RoleBasedUserGuideDialogState();
}

class __RoleBasedUserGuideDialogState
    extends State<_RoleBasedUserGuideDialog> {
  late int _selectedTab;

  @override
  void initState() {
    super.initState();
    final role = (widget.initialRole ?? '').toLowerCase();
    if (role == 'admin') {
      _selectedTab = 1;
    } else if (role == 'manager') {
      _selectedTab = 2;
    } else {
      _selectedTab = 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.xl)),
      elevation: 0,
      child: Container(
        width: 440,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.auto_awesome_rounded,
                    color: AppColors.primary,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Panduan Penggunaan PlanKP',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Petunjuk langkah kerja berdasarkan peran',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Tab Buttons
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: AppColors.surfaceAlt,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  _buildRoleTab(0, 'Teknisi', Icons.engineering_rounded),
                  _buildRoleTab(1, 'Admin', Icons.admin_panel_settings_rounded),
                  _buildRoleTab(2, 'Manager', Icons.shield_rounded),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Tab Contents
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    if (_selectedTab == 0) ...[
                      _buildTimelineItem(
                        '01',
                        'Jadwal',
                        'Buat jadwal maintenance untuk setiap jenis inventaris dan tetapkan teknisi yang bertugas.',
                        AppColors.primary,
                      ),
                      _buildTimelineItem(
                        '02',
                        'Inventaris',
                        'Daftarkan unit inventaris beserta detail nya.',
                        Colors.purple,
                      ),
                      _buildTimelineItem(
                        '03',
                        'Checklist',
                        'Tentukan daftar poin pemeriksaan pada setiap jenis inventaris.',
                        Colors.redAccent,
                      ),
                      _buildTimelineItem(
                        '04',
                        'Realisasi',
                        'Pantau laporan yang masuk dan histori realisasi maintenance.',
                        const Color(0xFF059669),
                        isLast: true,
                      ),
                    ] else if (_selectedTab == 1) ...[
                      _buildTimelineItem(
                        '01',
                        'Jenis',
                        'Daftarkan kategori/jenis inventaris (Laptop, Mobil, Mesin Jahit, dll).',
                        Colors.teal,
                      ),
                      _buildTimelineItem(
                        '02',
                        'Inventaris',
                        'Daftarkan unit inventaris beserta detail nya.',
                        Colors.purple,
                      ),
                      _buildTimelineItem(
                        '03',
                        'Checklist',
                        'Tentukan daftar poin pemeriksaan pada setiap jenis inventaris.',
                        Colors.redAccent,
                      ),
                      _buildTimelineItem(
                        '04',
                        'Jadwal',
                        'Buat jadwal maintenance untuk setiap jenis inventaris dan tetapkan teknisi yang bertugas.',
                        AppColors.primary,
                      ),
                      _buildTimelineItem(
                        '05',
                        'Realisasi',
                        'Pantau laporan yang masuk dan histori realisasi maintenance.',
                        const Color(0xFF059669),
                      ),
                      _buildTimelineItem(
                        '06',
                        'User',
                        'Kelola akun user/teknisi divisi masing-masing.',
                        const Color(0xFF2563EB),
                        isLast: true,
                      ),
                    ] else ...[
                      _buildTimelineItem(
                        '01',
                        'Monitoring Divisi',
                        'Lihat persentase capaian target realisasi semua divisi.',
                        const Color(0xFF2563EB),
                      ),
                      _buildTimelineItem(
                        '02',
                        'Jadwal',
                        'Buat jadwal maintenance untuk setiap jenis inventaris dan tetapkan teknisi yang bertugas.',
                        AppColors.primary,
                      ),
                      _buildTimelineItem(
                        '03',
                        'Realisasi',
                        'Pantau laporan yang masuk dan histori realisasi maintenance.',
                        const Color(0xFF059669),
                      ),
                      _buildTimelineItem(
                        '04',
                        'User',
                        'Kelola akun user/teknisi divisi masing-masing.',
                        const Color(0xFF2563EB),
                        isLast: true,
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 18),

            // Button
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.pop(context),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Text(
                  'Saya Mengerti',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRoleTab(int index, String label, IconData icon) {
    final bool isSelected = _selectedTab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedTab = index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: AppColors.textPrimary.withValues(alpha: 0.05),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 15,
                color: isSelected ? AppColors.primary : AppColors.textSecondary,
              ),
              const SizedBox(width: 5),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                  color:
                      isSelected ? AppColors.primary : AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTimelineItem(
    String number,
    String title,
    String description,
    Color color, {
    bool isLast = false,
  }) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: color.withValues(alpha: 0.5),
                    width: 1.5,
                  ),
                ),
                child: Center(
                  child: Text(
                    number,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      color: color,
                    ),
                  ),
                ),
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 2,
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    color: AppColors.border,
                  ),
                ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textSecondary,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AnimatedNotificationBell extends StatefulWidget {
  final int count;
  final bool isLoading;
  final VoidCallback onTap;

  const _AnimatedNotificationBell({
    required this.count,
    this.isLoading = false,
    required this.onTap,
  });

  @override
  State<_AnimatedNotificationBell> createState() =>
      _AnimatedNotificationBellState();
}

class _AnimatedNotificationBellState extends State<_AnimatedNotificationBell>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    _animation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: -0.25), weight: 1),
      TweenSequenceItem(tween: Tween(begin: -0.25, end: 0.25), weight: 2),
      TweenSequenceItem(tween: Tween(begin: -0.25, end: 0.2), weight: 2),
      TweenSequenceItem(tween: Tween(begin: -0.2, end: 0.2), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 0.2, end: 0.0), weight: 1),
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 0.0), weight: 4),
    ]).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

    if (widget.count > 0 && !widget.isLoading) {
      _controller.repeat();
    }
  }

  @override
  void didUpdateWidget(covariant _AnimatedNotificationBell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.count > 0 && !widget.isLoading && !_controller.isAnimating) {
      _controller.repeat();
    } else if ((widget.count == 0 || widget.isLoading) && _controller.isAnimating) {
      _controller.stop();
      _controller.reset();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool showActive = widget.count > 0 && !widget.isLoading;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        shape: BoxShape.circle,
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          IconButton(
            icon: RepaintBoundary(
              child: AnimatedBuilder(
                animation: _animation,
                builder: (context, child) {
                  return Transform.rotate(
                    angle: _animation.value,
                    child: child,
                  );
                },
                child: Icon(
                  showActive
                      ? Icons.notifications_active_rounded
                      : Icons.notifications_rounded,
                  color: showActive
                      ? Colors.amberAccent
                      : Colors.white.withValues(alpha: widget.isLoading ? 0.7 : 1.0),
                  size: 22,
                ),
              ),
            ),
            tooltip: 'Notifikasi Kendala Maintenance',
            onPressed: widget.onTap,
          ),
          if (widget.isLoading)
            Positioned(
              right: 6,
              top: 6,
              child: AppShimmer(
                child: Container(
                  width: 14,
                  height: 14,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            )
          else if (widget.count > 0)
            Positioned(
              right: 6,
              top: 6,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(
                  color: Colors.redAccent,
                  shape: BoxShape.circle,
                ),
                constraints: const BoxConstraints(
                  minWidth: 18,
                  minHeight: 18,
                ),
                child: Center(
                  child: Text(
                    '${widget.count > 99 ? '99+' : widget.count}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),

        ],
      ),
    );
  }
}

class _MultiLineDivisiChartPainter extends CustomPainter {
  final List<String> months;
  final Map<String, List<double>> series;
  final String? highlightedDivisi;
  final int? activeMonthIndex;

  _MultiLineDivisiChartPainter({
    required this.months,
    required this.series,
    this.highlightedDivisi,
    this.activeMonthIndex,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (months.isEmpty || series.isEmpty) return;

    const double leftPadding = 32.0;
    const double rightPadding = 20.0;
    const double topPadding = 22.0;
    const double bottomPadding = 26.0;

    final double chartWidth = size.width - leftPadding - rightPadding;
    final double chartHeight = size.height - topPadding - bottomPadding;

    final Paint gridPaint = Paint()
      ..color = AppColors.border
      ..strokeWidth = 1.0;

    final TextPainter textPainter = TextPainter(textDirection: TextDirection.ltr);

    // 1. Draw horizontal grid lines (0%, 50%, 100%)
    final gridSteps = [0, 50, 100];
    for (final step in gridSteps) {
      final double y = topPadding + chartHeight * (1.0 - step / 100.0);
      canvas.drawLine(Offset(leftPadding, y), Offset(size.width - rightPadding, y), gridPaint);

      textPainter.text = TextSpan(
        text: '$step%',
        style: const TextStyle(fontSize: 10, color: AppColors.textSecondary, fontWeight: FontWeight.w600),
      );
      textPainter.layout();
      textPainter.paint(canvas, Offset(2, y - textPainter.height / 2));
    }

    final double stepX = months.length > 1 ? chartWidth / (months.length - 1) : chartWidth / 2;

    // 1.5 Draw vertical active month guide line
    if (activeMonthIndex != null && activeMonthIndex! >= 0 && activeMonthIndex! < months.length) {
      final double activeX = leftPadding + (months.length == 1 ? chartWidth / 2 : activeMonthIndex! * stepX);
      final Paint activeLinePaint = Paint()
        ..color = AppColors.primary.withValues(alpha: 0.4)
        ..strokeWidth = 1.5;

      canvas.drawLine(
        Offset(activeX, topPadding - 4),
        Offset(activeX, topPadding + chartHeight + 18),
        activeLinePaint,
      );
    }

    // 2. Draw lines for each division with distinct colors
    series.forEach((divisi, values) {
      if (values.isEmpty) return;

      final Color divColor = AppDivisiColors.getColor(divisi);
      final bool isHighlighted = highlightedDivisi == null || highlightedDivisi == divisi;
      final double strokeWidth = isHighlighted ? 2.8 : 1.2;
      final double opacity = isHighlighted ? 1.0 : 0.25;

      final points = <Offset>[];
      for (int i = 0; i < values.length; i++) {
        final double pct = values[i].clamp(0.0, 100.0);
        final double x = leftPadding + (months.length == 1 ? chartWidth / 2 : i * stepX);
        final double y = topPadding + chartHeight * (1.0 - pct / 100.0);
        points.add(Offset(x, y));
      }

      if (points.isEmpty) return;

      // Cubic bezier path for each division line
      final Path path = Path();
      path.moveTo(points.first.dx, points.first.dy);

      for (int i = 0; i < points.length - 1; i++) {
        final p1 = points[i];
        final p2 = points[i + 1];
        final controlPoint1 = Offset(p1.dx + (p2.dx - p1.dx) / 2, p1.dy);
        final controlPoint2 = Offset(p1.dx + (p2.dx - p1.dx) / 2, p2.dy);
        path.cubicTo(controlPoint1.dx, controlPoint1.dy, controlPoint2.dx, controlPoint2.dy, p2.dx, p2.dy);
      }

      final Paint linePaint = Paint()
        ..color = divColor.withValues(alpha: opacity)
        ..strokeWidth = strokeWidth
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;

      canvas.drawPath(path, linePaint);

      // Data dots on nodes with percentage labels
      for (int i = 0; i < points.length; i++) {
        final pt = points[i];
        final int pctVal = values[i].round();
        final bool isActiveMonth = activeMonthIndex == i;

        if (isActiveMonth && isHighlighted) {
          final Paint activeGlow = Paint()..color = divColor.withValues(alpha: 0.35);
          canvas.drawCircle(pt, 7.0, activeGlow);
        }

        final Paint dotPaint = Paint()..color = divColor.withValues(alpha: opacity);
        canvas.drawCircle(pt, isHighlighted ? (isActiveMonth ? 4.5 : 3.8) : 2.5, dotPaint);

        if (isHighlighted) {
          final Paint whiteDot = Paint()..color = AppColors.white;
          canvas.drawCircle(pt, 1.8, whiteDot);

          // Render Percentage Detail Label ($pctVal%)
          textPainter.text = TextSpan(
            text: '$pctVal%',
            style: TextStyle(
              fontSize: isActiveMonth ? 9.5 : 8.5,
              fontWeight: FontWeight.w800,
              color: divColor,
              shadows: const [
                Shadow(color: AppColors.white, blurRadius: 2),
                Shadow(color: AppColors.white, blurRadius: 4),
              ],
            ),
          );
          textPainter.layout();
          // Offset above the dot
          final double textY = (pt.dy - (isActiveMonth ? 14 : 12)).clamp(topPadding - 4, size.height);
          textPainter.paint(canvas, Offset(pt.dx - textPainter.width / 2, textY));
        }
      }
    });

    // 3. Draw X Axis month labels
    for (int i = 0; i < months.length; i++) {
      final double x = leftPadding + (months.length == 1 ? chartWidth / 2 : i * stepX);
      final bool isActive = activeMonthIndex == i;

      textPainter.text = TextSpan(
        text: months[i],
        style: TextStyle(
          fontSize: isActive ? 11 : 10,
          fontWeight: isActive ? FontWeight.w900 : FontWeight.w700,
          color: isActive ? AppColors.primary : AppColors.textSecondary,
        ),
      );
      textPainter.layout();
      textPainter.paint(canvas, Offset(x - textPainter.width / 2, topPadding + chartHeight + 6));
    }
  }

  @override
  bool shouldRepaint(covariant _MultiLineDivisiChartPainter oldDelegate) => true;
}

class _DivisiBarChartPainter extends CustomPainter {
  final List<Map<String, dynamic>> data;
  final int Function(dynamic) toInt;
  final String keyTotal;
  final String keyCurrent;
  final int? activeDivIndex;

  _DivisiBarChartPainter({
    required this.data,
    required this.toInt,
    this.keyTotal = 'target_unit',
    this.keyCurrent = 'realisasi_unit',
    this.activeDivIndex,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;

    const double leftPadding = 32.0;
    const double rightPadding = 20.0;
    const double topPadding = 22.0;
    const double bottomPadding = 28.0;

    final double chartWidth = size.width - leftPadding - rightPadding;
    final double chartHeight = size.height - topPadding - bottomPadding;

    int maxVal = 1;
    for (final item in data) {
      final total = toInt(item[keyTotal]);
      final current = toInt(item[keyCurrent]);
      if (total > maxVal) maxVal = total;
      if (current > maxVal) maxVal = current;
    }
    maxVal = (maxVal * 1.2).ceil();
    if (maxVal < 4) maxVal = 4;

    final Paint gridPaint = Paint()
      ..color = AppColors.border
      ..strokeWidth = 1.0;

    final TextPainter textPainter = TextPainter(textDirection: TextDirection.ltr);

    // Draw horizontal grid lines (0, maxVal / 2, maxVal)
    final gridSteps = [0, maxVal ~/ 2, maxVal];
    for (final step in gridSteps) {
      final double y = topPadding + chartHeight * (1.0 - step / maxVal);
      canvas.drawLine(Offset(leftPadding, y), Offset(size.width - rightPadding, y), gridPaint);

      textPainter.text = TextSpan(
        text: '$step',
        style: const TextStyle(fontSize: 10, color: AppColors.textSecondary, fontWeight: FontWeight.w600),
      );
      textPainter.layout();
      textPainter.paint(canvas, Offset(8, y - textPainter.height / 2));
    }

    final double groupWidth = chartWidth / data.length;
    final double barWidth = (groupWidth * 0.28).clamp(6.0, 18.0);

    for (int i = 0; i < data.length; i++) {
      final item = data[i];
      final String divisi = item['divisi'] ?? '-';
      final int totalVal = toInt(item[keyTotal]);
      final int currentVal = toInt(item[keyCurrent]);
      final bool isActive = activeDivIndex == i;

      final double centerX = leftPadding + (i + 0.5) * groupWidth;
      final Color divColor = AppDivisiColors.getColor(divisi);

      // Vertical Active Guide Column Highlight
      if (isActive) {
        final Paint activeBgPaint = Paint()
          ..color = AppColors.primary.withValues(alpha: 0.1)
          ..style = PaintingStyle.fill;
        final RRect activeBgRRect = RRect.fromRectAndRadius(
          Rect.fromLTWH(centerX - groupWidth * 0.42, topPadding - 4, groupWidth * 0.84, chartHeight + 8),
          const Radius.circular(8),
        );
        canvas.drawRRect(activeBgRRect, activeBgPaint);
      }

      // Bar 1: Total (Grey)
      final double height1 = chartHeight * (totalVal / maxVal);
      final double rect1Left = centerX - barWidth - 2;
      final double rect1Top = topPadding + chartHeight - height1;
      final RRect rrect1 = RRect.fromRectAndRadius(
        Rect.fromLTWH(rect1Left, rect1Top, barWidth, height1),
        const Radius.circular(4),
      );
      canvas.drawRRect(rrect1, Paint()..color = isActive ? AppColors.textSecondary : AppColors.border);

      // Value label 1 (Total)
      textPainter.text = TextSpan(
        text: '$totalVal',
        style: TextStyle(
          fontSize: isActive ? 10 : 9,
          fontWeight: isActive ? FontWeight.w900 : FontWeight.w700,
          color: isActive ? AppColors.textPrimary : AppColors.textSecondary,
        ),
      );
      textPainter.layout();
      textPainter.paint(canvas, Offset(rect1Left + barWidth / 2 - textPainter.width / 2, rect1Top - 12));

      // Bar 2: Current (Division Color)
      final double height2 = chartHeight * (currentVal / maxVal);
      final double rect2Left = centerX + 2;
      final double rect2Top = topPadding + chartHeight - height2;
      final RRect rrect2 = RRect.fromRectAndRadius(
        Rect.fromLTWH(rect2Left, rect2Top, barWidth, height2),
        const Radius.circular(4),
      );
      canvas.drawRRect(rrect2, Paint()..color = divColor);

      // Value label 2 (Current)
      textPainter.text = TextSpan(
        text: '$currentVal',
        style: TextStyle(
          fontSize: isActive ? 10 : 9,
          fontWeight: FontWeight.w900,
          color: divColor,
        ),
      );
      textPainter.layout();
      textPainter.paint(canvas, Offset(rect2Left + barWidth / 2 - textPainter.width / 2, rect2Top - 12));

      // X Axis Label
      final labelText = divisi.length > 8 ? '${divisi.substring(0, 7)}..' : divisi;
      textPainter.text = TextSpan(
        text: labelText,
        style: TextStyle(
          fontSize: isActive ? 10.5 : 9.5,
          fontWeight: isActive ? FontWeight.w900 : FontWeight.w700,
          color: isActive ? AppColors.primary : AppColors.textSecondary,
        ),
      );
      textPainter.layout();
      textPainter.paint(canvas, Offset(centerX - textPainter.width / 2, topPadding + chartHeight + 6));
    }
  }

  @override
  bool shouldRepaint(covariant _DivisiBarChartPainter oldDelegate) => true;
}





