// Soccer and rugby scores (multi-sport step 4): totals instead of "1-05",
// tries and goals as the big score, voice words by sport. GAA unchanged.
import 'package:flutter_test/flutter_test.dart';

import 'package:coach_smart_v2/v3/match_stats/v3_match_stats_models.dart' as ms;
import 'package:coach_smart_v2/v3/create_team/v3_create_team_models.dart';
import 'package:coach_smart_v2/v3/matches/v3_matches_models.dart';
import 'package:coach_smart_v2/v3/score_keeper/sk_models.dart';
import 'package:coach_smart_v2/v3/score_keeper/sk_voice_parser.dart';
import 'package:coach_smart_v2/v3/sport/v3_sport.dart';

MatchEv ev(String side, int value, String name, {String member = ''}) =>
    MatchEv(
        half: 1,
        second: 60,
        side: side,
        value: value,
        name: name,
        member: member);

MatchModel liveModel(V3Sport sport, List<MatchEv> evs) => MatchModel(
    usName: 'Clontarf',
    oppName: 'Lansdowne',
    duration: 2400,
    hasH2: false,
    nowAbs: null,
    finished: true,
    events: evs,
    sport: sport);

ms.MsEvent mev(String side, int? value, String name, int order) => ms.MsEvent(
    half: 1,
    second: 60 * order,
    side: side,
    value: value,
    name: name,
    kind: 'score',
    count: 1,
    member: '',
    order: order);

