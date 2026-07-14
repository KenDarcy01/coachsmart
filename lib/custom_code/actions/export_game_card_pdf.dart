// FlutterFlow Custom Action
// Name: exportGameCardPdf
//
// Add these packages in FlutterFlow → Custom Code → Dependencies:
//   pdf: ^3.10.8
//   printing: ^5.12.0
//   image: ^4.2.0

import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;
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
) async {
  final PdfColor primary = _pdfColor(primaryColour ?? '#2E7D32');
  final PdfColor secondary = _pdfColor(secondaryColour ?? '#FFC107');
  final PdfColor third = _pdfColor(thirdColour ?? '#1565C0');

  final pw.MemoryImage? crestImage = _pdfImage(await _fetchBytes(clubCrest));
  final pw.MemoryImage? gameImage = _pdfImage(await _fetchBytes(gameImageUrl));

  final resolvedName = gameName ?? '';
  final safeName = resolvedName.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');

  final pdf = pw.Document(compress: !kIsWeb);

  pdf.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: pw.EdgeInsets.zero,
      build: (context) => [
        _pdfHeader(resolvedName, clubName, crestImage, primary, secondary),
        _pdfAccentStripe(secondary, third),
        if ((gameSetup ?? '').isNotEmpty)
          pw.Padding(
            padding: const pw.EdgeInsets.only(top: 16),
            child: _pdfSection('HOW TO SET UP', gameSetup!, primary, secondary),
          ),
        if (gameImage != null)
          pw.Padding(
            padding: const pw.EdgeInsets.fromLTRB(0, 8, 0, 8),
            child: pw.Image(gameImage, fit: pw.BoxFit.fitWidth),
          ),
        pw.SizedBox(height: 8),
        if ((gameHowToPlay ?? '').isNotEmpty)
          _pdfSection('HOW TO PLAY', gameHowToPlay!, primary, secondary),
        if ((gameVariations ?? '').isNotEmpty)
          _pdfSection('VARIATIONS', gameVariations!, primary, secondary),
        if ((gameTeachingPoints ?? '').isNotEmpty)
          _pdfSection('TEACHING POINTS', gameTeachingPoints!, primary, secondary),
        _pdfFooter(clubName, primary, third),
      ],
    ),
  );

  final bytes = await pdf.save();
  await Printing.sharePdf(bytes: bytes, filename: '$safeName.pdf');
}

// ─── Helpers ─────────────────────────────────────────────────────────────────

Future<Uint8List?> _fetchBytes(String? url) async {
  if (url == null || url.isEmpty) return null;
  try {
    final res =
        await http.get(Uri.parse(url)).timeout(const Duration(seconds: 10));
    if (res.statusCode == 200) return res.bodyBytes;
  } catch (_) {}
  return null;
}

// Always re-encode through the image package to produce a clean 8-bit PNG
// that the pdf package's internal decoder can reliably handle. Raw bytes from
// Supabase may have PNG features (interlacing, 16-bit depth) that cause
// PdfImage's internal PngDecoder to throw a null error.
pw.MemoryImage? _pdfImage(Uint8List? bytes) {
  if (bytes == null || bytes.isEmpty) return null;
  try {
    final decoded = img.decodeImage(bytes);
    if (decoded == null) return null;
    final png = Uint8List.fromList(img.encodePng(decoded));
    return pw.MemoryImage(png);
  } catch (_) {
    return null;
  }
}

PdfColor _pdfColor(String hex) {
  final c = hex.replaceAll('#', '');
  final value = int.parse(c.length == 6 ? 'FF$c' : c, radix: 16);
  final r = ((value >> 16) & 0xFF) / 255.0;
  final g = ((value >> 8) & 0xFF) / 255.0;
  final b = (value & 0xFF) / 255.0;
  return PdfColor(r, g, b);
}

// ─── PDF Widgets ─────────────────────────────────────────────────────────────

pw.Widget _pdfHeader(
  String gameName,
  String clubName,
  pw.MemoryImage? crestImage,
  PdfColor primary,
  PdfColor secondary,
) {
  return pw.Container(
    color: primary,
    padding: const pw.EdgeInsets.fromLTRB(20, 18, 20, 18),
    child: pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        if (crestImage != null) ...
          [
            pw.Container(
              width: 64,
              height: 64,
              child: pw.Image(crestImage, fit: pw.BoxFit.contain),
            ),
            pw.SizedBox(width: 16),
          ],
        pw.Expanded(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                clubName,
                style: pw.TextStyle(
                  color: PdfColors.white,
                  fontSize: 14,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 4),
              pw.Container(
                height: 1,
                color: secondary,
              ),
              pw.SizedBox(height: 4),
              pw.Text(
                gameName,
                style: pw.TextStyle(
                  color: PdfColors.white,
                  fontSize: 18,
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

pw.Widget _pdfAccentStripe(PdfColor secondary, PdfColor third) {
  return pw.Row(
    children: [
      pw.Expanded(
        flex: 6,
        child: pw.Container(height: 4, color: secondary),
      ),
      pw.Expanded(
        flex: 2,
        child: pw.Container(height: 4, color: third),
      ),
    ],
  );
}

pw.Widget _pdfSection(
  String title,
  String body,
  PdfColor primary,
  PdfColor secondary,
) {
  final lines = body.split('\n').where((l) => l.trim().isNotEmpty).toList();
  return pw.Padding(
    padding: const pw.EdgeInsets.fromLTRB(28, 0, 28, 14),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Row(
          children: [
            pw.Container(width: 3, height: 12, color: secondary),
            pw.SizedBox(width: 8),
            pw.Text(
              title,
              style: pw.TextStyle(
                color: primary,
                fontSize: 10,
                fontWeight: pw.FontWeight.bold,
                letterSpacing: 1.2,
              ),
            ),
          ],
        ),
        pw.SizedBox(height: 6),
        ...lines.map((line) {
          final text =
              line.startsWith('•') ? line.substring(1).trim() : line.trim();
          return pw.Padding(
            padding: const pw.EdgeInsets.only(bottom: 4),
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.SizedBox(width: 11),
                pw.Container(
                  width: 5,
                  height: 5,
                  margin: const pw.EdgeInsets.only(top: 3, right: 6),
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
                      fontSize: 10,
                      lineSpacing: 2,
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

pw.Widget _pdfFooter(String clubName, PdfColor primary, PdfColor third) {
  return pw.Padding(
    padding: const pw.EdgeInsets.fromLTRB(28, 8, 28, 20),
    child: pw.Column(
      children: [
        pw.Container(height: 1.5, color: third),
        pw.SizedBox(height: 8),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              clubName,
              style: pw.TextStyle(
                color: primary,
                fontSize: 9,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.Text(
              'CoachSmart',
              style: pw.TextStyle(
                color: PdfColor(0.7, 0.7, 0.7),
                fontSize: 9,
              ),
            ),
          ],
        ),
      ],
    ),
  );
}
