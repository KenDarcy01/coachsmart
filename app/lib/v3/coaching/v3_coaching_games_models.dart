// Rules for the Games half of the v3 Coaching tab (Coaching tab proposal
// and the pathway-first rework, both approved by Ken 2026-11-11).
//
// A club with a pathway opens on its stages: each stage card shows its ages
// and how many games it holds, and the games are browsed inside a stage.
// Search and Saved cut across every stage. A club with no pathway gets one
// flat list with Saved, Age, Code and Type filters.
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

  /// The stage page's title and the tag on a search result: "Stage 1".
  String get label => 'Stage $number';
}

/// The stages of one pathway, numbered as the Resources page numbers them.
List<CoachingStage> coachingStages(Pathway p, List<PathwayStage> stages) => [
      for (final (i, s) in stages.indexed)
        CoachingStage(pathway: p, stage: s, number: s.seq != 0 ? s.seq : i + 1)
    ];

final _stageN = RegExp(r'^stage\s*\d+$', caseSensitive: false);

/// The words on a stage card: the stage's description ("Learning to Master
/// the Ball"). Where a pathway names its stages "Stage 1" and keeps the
/// words in the description, the description is used; otherwise the name.
String stageTitle(PathwayStage s) {
  final name = s.name.trim(), desc = s.desc.trim();
  if (desc.isNotEmpty && (name.isEmpty || _stageN.hasMatch(name))) return desc;
  return name;
}

/// Any longer text to show under [stageTitle] on the stage page; '' when
/// the title already says it all.
String stageBlurb(PathwayStage s) {
  final title = stageTitle(s), name = s.name.trim(), desc = s.desc.trim();
  if (desc.isNotEmpty && desc != title) return desc;
  if (name != title && !_stageN.hasMatch(name)) return name;
  return '';
}

/// "U4 to U6" for a run of ages, "U8" for one, "U8, U10" when they skip.
String agesRange(List<String> ages) {
  final sorted = [...ages]
    ..sort((a, b) => _ageNumber(a).compareTo(_ageNumber(b)));
  if (sorted.isEmpty) return '';
  final first = _ageNumber(sorted.first), last = _ageNumber(sorted.last);
  if (sorted.length > 1 && last - first == sorted.length - 1) {
    return '${ageLabel(sorted.first)} to ${ageLabel(sorted.last)}';
  }
  return sorted.map(ageLabel).join(', ');
}

/// The second line of a stage card: "U4 to U6 · 14 games".
String stageCardLine(List<String> ages, int count) =>
    [if (ages.isNotEmpty) agesRange(ages), gamesCount(count)].join(' · ');

/// Under the stage page's title: "Learning to Master the Ball · U4 to U6".
String stageHeading(PathwayStage s) => [
      if (stageTitle(s).isNotEmpty) stageTitle(s),
      if (s.ages.isNotEmpty) agesRange(s.ages)
    ].join(' · ');

/// The heading over a pathway's stages: "TURAS pathway".
String pathwayHeading(String name) {
  final n = name.trim();
  if (n.isEmpty) return 'Pathway';
  return n.toLowerCase().endsWith('pathway') ? n : '$n pathway';
}

/// The games a coach sees inside [s], for the Code and Type picked.
List<V3Game> stageGames(List<V3Game> games, CoachingStage s,
        {String? code, GameKind? kind}) =>
    filterGames(
        games, GamesFilter(ages: s.stage.ages, code: code, kind: kind), {});

/// Games that belong to no stage ("Other games"), for the Code and Type.
List<V3Game> otherGames(List<V3Game> games, List<CoachingStage> stages,
        {String? code, GameKind? kind}) =>
    [
      for (final g
          in filterGames(games, GamesFilter(code: code, kind: kind), {}))
        if (!stages.any((s) => g.matchesAges(s.stage.ages))) g
    ];

/// The stage tag on a search or Saved result: "Stage 1", "Stages 1, 2"
/// when its ages span stages, '' when it is in none.
String stageTag(V3Game g, List<CoachingStage> stages) {
  final numbers = <int>{
    for (final s in stages)
      if (g.matchesAges(s.stage.ages)) s.number
  }.toList()
    ..sort();
  if (numbers.isEmpty) return '';
  return numbers.length == 1
      ? 'Stage ${numbers.first}'
      : 'Stages ${numbers.join(', ')}';
}

/// The heading over search or Saved results: "3 saved games", "5 games".
String resultsCountText(int n, {required bool saved}) =>
    saved ? '$n saved game${n == 1 ? '' : 's'}' : gamesCount(n);

const String kOtherGamesTitle = 'Other games';
const String kNoStageGamesText = 'No games here yet.';

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
