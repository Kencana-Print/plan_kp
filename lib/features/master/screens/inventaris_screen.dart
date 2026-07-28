// ignore_for_file: deprecated_member_use

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_notifier.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/shimmer_loading.dart';
import '../models/inventaris_model.dart';
import '../models/jenis_model.dart';
import '../providers/master_provider.dart';
import '../widgets/jenis_lookup_sheet.dart';

class InventarisScreen extends StatefulWidget {
  const InventarisScreen({super.key});
  @override
  State<InventarisScreen> createState() => _InventarisScreenState();
}

class _InventarisScreenState extends State<InventarisScreen> {
  static const _kPageBg = AppColors.surface;
  final _search = TextEditingController();
  final Set<int> _expandedJenisIds = <int>{};
  Timer? _searchDebounce;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
        (_) => context.read<MasterProvider>().fetchInventaris());
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 280), () {
      if (!mounted) return;
      context
          .read<MasterProvider>()
          .fetchInventaris(q: value.trim().isEmpty ? null : value.trim());
    });
  }

  Future<void> _openForm([InventarisModel? item, int? initialJenisId]) async {
    final provider = context.read<MasterProvider>();
    await provider.fetchJenis(showLoading: false);
    await provider.fetchJenisWithInventaris(showLoading: false);
    await provider.fetchPabrik();
    if (!mounted) return;

    if (item == null && initialJenisId == null) {
      final availableJenis = provider.jenisAvailableForInventaris();
      if (availableJenis.isEmpty) {
        await AppNotifier.showWarning(
          context,
          'Semua jenis sudah memiliki inventaris.\nKlik tombol Tambah untuk menambah inventaris.',
        );
        return;
      }
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: const BoxDecoration(
          color: _kPageBg,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: _InventarisForm(item: item, initialJenisId: initialJenisId),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kPageBg,
      appBar: AppBar(title: const Text('Inventaris')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openForm(),
        tooltip: 'Tambah Inventaris',
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.white,
        child: const Icon(Icons.add),
      ),
      body: Consumer<MasterProvider>(
        builder: (_, p, __) {
          return LayoutBuilder(
            builder: (context, constraints) {
              final maxContentWidth = constraints.maxWidth > 1024
                  ? 980.0
                  : constraints.maxWidth > 760
                      ? 760.0
                      : constraints.maxWidth;

              return Align(
                alignment: Alignment.topCenter,
                child: SizedBox(
                  width: maxContentWidth,
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
                            controller: _search,
                            style: const TextStyle(fontSize: 12.5),
                            decoration: InputDecoration(
                              hintText: 'Cari nama inventaris...',
                              prefixIcon: const Icon(Icons.search,
                                  size: 18, color: AppColors.textSecondary),
                              suffixIcon: _search.text.isNotEmpty
                                  ? IconButton(
                                      icon: const Icon(Icons.clear,
                                          size: 18,
                                          color: AppColors.textSecondary),
                                      onPressed: () {
                                        _search.clear();
                                        _onSearchChanged('');
                                        setState(() {});
                                      },
                                    )
                                  : null,
                              filled: true,
                              fillColor: Colors.white,
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 8),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(AppRadius.md),
                                borderSide:
                                    const BorderSide(color: AppColors.border),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(AppRadius.md),
                                borderSide:
                                    const BorderSide(color: AppColors.border),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(AppRadius.md),
                                borderSide: const BorderSide(
                                    color: AppColors.primary, width: 1.5),
                              ),
                            ),
                            onChanged: (val) {
                              _onSearchChanged(val);
                              setState(() {});
                            },
                          ),
                        ),
                      ),
                      if (!p.loading && p.inventarisList.isNotEmpty)
                        Container(
                          color: const Color(0xFFF8FAFC),
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                          child: Row(children: [
                            Text(
                              '${p.inventarisList.map((e) => e.invJenisId).toSet().length} jenis · ${p.inventarisList.length} inventaris',
                              style: const TextStyle(
                                  fontSize: 12, color: AppColors.textSecondary),
                            ),
                            if (_search.text.isNotEmpty)
                              const Text(' · hasil pencarian',
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: AppColors.textSecondary)),
                          ]),
                        ),
                      Expanded(
                        child: () {
                          if (p.loading) {
                            return const AppShimmer(
                              child: SingleChildScrollView(
                                physics: NeverScrollableScrollPhysics(),
                                padding: EdgeInsets.only(top: 8),
                                child: Column(
                                  children: [
                                    AppSkeletonFolderCard(),
                                    AppSkeletonFolderCard(),
                                    AppSkeletonFolderCard(),
                                  ],
                                ),
                              ),
                            );
                          }
                          if (p.inventarisList.isEmpty) {
                            return EmptyState(
                              message: 'Belum ada data inventaris',
                              actionLabel: 'Tambah',
                              onAction: () => _openForm(),
                            );
                          }
                          final grouped = <int, List<InventarisModel>>{};
                          for (final item in p.inventarisList) {
                            grouped
                                .putIfAbsent(
                                    item.invJenisId, () => <InventarisModel>[])
                                .add(item);
                          }
                          final jenisIds = grouped.keys.toList()..sort();

                          return ListView.separated(
                            physics: const BouncingScrollPhysics(),
                            padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
                            itemCount: jenisIds.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 12),
                            itemBuilder: (_, i) {
                              final jenisId = jenisIds[i];
                              final items = grouped[jenisId]!;
                              final firstItem = items.first;
                              final jenisNama =
                                  p.jenisById(jenisId)?.jenisNama ??
                                      'Jenis #$jenisId';
                              final kategoriLabel =
                                  p.kategoriByJenisId(jenisId) ??
                                      firstItem.invKategori;
                              final expanded =
                                  _expandedJenisIds.contains(jenisId);

                              return _InventarisGroupCard(
                                jenisId: jenisId,
                                jenisNama: jenisNama,
                                kategoriLabel: kategoriLabel,
                                items: items,
                                expanded: expanded,
                                onToggle: () {
                                  setState(() {
                                    if (expanded) {
                                      _expandedJenisIds.remove(jenisId);
                                    } else {
                                      _expandedJenisIds.add(jenisId);
                                    }
                                  });
                                },
                                pabrikLabelBuilder: p.displayPabrik,
                                onEditItem: _openForm,
                                onAddItem: (jId) => _openForm(null, jId),
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

class _InventarisGroupCard extends StatefulWidget {
  final int jenisId;
  final String jenisNama;
  final String kategoriLabel;
  final List<InventarisModel> items;
  final bool expanded;
  final VoidCallback onToggle;
  final String Function(String?) pabrikLabelBuilder;
  final ValueChanged<InventarisModel> onEditItem;
  final ValueChanged<int> onAddItem;

  const _InventarisGroupCard({
    required this.jenisId,
    required this.jenisNama,
    required this.kategoriLabel,
    required this.items,
    required this.expanded,
    required this.onToggle,
    required this.pabrikLabelBuilder,
    required this.onEditItem,
    required this.onAddItem,
  });

  @override
  State<_InventarisGroupCard> createState() => _InventarisGroupCardState();
}

class _InventarisGroupCardState extends State<_InventarisGroupCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _iconTurns;

  static final Animatable<double> _iconTurnTween =
      Tween<double>(begin: 0.0, end: 0.5)
          .chain(CurveTween(curve: Curves.easeIn));

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _iconTurns = _controller.drive(_iconTurnTween);
    if (widget.expanded) _controller.value = 1.0;
  }

  @override
  void didUpdateWidget(_InventarisGroupCard old) {
    super.didUpdateWidget(old);
    if (old.expanded != widget.expanded) {
      widget.expanded ? _controller.forward() : _controller.reverse();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.6)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: widget.onToggle,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.jenisNama,
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          widget.kategoriLabel,
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.primarySoft,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '${widget.items.length}',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  IconButton(
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: () => widget.onAddItem(widget.jenisId),
                    icon: const Icon(Icons.add_circle_outline, size: 20, color: AppColors.primary),
                  ),
                  const SizedBox(width: 4),
                  RotationTransition(
                    turns: _iconTurns,
                    child: const Icon(
                      Icons.expand_more_rounded,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
          ClipRect(
            child: AnimatedSize(
              duration: const Duration(milliseconds: 240),
              curve: Curves.easeOutCubic,
              alignment: Alignment.topCenter,
              child: widget.expanded
                  ? Column(
                      children: [
                        const Divider(height: 1, color: AppColors.border),
                        ...widget.items.map(
                          (item) => _InventarisCard(
                            item: item,
                            pabrikLabel:
                                widget.pabrikLabelBuilder(item.invPabrikKode),
                            onEdit: () => widget.onEditItem(item),
                          ),
                        ),
                        const SizedBox(height: 8),
                      ],
                    )
                  : const SizedBox.shrink(),
            ),
          ),
        ],
      ),
    );
  }
}

class _InventarisCard extends StatelessWidget {
  final InventarisModel item;
  final String pabrikLabel;
  final VoidCallback onEdit;
  const _InventarisCard({
    required this.item,
    required this.pabrikLabel,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final merkRaw = item.invMerk?.trim() ?? '';
    final picRaw = item.invPic?.trim() ?? '';
    final merk = merkRaw.isEmpty ? '-' : merkRaw;
    final pic = picRaw.isEmpty ? '-' : picRaw;

    final isInactive = !item.invIsActive;

    Widget row = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Nama inventaris — menonjol
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        item.invNama,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13.5,
                          color: isInactive
                              ? AppColors.textSecondary
                              : AppColors.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (isInactive) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.danger.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'nonaktif',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: AppColors.danger,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  'No: ${item.invNo}${item.invPabrikKode != null ? ' · $pabrikLabel' : ''}',
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  '$merk · PIC: $pic',
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          // Kondisi badge
          _KondisiBadge(kondisi: item.invKondisi),
          const SizedBox(width: 6),
          IconButton(
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            icon: const Icon(Icons.edit_outlined, size: 16, color: AppColors.textSecondary),
            onPressed: onEdit,
          ),
        ],
      ),
    );

    if (isInactive) {
      return Opacity(opacity: 0.6, child: row);
    }
    return row;
  }
}

class _KondisiBadge extends StatelessWidget {
  final String kondisi;
  const _KondisiBadge({required this.kondisi});

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color fg;
    String label;

    if (kondisi.contains('Rusak')) {
      bg = AppColors.danger.withValues(alpha: 0.08);
      fg = AppColors.danger;
      label = 'Rusak';
    } else if (kondisi.contains('Perhatian')) {
      bg = AppColors.warning.withValues(alpha: 0.08);
      fg = AppColors.warning;
      label = 'Perhatian';
    } else if (kondisi.contains('Jarang')) {
      bg = AppColors.success.withValues(alpha: 0.08);
      fg = AppColors.success;
      label = 'Jarang';
    } else {
      bg = AppColors.success.withValues(alpha: 0.08);
      fg = AppColors.success;
      label = 'Baik';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(label,
          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: fg)),
    );
  }
}

