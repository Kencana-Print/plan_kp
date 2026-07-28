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

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  static const _pageBg = AppColors.surface;
  bool _hasCheckedPendingTtd = false;
  bool _isLoadingData = true;

  List<RealisasiModel> _pendingDrafts = [];

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

  BoxDecoration _surfaceCard({Color? borderColor}) => BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(
          color: borderColor ?? AppColors.border,
          width: 1,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 10,
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
        Container(
          padding: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.8),
              width: 2,
            ),
          ),
          child: CircleAvatar(
            radius: 22,
            backgroundColor: AppColors.primarySoft,
            child: Text(
              _userInitial(user),
              style: const TextStyle(
                color: AppColors.primary,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _greeting(),
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.85),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.3,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                _userName(user).toUpperCase(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.3,
                ),
              ),
              Text(
                DateFormatter.toDisplayDateTime(DateTime.now()),
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.85),
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.3,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: Text(
                      role == 'manager'
                          ? 'MANAGER'
                          : '${user['user_divisi'] ?? 'Teknisi'}'.toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.4,
                      ),
                    ),
                  ),
                  if (role == 'manager') ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.amber.withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(99),
                        border: Border.all(
                          color: Colors.amber.withValues(alpha: 0.5),
                        ),
                      ),
                      child: const Text(
                        'Semua Divisi',
                        style: TextStyle(
                          color: Colors.amber,
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.4,
                        ),
                      ),
                    ),
                  ],
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
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
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

  void _tabToHistory(int index) {
    if (index == 1) {
      _nav(const RealisasiHistoryScreen());
    } else {
      _nav(const jadwal_screen.JadwalScreen(initialIndex: 0));
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
      return invId == null || !selesaiInvIds.contains(invId);
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
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
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

    final summary = p.dashboardSummary['summary_cards'];
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
        return r.realBulan == currentMonth && r.realTahun == currentYear;
      }).length;

      final startOfMonth = DateTime(now.year, now.month, 1);
      final endOfMonth = DateTime(now.year, now.month + 1, 0);
      final holidayDays = p.getHolidayDaysForMonth(now);

      for (final j in p.jadwalList) {
        if (j.jdwStatus != 'Draft') continue;
        final count =
            _effectiveScheduleDatesInMonth(j, startOfMonth, endOfMonth, holidayDays).length;
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
            final maxContentWidth =
                constraints.maxWidth > 1220 ? 1180.0 : constraints.maxWidth;
            return Center(
              child: SizedBox(
                width: maxContentWidth,
                child: CustomScrollView(
                  slivers: [
                    // 1. Header Section
                    SliverToBoxAdapter(
                      child: Container(
                        padding: const EdgeInsets.fromLTRB(20, 52, 20, 24),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [AppColors.primaryDark, AppColors.primary],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: const BorderRadius.vertical(
                            bottom: Radius.circular(28),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primaryDark.withValues(alpha: 0.2),
                              blurRadius: 16,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.2),
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
                                const SizedBox(width: 8),
                              ],
                              Container(
                                decoration: BoxDecoration(
                                  color: const Color(0xFFDC1E32).withValues(alpha: 0.22),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: const Color(0xFFFF6B6B).withValues(alpha: 0.45),
                                    width: 1,
                                  ),
                                ),
                                child: IconButton(
                                  icon: const Icon(
                                    Icons.logout_rounded,
                                    color: Color(0xFFFF6B6B),
                                    size: 20,
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
                          padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () => _nav(const RealisasiHistoryScreen(initialTab: 'Draft')),
                              borderRadius: BorderRadius.circular(16),
                              child: Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: AppColors.warning.withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: AppColors.warning.withValues(alpha: 0.4),
                                    width: 1.5,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: AppColors.warning.withValues(alpha: 0.15),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        Icons.draw_rounded,
                                        color: AppColors.warning,
                                        size: 22,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
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
                                          const SizedBox(height: 2),
                                          const Text(
                                            'Harap minta tanda tangan digital PIC lokasi untuk menyelesaikan laporan draft.',
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w500,
                                              color: AppColors.textSecondary,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: AppColors.warning,
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: const Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            'Lihat',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 11,
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                          SizedBox(width: 2),
                                          Icon(
                                            Icons.arrow_forward_rounded,
                                            color: Colors.white,
                                            size: 13,
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

                    // 2. Quick Actions Section
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
                        child: Row(
                          children: [
                            if (role == 'manager') ...[
                              _buildQuickAction(
                                icon: Icons.monitor_heart_rounded,
                                label: "Monitoring Divisi",
                                color: Colors.blue.shade700,
                                onTap: () => Navigator.pushNamed(context, AppRoutes.monitoringDivisi),
                              ),
                            ] else ...[
                              _buildQuickAction(
                                icon: Icons.event_note,
                                label: "Jadwal",
                                color: AppColors.primary,
                                onTap: () => _tabToHistory(0),
                              ),
                              const SizedBox(width: 15),
                              _buildQuickAction(
                                icon: Icons.analytics,
                                label: "Realisasi",
                                color: Colors.green.shade700,
                                onTap: () => _tabToHistory(1),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),

                    // 2.5 Quick Stats Section
                    SliverToBoxAdapter(
                      child: _buildQuickStatsSection(
                        jadwalAktif: jadwalAktif,
                        pendingTasks: pendingTasks,
                        doneBulanIni: doneBulanIni,
                        totalTargetBulanIni: totalTargetBulanIni,
                        isLoading: _isLoadingData || p.loading,
                      ),
                    ),

                    // 3. System Flow Section (Alur Persiapan & Kerja)
                    SliverToBoxAdapter(
                      child: _buildAdaptiveSystemFlow(isDesktop, role),
                    ),

                    // 4. Tasks Header Section
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              "Daftar Jadwal",
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                            TextButton(
                              onPressed: () {
                                final sorted = [...p.jadwalList]..sort((a, b) =>
                                    _getRemainingDaysDiff(a)
                                        .compareTo(_getRemainingDaysDiff(b)));
                                _showAllPlansBottomSheet(context, sorted, p);
                              },
                              child: const Text('Lihat Semua'),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // 5. Plan Cards Section
                    Consumer<JadwalProvider>(
                      builder: (_, pProvider, __) {
                        final sorted = [...pProvider.jadwalList]..sort((a, b) =>
                            _getRemainingDaysDiff(a)
                                .compareTo(_getRemainingDaysDiff(b)));
                        final list = sorted.take(5).toList();
                        if (pProvider.loading || _isLoadingData) {
                          return SliverToBoxAdapter(
                            child: SizedBox(
                              height: 165,
                              child: AppShimmer(
                                child: ListView.separated(
                                  padding: const EdgeInsets.symmetric(horizontal: 20),
                                  scrollDirection: Axis.horizontal,
                                  itemCount: 3,
                                  physics: const NeverScrollableScrollPhysics(),
                                  separatorBuilder: (_, __) => const SizedBox(width: 12),
                                  itemBuilder: (_, i) => _buildJadwalItemSkeleton(width: 285),
                                ),
                              ),
                            ),
                          );
                        }

                        if (list.isEmpty) {
                          return SliverToBoxAdapter(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 20),
                              child: Container(
                                padding: const EdgeInsets.all(16),
                                decoration: _surfaceCard(),
                                child: const Text(
                                  'Belum ada jadwal terdaftar',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ),
                            ),
                          );
                        }
                        return SliverToBoxAdapter(
                          child: SizedBox(
                            height: 165,
                            child: Stack(
                              children: [
                                ListView.separated(
                                  padding: const EdgeInsets.symmetric(horizontal: 20),
                                  scrollDirection: Axis.horizontal,
                                  itemCount: list.length,
                                  separatorBuilder: (_, __) => const SizedBox(width: 12),
                                  itemBuilder: (_, i) => _buildJadwalItem(
                                    list[i],
                                    pProvider,
                                    width: 285,
                                    compact: true,
                                  ),
                                ),
                                if (list.length > 1)
                                  Positioned(
                                    right: 0,
                                    top: 0,
                                    bottom: 0,
                                    width: 32,
                                    child: IgnorePointer(
                                      child: DecoratedBox(
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            begin: Alignment.centerLeft,
                                            end: Alignment.centerRight,
                                            colors: [
                                              _pageBg.withValues(alpha: 0.0),
                                              _pageBg.withValues(alpha: 0.8),
                                            ],
                                          ),
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

                    const SliverToBoxAdapter(child: SizedBox(height: 100)),
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
          'd': 'Input Jenis Inv',
          'i': Icons.category_rounded,
          'c': Colors.teal,
          's': const JenisScreen()
        },
        {
          't': '2. Inventaris',
          'd': 'Input Data Unit',
          'i': Icons.inventory_2_rounded,
          'c': Colors.purple,
          's': const InventarisScreen()
        },
        {
          't': '3. Checklist',
          'd': 'Template Checklist',
          'i': Icons.checklist_rounded,
          'c': Colors.redAccent,
          's': const ChecklistTemplateScreen()
        },
        {
          't': '4. Jadwal',
          'd': 'Buat Jadwal',
          'i': Icons.event_note_rounded,
          'c': AppColors.primary,
          's': const jadwal_screen.JadwalScreen()
        },
        {
          't': '5. Realisasi',
          'd': 'Cek Realisasi',
          'i': Icons.analytics_rounded,
          'c': Colors.green.shade700,
          's': const RealisasiHistoryScreen()
        },
        {
          't': '6. User',
          'd': 'Kelola Akun User',
          'i': Icons.people_outline_rounded,
          'c': Colors.green,
          's': const UserScreen()
        },
      ];
    } else if (isManager) {
      sectionTitle = "Alur Monitoring & Evaluasi Manager";
      steps = [
        {
          't': '1. Monitoring',
          'd': 'Pantau All Divisi',
          'i': Icons.monitor_heart_rounded,
          'c': Colors.blue.shade700,
          's': null,
          'onTap': () => Navigator.pushNamed(context, AppRoutes.monitoringDivisi),
        },
        {
          't': '2. Realisasi',
          'd': 'Cek Capaian Unit',
          'i': Icons.analytics_rounded,
          'c': Colors.green.shade700,
          's': const RealisasiHistoryScreen()
        },
        {
          't': '3. Panduan',
          'd': 'Petunjuk Manager',
          'i': Icons.auto_awesome_rounded,
          'c': Colors.amber.shade800,
          's': null,
          'onTap': () => _showSystemFlowInfoDialog(context),
        },
      ];
    } else {
      sectionTitle = "Alur Kerja Realisasi Harian";
      steps = [
        {
          't': '1. Cek Jadwal',
          'd': 'Jadwal Hari Ini',
          'i': Icons.event_note_rounded,
          'c': AppColors.primary,
          's': null,
          'onTap': () => _tabToHistory(0),
        },
        {
          't': '2. Pilih Unit',
          'd': 'Unit Inventaris',
          'i': Icons.touch_app_rounded,
          'c': Colors.purple,
          's': null,
          'onTap': () {
            final p = context.read<JadwalProvider>();
            final sorted = [...p.jadwalList]..sort((a, b) =>
                _getRemainingDaysDiff(a).compareTo(_getRemainingDaysDiff(b)));
            _showAllPlansBottomSheet(context, sorted, p);
          },
        },
        {
          't': '3. Checklist',
          'd': 'Foto & Pemeriksaan',
          'i': Icons.checklist_rtl_rounded,
          'c': Colors.teal,
          's': null,
          'onTap': () => _showSystemFlowInfoDialog(context),
        },
        {
          't': '4. TTD PIC',
          'd': 'Selesai & Sign',
          'i': Icons.draw_rounded,
          'c': Colors.orange.shade700,
          's': const RealisasiHistoryScreen(initialTab: 'Draft'),
        },
      ];
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Text(
                    sectionTitle,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(width: 6),
                  InkWell(
                    onTap: () => _showSystemFlowInfoDialog(context),
                    borderRadius: BorderRadius.circular(999),
                    child: Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.info_outline,
                        size: 14,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        if (isDesktop)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: steps.length > 3 ? 3 : steps.length,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                mainAxisExtent: 105,
              ),
              itemCount: steps.length,
              itemBuilder: (_, i) =>
                  _buildStepCard(steps[i], isFullWidth: true),
            ),
          )
        else
          SizedBox(
            height: 110,
            child: Stack(
              children: [
                ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  scrollDirection: Axis.horizontal,
                  itemCount: steps.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 12),
                  itemBuilder: (_, i) => _buildStepCard(steps[i]),
                ),
                if (steps.length > 2)
                  Positioned(
                    right: 0,
                    top: 0,
                    bottom: 0,
                    width: 32,
                    child: IgnorePointer(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                            colors: [
                              _pageBg.withValues(alpha: 0.0),
                              _pageBg.withValues(alpha: 0.8),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
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

  Widget _buildStepCardSkeleton({bool isFullWidth = false}) {
    return AppShimmer(
      child: Container(
        width: isFullWidth ? null : 155,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: AppColors.border, width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                Container(
                  width: 20,
                  height: 12,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ],
            ),
            const Spacer(),
            Container(
              width: 80,
              height: 14,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(height: 6),
            Container(
              width: 110,
              height: 10,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStepCard(Map<String, dynamic> step, {bool isFullWidth = false}) {
    if (_isLoadingData) {
      return _buildStepCardSkeleton(isFullWidth: isFullWidth);
    }
    final Color color = step['c'] as Color;
    final String title = step['t'] as String;
    final String desc = step['d'] as String;
    final VoidCallback? customTap = step['onTap'] as VoidCallback?;
    final Widget? targetScreen = step['s'] as Widget?;

    // Extract step number from e.g. "1. Jenis" -> "01"
    final stepNum = title.split('.').first.trim();
    final formattedNum = stepNum.length == 1 ? '0$stepNum' : stepNum;
    final cleanTitle = title.substring(title.indexOf('.') + 1).trim();

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _isLoadingData
            ? () {
                AppNotifier.showWarning(context, 'Sedang memuat data, mohon tunggu...');
              }
            : () {
                if (customTap != null) {
                  customTap();
                } else if (targetScreen != null) {
                  _nav(targetScreen);
                }
              },
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: Container(
          width: isFullWidth ? null : 155,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: AppColors.border, width: 1),
            boxShadow: const [
              BoxShadow(
                color: Color(0x0A000000),
                blurRadius: 8,
                offset: Offset(0, 2),
              )
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(step['i'] as IconData, color: color, size: 18),
                  ),
                  Text(
                    formattedNum,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      color: color.withValues(alpha: 0.5),
                    ),
                  ),
                ],
              ),
              const Spacer(),
              Text(
                cleanTitle,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                  color: AppColors.textPrimary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                desc,
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textSecondary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuickAction({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    if (_isLoadingData) {
      return Expanded(
        child: AppShimmer(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border: Border.all(color: AppColors.border, width: 1),
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 70,
                        height: 14,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        width: 90,
                        height: 10,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(4),
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
    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _isLoadingData
              ? () {
                  AppNotifier.showWarning(context, 'Sedang memuat data, mohon tunggu...');
                }
              : onTap,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border: Border.all(color: AppColors.border, width: 1),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x0A000000),
                  blurRadius: 10,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(icon, color: color, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          label,
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 13,
                  color: AppColors.textSecondary.withValues(alpha: 0.6),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showAllPlansBottomSheet(
    BuildContext context,
    List<JadwalModel> plans,
    JadwalProvider p,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
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
    final double percent = (totalTargetBulanIni > 0)
        ? (doneBulanIni / totalTargetBulanIni).clamp(0.0, 1.0)
        : 0.0;


    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "Ringkasan Kinerja",
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                  letterSpacing: -0.2,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'Bulan Ini',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              // Kartu 1: Total Jadwal Aktif + berapa yang pending
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: _surfaceCard(
                    borderColor: pendingTasks > 0
                        ? AppColors.warning.withValues(alpha: 0.4)
                        : null,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(7),
                            decoration: BoxDecoration(
                              color: (pendingTasks > 0 ? AppColors.warning : AppColors.primary)
                                  .withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              Icons.pending_actions_rounded,
                              color: pendingTasks > 0
                                  ? AppColors.warning
                                  : AppColors.primary,
                              size: 18,
                            ),
                          ),
                          Text(
                            "$jadwalAktif",
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        "Jadwal Aktif",
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        pendingTasks > 0
                            ? "$pendingTasks perlu dikerjakan"
                            : "Semua jadwal selesai",
                        style: TextStyle(
                          fontSize: 10,
                          color: pendingTasks > 0
                              ? AppColors.warning
                              : AppColors.textSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Kartu 2: Realisasi Selesai vs Target Bulan Ini
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: _surfaceCard(
                    borderColor: totalTargetBulanIni > 0 &&
                            doneBulanIni >= totalTargetBulanIni
                        ? AppColors.success.withValues(alpha: 0.4)
                        : null,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(7),
                            decoration: BoxDecoration(
                              color: AppColors.success.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.task_alt_rounded,
                              color: AppColors.success,
                              size: 18,
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                totalTargetBulanIni > 0
                                    ? "$doneBulanIni / $totalTargetBulanIni"
                                    : "$doneBulanIni",
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              if (totalTargetBulanIni > 0)
                                Text(
                                  '${(percent * 100).round()}%',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: percent >= 1.0
                                        ? AppColors.success
                                        : AppColors.warning,
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(99),
                        child: LinearProgressIndicator(
                          value: totalTargetBulanIni > 0 ? percent : 1.0,
                          minHeight: 5,
                          backgroundColor: AppColors.border,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            percent >= 1.0
                                ? AppColors.success
                                : AppColors.accent,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        "Realisasi Selesai",
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
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



  Widget _buildJadwalItem(
    JadwalModel item,
    JadwalProvider p, {
    double? width,
    bool compact = false,
    bool showDivisi = false,
    bool closeSheetOnTap = false,
  }) {
    final rem = _getRemainingDays(item);
    final divisiColor = _colorForDivisi(item.jdwDivisi);
    final icon = _iconForDivisi(item.jdwDivisi);
    Color badgeBg;
    Color badgeText;
    if (rem.contains('Terlewat')) {
      badgeBg = AppColors.danger.withValues(alpha: 0.1);
      badgeText = AppColors.danger;
    } else if (rem == 'Hari ini!') {
      badgeBg = AppColors.warning.withValues(alpha: 0.12);
      badgeText = AppColors.warning;
    } else {
      badgeBg = AppColors.success.withValues(alpha: 0.1);
      badgeText = AppColors.success;
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

    return Container(
      width: width,
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () =>
                _openJadwalDetail(item, closeSheetFirst: closeSheetOnTap),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(9),
                        decoration: BoxDecoration(
                          color: divisiColor.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          icon,
                          size: 20,
                          color: divisiColor,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.jdwJudul,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 13.5,
                                height: 1.3,
                                color: AppColors.textPrimary,
                              ),
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 3),
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: divisiColor.withValues(alpha: 0.08),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    'Divisi ${item.jdwDivisi}',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: divisiColor,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'Target: $totalTarget unit',
                                  style: const TextStyle(
                                    fontSize: 10,
                                    color: AppColors.textSecondary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: badgeBg,
                          borderRadius: BorderRadius.circular(99),
                        ),
                        child: Text(
                          rem,
                          style: TextStyle(
                            color: badgeText,
                            fontWeight: FontWeight.w800,
                            fontSize: 10,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Progres Unit',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        '$realisasiSelesai / $totalTarget Selesai (${(progressPercent * 100).round()}%)',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(99),
                    child: LinearProgressIndicator(
                      value: progressPercent,
                      minHeight: 6,
                      backgroundColor: AppColors.surfaceAlt,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        progressPercent == 1.0
                            ? AppColors.success
                            : (progressPercent > 0.5
                                ? AppColors.accent
                                : AppColors.warning),
                      ),
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

  Widget _buildJadwalItemSkeleton({required double width}) {
    return Container(
      width: width,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.6)),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppSkeletonSquircle(width: 42, height: 42, borderRadius: 14),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AppSkeletonLine(width: 120, height: 14, borderRadius: 4),
                    SizedBox(height: 8),
                    Row(
                      children: [
                        AppSkeletonSquircle(width: 60, height: 16, borderRadius: 6),
                        SizedBox(width: 6),
                        AppSkeletonLine(width: 40, height: 10, borderRadius: 3),
                      ],
                    ),
                  ],
                ),
              ),
              AppSkeletonSquircle(width: 60, height: 20, borderRadius: 12),
            ],
          ),
          Spacer(),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              AppSkeletonLine(width: 70, height: 12, borderRadius: 3),
              AppSkeletonLine(width: 90, height: 12, borderRadius: 3),
            ],
          ),
          SizedBox(height: 8),
          AppSkeletonLine(width: double.infinity, height: 8, borderRadius: 4),
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
    final fallbackDate = _parseDateOnly(j.jdwNextDueDate ?? j.jdwTglMulai);
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

  IconData _iconForDivisi(String? divisiRaw) {
    final divisi = (divisiRaw ?? '').toLowerCase();
    if (divisi == 'it') {
      return Icons.support_agent_rounded;
    }
    if (divisi == 'ga') {
      return Icons.precision_manufacturing_outlined;
    }
    if (divisi == 'driver') {
      return Icons.local_shipping_outlined;
    }
    return Icons.event_note;
  }

  Color _colorForDivisi(String? divisiRaw) {
    final divisi = (divisiRaw ?? '').toLowerCase();
    if (divisi == 'it') {
      return Colors.indigo;
    }
    if (divisi == 'ga') {
      return Colors.orange.shade700;
    }
    if (divisi == 'driver') {
      return Colors.teal.shade700;
    }
    return AppColors.primary;
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
                        'Cek Daftar Jadwal',
                        'Periksa jadwal aktif yang jatuh tempo hari ini atau yang terlewat (overdue).',
                        AppColors.primary,
                      ),
                      _buildTimelineItem(
                        '02',
                        'Pilih Unit Inventaris',
                        'Pilih unit fisik inventaris (serial number/nama unit) yang akan dipelihara.',
                        Colors.purple,
                      ),
                      _buildTimelineItem(
                        '03',
                        'Isi Checklist & Upload Foto',
                        'Jawab poin pemeriksaan kondisi unit & unggah foto fisik sebagai bukti pengerjaan.',
                        Colors.teal,
                      ),
                      _buildTimelineItem(
                        '04',
                        'Tanda Tangan Digital PIC',
                        'Minta tanda tangan digital PIC/penanggung jawab lokasi untuk menyelesaikan draft.',
                        Colors.orange.shade700,
                        isLast: true,
                      ),
                    ] else if (_selectedTab == 1) ...[
                      _buildTimelineItem(
                        '01',
                        'Input Jenis Inventaris',
                        'Daftarkan kategori/jenis inventaris (Laptop, AC, Mobil Operasional, dsb).',
                        Colors.teal,
                      ),
                      _buildTimelineItem(
                        '02',
                        'Input Data Inventaris Unit',
                        'Daftarkan data fisik unit beserta serial number, merk, lokasi & PIC unit.',
                        Colors.purple,
                      ),
                      _buildTimelineItem(
                        '03',
                        'Buat Template Checklist',
                        'Tentukan daftar pertanyaan/poin pemeriksaan wajib untuk tiap jenis inventaris.',
                        Colors.redAccent,
                      ),
                      _buildTimelineItem(
                        '04',
                        'Buat Jadwal Maintenance',
                        'Atur frekuensi perawatan (Harian/Mingguan/Bulanan) dan penanggung jawab.',
                        AppColors.primary,
                      ),
                      _buildTimelineItem(
                        '05',
                        'Kelola User & Divisi',
                        'Daftarkan akun teknisi dan sesuaikan hak akses divisi masing-masing.',
                        Colors.green.shade700,
                        isLast: true,
                      ),
                    ] else ...[
                      _buildTimelineItem(
                        '01',
                        'Pantau Dashboard Monitoring',
                        'Buka menu Monitoring Divisi untuk melihat persentase target realisasi semua divisi.',
                        Colors.blue.shade700,
                      ),
                      _buildTimelineItem(
                        '02',
                        'Cek Histori Realisasi & Kendala',
                        'Tinjau laporan realisasi yang telah selesai atau yang mengalami keterlambatan/kendala.',
                        Colors.green.shade700,
                      ),
                      _buildTimelineItem(
                        '03',
                        'Evaluasi Performa Maintenance',
                        'Rekap pencapaian bulanan untuk memastikan keandalan seluruh aset operasional.',
                        Colors.amber.shade800,
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
            icon: AnimatedBuilder(
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





