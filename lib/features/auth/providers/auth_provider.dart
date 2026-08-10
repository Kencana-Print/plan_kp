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
      String appVersion = '1.0.0+1';
      try {
        final packageInfo = await PackageInfo.fromPlatform();
        appVersion = '${packageInfo.version}+${packageInfo.buildNumber}';
      } catch (_) {}

      final res = await ApiClient.post(
        ApiConfig.login,
        {
          'user_nama': user_nama,
          'user_password': user_password,
          'app_version': appVersion,
        },
        auth: false,
      );

      final data = res['data'] as Map<String, dynamic>? ?? {};
      final token = (data['token'] ?? '').toString();
      _user = data['user'] as Map<String, dynamic>?;

      if (token.isNotEmpty) {
        await SecureStorageService.write(StorageKeys.token, token);
      }
      if (_user != null) {
        await SecureStorageService.write(StorageKeys.userData, jsonEncode(_user));
      }

      _loading = false;
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      _error = e.message;
      _loading = false;
      notifyListeners();
      return false;
    } catch (e) {
      debugPrint('[Login Exception] $e');
      _error = e.toString().replaceFirst('Exception: ', '');
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
      final data = res['data'] as Map<String, dynamic>? ?? {};
      final token = (data['token'] ?? '').toString();
      _user = data['user'] as Map<String, dynamic>?;

      if (token.isNotEmpty) {
        await SecureStorageService.write(StorageKeys.token, token);
      }
      if (_user != null) {
        await SecureStorageService.write(StorageKeys.userData, jsonEncode(_user));
      }

      _loading = false;
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      _error = e.message;
      _loading = false;
      notifyListeners();
      return false;
    } catch (e) {
      debugPrint('[Register Exception] $e');
      _error = e.toString().replaceFirst('Exception: ', '');
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
