// Games and drills library: the data model shared by every v3 page that
// shows coaching games (Resources, Favourites, Session plan, Add a resource).
//
// A "game" is one row of public.games. Rows with club_id NULL are public;
// rows with a club_id belong to that club only (webviews/games-resource-v2.html
// loads `club_id IS NULL OR club_id = <my default club>`).
//
// Everything here is pure Dart (no Flutter, no network) so it can be unit
// tested and reused freely.

/// The columns every games query selects (same list as the web page).
const String kGameColumns = 'game_id,game_name,game_age,game_code,game_type,'
    'game_skill,game_setup,game_how_to_play,game_variations,'
    'game_teaching_points,game_pdf,game_video,game_image,club_id,created_by';

/// Accounts that may delete any game (mirrors GAME_ADMINS in the web page
/// and in the ai-process-game edge function, which enforces it).
const List<String> kGameAdmins = ['ken.darcy@gmail.com'];

/// The kind of resource, from the first entry of `game_type`.
enum GameKind { game, warmup, drill, skill, video }

int _i(dynamic v) =>
    v is int ? v : (v is num ? v.toInt() : int.tryParse('$v') ?? 0);
int? _iN(dynamic v) => v == null ? null : _i(v);
String _s(dynamic v) => v == null ? '' : '$v';

/// Text arrays arrive as JSON lists; very old rows may hold a comma string.
List<String> _list(dynamic v) {
  if (v == null) return const [];
  if (v is List) {
    return [
      for (final e in v)
        if (e != null && '$e'.trim().isNotEmpty) '$e'.trim()
    ];
  }
  final s = '$v'.trim();
  if (s.isEmpty) return const [];
  return [
    for (final p in s.replaceAll(RegExp(r'^\{|\}$'), '').split(','))
      if (p.trim().replaceAll('"', '').isNotEmpty) p.trim().replaceAll('"', '')
  ];
}

/// One game, drill, warmup, skill or video from public.games.
class V3Game {
  const V3Game({
    required this.gameId,
    required this.name,
    this.ages = const [],
    this.codes = const [],
    this.types = const [],
    this.skills = const [],
    this.setup = '',
    this.howToPlay = '',
    this.variations = '',
    this.teachingPoints = '',
    this.pdf = '',
    this.video = '',
    this.image = '',
    this.clubId,
    this.createdBy = '',
  });

  factory V3Game.fromJson(Map j) => V3Game(
        gameId: _i(j['game_id']),
        name: _s(j['game_name']),
        ages: _list(j['game_age']),
        codes: _list(j['game_code']),
        types: _list(j['game_type']),
        skills: _list(j['game_skill']),
        setup: _s(j['game_setup']),
        howToPlay: _s(j['game_how_to_play']),
        variations: _s(j['game_variations']),
        teachingPoints: _s(j['game_teaching_points']),
        pdf: _s(j['game_pdf']),
        video: _s(j['game_video']),
        image: _s(j['game_image']),
        clubId: _iN(j['club_id']),
        createdBy: _s(j['created_by']),
      );

  final int gameId;
  final String name;

  /// Age groups, e.g. ['u8', 'u9'] (compare case-insensitively).
  final List<String> ages;

  /// Codes, e.g. ['Football', 'Hurling'].
  final List<String> codes;

  /// Types, e.g. ['Game'], ['Warmup'], ['Drill'], ['Skills'], ['Video'].
  final List<String> types;
  final List<String> skills;
  final String setup, howToPlay, variations, teachingPoints;
  final String pdf, video, image;

  /// Null for a public game; the owning club otherwise.
  final int? clubId;

  /// auth user id of the coach who added it ('' for older rows).
  final String createdBy;

  Map<String, dynamic> toJson() => {
        'game_id': gameId,
        'game_name': name,
        'game_age': ages,
        'game_code': codes,
        'game_type': types,
        'game_skill': skills,
        'game_setup': setup,
        'game_how_to_play': howToPlay,
        'game_variations': variations,
        'game_teaching_points': teachingPoints,
        'game_pdf': pdf,
        'game_video': video,
        'game_image': image,
        'club_id': clubId,
        'created_by': createdBy,
      };

