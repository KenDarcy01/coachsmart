import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:coach_smart_v2/v3/matches/v3_match_live_page.dart';
import 'package:coach_smart_v2/v3/matches/v3_matches_models.dart';
import 'package:coach_smart_v2/v3/matches/v3_matches_page.dart';

final now = DateTime.utc(2026, 11, 11, 14, 20);

Map<String, dynamic> score(int ug, int up, int og, int op) => {
      'us': {'g': ug, 'p': up, 't': ug * 3 + up},
      'opp': {'g': og, 'p': op, 't': og * 3 + op},
    };

Map<String, dynamic> listSample() => {
      'server_now': now.toIso8601String(),
      'matches': [
        // Two squads of one event: Blue live, Red later
        {
          'event_id': 10,
          'squad_key': 11,
          'squad_name': 'Blue Team',
          'squads_in_event': 2,
          'event_date_time': '2026-11-11T14:00:00Z',
          'team_name': 'U12 Girls',
          'opposition': 'Raheny',
          'venue': 'St Annes',
          'home_away': 'HOME',
          'phase': 'play',
          'timer': {
            'status': 'running',
            'started_at': '2026-11-11T14:10:00Z',
            'elapsed_seconds': 0,
            'current_half': 1,
            'duration_seconds': 1500
          },
          'score': score(1, 3, 0, 4),
          'follow': {'level': 'all', 'kickoff': true, 'names': true},
        },
        {
          'event_id': 10,
          'squad_key': 12,
          'squad_name': 'Red Team',
          'squads_in_event': 2,
          'event_date_time': '2026-11-11T15:30:00Z',
          'team_name': 'U12 Girls',
          'opposition': 'Naomh Barróg',
          'venue': 'Clontarf Road',
          'home_away': 'home',
          'phase': 'pre',
          'score': null,
          'follow': {'level': 'all', 'kickoff': true, 'names': true},
        },
        {
          'event_id': 20,
          'squad_key': 0,
          'squad_name': null,
          'squads_in_event': 1,
          'event_date_time': '2026-11-11T10:00:00Z',
          'team_name': 'Senior Hurling',
          'opposition': 'Cuala',
          'home_away': 'away',
          'phase': 'ft',
          'score': score(2, 14, 1, 12),
          'follow': {'level': 'off'},
        },
      ],
    };

Map<String, dynamic> squadSummary(int key, String name, String phase,
        {String opp = 'Raheny', Map? sc, String? throwIn, Map? last}) =>
    {
      'key': key,
      'squad_id': key,
      'name': name,
      'colour': null,
      'phase': phase,
      'score': sc,
      'opposition': opp,
      'venue': 'St Annes',
      'throw_in_at': throwIn ?? '2026-11-11T14:00:00Z',
      'kicked_off_at': phase == 'pre' ? null : '2026-11-11T14:02:00Z',
      'timer': {
        'status': 'running',
        'started_at': '2026-11-11T14:10:00Z',
        'elapsed_seconds': 0,
        'current_half': 1,
        'duration_seconds': 1800
      },
      'last': last,
    };

Map<String, dynamic> liveSample({bool multi = false, String phase = 'play'}) =>
    {
      'server_now': now.toIso8601String(),
      'phase': phase,
      'event': {
        'event_id': 10,
        'event_date_time': '2026-11-11T14:00:00Z',
        'event_start': '2026-11-11T14:00:00Z',
        'event_title': 'Go Games',
        'opposition': 'Raheny',
        'home_away': 'home',
        'location_name': 'St Annes',
        'team_name': 'U12 Girls',
        'club_name': 'Clontarf GAA',
      },
      'timer': {
        'status': 'running',
        'started_at': '2026-11-11T14:10:00Z',
        'elapsed_seconds': 0,
        'current_half': 1,
        'duration_seconds': 1800
      },
      'score': score(1, 2, 0, 1),
      'score_types': [
        {'id': 1, 'name': 'Point', 'value': 1},
        {'id': 3, 'name': 'Goal', 'value': 3},
        {'id': 9, 'name': 'Wide', 'value': 0},
      ],
      'actions': [
        {
          'id': 1,
          'type': 1,
          'side': 'us',
          'kind': 'score',
          'half': 1,
          'second': 60,
          'member': 'Aoife Byrne'
        },
        {
          'id': 2,
          'type': 9,
          'side': 'opp',
          'kind': 'score',
          'half': 1,
          'second': 90
        },
        {
          'id': 3,
          'type': 1,
          'side': 'opp',
          'kind': 'score',
          'half': 1,
          'second': 200
        },
        {
          'id': 4,
          'type': 3,
          'side': 'us',
          'kind': 'score',
          'half': 1,
          'second': 400,
          'member': 'Aoife Byrne'
        },
        {
          'id': 5,
          'type': 1,
          'side': 'us',
          'kind': 'score',
          'half': 1,
          'second': 500
        },
      ],
      'subs': [],
      'follow': {'level': 'off', 'kickoff': false, 'names': true},
      'squad': squadSummary(11, 'Blue Team', phase, sc: score(1, 2, 0, 1)),
      'squads': multi
          ? [
              squadSummary(11, 'Blue Team', phase,
                  sc: score(1, 2, 0, 1),
                  last: {
                    'type': 'Point',
                    'value': 1,
                    'side': 'us',
                    'half': 1,
                    'second': 500
                  }),
              squadSummary(12, 'Red Team', 'pre',
                  opp: 'Naomh Barróg', throwIn: '2026-11-11T15:30:00Z'),
            ]
          : [squadSummary(11, 'Blue Team', phase, sc: score(1, 2, 0, 1))],
    };

