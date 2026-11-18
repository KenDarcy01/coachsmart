// v3 Pitch planner colours: a light page so the club's own colours and
// crest sit on white (Ken, 2026-11-16). CoachSmart's dark V3 palette is
// kept for the rest of the app; this is used only under lib/v3/pitches.
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class PT {
  /// Black CoachSmart look when the planner is opened inside the app; the
  /// light club-branded look when opened from a link on a laptop (Ken,
  /// 2026-11-18). Set by V3PitchesPage before anything is built.
  static bool dark = false;

  /// CoachSmart green, the accent inside the app.
  static const csGreen = Color(0xFF87C232);

  static Color get bg =>
      dark ? const Color(0xFF14181B) : const Color(0xFFF4F5F7);
  static Color get card =>
      dark ? const Color(0xFF1E222B) : const Color(0xFFFFFFFF);
  static Color get card2 =>
      dark ? const Color(0xFF262B36) : const Color(0xFFF0F2F5);
  static Color get text =>
      dark ? const Color(0xFFF1F4F8) : const Color(0xFF14181B);
  static Color get muted =>
      dark ? const Color(0xFFB5B8BE) : const Color(0xFF5F6670);
  static Color get faint =>
      dark ? const Color(0xFF7D828B) : const Color(0xFF9AA0A8);
  static Color get line =>
      dark ? const Color(0xFF2E333E) : const Color(0xFFE3E6EB);
  static Color get red =>
      dark ? const Color(0xFFE5484D) : const Color(0xFFD93036);
  static Color get redText =>
      dark ? const Color(0xFFFF7B7F) : const Color(0xFFC62828);
  static Color get redTint =>
      dark ? const Color(0xFF3D1C1E) : const Color(0xFFFDECEC);
  static Color get green =>
      dark ? const Color(0xFF87C232) : const Color(0xFF3F7D0B);
  static Color get greenTint =>
      dark ? const Color(0xFF2A3D17) : const Color(0xFFEAF5DC);
  static Color get amber =>
      dark ? const Color(0xFFF5A524) : const Color(0xFFF5A524);
  static Color get amberText =>
      dark ? const Color(0xFFFFC861) : const Color(0xFF8A5A00);
  static Color get amberTint =>
      dark ? const Color(0xFF3A2B0D) : const Color(0xFFFFF4DD);
  static Color get tabBar =>
      dark ? const Color(0xFF101316) : const Color(0xFFFFFFFF);
  static Color get slot =>
      dark ? const Color(0xFF232833) : const Color(0xFFF8F9FB);
  static Color get slotLine =>
      dark ? const Color(0xFF343A46) : const Color(0xFFE6E9EE);

  static TextStyle inter(double size,
          {FontWeight weight = FontWeight.w400,
          Color? color,
          double? height,
          double? letterSpacing}) =>
      GoogleFonts.inter(
          fontSize: size,
          fontWeight: weight,
          color: color ?? text,
          height: height,
          letterSpacing: letterSpacing);

  static TextStyle tight(double size,
          {FontWeight weight = FontWeight.w600,
          Color? color,
          double? height}) =>
      GoogleFonts.interTight(
          fontSize: size,
          fontWeight: weight,
          color: color ?? text,
          height: height);

  /// Light Material theme for the planner, with the club colour as accent.
  static ThemeData theme(Color accent) {
    final scheme = ColorScheme.fromSeed(
        seedColor: accent,
        brightness: dark ? Brightness.dark : Brightness.light,
        surface: card);
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme.copyWith(primary: accent),
      scaffoldBackgroundColor: bg,
      canvasColor: card,
      dividerColor: line,
      textTheme: GoogleFonts.interTextTheme(
              dark ? ThemeData(brightness: Brightness.dark).textTheme : null)
          .apply(bodyColor: text, displayColor: text),
      iconTheme: IconThemeData(color: muted),
      dialogTheme: DialogThemeData(backgroundColor: card),
      bottomSheetTheme: BottomSheetThemeData(backgroundColor: card),
      snackBarTheme: SnackBarThemeData(
          backgroundColor: text, contentTextStyle: TextStyle(color: card)),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: accent),
      textSelectionTheme: TextSelectionThemeData(
          cursorColor: accent, selectionHandleColor: accent),
    );
  }
}
