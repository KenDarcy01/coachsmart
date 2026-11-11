// Data and rules for the v3 Resources page, a native copy of
// webviews/games-resource-v2.html (the TURAS games and drills library).
//
// A club linked to one or more pathways (club_pathway_link) browses
// pathway -> development stage -> resources. A club with no pathway gets the
// original six fixed stages (ages u4..u17) and a filtered games list.
// Pure Dart: no Flutter, no network.
import '../games/v3_game_models.dart';

int _i(dynamic v) =>
    v is int ? v : (v is num ? v.toInt() : int.tryParse('$v') ?? 0);
String _s(dynamic v) => v == null ? '' : '$v';

/// A pathway (pathway_types) the club is linked to.
class Pathway {
  const Pathway(this.id, this.name);
  Pathway.fromJson(Map j)
      : id = _i(j['pathway_type_id']),
        name = _s(j['pathway_name']);
  final int id;
  final String name;
}

/// club_pathway_link rows ({pathway_types: {...}}) -> pathways.
List<Pathway> parsePathways(dynamic rows) => [
      if (rows is List)
        for (final r in rows)
          if (r is Map && r['pathway_types'] is Map)
            Pathway.fromJson(r['pathway_types'] as Map)
          else if (r is Map && r['pathway_type_id'] != null)
            Pathway.fromJson(r)
    ];

/// One development stage of a pathway (pathway_stages).
class PathwayStage {
  const PathwayStage(
      {required this.id,
      required this.name,
      this.desc = '',
      this.ages = const [],
      this.seq = 0});
  PathwayStage.fromJson(Map j)
      : id = _i(j['pathway_stage_id']),
        name = _s(j['pathway_stage']),
        desc = _s(j['pathway_stage_desc']),
        ages = [
          if (j['pathway_ages'] is List)
            for (final a in j['pathway_ages'] as List)
              if (a != null) '$a'
        ],
        seq = _i(j['pathway_display_seq']);
  final int id;
  final String name, desc;
  final List<String> ages;
  final int seq;

  /// "U8, U9"
  String get agesLabel => ages.map((a) => a.toUpperCase()).join(', ');
}

List<PathwayStage> parseStages(dynamic rows) {
  final out = [
    if (rows is List)
      for (final r in rows)
        if (r is Map) PathwayStage.fromJson(r)
  ];
  out.sort((a, b) => a.seq.compareTo(b.seq));
  return out;
}

/// Stage detail categories shown as picture rows.
const String kPlayerPathways = 'Player Pathways';
const String kSampleSessions = 'Sample Sessions';

/// A picture or video resource of a stage (pathway_stage_details).
class StageDetail {
  const StageDetail(
      {required this.id,
      required this.heading,
      this.subheading = '',
      this.imageLink = '',
      this.videoLink = '',
      this.category = '',
      this.codeText});
  StageDetail.fromJson(Map j)
      : id = _i(j['pathway_stage_details_id']),
        heading = _s(j['detail_heading']),
        subheading = _s(j['detail_subheading']),
        imageLink = _s(j['image_link']),
        videoLink = _s(j['video_link']),
        category = _s(j['detail_category']),
        codeText = j['event_codes'] is Map &&
                _s((j['event_codes'] as Map)['event_code']).isNotEmpty
            ? _s((j['event_codes'] as Map)['event_code'])
            : (j['code_text'] == null ? null : _s(j['code_text']));
  final int id;
  final String heading, subheading, imageLink, videoLink, category;

  /// The code it is for (Football, Hurling...), null for every code.
  final String? codeText;
}

List<StageDetail> parseDetails(dynamic rows) => [
      if (rows is List)
        for (final r in rows)
          if (r is Map) StageDetail.fromJson(r)
    ];

/// "3 resources", "1 resource", '' for none.
String resourceCount(int n) => n == 0 ? '' : '$n resource${n == 1 ? '' : 's'}';

/// Games for a stage's ages that have something to show.
int stageResourceCount(PathwayStage s, List<V3Game> games) =>
    games.where((g) => g.matchesAges(s.ages) && g.hasContent).length;

/// Code chips for a stage: All, then every code on its details and on the
/// games for its ages, sorted.
List<String> stageCodes(
    PathwayStage s, List<StageDetail> details, List<V3Game> games) {
  final set = <String>{
    for (final d in details)
      if (d.codeText != null && d.codeText!.isNotEmpty) d.codeText!,
    for (final g in games)
      if (g.matchesAges(s.ages)) ...g.codes,
  };
  return ['All', ...set.toList()..sort()];
}

/// Type chips on a stage. Tapping the active one goes back to All.
const List<String> kStageTypes = [
  'All',
  'Videos',
  'Warmups',
  'Drills',
  'Games',
  'Skills'
];

/// Next type filter after tapping [tapped] while [current] is on.
String nextTypeFilter(String current, String tapped) =>
    (tapped != 'All' && current == tapped) ? 'All' : tapped;

