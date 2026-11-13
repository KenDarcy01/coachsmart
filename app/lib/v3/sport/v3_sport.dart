// Sport settings for v3 (multi-sport, Ken 2026-11-13: GAA, soccer, rugby).
//
// One place that says how each sport talks and plays, so screens stop
// hard-coding GAA. A team's sport is its club's (clubs.sport_id: 1 GAA,
// 2 Soccer, 3 Rugby); codes carry a sport too (event_codes.sport_id, NULL
// for "-" and S&C, which suit any sport). Anything unknown falls back to
// GAA, so GAA screens behave exactly as before.
//
// Later steps fill this in further: score types (score keeper), lineup
// formats and pitch (lineups), games library codes and AI wording.
import '/backend/supabase/supabase.dart';

enum V3SportKind { gaa, soccer, rugby }

/// How a score reads: GAA "1-05 (8)", soccer and rugby just the total.
enum V3ScoreStyle { goalsPoints, total }

class V3Sport {
  const V3Sport({
    required this.kind,
    required this.id,
    required this.name,
    required this.codes,
    required this.matchStart,
    required this.scoreStyle,
    required this.ball,
    required this.pitch,
    required this.clubSuffixes,
  });

  final V3SportKind kind;

  /// sport.sport_id
  final int id;

  /// "GAA", "Soccer", "Rugby"
  final String name;

  /// The sport's own codes (event_codes.event_code), e.g. Football, Hurling.
  final List<String> codes;

  /// What starts a match: "Throw-in" (GAA) or "Kick-off".
  final String matchStart;

  final V3ScoreStyle scoreStyle;

  /// "ball" (football, soccer, rugby); hurling/camogie say sliotar via
  /// [ballFor].
  final String ball;

  /// "pitch"
  final String pitch;

  /// Words dropped from a club name to get the short name, e.g.
  /// "Clontarf GAA" -> "Clontarf".
  final List<String> clubSuffixes;

  bool get isGaa => kind == V3SportKind.gaa;

  /// The ball for a code: a sliotar in hurling and camogie.
  String ballFor(String? code) {
    final c = (code ?? '').toLowerCase();
    return (c == 'hurling' || c == 'camogie') ? 'sliotar' : ball;
  }

  /// Display name of a code: Hurling is Camogie on a female team (GAA only).
  String codeLabel(String code, {bool female = false}) =>
      (isGaa && female && code == 'Hurling') ? 'Camogie' : code;

  /// A score as the sport reads it. GAA "1-05"; others the plain total.
  String score(int goals, int points) => scoreStyle == V3ScoreStyle.goalsPoints
      ? '$goals-${points.toString().padLeft(2, '0')}'
      : '${goals * 3 + points}';

  /// "Clontarf GAA" -> "Clontarf", "Clontarf RFC" -> "Clontarf".
  String shortClub(String name) {
    final re = RegExp('\\b(${clubSuffixes.map(RegExp.escape).join('|')})\\b',
        caseSensitive: false);
    final s = name.replaceAll(re, '').replaceAll(RegExp(r'\s+'), ' ').trim();
    return s.isEmpty ? name : s;
  }

  static const gaa = V3Sport(
    kind: V3SportKind.gaa,
    id: 1,
    name: 'GAA',
    codes: ['Football', 'Hurling'],
    matchStart: 'Throw-in',
    scoreStyle: V3ScoreStyle.goalsPoints,
    ball: 'ball',
    pitch: 'pitch',
    clubSuffixes: ['GAA', 'GFC', 'CLG', 'HC', 'LGFA', 'Camogie Club'],
  );

  static const soccer = V3Sport(
    kind: V3SportKind.soccer,
    id: 2,
    name: 'Soccer',
    codes: ['Soccer'],
    matchStart: 'Kick-off',
    scoreStyle: V3ScoreStyle.total,
    ball: 'ball',
    pitch: 'pitch',
    clubSuffixes: ['FC', 'AFC', 'United', 'Football Club'],
  );

  static const rugby = V3Sport(
    kind: V3SportKind.rugby,
    id: 3,
    name: 'Rugby',
    codes: ['Rugby'],
    matchStart: 'Kick-off',
    scoreStyle: V3ScoreStyle.total,
    ball: 'ball',
    pitch: 'pitch',
    clubSuffixes: ['RFC', 'RFU', 'Rugby Club', 'Rugby'],
  );

  static const all = [gaa, soccer, rugby];

  /// The sport for clubs.sport_id; GAA when unknown.
  static V3Sport fromId(int? id) =>
      all.firstWhere((s) => s.id == id, orElse: () => gaa);

  static final Map<int, V3Sport> _teamCache = {};

  /// The team's sport (its club's), read once per team and kept. GAA if
  /// the read fails, so nothing changes for GAA teams.
  static Future<V3Sport> forTeam(int teamId) async {
    final hit = _teamCache[teamId];
    if (hit != null) return hit;
    try {
      final r = await SupaFlow.client
          .from('teams')
          .select('clubs(sport_id)')
          .eq('team_id', teamId)
          .maybeSingle();
      final club = r?['clubs'];
      final id = club is Map ? club['sport_id'] : null;
      final s = fromId(id is int ? id : int.tryParse('${id ?? ''}'));
      _teamCache[teamId] = s;
      return s;
    } catch (_) {
      return gaa;
    }
  }

  /// The team's sport if already read, else null (for sync code).
  static V3Sport? cachedForTeam(int teamId) => _teamCache[teamId];
}
