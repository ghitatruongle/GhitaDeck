import 'package:flutter/material.dart';
import 'office_colors.dart';

/// GhitaPPT v2.0.0 — Microsoft Office 365 Theme System với dynamic colors
class AppTheme {
  // Light Theme - supports dynamic colors
  static ThemeData lightTheme({
    Color? primaryColor,
    Color? accentColor,
    String? fontFamily,
  }) {
    final primary = primaryColor ?? OfficeColors.officeBlue;
    final accent = accentColor ?? OfficeColors.accentOrange;
    final font = fontFamily ?? 'Segoe UI';
    final colorScheme = _buildLightColorScheme(primary, accent);

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      fontFamily: font,
      scaffoldBackgroundColor: OfficeColors.gray98,

      appBarTheme: AppBarTheme(
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        backgroundColor: OfficeColors.white,
        foregroundColor: OfficeColors.gray10,
        titleTextStyle: TextStyle(
          fontFamily: font,
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: OfficeColors.gray10,
        ),
      ),

      cardTheme: const CardThemeData(
        elevation: 0,
        margin: EdgeInsets.only(bottom: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(4)),
          side: BorderSide(color: OfficeColors.ribbonBorderLight, width: 1),
        ),
        color: OfficeColors.white,
      ),

      dividerTheme: const DividerThemeData(
        color: OfficeColors.ribbonBorderLight,
        thickness: 1,
        space: 1,
      ),

