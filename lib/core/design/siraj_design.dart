import 'package:flutter/material.dart';

abstract final class SirajPalette {
  static const navy = Color(0xFF102B46);
  static const blue = Color(0xFF2563EB);
  static const teal = Color(0xFF0D9488);
  static const background = Color(0xFFF5F7FB);
}

abstract final class SirajSpacing {
  static const x1 = 4.0;
  static const x2 = 8.0;
  static const x3 = 12.0;
  static const x4 = 16.0;
  static const x5 = 20.0;
  static const x6 = 24.0;
}

abstract final class SirajRadius {
  static const card = 20.0;
  static const field = 12.0;
}

abstract final class SirajBreakpoints {
  static const compact = 600.0;
  static const expanded = 900.0;
}

abstract final class SirajTheme {
  static ThemeData light() => _create(Brightness.light);
  static ThemeData dark() => _create(Brightness.dark);

  static ThemeData _create(Brightness brightness) {
    final dark = brightness == Brightness.dark;
    final scheme = ColorScheme.fromSeed(
      seedColor: SirajPalette.blue,
      brightness: brightness,
    ).copyWith(
      primary: dark ? const Color(0xFF8CB6FF) : SirajPalette.blue,
      secondary: dark ? const Color(0xFF55C5B8) : SirajPalette.teal,
      surface: dark ? const Color(0xFF182A3C) : Colors.white,
      error: dark ? const Color(0xFFFB8FA0) : const Color(0xFFBF3344),
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: dark ? const Color(0xFF101D2B) : SirajPalette.background,
      appBarTheme: AppBarTheme(
        backgroundColor: dark ? const Color(0xFF182A3C) : SirajPalette.navy,
        foregroundColor: Colors.white,
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        color: scheme.surface,
        elevation: 1,
        shadowColor: Colors.black.withValues(alpha: .08),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(SirajRadius.card)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(SirajRadius.field)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(48, 48),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: scheme.surface,
        indicatorColor: scheme.primaryContainer,
      ),
      visualDensity: VisualDensity.standard,
    );
  }
}
