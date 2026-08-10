import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:awesome_dialog/awesome_dialog.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/update/update_checker.dart';
import '../../../core/update/update_service.dart';
import '../providers/auth_provider.dart';
import '../../../core/widgets/app_notifier.dart';
import '../../../core/utils/uppercase_formatter.dart';
import 'package:flutter/services.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  static const _pageBg = AppColors.surface;
  final _formKey = GlobalKey<FormState>();
  final _usernameCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final UpdateService _updateService = UpdateService.instance;
  bool _rememberMe = false;
  bool _obscure = true;
  String _appVersionLabel = 'Versi -';
  String _updateStatusLabel = 'Memeriksa pembaruan aplikasi...';
  Color _updateStatusColor = AppColors.textSecondary;

  @override
  void initState() {
    super.initState();
    _loadVersionAndUpdateStatus();
    _loadSavedCredentials();
  }

  Future<void> _loadSavedCredentials() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedUser = prefs.getString('saved_username');
      if (savedUser != null && savedUser.isNotEmpty) {
        if (mounted) {
          setState(() {
            _usernameCtrl.text = savedUser;
            _rememberMe = true;
          });
        }
      }
    } catch (_) {}
  }

  Future<void> _loadVersionAndUpdateStatus() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      if (mounted) {
        setState(() {
          _appVersionLabel =
              'Versi ${packageInfo.version} (build ${packageInfo.buildNumber})';
        });
      }
    } catch (_) {}

    try {
      // Gunakan cached result dari UpdateService jika sudah tersedia,
      // atau lakukan pengecekan baru (throttle berlaku secara global)
      final result = await _updateService.checkForUpdate();
      if (!mounted || result == null) return;

      setState(() {
        switch (result.status) {
          case AppUpdateStatus.updateAvailable:
            final latest = result.manifest;
            _updateStatusLabel = latest == null
                ? 'Update tersedia'
                : 'Update tersedia • Versi ${latest.version} (build ${latest.buildNumber})';
            _updateStatusColor = const Color(0xFFB45309);
            break;
          case AppUpdateStatus.failedCheck:
            _updateStatusLabel = 'Gagal memeriksa pembaruan';
            _updateStatusColor = AppColors.danger;
            break;
          case AppUpdateStatus.upToDate:
            _updateStatusLabel = 'Aplikasi sudah versi terbaru';
            _updateStatusColor = AppColors.textSecondary;
            break;
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _updateStatusLabel = 'Gagal memeriksa pembaruan';
        _updateStatusColor = AppColors.danger;
      });
    }
  }

  @override
  void dispose() {
    _usernameCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _showWelcomeDialog(String userName) async {
    final size = MediaQuery.of(context).size;
    final dialogWidth = size.width < 600
        ? size.width * 0.92
        : (size.width > 900 ? 380.0 : 340.0);

    return await AwesomeDialog(
      context: context,
      dialogType: DialogType.success,
      animType: AnimType.scale,
      title: 'Login Berhasil!',
      desc: 'Selamat Datang ${userName.toUpperCase()}',
      width: dialogWidth,
      autoHide: const Duration(seconds: 1),
      onDismissCallback: (dismissType) {
        Navigator.of(context).pushNamedAndRemoveUntil(
          AppRoutes.dashboard,
          (route) => false,
        );
      },
    ).show();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      await AppNotifier.showWarning(
          context, 'Lengkapi username dan password terlebih dahulu');
      return;
    }
    final auth = context.read<AuthProvider>();
    if (auth.loading) return;

    final ok = await auth.login(_usernameCtrl.text.trim().toUpperCase(), _passCtrl.text);
    if (ok && mounted) {
      try {
        final prefs = await SharedPreferences.getInstance();
        if (_rememberMe) {
          await prefs.setString('saved_username', _usernameCtrl.text.trim());
        } else {
          await prefs.remove('saved_username');
        }
      } catch (_) {}

      final userName = (auth.user?['user_nama'] as String?) ?? 'User';
      _showWelcomeDialog(userName);
    } else if (mounted) {
      final error = auth.error ?? 'Tidak dapat login saat ini';
      await AppNotifier.showError(context, error);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _pageBg,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: EdgeInsets.all(AppBreakpoints.isMobile(context) ? 20 : 28),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: AppBreakpoints.isDesktop(context)
                    ? 1040
                    : (AppBreakpoints.isTablet(context) ? 580 : double.infinity),
              ),
              child: AppBreakpoints.isDesktop(context)
                  ? _buildDesktopLayout(context)
                  : (AppBreakpoints.isTablet(context)
                      ? _buildTabletLayout(context)
                      : _buildMobileLayout(context)),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTabletLayout(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildHeroPanel(context, compact: true),
        const SizedBox(height: 16),
        _buildLoginCard(context),
        _buildFooterLink(),
      ],
    );
  }

  Widget _buildDesktopLayout(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: _buildHeroPanel(context, compact: false),
        ),
        const SizedBox(width: 24),
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildLoginCard(context),
              _buildFooterLink(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMobileLayout(BuildContext context) {
    return Column(
      children: [
        _buildHeroPanel(context, compact: true),
        Transform.translate(
          offset: const Offset(0, -22),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: _buildLoginCard(context),
          ),
        ),
        _buildFooterLink(),
      ],
    );
  }

  Widget _buildHeroPanel(BuildContext context, {required bool compact}) {
    return Container(
      width: double.infinity,
      padding:
          EdgeInsets.fromLTRB(24, compact ? 30 : 42, 24, compact ? 34 : 42),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(32),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: compact ? 56 : 64,
            child: Image.asset(
              'assets/images/logo.png',
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => const Icon(
                Icons.precision_manufacturing_rounded,
                color: Colors.white,
                size: 48,
              ),
            ),
          ),
          const SizedBox(height: 18),
          const Text(
            'PlanKP',
            style: TextStyle(
              fontSize: 36,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              letterSpacing: -1,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoginCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.8)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.025),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Login',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: AppSpacing.md),
            _buildInputField(
              controller: _usernameCtrl,
              label: 'Username',
              icon: Icons.alternate_email_rounded,
              textCapitalization: TextCapitalization.characters,
              inputFormatters: [UpperCaseTextFormatter()],
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? 'Username wajib diisi'
                  : null,
            ),
            const SizedBox(height: AppSpacing.sm),
            _buildInputField(
              controller: _passCtrl,
              label: 'Password',
              icon: Icons.lock_outline_rounded,
              isPassword: true,
              obscure: _obscure,
              onToggle: () => setState(() => _obscure = !_obscure),
              validator: (v) =>
                  (v == null || v.isEmpty) ? 'Password wajib diisi' : null,
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                SizedBox(
                  height: 20,
                  width: 20,
                  child: Checkbox(
                    value: _rememberMe,
                    onChanged: (val) {
                      setState(() {
                        _rememberMe = val ?? false;
                      });
                    },
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4),
                    ),
                    activeColor: AppColors.primary,
                    side: const BorderSide(color: AppColors.border, width: 1.5),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _rememberMe = !_rememberMe;
                    });
                  },
                  child: Text(
                    'Ingat saya',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Consumer<AuthProvider>(
              builder: (_, auth, __) => ElevatedButton(
                onPressed: auth.loading ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.white,
                  minimumSize: const Size(double.infinity, 44),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.md)),
                  elevation: 0,
                ),
                child: auth.loading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Text(
                        'Masuk',
                        style: TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 14),
                      ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              '$_appVersionLabel • $_updateStatusLabel',
              style: TextStyle(
                color: _updateStatusColor,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool isPassword = false,
    bool obscure = false,
    VoidCallback? onToggle,
    TextCapitalization textCapitalization = TextCapitalization.none,
    List<TextInputFormatter>? inputFormatters,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscure,
      validator: validator,
      textCapitalization: textCapitalization,
      inputFormatters: inputFormatters,
      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w500,
            fontSize: 12),
        prefixIcon: Icon(icon, color: AppColors.textSecondary, size: 18),
        suffixIcon: isPassword
            ? IconButton(
                icon: Icon(obscure
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined),
                onPressed: onToggle,
                iconSize: 18,
                color: AppColors.textSecondary,
              )
            : null,
        filled: true,
        fillColor: AppColors.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
        contentPadding:
            const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
      ),
    );
  }

  Widget _buildFooterLink() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          'Belum punya akun?',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        TextButton(
          onPressed: () => Navigator.pushNamed(context, AppRoutes.register),
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            visualDensity: VisualDensity.compact,
          ),
          child: const Text(
            'Daftar',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 13,
              color: AppColors.primary,
            ),
          ),
        ),
      ],
    );
  }
}