void main() {
  test('sport helpers', () {
    expect(V3Sport.gaa.zeroScore, '0-00');
    expect(V3Sport.rugby.zeroScore, '0');
    expect(V3Sport.gaa.isGoal(3), isTrue);
    expect(V3Sport.rugby.isGoal(3), isFalse); // a penalty goal is 3 points
    expect(V3Sport.rugby.isBigScore(5), isTrue);
    expect(V3Sport.rugby.isBigScore(3), isFalse);
    expect(V3Sport.soccer.isBigScore(1), isTrue);
    expect(V3Sport.rugby.scoreLetter(3, 'Penalty goal'), 'PG');
    expect(V3Sport.gaa.scoreLetter(3, 'Goal'), 'G');
    expect(V3Sport.rugby.bigScoreName, 'Try');
  });

  test('live score: GAA unchanged, rugby a total', () {
    final gaa = LiveScore.fromJson({
      'us': {'g': 1, 'p': 5, 't': 8},
      'opp': {'g': 0, 'p': 3, 't': 3}
    });
    expect(gaa.us.text, '1-05');
    expect(gaa.sport, V3Sport.gaa);
    final rugby = LiveScore.fromJson({
      'us': {'g': 0, 'p': 10, 't': 10},
      'opp': {'g': 0, 'p': 5, 't': 5},
      'sport': 3
    });
    expect(rugby.us.text, '10');
    expect(rugby.opp.text, '5');
    expect(rugby.diff, 5);
  });

  test('rugby walk, halves, scorers and timeline', () {
    final m = liveModel(V3Sport.rugby, [
      ev('us', 5, 'Try', member: 'Seán'),
      ev('us', 2, 'Conversion', member: 'Tom'),
      ev('opp', 3, 'Penalty goal'),
      ev('us', 3, 'Penalty goal', member: 'Tom'),
    ]);
    final w = m.walk();
    expect(w.last.us.text, '10');
    expect(w.last.opp.text, '3');
    expect(m.halfScores[1]!.us.text, '10');
    expect(m.scorers.map((s) => '${s.$1} ${s.$2.text}'), ['Seán 5', 'Tom 5']);
    final tl = m.timeline();
    expect(tl.last.title, 'Kick-off');
    expect(tl.last.right, '0 v 0');
    expect(tl.first.right, '10 v 3');
  });

  test('GAA walk still counts a 3 as a goal', () {
    final m =
        liveModel(V3Sport.gaa, [ev('us', 3, 'Goal'), ev('us', 1, 'Point')]);
    expect(m.walk().last.us.text, '1-01');
  });

  test('stats page models: soccer totals and goal tags', () {
    final m = ms.MatchModel(
        usName: 'Clontarf',
        oppName: 'Raheny',
        duration: 2700,
        hasH2: false,
        nowAbs: null,
        finished: true,
        events: [
          mev('us', 1, 'Goal', 0),
          mev('opp', null, 'Corner', 1),
          mev('opp', 1, 'Goal', 2),
          mev('us', 1, 'Goal', 3),
        ],
        subs: const [],
        sport: V3Sport.soccer);
    final w = ms.walk(m);
    expect((w.us, w.opp), ('2', '1'));
    expect(ms.halfScores(m)[1], ('2', '1'));
    final tl = ms.timeline(m);
    final goal = tl.firstWhere((t) => t.kind == ms.TlKind.event);
    expect(goal.tagText, 'GOAL');
    expect(tl.last.label, 'Kick-off');
    expect(tl.last.score, '0 v 0');
  });

  test('score keeper info: rugby has no goal/point and orders by value', () {
    final c = SkInfo(SkInfo.pick({
      'event': {'sport_id': 3, 'club_name': 'Clontarf RFC'},
      'score_types': [
        {'id': 1, 'score_type': 'Conversion', 'score_value': 2},
        {'id': 2, 'score_type': 'Try', 'score_value': 5},
        {'id': 3, 'score_type': 'Penalty goal', 'score_value': 3},
        {'id': 4, 'score_type': 'Lineout'},
      ],
    }));
    expect(c.sport, V3Sport.rugby);
    expect(c.goalType, isNull);
    expect(c.padTypes.map((t) => t.name),
        ['Try', 'Penalty goal', 'Conversion', 'Lineout']);
    expect(c.scoringTypes.map((t) => t.name),
        ['Try', 'Penalty goal', 'Conversion']);
    expect(usName(c), 'Clontarf');
  });

  test('voice: rugby and soccer words', () {
    VoiceCtx ctx(List<VoiceType> types) => VoiceCtx(
            types: types,
            usName: 'Clontarf',
            oppName: 'Lansdowne',
            players: const [
              VoicePlayer(memberId: 7, firstName: 'Ciarán', lastName: 'Byrne')
            ]);
    final rugby = ctx(const [
      VoiceType(id: 1, name: 'Try', value: 5, gaa: false),
      VoiceType(id: 2, name: 'Conversion', value: 2, gaa: false),
      VoiceType(id: 3, name: 'Penalty goal', value: 3, gaa: false),
      VoiceType(id: 4, name: 'Penalty', gaa: false),
      VoiceType(id: 5, name: 'Turnover', abbr: 'TO', gaa: false),
    ]);
    final t = parseVoice('try Ciarán', rugby).items.single;
    expect((t.typeId, t.memberId), (1, 7));
    expect(parseVoice('penalty goal for them', rugby).items.single.typeId, 3);
    expect(parseVoice('penalty to us', rugby).items.single.typeId, 4);
    expect(parseVoice('conversion', rugby).items.single.typeId, 2);

    final soccer = ctx(const [
      VoiceType(id: 11, name: 'Goal', value: 1, gaa: false),
      VoiceType(id: 12, name: 'Corner', source: true, gaa: false),
      VoiceType(id: 13, name: 'Yellow card', gaa: false),
    ]);
    expect(parseVoice('goal Ciarán', soccer).items.single.typeId, 11);
    expect(parseVoice('corner for them', soccer).items.single.side, 'opp');
    expect(parseVoice('yellow card', soccer).items.single.typeId, 13);
  });

  test('wording: kick-off and alert choices by sport', () {
    expect(V3Sport.fromCode('Soccer'), V3Sport.soccer);
    expect(V3Sport.fromCode('Hurling'), V3Sport.gaa);
    expect(V3Sport.fromCode('-'), isNull);
    expect(V3Sport.rugby.matchStartLower, 'kick-off');
    expect(V3Sport.gaa.alertLevels.map((a) => a.$2),
        ['Every score', 'Goals only', 'Half time and full time only', 'Stop following']);
    expect(V3Sport.soccer.alertLevels.map((a) => a.$1),
        ['all', 'result', 'off']);
    expect(V3Sport.rugby.alertLevels[1].$2, 'Tries only');
    const f = LiveFollow(level: 'goals', kickoff: true);
    expect(f.label, 'Goals, half time and full time and throw-in');
    expect(f.labelFor(V3Sport.rugby),
        'Tries, half time and full time and kick-off');
    expect(levelLabel('all'), 'Every score');

    final row = LiveMatchRow.fromJson({'event_id': 1, 'sport': 2});
    expect(row.sport, V3Sport.soccer);
    expect(LiveMatchRow.fromJson({'event_id': 1}).sport, V3Sport.gaa);
    final live = LiveMatchData.fromJson({
      'event': {'event_id': 1, 'event_code': 'Rugby', 'team_id': 5}
    });
    expect(live.sport, V3Sport.rugby);
  });

  test('create team ticks the club sport codes', () {
    expect(defaultCodeIds(const [CtCode(5, 'Soccer'), CtCode(6, 'S&C')], null),
        [5]);
  });
}
