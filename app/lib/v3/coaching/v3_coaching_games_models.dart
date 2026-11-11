// Rules for the Games half of the v3 Coaching tab: one searchable list of
// every game the coach can see, with Saved, Stage (or Age), Code and Type
// filters (Coaching tab proposal, approved by Ken 2026-11-11).
//
// The stage rule is the Resources page's: a game belongs to a stage when
// any of its ages is one of the stage's ages, and games with nothing to
// show are hidden (see v3_resources_models.dart).
// Pure Dart: no Flutter, no network.
import '../games/v3_game_models.dart';
import '../resources/v3_resources_models.dart';

/// A development stage the coach can filter by, with the pathway it is in.
class CoachingStage {
  const CoachingStage(
      {required this.pathway, required this.stage, required this.number});
  final Pathway pathway;
  final PathwayStage stage;

  /// Its place in the pathway (pathway_display_seq, else its position).
  final int number;

  /// What the Stage pill shows once picked: "Stage 1".
  String get label => 'Stage $number';
}

/// The stages of one pathway, numbered as the Resources page numbers them.
List<CoachingStage> coachingStages(Pathway p, List<PathwayStage> stages) => [
      for (final (i, s) in stages.indexed)
        CoachingStage(pathway: p, stage: s, number: s.seq != 0 ? s.seq : i + 1)
    ];

/// What the coach has typed and picked.
class GamesFilter {
  const GamesFilter(
      {this.query = '', this.saved = false, this.ages, this.code, this.kind});

  /// The search box.
  final String query;

  /// Only hearted games.
  final bool saved;

  /// The picked stage's ages, or the one picked age; null for all.
  final List<String>? ages;

  /// The picked code (Football, Hurling...); null for all.
  final String? code;

  /// The picked type; null for all.
  final GameKind? kind;

  /// Any pill other than All is on.
  bool get hasFilters => saved || ages != null || code != null || kind != null;

  bool get isEmpty => !hasFilters && query.trim().isEmpty;
}

/// Section order and headings of the list.
const List<GameKind> kCoachingKinds = [
  GameKind.warmup,
  GameKind.drill,
  GameKind.game,
  GameKind.skill,
  GameKind.video,
];

String coachingKindLabel(GameKind k) => switch (k) {
      GameKind.warmup => 'Warm-ups',
      GameKind.drill => 'Drills',
      GameKind.game => 'Games',
      GameKind.skill => 'Skills',
      GameKind.video => 'Videos',
    };

/// The kinds a game is listed under (a game with several types sits in
/// several sections, as on the Resources page).
Set<GameKind> kindsOf(V3Game g) => {
      if (g.isWarmup) GameKind.warmup,
      if (g.isDrill) GameKind.drill,
      if (g.isPlainGame) GameKind.game,
      if (g.isSkill) GameKind.skill,
      if (g.isVideo) GameKind.video,
    };

String _norm(String s) =>
    s.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), ' ').trim();

/// The text the search box looks in: name, skills, types, codes, and the
/// section names ("warm up", "drills") so plain words find them.
String searchText(V3Game g) => _norm([
      g.name,
      ...g.skills,
      ...g.types,
      ...g.codes,
      for (final k in kindsOf(g)) coachingKindLabel(k),
      if (g.isWarmup) 'warmup',
    ].join(' '));

/// True when every word typed is somewhere in the game's name, skills,
/// type or code. Case and punctuation don't matter; an empty box matches.
bool matchesSearch(V3Game g, String query) {
  final words = _norm(query).split(' ').where((w) => w.isNotEmpty);
  if (words.isEmpty) return true;
  final text = searchText(g);
  return words.every(text.contains);
}

/// The games to list for [f]. Games with nothing to show are always hidden.
List<V3Game> filterGames(
        List<V3Game> games, GamesFilter f, Set<int> favourites) =>
    [
      for (final g in games)
        if (g.hasContent &&
            (!f.saved || favourites.contains(g.gameId)) &&
            (f.ages == null || g.matchesAges(f.ages!)) &&
            (f.code == null || g.codes.contains(f.code)) &&
            (f.kind == null || kindsOf(g).contains(f.kind)) &&
            matchesSearch(g, f.query))
          g
    ];

/// [games] under their headings, in list order, empty sections left out.
/// [only] keeps one section (the Type filter).
List<(GameKind, List<V3Game>)> coachingSections(List<V3Game> games,
    {GameKind? only}) {
  final grouped = groupByKind(games);
  return [
    for (final k in kCoachingKinds)
      if ((only == null || only == k) && (grouped[k] ?? const []).isNotEmpty)
        (k, grouped[k]!)
  ];
}

/// Codes to offer in the Code sheet: every code on a listable game, plus
/// [extra] (codes on the picked stage's pathway content), sorted.
List<String> gameCodes(List<V3Game> games,
        [Iterable<String> extra = const []]) =>
    ({
      for (final g in games)
        if (g.hasContent) ...g.codes,
      ...extra,
    }.toList()
      ..sort());

/// Types to offer in the Type sheet: the ones that have games.
List<GameKind> gameKinds(List<V3Game> games) {
  final have = {
    for (final g in games)
      if (g.hasContent) ...kindsOf(g)
  };
  return [
    for (final k in kCoachingKinds)
      if (have.contains(k)) k
  ];
}

int _ageNumber(String a) =>
    int.tryParse(RegExp(r'\d+').firstMatch(a)?.group(0) ?? '') ?? 999;

/// Ages to offer in the Age sheet (clubs with no pathway): every age on a
/// listable game, youngest first, lower case ('u8').
List<String> gameAges(List<V3Game> games) {
  final set = {
    for (final g in games)
      if (g.hasContent)
        for (final a in g.ages) a.toLowerCase()
  };
  return set.toList()
    ..sort((a, b) {
      final c = _ageNumber(a).compareTo(_ageNumber(b));
      return c != 0 ? c : a.compareTo(b);
    });
}

/// "u8" -> "U8".
String ageLabel(String age) => age.toUpperCase();

/// "1 game", "3 games".
String gamesCount(int n) => '$n game${n == 1 ? '' : 's'}';

/// The green bar: "2 games in your plan · 20 min".
String planBarText(int count, int mins) =>
    '${gamesCount(count)} in your plan · $mins min';

/// The bar when the plan builder opened the list to add games.
String pickDoneText(int count) => 'Done · ${gamesCount(count)} in your plan';

const String kPlanFullText = 'A plan holds up to 10 games';
const String kNoMatchText = 'No games match. Clear the filters.';
const String kNoSavedText = 'Tap the heart on a game to save it.';

/// Which empty message fits: nothing hearted yet (Saved is on and no
/// listable game is hearted), or nothing matches.
String emptyText(List<V3Game> games, GamesFilter f, Set<int> favourites) {
  if (games.every((g) => !g.hasContent)) return 'No games yet.';
  if (f.saved &&
      !games.any((g) => g.hasContent && favourites.contains(g.gameId))) {
    return kNoSavedText;
  }
  return kNoMatchText;
}
