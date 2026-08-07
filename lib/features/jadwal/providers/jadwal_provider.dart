import 'package:flutter/foundation.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/utils/api_client.dart';
import '../models/jadwal_model.dart';
import '../models/realisasi_model.dart';
import '../models/checklist_hasil_model.dart';

class JadwalProvider extends ChangeNotifier {
  List<JadwalModel> jadwalList = [];
  List<JadwalModel> jadwalHariIni = [];
  List<RealisasiModel> realisasiList = [];
  RealisasiModel? realisasiDetail;
  JadwalModel? jadwalDetail;
  List<dynamic> inventarisByJenis = [];
  List<dynamic> monitoringDivisiList = [];
  int? monitoringBulan;
  int? monitoringTahun;
  final Map<String, Set<int>> _holidayDaysByMonth = {};
  Map<String, dynamic> dashboardSummary = {};
  List<RealisasiModel> kendalaList = [];
  bool loadingKendala = false;
  String? _lastKendalaDivisi;
  DateTime? _lastKendalaFetchTime;

  Future<void> fetchKendalaDivisi({
    String? divisi,
    String filterTindakLanjut = 'all',
    bool forceRefresh = false,
  }) async {
    // ⚡ Smart Caching 30 detik: Jika request sama dan belum 30 detik, manfaatkan cache lokal
    final now = DateTime.now();
    if (!forceRefresh &&
        _lastKendalaDivisi == divisi &&
        _lastKendalaFetchTime != null &&
        now.difference(_lastKendalaFetchTime!).inSeconds < 30 &&
        kendalaList.isNotEmpty) {
      return;
    }

    loadingKendala = true;
    notifyListeners();
    try {
      final query = <String, dynamic>{
        'kondisi_akhir': 'Rusak,Perlu Perhatian',
        if (filterTindakLanjut != 'all') 'tindak_lanjut': filterTindakLanjut,
        if (divisi != null && divisi.isNotEmpty) 'divisi': divisi,
      };
      final res = await ApiClient.get('${ApiConfig.realisasi}/kendala', query: query);
      final rawList = (res['data'] as List? ?? []);
      kendalaList = rawList.map((j) => RealisasiModel.fromJson(j)).toList();
      _lastKendalaDivisi = divisi;
      _lastKendalaFetchTime = now;
      _setError(null);
    } on ApiException catch (e) {
      _setError(e.message);
    } finally {
      loadingKendala = false;
      notifyListeners();
    }
  }
  
  // (sisanya tetap sama, mari kita sesuaikan fetchMonitoringDivisi di bawah)
  
  Future<void> fetchMonitoringDivisi({int? bulan, int? tahun}) async {
    _setLoading(true);
    try {
      final query = <String, dynamic>{
        if (bulan != null) 'bulan': bulan,
        if (tahun != null) 'tahun': tahun,
      };
      final res = await ApiClient.get(ApiConfig.monitoringDivisi, query: query);
      final responseData = res['data'];
      if (responseData is Map<String, dynamic>) {
        monitoringDivisiList = responseData['data'] ?? [];
        monitoringBulan = responseData['bulan'];
        monitoringTahun = responseData['tahun'];
      } else {
        monitoringDivisiList = responseData ?? [];
        monitoringBulan = bulan;
        monitoringTahun = tahun;
      }
      _setError(null);
    } on ApiException catch (e) {
      _setError(e.message);
    } finally {
      _setLoading(false);
    }
  }

  bool _loading = false;
  bool _loadingDetail = false;
  String? _error;
  bool _lastFetchDivisi = false;
  bool _lastFetchUser = false;
  String? _lastJadwalStatus;
  String? _lastJadwalJenis;
  int? _lastJadwalJenisId;
  bool get loading => _loading;
  bool get loadingDetail => _loadingDetail;
  String? get error => _error;

  Set<int> getHolidayDaysForMonth(DateTime month, {String? divisi}) {
    final key = '${_monthKey(month)}_${divisi ?? "ALL"}';
    return _holidayDaysByMonth[key] ?? <int>{};
  }

  String _monthKey(DateTime month) =>
      '${month.year}-${month.month.toString().padLeft(2, '0')}';

  List<dynamic> _extractHolidayItems(dynamic data) {
    if (data is Map<String, dynamic>) {
      final items = data['items'];
      if (items is List) return items;
      return const [];
    }
    if (data is List) return data;
    return const [];
  }

