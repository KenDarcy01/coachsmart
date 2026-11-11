// What the v3 Add Game / Drill page needs from outside: the AI flag, the two
// edge functions the web page calls (ai-process-game, diagram-to-drawio),
// pictures to PNG, and photos from the camera or library. Tests replace it.
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';

import '/backend/supabase/supabase.dart';
import '../games/v3_games.dart';
import '../games/v3_scene.dart';
import 'v3_game_upload_models.dart';

class V3GameUploadServices {
  const V3GameUploadServices();

  /// users.ai_features for the signed-in coach (get_my_ai_features).
  Future<bool> aiEnabled() async {
    try {
      return (await SupaFlow.client.rpc('get_my_ai_features')) == true;
    } catch (_) {
      return false;
    }
  }

  /// ai-process-game: the JSON answer, errors included.
  Future<Map<String, dynamic>> aiProcessGame(Map<String, dynamic> body) =>
      _invoke('ai-process-game', body);

  /// diagram-to-drawio: the JSON answer, errors included.
  Future<Map<String, dynamic>> diagram(Map<String, dynamic> body) =>
      _invoke('diagram-to-drawio', body);

  Future<Map<String, dynamic>> _invoke(
      String fn, Map<String, dynamic> body) async {
    try {
      final res = await SupaFlow.client.functions.invoke(fn, body: body);
      return _asMap(res.data);
    } on FunctionException catch (e) {
      final m = _asMap(e.details);
      return m.isEmpty ? {'error': 'Server error ${e.status}'} : m;
    }
  }

  static Map<String, dynamic> _asMap(dynamic d) {
    if (d is Map) return Map<String, dynamic>.from(d);
    if (d is String && d.trim().isNotEmpty) {
      try {
        final j = jsonDecode(d);
        if (j is Map) return Map<String, dynamic>.from(j);
      } catch (_) {}
      return {'error': d.trim()};
    }
    return {};
  }

  /// The sketch at 600 x 600, the size the web page uploads.
  Future<Uint8List> sketchPng(DrillSketch s) =>
      renderDrillSketchPng(s, size: const Size(600, 600), pixelRatio: 1);

  /// An AI diagram as the PNG the web page uploads.
  Future<Uint8List> diagramPng(V3Diagram d, double pixelRatio) =>
      renderDiagramPng(d, pixelRatio: pixelRatio);

  /// Photos from the camera or the library (at most [max]), each made
  /// into a 1024px and a 2048px JPEG as the web page does.
  Future<List<GuPhoto>> pickPhotos(
      {required bool camera, required int max}) async {
    if (max <= 0) return const [];
    final picker = ImagePicker();
    final files = camera
        ? [
            if (await picker.pickImage(
                    source: ImageSource.camera,
                    maxWidth: 2048,
                    maxHeight: 2048,
                    imageQuality: 90)
                case final f?)
              f
          ]
        : await picker.pickMultiImage(
            maxWidth: 2048, maxHeight: 2048, imageQuality: 90);
    final out = <GuPhoto>[];
    for (final f in files.take(max)) {
      final p = await compute(guCompressPhoto, await f.readAsBytes());
      if (p != null) out.add(p);
    }
    return out;
  }
}

/// A photo as a 1024px JPEG (quality 80) and a 2048px JPEG (quality 85),
/// or null if it cannot be read.
GuPhoto? guCompressPhoto(Uint8List bytes) {
  final src = img.decodeImage(bytes);
  if (src == null) return null;
  final upright = img.bakeOrientation(src);
  Uint8List jpeg(int max, int q) {
    var i = upright;
    if (i.width > max || i.height > max) {
      i = i.width >= i.height
          ? img.copyResize(i, width: max)
          : img.copyResize(i, height: max);
    }
    return img.encodeJpg(i, quality: q);
  }

  return GuPhoto(GuImage(jpeg(1024, 80), 'image/jpeg'),
      GuImage(jpeg(2048, 85), 'image/jpeg'));
}
