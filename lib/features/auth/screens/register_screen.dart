import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/api_client.dart';
import '../providers/auth_provider.dart';
import '../../../core/widgets/app_notifier.dart';
import '../../../core/utils/uppercase_formatter.dart';
import 'package:flutter/services.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  static const _pageBg = AppColors.surface;
  final _formKey = GlobalKey<FormState>();
  final _namaCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _nikCtrl = TextEditingController();
  final _divisiCtrl = TextEditingController();
  final _divisiOptions = const [
    'GA',
    'IT',
    'Driver',
  ];
  String? _selectedCabang;
  List<Map<String, dynamic>> _pabrikList = [];
  bool _loadingPabrik = true;
  static const _defaultJabatan = 'user';
  bool _obscure = true;

  @override
  void initState() {
    super.initState();
    _loadPabrik();
  }

  Future<void> _loadPabrik() async {
    try {
      final res = await ApiClient.get(ApiConfig.pabrik, auth: false);
      if (mounted) {
        setState(() {
          _pabrikList = List<Map<String, dynamic>>.from(
              (res['data'] as List).map((e) => e as Map<String, dynamic>));
          _loadingPabrik = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loadingPabrik = false);
        AppNotifier.showError(context, 'Gagal memuat data cabang');
      }
    }
  }

  @override
  void dispose() {
    _namaCtrl.dispose();
    _passwordCtrl.dispose();
    _nikCtrl.dispose();
    _divisiCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      await AppNotifier.showWarning(
          context, 'Lengkapi data registrasi terlebih dahulu');
      return;
    }
    if (_selectedCabang == null) {
      await AppNotifier.showWarning(context, 'Pilih cabang terlebih dahulu');
      return;
    }
    final auth = context.read<AuthProvider>();
    if (auth.loading) return;
    final ok = await auth.register(
      userNama: _namaCtrl.text.trim().toUpperCase(),
      userPassword: _passwordCtrl.text,
      userDivisi: _divisiCtrl.text.trim(),
      userCabang: _selectedCabang!,
      userNik: _nikCtrl.text.trim(),
      userJabatan: _defaultJabatan,
    );
    if (ok && mounted) {
      await AppNotifier.showSuccess(context, 'Registrasi berhasil');
      if (!mounted) return;
      Navigator.pop(context);
    } else if (mounted) {
      final error = auth.error ?? 'Tidak dapat mendaftar saat ini';
      await AppNotifier.showError(context, error);
    }
  }

  void _backToLogin() {
    if (Navigator.canPop(context)) {
      Navigator.pop(context);
      return;
    }
    Navigator.pushReplacementNamed(context, AppRoutes.login);
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
                    : (AppBreakpoints.isTablet(context) ? 620 : double.infinity),
              ),
              child: AppBreakpoints.isDesktop(context)
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(child: _buildHeroPanel(compact: false)),
                        const SizedBox(width: 24),
                        Expanded(child: _buildFormCard()),
                      ],
                    )
                  : (AppBreakpoints.isTablet(context)
                      ? Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _buildHeroPanel(compact: true),
                            const SizedBox(height: 16),
                            _buildFormCard(),
                          ],
                        )
                      : Column(
                          children: [
                            _buildHeroPanel(compact: true),
                            Transform.translate(
                              offset: const Offset(0, -22),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 4),
                                child: _buildFormCard(),
                              ),
                            ),
                          ],
                        )),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeroPanel({required bool compact}) {
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
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.person_add_alt_1_rounded,
                color: Colors.white, size: 28),
          ),
          const SizedBox(height: 18),
          const Text(
            'Buat Akun',
            style: TextStyle(
              fontSize: 34,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              letterSpacing: -0.8,
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildFormCard() {
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
              'Registrasi',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: AppSpacing.md),
            _buildInputField(
              controller: _namaCtrl,
              label: 'Nama Lengkap',
              icon: Icons.person_outline_rounded,
              textCapitalization: TextCapitalization.characters,
              inputFormatters: [UpperCaseTextFormatter()],
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Nama wajib diisi' : null,
            ),
            const SizedBox(height: AppSpacing.sm),
            _buildInputField(
              controller: _nikCtrl,
              label: 'NIK',
              icon: Icons.badge_outlined,
              keyboardType: TextInputType.number,
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'NIK wajib diisi' : null,
            ),
            const SizedBox(height: AppSpacing.sm),
            _buildDropdownField<String>(
              label: 'Divisi',
              icon: Icons.account_tree_outlined,
              value: _divisiCtrl.text.isNotEmpty &&
                      _divisiOptions.contains(_divisiCtrl.text)
                  ? _divisiCtrl.text
                  : null,
              items: _divisiOptions
                  .map((opt) => DropdownMenuItem(value: opt, child: Text(opt)))
                  .toList(),
              onChanged: (val) {
                if (val != null) {
                  _divisiCtrl.text = val;
                }
              },
              validator: (v) =>
                  v == null || v.isEmpty ? 'Divisi wajib diisi' : null,
            ),
            const SizedBox(height: AppSpacing.sm),
            _loadingPabrik
                ? const SizedBox(
                    height: 44,
                    child: Center(
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  )
                : _buildDropdownField<String>(
                    label: 'Cabang',
                    icon: Icons.business_outlined,
                    value: _selectedCabang,
                    items: _pabrikList
                        .map((pab) => DropdownMenuItem<String>(
                              value: pab['pab_kode'] as String,
                              child: Text(pab['pab_nama'] as String),
                            ))
                        .toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setState(() => _selectedCabang = val);
                      }
                    },
                    validator: (v) => v == null ? 'Cabang wajib diisi' : null,
                  ),
            const SizedBox(height: AppSpacing.sm),
            _buildInputField(
              controller: _passwordCtrl,
              label: 'Password',
              icon: Icons.lock_outline_rounded,
              isPassword: true,
              obscure: _obscure,
              onToggle: () => setState(() => _obscure = !_obscure),
              validator: (v) => v == null || v.length <= 2
                  ? 'Password minimal 3 karakter'
                  : null,
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
                        'Daftar',
                        style: TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 14),
                      ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            _buildFooterLink(),
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
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscure,
      validator: validator,
      keyboardType: keyboardType,
      textCapitalization: textCapitalization,
      inputFormatters: inputFormatters,
      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w500, fontSize: 12),
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

  Widget _buildDropdownField<T>({
    required String label,
    required IconData icon,
    required T? value,
    required List<DropdownMenuItem<T>> items,
    required void Function(T?) onChanged,
    required String? Function(T?) validator,
  }) {
    return DropdownButtonFormField<T>(
      value: value,
      items: items,
      onChanged: onChanged,
      validator: validator,
      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w500, fontSize: 12),
        prefixIcon: Icon(icon, color: AppColors.textSecondary, size: 18),
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
          'Sudah punya akun?',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        TextButton(
          onPressed: _backToLogin,
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            visualDensity: VisualDensity.compact,
          ),
          child: const Text(
            'Masuk',
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
