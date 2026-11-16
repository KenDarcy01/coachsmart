// v3 Pitch planner colours: a light page so the club's own colours and
// crest sit on white (Ken, 2026-11-16). CoachSmart's dark V3 palette is
// kept for the rest of the app; this is used only under lib/v3/pitches.
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class PT {
  static const bg = Color(0xFFF4F5F7);
  static const card = Color(0xFFFFFFFF);
  static const card2 = Color(0xFFF0F2F5);
  static const text = Color(0xFF14181B);
  static const muted = Color(0xFF5F6670);
  static const faint = Color(0xFF9AA0A8);
  static const line = Color(0xFFE3E6EB);
  static const red = Color(0xFFD93036);
  static const redText = Color(0xFFC62828);
  static const redTint = Color(0xFFFDECEC);
  static const green = Color(0xFF3F7D0B);
  static const greenTint = Color(0xFFEAF5DC);
  static const amber = Color(0xFFF5A524);
  static const amberText = Color(0xFF8A5A00);
  static const amberTint = Color(0xFFFFF4DD);
  static const tabBar = Color(0xFFFFFFFF);
  static const slot = Color(0xFFF8F9FB);
  static const slotLine = Color(0xFFE6E9EE);

  static TextStyle inter(double size,
          {FontWeight weight = FontWeight.w400,
          Color color = text,
          double? height,
          double? letterSpacing}) =>
      GoogleFonts.inter(
          fontSize: size,
          fontWeight: weight,
          color: color,
          height: height,
          letterSpacing: letterSpacing);

  static TextStyle tight(double size,
          {FontWeight weight = FontWeight.w600,
          Color color = text,
          double? height}) =>
      GoogleFonts.interTight(
          fontSize: size, fontWeight: weight, color: color, height: height);

  /// Light Material theme for the planner, with the club colour as accent.
  static ThemeData theme(Color accent) {
    final scheme = ColorScheme.fromSeed(
        seedColor: accent, brightness: Brightness.light, surface: card);
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme.copyWith(primary: accent),
      scaffoldBackgroundColor: bg,
      canvasColor: card,
      dividerColor: line,
      textTheme: GoogleFonts.interTextTheme()
          .apply(bodyColor: text, displayColor: text),
      iconTheme: const IconThemeData(color: muted),
      dialogTheme: const DialogThemeData(backgroundColor: card),
      bottomSheetTheme: const BottomSheetThemeData(backgroundColor: card),
      snackBarTheme: const SnackBarThemeData(
          backgroundColor: text, contentTextStyle: TextStyle(color: card)),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: accent),
      textSelectionTheme: TextSelectionThemeData(
          cursorColor: accent, selectionHandleColor: accent),
    );
  }
}
