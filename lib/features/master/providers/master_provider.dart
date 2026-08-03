import 'package:flutter/foundation.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/utils/api_client.dart';
import '../models/checklist_template_model.dart';
import '../models/divisi_model.dart';
import '../models/inventaris_model.dart';
import '../models/jenis_model.dart';
import '../models/pabrik_model.dart';
import '../models/user_model.dart';

class MasterProvider extends ChangeNotifier {
  List<InventarisModel> inventarisList = [];
  List<ChecklistTemplateModel> checklistList = [];
  List<UserModel> userList = [];
  List<DivisiModel> divisiList = [];
  List<String> divisiMetadata = [];
  List<JenisModel> jenisMaster = [];
  List<PabrikModel> pabrikList = [];
  final Map<int, String> _jenisKategoriMap = {};
  Set<int> _jenisWithInventarisIds = {};

  bool _loading = false;
  String? _error;
  bool get loading => _loading;
  String? get error => _error;

  void _setLoading(bool v) {
    _loading = v;
    notifyListeners();
  }

  void _setError(String? v) {
    _error = v;
    notifyListeners();
  }

  // ── INVENTARIS ─────────────────────────────────────────────────
  String? kategoriByJenisId(int jenisId) => _jenisKategoriMap[jenisId];
  bool hasInventarisForJenis(int jenisId) =>
      _jenisWithInventarisIds.contains(jenisId);

  List<JenisModel> jenisAvailableForJadwal({int? includeJenisId}) {
    final includeId = includeJenisId;
    return jenisMaster.where((j) {
      if (includeId != null && j.jenisId == includeId) {
        return j.jenisIsActive && hasInventarisForJenis(j.jenisId);
      }
      return j.jenisIsActive && hasInventarisForJenis(j.jenisId);
    }).toList();
  }

  List<JenisModel> jenisAvailableForInventaris({int? includeJenisId}) {
    final includeId = includeJenisId;
    return jenisMaster.where((j) {
      if (includeId != null && j.jenisId == includeId) {
        return j.jenisIsActive;
      }
      return j.jenisIsActive && !hasInventarisForJenis(j.jenisId);
    }).toList();
  }

  bool isJenisActive(int jenisId) => jenisById(jenisId)?.jenisIsActive == true;

  JenisModel? jenisById(int jenisId) {
    try {
      return jenisMaster.firstWhere((j) => j.jenisId == jenisId);
    } catch (_) {
      return null;
    }
  }

  PabrikModel? pabrikByKode(String? kode) {
    if (kode == null || kode.isEmpty) return null;
    try {
      return pabrikList.firstWhere((p) => p.pabKode == kode);
    } catch (_) {
      return null;
    }
  }

  String displayPabrik(String? kode) {
    final pabrik = pabrikByKode(kode);
    if (pabrik == null) return kode ?? '-';
    return pabrik.displayLabel;
  }

  Future<void> fetchInventaris(
      {String? kategori,
      String? jenis,
      String? pabrik,
      String? q,
      bool showLoading = true,
      bool updateKategoriMap = true}) async {
    if (showLoading) _setLoading(true);
    try {
      final query = {
        if (kategori != null) 'kategori': kategori,
        if (jenis != null) 'jenis': jenis,
        if (pabrik != null) 'pabrik': pabrik,
        if (q != null) 'q': q,
      };
      final res = await ApiClient.get(ApiConfig.inventaris, query: query);
      final dataField = res['data'];
      final List rawList = dataField is Map && dataField.containsKey('items')
          ? dataField['items']
          : (dataField as List);
      inventarisList = rawList
          .map((e) => InventarisModel.fromJson(e))
          .toList();
      if (updateKategoriMap && jenisMaster.isNotEmpty) {
        _jenisKategoriMap
          ..clear()
          ..addEntries(
            jenisMaster.map((j) => MapEntry(j.jenisId, j.jenisKategori)),
          );
      }
      _setError(null);
    } on ApiException catch (e) {
      _setError(e.message);
    } finally {
      if (showLoading) _setLoading(false);
    }
  }

  Future<bool> saveInventaris(Map<String, dynamic> body, {int? id}) async {
    try {
      if (id != null) {
        await ApiClient.put('${ApiConfig.inventaris}/$id', body);
      } else {
        await ApiClient.post(ApiConfig.inventaris, body);
      }
      await fetchInventaris();
      return true;
    } on ApiException catch (e) {
      _setError(e.message);
      return false;
    }
  }

