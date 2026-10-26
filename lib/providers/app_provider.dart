import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppProvider with ChangeNotifier {
  static const String _themePrefKey = 'app_theme_mode';

  int _currentIndex = 0;
  ThemeMode _themeMode = ThemeMode.system;

  int get currentIndex => _currentIndex;
  ThemeMode get themeMode => _themeMode;

  AppProvider() {
    _loadThemeMode();
  }

  void updateIndex(int index) {
    if (_currentIndex != index) {
      _currentIndex = index;
      notifyListeners();
    }
  }

  String get currentScreenName {
    switch (_currentIndex) {
      case 0:
        return 'Editor & Presenter';
      case 1:
        return 'Quản Lý Dự Án (.ghita)';
      case 2:
        return 'Template Studio';
      case 3:
        return 'AI Pitch Deck Copilot';
      case 4:
        return 'Cài Đặt Hệ Thống';
      default:
        return 'GhitaDeck';
    }
  }

  /// Toggle between light, dark, and system theme.
  void toggleTheme() {
    switch (_themeMode) {
      case ThemeMode.light:
        _themeMode = ThemeMode.dark;
        break;
      case ThemeMode.dark:
        _themeMode = ThemeMode.system;
        break;
      case ThemeMode.system:
        _themeMode = ThemeMode.light;
        break;
    }
    _saveThemeMode();
    notifyListeners();
  }

  /// Set a specific theme mode.
  void setThemeMode(ThemeMode mode) {
    _themeMode = mode;
    _saveThemeMode();
    notifyListeners();
  }

  String get themeIcon {
    switch (_themeMode) {
      case ThemeMode.light:
        return 'light_mode';
      case ThemeMode.dark:
        return 'dark_mode';
      case ThemeMode.system:
        return 'brightness_auto';
    }
  }

  // ---- Persistence ----

  Future<void> _loadThemeMode() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final stored = prefs.getString(_themePrefKey) ?? 'system';
      _themeMode = ThemeMode.values.firstWhere(
        (e) => e.name == stored,
        orElse: () => ThemeMode.system,
      );
      notifyListeners();
    } catch (_) {
      _themeMode = ThemeMode.system;
    }
  }

  Future<void> _saveThemeMode() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_themePrefKey, _themeMode.name);
    } catch (_) {
      // Silently fail on save errors
    }
  }
}
