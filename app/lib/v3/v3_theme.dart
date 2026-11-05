// v3 look: the palette and type ramp from the approved mockups
// (/mnt/project-files/coachsmart/app-v3/home-design/home.html).
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class V3 {
  static const green = Color(0xFF87C232);
  static const bg = Color(0xFF14181B);
  static const card = Color(0xFF1E222B);
  static const card2 = Color(0xFF262B36);
  static const text = Color(0xFFF1F4F8);
  static const muted = Color(0xFFB5B8BE);
  static const red = Color(0xFFE5484D);
  static const redText = Color(0xFFFF7B7F);
  static const amber = Color(0xFFF5A524);
  static const amberText = Color(0xFFFFC861);
  static const line = Color(0xFF2E333E);
  static const barGrey = Color(0xFF4A4F59);
  static const tabBar = Color(0xFF101316);

  // Tinted pill backgrounds.
  static const greenTint = Color(0xFF2A3D17);
  static const redTint = Color(0xFF3D1C1E);
  static const amberTint = Color(0xFF3A2B0D);
  static const amberLine = Color(0xFF6B4D12);
  static const nextLine = Color(0xFF3F5D1E);
  static const nextTop = Color(0xFF1F2A19);

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
}
