import 'package:flutter/material.dart';

/// Ediacara's stage: near-black, one blue accent (`#4facfe`) and glass cards,
/// matching the `AcousticTheme` used by the other Infortts consoles.
abstract final class EdiacaraTheme {
  static const Color stage = Color(0xFF0A0A0C);
  static const Color accent = Color(0xFF4FACFE);
  static const Color ink = Color(0xFFE0E0E0);
  static const Color glass = Color(0x1FFFFFFF);
  static const Color hairline = Color(0x1AFFFFFF);

  static ThemeData dark() {
    final scheme = ColorScheme.fromSeed(
      seedColor: accent,
      brightness: Brightness.dark,
    ).copyWith(surface: stage, primary: accent, onPrimary: Colors.white);

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: stage,
      fontFamily: 'Roboto',
      textTheme: const TextTheme(
        displaySmall: TextStyle(
          fontWeight: FontWeight.w300,
          letterSpacing: 2,
          color: accent,
        ),
        bodyMedium: TextStyle(color: ink),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: accent,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  /// The frosted panel the whole console sits in.
  static BoxDecoration get panel => BoxDecoration(
    color: glass,
    borderRadius: BorderRadius.circular(24),
    border: Border.all(color: hairline),
    boxShadow: const [
      BoxShadow(
        color: Color(0x80000000),
        blurRadius: 50,
        offset: Offset(0, 20),
      ),
    ],
  );
}
