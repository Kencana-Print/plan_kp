class JadwalModel {
  final int jdwId;
  final String jdwJudul;
  final int jdwJenisId;
  final String? jdwInvJenis;
  final String jdwDivisi;
  final String jdwFrekuensi;
  final int jdwGapHari;
  final String jdwTglMulai;
  final String? jdwTglSelesai;
  final int? jdwWeekNumber;
  final int? jdwBulan;
  final int jdwTahun;
  final int? jdwAssignedTo;
  final List<String> jdwPabrikList;
  final String jdwStatus;
  final int? jdwTarget;
  final int? jdwTotalUnit;
  final int? jdwSelesaiUnit;
  final bool jdwPeriodFulfilled;
  final String? jdwCurrentPeriodStart;
  final String? jdwNextDueDate;
  final int? jdwDaysRemaining;
  final String? jdwNotes;
  final Map<String, dynamic>? assignedUser;
  final Map<String, dynamic>? dibuatUser;

  JadwalModel({
    required this.jdwId,
    required this.jdwJudul,
    required this.jdwJenisId,
    this.jdwInvJenis,
    required this.jdwDivisi,
    required this.jdwFrekuensi,
    this.jdwGapHari = 0,
    required this.jdwTglMulai,
    this.jdwTglSelesai,
    this.jdwWeekNumber,
    this.jdwBulan,
    required this.jdwTahun,
    this.jdwAssignedTo,
    this.jdwPabrikList = const [],
    required this.jdwStatus,
    this.jdwTarget,
    this.jdwTotalUnit,
    this.jdwSelesaiUnit,
    this.jdwPeriodFulfilled = false,
    this.jdwCurrentPeriodStart,
    this.jdwNextDueDate,
    this.jdwDaysRemaining,
    this.jdwNotes,
    this.assignedUser,
    this.dibuatUser,
  });

  factory JadwalModel.fromJson(Map<String, dynamic> j) => JadwalModel(
        jdwId: j['jdw_id'],
        jdwJudul: j['jdw_judul'] ?? '',
        jdwJenisId: j['jdw_jenis_id'] ?? j['jdw_inv_jenis'] ?? 0,
        jdwInvJenis: j['jdw_inv_jenis'],
        jdwDivisi: j['jdw_divisi'] ?? '',
        jdwFrekuensi: j['jdw_frekuensi'] ?? '',
        jdwGapHari: j['jdw_gap_hari'] is int
            ? j['jdw_gap_hari']
            : int.tryParse('${j['jdw_gap_hari'] ?? ''}') ?? 0,
        jdwTglMulai: j['jdw_tgl_mulai'] ?? '',
        jdwTglSelesai: j['jdw_tgl_selesai'],
        jdwWeekNumber: j['jdw_week_number'],
        jdwBulan: j['jdw_bulan'],
        jdwTahun: j['jdw_tahun'] ?? DateTime.now().year,
        jdwAssignedTo: j['jdw_assigned_to'],
        jdwPabrikList:
            _parsePabrikList(j['jdw_pabrik_list'] ?? j['jdw_pabrik_kode']),
        jdwStatus: j['jdw_status'] ?? 'Draft',
        jdwTarget: j['jdw_target'] is int
            ? j['jdw_target']
            : int.tryParse('${j['jdw_target'] ?? ''}'),
        jdwTotalUnit: j['jdw_total_unit'] is int
            ? j['jdw_total_unit']
            : int.tryParse('${j['jdw_total_unit'] ?? ''}'),
        jdwSelesaiUnit: j['jdw_selesai_unit'] is int
            ? j['jdw_selesai_unit']
            : int.tryParse('${j['jdw_selesai_unit'] ?? ''}'),
        jdwPeriodFulfilled: j['jdw_period_fulfilled'] == true,
        jdwCurrentPeriodStart: j['jdw_current_period_start'],
        jdwNextDueDate: j['jdw_next_due_date'],
        jdwDaysRemaining: j['jdw_days_remaining'] is int
            ? j['jdw_days_remaining']
            : int.tryParse('${j['jdw_days_remaining'] ?? ''}'),
        jdwNotes: j['jdw_notes'],
        assignedUser:
            (j['assigned_user'] ?? j['jdw_assigned_to_plan_user']) != null
                ? Map<String, dynamic>.from(
                    j['assigned_user'] ?? j['jdw_assigned_to_plan_user'])
                : null,
        dibuatUser: (j['dibuat_user'] ?? j['jdw_dibuat_oleh_plan_user']) != null
            ? Map<String, dynamic>.from(
                j['dibuat_user'] ?? j['jdw_dibuat_oleh_plan_user'])
            : null,
      );

  String get assignedNama => assignedUser?['user_nama'] ?? '-';

  DateTime? get calculatedNextDueDate {
    final start = DateTime.tryParse(jdwTglMulai);
    if (start == null) return null;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final startDateOnly = DateTime(start.year, start.month, start.day);

    if (jdwFrekuensi == 'Harian') {
      if (startDateOnly.isAfter(today)) return startDateOnly;
      if (jdwPeriodFulfilled) {
        return today.add(const Duration(days: 1));
      }
      return today;
    } else if (jdwFrekuensi == 'Mingguan') {
      final intervalDays = jdwGapHari > 0 ? jdwGapHari : 7;
      if (startDateOnly.isAfter(today)) return startDateOnly;

      var currentPeriodStart = startDateOnly;
      while (currentPeriodStart.add(Duration(days: intervalDays)).isBefore(today) ||
          currentPeriodStart.add(Duration(days: intervalDays)).isAtSameMomentAs(today)) {
        currentPeriodStart = currentPeriodStart.add(Duration(days: intervalDays));
      }

      if (jdwPeriodFulfilled) {
        return currentPeriodStart.add(Duration(days: intervalDays));
      }
      return currentPeriodStart.isBefore(today) ? today : currentPeriodStart;
    } else if (jdwFrekuensi == 'Bulanan') {
      final intervalDays = jdwGapHari > 0 ? jdwGapHari : 30;
      if (startDateOnly.isAfter(today)) return startDateOnly;

      if (jdwGapHari > 0) {
        var currentPeriodStart = startDateOnly;
        while (currentPeriodStart.add(Duration(days: intervalDays)).isBefore(today) ||
            currentPeriodStart.add(Duration(days: intervalDays)).isAtSameMomentAs(today)) {
          currentPeriodStart = currentPeriodStart.add(Duration(days: intervalDays));
        }
        if (jdwPeriodFulfilled) {
          return currentPeriodStart.add(Duration(days: intervalDays));
        }
        return currentPeriodStart.isBefore(today) ? today : currentPeriodStart;
      } else {
        var currentPeriodStart = startDateOnly;
        while (true) {
          final nextMonth = DateTime(currentPeriodStart.year, currentPeriodStart.month + 1, currentPeriodStart.day);
          if (nextMonth.isAfter(today)) break;
          currentPeriodStart = nextMonth;
        }
        if (jdwPeriodFulfilled) {
          return DateTime(currentPeriodStart.year, currentPeriodStart.month + 1, currentPeriodStart.day);
        }
        return currentPeriodStart.isBefore(today) ? today : currentPeriodStart;
      }
    }

    return startDateOnly;
  }

  String? get effectiveNextDueDateStr {
    final calc = calculatedNextDueDate;
    if (calc != null) {
      final calcStr = '${calc.year}-${calc.month.toString().padLeft(2, '0')}-${calc.day.toString().padLeft(2, '0')}';
      if (jdwNextDueDate != null && jdwNextDueDate!.trim().isNotEmpty) {
        final backendParsed = DateTime.tryParse(jdwNextDueDate!);
        if (backendParsed != null) {
          final backendDateOnly = DateTime(backendParsed.year, backendParsed.month, backendParsed.day);
          final now = DateTime.now();
          final today = DateTime(now.year, now.month, now.day);
          if (!jdwPeriodFulfilled || backendDateOnly.isAfter(today)) {
            return jdwNextDueDate;
          }
        }
      }
      return calcStr;
    }
    return jdwNextDueDate ?? jdwTglMulai;
  }

  static List<String> _parsePabrikList(dynamic value) {
    if (value == null) return const [];
    if (value is List) {
      return value
          .map(
              (e) => e is Map<String, dynamic> ? e['kode'] ?? e['pab_kode'] : e)
          .map((e) => e?.toString().trim() ?? '')
          .where((e) => e.isNotEmpty)
          .toSet()
          .toList();
    }
    return value
        .toString()
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toSet()
        .toList();
  }
}
