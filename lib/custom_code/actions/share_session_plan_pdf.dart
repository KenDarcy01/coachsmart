// Automatic FlutterFlow imports
import '/backend/backend.dart';
import '/backend/schema/structs/index.dart';
import '/backend/supabase/supabase.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'index.dart'; // Imports other custom actions
import '/flutter_flow/custom_functions.dart'; // Imports custom functions
import 'package:flutter/material.dart';
// Begin custom action code
// DO NOT REMOVE OR MODIFY THE CODE ABOVE!

// Required packages — add these in FlutterFlow > Custom Code > Dependencies:
//   pdf: ^3.10.8
//   printing: ^5.13.2

import 'dart:math' as math;
import 'package:http/http.dart' as http;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

/// Generates a branded session plan PDF and opens the native share sheet.
///
/// Parameters (all wired from FlutterFlow):
///   sessionName    — title shown on the cover page
///   games          — ordered list of GamesRow (max 10 used)
///   clubName       — displayed in the header
///   crestUrl       — full URL to the club crest image (nullable)
///   primaryHex     — club primary colour e.g. '#CC2200'
///   secondaryHex   — club secondary colour e.g. '#FFFFFF' (nullable)
///   tertiaryHex    — club tertiary colour e.g. '#FFD700' (nullable)
Future<void> shareSessionPlanPdf(
  String sessionName,
  List<GamesRow> games,
  String clubName,
  String? crestUrl,
  String primaryHex,
  String? secondaryHex,
  String? tertiaryHex,
) async {
  // ── Colour setup ──────────────────────────────────────────────────────────
  final PdfColor primary = _hexToPdf(primaryHex);
  final PdfColor secondary = _hexToPdfOr(secondaryHex, PdfColors.white);
  final PdfColor tertiary = _hexToPdfOr(tertiaryHex, PdfColors.white);
  // Dark stop for gradient start; light stop uses secondary if present,
  // otherwise a brightened tint of primary.
  final PdfColor primaryDark = _shiftL(primary, -0.30);
  final PdfColor gradientLight = (secondaryHex != null && secondaryHex.isNotEmpty)
      ? _hexToPdf(secondaryHex!)
      : _shiftL(primary, 0.15);

  // ── Download images concurrently ──────────────────────────────────────────
  final limitedGames = games.take(10).toList();
  final results = await Future.wait([
    _fetchImage(crestUrl),
    ...limitedGames.map((g) => _fetchImage(g.gameImage)),
  ]);
  final pw.ImageProvider? crestImage = results[0];
  final gameImages = List<pw.ImageProvider?>.from(results.skip(1));

  // ── Build document ────────────────────────────────────────────────────────
  final pdf = pw.Document(title: sessionName);

  pdf.addPage(_coverPage(
    sessionName: sessionName,
    clubName: clubName,
    crestImage: crestImage,
    gameCount: limitedGames.length,
    primary: primary,
    primaryDark: primaryDark,
    gradientLight: gradientLight,
    secondary: secondary,
    tertiary: tertiary,
  ));

  for (var i = 0; i < limitedGames.length; i++) {
    pdf.addPage(_gamePage(
      game: limitedGames[i],
      gameNumber: i + 1,
      totalGames: limitedGames.length,
      gameImage: gameImages[i],
      primary: primary,
      primaryDark: primaryDark,
    ));
  }

  // ── Share ─────────────────────────────────────────────────────────────────
  final bytes = await pdf.save();
  final safeName = sessionName
      .replaceAll(RegExp(r'[^\w\s-]'), '')
      .replaceAll(RegExp(r'\s+'), '_');
  await Printing.sharePdf(bytes: bytes, filename: '$safeName.pdf');
}

// ════════════════════════════════════════════════════════════════════════════
// Cover page
// ════════════════════════════════════════════════════════════════════════════