  V3Game copyWith({
    String? name,
    List<String>? codes,
    List<String>? types,
    String? setup,
    String? howToPlay,
    String? variations,
    String? teachingPoints,
    String? video,
    String? image,
  }) =>
      V3Game(
        gameId: gameId,
        name: name ?? this.name,
        ages: ages,
        codes: codes ?? this.codes,
        types: types ?? this.types,
        skills: skills,
        setup: setup ?? this.setup,
        howToPlay: howToPlay ?? this.howToPlay,
        variations: variations ?? this.variations,
        teachingPoints: teachingPoints ?? this.teachingPoints,
        pdf: pdf,
        video: video ?? this.video,
        image: image ?? this.image,
        clubId: clubId,
        createdBy: createdBy,
      );

  Iterable<String> get _typesLower => types.map((t) => t.toLowerCase());

  /// Kind from the first type (web primaryType()).
  GameKind get kind => primaryKind(types);

  bool get isSkill => types.any((t) => t == 'Skills' || t == 'Skill');
  bool get isVideo => _typesLower.contains('video');
  bool get isWarmup => _typesLower.contains('warmup');
  bool get isDrill => _typesLower.contains('drill');

  /// A plain "game": none of warmup, drill, skill(s) or video.
  bool get isPlainGame => !_typesLower.any((t) =>
      t == 'warmup' ||
      t == 'drill' ||
      t == 'skill' ||
      t == 'skills' ||
      t == 'video');

  /// Skills rows have no heart and cannot be deleted.
  bool get canFavourite => !isSkill;

  /// Something to show: a picture, any text section, a video or a PDF.
  /// Rows without content are hidden from lists (web hasContent()).
  bool get hasContent =>
      image.trim().isNotEmpty ||
      setup.trim().isNotEmpty ||
      howToPlay.trim().isNotEmpty ||
      variations.trim().isNotEmpty ||
      teachingPoints.trim().isNotEmpty ||
      video.trim().isNotEmpty ||
      pdf.trim().isNotEmpty;

  /// True when any of the game's ages is in [ages] (case-insensitive).
  bool matchesAges(Iterable<String> ages) {
    final set = ages.map((a) => a.toLowerCase()).toSet();
    return this.ages.any((a) => set.contains(a.toLowerCase()));
  }

  /// YouTube video id when [video] is a YouTube link, else null.
  String? get youtubeId => youtubeIdOf(video);

  /// Numbered steps and intro text of "How to play".
  GameSteps get steps => splitSteps(howToPlay);

  /// The "Make it harder" ideas, from the Variations text.
  List<String> get harderIdeas => splitIdeas(variations);

  /// The club owns this game and it is my club: show Edit.
  bool canEdit(int? myClubId) =>
      clubId != null && myClubId != null && clubId == myClubId;

  /// The coach who added it, or a game admin, may delete it (never Skills).
  bool canDelete({required String userId, required String email}) {
    if (isSkill) return false;
    if (kGameAdmins.contains(email.toLowerCase())) return true;
    return userId.isNotEmpty && createdBy == userId;
  }
}

/// Kind from a type list (web primaryType()): the first entry decides.
GameKind primaryKind(List<String> types) {
  if (types.isEmpty) return GameKind.game;
  switch (types.first.toLowerCase()) {
    case 'warmup':
      return GameKind.warmup;
    case 'drill':
      return GameKind.drill;
    case 'skill':
    case 'skills':
      return GameKind.skill;
    case 'video':
      return GameKind.video;
    default:
      return GameKind.game;
  }
}

/// Parses a list of games rows, skipping anything that is not a map.
List<V3Game> parseGames(dynamic rows) => [
      if (rows is List)
        for (final r in rows)
          if (r is Map) V3Game.fromJson(r)
    ];

/// Favourite ids from get_user_game_links (a list of ids or of rows).
Set<int> parseFavouriteIds(dynamic rows) {
  final out = <int>{};
  if (rows is! List) return out;
  for (final r in rows) {
    final v = r is Map ? (r['game_id'] ?? r.values.firstOrNull) : r;
    final id = _i(v);
    if (id != 0) out.add(id);
  }
  return out;
}

final _yt = RegExp(
    r'(?:youtube\.com/(?:watch\?v=|embed/|shorts/)|youtu\.be/)([a-zA-Z0-9_-]{11})');

