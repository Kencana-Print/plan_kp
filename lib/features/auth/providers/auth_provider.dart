// ignore_for_file: non_constant_identifier_names

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/utils/api_client.dart';
import '../../../core/utils/secure_storage.dart';

class AuthProvider extends ChangeNotifier {
  Map<String, dynamic>? _user;
  bool _loading = false;
  String? _error;

  Map<String, dynamic>? get user => _user;
  bool get loading => _loading;
  String? get error => _error;
  bool get isLoggedIn => _user != null;
  String get jabatan => _user?['user_jabatan'] ?? '';

  Future<void> checkSession() async {
    final token = await SecureStorageService.read(StorageKeys.token);
    if (token == null) return;
    try {
      final res = await ApiClient.get(ApiConfig.me);
      _user = res['data'];
      notifyListeners();
    } catch (_) {
      await SecureStorageService.delete(StorageKeys.token);
    }
  }

  Future<bool> login(String user_nama, String user_password) async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final String appVersion = '${packageInfo.version}+${packageInfo.buildNumber}';

      final res = await ApiClient.post(
        ApiConfig.login,
        {
          'user_nama': user_nama,
          'user_password': user_password,
          'app_version': appVersion,
        },
        auth: false,
      );
      final token = res['data']['token'] as String;
      _user = res['data']['user'];
      await SecureStorageService.write(StorageKeys.token, token);
      await SecureStorageService.write(StorageKeys.userData, jsonEncode(_user));
      _loading = false;
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      _error = e.message;
      _loading = false;
      notifyListeners();
      return false;
    } catch (e) {
      if (kDebugMode) debugPrint('[Login Error] $e');
      _error = 'Tidak dapat terhubung ke server';
      _loading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> register({
    required String userNama,
    required String userPassword,
    required String userDivisi,
    required String userCabang,
    required String userNik,
    required String userJabatan,
  }) async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      final body = <String, dynamic>{
        'user_nama': userNama,
        'user_password': userPassword,
        'user_divisi': userDivisi,
        'user_jabatan': userJabatan,
        'user_cabang': userCabang,
        'user_nik': userNik,
      };
      final res = await ApiClient.post(
        ApiConfig.register,
        body,
        auth: false,
      );
      final token = res['data']['token'] as String;
      _user = res['data']['user'];
      await SecureStorageService.write(StorageKeys.token, token);
      await SecureStorageService.write(StorageKeys.userData, jsonEncode(_user));
      _loading = false;
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      _error = e.message;
      _loading = false;
      notifyListeners();
      return false;
    } catch (e) {
      if (kDebugMode) debugPrint('[Register Error] $e');
      _error = 'Tidak dapat terhubung ke server';
      _loading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> logout() async {
    _user = null;
    await SecureStorageService.delete(StorageKeys.token);
    await SecureStorageService.delete(StorageKeys.userData);
    notifyListeners();
  }
}
