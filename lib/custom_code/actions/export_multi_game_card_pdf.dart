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
// Name: exportMultiGameCardPdf
//
// Add these packages in FlutterFlow → Custom Code → Dependencies:
//   pdf: ^3.10.8
//   printing: ^5.12.0

import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart' as paint;
import 'package:http/http.dart' as http;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Future<String?> exportMultiGameCardPdf(
  List<int> gameIds,
  String clubName,
  String? clubCrest,
  String? primaryColour,
  String? secondaryColour,
  String? thirdColour,
) async {
  if (gameIds.isEmpty) return null;

  if (gameIds.length > 10) {
    return 'Please select a maximum of 10 games to export at once.';
  }

  try {
    debugPrint('[PDF] Starting exportMultiGameCardPdf for ${gameIds.length} games: $gameIds');

    final PdfColor primary = _mgPdfColor(primaryColour, 0.18, 0.49, 0.20);
    final PdfColor secondary = _mgPdfColor(secondaryColour, 1.0, 0.76, 0.03);
    final PdfColor third = _mgPdfColor(thirdColour, 0.08, 0.40, 0.75);
    final bool hasThird = thirdColour != null &&
        thirdColour.trim().isNotEmpty &&
        !_mgIsWhite(thirdColour);

    debugPrint('[PDF] Loading fonts...');
    final pw.Font clubFont = await PdfGoogleFonts.montserratBold();
    final pw.Font bodyFont = await PdfGoogleFonts.notoSansRegular();
    final pw.Font bodyFontBold = await PdfGoogleFonts.notoSansBold();
    debugPrint('[PDF] Fonts loaded');

    final supabase = Supabase.instance.client;
    debugPrint('[PDF] Fetching game rows from Supabase...');
    final List<dynamic> rows = await supabase
        .from('games')
        .select(
            'game_id, game_name, game_setup, game_how_to_play, game_variations, game_teaching_points, game_image, game_video')
        .inFilter('game_id', gameIds);

    debugPrint('[PDF] Got ${rows.length} rows');
    if (rows.isEmpty) return null;

    final rowMap = <int, Map<String, dynamic>>{
      for (final r in rows) (r['game_id'] as int): r as Map<String, dynamic>,
    };
    final ordered = gameIds
        .where((id) => rowMap.containsKey(id))
        .map((id) => rowMap[id]!)
        .toList();

    debugPrint('[PDF] Fetching club crest: $clubCrest');
    final pw.ImageProvider? crestImage =
        await _mgPdfImage(await _mgFetchBytes(clubCrest));
    debugPrint('[PDF] Crest loaded: ${crestImage != null}');

    debugPrint('[PDF] Fetching game images...');
    final List<(pw.ImageProvider?, double?)> gameImageData = await Future.wait(
      ordered.map((row) async {
        final url = row['game_image'] as String?;
        debugPrint('[PDF]   game image url: $url');
        final bytes = await _mgFetchBytes(url);
        debugPrint('[PDF]   game image bytes: ${bytes?.length ?? 0}');
        final provider = await _mgPdfImage(bytes);
        final ratio = bytes != null ? await _mgImageRatio(bytes) : null;
        return (provider, ratio);
      }),
    );

    final PdfPageFormat pageFormat =
        kIsWeb ? PdfPageFormat.a4 : const PdfPageFormat(380, 820);
    final double hPad = kIsWeb ? 28.0 : 16.0;
    final double crestSize = kIsWeb ? 84.0 : 68.0;

    debugPrint('[PDF] Building PDF document (kIsWeb=$kIsWeb)...');
    final pdf = pw.Document(compress: !kIsWeb);

    // One MultiPage per game so context.pageNumber resets to 1 for each game's
    // first page (banner page = no top padding) and is >1 for continuation pages
    // (content only = needs breathing room at top).
    for (int i = 0; i < ordered.length; i++) {
      final row = ordered[i];
      final gameName = _mgSanitise(row['game_name'] as String? ?? '');
      final gameSetup = _mgSanitise(row['game_setup'] as String? ?? '');
      final gameHowToPlay =
          _mgSanitise(row['game_how_to_play'] as String? ?? '');
      final gameVariations =
          _mgSanitise(row['game_variations'] as String? ?? '');
      final gameTeachingPoints =
          _mgSanitise(row['game_teaching_points'] as String? ?? '');
      final gameVideo = (row['game_video'] as String? ?? '').trim();
      final (gameImage, imageRatio) = gameImageData[i];

      final double contentW = pageFormat.width - 2 * hPad;
      pw.Widget? imageWidget;
      if (gameImage != null) {
        double imgW = contentW;
        double imgH = imageRatio != null ? imgW / imageRatio : 280.0;
        if (imgH > 380) { imgH = 280; imgW = imgH * (imageRatio ?? 1.0); }
        imageWidget = pw.Padding(
          padding: const pw.EdgeInsets.symmetric(vertical: 8),
          child: pw.Center(
            child: pw.Image(gameImage, width: imgW, height: imgH, fit: pw.BoxFit.contain),
          ),
        );
      }

      pdf.addPage(
        pw.MultiPage(
          pageFormat: pageFormat,
          margin: pw.EdgeInsets.zero,
          header: (context) =>
              pw.SizedBox(height: context.pageNumber == 1 ? 0 : 16),
          footer: (context) => _mgPdfFooter(_mgSanitise(clubName), primary,
              secondary, third, hPad, hasThird, bodyFont, bodyFontBold),
          build: (context) => [
            _mgPdfHeader(gameName, _mgSanitise(clubName), crestImage, primary,
                secondary, clubFont, bodyFontBold, hPad, crestSize),
            _mgPdfAccentStripe(secondary, third, hasThird),
            if (gameSetup.isNotEmpty)
              pw.Padding(
                padding: const pw.EdgeInsets.only(top: 16),
                child: _mgPdfSection('HOW TO SET UP', gameSetup, primary,
                    secondary, hPad, bodyFont, bodyFontBold),
              ),
            if (imageWidget != null) imageWidget,
            pw.SizedBox(height: 8),
            if (gameHowToPlay.isNotEmpty)
              _mgPdfSection('HOW TO PLAY', gameHowToPlay, primary, secondary,
                  hPad, bodyFont, bodyFontBold),
            if (gameVariations.isNotEmpty)
              _mgPdfSection('VARIATIONS', gameVariations, primary, secondary,
                  hPad, bodyFont, bodyFontBold),
            if (gameTeachingPoints.isNotEmpty)
              _mgPdfSection('TEACHING POINTS', gameTeachingPoints, primary,
                  secondary, hPad, bodyFont, bodyFontBold),
            if (gameVideo.isNotEmpty)
              _mgPdfVideoLink(
                  _mgSanitise(gameVideo), secondary, primary, hPad, bodyFont, bodyFontBold),
          ],
        ),
      );
    }

    debugPrint('[PDF] Saving PDF...');
    final safeClub = clubName.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');
    final bytes = await pdf.save();
    debugPrint('[PDF] PDF saved (${bytes.length} bytes), sharing...');
    await Printing.sharePdf(
      bytes: bytes,
      filename: '${safeClub}_${ordered.length}_games.pdf',
    );

    debugPrint('[PDF] Done');
    return null;
  } catch (e, stack) {
    debugPrint('[PDF] ERROR: $e');
    debugPrint('[PDF] STACK: $stack');
    return 'PDF error: $e';
  }
}

