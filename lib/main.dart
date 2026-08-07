// ignore_for_file: use_build_context_synchronously, unnecessary_cast

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:awesome_dialog/awesome_dialog.dart';
import 'package:provider/provider.dart';
import 'core/theme/app_theme.dart';
import 'core/constants/app_constants.dart';
import 'core/update/update_checker.dart';
import 'core/update/update_downloader.dart';
import 'core/update/update_service.dart';
import 'core/widgets/app_notifier.dart';
import 'features/auth/providers/auth_provider.dart';
import 'features/master/providers/master_provider.dart';
import 'features/jadwal/providers/jadwal_provider.dart';
import 'features/auth/screens/login_screen.dart';
import 'features/auth/screens/register_screen.dart';
import 'features/dashboard/screens/dashboard_screen.dart';
import 'features/jadwal/screens/jadwal_detail_screen.dart';
import 'features/jadwal/screens/realisasi_form_screen.dart';
import 'features/dashboard/screens/monitoring_divisi_screen.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const PlanKPApp());
}

class PlanKPApp extends StatelessWidget {
  const PlanKPApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => MasterProvider()),
        ChangeNotifierProvider(create: (_) => JadwalProvider()),
      ],
      child: MaterialApp(
        title: 'PlanKP',
        navigatorKey: navigatorKey,
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        builder: (context, child) => MainAppWrapper(child: child!),
        routes: {
          AppRoutes.login: (_) => const LoginScreen(),
          AppRoutes.register: (_) => const RegisterScreen(),
          AppRoutes.dashboard: (_) => const _ProtectedRoute(
                child: DashboardScreen(),
              ),
          AppRoutes.jadwalDetail: (ctx) {
            final rawArgs = ModalRoute.of(ctx)!.settings.arguments;
            final args = rawArgs is int ? rawArgs : int.tryParse('$rawArgs') ?? 0;
            return _ProtectedRoute(
              child: JadwalDetailScreen(jadwalId: args),
            );
          },
          AppRoutes.realisasiForm: (ctx) {
            final args =
                ModalRoute.of(ctx)!.settings.arguments as Map<String, dynamic>;
            return _ProtectedRoute(
              allowedRoles: const ['user', 'teknisi', 'it_support'],
              child: RealisasiFormScreen(args: args),
            );
          },
          AppRoutes.monitoringDivisi: (_) => const _ProtectedRoute(
                allowedRoles: ['manager'],
                child: MonitoringDivisiScreen(),
              ),
        },
        home: const _AuthGate(),
      ),
    );
  }
}

class _AuthGate extends StatefulWidget {
  const _AuthGate();