      inputDecorationTheme: InputDecorationTheme(
        isDense: true,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(2),
          borderSide: const BorderSide(color: OfficeColors.gray60, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(2),
          borderSide: const BorderSide(color: OfficeColors.gray60, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(2),
          borderSide: BorderSide(color: primary, width: 2),
        ),
        filled: true,
        fillColor: OfficeColors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(2)),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          elevation: 0,
          textStyle: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 12,
            fontFamily: font,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(2),
            side: BorderSide(color: primary, width: 1),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          textStyle: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 12,
            fontFamily: font,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primary,
          textStyle: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 12,
            fontFamily: font,
          ),
        ),
      ),

      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(2)),
      ),

      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(2)),
      ),

      dialogTheme: DialogThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(2)),
      ),

      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: OfficeColors.gray95,
        selectedIconTheme: IconThemeData(color: primary, size: 20),
        unselectedIconTheme: const IconThemeData(
          color: OfficeColors.gray40,
          size: 20,
        ),
        selectedLabelTextStyle: TextStyle(
          color: primary,
          fontWeight: FontWeight.w600,
          fontSize: 11,
          fontFamily: font,
        ),
        unselectedLabelTextStyle: TextStyle(
          color: OfficeColors.gray40,
          fontWeight: FontWeight.w400,
          fontSize: 11,
          fontFamily: font,
        ),
        indicatorColor: primary.withValues(alpha: 0.15),
      ),

      tabBarTheme: TabBarThemeData(
        labelColor: primary,
        unselectedLabelColor: OfficeColors.gray40,
        indicatorColor: primary,
        indicatorSize: TabBarIndicatorSize.label,
        labelStyle: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          fontFamily: font,
        ),
        unselectedLabelStyle: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w400,
          fontFamily: font,
        ),
      ),

      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: OfficeColors.gray10,
          borderRadius: BorderRadius.circular(2),
        ),
        textStyle: TextStyle(
          color: OfficeColors.white,
          fontSize: 12,
          fontFamily: font,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      ),

      iconTheme: const IconThemeData(
        color: OfficeColors.gray40,
        size: 18,
      ),
    );
  }

  // Dark Theme - supports dynamic colors
  static ThemeData darkTheme({
    Color? primaryColor,
    Color? accentColor,
    String? fontFamily,
  }) {
    final primary = primaryColor ?? const Color(0xFF50B8F4);
    final accent = accentColor ?? const Color(0xFFFFB870);
    final font = fontFamily ?? 'Segoe UI';
    final colorScheme = _buildDarkColorScheme(primary, accent);

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      fontFamily: font,
      scaffoldBackgroundColor: const Color(0xFF1B1A19),

      appBarTheme: AppBarTheme(
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        backgroundColor: const Color(0xFF1B1A19),
        foregroundColor: OfficeColors.gray90,
        titleTextStyle: TextStyle(
          fontFamily: font,
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: OfficeColors.gray90,
        ),
      ),

      cardTheme: const CardThemeData(
        elevation: 0,
        margin: EdgeInsets.only(bottom: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(4)),
          side: BorderSide(color: OfficeColors.ribbonBorderDark, width: 1),
        ),
        color: Color(0xFF252423),
      ),

      dividerTheme: const DividerThemeData(
        color: OfficeColors.ribbonBorderDark,
        thickness: 1,
        space: 1,
      ),

      inputDecorationTheme: InputDecorationTheme(
        isDense: true,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(2),
          borderSide: const BorderSide(color: OfficeColors.gray30, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(2),
          borderSide: const BorderSide(color: OfficeColors.gray30, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(2),
          borderSide: BorderSide(color: primary, width: 2),
        ),
        filled: true,
        fillColor: const Color(0xFF252423),
        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: OfficeColors.gray10,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(2)),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          elevation: 0,
          textStyle: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 12,
            fontFamily: font,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(2),
            side: BorderSide(color: primary, width: 1),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          textStyle: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 12,
            fontFamily: font,
          ),
        ),
      ),

      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(2)),
      ),

      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(2)),
      ),

      dialogTheme: DialogThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(2)),
      ),

      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: const Color(0xFF252423),
        selectedIconTheme: IconThemeData(color: primary, size: 20),
        unselectedIconTheme: const IconThemeData(
          color: OfficeColors.gray60,
          size: 20,
        ),
        selectedLabelTextStyle: TextStyle(
          color: primary,
          fontWeight: FontWeight.w600,
          fontSize: 11,
          fontFamily: font,
        ),
        unselectedLabelTextStyle: TextStyle(
          color: OfficeColors.gray60,
          fontWeight: FontWeight.w400,
          fontSize: 11,
          fontFamily: font,
        ),
        indicatorColor: primary.withValues(alpha: 0.15),
      ),

      tabBarTheme: TabBarThemeData(
        labelColor: OfficeColors.gray90,
        unselectedLabelColor: OfficeColors.gray60,
        indicatorColor: primary,
        indicatorSize: TabBarIndicatorSize.label,
        labelStyle: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          fontFamily: font,
        ),
        unselectedLabelStyle: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w400,
          fontFamily: font,
        ),
      ),

      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: OfficeColors.gray90,
          borderRadius: BorderRadius.circular(2),
        ),
        textStyle: TextStyle(
          color: OfficeColors.gray10,
          fontSize: 12,
          fontFamily: font,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      ),

      iconTheme: const IconThemeData(
        color: OfficeColors.gray60,
        size: 18,
      ),
    );
  }

  // Build ColorScheme từ base office scheme với dynamic primary + accent
  static ColorScheme _buildLightColorScheme(Color primary, Color accent) {
    const base = officeColorSchemeLight;
    return base.copyWith(
      primary: primary,
      primaryContainer: primary.withValues(alpha: 0.12),
      onPrimaryContainer: primary,
      secondary: accent,
      onSecondary: Colors.white,
      secondaryContainer: accent.withValues(alpha: 0.15),
      onSecondaryContainer: accent,
      tertiary: accent,
    );
  }

  // Build dark ColorScheme từ base office scheme với dynamic primary + accent
  static ColorScheme _buildDarkColorScheme(Color primary, Color accent) {
    const base = officeColorSchemeDark;
    return base.copyWith(
      primary: primary,
      primaryContainer: primary.withValues(alpha: 0.15),
      onPrimaryContainer: primary,
      secondary: accent,
      onSecondary: OfficeColors.gray10,
      secondaryContainer: accent.withValues(alpha: 0.20),
      onSecondaryContainer: accent,
      tertiary: accent,
    );
  }
}