MatchModel model(List<MatchEv> evs,
        {bool hasH2 = true, bool finished = true}) =>
    MatchModel(
        usName: 'Clontarf',
        oppName: 'Raheny',
        duration: 1800,
        hasH2: hasH2,
        nowAbs: null,
        finished: finished,
        events: evs);

MatchEv ev(String side, int value, int half, int sec,
        {String member = '', String kind = 'score', int count = 1}) =>
    MatchEv(
        half: half,
        second: sec,
        side: side,
        value: value,
        name: value == 3 ? 'Goal' : (value == 0 ? 'Wide' : 'Point'),
        kind: kind,
        count: count,
        member: member);

void main() {
  widgetTests();

  test('Irish time, countdowns and labels', () {
    // Winter: GMT. Summer: IST (UTC+1).
    expect(clockTime(DateTime.utc(2026, 11, 11, 14, 5)), '14:05');
    expect(clockTime(DateTime.utc(2026, 6, 1, 14, 5)), '15:05');
    expect(clockTime(DateTime.utc(2026, 3, 29, 0, 59)), '00:59');
    expect(clockTime(DateTime.utc(2026, 3, 29, 1, 0)), '02:00');
    expect(dayLabel(DateTime.utc(2026, 11, 11, 23, 30)), 'Wed 11 Nov');
    expect(untilLabel(now.add(const Duration(minutes: 45)), now), '45m');
    expect(untilLabel(now.add(const Duration(minutes: 125)), now), '2h 5m');
    expect(untilLabel(now.subtract(const Duration(minutes: 1)), now), 'Due');
    expect(untilLabel(now.add(const Duration(days: 2)), now), 'Fri 13 Nov');
    expect(countdown(const Duration(hours: 1, minutes: 2, seconds: 3)),
        '01:02:03');
    expect(countdown(const Duration(days: 2, hours: 1)), '2 days');
    expect(untilCaps(const Duration(minutes: 125)), '2H 5M');
    expect(untilCaps(const Duration(days: 1)), '1 DAY');
    expect(fmtClock(605.7), '10:05');
  });

  test('squad names, colours and club names', () {
    expect(squadShort('Blue Team'), 'Blue');
    expect(squadShort('No team'), 'Team');
    expect(squadShort('A Squad'), 'A');
    expect(squadShort('Panthers'), 'Panthers');
    expect(squadColour('Blue Team', '', 0), const Color(0xFF3B82F6));
    expect(squadColour('Panthers', '#ff0000', 0), const Color(0xFFFF0000));
    expect(squadColour('Panthers', '', 1), const Color(0xFFE05252));
    expect(cleanClub('Clontarf GAA'), 'Clontarf');
    expect(cleanClub('St Vincents Camogie Club'), 'St Vincents');
  });

  test('timer minute, injury time and second half', () {
    const t = LiveTimer(
        status: 'paused', elapsedSeconds: 1500, durationSeconds: 1800);
    expect(t.minuteOf(now), "26'");
    const inj = LiveTimer(
        status: 'paused',
        elapsedSeconds: 1800 + 70,
        currentHalf: 2,
        durationSeconds: 1800);
    expect(inj.minuteOf(now), "60+2'");
    final run = LiveTimer(
        status: 'running',
        startedAt: now.subtract(const Duration(seconds: 90)),
        elapsedSeconds: 30);
    expect(run.halfSeconds(now), 120);
  });

  test('matches list: live, today, results, following per event', () {
    final d = LiveMatchesData.fromJson(listSample());
    expect(d.matches.first.teamName, 'Senior Hurling'); // by throw-in time
    expect(d.live.single.title, 'U12 Girls Blue v Raheny');
    expect(d.live.single.place, 'St Annes'); // venue for squads
    expect(d.today(now).length, 3);
    expect(d.results.single.title, 'Senior Hurling v Cuala');
    expect(d.results.single.place, 'Away');
    expect(d.following.length, 2);
    expect(d.eventIds, [20, 10]);
    d.setFollow(10, const LiveFollow());
    expect(d.following, isEmpty);
    expect(
        LiveMatchesData.fromJson({'error': 'not_signed_in'}).hasError, isTrue);
  });

  test('live match: views, order, share text', () {
    final single = LiveMatchData.fromJson(liveSample());
    expect(single.multi, isFalse);
    expect(single.nextView(null), 11);
    expect(single.usName, 'Clontarf');
    expect(single.scoringActions.length, 4); // the wide is not a score
    expect(single.shareText(11), 'Live: Clontarf 1-02 Raheny 0-01');
    expect(LiveMatchData.shareUrl('abc', 11),
        'https://coachsmart.app/webviews/match-live.html?share=abc&squad=11');
    expect(LiveMatchData.shareUrl('abc', null),
        'https://coachsmart.app/webviews/match-live.html?share=abc');

    final multi = LiveMatchData.fromJson(liveSample(multi: true));
    expect(multi.multi, isTrue);
    expect(multi.nextView(null), kBoth);
    expect(multi.nextView(12), 12);
    expect(multi.nextView(99), 11); // a squad that has gone
    expect(multi.ordered.map((s) => s.short), ['Blue', 'Red']);
    expect(multi.shareText(kBoth),
        'Follow U12 Girls live: Blue v Raheny, Red v Naomh Barróg');
    final err = LiveMatchData.fromJson({'error': 'not_allowed'});
    expect(err.errorText, 'This match is only for members of the club.');
  });

  test('charts maths: running score, leads, halves, scorers', () {
    final m = model([
      ev('us', 1, 1, 60, member: 'Aoife'),
      ev('opp', 0, 1, 70), // wide: left out
      ev('opp', 3, 1, 200),
      ev('us', 2, 1, 1810, member: 'Aoife'), // injury time, 30+1'
      ev('us', 1, 2, 100),
      ev('us', 1, 2, 300, member: 'Ciara'),
    ]);
    final w = m.walk();
    expect(w.length, 5);
    expect(w.last.us.gaa, '0-05');
    expect(w.last.opp.gaa, '1-00');
    expect(m.minuteLabel(1, 1810), "30+1'");
    expect(m.minuteLabel(2, 100), "32'");
    final (ud, ua, od, oa) = m.biggestLeads;
    expect((ud, ua), (2, "36'"));
    expect((od, oa), (2, "4'"));
    expect(m.halfScores[1]!.us.gaa, '0-03');
    expect(m.halfScores[2]!.us.gaa, '0-02');
    expect(m.scorers.map((s) => '${s.$1} ${s.$2.gaa}'),
        ['Aoife 0-03', 'Ciara 0-01', ' 0-01']);
  });

  test('timeline: newest first, half time band, runs of three', () {
    final m = model([
      ev('us', 1, 1, 60),
      ev('us', 1, 1, 120),
      ev('us', 3, 1, 180),
      ev('opp', 1, 2, 60),
    ]);
    final t = m.timeline();
    expect(t.first.title, 'Full time');
    expect(t.first.right, '1-02 v 0-01');
    expect(t.last.title, 'Throw-in');
    final titles = [
      for (final i in t) i.kind == TimelineKind.score ? i.scoreName : i.title
    ];
    expect(titles, [
      'Full time',
      'Point',
      'Half time',
      'Clontarf scored 3 in a row',
      'Goal',
      'Point',
      'Point',
      'Throw-in',
    ]);
    expect(model([]).timeline(), isEmpty);
    final check = model([ev('us', 1, 1, 60, kind: 'correction', count: -1)]);
    expect(check.timeline()[1].scoreName, 'Score check: -1 point');
  });
}

