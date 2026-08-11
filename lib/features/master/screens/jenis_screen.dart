import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../auth/providers/auth_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_notifier.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/shimmer_loading.dart';
import '../models/jenis_model.dart';
import '../providers/master_provider.dart';
import '../../../core/utils/responsive_sheet.dart';

class JenisScreen extends StatefulWidget {
  const JenisScreen({super.key});

  @override
  State<JenisScreen> createState() => _JenisScreenState();
}

class _JenisScreenState extends State<JenisScreen> {
  static const _kPageBg = AppColors.surface;
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<MasterProvider>().fetchJenis();
    });
  }

  void _openForm([JenisModel? jenis]) {
    showResponsiveSheet(
      context,
      maxDesktopWidth: 520,
      builder: (_) => _JenisForm(jenis: jenis),
    );
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kPageBg,
      appBar: AppBar(title: const Text('Jenis')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openForm(),
        tooltip: 'Tambah Jenis',
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.white,
        child: const Icon(Icons.add),
      ),
      body: Consumer<MasterProvider>(
        builder: (_, p, __) {
          final query = _searchCtrl.text.trim().toLowerCase();
          final filtered = query.isEmpty
              ? p.jenisMaster
              : p.jenisMaster.where((j) {
                  final nama = j.jenisNama.toLowerCase();
                  final kategori = j.jenisKategori.toLowerCase();
                  return nama.contains(query) || kategori.contains(query);
                }).toList();

          return LayoutBuilder(
            builder: (_, constraints) {
              final maxWidth = AppBreakpoints.responsiveValue(
                context,
                mobile: constraints.maxWidth,
                tablet: constraints.maxWidth > 880 ? 860.0 : constraints.maxWidth,
                desktop: 1180.0,
              );
              return Align(
                alignment: Alignment.topCenter,
                child: SizedBox(
                  width: maxWidth,
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(AppRadius.md),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.02),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: TextField(
                            controller: _searchCtrl,
                            style: const TextStyle(fontSize: 12.5),
                            decoration: InputDecoration(
                              hintText: 'Cari Nama Jenis...',
                              prefixIcon: const Icon(Icons.search, size: 18, color: AppColors.textSecondary),
                              suffixIcon: _searchCtrl.text.isNotEmpty
                                  ? IconButton(
                                      icon: const Icon(Icons.clear, size: 18, color: AppColors.textSecondary),
                                      onPressed: () {
                                        _searchCtrl.clear();
                                        setState(() {});
                                      },
                                    )
                                  : null,
                              filled: true,
                              fillColor: Colors.white,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(AppRadius.md),
                                borderSide: const BorderSide(color: AppColors.border),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(AppRadius.md),
                                borderSide: const BorderSide(color: AppColors.border),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(AppRadius.md),
                                borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
                              ),
                            ),
                            onChanged: (_) => setState(() {}),
                          ),
                        ),
                      ),
                      if (!p.loading && filtered.isNotEmpty)
                        Container(
                          color: const Color(0xFFF8FAFC),
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                          child: Row(
                            children: [
                              Text(
                                '${filtered.length} jenis',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                              if (_searchCtrl.text.isNotEmpty)
                                const Text(
                                  ' · hasil pencarian',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      Expanded(
                        child: () {
                          if (p.loading) {
                            final isMobile = AppBreakpoints.isMobile(context);
                            if (isMobile) {
                              return const AppShimmer(
                                child: SingleChildScrollView(
                                  physics: NeverScrollableScrollPhysics(),
                                  padding: EdgeInsets.symmetric(horizontal: 16),
                                  child: Column(
                                    children: [
                                      AppSkeletonListCard(),
                                      AppSkeletonListCard(),
                                      AppSkeletonListCard(),
                                      AppSkeletonListCard(),
                                    ],
                                  ),
                                ),
                              );
                            } else {
                              final columns = AppBreakpoints.gridColumns(
                                context,
                                mobile: 1,
                                tablet: 2,
                                desktop: 3,
                              );
                              return AppShimmer(
                                child: GridView.builder(
                                  physics: const NeverScrollableScrollPhysics(),
                                  padding: const EdgeInsets.fromLTRB(0, 12, 0, 80),
                                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: columns,
                                    mainAxisSpacing: 12,
                                    crossAxisSpacing: 12,
                                    mainAxisExtent: 115,
                                  ),
                                  itemCount: 6,
                                  itemBuilder: (_, __) => const AppSkeletonListCard(),
                                ),
                              );
                            }
                          }
                          if (p.jenisMaster.isEmpty) {
                            return EmptyState(
                              message: 'Belum ada master jenis',
                              actionLabel: 'Tambah',
                              onAction: () => _openForm(),
                            );
                          }
                          if (filtered.isEmpty) {
                            return const EmptyState(
                              message: 'Data jenis tidak ditemukan',
                            );
                          }

                          final isMobile = AppBreakpoints.isMobile(context);
                          if (isMobile) {
                            return ListView.separated(
                              physics: const BouncingScrollPhysics(),
                              padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
                              itemCount: filtered.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: 12),
                              itemBuilder: (_, i) {
                                final jenis = filtered[i];
                                return _JenisCard(
                                  jenis: jenis,
                                  onEdit: () => _openForm(jenis),
                                );
                              },
                            );
                          }

                          final columns = AppBreakpoints.gridColumns(
                            context,
                            mobile: 1,
                            tablet: 2,
                            desktop: 3,
                          );
                          return GridView.builder(
                            physics: const BouncingScrollPhysics(),
                            padding: const EdgeInsets.fromLTRB(0, 12, 0, 80),
                            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: columns,
                              mainAxisSpacing: 12,
                              crossAxisSpacing: 12,
                              mainAxisExtent: 115,
                            ),
                            itemCount: filtered.length,
                            itemBuilder: (_, i) {
                              final jenis = filtered[i];
                              return _JenisCard(
                                jenis: jenis,
                                onEdit: () => _openForm(jenis),
                              );
                            },
                          );
                        }(),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _JenisCard extends StatelessWidget {
  final JenisModel jenis;
  final VoidCallback onEdit;

  const _JenisCard({
    required this.jenis,
    required this.onEdit,
  });

  Widget _buildDivisiBadge(String kategori) {
    final divisiColor = AppDivisiColors.getColor(kategori);
    final divisiIcon = AppDivisiColors.getIcon(kategori);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: divisiColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(divisiIcon, size: 11, color: divisiColor),
          const SizedBox(width: 4),
          Text(
            kategori.toUpperCase(),
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: divisiColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGapBadge(int gapHari) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.textSecondary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        'Gap ${gapHari}h',
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: AppColors.textSecondary,
        ),
      ),
    );
  }

  Widget _buildStatusBadge(bool isActive, Color activeColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: activeColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        isActive ? 'Aktif' : 'Nonaktif',
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: activeColor,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isInactive = !jenis.jenisIsActive;
    final activeColor =
        jenis.jenisIsActive ? AppColors.success : AppColors.danger;
    final isMobile = AppBreakpoints.isMobile(context);

    Widget cardContent;

    if (isMobile) {
      cardContent = Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    jenis.jenisNama,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                      color: isInactive ? AppColors.textSecondary : AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  _buildDivisiBadge(jenis.jenisKategori),
                ],
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (jenis.jenisGapHari > 0) ...[
                  _buildGapBadge(jenis.jenisGapHari),
                  const SizedBox(width: 6),
                ],
                _buildStatusBadge(jenis.jenisIsActive, activeColor),
                const SizedBox(width: 8),
                IconButton(
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  icon: const Icon(Icons.edit_outlined, size: 18, color: AppColors.textSecondary),
                  onPressed: onEdit,
                ),
              ],
            ),
          ],
        ),
      );
    } else {
      cardContent = Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildDivisiBadge(jenis.jenisKategori),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (jenis.jenisGapHari > 0) ...[
                      _buildGapBadge(jenis.jenisGapHari),
                      const SizedBox(width: 6),
                    ],
                    _buildStatusBadge(jenis.jenisIsActive, activeColor),
                    const SizedBox(width: 6),
                    IconButton(
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      icon: const Icon(Icons.edit_outlined, size: 18, color: AppColors.textSecondary),
                      onPressed: onEdit,
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              jenis.jenisNama,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 15,
                color: isInactive ? AppColors.textSecondary : AppColors.textPrimary,
              ),
            ),
          ],
        ),
      );
    }

    if (isInactive) {
      cardContent = Opacity(opacity: 0.6, child: cardContent);
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.6)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onEdit,
          child: cardContent,
        ),
      ),
    );
  }
}

