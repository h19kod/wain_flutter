import 'package:flutter/material.dart';

/// The palette from frontend/src/styles.css: enamel shop-sign blue, price-tag yellow,
/// concrete grey and a red rubber stamp.
@immutable
class WainColors extends ThemeExtension<WainColors> {
  const WainColors({
    required this.enamel,
    required this.enamelDeep,
    required this.tag,
    required this.tagInk,
    required this.concrete,
    required this.card,
    required this.ink,
    required this.ink2,
    required this.rule,
    required this.stamp,
    required this.ok,
    required this.accent,
  });

  static const light = WainColors(
    enamel: Color(0xFF123C8C),
    enamelDeep: Color(0xFF0C2A66),
    tag: Color(0xFFF6C428),
    tagInk: Color(0xFF2B2100),
    concrete: Color(0xFFEEF0EC),
    card: Color(0xFFFFFFFF),
    ink: Color(0xFF14203A),
    ink2: Color(0xFF4F5B70),
    rule: Color(0xFFCFD5CF),
    stamp: Color(0xFFC8322B),
    ok: Color(0xFF1E7A4C),
    accent: Color(0xFF123C8C),
  );

  static const dark = WainColors(
    enamel: Color(0xFF1A4AA6),
    enamelDeep: Color(0xFF0D2A62),
    tag: Color(0xFFF6C428),
    tagInk: Color(0xFF2B2100),
    concrete: Color(0xFF11161F),
    card: Color(0xFF1A212D),
    ink: Color(0xFFE9EDF3),
    ink2: Color(0xFFA8B2C2),
    rule: Color(0xFF2E3747),
    stamp: Color(0xFFF0736B),
    ok: Color(0xFF5FC391),
    accent: Color(0xFF8FB0F2),
  );

  final Color enamel;
  final Color enamelDeep;
  final Color tag;
  final Color tagInk;
  final Color concrete;
  final Color card;
  final Color ink;
  final Color ink2;
  final Color rule;
  final Color stamp;
  final Color ok;
  final Color accent;

  /// CSS color-mix(in srgb, a p%, b).
  static Color mix(Color a, double p, Color b) => Color.lerp(b, a, p)!;

  @override
  WainColors copyWith() => this;

  @override
  WainColors lerp(WainColors? other, double t) => t < 0.5 || other == null ? this : other;
}

const displayFont = 'Lalezar';
const bodyFont = 'IBMPlexSansArabic';

extension WainTheme on BuildContext {
  WainColors get wain => Theme.of(this).extension<WainColors>() ?? WainColors.light;
}

ThemeData buildTheme(Brightness brightness) {
  final c = brightness == Brightness.dark ? WainColors.dark : WainColors.light;
  final border = OutlineInputBorder(
    borderRadius: BorderRadius.circular(6),
    borderSide: BorderSide(color: c.rule, width: 2),
  );
  return ThemeData(
    brightness: brightness,
    fontFamily: bodyFont,
    scaffoldBackgroundColor: c.concrete,
    colorScheme: ColorScheme.fromSeed(
      seedColor: c.enamel,
      brightness: brightness,
      primary: c.enamel,
      onPrimary: Colors.white,
      secondary: c.tag,
      onSecondary: c.tagInk,
      surface: c.card,
      onSurface: c.ink,
      error: c.stamp,
    ),
    extensions: [c],
    appBarTheme: AppBarTheme(
      backgroundColor: c.enamelDeep,
      foregroundColor: Colors.white,
      titleTextStyle: const TextStyle(fontFamily: bodyFont, fontSize: 18, fontWeight: FontWeight.w600, color: Colors.white),
    ),
    textTheme: ThemeData(brightness: brightness).textTheme.apply(
          fontFamily: bodyFont,
          bodyColor: c.ink,
          displayColor: c.ink,
        ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: c.card,
      border: border,
      enabledBorder: border,
      focusedBorder: border.copyWith(borderSide: BorderSide(color: c.enamel, width: 2)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: c.enamel,
        foregroundColor: Colors.white,
        minimumSize: const Size(44, 44),
        padding: const EdgeInsets.symmetric(horizontal: 18),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        textStyle: const TextStyle(fontFamily: bodyFont, fontWeight: FontWeight.w600, fontSize: 15),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: c.ink,
        minimumSize: const Size(44, 44),
        padding: const EdgeInsets.symmetric(horizontal: 18),
        side: BorderSide(color: c.rule, width: 2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        textStyle: const TextStyle(fontFamily: bodyFont, fontWeight: FontWeight.w600, fontSize: 15),
      ),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: c.card,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(14))),
    ),
  );
}