void widgetTests() {
  void phone(WidgetTester tester) {
    tester.view.physicalSize = const Size(390 * 3, 1400 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
  }

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }
  }

  testWidgets('matches list: tabs, squad rows, results, following',
      (tester) async {
    phone(tester);
    await tester.pumpWidget(
        MaterialApp(home: V3MatchesPage(testData: listSample(), testNow: now)));
    await settle(tester);
    expect(find.text('Matches'), findsOneWidget);
    expect(find.text('Live now · 1'), findsOneWidget);
    expect(find.text('U12 Girls Blue v Raheny'), findsOneWidget);
    expect(find.text("LIVE 11'"), findsOneWidget);
    expect(find.text('1-03'), findsOneWidget);
    expect(find.text('Coming up today'), findsOneWidget);
    expect(find.text('U12 Girls Red v Naomh Barróg'), findsOneWidget);
    expect(find.text('Throw-in 15:30 · Clontarf Road'), findsOneWidget);
    expect(find.text('Results'), findsOneWidget);
    expect(find.text('FULL TIME'), findsOneWidget);
    await tester.tap(find.text('Following'));
    await settle(tester);
    expect(find.text('Senior Hurling v Cuala'), findsNothing);
    expect(find.text('U12 Girls Red v Naomh Barróg'), findsOneWidget);
    await tester.tap(find.text('Today'));
    await settle(tester);
    expect(find.text('Senior Hurling v Cuala'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('live match: clock, score, last score, stats and timeline',
      (tester) async {
    phone(tester);
    await tester.pumpWidget(MaterialApp(
        home: V3MatchLivePage(
            eventId: 10, testData: liveSample(), testNow: now)));
    await settle(tester);
    expect(find.text('LIVE'), findsOneWidget);
    expect(find.text('10:00'), findsOneWidget); // 10 minutes in
    expect(find.text('1-02'), findsWidgets);
    expect(find.text('5 pts'), findsOneWidget);
    expect(find.text('Point · Clontarf'), findsOneWidget);
    expect(find.text("Who's ahead"), findsOneWidget);
    expect(find.text('Follow this match'), findsOneWidget);
    expect(find.text('Share link'), findsOneWidget);
    await tester.tap(find.text('Stats'));
    await settle(tester);
    expect(find.text('Who was ahead'), findsOneWidget);
    expect(find.text('Clontarf scorers'), findsOneWidget);
    expect(find.text('Aoife Byrne'), findsOneWidget);
    await tester.tap(find.text('Timeline'));
    await settle(tester);
    expect(find.text('NOW'), findsOneWidget);
    expect(find.text('THROW-IN'), findsOneWidget);
    expect(find.text('Wide'), findsNothing); // scores only
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('live match: several squads open on Both with squad tabs',
      (tester) async {
    phone(tester);
    final red = liveSample(multi: true)
      ..['phase'] = 'pre'
      ..['actions'] = []
      ..['score'] = null
      ..['event'] = {
        ...(liveSample()['event'] as Map),
        'opposition': 'Naomh Barróg',
        'event_date_time': '2026-11-11T15:30:00Z',
      }
      ..['squad'] = squadSummary(12, 'Red Team', 'pre',
          opp: 'Naomh Barróg', throwIn: '2026-11-11T15:30:00Z');
    await tester.pumpWidget(MaterialApp(
        home: V3MatchLivePage(
            eventId: 10,
            testData: liveSample(multi: true),
            testBySquad: {12: red},
            testNow: now)));
    await settle(tester);
    expect(find.text('Both'), findsOneWidget);
    expect(find.text('1 LIVE'), findsWidgets);
    expect(find.text('Blue v Raheny'), findsOneWidget);
    expect(find.text('Red v Naomh Barróg'), findsOneWidget);
    expect(find.text('STARTS 15:30'), findsOneWidget);
    expect(find.text('1H 10M'), findsOneWidget);
    expect(find.text('Open Red ›'), findsOneWidget);
    await tester.tap(find.text('Open Red ›'));
    await settle(tester);
    expect(find.text('NOT STARTED'), findsOneWidget);
    expect(find.text('THROW-IN IN'), findsOneWidget);
    expect(find.text('01:10:00'), findsOneWidget);
    expect(find.text('This screen goes live by itself'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('live match: error message', (tester) async {
    phone(tester);
    await tester.pumpWidget(MaterialApp(
        home: V3MatchLivePage(
            eventId: 10, testData: const {'error': 'not_allowed'})));
    await settle(tester);
    expect(find.text('This match is only for members of the club.'),
        findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
}
