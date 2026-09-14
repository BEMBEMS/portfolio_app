import 'package:flutter/material.dart';

class ThemeProvider extends ChangeNotifier {
  bool _isDarkMode = false;

  bool get isDarkMode => _isDarkMode;

  ThemeData get currentTheme => _isDarkMode ? _darkTheme : _lightTheme;

  Color get gradientTop =>
      _isDarkMode ? _darkGradientTop : _lightGradientTop;
  Color get gradientBottom =>
      _isDarkMode ? _darkGradientBottom : _lightGradientBottom;
  Color get accentColor => _isDarkMode ? _darkAccent : _lightAccent;

  Color get textColor => _isDarkMode ? Colors.white : const Color(0xFF1B1B1B);
  Color get secondaryTextColor =>
      _isDarkMode ? Colors.white70 : const Color(0xFF4B4B4B);
  Color get mutedTextColor =>
      _isDarkMode ? Colors.white54 : const Color(0xFF717171);
  Color get dividerColor =>
      _isDarkMode ? Colors.white24 : const Color(0xFFD9D9D9);
  Color get borderColor =>
      _isDarkMode ? Colors.white.withValues(alpha: 0.2) : const Color(0xFFDDDDDD);

  void toggleTheme() {
    _isDarkMode = !_isDarkMode;
    notifyListeners();
  }

  static const Color _lightGradientTop = Color(0xFFF2F2F2);
  static const Color _lightGradientBottom = Color(0xFFF2F2F2);
  static const Color _darkGradientTop = Color(0xFF0A0A0A);
  static const Color _darkGradientBottom = Color(0xFF1A1A1A);
  static const Color _lightAccent = Color(0xFFF57C00);
  static const Color _darkAccent = Color(0xFFFFB74D);

  static final ThemeData _lightTheme = ThemeData(
    brightness: Brightness.light,
    colorSchemeSeed: Colors.deepPurple,
    useMaterial3: true,
  );

  static final ThemeData _darkTheme = ThemeData(
    brightness: Brightness.dark,
    colorSchemeSeed: Colors.deepPurple,
    useMaterial3: true,
  );
}