class _JenisForm extends StatefulWidget {
  final JenisModel? jenis;
  const _JenisForm({this.jenis});

  @override
  State<_JenisForm> createState() => _JenisFormState();
}

class _JenisFormState extends State<_JenisForm> {
  final _form = GlobalKey<FormState>();
  String _kategori = '';
  final _gapHariCtrl = TextEditingController(text: '0');

  // Edit mode: single field
  final _namaCtrl = TextEditingController();

  // Create mode: multiple fields
  final List<TextEditingController> _namaCtrls = [];

  bool get _isEdit => widget.jenis != null;

  @override
  void initState() {
    super.initState();
    if (_isEdit) {
      _namaCtrl.text = widget.jenis!.jenisNama;
      _kategori = widget.jenis!.jenisKategori;
      _gapHariCtrl.text = widget.jenis!.jenisGapHari.toString();
    } else {
      _namaCtrls.add(TextEditingController());
      final auth = context.read<AuthProvider>();
      final isManager = auth.user?['user_jabatan'] == 'manager';
      _kategori = isManager ? 'GA' : (auth.user?['user_divisi'] ?? '').toString();
      _gapHariCtrl.text = '0';
    }
  }

  @override
  void dispose() {
    _namaCtrl.dispose();
    _gapHariCtrl.dispose();
    for (final c in _namaCtrls) {
      c.dispose();
    }
    super.dispose();
  }

