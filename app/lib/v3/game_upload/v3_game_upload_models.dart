// Pure rules for the v3 "Add Game / Drill" page (webviews/game-upload.html):
// what can be created, the edge-function bodies, and reading the answers.
import 'dart:convert';
import 'dart:typed_data';

/// Options on the draft form (the web page's select and chips).
const kGuTypes = ['Game', 'Drill', 'Skill', 'Warmup', 'Video'];
const kGuAges = ['U6', 'U8', 'U10', 'U12', 'U14', 'U16', 'U18', 'Adult'];
const kGuCodes = ['Football', 'Hurling', 'Camogie'];
const kGuSkills = [
  'Handpass',
  'Kick Pass',
  'Catching',
  'Solo',
  'Shooting',
  'Tackling',
  'Blocking',
  'Fielding'
];

/// Up to four photos per game (the web page's limit).
const kGuMaxPhotos = 4;

/// A description this long is enough for the AI to draw from.
const kGuMinWords = 20;

enum GuMedia { photo, sketch }

/// A picture to send: bytes and their type.
class GuImage {
  const GuImage(this.bytes, this.mimeType);
  final Uint8List bytes;
  final String mimeType;
  String get base64 => base64Encode(bytes);
  Map<String, dynamic> toJson() => {'base64': base64, 'mimeType': mimeType};
}

/// A photo added by the coach: a 1024px copy for the form and the text AI,
/// and a sharper 2048px copy for the diagram AI.
class GuPhoto {
  const GuPhoto(this.form, this.hires);
  final GuImage form;
  final GuImage hires;
}

/// AI users can skip the picture: a sentence or two is enough.
bool guHasWords(bool ai, String words) =>
    ai && words.trim().length >= kGuMinWords;

/// Create Draft / Continue is enabled.
bool guCanCreate(
        {required GuMedia tab,
        required int photos,
        required bool drawn,
        required bool ai,
        required String words}) =>
    (tab == GuMedia.photo && photos > 0) ||
    (tab == GuMedia.sketch && drawn) ||
    guHasWords(ai, words);

/// No sketch or photo, so the diagram and fields come from the description.
bool guFromWords(
        {required GuMedia tab,
        required int photos,
        required bool drawn,
        required bool ai,
        required String words}) =>
    guHasWords(ai, words) &&
    ((tab == GuMedia.sketch && !drawn) ||
        (tab != GuMedia.sketch && photos == 0));

/// Why a draft cannot be made yet, or null.
String? guMissingSource(
    {required GuMedia tab,
    required int photos,
    required bool drawn,
    required bool ai}) {
  if (tab == GuMedia.sketch) {
    if (!drawn) {
      return ai
          ? 'Draw something, or describe the drill below'
          : 'Draw something first';
    }
    return null;
  }
  if (photos == 0) {
    return ai
        ? 'Add a photo, or describe the drill below (a sentence or two)'
        : 'Add at least one photo to continue';
  }
  return null;
}

/// The processing screen's timer line.
String guElapsed(int s) {
  if (s < 90) return '${s}s elapsed — usually takes 60–90 seconds';
  final ss = '${s % 60}'.padLeft(2, '0');
  return '${s ~/ 60}:$ss elapsed — almost there…';
}

/// The options the AI suggested, matched without case. Nothing suggested
/// leaves [current] as it is (the page's _preselectChips).
List<String> guPreselect(
    List<String> options, List<String> current, Iterable<dynamic>? wanted) {
  final w = [for (final v in wanted ?? const []) '$v'.toLowerCase()];
  if (w.isEmpty) return current;
  return [
    for (final o in options)
      if (w.contains(o.toLowerCase())) o
  ];
}

/// The suggested type as one of [kGuTypes], or null.
String? guMatchType(String? t) {
  if (t == null) return null;
  for (final o in kGuTypes) {
    if (o.toLowerCase() == t.trim().toLowerCase()) return o;
  }
  return null;
}

/// Codes to preselect: the diagram's (e.g. hurling, camogie), else the
/// text AI's sport guess.
List<String> guDraftCodes(List<String> diagramCodes, String? sport) =>
    diagramCodes.isNotEmpty
        ? diagramCodes
        : (sport != null && sport.isNotEmpty ? [sport] : const []);

/// Hurling and camogie have no kick pass: the chip is hidden when only
/// those codes are picked.
List<String> guVisibleSkills(List<String> codes) {
  final noKick = codes.isNotEmpty && !codes.contains('Football');
  return [
    for (final s in kGuSkills)
      if (!(noKick && s == 'Kick Pass')) s
  ];
}

/// The text fields of a draft (ai-process-game answers).
class GuDraft {
  const GuDraft(
      {this.name = '',
      this.setup = '',
      this.howTo = '',
      this.variations = '',
      this.teaching = '',
      this.type,
      this.ages = const [],
      this.sport,
      this.skills = const []});

  factory GuDraft.fromJson(Map m) {
    String s(String k) => m[k] is String ? m[k] as String : '';
    List<String> l(String k) =>
        m[k] is List ? [for (final v in m[k] as List) '$v'] : const [];
    return GuDraft(
        name: s('game_name'),
        setup: s('game_setup'),
        howTo: s('game_how_to_play'),
        variations: s('game_variations'),
        teaching: s('game_teaching_points'),
        type: m['suggested_type'] is String
            ? m['suggested_type'] as String
            : null,
        ages: l('suggested_ages'),
        sport: m['suggested_sport'] is String
            ? m['suggested_sport'] as String
            : null,
        skills: l('suggested_skills'));
  }

  final String name, setup, howTo, variations, teaching;
  final String? type, sport;
  final List<String> ages, skills;
}

