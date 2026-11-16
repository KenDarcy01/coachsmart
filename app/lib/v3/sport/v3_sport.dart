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
    required this.gameCodes,
    required this.gameSkills,
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

  /// Codes a game can be tagged with (games.game_code). One code means
  /// there is nothing to pick.
  final List<String> gameCodes;

  /// Skill chips for games and drills.
  final List<String> gameSkills;

  bool get isGaa => kind == V3SportKind.gaa;

  /// More than one code to pick from (GAA); soccer and rugby have one.
  bool get pickCode => gameCodes.length > 1;

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

  /// The score before anything is scored: "0-00", or "0".
  String get zeroScore => score(0, 0);

  /// Counts as a goal in the score (GAA only: a 3-point score is a goal and
  /// shows on the left of "1-05"). Soccer and rugby add every score to the
  /// total.
  bool isGoal(int? value) => isGaa && value == 3;

  /// The big score that gets a marker on charts and the timeline: a GAA
  /// goal, any soccer goal, a rugby try (5) or penalty try (7).
  bool isBigScore(int? value) => switch (kind) {
        V3SportKind.gaa => value == 3,
        V3SportKind.soccer => (value ?? 0) > 0,
        V3SportKind.rugby => (value ?? 0) >= 5,
      };

  /// Name of the big score: Goal, Goal, Try.
  String get bigScoreName => kind == V3SportKind.rugby ? 'Try' : 'Goal';

  /// The short letter on a score's badge: G, 2 or P in GAA; otherwise the
  /// initials of the score's name (T, C, PG, G).
  String scoreLetter(int? value, String name) {
    if (isGaa) return value == 3 ? 'G' : (value == 2 ? '2' : 'P');
    final w = name.trim().split(RegExp(r'\s+')).where((x) => x.isNotEmpty);
    final l = w.take(2).map((x) => x[0].toUpperCase()).join();
    return l.isEmpty ? '•' : l;
  }

  /// "throw-in" / "kick-off", for the middle of a sentence.
  String get matchStartLower => matchStart.toLowerCase();

  /// The alert choices for following a live match: (key, title, small).
  /// Soccer has no "goals only" (every score is a goal); rugby's is tries.
  List<(String, String, String)> get alertLevels => [
        switch (kind) {
          V3SportKind.gaa => (
              'all',
              'Every score',
              'Goals, points and 2 pointers, both teams, plus half time and full time'
            ),
          V3SportKind.soccer => (
              'all',
              'Every goal',
              'Both teams, plus half time and full time'
            ),
          V3SportKind.rugby => (
              'all',
              'Every score',
              'Tries, conversions and penalty goals, both teams, plus half time and full time'
            ),
        },
        if (kind != V3SportKind.soccer)
          (
            'goals',
            kind == V3SportKind.rugby ? 'Tries only' : 'Goals only',
            'Plus half time and full time'
          ),
        ('result', 'Half time and full time only', 'No alerts for scores'),
        ('off', 'Stop following', 'No alerts for this match'),
      ];

  /// A follow level in a sentence: "Every score", "Tries, half time and
  /// full time".
  String levelLabel(String l) => switch (l) {
        'all' => kind == V3SportKind.soccer ? 'Every goal' : 'Every score',
        'goals' => kind == V3SportKind.rugby
            ? 'Tries, half time and full time'
            : 'Goals, half time and full time',
        'result' => 'Half time and full time',
        'off' => 'No alerts',
        _ => '',
      };

  /// A GAA two-pointer (gets a "+2" tag).
  bool isTwoPointer(int? value) => isGaa && value == 2;

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
    gameCodes: ['Football', 'Hurling', 'Camogie'],
    gameSkills: [
      'Handpass',
      'Kick Pass',
      'Catching',
      'Solo',
      'Shooting',
      'Tackling',
      'Blocking',
      'Fielding'
    ],
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
    gameCodes: ['Soccer'],
    gameSkills: [
      'Passing',
      'First Touch',
      'Dribbling',
      'Shooting',
      'Heading',
      'Tackling',
      'Defending',
      'Goalkeeping'
    ],
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
    gameCodes: ['Rugby'],
    gameSkills: [
      'Passing',
      'Catching',
      'Tackling',
      'Rucking',
      'Evasion',
      'Running Lines',
      'Kicking',
      'Contact'
    ],
  );

  static const all = [gaa, soccer, rugby];

  /// The sport a code belongs to (event_codes.event_code): Soccer, Rugby,
  /// or GAA for Football and Hurling; null for "-", S&C or unknown.
  static V3Sport? fromCode(String? code) {
    final c = (code ?? '').trim().toLowerCase();
    if (c.isEmpty) return null;
    for (final s in all) {
      if (s.codes.any((x) => x.toLowerCase() == c)) return s;
    }
    return c == 'camogie' ? gaa : null;
  }

  /// A team's sport if [forTeam] has already read it, else null.
  static V3Sport? cachedTeam(int? teamId) =>
      teamId == null ? null : _teamCache[teamId];

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

  static final Map<int, V3Sport> _clubCache = {};

  /// The club's sport, read once per club and kept. GAA when unknown.
  static Future<V3Sport> forClub(int? clubId) async {
    if (clubId == null) return gaa;
    final hit = _clubCache[clubId];
    if (hit != null) return hit;
    try {
      final r = await SupaFlow.client
          .from('clubs')
          .select('sport_id')
          .eq('club_id', clubId)
          .maybeSingle();
      final id = r?['sport_id'];
      final s = fromId(id is int ? id : int.tryParse('${id ?? ''}'));
      _clubCache[clubId] = s;
      return s;
    } catch (_) {
      return gaa;
    }
  }

  /// The signed-in user's sport: their default club's (users.default_club).
  static Future<V3Sport> mine(String userId) async {
    if (userId.isEmpty) return gaa;
    try {
      final r = await SupaFlow.client
          .from('users')
          .select('default_club')
          .eq('user_id', userId)
          .maybeSingle();
      final v = r?['default_club'];
      return await forClub(v is int ? v : int.tryParse('${v ?? ''}'));
    } catch (_) {
      return gaa;
    }
  }

  /// The team's sport if already read, else null (for sync code).
  static V3Sport? cachedForTeam(int teamId) => _teamCache[teamId];
}
