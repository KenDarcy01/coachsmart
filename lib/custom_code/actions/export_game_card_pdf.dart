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

// FlutterFlow Custom Action
// Name: exportGameCardPdf
//
// Add these packages in FlutterFlow → Custom Code → Dependencies:
//   pdf: ^3.10.8
//   printing: ^5.12.0

import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart' as paint;
import 'package:http/http.dart' as http;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

Future<void> exportGameCardPdf(
  String? gameName,
  String? gameSetup,
  String? gameHowToPlay,
  String? gameVariations,
  String? gameTeachingPoints,
  String? gameImageUrl,
  String clubName,
  String? clubCrest,
  String? primaryColour,
  String? secondaryColour,
  String? thirdColour,
  String? gameVideoUrl,
) async {
  final PdfColor primary = _pdfColor(primaryColour, 0.18, 0.49, 0.20);
  final PdfColor secondary = _pdfColor(secondaryColour, 1.0, 0.76, 0.03);
  final PdfColor third = _pdfColor(thirdColour, 0.08, 0.40, 0.75);
  final bool hasThird = thirdColour != null &&
      thirdColour.trim().isNotEmpty &&
      !_isWhite(thirdColour);

  final pw.Font clubFont = await PdfGoogleFonts.montserratBold();

  final pw.ImageProvider? crestImage =
      await _pdfImage(await _fetchBytes(clubCrest));
  final pw.ImageProvider? gameImage =
      await _pdfImage(await _fetchBytes(gameImageUrl));

  final resolvedName = _sanitise(gameName ?? '');
  final safeName = resolvedName.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');

  final PdfPageFormat pageFormat =
      kIsWeb ? PdfPageFormat.a4 : const PdfPageFormat(380, 820);
  final double hPad = kIsWeb ? 28.0 : 16.0;
  final double crestSize = kIsWeb ? 84.0 : 68.0;
  final double imageHeight = kIsWeb ? 260.0 : 200.0;

  final pdf = pw.Document(compress: !kIsWeb);

  pdf.addPage(
    pw.MultiPage(
      pageFormat: pageFormat,
      margin: pw.EdgeInsets.zero,
      header: (context) => pw.SizedBox(
        height: context.pageNumber > 1 ? 24 : 0,
      ),
      footer: (context) => _pdfFooter(
          _sanitise(clubName), primary, secondary, third, hPad, hasThird),
      build: (context) => [
        _pdfHeader(resolvedName, _sanitise(clubName), crestImage, primary,
            secondary, clubFont, hPad, crestSize),
        _pdfAccentStripe(secondary, third, hasThird),
        if (_sanitise(gameSetup ?? '').isNotEmpty)
          pw.Padding(
            padding: const pw.EdgeInsets.only(top: 16),
            child: _pdfSection('HOW TO SET UP', _sanitise(gameSetup!), primary,
                secondary, hPad),
          ),
        if (gameImage != null)
          pw.Padding(
            padding: const pw.EdgeInsets.symmetric(vertical: 8),
            child: pw.Center(
              child: pw.SizedBox(
                height: imageHeight,
                child: pw.Image(gameImage, fit: pw.BoxFit.contain),
              ),
            ),
          ),
        pw.SizedBox(height: 8),
        if (_sanitise(gameHowToPlay ?? '').isNotEmpty)
          _pdfSection('HOW TO PLAY', _sanitise(gameHowToPlay!), primary,
              secondary, hPad),
        if (_sanitise(gameVariations ?? '').isNotEmpty)
          _pdfSection('VARIATIONS', _sanitise(gameVariations!), primary,
              secondary, hPad),
        if (_sanitise(gameTeachingPoints ?? '').isNotEmpty)
          _pdfSection('TEACHING POINTS', _sanitise(gameTeachingPoints!),
              primary, secondary, hPad),
        if ((gameVideoUrl ?? '').trim().isNotEmpty)
          _pdfVideoLink(_sanitise(gameVideoUrl!.trim()), secondary, primary, hPad),
      ],
    ),
  );

  final bytes = await pdf.save();
  await Printing.sharePdf(bytes: bytes, filename: '$safeName.pdf');
}

// ─── Helpers ─────────────────────────────────────────────────────────────────

bool _isWhite(String hex) {
  final c = hex.trim().replaceAll('#', '').replaceAll(' ', '').toUpperCase();
  return c == 'FFF' || c == 'FFFFFF' || c == 'FFFFFFFF';
}

PdfColor _pdfColor(
    String? hex, double fallbackR, double fallbackG, double fallbackB) {
  if (hex == null || hex.trim().isEmpty) {
    return PdfColor(fallbackR, fallbackG, fallbackB);
  }
  try {
    var c = hex.trim().replaceAll('#', '').replaceAll(' ', '');
    if (c.length == 3) {
      c = '${c[0]}${c[0]}${c[1]}${c[1]}${c[2]}${c[2]}';
    }
    if (c.length == 6) c = 'FF$c';
    if (c.length != 8) return PdfColor(fallbackR, fallbackG, fallbackB);
    final value = int.parse(c, radix: 16);
    return PdfColor(
      ((value >> 16) & 0xFF) / 255.0,
      ((value >> 8) & 0xFF) / 255.0,
      (value & 0xFF) / 255.0,
    );
  } catch (_) {
    return PdfColor(fallbackR, fallbackG, fallbackB);
  }
}

