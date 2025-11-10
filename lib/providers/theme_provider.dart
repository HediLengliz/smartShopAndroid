import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum ThemeModeOption {
  light,
  dark,
  system,
}

enum LuminosityLevel {
  low,
  medium,
  high,
}

class ThemeProvider with ChangeNotifier {
  ThemeModeOption _themeMode = ThemeModeOption.system;
  LuminosityLevel _luminosity = LuminosityLevel.medium;
  double _brightness = 1.0;

  ThemeModeOption get themeMode => _themeMode;
  LuminosityLevel get luminosity => _luminosity;
  double get brightness => _brightness;

  ThemeProvider() {
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final themeModeIndex = prefs.getInt('theme_mode') ?? ThemeModeOption.system.index;
      final luminosityIndex = prefs.getInt('luminosity') ?? LuminosityLevel.medium.index;
      
      _themeMode = ThemeModeOption.values[themeModeIndex];
      _luminosity = LuminosityLevel.values[luminosityIndex];
      _updateBrightness();
      
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading theme preferences: $e');
    }
  }

  Future<void> setThemeMode(ThemeModeOption mode) async {
    _themeMode = mode;
    notifyListeners();
    
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('theme_mode', mode.index);
    } catch (e) {
      debugPrint('Error saving theme mode: $e');
    }
  }

  Future<void> setLuminosity(LuminosityLevel level) async {
    _luminosity = level;
    _updateBrightness();
    notifyListeners();
    
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('luminosity', level.index);
    } catch (e) {
      debugPrint('Error saving luminosity: $e');
    }
  }

  void _updateBrightness() {
    switch (_luminosity) {
      case LuminosityLevel.low:
        _brightness = 0.7;
        break;
      case LuminosityLevel.medium:
        _brightness = 1.0;
        break;
      case LuminosityLevel.high:
        _brightness = 1.3;
        break;
    }
  }

  ThemeMode get flutterThemeMode {
    switch (_themeMode) {
      case ThemeModeOption.light:
        return ThemeMode.light;
      case ThemeModeOption.dark:
        return ThemeMode.dark;
      case ThemeModeOption.system:
        return ThemeMode.system;
    }
  }

  String get themeModeDisplay {
    switch (_themeMode) {
      case ThemeModeOption.light:
        return 'Light';
      case ThemeModeOption.dark:
        return 'Dark';
      case ThemeModeOption.system:
        return 'System';
    }
  }

  String get luminosityDisplay {
    switch (_luminosity) {
      case LuminosityLevel.low:
        return 'Low';
      case LuminosityLevel.medium:
        return 'Medium';
      case LuminosityLevel.high:
        return 'High';
    }
  }
}

