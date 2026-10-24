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
  static const card = 16.0;
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
    final scheme =
        ColorScheme.fromSeed(
          seedColor: SirajPalette.blue,
          brightness: brightness,
        ).copyWith(
          primary: dark ? const Color(0xFF80AAFF) : SirajPalette.blue,
          secondary: dark ? const Color(0xFF55C5B8) : SirajPalette.teal,
          surface: dark ? const Color(0xFF182A3C) : Colors.white,
          onSurface: dark ? const Color(0xFFEDF4FC) : const Color(0xFF172B4D),
          onSurfaceVariant: dark
              ? const Color(0xFFA3B4C7)
              : const Color(0xFF697891),
          outlineVariant: dark
              ? const Color(0xFF2C4359)
              : const Color(0xFFE3E9F3),
          primaryContainer: dark
              ? const Color(0xFF213A57)
              : const Color(0xFFEDF3FF),
          error: dark ? const Color(0xFFFB8FA0) : const Color(0xFFBF3344),
        );
    return ThemeData(
      useMaterial3: true,
      fontFamily: 'NotoSansArabic',
      extensions: [
        SirajSemanticColors(
          success: dark ? const Color(0xFF55C5B8) : SirajPalette.teal,
          warning: dark ? const Color(0xFFFFCD80) : const Color(0xFFAD721C),
        ),
      ],
      colorScheme: scheme,
      scaffoldBackgroundColor: dark
          ? const Color(0xFF101D2B)
          : SirajPalette.background,
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        color: scheme.surface,
        elevation: 0,
        shadowColor: Colors.black.withValues(alpha: .08),
        shape: RoundedRectangleBorder(
          side: BorderSide(color: scheme.outlineVariant),
          borderRadius: BorderRadius.circular(SirajRadius.card),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(SirajRadius.field),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(48, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
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

@immutable
class SirajSemanticColors extends ThemeExtension<SirajSemanticColors> {
  const SirajSemanticColors({required this.success, required this.warning});
  final Color success, warning;
  @override
  SirajSemanticColors copyWith({Color? success, Color? warning}) =>
      SirajSemanticColors(
        success: success ?? this.success,
        warning: warning ?? this.warning,
      );
  @override
  SirajSemanticColors lerp(covariant SirajSemanticColors? other, double t) =>
      other == null
      ? this
      : SirajSemanticColors(
          success: Color.lerp(success, other.success, t)!,
          warning: Color.lerp(warning, other.warning, t)!,
        );
}
