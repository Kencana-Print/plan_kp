import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Menampilkan BottomSheet di mobile/tablet, dan Dialog di desktop.
/// Gunakan sebagai pengganti [showModalBottomSheet] agar tampilan
/// menyesuaikan layar besar secara otomatis tanpa mengubah mobile.
Future<T?> showResponsiveSheet<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  double maxDesktopWidth = 580.0,
  bool isScrollControlled = true,
  bool barrierDismissible = true,
}) {
  if (AppBreakpoints.isDesktop(context)) {
    return showDialog<T>(
      context: context,
      barrierDismissible: barrierDismissible,
      builder: (ctx) => Dialog(
        insetPadding:
            const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
        backgroundColor: Colors.transparent,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: maxDesktopWidth,
            maxHeight: MediaQuery.of(ctx).size.height * 0.88,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: builder(ctx),
          ),
        ),
      ),
    );
  }

  // Mobile & Tablet: tetap pakai BottomSheet seperti semula
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: isScrollControlled,
    backgroundColor: Colors.transparent,
    builder: builder,
  );
}