  Future<void> fetchHariLiburForMonth(DateTime month, {String? divisi}) async {
    final key = '${_monthKey(month)}_${divisi ?? "ALL"}';
    if (_holidayDaysByMonth.containsKey(key)) return;

    try {
      final query = <String, dynamic>{
        'year': month.year,
        'month': month.month,
        if (divisi != null && divisi.isNotEmpty) 'divisi': divisi,
      };
      final res = await ApiClient.get(
        ApiConfig.jadwalHariLibur,
        query: query,
      );
      final items = _extractHolidayItems(res['data']);
      final days = <int>{};
      for (final item in items) {
        if (item is! Map<String, dynamic>) continue;
        final tanggal = _extractHolidayDateString(item);
        if (tanggal == null || tanggal.isEmpty) continue;
        final date = _parseHolidayDate(tanggal);
        if (date == null) continue;
        if (date.year == month.year && date.month == month.month) {
          days.add(date.day);
        }
      }
      _holidayDaysByMonth[key] = days;
      notifyListeners();
    } on ApiException {
      _holidayDaysByMonth.remove(key);
      notifyListeners();
    }
  }

  String? _extractHolidayDateString(Map<String, dynamic> item) {
    const keys = [
      'tanggal',
      'hl_tanggal',
      'hlib_tanggal',
      'harilibur_tanggal',
      'tgl',
      'date',
    ];
    for (final key in keys) {
      final value = item[key]?.toString().trim();
      if (value != null && value.isNotEmpty) return value;
    }
    return null;
  }

  DateTime? _parseHolidayDate(String raw) {
    final parsed = DateTime.tryParse(raw);
    if (parsed != null) return parsed;

    final normalized = raw.replaceAll('/', '-');
    final parts = normalized.split('-');
    if (parts.length == 3) {
      final a = int.tryParse(parts[0]);
      final b = int.tryParse(parts[1]);
      final c = int.tryParse(parts[2]);
      // fallback format: dd-MM-yyyy
      if (a != null && b != null && c != null && c > 1900) {
        return DateTime(c, b, a);
      }
    }
    return null;
  }

  void _setLoading(bool v) {
    _loading = v;
    notifyListeners();
  }

  void _setLoadingDetail(bool v) {
    _loadingDetail = v;
    notifyListeners();
  }

