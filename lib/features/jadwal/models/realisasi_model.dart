import 'checklist_hasil_model.dart';

class RealisasiModel {
  final int realId;
  final int realJadwalId;
  final int realInvId;
  final int realTeknisiId;
  final String realTgl;
  final String? realJamMulai;
  final String? realJamSelesai;
  final int realWeekNumber;
  final int realBulan;
  final int realTahun;
  final String? realKondisiAkhir;
  final String? realKeterangan;
  final String realStatus;
  final String? realTtdPicNama;
  final String? realTtdData;
  final String? realTtdAt;
  final int? realApprovedBy;
  final String? realApprovedAt;
  final String? realFoto;
  final int realIsTindakLanjut;
  final String? realTindakLanjutCatatan;
  final Map<String, dynamic>? jadwal;
  final Map<String, dynamic>? inventaris;
  final Map<String, dynamic>? teknisi;
  final List<ChecklistHasilModel> hasilChecklist;

  RealisasiModel({
    required this.realId,
    required this.realJadwalId,
    required this.realInvId,
    required this.realTeknisiId,
    required this.realTgl,
    this.realJamMulai,
    this.realJamSelesai,
    required this.realWeekNumber,
    required this.realBulan,
    required this.realTahun,
    this.realKondisiAkhir,
    this.realKeterangan,
    required this.realStatus,
    this.realTtdPicNama,
    this.realTtdData,
    this.realTtdAt,
    this.realApprovedBy,
    this.realApprovedAt,
    this.realFoto,
    this.realIsTindakLanjut = 0,
    this.realTindakLanjutCatatan,
    this.jadwal,
    this.inventaris,
    this.teknisi,
    this.hasilChecklist = const [],
  });

  static int _parseIsTindakLanjut(dynamic val) {
    if (val == null) return 0;
    if (val is int) return val;
    if (val is bool) return val ? 1 : 0;
    final str = val.toString().trim().toLowerCase();
    if (str == '1' || str == 'true') return 1;
    return 0;
  }

  factory RealisasiModel.fromJson(Map<String, dynamic> j) => RealisasiModel(
        realId: j['real_id'],
        realJadwalId: j['real_jadwal_id'],
        realInvId: j['real_inv_id'],
        realTeknisiId: j['real_teknisi_id'],
        realTgl: j['real_tgl'] ?? '',
        realJamMulai: j['real_jam_mulai'],
        realJamSelesai: j['real_jam_selesai'],
        realWeekNumber: j['real_week_number'] ?? 0,
        realBulan: j['real_bulan'] ?? 0,
        realTahun: j['real_tahun'] ?? 0,
        realKondisiAkhir: j['real_kondisi_akhir'],
        realKeterangan: j['real_keterangan'],
        realStatus: j['real_status'] ?? 'Draft',
        realTtdPicNama: j['real_ttd_pic_nama'],
        realTtdData: j['real_ttd_data'],
        realTtdAt: j['real_ttd_at'],
        realApprovedBy: j['real_approved_by'],
        realApprovedAt: j['real_approved_at'],
        realFoto: j['real_foto'],
        realIsTindakLanjut: _parseIsTindakLanjut(
            j['is_tindak_lanjut'] ?? j['real_is_tindak_lanjut']),
        realTindakLanjutCatatan:
            j['tindak_lanjut_info'] ?? j['real_tindak_lanjut_catatan'],
        jadwal: (j['jadwal'] ?? j['real_jadwal']) != null
            ? Map<String, dynamic>.from(j['jadwal'] ?? j['real_jadwal'])
            : null,
        inventaris: (j['inventaris'] ?? j['real_inv']) != null
            ? Map<String, dynamic>.from(j['inventaris'] ?? j['real_inv'])
            : null,
        teknisi: (j['teknisi'] ?? j['real_teknisi']) != null
            ? Map<String, dynamic>.from(j['teknisi'] ?? j['real_teknisi'])
            : null,
        hasilChecklist:
            (j['hasil_checklist'] ?? j['plan_hasil_checklists']) != null
                ? ((j['hasil_checklist'] ?? j['plan_hasil_checklists']) as List)
                    .map((e) => ChecklistHasilModel.fromJson(e))
                    .toList()
                : [],
      );

  bool get selesai => realStatus == 'Selesai';
  bool get isDraft => realStatus == 'Draft';
  bool get isRusak => (realKondisiAkhir ?? '').trim().toLowerCase() == 'rusak';
  bool get isPerluPerhatian =>
      (realKondisiAkhir ?? '').trim().toLowerCase() == 'perlu perhatian';
  bool get isKendala => isRusak || isPerluPerhatian;
  bool get isTindakLanjut => realIsTindakLanjut == 1;
  String get invNama => inventaris?['inv_nama'] ?? '-';
  String get invNo => inventaris?['inv_no'] ?? '-';
  String get invSerialNumber => inventaris?['inv_serial_number'] ?? '-';
}
