import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'update_checker.dart';
import 'update_downloader.dart';

/// Service terpusat untuk semua logika update.
/// Singleton — satu instance dipakai di seluruh app.
class UpdateService {
  static final UpdateService instance = UpdateService._();
  UpdateService._();

  final UpdateChecker _checker = UpdateChecker();
  final UpdateDownloader _downloader = UpdateDownloader();

  // ─── Cache & Throttle ───
  AppUpdateCheckResult? _cachedResult;
  DateTime? _lastCheckTime;

  /// Interval minimum antar pengecekan: 1 jam
  static const _throttleDuration = Duration(hours: 1);

  static const _skippedBuildKey = 'update_skipped_build_number';

  // ─── Getters ───
  UpdateDownloader get downloader => _downloader;
  AppUpdateCheckResult? get cachedResult => _cachedResult;

  // ─── Cek Update (dengan throttle & skip) ───

  /// Cek update ke server.
  /// - [force]: bypass throttle (misalnya dipanggil manual oleh user)
  /// Return null jika di-throttle atau versi sudah di-skip.
  Future<AppUpdateCheckResult?> checkForUpdate({bool force = false}) async {
    // Pada Flutter Web, pengecekan APK update Android tidak diperlukan dan dilewati untuk menghindari CORS/Cross-Origin error
    if (kIsWeb) return null;

    final now = DateTime.now();

    // Throttle: jangan cek jika belum lewat 1 jam (kecuali force)
    if (!force &&
        _lastCheckTime != null &&
        now.difference(_lastCheckTime!) < _throttleDuration) {
      debugPrint(
          '[UpdateService] Throttled — terakhir cek ${now.difference(_lastCheckTime!).inMinutes} menit lalu');
      // Kembalikan cached result agar caller tetap bisa pakai data terakhir
      return _cachedResult;
    }

    debugPrint('[UpdateService] Memulai pengecekan update...');
    _lastCheckTime = now;

    try {
      final result = await _checker.checkForUpdate();
      _cachedResult = result;

      // Jika ada update, cek apakah versi ini sudah di-skip
      if (result.hasUpdate && result.manifest != null) {
        final skipped = await isVersionSkipped(result.manifest!.buildNumber);
        if (skipped && !force) {
          debugPrint(
              '[UpdateService] Build ${result.manifest!.buildNumber} sudah di-skip user');
          return AppUpdateCheckResult(
            status: AppUpdateStatus.upToDate,
            currentVersion: result.currentVersion,
            currentBuildNumber: result.currentBuildNumber,
          );
        }
      }

      return result;
    } catch (e) {
      debugPrint('[UpdateService] Error: $e');
      return AppUpdateCheckResult(
        status: AppUpdateStatus.failedCheck,
        currentVersion: _cachedResult?.currentVersion ?? '',
        currentBuildNumber: _cachedResult?.currentBuildNumber ?? 0,
      );
    }
  }

  // ─── Skip Version ───

  /// Tandai build number ini sebagai "di-skip" oleh user (tombol "Nanti Saja").
  /// Dialog tidak akan ditampilkan lagi untuk build ini.
  Future<void> skipVersion(int buildNumber) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_skippedBuildKey, buildNumber);
      debugPrint('[UpdateService] Build $buildNumber di-skip');
    } catch (e) {
      debugPrint('[UpdateService] Error skip version: $e');
    }
  }

  /// Cek apakah build number tertentu sudah di-skip.
  Future<bool> isVersionSkipped(int buildNumber) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final skipped = prefs.getInt(_skippedBuildKey) ?? 0;
      return skipped >= buildNumber;
    } catch (_) {
      return false;
    }
  }

  /// Reset skip (dipanggil saat ada build baru yang lebih tinggi dari yang di-skip).
  Future<void> clearSkip() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_skippedBuildKey);
    } catch (_) {}
  }

  // ─── Local APK Check ───

  /// Cek apakah file APK untuk versi tertentu sudah ada di storage lokal.
  Future<String?> checkLocalApk({
    required String downloadUrl,
    required String versionName,
  }) {
    if (kIsWeb) return Future.value(null);
    return _downloader.checkLocalApk(
      downloadUrl: downloadUrl,
      versionName: versionName,
    );
  }

  // ─── Download & Install ───

  /// Download APK dan coba install. Termasuk cek file lokal + 3 lapis fallback.
  Future<AppUpdateDownloadResult> downloadAndInstall({
    required AppUpdateManifest manifest,
    void Function(int percent)? onProgress,
  }) {
    if (kIsWeb) {
      return Future.value(const AppUpdateDownloadResult(
        status: AppUpdateDownloadStatus.failedOther,
      ));
    }
    return _downloader.downloadAndInstall(
      downloadUrl: manifest.url,
      versionName: manifest.version,
      onProgress: onProgress,
    );
  }
}
