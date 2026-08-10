import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  static const primary = Color.fromRGBO(40, 90, 200, 1);
  static const primaryDark = Color.fromRGBO(20, 50, 120, 1);
  static const accent = Color.fromRGBO(56, 108, 232, 1);
  static const primarySoft = Color.fromRGBO(235, 243, 255, 1);
  static const surface = Color.fromRGBO(235, 243, 255, 1);
  static const surfaceAlt = Color.fromRGBO(247, 245, 245, 1);
  static const success = Color.fromRGBO(0, 150, 60, 1);
  static const warning = Color.fromRGBO(190, 140, 20, 1);
  static const danger = Color.fromRGBO(220, 30, 50, 1);
  static const bgGray = Color.fromRGBO(235, 243, 255, 1);
  static const textPrimary = Color.fromRGBO(15, 23, 42, 1);
  static const textSecondary = Color.fromRGBO(51, 65, 85, 1);
  static const border = Color.fromRGBO(233, 231, 231, 1);
  static const white = Color.fromRGBO(255, 255, 255, 1);
}

class AppDivisiColors {
  static Color getColor(String? divisi) {
    if (divisi == null || divisi.trim().isEmpty) return AppColors.primary;
    switch (divisi.trim().toLowerCase()) {
      case 'it':
        return const Color(0xFF4F46E5); // Indigo enterprise
      case 'ga':
        return const Color(0xFFEA580C); // Orange warm
      case 'driver':
        return const Color(0xFF0D9488); // Teal rich
      case 'hrd':
      case 'hr':
        return const Color(0xFFE11D48); // Rose / Pink
      case 'fat':
      case 'finance':
        return const Color(0xFF0284C7); // Sky Blue / Finance
      case 'logistik':
      case 'log':
        return const Color(0xFF7C3AED); // Purple / Violet
      default:
        return AppColors.primary;
    }
  }

  static IconData getIcon(String? divisi) {
    if (divisi == null || divisi.trim().isEmpty) return Icons.business_rounded;
    switch (divisi.trim().toLowerCase()) {
      case 'it':
        return Icons.computer_rounded;
      case 'ga':
        return Icons.precision_manufacturing_rounded;
      case 'driver':
        return Icons.local_shipping_rounded;
      case 'hrd':
      case 'hr':
        return Icons.people_alt_rounded;
      case 'fat':
      case 'finance':
        return Icons.account_balance_wallet_rounded;
      case 'logistik':
      case 'log':
        return Icons.inventory_2_rounded;
      default:
        return Icons.business_rounded;
    }
  }
}

class AppBreakpoints {
  static const mobile = 600.0;
  static const tablet = 960.0;

  static bool isMobile(BuildContext context) =>
      MediaQuery.of(context).size.width < mobile;

  static bool isTablet(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    return w >= mobile && w < tablet;
  }

  static bool isDesktop(BuildContext context) =>
      MediaQuery.of(context).size.width >= tablet;

  static int gridColumns(
    BuildContext context, {
    int mobile = 1,
    int tablet = 2,
    int desktop = 4,
  }) {
    if (isMobile(context)) return mobile;
    if (isTablet(context)) return tablet;
    return desktop;
  }

  static T responsiveValue<T>(
    BuildContext context, {
    required T mobile,
    T? tablet,
    T? desktop,
  }) {
    if (isDesktop(context)) return desktop ?? tablet ?? mobile;
    if (isTablet(context)) return tablet ?? mobile;
    return mobile;
  }

  /// Padding horizontal konten utama per breakpoint.
  /// Gunakan sebagai pengganti EdgeInsets statis di screen body.
  static EdgeInsets contentPadding(BuildContext context, {
    double mobileH = 12.0,
    double tabletH = 20.0,
    double desktopH = 32.0,
    double mobileV = 8.0,
    double tabletV = 12.0,
    double desktopV = 16.0,
  }) {
    if (isDesktop(context)) {
      return EdgeInsets.symmetric(horizontal: desktopH, vertical: desktopV);
    }
    if (isTablet(context)) {
      return EdgeInsets.symmetric(horizontal: tabletH, vertical: tabletV);
    }
    return EdgeInsets.symmetric(horizontal: mobileH, vertical: mobileV);
  }

  /// Padding konten di dalam sheet/dialog responsif.
  static EdgeInsets sheetContentPadding(BuildContext context) {
    if (isDesktop(context)) {
      return const EdgeInsets.fromLTRB(28, 16, 28, 32);
    }
    if (isTablet(context)) {
      return const EdgeInsets.fromLTRB(24, 14, 24, 28);
    }
    return const EdgeInsets.fromLTRB(20, 12, 20, 24);
  }
}

class AppSpacing {
  static const xxs = 2.0;
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 24.0;
}

class AppRadius {
  static const sm = 4.0;
  static const md = 8.0;
  static const lg = 10.0;
  static const xl = 12.0;
  static const full = 9999.0;
}

class AppTheme {
  static ThemeData get light {
    final textTheme = GoogleFonts.plusJakartaSansTextTheme().copyWith(
      titleLarge: GoogleFonts.plusJakartaSans(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
        height: 1.25,
      ),
      titleMedium: GoogleFonts.plusJakartaSans(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
        height: 1.3,
      ),
      titleSmall: GoogleFonts.plusJakartaSans(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
        height: 1.35,
      ),
      bodyLarge: GoogleFonts.plusJakartaSans(
        fontSize: 13,
        fontWeight: FontWeight.w500,
        color: AppColors.textPrimary,
        height: 1.4,
      ),
      bodyMedium: GoogleFonts.plusJakartaSans(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        color: AppColors.textSecondary,
        height: 1.4,
      ),
      bodySmall: GoogleFonts.plusJakartaSans(
        fontSize: 11,
        fontWeight: FontWeight.w500,
        color: AppColors.textSecondary,
        height: 1.35,
      ),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        primary: AppColors.primary,
        surface: AppColors.surface,
        error: AppColors.danger,
      ),
      textTheme: textTheme,
      scaffoldBackgroundColor: AppColors.surface,
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.primaryDark,
        foregroundColor: AppColors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle: GoogleFonts.plusJakartaSans(
          color: AppColors.white,
          fontSize: 16,
          fontWeight: FontWeight.w700,
        ),
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.full)),
        side: const BorderSide(color: AppColors.border),
        backgroundColor: AppColors.white,
        selectedColor: AppColors.primarySoft,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        labelStyle: GoogleFonts.plusJakartaSans(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: AppColors.textSecondary,
        ),
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: AppColors.primary,
        unselectedLabelColor: AppColors.textSecondary,
        indicator: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.full),
          color: AppColors.primarySoft,
        ),
        labelStyle: GoogleFonts.plusJakartaSans(
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
        unselectedLabelStyle: GoogleFonts.plusJakartaSans(
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.white,
          minimumSize: const Size.fromHeight(42),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          textStyle: GoogleFonts.plusJakartaSans(
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 10,
        ),
        hintStyle: GoogleFonts.plusJakartaSans(
          fontSize: 12,
          fontWeight: FontWeight.w400,
          color: AppColors.textSecondary,
        ),
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
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: const BorderSide(color: AppColors.danger),
        ),
        labelStyle: GoogleFonts.plusJakartaSans(
          color: AppColors.textSecondary,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
      dropdownMenuTheme: DropdownMenuThemeData(
        textStyle: GoogleFonts.plusJakartaSans(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: AppColors.textPrimary,
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          side: const BorderSide(color: AppColors.border),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.textPrimary,
        contentTextStyle: GoogleFonts.plusJakartaSans(
          color: AppColors.white,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md)),
      ),
    );
  }
}