// ─── Helpers ─────────────────────────────────────────────────────────────────

bool _mgIsWhite(String hex) {
  final c = hex.trim().replaceAll('#', '').replaceAll(' ', '').toUpperCase();
  return c == 'FFF' || c == 'FFFFFF' || c == 'FFFFFFFF';
}

PdfColor _mgPdfColor(
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

Future<pw.ImageProvider?> _mgPdfImage(Uint8List? bytes) async {
  if (bytes == null || bytes.isEmpty) return null;
  try {
    return await flutterImageProvider(paint.MemoryImage(bytes));
  } catch (_) {
    return null;
  }
}

String _mgSanitise(String text) {
  return text
      .replaceAll(''', "'")
      .replaceAll(''', "'")
      .replaceAll('"', '"')
      .replaceAll('"', '"')
      .replaceAll('–', '-')
      .replaceAll('—', '-')
      .replaceAll('…', '...');
}

Future<double?> _mgImageRatio(Uint8List bytes) async {
  try {
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    final ratio = frame.image.width / frame.image.height;
    frame.image.dispose();
    codec.dispose();
    return ratio;
  } catch (_) {
    return null;
  }
}

Future<Uint8List?> _mgFetchBytes(String? url) async {
  if (url == null || url.isEmpty) return null;
  try {
    final res =
        await http.get(Uri.parse(url)).timeout(const Duration(seconds: 10));
    if (res.statusCode == 200) return res.bodyBytes;
  } catch (_) {}
  return null;
}

// ─── PDF Widgets ─────────────────────────────────────────────────────────────

pw.Widget _mgPdfHeader(
  String gameName,
  String clubName,
  pw.ImageProvider? crestImage,
  PdfColor primary,
  PdfColor secondary,
  pw.Font clubFont,
  pw.Font gameNameFont,
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
                style: pw.TextStyle(font: clubFont, color: PdfColors.white, fontSize: 22),
              ),
              pw.SizedBox(height: 5),
              pw.Container(height: 1, color: PdfColors.white),
              pw.SizedBox(height: 5),
              pw.Text(
                gameName,
                style: pw.TextStyle(font: gameNameFont, color: PdfColors.white, fontSize: 17),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

pw.Widget _mgPdfAccentStripe(
    PdfColor secondary, PdfColor third, bool hasThird) {
  return pw.Column(
    children: [
      pw.Container(height: 2, color: PdfColors.white),
      pw.Container(height: 4, color: secondary),
      if (hasThird) pw.Container(height: 3, color: third),
    ],
  );
}

pw.Widget _mgPdfSection(
  String title,
  String body,
  PdfColor primary,
  PdfColor secondary,
  double hPad,
  pw.Font bodyFont,
  pw.Font bodyFontBold,
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
              style: pw.TextStyle(font: bodyFontBold, color: primary, fontSize: 11, letterSpacing: 1.0),
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
                  decoration: pw.BoxDecoration(color: secondary, shape: pw.BoxShape.circle),
                ),
                pw.Expanded(
                  child: pw.Text(
                    text,
                    style: pw.TextStyle(font: bodyFont, color: PdfColor(0.18, 0.18, 0.18), fontSize: 12, lineSpacing: 3),
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

pw.Widget _mgPdfVideoLink(
    String url, PdfColor secondary, PdfColor primary, double hPad,
    pw.Font bodyFont, pw.Font bodyFontBold) {
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
              style: pw.TextStyle(font: bodyFontBold, color: primary, fontSize: 11, letterSpacing: 1.0),
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
              style: pw.TextStyle(font: bodyFont, color: PdfColor(0.1, 0.4, 0.85), fontSize: 12, decoration: pw.TextDecoration.underline),
            ),
          ),
        ),
      ],
    ),
  );
}

pw.Widget _mgPdfFooter(
  String clubName,
  PdfColor primary,
  PdfColor secondary,
  PdfColor third,
  double hPad,
  bool hasThird,
  pw.Font bodyFont,
  pw.Font bodyFontBold,
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
            pw.Text(clubName,
                style: pw.TextStyle(font: bodyFontBold, color: primary, fontSize: 10)),
            pw.Text('CoachSmart',
                style: pw.TextStyle(font: bodyFont, color: PdfColor(0.7, 0.7, 0.7), fontSize: 10)),
          ],
        ),
      ],
    ),
  );
}
