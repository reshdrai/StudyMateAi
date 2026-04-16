import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeProvider extends ValueNotifier<ThemeMode> {
  ThemeProvider() : super(ThemeMode.light) {
    _load();
  }

  static const _key = 'isDarkTheme';

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    // notifyListeners is called automatically by ValueNotifier setter
    value = (prefs.getBool(_key) ?? false) ? ThemeMode.dark : ThemeMode.light;
  }

  bool get isDark => value == ThemeMode.dark;

  Future<void> toggle() async {
    // Compute NEW state first, then save
    final newIsDark = !isDark;
    value = newIsDark ? ThemeMode.dark : ThemeMode.light;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, newIsDark); // save correct value
  }
}

/// Global singleton — lives for the whole app lifetime
final themeProvider = ThemeProvider();