/// An edge-function failure, worded for the coach.
class GuError implements Exception {
  const GuError(this.message);
  final String message;
  @override
  String toString() => message;
}

/// ai-process-game's { success, data }: the data, or a GuError
/// ("AI processing failed (detail)").
Map<String, dynamic> guUnwrapAi(Map r) {
  if (r['success'] != true) {
    final detail = r['detail'];
    throw GuError('${r['error'] ?? 'AI processing failed'}'
        '${detail != null && '$detail'.isNotEmpty ? ' ($detail)' : ''}');
  }
  final d = r['data'];
  return d is Map ? Map<String, dynamic>.from(d) : {};
}

/// Fields and pictures to a draft (action split_voice).
Map<String, dynamic> guSplitVoiceBody(
        String description, List<GuImage> images) =>
    {
      'action': 'split_voice',
      'voice_transcript': description,
      'game_code': <String>[],
      'images': [for (final i in images) i.toJson()],
    };

/// Revise the draft from what the coach said.
Map<String, dynamic> guReviseBody(
        {required String name,
        required String setup,
        required String howTo,
        required String variations,
        required String teaching,
        required String feedback}) =>
    {
      'action': 'revise_with_feedback',
      'game_name': name.trim(),
      'game_setup': setup.trim(),
      'game_how_to_play': howTo.trim(),
      'game_variations': variations.trim(),
      'game_teaching_points': teaching.trim(),
      'feedback': feedback,
    };

/// What stops a save, or null.
String? guSaveProblem(
    {required String name,
    required String? type,
    required List<String> codes}) {
  if (name.trim().isEmpty) return 'Game name is required';
  if (type == null || type.isEmpty) return 'Please select a Type';
  if (codes.isEmpty) {
    return 'Please select a Code (Football / Hurling / Camogie)';
  }
  return null;
}

/// Saves the game (action save_game).
Map<String, dynamic> guSaveBody(
        {required String name,
        required String type,
        required List<String> ages,
        required List<String> codes,
        required List<String> skills,
        required String setup,
        required String howTo,
        required String variations,
        required String teaching,
        required String video,
        GuImage? image}) =>
    {
      'action': 'save_game',
      'game_name': name.trim(),
      'game_age': ages,
      'game_code': codes,
      'game_skill': skills.isEmpty ? null : skills,
      'game_type': [type],
      'game_setup': setup.trim(),
      'game_how_to_play': howTo.trim(),
      'game_variations': variations.trim(),
      'game_teaching_points': teaching.trim(),
      'image_base64': image?.base64,
      'image_mime_type': image?.mimeType,
      'game_video': video.trim().isEmpty ? null : video.trim(),
    };

/// A change asked for on an AI drawing.
class GuFix {
  const GuFix(
      {required this.scene,
      required this.instruction,
      this.notes = '',
      this.drawing});
  final Map scene;
  final String instruction, notes;
  final String? drawing;
}

/// A diagram-to-drawio request: from a picture ([image]) or from words
/// ([drawing]); [fix] redraws an earlier scene; [notes] is the coach's
/// description so the drawing is read as they meant it.
Map<String, dynamic> guDiagramBody(
    {GuImage? image, GuFix? fix, String notes = '', String? drawing}) {
  final words = (fix?.drawing?.isNotEmpty == true ? fix!.drawing : null) ??
      (drawing?.isNotEmpty == true ? drawing : null) ??
      '';
  return {
    if (image != null) 'image_base64': image.base64,
    if (image != null) 'media_type': image.mimeType,
    if (words.isNotEmpty) 'drawing': words,
    if (fix != null) ...{
      'scene': fix.scene,
      'instruction': fix.instruction,
      'notes': fix.notes,
    } else
      'notes': notes,
  };
}

/// The "look at your own drawing once" request after drawing from words.
Map<String, dynamic> guCheckBody(
        {required String drawing,
        required String notes,
        required Map scene,
        required String pngBase64}) =>
    {
      'drawing': drawing,
      'notes': notes,
      'scene': scene,
      'check_image_base64': pngBase64,
    };

/// A diagram-to-drawio answer.
class GuDiagramAnswer {
  const GuDiagramAnswer(
      {this.xml, this.scene, this.gameName, this.codes = const [], this.error});

  factory GuDiagramAnswer.fromJson(Map m) {
    final xml = m['xml'] is String && (m['xml'] as String).isNotEmpty
        ? m['xml'] as String
        : null;
    final err = m['error'] ?? m['detail'];
    return GuDiagramAnswer(
        xml: xml,
        scene: m['scene'] is Map ? Map<String, dynamic>.from(m['scene']) : null,
        gameName:
            m['game_name'] is String && (m['game_name'] as String).isNotEmpty
                ? m['game_name'] as String
                : null,
        codes: m['suggested_codes'] is List
            ? [for (final c in m['suggested_codes'] as List) '$c']
            : const [],
        error: m['error'] != null || xml == null
            ? '${err ?? 'no xml returned'}'
            : null);
  }

  final String? xml;
  final Map<String, dynamic>? scene;
  final String? gameName;
  final List<String> codes;
  final String? error;
  bool get ok => error == null;
}

/// The line under the diagram saying what the AI tidied.
String guTidied(Map? scene) {
  final t = scene?['tidied'];
  final s = t is String ? t.trim() : '';
  return s.isEmpty ? '' : 'Tidied: $s';
}

/// Example for the revise panel; hurling and camogie never say kick.
String guRevisePlaceholder(List<String> codes) {
  final noKick = codes.isNotEmpty && !codes.contains('Football');
  return 'e.g. make the setup shorter, add a U10 variation, focus more on '
      '${noKick ? 'scoring' : 'kicking'}';
}