Future<pw.ImageProvider?> _pdfImage(Uint8List? bytes) async {
  if (bytes == null || bytes.isEmpty) return null;
  try {
    return await flutterImageProvider(paint.MemoryImage(bytes));
  } catch (_) {
    return null;
  }
}

String _sanitise(String text) {
  return text
      .replaceAll('‘', "'")
      .replaceAll('’', "'")
      .replaceAll('“', '"')
      .replaceAll('”', '"')
      .replaceAll('–', '-')
      .replaceAll('—', '-')
      .replaceAll('…', '...');
}

Future<Uint8List?> _fetchBytes(String? url) async {
  if (url == null || url.isEmpty) return null;
  try {
    final res =
        await http.get(Uri.parse(url)).timeout(const Duration(seconds: 10));
    if (res.statusCode == 200) return res.bodyBytes;
  } catch (_) {}
  return null;
}

// ─── PDF Widgets ─────────────────────────────────────────────────────────────

pw.Widget _pdfHeader(
  String gameName,
  String clubName,
  pw.ImageProvider? crestImage,
  PdfColor primary,
  PdfColor secondary,
  pw.Font clubFont,
  double hPad,
  double crestSize,
) {
  return pw.Container(
    color: primary,
    padding: pw.EdgeInsets.fromLTRB(hPad, 16, hPad, 16),
    child: pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        if (crestImage != null) ...[
          pw.Container(
            width: crestSize,
            height: crestSize,
            child: pw.Image(crestImage, fit: pw.BoxFit.contain),
          ),
          pw.SizedBox(width: 14),
        ],
        pw.Expanded(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                clubName,
                style: pw.TextStyle(
                  font: clubFont,
                  color: PdfColors.white,
                  fontSize: 22,
                ),
              ),
              pw.SizedBox(height: 5),
              pw.Container(height: 1, color: PdfColors.white),
              pw.SizedBox(height: 5),
              pw.Text(
                gameName,
                style: pw.TextStyle(
                  color: PdfColors.white,
                  fontSize: 17,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

pw.Widget _pdfAccentStripe(PdfColor secondary, PdfColor third, bool hasThird) {
  return pw.Column(
    children: [
      pw.Container(height: 2, color: PdfColors.white),
      pw.Container(height: 4, color: secondary),
      if (hasThird) pw.Container(height: 3, color: third),
    ],
  );
}

pw.Widget _pdfSection(
  String title,
  String body,
  PdfColor primary,
  PdfColor secondary,
  double hPad,
) {
  final lines = body.split('\n').where((l) => l.trim().isNotEmpty).toList();
  return pw.Padding(
    padding: pw.EdgeInsets.fromLTRB(hPad, 0, hPad, 16),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Row(
          children: [
            pw.Container(width: 3, height: 13, color: secondary),
            pw.SizedBox(width: 8),
            pw.Text(
              title,
              style: pw.TextStyle(
                color: primary,
                fontSize: 11,
                fontWeight: pw.FontWeight.bold,
                letterSpacing: 1.0,
              ),
            ),
          ],
        ),
        pw.SizedBox(height: 7),
        ...lines.map((line) {
          final text =
              line.startsWith('•') ? line.substring(1).trim() : line.trim();
          return pw.Padding(
            padding: const pw.EdgeInsets.only(bottom: 5),
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.SizedBox(width: 11),
                pw.Container(
                  width: 5,
                  height: 5,
                  margin: const pw.EdgeInsets.only(top: 4, right: 7),
                  decoration: pw.BoxDecoration(
                    color: secondary,
                    shape: pw.BoxShape.circle,
                  ),
                ),
                pw.Expanded(
                  child: pw.Text(
                    text,
                    style: pw.TextStyle(
                      color: PdfColor(0.18, 0.18, 0.18),
                      fontSize: 12,
                      lineSpacing: 3,
                    ),
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    ),
  );
}

pw.Widget _pdfVideoLink(
    String url, PdfColor secondary, PdfColor primary, double hPad) {
  return pw.Padding(
    padding: pw.EdgeInsets.fromLTRB(hPad, 0, hPad, 16),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Row(
          children: [
            pw.Container(width: 3, height: 13, color: secondary),
            pw.SizedBox(width: 8),
            pw.Text(
              'VIDEO EXPLAINER',
              style: pw.TextStyle(
                color: primary,
                fontSize: 11,
                fontWeight: pw.FontWeight.bold,
                letterSpacing: 1.0,
              ),
            ),
          ],
        ),
        pw.SizedBox(height: 7),
        pw.Padding(
          padding: const pw.EdgeInsets.only(left: 11),
          child: pw.UrlLink(
            destination: url,
            child: pw.Text(
              url,
              style: pw.TextStyle(
                color: PdfColor(0.1, 0.4, 0.85),
                fontSize: 12,
                decoration: pw.TextDecoration.underline,
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

pw.Widget _pdfFooter(
  String clubName,
  PdfColor primary,
  PdfColor secondary,
  PdfColor third,
  double hPad,
  bool hasThird,
) {
  return pw.Padding(
    padding: pw.EdgeInsets.fromLTRB(hPad, 8, hPad, 16),
    child: pw.Column(
      children: [
        pw.Container(height: 1.5, color: hasThird ? third : secondary),
        pw.SizedBox(height: 8),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              clubName,
              style: pw.TextStyle(
                color: primary,
                fontSize: 10,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.Text(
              'CoachSmart',
              style: pw.TextStyle(
                color: PdfColor(0.7, 0.7, 0.7),
                fontSize: 10,
              ),
            ),
          ],
        ),
      ],
    ),
  );
}