  Future<bool> toggleInventarisAktif(int id) async {
    try {
      await ApiClient.patch('${ApiConfig.inventaris}/$id/aktif', {});
      final index = inventarisList.indexWhere((item) => item.invId == id);
      if (index != -1) {
        final current = inventarisList[index];
        inventarisList[index] = InventarisModel(
          invId: current.invId,
          invNo: current.invNo,
          invNama: current.invNama,
          invKategori: current.invKategori,
          invJenisId: current.invJenisId,
          invPabrikKode: current.invPabrikKode,
          invMerk: current.invMerk,
          invSerialNumber: current.invSerialNumber,
          invPic: current.invPic,
          invTglBeli: current.invTglBeli,
          invKondisi: current.invKondisi,
          invIsActive: !current.invIsActive,
          invNotes: current.invNotes,
        );
        notifyListeners();
      }
      return true;
    } on ApiException catch (e) {
      _setError(e.message);
      return false;
    }
  }

  Future<void> fetchPabrik({bool showLoading = false}) async {
    if (showLoading) _setLoading(true);
    try {
      final res = await ApiClient.get(ApiConfig.pabrik, auth: false);
      pabrikList =
          (res['data'] as List).map((e) => PabrikModel.fromJson(e)).toList();
      _setError(null);
      notifyListeners();
    } on ApiException catch (e) {
      _setError(e.message);
    } finally {
      if (showLoading) _setLoading(false);
    }
  }

  Future<bool> toggleJenisAktif(int id, bool isActive) async {
    try {
      await ApiClient.put('${ApiConfig.jenis}/$id', {
        'jenis_is_active': isActive,
      });
      final index = jenisMaster.indexWhere((item) => item.jenisId == id);
      if (index != -1) {
        final current = jenisMaster[index];
        jenisMaster[index] = JenisModel(
          jenisId: current.jenisId,
          jenisNama: current.jenisNama,
          jenisKategori: current.jenisKategori,
          jenisGapHari: current.jenisGapHari,
          jenisIsActive: isActive,
        );
        notifyListeners();
      }
      return true;
    } on ApiException catch (e) {
      _setError(e.message);
      return false;
    }
  }

  Future<bool> deleteInventaris(int id) async {
    try {
      await ApiClient.delete('${ApiConfig.inventaris}/$id');
      await fetchInventaris();
      return true;
    } on ApiException catch (e) {
      _setError(e.message);
      return false;
    }
  }

  // ── METADATA & DIVISI ──────────────────────────────────────────
  Future<void> fetchMetadata({bool showLoading = true}) async {
    if (showLoading) _setLoading(true);
    try {
      final res = await ApiClient.get(ApiConfig.metadata);
      final rawDivisi = res['data']['divisi'] as List;
      divisiMetadata = rawDivisi.map((e) => e.toString()).toList();
      _setError(null);
    } on ApiException catch (e) {
      _setError(e.message);
    } finally {
      if (showLoading) _setLoading(false);
    }
    notifyListeners();
  }

  // ── CHECKLIST TEMPLATE ─────────────────────────────────────────
  Future<void> fetchChecklist({String? jenis}) async {
    _setLoading(true);
    try {
      final res = await ApiClient.get(
        ApiConfig.checklistTemplate,
        query: jenis != null ? {'jenis': jenis} : null,
      );
      if (kDebugMode) {
        debugPrint('[Checklist] fetched ${res['data']?.length ?? 0} rows'
            '${jenis != null ? ' for jenis=$jenis' : ''}');
      }
      checklistList = (res['data'] as List)
          .map((e) => ChecklistTemplateModel.fromJson(e))
          .toList();
      if (kDebugMode) {
        debugPrint(
            '[Checklist] provider list length = ${checklistList.length}');
      }
      _setError(null);
    } on ApiException catch (e) {
      _setError(e.message);
    } finally {
      _setLoading(false);
    }
  }

  Future<void> fetchJenis({bool showLoading = false}) async {
    if (showLoading) _setLoading(true);
    try {
      final res = await ApiClient.get(ApiConfig.jenis);
      jenisMaster =
          (res['data'] as List).map((e) => JenisModel.fromJson(e)).toList();
      _jenisKategoriMap
        ..clear()
        ..addEntries(
            jenisMaster.map((j) => MapEntry(j.jenisId, j.jenisKategori)));
      _setError(null);
    } on ApiException catch (e) {
      _setError(e.message);
    } finally {
      if (showLoading) _setLoading(false);
    }
    notifyListeners();
  }

