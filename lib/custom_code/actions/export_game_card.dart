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

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:screenshot/screenshot.dart';
import 'package:share_plus/share_plus.dart';
import 'package:universal_html/html.dart' as html;

Future<void> exportGameCard(
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
  final Color primary = _hexToColor(primaryColour ?? '#2E7D32');
  final Color secondary = _hexToColor(secondaryColour ?? '#FFC107');
  final Color third = _hexToColor(thirdColour ?? '#1565C0');

  final Uint8List? crestBytes = await _fetchBytes(clubCrest);
  final Uint8List? gameImageBytes = await _fetchBytes(gameImageUrl);

  final controller = ScreenshotController();
  final resolvedName = gameName ?? '';

  // Use a tall targetSize so content is never clipped, then trim whitespace
  final Uint8List rawBytes = await controller.captureFromWidget(
    _GameCard(
      gameName: resolvedName,
      gameSetup: gameSetup ?? '',
      gameHowToPlay: gameHowToPlay ?? '',
      gameVariations: gameVariations ?? '',
      gameTeachingPoints: gameTeachingPoints ?? '',
      gameImageBytes: gameImageBytes,
      clubName: clubName,
      crestBytes: crestBytes,
      primaryColor: primary,
      secondaryColor: secondary,
      thirdColor: third,
    ),
    pixelRatio: 2.0,
    targetSize: const Size(400, 5000),
  );

  final Uint8List pngBytes = _trimWhiteBottom(rawBytes);
  final safeName = resolvedName.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');

  if (kIsWeb) {
    final blob = html.Blob([pngBytes], 'image/png');
    final url = html.Url.createObjectUrlFromBlob(blob);
    html.AnchorElement(href: url)
      ..setAttribute('download', '$safeName.png')
      ..click();
    html.Url.revokeObjectUrl(url);
  } else {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/game_$safeName.png');
    await file.writeAsBytes(pngBytes);
    await Share.shareXFiles(
      [XFile(file.path, mimeType: 'image/png')],
      subject: resolvedName,
    );
  }
}

// Scans from the bottom and trims fully-white rows
Uint8List _trimWhiteBottom(Uint8List pngBytes) {
  final decoded = img.decodeImage(pngBytes);
  if (decoded == null) return pngBytes;

  int lastContentRow = 0;
  for (int y = decoded.height - 1; y >= 0; y--) {
    bool hasContent = false;
    for (int x = 0; x < decoded.width; x++) {
      final p = decoded.getPixel(x, y);
      if (p.r < 250 || p.g < 250 || p.b < 250) {
        hasContent = true;
        break;
      }
    }
    if (hasContent) {
      lastContentRow = y;
      break;
    }
  }

  final cropped = img.copyCrop(
    decoded,
    x: 0,
    y: 0,
    width: decoded.width,
    height: lastContentRow + 30, // 30px breathing room below last content
  );
  return Uint8List.fromList(img.encodePng(cropped));
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

Color _hexToColor(String hex) {
  final c = hex.replaceAll('#', '');
  return Color(int.parse(c.length == 6 ? 'FF$c' : c, radix: 16));
}

class _GameCard extends StatelessWidget {
  final String gameName;
  final String gameSetup;
  final String gameHowToPlay;
  final String gameVariations;
  final String gameTeachingPoints;
  final Uint8List? gameImageBytes;
  final String clubName;
  final Uint8List? crestBytes;
  final Color primaryColor;
  final Color secondaryColor;
  final Color thirdColor;

  const _GameCard({
    required this.gameName,
    required this.gameSetup,
    required this.gameHowToPlay,
    required this.gameVariations,
    required this.gameTeachingPoints,
    this.gameImageBytes,
    required this.clubName,
    this.crestBytes,
    required this.primaryColor,
    required this.secondaryColor,
    required this.thirdColor,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      child: SizedBox(
        width: 400,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            _header(),
            _accentStripe(),
            // HOW TO SET UP above the image
            if (gameSetup.isNotEmpty) _preImageSetup(),
            if (gameImageBytes != null) _gameImage(),
            // Remaining sections below the image
            _postImageContent(),
            _footer(),
          ],
        ),
      ),
    );
  }

  Widget _header() {
    return Container(
      color: primaryColor,
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (crestBytes != null) ...[
            SizedBox(
              width: 84,
              height: 84,
              child: Image.memory(crestBytes!, fit: BoxFit.contain),
            ),
            const SizedBox(width: 16),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  clubName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 7),
                  child: Container(
                    height: 1,
                    color: Colors.white.withOpacity(0.4),
                  ),
                ),
                Text(
                  gameName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _accentStripe() {
    return Row(
      children: [
        Expanded(flex: 6, child: Container(height: 4, color: secondaryColor)),
        Expanded(flex: 2, child: Container(height: 4, color: thirdColor)),
      ],
    );
  }

  // HOW TO SET UP — above the image, lighter padding
  Widget _preImageSetup() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 18, 24, 12),
      child: _section('HOW TO SET UP', gameSetup),
    );
  }

  Widget _gameImage() => Image.memory(
        gameImageBytes!,
        width: double.infinity,
        fit: BoxFit.contain,
      );

  // HOW TO PLAY, VARIATIONS, TEACHING POINTS — below the image
  Widget _postImageContent() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (gameHowToPlay.isNotEmpty) _section('HOW TO PLAY', gameHowToPlay),
          if (gameVariations.isNotEmpty) _section('VARIATIONS', gameVariations),
          if (gameTeachingPoints.isNotEmpty)
            _section('TEACHING POINTS', gameTeachingPoints),
        ],
      ),
    );
  }

  Widget _section(String title, String body) {
    final lines = body.split('\n').where((l) => l.trim().isNotEmpty).toList();
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 3,
                height: 14,
                decoration: BoxDecoration(
                  color: secondaryColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  color: primaryColor,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 7),
          ...lines.map(
            (line) => Padding(
              padding: const EdgeInsets.only(bottom: 4, left: 11),
              child: Text(
                line,
                style: const TextStyle(
                  color: Color(0xFF2D2D2D),
                  fontSize: 12,
                  height: 1.5,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _footer() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 4, 24, 18),
      child: Column(
        children: [
          Container(height: 1.5, color: thirdColor),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                clubName,
                style: TextStyle(
                  color: primaryColor,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                'CoachSmart',
                style: TextStyle(color: Colors.grey.shade400, fontSize: 10),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
