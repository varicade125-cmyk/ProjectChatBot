import 'package:flutter/material.dart';

/// Centralized themes. All product colors flow from here.
/// Light / dark / OLED true-dark + system mode.
/// Spec ref: docs/02 FR-THEME-01, docs/03 S8.
enum AppThemeMode { system, light, dark, oled }

abstract final class AppThemes {
  static ThemeData light() {
    final scheme = ColorScheme.fromSeed(
      seedColor: Colors.teal,
      brightness: Brightness.light,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: scheme.surface,
    );
  }

  static ThemeData dark() {
    final scheme = ColorScheme.fromSeed(
      seedColor: Colors.teal,
      brightness: Brightness.dark,
    );
    return ThemeData(useMaterial3: true, colorScheme: scheme);
  }

  /// OLED / true-dark: pure black background for AMOLED saving + contrast.
  static ThemeData oled() {
    final scheme = ColorScheme.fromSeed(
      seedColor: Colors.teal,
      brightness: Brightness.dark,
    ).copyWith(surface: Colors.black);
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: Colors.black,
    );
  }

  static ThemeMode toMaterialMode(AppThemeMode mode) {
    switch (mode) {
      case AppThemeMode.light:
        return ThemeMode.light;
      case AppThemeMode.dark:
      case AppThemeMode.oled:
        return ThemeMode.dark;
      case AppThemeMode.system:
        return ThemeMode.system;
    }
  }
}