  Future<void> fetchJenisWithInventaris({bool showLoading = false}) async {
    if (showLoading) _setLoading(true);
    try {
      final res = await ApiClient.get('${ApiConfig.inventaris}/jenis');
      final rawList = res['data'] as List;
      _jenisWithInventarisIds = rawList
          .map((e) => e is int ? e : int.tryParse('$e'))
          .whereType<int>()
          .toSet();
      _setError(null);
      notifyListeners();
    } on ApiException catch (e) {
      _setError(e.message);
    } finally {
      if (showLoading) _setLoading(false);
    }
  }

  Future<bool> saveJenis(Map<String, dynamic> body, {int? id}) async {
    try {
      if (id != null) {
        await ApiClient.put('${ApiConfig.jenis}/$id', body);
      } else {
        await ApiClient.post(ApiConfig.jenis, body);
      }
      await fetchJenis();
      return true;
    } on ApiException catch (e) {
      _setError(e.message);
      return false;
    }
  }

  Future<bool> deleteJenis(int id) async {
    try {
      await ApiClient.delete('${ApiConfig.jenis}/$id');
      await fetchJenis();
      return true;
    } on ApiException catch (e) {
      _setError(e.message);
      return false;
    }
  }

  Future<bool> bulkCreateChecklist(
      String jenis, List<Map<String, dynamic>> items) async {
    try {
      await ApiClient.post('${ApiConfig.checklistTemplate}/bulk', {
        'ct_jenis_id': jenis,
        'items': items,
      });
      await fetchChecklist();
      return true;
    } on ApiException catch (e) {
      _setError(e.message);
      return false;
    }
  }

  Future<bool> saveChecklist(Map<String, dynamic> body, {int? id}) async {
    try {
      if (id != null) {
        await ApiClient.put('${ApiConfig.checklistTemplate}/$id', body);
      } else {
        await ApiClient.post(ApiConfig.checklistTemplate, body);
      }
      await fetchChecklist();
      return true;
    } on ApiException catch (e) {
      _setError(e.message);
      return false;
    }
  }

  Future<bool> deleteChecklist(int id) async {
    try {
      await ApiClient.delete('${ApiConfig.checklistTemplate}/$id');
      await fetchChecklist();
      return true;
    } on ApiException catch (e) {
      _setError(e.message);
      return false;
    }
  }

  // ── USERS ──────────────────────────────────────────────────────
  Future<List<UserModel>> fetchUsers(
      {String? jabatan,
      String? divisi,
      String? scope,
      bool showLoading = true,
      bool replaceState = true}) async {
    final toggleLoading = showLoading && replaceState;
    if (toggleLoading) _setLoading(true);
    try {
      final query = {
        if (jabatan != null) 'jabatan': jabatan,
        if (divisi != null) 'divisi': divisi,
        if (scope != null) 'scope': scope,
      };
      final res = await ApiClient.get(ApiConfig.users,
          query: query.isEmpty ? null : query);
      final list =
          (res['data'] as List).map((e) => UserModel.fromJson(e)).toList();
      if (replaceState) {
        userList = list;
        _setError(null);
      }
      return list;
    } on ApiException catch (e) {
      if (replaceState) {
        _setError(e.message);
        return const [];
      }
      rethrow;
    } finally {
      if (toggleLoading) _setLoading(false);
    }
  }

  Future<bool> saveUser(Map<String, dynamic> body, {int? id}) async {
    try {
      if (id != null) {
        await ApiClient.put('${ApiConfig.users}/$id', body);
      } else {
        await ApiClient.post(ApiConfig.users, body);
      }
      await fetchUsers();
      return true;
    } on ApiException catch (e) {
      _setError(e.message);
      return false;
    }
  }

  Future<bool> toggleUserAktif(int id) async {
    try {
      await ApiClient.patch('${ApiConfig.users}/$id/aktif', {});
      final index = userList.indexWhere((u) => u.userId == id);
      if (index != -1) {
        final current = userList[index];
        userList[index] = UserModel(
          userId: current.userId,
          userNama: current.userNama,
          userNik: current.userNik,
          userJabatan: current.userJabatan,
          userDivisi: current.userDivisi,
          userCabang: current.userCabang,
          userIsActive: !current.userIsActive,
        );
        notifyListeners();
      }
      return true;
    } on ApiException catch (e) {
      _setError(e.message);
      return false;
    }
  }
}