  @override
  State<_AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<_AuthGate> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final auth = context.read<AuthProvider>();
      await auth.checkSession();
      if (mounted) {
        Navigator.pushReplacementNamed(
          context,
          auth.isLoggedIn ? AppRoutes.dashboard : AppRoutes.login,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}

class MainAppWrapper extends StatefulWidget {
  final Widget child;
  const MainAppWrapper({super.key, required this.child});

  @override
  State<MainAppWrapper> createState() => _MainAppWrapperState();
}

class _MainAppWrapperState extends State<MainAppWrapper> with WidgetsBindingObserver {
  final UpdateService _updateService = UpdateService.instance;
  bool _isChecking = false;
  bool _dialogOpen = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Pemicu 1: Cek saat startup pertama kali (delay 1.5s agar tidak bentrok dengan _AuthGate)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(const Duration(milliseconds: 1500), () {
        if (mounted) _triggerUpdateCheck();
      });
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Pemicu 2: Cek saat kembali dari background
    if (state == AppLifecycleState.resumed) {
      _triggerUpdateCheck();
    }
  }

  Future<void> _triggerUpdateCheck() async {
    if (_isChecking || _dialogOpen) return;
    _isChecking = true;

    try {
      // Throttle & skip sudah dihandle di dalam UpdateService
      final result = await _updateService.checkForUpdate();
      if (mounted &&
          result != null &&
          result.hasUpdate &&
          result.manifest != null) {
        _dialogOpen = true;
        await _showUpdateDialog(result.manifest!);
        _dialogOpen = false;
      }
    } catch (e) {
      debugPrint('[AutoUpdate] Error: $e');
    } finally {
      _isChecking = false;
    }
  }

  // ─── Dialog 1: Pemberitahuan Update Tersedia ───
  Future<void> _showUpdateDialog(AppUpdateManifest manifest) async {
    final context = navigatorKey.currentContext;
    if (context == null) return;

    await AwesomeDialog(
      context: context,
      dialogType: DialogType.info,
      animType: AnimType.scale,
      dismissOnTouchOutside: !manifest.mandatory,
      dismissOnBackKeyPress: !manifest.mandatory,
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Pembaruan Tersedia!',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Versi terbaru ${manifest.version} siap diunduh.',
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            if ((manifest.notes ?? '').trim().isNotEmpty) ...[
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: Text(
                  manifest.notes!.trim(),
                  style: const TextStyle(
                      fontSize: 13, color: AppColors.textPrimary),
                  textAlign: TextAlign.left,
                ),
              ),
            ],
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (!manifest.mandatory) ...[
                  Expanded(
                    child: AnimatedButton(
                      text: 'Nanti Saja',
                      color: Colors.grey.shade300,
                      pressEvent: () async {
                        // Simpan skip agar tidak ditanya lagi untuk versi ini
                        await _updateService.skipVersion(manifest.buildNumber);
                        if (context.mounted) Navigator.of(context).pop();
                      },
                      isFixedHeight: false,
                    ),
                  ),
                  const SizedBox(width: 10),
                ],
                Expanded(
                  child: AnimatedButton(
                    text: 'Update Sekarang',
                    color: AppColors.primary,
                    pressEvent: () {
                      Navigator.of(context).pop();
                      _startDownloadAndInstall(manifest);
                    },
                    isFixedHeight: false,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ).show();
  }

  // ─── Proses Download + Install (In-App) ───
  Future<void> _startDownloadAndInstall(AppUpdateManifest manifest) async {
    final context = navigatorKey.currentContext;
    if (context == null) return;

    // Cek dulu apakah file sudah ada di lokal
    final existingPath = await _updateService.checkLocalApk(
      downloadUrl: manifest.url,
      versionName: manifest.version,
    );

    if (existingPath != null && context.mounted) {
      // File sudah ada → tampilkan dialog "File ditemukan" lalu coba install
      _showLocalFileFoundDialog(manifest, existingPath);
      return;
    }

    // File belum ada → tampilkan dialog download progress
    if (context.mounted) {
      _showDownloadProgressDialog(manifest);
    }
  }

  // ─── Dialog 2: File APK Sudah Ada di Lokal ───
  void _showLocalFileFoundDialog(
      AppUpdateManifest manifest, String filePath) {
    final context = navigatorKey.currentContext;
    if (context == null) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.check_circle,
                    color: Colors.green.shade600, size: 40),
              ),
              const SizedBox(height: 16),
              const Text(
                'File Update Ditemukan!',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'File PlanKP-v${manifest.version}.apk sudah tersedia di penyimpanan Anda.',
                style: const TextStyle(
                    fontSize: 13, color: AppColors.textSecondary),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () async {
                        Navigator.of(ctx).pop();
                        try {
                          final f = File(filePath);
                          if (await f.exists()) await f.delete();
                        } catch (_) {}
                        // Download ulang dari awal
                        _showDownloadProgressDialog(manifest);
                      },
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: const Text('Unduh Ulang'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        Navigator.of(ctx).pop();
                        // Langsung coba install dari file lokal
                        final result =
                            await _updateService.downloadAndInstall(
                          manifest: manifest,
                        );
                        _handleInstallResult(result, manifest);
                      },
                      icon: const Icon(Icons.install_mobile, size: 18),
                      label: const Text('Pasang'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Dialog 3: Progress Download In-App ───
  void _showDownloadProgressDialog(AppUpdateManifest manifest) {
    final context = navigatorKey.currentContext;
    if (context == null) return;

    final progressNotifier = ValueNotifier<double>(0.0);
    bool isCancelled = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Mengunduh Pembaruan',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ValueListenableBuilder<double>(
                valueListenable: progressNotifier,
                builder: (context, percent, _) => Column(
                  children: [
                    LinearProgressIndicator(
                      value: percent > 0 ? percent : null,
                      backgroundColor: Colors.grey[200],
                      color: AppColors.primary,
                      minHeight: 8,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${(percent * 100).round()}%',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        isCancelled = true;
                        Navigator.of(ctx).pop();
                      },
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: const Text('Batalkan'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    // Mulai download
    _updateService
        .downloadAndInstall(
      manifest: manifest,
      onProgress: (percent) {
        if (!isCancelled) {
          progressNotifier.value = (percent / 100.0).clamp(0.0, 1.0);
        }
      },
    )
        .then((result) {
      // Tutup dialog progress jika masih terbuka
      final navContext = navigatorKey.currentContext;
      if (navContext != null && !isCancelled) {
        Navigator.of(navContext, rootNavigator: true).pop();
      }
      if (!isCancelled) {
        _handleInstallResult(result, manifest);
      }
    });
  }

  // ─── Handle Hasil Install ───
  void _handleInstallResult(
      AppUpdateDownloadResult result, AppUpdateManifest manifest) {
    switch (result.status) {
      case AppUpdateDownloadStatus.downloadedOpenedInstaller:
      case AppUpdateDownloadStatus.alreadyDownloaded:
        // Berhasil membuka installer — tidak perlu tindakan tambahan
        break;
      case AppUpdateDownloadStatus.openedBrowserFallback:
        // Fallback ke browser berhasil → tampilkan panduan manual
        _showManualInstallGuide(manifest.url, manifest.version);
        break;
      case AppUpdateDownloadStatus.downloadedOpenedFolder:
      case AppUpdateDownloadStatus.failedNetwork:
      case AppUpdateDownloadStatus.failedOther:
        // Gagal total → tampilkan panduan manual juga
        _showManualInstallGuide(manifest.url, manifest.version);
        break;
    }
  }

  // ─── Dialog 4: Panduan Install Manual (Fallback Terakhir) ───
  void _showManualInstallGuide(String downloadUrl, String versionName) {
    final context = navigatorKey.currentContext;
    if (context == null) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.download_for_offline,
                      color: AppColors.primary, size: 30),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Panduan Pemasangan',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Text(
                'File APK sedang diunduh oleh browser. Ikuti langkah berikut untuk memasang pembaruan:',
                style:
                    TextStyle(fontSize: 13, color: AppColors.textPrimary),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildStepRow('1',
                        'Tunggu unduhan selesai di bar notifikasi browser Anda.'),
                    const SizedBox(height: 6),
                    _buildStepRow('2',
                        'Buka aplikasi File Manager / File Saya di HP Anda.'),
                    const SizedBox(height: 6),
                    _buildStepRow(
                        '3', 'Masuk ke folder Downloads / Unduhan.'),
                    const SizedBox(height: 6),
                    _buildStepRow('4',
                        'Cari dan klik file APK PlanKP untuk memasangnya.'),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.support_agent_rounded,
                              size: 18, color: AppColors.primary),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Mengalami kendala install? Silakan hubungi IT Support.',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        await Clipboard.setData(
                            ClipboardData(text: downloadUrl));
                        if (ctx.mounted) {
                          AppNotifier.showSuccess(
                              ctx, 'Link unduhan disalin ke clipboard');
                        }
                      },
                      icon: const Icon(Icons.copy, size: 16),
                      label: const Text('Salin Link'),
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: const Text('Tutup'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStepRow(String num, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 18,
          height: 18,
          margin: const EdgeInsets.only(top: 2, right: 8),
          decoration: const BoxDecoration(
            color: Colors.blueAccent,
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: Text(
            num,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.bold),
          ),
        ),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(fontSize: 12, color: Colors.black87),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}

class _ProtectedRoute extends StatelessWidget {
  final Widget child;
  final List<String>? allowedRoles;

  const _ProtectedRoute({
    required this.child,
    this.allowedRoles,
  });

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    if (auth.isLoggedIn) {
      final role = auth.jabatan.toLowerCase();
      final isRoleAllowed = allowedRoles == null ||
          allowedRoles!.map((r) => r.toLowerCase()).contains(role);
      if (isRoleAllowed) return child;

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!context.mounted) return;
        Navigator.pushReplacementNamed(context, AppRoutes.dashboard);
      });

      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!context.mounted) return;
      Navigator.pushReplacementNamed(context, AppRoutes.login);
    });

    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}