// ── Form tambah / edit ──────────────────────────────────────────
class _InventarisForm extends StatefulWidget {
  final InventarisModel? item;
  final int? initialJenisId;
  const _InventarisForm({this.item, this.initialJenisId});
  @override
  State<_InventarisForm> createState() => _InventarisFormState();
}

class _InventarisFormState extends State<_InventarisForm> {
  final _form = GlobalKey<FormState>();
  final _noCtrl = TextEditingController();
  final _namaCtrl = TextEditingController();
  final _jenisCtrl = TextEditingController();
  int? _jenisId;
  String? _pabrikKode;
  final _merkCtrl = TextEditingController();
  final _snCtrl = TextEditingController();
  final _picCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  String _kategori = '';
  String _kondisi = 'Baik (Sering digunakan)';
  bool _isActive = true;

  static const _kondisiList = [
    'Baik (Sering digunakan)',
    'Baik (Jarang digunakan)',
    'Perlu Perhatian',
    'Rusak'
  ];

  bool get _isCreateMode => widget.item == null;

  @override
  void initState() {
    super.initState();
    final d = widget.item;
    if (d != null) {
      _noCtrl.text = d.invNo;
      _namaCtrl.text = d.invNama;
      _jenisId = d.invJenisId;
      final jenis = context.read<MasterProvider>().jenisById(d.invJenisId);
      _jenisCtrl.text = jenis?.jenisNama ?? 'ID ${d.invJenisId}';
      _pabrikKode = d.invPabrikKode;
      _merkCtrl.text = d.invMerk ?? '';
      _snCtrl.text = d.invSerialNumber ?? '';
      _picCtrl.text = d.invPic ?? '';
      _notesCtrl.text = d.invNotes ?? '';
      final mappedKategori =
          context.read<MasterProvider>().kategoriByJenisId(d.invJenisId);
      _kategori = (mappedKategori ?? d.invKategori).trim();
      _kondisi = d.invKondisi;
      _isActive = d.invIsActive;
    } else if (widget.initialJenisId != null) {
      final jenis =
          context.read<MasterProvider>().jenisById(widget.initialJenisId!);
      if (jenis != null) {
        _jenisId = jenis.jenisId;
        _jenisCtrl.text = jenis.jenisNama;
        _kategori = jenis.jenisKategori.trim();
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _jenisId == null) return;
        _autoGenerateNoNamaForJenis(_jenisId!);
      });
    }
  }

  Future<void> _autoGenerateNoNamaForJenis(int jenisId) async {
    if (!_isCreateMode) return;
    final provider = context.read<MasterProvider>();
    await provider.fetchInventaris(
      jenis: '$jenisId',
      showLoading: false,
      updateKategoriMap: false,
    );
    if (!mounted) return;

    final items = provider.inventarisList
        .where((e) => e.invJenisId == jenisId)
        .toList(growable: false);


    int maxNoNumber = 0;
    int noWidth = 3;
    String noPrefix = '';
    int maxNamaNumber = 0;
    String namaPrefix = '';

    final noPattern = RegExp(r'^(.*?)(\d+)$');
    final namaPattern = RegExp(r'^(.*?)(\d+)$');

    for (final item in items) {
      final no = item.invNo.trim();
      final noMatch = noPattern.firstMatch(no);
      if (noMatch != null) {
        final prefix = noMatch.group(1) ?? '';
        final numberRaw = noMatch.group(2) ?? '';
        final n = int.tryParse(numberRaw) ?? 0;
        if (n >= maxNoNumber) {
          maxNoNumber = n;
          noPrefix = prefix;
          noWidth = numberRaw.length > noWidth ? numberRaw.length : noWidth;
        }
      }

      final nama = item.invNama.trim();
      final namaMatch = namaPattern.firstMatch(nama);
      if (namaMatch != null) {
        final prefix = (namaMatch.group(1) ?? '').trimRight();
        final n = int.tryParse(namaMatch.group(2) ?? '') ?? 0;
        if (n >= maxNamaNumber) {
          maxNamaNumber = n;
          namaPrefix = prefix;
        }
      } else if (namaPrefix.isEmpty && nama.isNotEmpty) {
        namaPrefix = nama;
      }
    }

    final jenisNama = _jenisCtrl.text.trim();
    if (noPrefix.isEmpty) {
      final fallbackBase =
          _namaCtrl.text.trim().isNotEmpty ? _namaCtrl.text.trim() : jenisNama;
      final normalized = fallbackBase
          .toUpperCase()
          .replaceAll(RegExp(r'[^A-Z0-9]+'), '_')
          .replaceAll(RegExp(r'_+'), '_')
          .replaceAll(RegExp(r'^_|_$'), '');
      noPrefix = normalized.isEmpty ? 'INV_' : '${normalized}_';
    }
    if (namaPrefix.isEmpty) {
      namaPrefix = jenisNama.isEmpty ? 'Inventaris' : jenisNama;
    }

    final nextNo = maxNoNumber + 1;
    final nextNama = maxNamaNumber + 1;

    setState(() {
      _noCtrl.text = '$noPrefix${nextNo.toString().padLeft(noWidth, '0')}';
      _namaCtrl.text = maxNamaNumber > 0 ? '$namaPrefix $nextNama' : namaPrefix;
    });
  }

  @override
  void dispose() {
    _noCtrl.dispose();
    _namaCtrl.dispose();
    _jenisCtrl.dispose();
    _merkCtrl.dispose();
    _snCtrl.dispose();
    _picCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) {
      await AppNotifier.showWarning(context, 'Lengkapi data inventaris dahulu');
      return;
    }
    if (_jenisId == null) {
      await AppNotifier.showWarning(context, 'Jenis inventaris wajib dipilih');
      return;
    }
    final master = context.read<MasterProvider>();
    if (!master.isJenisActive(_jenisId!)) {
      await AppNotifier.showWarning(
        context,
        'Jenis inventaris nonaktif. Pilih jenis yang aktif.',
      );
      return;
    }
    if (_kategori.trim().isEmpty) {
      await AppNotifier.showWarning(
          context, 'Kategori otomatis belum terdeteksi dari jenis inventaris');
      return;
    }
    final p = context.read<MasterProvider>();
    final isEdit = widget.item != null;
    final body = {
      'inv_no': _noCtrl.text.trim(),
      'inv_nama': _namaCtrl.text.trim(),
      'inv_jenis_id': _jenisId,
      'inv_pabrik_kode': _pabrikKode,
      'inv_merk': _merkCtrl.text.trim().isEmpty ? null : _merkCtrl.text.trim(),
      'inv_serial_number':
          _snCtrl.text.trim().isEmpty ? null : _snCtrl.text.trim(),
      'inv_pic': _picCtrl.text.trim().isEmpty ? null : _picCtrl.text.trim(),
      'inv_kondisi': _kondisi,
      'inv_notes':
          _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
      'inv_is_active': _isActive ? 1 : 0,
    };
    final ok = await p.saveInventaris(body, id: widget.item?.invId);
    if (ok && mounted) {
      await AppNotifier.showSuccess(
          context,
          isEdit
              ? 'Inventaris berhasil diperbarui'
              : 'Inventaris berhasil ditambahkan');
      if (!mounted) return;
      Navigator.pop(context);
    } else if (mounted) {
      await AppNotifier.showError(
          context, p.error ?? 'Gagal menyimpan data inventaris');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.item != null;
    final master = context.watch<MasterProvider>();
    final pabrikCodes = master.pabrikList.map((e) => e.pabKode).toSet();
    final safePabrikKode =
        (_pabrikKode != null && pabrikCodes.contains(_pabrikKode))
            ? _pabrikKode
            : null;
    final safeKondisi =
        _kondisiList.contains(_kondisi) ? _kondisi : _kondisiList.first;
    return DraggableScrollableSheet(
      initialChildSize: 0.92,
      maxChildSize: 0.95,
      minChildSize: 0.5,
      builder: (_, ctrl) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFFF8FAFC),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Form(
          key: _form,
          child: ListView(
              controller: ctrl,
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
              children: [
                Center(
                    child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                            color: Colors.grey[300],
                            borderRadius: BorderRadius.circular(2)))),
                const SizedBox(height: 16),
                Text(isEdit ? 'Edit Inventaris' : 'Tambah Inventaris',
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w700)),
                const SizedBox(height: 20),

                // 1. No. Inventaris / Penjelasan Auto Generate paling atas
                if (_isCreateMode && _jenisId == null)
                  Container(
                    margin: const EdgeInsets.only(bottom: 14),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: AppColors.primary.withValues(alpha: 0.25),
                      ),
                    ),
                    child: const Row(
                      children: [
                        Icon(
                          Icons.auto_awesome_rounded,
                          color: AppColors.primary,
                          size: 20,
                        ),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'No. Inventaris Generate Otomatis',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w500,
                              height: 1.3,
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  Container(
                    margin: const EdgeInsets.only(bottom: 14),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: AppColors.border.withValues(alpha: 0.7),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.tag_rounded,
                            color: AppColors.primary,
                            size: 18,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text(
                                'No. Inventaris',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _noCtrl.text.isEmpty ? '-' : _noCtrl.text,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.textPrimary,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (_isCreateMode)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.auto_awesome,
                                    size: 12, color: AppColors.primary),
                                SizedBox(width: 4),
                                Text(
                                  'Otomatis',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.primary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),

                // 2. Picker Jenis
                _jenisPickerField(),

                // 3. Nama Inventaris
                _field(_namaCtrl, 'Nama', Icons.inventory_2_outlined,
                    required: true),
                Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: DropdownButtonFormField<String>(
                    initialValue: safePabrikKode,
                    style: const TextStyle(fontSize: 13, color: AppColors.textPrimary),
                    decoration: const InputDecoration(
                      labelText: 'Lokasi / Pabrik',
                      prefixIcon: Icon(Icons.location_on_outlined),
                    ),
                    items: master.pabrikList
                        .map(
                          (pabrik) => DropdownMenuItem(
                            value: pabrik.pabKode,
                            child: Text(pabrik.displayLabel,
                                style: const TextStyle(
                                    fontSize: 13, color: AppColors.textPrimary)),
                          ),
                        )
                        .toList(),
                    onChanged: (value) => setState(() => _pabrikKode = value),
                  ),
                ),
                _field(_merkCtrl, 'Merk', Icons.branding_watermark_outlined),
                _field(_snCtrl, 'Serial Number', Icons.qr_code_outlined),
                _field(_picCtrl, 'PIC', Icons.person_outline,
                    hint: 'Masukkan nama PIC'),

                // Kondisi
                DropdownButtonFormField<String>(
                  initialValue: safeKondisi,
                  style: const TextStyle(fontSize: 13, color: AppColors.textPrimary),
                  decoration: const InputDecoration(
                      labelText: 'Kondisi',
                      prefixIcon: Icon(Icons.health_and_safety_outlined)),
                  items: _kondisiList
                      .map((k) => DropdownMenuItem(
                          value: k,
                          child: Text(k,
                              style: const TextStyle(
                                  fontSize: 13, color: AppColors.textPrimary))))
                      .toList(),
                  onChanged: (v) => setState(() => _kondisi = v!),
                ),
                const SizedBox(height: 14),

                // Status Aktif Slider (Switch)
                Container(
                  margin: const EdgeInsets.only(bottom: 14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                        color: AppColors.border.withValues(alpha: 0.8)),
                  ),
                  child: SwitchListTile(
                    value: _isActive,
                    activeColor: AppColors.primary,
                    activeTrackColor: AppColors.primary.withValues(alpha: 0.2),
                    inactiveThumbColor: AppColors.textSecondary,
                    inactiveTrackColor: AppColors.border.withValues(alpha: 0.5),
                    title: const Text(
                      'Status',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    subtitle: Text(
                      _isActive ? 'Inventaris aktif' : 'Inventaris tidak aktif',
                      style: TextStyle(
                        fontSize: 12,
                        color: _isActive
                            ? AppColors.success
                            : AppColors.textSecondary,
                      ),
                    ),
                    secondary: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: (_isActive
                                ? AppColors.primary
                                : AppColors.textSecondary)
                            .withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        _isActive
                            ? Icons.check_circle_outline_rounded
                            : Icons.cancel_outlined,
                        color: _isActive
                            ? AppColors.primary
                            : AppColors.textSecondary,
                        size: 20,
                      ),
                    ),
                    onChanged: (value) => setState(() => _isActive = value),
                  ),
                ),

                _field(_notesCtrl, 'Catatan', Icons.notes_outlined,
                    maxLines: 3),
                const SizedBox(height: 24),

                Consumer<MasterProvider>(
                  builder: (_, p, __) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (p.error != null)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Text(p.error!,
                                style: const TextStyle(
                                    color: AppColors.danger, fontSize: 13)),
                          ),
                        ElevatedButton(
                          onPressed: p.loading ? null : _submit,
                          child: p.loading
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                      color: Colors.white, strokeWidth: 2))
                              : Text(isEdit ? 'Simpan Perubahan' : 'Tambah'),
                        ),
                      ],
                    );
                  },
                ),
              ]),
        ),
      ),
    );
  }

  Widget _jenisPickerField() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextFormField(
            controller: _jenisCtrl,
            readOnly: true,
            decoration: InputDecoration(
              label: RichText(
                text: const TextSpan(
                  text: 'Jenis',
                  style:
                      TextStyle(color: AppColors.textSecondary, fontSize: 14),
                  children: [
                    TextSpan(
                        text: ' *',
                        style: TextStyle(color: Colors.red, fontSize: 14)),
                  ],
                ),
              ),
              hintText: 'Cari...',
              prefixIcon: const Icon(Icons.label_outline),
              suffixIcon: IconButton(
                icon: const Icon(Icons.search),
                onPressed: _pickJenis,
              ),
            ),
            validator: (_) {
              if (_jenisId == null) return 'Jenis wajib dipilih';
              final master = context.read<MasterProvider>();
              if (!master.isJenisActive(_jenisId!)) {
                return 'Jenis inventaris nonaktif';
              }
              return null;
            },
            onTap: _pickJenis,
          ),
          if (_kategori.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4, left: 12),
              child: Row(
                children: [
                  const Icon(Icons.category_outlined,
                      size: 13, color: AppColors.textSecondary),
                  const SizedBox(width: 4),
                  Text(
                    'Kategori: $_kategori',
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _pickJenis() async {
    final provider = context.read<MasterProvider>();
    if (provider.jenisMaster.isEmpty) {
      await provider.fetchJenis(showLoading: false);
    }
    await provider.fetchJenisWithInventaris(showLoading: false);
    if (!mounted) return;

    final allowedItems = provider.jenisAvailableForInventaris(
      includeJenisId: _jenisId ?? widget.initialJenisId,
    );
    if (allowedItems.isEmpty) {
      await AppNotifier.showWarning(
        context,
        'Tidak ada jenis yang tersedia untuk dipilih.',
      );
      return;
    }

    final result = await showModalBottomSheet<JenisModel>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => JenisLookupSheet(
        items: allowedItems,
        initialId: _jenisId,
      ),
    );
    if (result != null) {
      setState(() {
        _jenisId = result.jenisId;
        _jenisCtrl.text = result.jenisNama;
        _kategori = result.jenisKategori.trim();
      });
      await _autoGenerateNoNamaForJenis(result.jenisId);
    }
  }

  Widget _field(TextEditingController ctrl, String label, IconData icon,
      {bool required = false,
      String? hint,
      String? helperText,
      int maxLines = 1,
      bool readOnly = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextFormField(
        controller: ctrl,
        readOnly: readOnly,
        maxLines: maxLines,
        decoration: InputDecoration(
            label: required
                ? RichText(
                    text: TextSpan(
                      text: label,
                      style: const TextStyle(
                          color: AppColors.textSecondary, fontSize: 14),
                      children: const [
                        TextSpan(
                            text: ' *',
                            style: TextStyle(color: Colors.red, fontSize: 14)),
                      ],
                    ),
                  )
                : null,
            labelText: required ? null : label,
            hintText: hint,
            helperText: helperText,
            prefixIcon: Icon(icon),
            fillColor: readOnly ? Colors.grey.shade100 : null,
            filled: readOnly,
            alignLabelWithHint: maxLines > 1),
        validator: required
            ? (v) =>
                (v == null || v.trim().isEmpty) ? '$label wajib diisi' : null
            : null,
      ),
    );
  }
}
