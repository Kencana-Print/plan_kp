import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Wrapper terpusat untuk menjaga konsistensi lebar dan peletakan elemen
/// pada tampilan Web & Tablet tanpa mengubah tampilan Mobile.
class ResponsiveContentWrapper extends StatelessWidget {
  final Widget child;
  final double maxDesktopWidth;
  final double maxTabletWidth;
  final EdgeInsetsGeometry? padding;
  final AlignmentGeometry alignment;
  final bool enableCenter;

  const ResponsiveContentWrapper({
    super.key,
    required this.child,
    this.maxDesktopWidth = 1180.0,
    this.maxTabletWidth = 860.0,
    this.padding,
    this.alignment = Alignment.topCenter,
    this.enableCenter = true,
  });

  @override
  Widget build(BuildContext context) {
    if (AppBreakpoints.isMobile(context)) {
      // Tampilan Mobile (< 600px) tidak diubah sama sekali
      return child;
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final isTablet = AppBreakpoints.isTablet(context);
        final maxWidth = isTablet ? maxTabletWidth : maxDesktopWidth;
        final defaultPadding = padding ??
            EdgeInsets.symmetric(
              horizontal: isTablet ? 20.0 : 24.0,
              vertical: isTablet ? 12.0 : 16.0,
            );

        Widget content = Align(
          alignment: alignment,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: Padding(
              padding: defaultPadding,
              child: child,
            ),
          ),
        );

        if (enableCenter && constraints.maxWidth > maxWidth) {
          return Center(child: content);
        }

        return content;
      },
    );
  }
}