  void _setError(String? v) {
    _error = v;
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  // ── JADWAL ─────────────────────────────────────────────────
  Future<void> fetchJadwal({String? status, String? jenis}) async {
    _setLoading(true);
    _lastFetchDivisi = false;
    _lastFetchUser = false;
    _lastJadwalStatus = status;
    _lastJadwalJenis = jenis;
    _lastJadwalJenisId = null;
    try {
      final query = <String, dynamic>{
        if (status != null) 'status': status,
        if (jenis != null) 'jenis': jenis,
      };
      final res = await ApiClient.get(ApiConfig.jadwal, query: query);
      jadwalList = ((res['data']['items'] ?? []) as List)
          .map((e) => JadwalModel.fromJson(e))
          .toList();
      _setError(null);
    } on ApiException catch (e) {
      _setError(e.message);
    } finally {
      _setLoading(false);
    }
  }

  Future<void> fetchJadwalByDivisi({String? status, int? jenisId}) async {
    _setLoading(true);
    _lastFetchDivisi = true;
    _lastFetchUser = false;
    _lastJadwalStatus = status;
    _lastJadwalJenis = null;
    _lastJadwalJenisId = jenisId;
    try {
      final query = <String, dynamic>{
        if (status != null) 'status': status,
        if (jenisId != null) 'jenis': jenisId,
      };
      final res =
          await ApiClient.get('${ApiConfig.jadwal}/divisi', query: query);
      jadwalList = ((res['data']['items'] ?? []) as List)
          .map((e) => JadwalModel.fromJson(e))
          .toList();
      _setError(null);
    } on ApiException catch (e) {
      _setError(e.message);
    } finally {
      _setLoading(false);
    }
  }

  Future<void> fetchJadwalByUser({String? status, int? jenisId}) async {
    _setLoading(true);
    _lastFetchUser = true;
    _lastFetchDivisi = false;
    _lastJadwalStatus = status;
    _lastJadwalJenis = null;
    _lastJadwalJenisId = jenisId;
    try {
      final query = <String, dynamic>{
        if (status != null) 'status': status,
        if (jenisId != null) 'jenis': jenisId,
      };
      final res =
          await ApiClient.get('${ApiConfig.jadwal}/assigned', query: query);
      jadwalList = ((res['data']['items'] ?? []) as List)
          .map((e) => JadwalModel.fromJson(e))
          .toList();
      _setError(null);
    } on ApiException catch (e) {
      _setError(e.message);
    } finally {
      _setLoading(false);
    }
  }

  Future<void> fetchJadwalHariIni() async {
    _setLoading(true);
    try {
      final res = await ApiClient.get('${ApiConfig.jadwal}/hari-ini');
      jadwalHariIni = ((res['data']['items'] ?? []) as List)
          .map((e) => JadwalModel.fromJson(e))
          .toList();
      _setError(null);
    } on ApiException catch (e) {
      _setError(e.message);
    } finally {
      _setLoading(false);
    }
  }



  Future<void> fetchJadwalDetail(int id,
      {bool affectGlobalLoading = true}) async {
    if (affectGlobalLoading) {
      _setLoading(true);
    } else {
      _setLoadingDetail(true);
    }
    try {
      final res = await ApiClient.get('${ApiConfig.jadwal}/$id');
      jadwalDetail = JadwalModel.fromJson(res['data']['jadwal']);
      inventarisByJenis = List.from(res['data']['inventaris']);
      _setError(null);
    } on ApiException catch (e) {
      _setError(e.message);
    } finally {
      if (affectGlobalLoading) {
        _setLoading(false);
      } else {
        _setLoadingDetail(false);
      }
    }
  }

  Future<bool> saveJadwal(Map<String, dynamic> body, {int? id}) async {
    try {
      if (id != null) {
        await ApiClient.put('${ApiConfig.jadwal}/$id', body);
      } else {
        await ApiClient.post(ApiConfig.jadwal, body);
      }
      if (_lastFetchUser) {
        await fetchJadwalByUser(
          status: _lastJadwalStatus,
          jenisId: _lastJadwalJenisId,
        );
      } else if (_lastFetchDivisi) {
        await fetchJadwalByDivisi(
          status: _lastJadwalStatus,
          jenisId: _lastJadwalJenisId,
        );
      } else {
        await fetchJadwal(status: _lastJadwalStatus, jenis: _lastJadwalJenis);
      }
      return true;
    } on ApiException catch (e) {
      _setError(e.message);
      return false;
    }
  }

  Future<bool> updateStatusJadwal(int id, String status) async {
    try {
      await ApiClient.patch(
          '${ApiConfig.jadwal}/$id/status', {'status': status});
      if (_lastFetchUser) {
        await fetchJadwalByUser(
          status: _lastJadwalStatus,
          jenisId: _lastJadwalJenisId,
        );
      } else if (_lastFetchDivisi) {
        await fetchJadwalByDivisi(
          status: _lastJadwalStatus,
          jenisId: _lastJadwalJenisId,
        );
      } else {
        await fetchJadwal(status: _lastJadwalStatus, jenis: _lastJadwalJenis);
      }
      return true;
    } on ApiException catch (e) {
      _setError(e.message);
      return false;
    }
  }

  // ── REALISASI ──────────────────────────────────────────────
  Future<void> fetchRealisasi({
    int? jadwalId,
    String? status,
    bool byDivisi = false,
  }) async {
    _setLoading(true);
    try {
      final query = <String, dynamic>{
        if (jadwalId != null) 'jadwal_id': jadwalId,
        if (status != null) 'status': status,
        if (byDivisi) 'by_divisi': true,
      };
      final res = await ApiClient.get(ApiConfig.realisasi, query: query);
      realisasiList = ((res['data']['items'] ?? res['data']) as List)
          .map((e) => RealisasiModel.fromJson(e))
          .toList();
      _setError(null);
    } on ApiException catch (e) {
      _setError(e.message);
    } finally {
      _setLoading(false);
    }
  }

  Future<List<RealisasiModel>> fetchRealisasiByJadwal(int jadwalId,
      {String? status}) async {
    try {
      final query = <String, dynamic>{
        'jadwal_id': jadwalId,
        if (status != null) 'status': status,
      };
      final res = await ApiClient.get(ApiConfig.realisasi, query: query);
      return ((res['data']['items'] ?? res['data']) as List)
          .map((e) => RealisasiModel.fromJson(e))
          .toList();
    } on ApiException {
      return [];
    }
  }

  Future<List<RealisasiModel>> fetchRealisasiForReport({
    required int bulan,
    required int tahun,
    String? divisi,
    int? teknisiId,
  }) async {
    try {
      final query = <String, dynamic>{
        'bulan': bulan,
        'tahun': tahun,
        'status': 'Selesai',
        if (divisi != null && divisi != 'Semua Divisi') 'divisi': divisi,
        if (teknisiId != null) 'teknisi_id': teknisiId,
      };
      final res = await ApiClient.get(ApiConfig.realisasi, query: query);
      return ((res['data']['items'] ?? res['data']) as List)
          .map((e) => RealisasiModel.fromJson(e))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<List<RealisasiModel>> fetchDraftRealisasi({bool? byDivisi}) async {
    try {
      final query = <String, dynamic>{
        'status': 'Draft',
        if (byDivisi != null) 'by_divisi': byDivisi,
      };
      final res = await ApiClient.get(ApiConfig.realisasi, query: query);
      return ((res['data']['items'] ?? res['data']) as List)
          .map((e) => RealisasiModel.fromJson(e))
          .toList();
    } on ApiException {
      return [];
    }
  }

  Future<RealisasiModel?> fetchLastTemuanByInventaris(int invId) async {
    try {
      final res = await ApiClient.get(ApiConfig.realisasi, query: {'inv_id': invId});
      final list = ((res['data']['items'] ?? res['data']) as List)
          .map((e) => RealisasiModel.fromJson(e))
          .toList();

      final temuanList = list.where((r) {
        final hasKet = r.realKeterangan != null && r.realKeterangan!.trim().isNotEmpty;
        final notBaik = r.realKondisiAkhir != null && r.realKondisiAkhir != 'Baik';
        return hasKet || notBaik;
      }).toList();

      if (temuanList.isEmpty) return null;
      temuanList.sort((a, b) => b.realTgl.compareTo(a.realTgl));
      return temuanList.first;
    } catch (_) {
      return null;
    }
  }

  Future<void> fetchRealisasiDetail(int id) async {
    _setLoading(true);
    try {
      final res = await ApiClient.get('${ApiConfig.realisasi}/$id');
      realisasiDetail = RealisasiModel.fromJson(res['data']);
      _setError(null);
    } on ApiException catch (e) {
      _setError(e.message);
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> checkRealisasiEligibility(int jadwalId, int invId, String tgl) async {
    try {
      await ApiClient.post('${ApiConfig.realisasi}/check-eligibility', {
        'real_jadwal_id': jadwalId,
        'real_inv_id': invId,
        'real_tgl': tgl,
      });
      _setError(null);
      return true;
    } on ApiException catch (e) {
      _setError(e.message);
      return false;
    }
  }

  Future<RealisasiModel?> createRealisasi(Map<String, dynamic> body) async {
    try {
      final res = await ApiClient.post(ApiConfig.realisasi, body);
      return RealisasiModel.fromJson(res['data']);
    } on ApiException catch (e) {
      _setError(e.message);
      return null;
    }
  }

  Future<bool> updateRealisasi(int realId, Map<String, dynamic> body) async {
    try {
      await ApiClient.put('${ApiConfig.realisasi}/$realId', body);
      return true;
    } on ApiException catch (e) {
      _setError(e.message);
      return false;
    }
  }

  Future<bool> saveChecklist(
      int realId, List<ChecklistInputModel> items) async {
    try {
      await ApiClient.post('${ApiConfig.realisasi}/$realId/checklist', {
        'hasil': items.map((e) => e.toJson()).toList(),
      });
      return true;
    } on ApiException catch (e) {
      _setError(e.message);
      return false;
    }
  }

  Future<bool> saveTtd(int realId, String picNama, String ttdBase64) async {
    try {
      await ApiClient.post('${ApiConfig.realisasi}/$realId/ttd', {
        'real_ttd_pic_nama': picNama,
        'real_ttd_data': ttdBase64,
      });
      return true;
    } on ApiException catch (e) {
      _setError(e.message);
      return false;
    }
  }

  Future<bool> uploadRealisasiFoto(
    int realId, {
    String? filePath,
    List<int>? bytes,
    String? filename,
  }) async {
    try {
      await ApiClient.upload(
        '${ApiConfig.realisasi}/$realId/foto',
        filePath: filePath,
        bytes: bytes,
        filename: filename,
      );
      return true;
    } on ApiException catch (e) {
      _setError(e.message);
      return false;
    }
  }


  // Ambil template checklist untuk jenis inventaris tertentu
  Future<List<ChecklistInputModel>> fetchTemplate(int jenisId) async {
    try {
      final res =
          await ApiClient.get('${ApiConfig.realisasi}/template/$jenisId');
      _setError(null);
      return (res['data'] as List)
          .map((e) => ChecklistInputModel.fromTemplate(e))
          .toList();
    } on ApiException catch (e) {
      _setError(e.message);
      return [];
    }
  }

  Future<void> fetchDashboardSummary() async {
    _setLoading(true);
    try {
      final res = await ApiClient.get(ApiConfig.dashboardSummary);
      dashboardSummary = Map<String, dynamic>.from(res['data'] ?? {});
      _setError(null);
    } on ApiException catch (e) {
      _setError(e.message);
    } finally {
      _setLoading(false);
    }
  }
}
