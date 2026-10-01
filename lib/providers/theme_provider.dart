import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeProvider extends ChangeNotifier {
  ThemeProvider({
    required SharedPreferences preferences,
    required bool isLightTheme,
  }) : _preferences = preferences,
       _isLightTheme = isLightTheme;

  static const _preferenceKey = 'isLightTheme';

  final SharedPreferences _preferences;
  bool _isLightTheme;

  bool get isLightTheme => _isLightTheme;
  ThemeMode get themeMode => _isLightTheme ? ThemeMode.light : ThemeMode.dark;

  Future<void> toggleTheme() async {
    final nextValue = !_isLightTheme;
    final saved = await _preferences.setBool(_preferenceKey, nextValue);
    if (!saved) {
      throw StateError('Unable to save the theme preference.');
    }

    _isLightTheme = nextValue;
    notifyListeners();
  }
}