/// Details of [category] for the code (details with no code always show).
List<StageDetail> filteredDetails(
        List<StageDetail> details, String category, String code) =>
    [
      for (final d in details)
        if (d.category == category &&
            (code == 'All' || d.codeText == code || d.codeText == null))
          d
    ];

/// Games for the stage's ages and code, with content.
List<V3Game> filteredStageGames(
        PathwayStage s, List<V3Game> games, String code) =>
    [
      for (final g in games)
        if (g.matchesAges(s.ages) &&
            (code == 'All' || g.codes.contains(code)) &&
            g.hasContent)
          g
    ];

/// What a stage page shows for the chosen code and type.
class StageSections {
  StageSections(
      {required this.playerPathways,
      required this.sampleSessions,
      required this.games});

  final List<StageDetail> playerPathways, sampleSessions;

  /// Videos, Warmups, Drills, Games, Skills (only the ones the type filter
  /// shows and that have games).
  final Map<GameKind, List<V3Game>> games;

  bool get isEmpty =>
      playerPathways.isEmpty &&
      sampleSessions.isEmpty &&
      games.values.every((l) => l.isEmpty);
}

GameKind? _kindOfFilter(String type) => switch (type) {
      'Videos' => GameKind.video,
      'Warmups' => GameKind.warmup,
      'Drills' => GameKind.drill,
      'Games' => GameKind.game,
      'Skills' => GameKind.skill,
      _ => null,
    };

/// The stage sections for [code] and [type] (web renderStageDetailContent).
/// Picture rows ignore the type filter, as on the web page.
StageSections stageSections(PathwayStage s, List<StageDetail> details,
    List<V3Game> games, String code, String type) {
  final grouped = groupByKind(filteredStageGames(s, games, code));
  final only = _kindOfFilter(type);
  return StageSections(
    playerPathways: filteredDetails(details, kPlayerPathways, code),
    sampleSessions: filteredDetails(details, kSampleSessions, code),
    games: {
      for (final e in grouped.entries)
        if ((only == null || e.key == only) && e.value.isNotEmpty)
          e.key: e.value
    },
  );
}

// ------------------------------------------------- no pathway (fallback)

/// One of the six fixed stages for clubs with no pathway.
class FallbackStage {
  const FallbackStage(this.id, this.subtitle, this.ages);
  final int id;
  final String subtitle;
  final List<String> ages;
  String get label => 'Stage $id';
  String get agesLabel => ages.map((a) => a.toUpperCase()).join(', ');
}

const List<FallbackStage> kFallbackStages = [
  FallbackStage(1, 'Learning to Master the Ball', ['u4', 'u5', 'u6']),
  FallbackStage(2, 'Learning to Use the Ball Well', ['u7', 'u8', 'u9']),
  FallbackStage(3, 'Learning to Play Together', ['u10', 'u11']),
  FallbackStage(4, 'Learning About Positions & Decisions', ['u12', 'u13']),
  FallbackStage(5, 'Competing & Refining', ['u14', 'u15']),
  FallbackStage(6, 'Learn to Perform', ['u16', 'u17']),
];

/// Games for a fallback stage's ages (with or without content).
int fallbackStageCount(FallbackStage s, List<V3Game> games) => games
    .where((g) => g.matchesAges(s.ages))
    .map((g) => g.gameId)
    .toSet()
    .length;

/// Stages with games (all six while there are no games at all).
List<FallbackStage> visibleFallbackStages(List<V3Game> games) => games.isEmpty
    ? kFallbackStages
    : [
        for (final s in kFallbackStages)
          if (fallbackStageCount(s, games) > 0) s
      ];

const List<String> kFallbackSports = ['All', 'Football', 'Hurling', 'Camogie'];
const List<String> kFallbackTypes = ['All', 'Games', 'Warmups', 'Drill'];

List<V3Game> fallbackStageGames(FallbackStage s, List<V3Game> games) => [
      for (final g in games)
        if (g.matchesAges(s.ages)) g
    ];

/// Sport chips that have games on this stage.
List<String> fallbackSports(FallbackStage s, List<V3Game> games) {
  final avail = {
    'All',
    for (final g in fallbackStageGames(s, games)) ...g.codes
  };
  return [
    for (final x in kFallbackSports)
      if (avail.contains(x)) x
  ];
}

/// Type chips that have games on this stage (exact type names, as the web
/// page matches them).
List<String> fallbackTypes(FallbackStage s, List<V3Game> games) {
  final avail = {
    'All',
    for (final g in fallbackStageGames(s, games)) ...g.types
  };
  return [
    for (final x in kFallbackTypes)
      if (avail.contains(x)) x
  ];
}

List<V3Game> fallbackFiltered(
        FallbackStage s, List<V3Game> games, String sport, String type) =>
    [
      for (final g in fallbackStageGames(s, games))
        if (g.hasContent &&
            (sport == 'All' || g.codes.contains(sport)) &&
            (type == 'All' || g.types.contains(type)))
          g
    ];

/// The club website strip on the pathway page (as on the web page).
const String kPathwayLinkUrl = 'https://www.dosclontarf.com';
const String kPathwayLinkLabel = 'dosclontarf.com';
