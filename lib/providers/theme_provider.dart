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

  void toggleTheme() {
    _isDarkMode = !_isDarkMode;
    notifyListeners();
  }

  static const Color _lightGradientTop = Color(0xFF7F00FF);
  static const Color _lightGradientBottom = Color(0xFFE100FF);
  static const Color _darkGradientTop = Color(0xFF1A237E);
  static const Color _darkGradientBottom = Color(0xFF6A1B9A);
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
    colorScheme: const ColorScheme.dark(
      primary: Colors.deepPurpleAccent,
      surface: Color(0xFF121212),
    ),
    useMaterial3: true,
  );
}
