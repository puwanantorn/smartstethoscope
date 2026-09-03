import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Tracks the user's light/dark mode preference and persists it locally
/// so it survives app restarts.
class ThemeProvider extends ChangeNotifier {
  static const String _key = 'theme_mode_dark';

  ThemeMode _themeMode = ThemeMode.light;
  ThemeMode get themeMode => _themeMode;
  bool get isDarkMode => _themeMode == ThemeMode.dark;

  Future<void> init() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    _themeMode = (prefs.getBool(_key) ?? false) ? ThemeMode.dark : ThemeMode.light;
    notifyListeners();
  }

  Future<void> setDarkMode(bool isDark) async {
    _themeMode = isDark ? ThemeMode.dark : ThemeMode.light;
    notifyListeners();
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, isDark);
  }
}
