import 'package:flutter/material.dart';

/// Microsoft Office 365 color palette
class OfficeColors {
  // Primary Office colors
  static const Color officeBlue = Color(0xFF106EBE);
  static const Color officeBlueDark = Color(0xFF004578);
  static const Color officeBlueLight = Color(0xFFDEECF9);
  
  // Neutral grays (Segoe UI style)
  static const Color gray10 = Color(0xFF161514);
  static const Color gray20 = Color(0xFF292827);
  static const Color gray30 = Color(0xFF3B3A39);
  static const Color gray40 = Color(0xFF605E5C);
  static const Color gray60 = Color(0xFFA19F9D);
  static const Color gray90 = Color(0xFFF3F2F1);
  static const Color gray95 = Color(0xFFF8F8F8);
  static const Color gray98 = Color(0xFFFAFAFA);
  static const Color white = Colors.white;
  
  // Status colors
  static const Color success = Color(0xFF107C10);
  static const Color warning = Color(0xFFFFB900);
  static const Color danger = Color(0xFFD13438);
  static const Color info = Color(0xFF0078D4);
  
  // Office accent colors
  static const Color accentOrange = Color(0xFFCA5010);
  static const Color accentGreen = Color(0xFF498205);
  static const Color accentPurple = Color(0xFF5C2D91);
  
  // Ribbon background
  static const Color ribbonBgLight = Color(0xFFF3F2F1);
  static const Color ribbonBgDark = Color(0xFF252423);
  static const Color ribbonBorderLight = Color(0xFFE1DFDD);
  static const Color ribbonBorderDark = Color(0xFF484644);

  static const Color chromeDark = Color(0xFF1B1A19);
  static const Color blueBadgeBgDark = Color(0xFF1B3A4F);
  static const Color blueBadgeFgDark = Color(0xFF50B8F4);
  
  // Tab bar (active tab underline)
  static const Color tabActive = Color(0xFF0078D4);
  static const Color tabHoverLight = Color(0xFFEDEBE9);
  static const Color tabHoverDark = Color(0xFF323130);
}

/// Create Office 365 light theme color scheme
const officeColorSchemeLight = ColorScheme(
  brightness: Brightness.light,
  primary: OfficeColors.officeBlue,
  onPrimary: OfficeColors.white,
  primaryContainer: OfficeColors.officeBlueLight,
  onPrimaryContainer: OfficeColors.officeBlueDark,
  secondary: OfficeColors.accentPurple,
  onSecondary: OfficeColors.white,
  secondaryContainer: Color(0xFFE8DAFF),
  onSecondaryContainer: Color(0xFF3B0F6F),
  tertiary: OfficeColors.accentOrange,
  onTertiary: OfficeColors.white,
  tertiaryContainer: Color(0xFFFFDDBA),
  onTertiaryContainer: Color(0xFF7A3800),
  error: OfficeColors.danger,
  onError: OfficeColors.white,
  errorContainer: Color(0xFFFFDAD6),
  onErrorContainer: Color(0xFF410002),
  surface: OfficeColors.white,
  onSurface: OfficeColors.gray10,
  onSurfaceVariant: OfficeColors.gray40,
  outline: OfficeColors.gray40,
  outlineVariant: OfficeColors.gray60,
  shadow: Color(0xFF000000),
  scrim: Color(0xFF000000),
  inverseSurface: OfficeColors.gray20,
  onInverseSurface: OfficeColors.gray95,
  inversePrimary: Color(0xFF7AC6F5),
  surfaceContainerHighest: OfficeColors.gray95,
  surfaceContainerHigh: OfficeColors.gray90,
);

/// Create Office 365 dark theme color scheme
const officeColorSchemeDark = ColorScheme(
  brightness: Brightness.dark,
  primary: Color(0xFF50B8F4),
  onPrimary: OfficeColors.gray10,
  primaryContainer: OfficeColors.officeBlue,
  onPrimaryContainer: OfficeColors.officeBlueLight,
  secondary: Color(0xFFD4A6FF),
  onSecondary: Color(0xFF2B0A53),
  secondaryContainer: Color(0xFF46227F),
  onSecondaryContainer: Color(0xFFE8DAFF),
  tertiary: Color(0xFFFFB870),
  onTertiary: Color(0xFF532100),
  tertiaryContainer: Color(0xFF844400),
  onTertiaryContainer: Color(0xFFFFDDBA),
  error: Color(0xFFFF99A4),
  onError: Color(0xFF690005),
  errorContainer: Color(0xFF93000A),
  onErrorContainer: Color(0xFFFFDAD6),
  surface: Color(0xFF1B1A19),
  onSurface: OfficeColors.gray90,
  onSurfaceVariant: OfficeColors.gray60,
  outline: OfficeColors.gray60,
  outlineVariant: OfficeColors.gray30,
  shadow: Color(0xFF000000),
  scrim: Color(0xFF000000),
  inverseSurface: OfficeColors.gray95,
  onInverseSurface: OfficeColors.gray20,
  inversePrimary: OfficeColors.officeBlue,
  surfaceContainerHighest: Color(0xFF292827),
  surfaceContainerHigh: Color(0xFF252423),
);
