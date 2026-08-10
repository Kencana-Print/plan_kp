import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

abstract class SecureStorage {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
  Future<void> deleteAll();
}

class WebSafeStorage implements SecureStorage {
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  final Map<String, String> _memoryStorage = {};

  @override
  Future<String?> read(String key) async {
    if (kIsWeb) {
      try {
        final prefs = await SharedPreferences.getInstance();
        return prefs.getString(key) ?? _memoryStorage[key];
      } catch (_) {
        return _memoryStorage[key];
      }
    }
    try {
      return await _secureStorage.read(key: key);
    } catch (_) {
      try {
        final prefs = await SharedPreferences.getInstance();
        return prefs.getString(key) ?? _memoryStorage[key];
      } catch (_) {
        return _memoryStorage[key];
      }
    }
  }

  @override
  Future<void> write(String key, String value) async {
    _memoryStorage[key] = value;
    if (kIsWeb) {
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(key, value);
      } catch (_) {}
      return;
    }
    try {
      await _secureStorage.write(key: key, value: value);
    } catch (_) {
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(key, value);
      } catch (_) {}
    }
  }

  @override
  Future<void> delete(String key) async {
    _memoryStorage.remove(key);
    if (kIsWeb) {
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove(key);
      } catch (_) {}
      return;
    }
    try {
      await _secureStorage.delete(key: key);
    } catch (_) {
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove(key);
      } catch (_) {}
    }
  }

  @override
  Future<void> deleteAll() async {
    _memoryStorage.clear();
    if (kIsWeb) {
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.clear();
      } catch (_) {}
      return;
    }
    try {
      await _secureStorage.deleteAll();
    } catch (_) {
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.clear();
      } catch (_) {}
    }
  }
}

class SecureStorageService {
  static SecureStorage instance = WebSafeStorage();

  static Future<String?> read(String key) => instance.read(key);
  static Future<void> write(String key, String value) => instance.write(key, value);
  static Future<void> delete(String key) => instance.delete(key);
  static Future<void> deleteAll() => instance.deleteAll();
}