pw.Page _coverPage({
  required String sessionName,
  required String clubName,
  required pw.ImageProvider? crestImage,
  required int gameCount,
  required PdfColor primary,
  required PdfColor primaryDark,
  required PdfColor gradientLight,
  required PdfColor secondary,
  required PdfColor tertiary,
}) {
  const w = PdfPageFormat.a4Width;
  const h = PdfPageFormat.a4Height;

  return pw.Page(
    pageFormat: PdfPageFormat.a4,
    margin: const pw.EdgeInsets.all(0),
    build: (_) => pw.Stack(
      children: [
        // 1 — Gradient background
        pw.Container(
          width: w,
          height: h,
          decoration: pw.BoxDecoration(
            gradient: pw.LinearGradient(
              begin: pw.Alignment.topRight,
              end: pw.Alignment.bottomLeft,
              colors: [primaryDark, primary, gradientLight],
              stops: const [0.0, 0.45, 1.0],
            ),
          ),
        ),
        // 2 — Decorative stripes + dot grids
        pw.Positioned(
          left: 0,
          top: 0,
          child: pw.CustomPaint(
            size: const PdfPoint(w, h),
            painter: (canvas, size) =>
                _paintDecorations(canvas, size, secondary, tertiary),
          ),
        ),
        // 3 — Centred content
        pw.Positioned(
          left: w * 0.10,
          right: w * 0.10,
          top: 0,
          bottom: 0,
          child: pw.Center(
            child: pw.Column(
              mainAxisAlignment: pw.MainAxisAlignment.center,
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                if (crestImage != null) ...[
                  pw.Container(
                    width: 88,
                    height: 88,
                    child: pw.Image(crestImage, fit: pw.BoxFit.contain),
                  ),
                  pw.SizedBox(height: 22),
                ],
                pw.Text(
                  clubName.toUpperCase(),
                  style: pw.TextStyle(
                    color: PdfColor(1, 1, 1, 0.65),
                    fontSize: 11,
                    fontWeight: pw.FontWeight.bold,
                    letterSpacing: 4,
                  ),
                ),
                pw.SizedBox(height: 14),
                pw.Container(width: 48, height: 1.5, color: PdfColors.white),
                pw.SizedBox(height: 14),
                pw.Text(
                  sessionName,
                  textAlign: pw.TextAlign.center,
                  style: pw.TextStyle(
                    color: PdfColors.white,
                    fontSize: 32,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 12),
                pw.Text(
                  '$gameCount ${gameCount == 1 ? 'game' : 'games'}',
                  style: pw.TextStyle(
                    color: PdfColor(1, 1, 1, 0.55),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}

// ════════════════════════════════════════════════════════════════════════════
// Game page
// ════════════════════════════════════════════════════════════════════════════

pw.Page _gamePage({
  required GamesRow game,
  required int gameNumber,
  required int totalGames,
  required pw.ImageProvider? gameImage,
  required PdfColor primary,
  required PdfColor primaryDark,
}) {
  return pw.Page(
    pageFormat: PdfPageFormat.a4,
    margin: const pw.EdgeInsets.all(0),
    build: (_) => pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        // Header strip
        pw.Container(
          width: double.infinity,
          padding: const pw.EdgeInsets.fromLTRB(24, 14, 24, 14),
          decoration: pw.BoxDecoration(
            gradient: pw.LinearGradient(
              begin: pw.Alignment.centerLeft,
              end: pw.Alignment.centerRight,
              colors: [primaryDark, primary],
            ),
          ),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Expanded(
                child: pw.Text(
                  game.gameName ?? 'Game $gameNumber',
                  style: pw.TextStyle(
                    color: PdfColors.white,
                    fontSize: 18,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
              pw.Text(
                '$gameNumber / $totalGames',
                style: pw.TextStyle(
                  color: PdfColor(1, 1, 1, 0.5),
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ),
        // Tag row (age / type / skill)
        if (_hasAnyTag(game))
          pw.Container(
            width: double.infinity,
            padding: const pw.EdgeInsets.fromLTRB(24, 8, 24, 8),
            color: PdfColor(0.95, 0.95, 0.96),
            child: pw.Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                ...?game.gameAge?.map((v) => _tag(v, primary)).toList(),
                ...?game.gameType?.map((v) => _tag(v, primary)).toList(),
                ...?game.gameSkill?.map((v) => _tag(v, primary)).toList(),
              ],
            ),
          ),
        // Game image
        if (gameImage != null)
          pw.Container(
            width: double.infinity,
            height: 185,
            child: pw.Image(gameImage, fit: pw.BoxFit.cover),
          ),
        // Body content
        pw.Expanded(
          child: pw.Padding(
            padding: const pw.EdgeInsets.fromLTRB(24, 18, 24, 18),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                if (_notEmpty(game.gameSetup)) ...[
                  _section('Setup', game.gameSetup!, primary),
                  pw.SizedBox(height: 14),
                ],
                if (_notEmpty(game.gameHowToPlay)) ...[
                  _section('How to Play', game.gameHowToPlay!, primary),
                  pw.SizedBox(height: 14),
                ],
                if (_notEmpty(game.gameTeachingPoints)) ...[
                  _section('Coaching Points', game.gameTeachingPoints!, primary),
                  pw.SizedBox(height: 14),
                ],
                if (_notEmpty(game.gameVariations))
                  _section('Variations', game.gameVariations!, primary),
              ],
            ),
          ),
        ),
        // Footer
        pw.Container(
          width: double.infinity,
          padding: const pw.EdgeInsets.symmetric(horizontal: 24, vertical: 7),
          color: PdfColor(primary.red, primary.green, primary.blue, 0.10),
          child: pw.Text(
            'CoachSmart Session Plan',
            style: pw.TextStyle(
              color: PdfColor(0, 0, 0, 0.28),
              fontSize: 8,
            ),
          ),
        ),
      ],
    ),
  );
}

// ════════════════════════════════════════════════════════════════════════════
// Decoration painter — stripes + dot grids drawn onto cover background
// ════════════════════════════════════════════════════════════════════════════

void _paintDecorations(
  PdfGraphics canvas,
  PdfPoint size,
  PdfColor secondary,
  PdfColor tertiary,
) {
  // Diagonal stripes lean from top-right toward bottom-left (≈22°)
  final dx = size.y * math.tan(0.384); // tan(22°)
  _stripe(canvas, size, size.x * 0.73, 58, dx,
      PdfColor(secondary.red, secondary.green, secondary.blue, 0.11));
  _stripe(canvas, size, size.x * 0.81, 29, dx,
      PdfColor(secondary.red, secondary.green, secondary.blue, 0.08));
  _stripe(canvas, size, size.x * 0.87, 14, dx,
      PdfColor(secondary.red, secondary.green, secondary.blue, 0.06));

  // Dot grids in two corners
  _dotGrid(canvas, 0, 0, 175, 175, tertiary);                          // top-left
  _dotGrid(canvas, size.x - 175, size.y - 175, 175, 175, tertiary);  // bottom-right
}

void _stripe(PdfGraphics canvas, PdfPoint size, double x, double w, double dx,
    PdfColor color) {
  // Parallelogram: top edge at y=0, bottom edge shifted left by dx
  canvas.setFillColor(color);
  canvas.moveTo(x, 0);
  canvas.lineTo(x + w, 0);
  canvas.lineTo(x + w - dx, size.y);
  canvas.lineTo(x - dx, size.y);
  canvas.closePath();
  canvas.fillPath();
}

void _dotGrid(PdfGraphics canvas, double ox, double oy, double w, double h,
    PdfColor color) {
  const spacing = 18.0;
  const r = 2.0;
  canvas.setFillColor(PdfColor(color.red, color.green, color.blue, 0.22));
  for (double x = ox + spacing / 2; x < ox + w; x += spacing) {
    for (double y = oy + spacing / 2; y < oy + h; y += spacing) {
      canvas.drawEllipse(x, y, r, r);
      canvas.fillPath();
    }
  }
}

// ════════════════════════════════════════════════════════════════════════════
// Small widget helpers
// ════════════════════════════════════════════════════════════════════════════

pw.Widget _section(String title, String body, PdfColor accent) {
  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          pw.Container(width: 3, height: 13, color: accent),
          pw.SizedBox(width: 7),
          pw.Text(
            title,
            style: pw.TextStyle(
              fontSize: 10,
              fontWeight: pw.FontWeight.bold,
              color: PdfColor(0.10, 0.10, 0.10),
            ),
          ),
        ],
      ),
      pw.SizedBox(height: 5),
      pw.Padding(
        padding: const pw.EdgeInsets.only(left: 10),
        child: pw.Text(
          body,
          style: pw.TextStyle(
            fontSize: 9,
            color: PdfColor(0.27, 0.27, 0.27),
            lineSpacing: 1.5,
          ),
        ),
      ),
    ],
  );
}

pw.Widget _tag(String label, PdfColor primary) {
  return pw.Container(
    padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: pw.BoxDecoration(
      border: pw.Border.all(
          color: PdfColor(primary.red, primary.green, primary.blue, 0.55),
          width: 0.5),
      borderRadius: const pw.BorderRadius.all(pw.Radius.circular(3)),
    ),
    child: pw.Text(
      label,
      style: pw.TextStyle(
        fontSize: 8,
        color: PdfColor(primary.red, primary.green, primary.blue, 0.75),
      ),
    ),
  );
}

// ════════════════════════════════════════════════════════════════════════════
// Utility functions
// ════════════════════════════════════════════════════════════════════════════

bool _hasAnyTag(GamesRow g) =>
    (g.gameAge?.isNotEmpty ?? false) ||
    (g.gameType?.isNotEmpty ?? false) ||
    (g.gameSkill?.isNotEmpty ?? false);

Future<pw.ImageProvider?> _fetchImage(String? url) async {
  if (url == null || url.isEmpty) return null;
  try {
    final res =
        await http.get(Uri.parse(url)).timeout(const Duration(seconds: 8));
    if (res.statusCode == 200) return pw.MemoryImage(res.bodyBytes);
  } catch (_) {}
  return null;
}

PdfColor _hexToPdf(String hex) {
  final v = int.parse(hex.replaceAll('#', '').padLeft(6, '0'), radix: 16);
  return PdfColor(
    ((v >> 16) & 0xFF) / 255.0,
    ((v >> 8) & 0xFF) / 255.0,
    (v & 0xFF) / 255.0,
  );
}

PdfColor _hexToPdfOr(String? hex, PdfColor fallback) =>
    (hex != null && hex.isNotEmpty) ? _hexToPdf(hex) : fallback;

/// Shifts HSL lightness by [delta] (positive = lighter, negative = darker).
PdfColor _shiftL(PdfColor c, double delta) {
  final r = c.red, g = c.green, b = c.blue;
  final mx = [r, g, b].reduce(math.max);
  final mn = [r, g, b].reduce(math.min);
  var l = (mx + mn) / 2.0;
  var s = 0.0;
  var h = 0.0;
  final d = mx - mn;

  if (d > 0.0001) {
    s = l > 0.5 ? d / (2.0 - mx - mn) : d / (mx + mn);
    if (mx == r)      h = ((g - b) / d + (g < b ? 6.0 : 0.0)) / 6.0;
    else if (mx == g) h = ((b - r) / d + 2.0) / 6.0;
    else              h = ((r - g) / d + 4.0) / 6.0;
  }

  l = (l + delta).clamp(0.0, 1.0);
  if (s < 0.0001) return PdfColor(l, l, l);

  double hue(double p, double q, double t) {
    if (t < 0) t += 1;
    if (t > 1) t -= 1;
    if (t < 1 / 6) return p + (q - p) * 6 * t;
    if (t < 1 / 2) return q;
    if (t < 2 / 3) return p + (q - p) * (2 / 3 - t) * 6;
    return p;
  }

  final q = l < 0.5 ? l * (1 + s) : l + s - l * s;
  final p = 2 * l - q;
  return PdfColor(hue(p, q, h + 1 / 3), hue(p, q, h), hue(p, q, h - 1 / 3));
}