  void _addField() => setState(() => _namaCtrls.add(TextEditingController()));

  void _removeField(int index) {
    setState(() {
      _namaCtrls[index].dispose();
      _namaCtrls.removeAt(index);
    });
  }

  Future<void> _submit() async {
    final provider = context.read<MasterProvider>();
    final gapHari = int.tryParse(_gapHariCtrl.text.trim()) ?? -1;
    if (gapHari < 0) {
      await AppNotifier.showWarning(
          context, 'Gap hari wajib angka bulat minimal 0');
      return;
    }

    if (_isEdit) {
      if (!_form.currentState!.validate()) return;
      final ok = await provider.saveJenis(
        {
          'jenis_nama': _namaCtrl.text.trim(),
          'jenis_kategori': _kategori,
          'jenis_gap_hari': gapHari,
        },
        id: widget.jenis!.jenisId,
      );
      if (ok && mounted) {
        await AppNotifier.showSuccess(context, 'Jenis berhasil diperbarui');
        if (!mounted) return;
        Navigator.pop(context);
      } else if (mounted) {
        await AppNotifier.showError(
            context, provider.error ?? 'Gagal menyimpan jenis');
      }
      return;
    }

    // Create mode: submit all non-empty fields
    final valid = _namaCtrls.where((c) => c.text.trim().isNotEmpty).toList();
    if (valid.isEmpty) {
      await AppNotifier.showWarning(context, 'Isi minimal satu nama jenis');
      return;
    }
    int count = 0;
    for (final ctrl in valid) {
      final ok = await provider.saveJenis({
        'jenis_nama': ctrl.text.trim(),
        'jenis_kategori': _kategori,
        'jenis_gap_hari': gapHari,
      });
      if (ok) count++;
    }
    if (!mounted) return;
    if (count > 0) {
      await AppNotifier.showSuccess(
          context, '$count jenis berhasil ditambahkan');
      if (!mounted) return;
      Navigator.pop(context);
    } else {
      await AppNotifier.showError(
          context, provider.error ?? 'Gagal menyimpan jenis');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isManager =
        context.read<AuthProvider>().user?['user_jabatan'] == 'manager';
    final mediaQuery = MediaQuery.of(context);
    final bottomInset = mediaQuery.viewInsets.bottom;
    final bottomPadding = mediaQuery.padding.bottom;

    return AnimatedPadding(
      duration: const Duration(milliseconds: 150),
      curve: Curves.easeOut,
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        decoration: const BoxDecoration(
          color: Color(0xFFF8FAFC),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: EdgeInsets.fromLTRB(
            20, 12, 20, 32 + (bottomInset > 0 ? 0 : bottomPadding)),
        child: Form(
          key: _form,
          child: SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                    child: Container(
                  margin: const EdgeInsets.only(top: 8, bottom: 16),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2)),
                )),
                Row(
                  children: [
                    Text(_isEdit ? 'Edit Jenis' : 'Tambah Jenis',
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.w700)),
                    const Spacer(),
                    if (!isManager && _kategori.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(_kategori,
                            style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: AppColors.primary)),
                      ),
                  ],
                ),
                const SizedBox(height: 20),
                if (isManager) ...[
                  DropdownButtonFormField<String>(
                    value: _kategori.isEmpty ? 'GA' : _kategori,
                    style: const TextStyle(fontSize: 13, color: AppColors.textPrimary),
                    decoration: const InputDecoration(
                      labelText: 'Kategori Divisi',
                      prefixIcon: Icon(Icons.business_outlined),
                    ),
                    items: const [
                      DropdownMenuItem(
                          value: 'GA',
                          child: Text('GA',
                              style: TextStyle(
                                  fontSize: 13, color: AppColors.textPrimary))),
                      DropdownMenuItem(
                          value: 'IT',
                          child: Text('IT',
                              style: TextStyle(
                                  fontSize: 13, color: AppColors.textPrimary))),
                      DropdownMenuItem(
                          value: 'DRIVER',
                          child: Text('DRIVER',
                              style: TextStyle(
                                  fontSize: 13, color: AppColors.textPrimary))),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        setState(() {
                          _kategori = val;
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                ],
                if (_isEdit)
                  TextFormField(
                    controller: _namaCtrl,
                    autofocus: true,
                    decoration: const InputDecoration(
                      labelText: 'Nama Jenis',
                      prefixIcon: Icon(Icons.label_outlined),
                    ),
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Wajib diisi' : null,
                  )
                else ...[
                  ..._namaCtrls.asMap().entries.map((e) {
                    final i = e.key;
                    final ctrl = e.value;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: ctrl,
                              autofocus: i == 0,
                              textCapitalization: TextCapitalization.words,
                              decoration: InputDecoration(
                                hintText: 'Nama jenis ${i + 1}',
                                prefixIcon:
                                    const Icon(Icons.label_outlined, size: 20),
                                isDense: true,
                              ),
                            ),
                          ),
                          if (_namaCtrls.length > 1)
                            IconButton(
                              icon: const Icon(Icons.remove_circle_outline,
                                  color: Colors.red, size: 20),
                              onPressed: () => _removeField(i),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              visualDensity: VisualDensity.compact,
                            ),
                        ],
                      ),
                    );
                  }),
                  TextButton.icon(
                    onPressed: _addField,
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('Tambah baris'),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      padding: EdgeInsets.zero,
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.primarySoft,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
                  ),
                  child: const Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.info_outline, size: 16, color: AppColors.primary),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Atur gap waktu (hari) agar satu inventaris tidak dapat dimaintenance dalam periode yang berdekatan. '
                          'Contoh: isi 30 berarti setiap inventaris baru bisa dimaintenance lagi setelah 30 hari. '
                          'Isi 0 jika tidak ada pembatasan.',
                          style: TextStyle(fontSize: 12, color: AppColors.primary, height: 1.5),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _gapHariCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Gap Hari Realisasi per Inventaris',
                    hintText: '0',
                    helperText:
                        'Jarak waktu minimal (hari) sebelum satu mesin yang sama dapat diservis kembali.',
                    helperMaxLines: 2,
                    prefixIcon: Icon(Icons.calendar_today_outlined),
                  ),
                  validator: (v) {
                    final parsed = int.tryParse((v ?? '').trim());
                    if (parsed == null || parsed < 0) {
                      return 'Isi angka bulat minimal 0';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),
                Consumer<MasterProvider>(
                  builder: (_, p, __) => ElevatedButton(
                    onPressed: p.loading ? null : _submit,
                    child: p.loading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2))
                        : Text(_isEdit ? 'Simpan' : 'Tambah Semua'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