/// YouTube id in [url], or null (same pattern as the web page).
String? youtubeIdOf(String url) => _yt.firstMatch(url)?.group(1);

/// Thumbnail for a YouTube id.
String youtubeThumb(String id) =>
    'https://img.youtube.com/vi/$id/hqdefault.jpg';

/// "How to play" split into intro lines and numbered steps.
class GameSteps {
  const GameSteps(this.intro, this.steps);
  final List<String> intro;
  final List<String> steps;
}

/// Separates text into intro lines and numbered steps ("1. ..." on their own
/// lines or inline). Fewer than two steps: everything is intro.
/// Port of splitSteps() in supabase/functions/_shared/pdf-kit.ts, so the app
/// shows steps the way the game card and session plan PDFs print them.
GameSteps splitSteps(String text) {
  var t = text.trim();
  if (RegExp(r'(^|\s)1[.)]\s').hasMatch(t) &&
      RegExp(r'\s2[.)]\s').hasMatch(t)) {
    t = t.replaceAll(RegExp(r'\s+(?=\d{1,2}[.)]\s)'), '\n');
  }
  final lines = [
    for (final l in t.split('\n'))
      if (l.trim().isNotEmpty) l.trim()
  ];
  final intro = <String>[], steps = <String>[];
  final num = RegExp(r'^(\d{1,2})[.)]\s+(.*)$');
  for (final line in lines) {
    final m = num.firstMatch(line);
    if (m != null) {
      steps.add(m.group(2)!);
    } else if (steps.isNotEmpty) {
      steps[steps.length - 1] = '${steps.last} $line';
    } else {
      intro.add(line);
    }
  }
  if (steps.length < 2) return GameSteps(lines, const []);
  return GameSteps(intro, steps);
}

/// Splits "• a • b", "- a - b" or multi-line text into separate ideas.
/// Port of splitIdeas() in pdf-kit.ts (the "Make it harder" lines).
List<String> splitIdeas(String text) {
  final t = text.trim();
  if (t.isEmpty) return const [];
  var parts = t.split(RegExp(r'\n+|\s*•\s*'));
  if (RegExp(r'^[-–]\s').hasMatch(t)) {
    parts = [for (final p in parts) ...p.split(RegExp(r'(?:^|\s)[-–]\s+'))];
  }
  return [
    for (final p in parts)
      if (p.replaceFirst(RegExp(r'^\s*(?:[-–*]|\d+[.)])\s*'), '').trim()
          case final s when s.isNotEmpty)
        s
  ];
}

/// Splits text into its non-empty lines (Setup, Teaching points).
List<String> textLines(String text) => [
      for (final l in text.split('\n'))
        if (l.trim().isNotEmpty) l.trim()
    ];

/// Plural label for a kind, as the stage sections are headed.
String kindSectionLabel(GameKind k) => switch (k) {
      GameKind.video => 'Videos',
      GameKind.warmup => 'Warmups',
      GameKind.drill => 'Drills',
      GameKind.game => 'Games',
      GameKind.skill => 'Skills',
    };

/// Groups [games] into the stage sections, in the page's order
/// (Videos, Warmups, Drills, Games, Skills). A game can sit in more than one
/// section when it has several types, as on the web page.
Map<GameKind, List<V3Game>> groupByKind(Iterable<V3Game> games) {
  final out = {
    GameKind.video: <V3Game>[],
    GameKind.warmup: <V3Game>[],
    GameKind.drill: <V3Game>[],
    GameKind.game: <V3Game>[],
    GameKind.skill: <V3Game>[],
  };
  for (final g in games) {
    if (g.isVideo) out[GameKind.video]!.add(g);
    if (g.isWarmup) out[GameKind.warmup]!.add(g);
    if (g.isDrill) out[GameKind.drill]!.add(g);
    if (g.isPlainGame) out[GameKind.game]!.add(g);
    if (g.isSkill) out[GameKind.skill]!.add(g);
  }
  return out;
}

/// The text shown in the delete confirm.
String deleteGameText(V3Game g) =>
    '"${g.name}" will be removed for everyone, including from anyone\'s '
    'favourites. Saved session plans keep their copy. This can\'t be undone.';
