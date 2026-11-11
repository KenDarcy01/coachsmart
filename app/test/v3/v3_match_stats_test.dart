import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:coach_smart_v2/v3/match_stats/v3_match_stats_models.dart';
import 'package:coach_smart_v2/v3/match_stats/v3_match_stats_page.dart';

Map<String, dynamic> ev(
        int half, int second, String side, int? value, String name,
        {String member = '', String kind = 'score', int count = 1}) =>
    {
      'half': half,
      'second': second,
      'side': side,
      'score_value': value,
      'score_type_name': name,
      'kind': kind,
      'count': count,
      'member_name': member,
    };

Map<String, dynamic> session({bool finished = true}) => {
      'match_stats_id': 12,
      'event_id': 1,
      'team_name': 'Clontarf',
      'opposition': 'Raheny',
      'event_title': 'U14 League v Raheny',
      'finalised_at': finished ? '2026-11-08T12:00:00Z' : null,
      'timer': {
        'elapsed_seconds': 600,
        'status': 'paused',
        'duration_seconds': 1800,
        'current_half': 2,
      },
      'events': [
        ev(1, 120, 'us', 1, 'Point', member: 'Aimee Morris'),
        ev(1, 300, 'opp', 1, 'Point'),
        ev(1, 600, 'us', 3, 'Goal'),
        ev(1, 700, 'us', 1, 'Point', member: 'Anna Ryan'),
        ev(1, 800, 'us', 1, 'Point', member: 'Aimee Morris'),
        ev(1, 900, 'opp', null, 'Wide'), // not a score: never shown
        ev(2, 100, 'opp', 2, '2 Point'),
        ev(2, 1700, 'us', 1, 'Point', kind: 'correction', count: 1),
      ],
      'subs': [
        {
          'half': 2,
          'second': 200,
          'on_name': 'Fiadh Nolan',
          'off_name': 'Anna Ryan'
        },
      ],
    };

final list2 = [
  {
    'id': 12,
    'user_name': 'Ken Darcy',
    'squad_name': 'Blue',
    'squad_colour': '#1E88E5',
    'opposition': 'Raheny',
    'finalised_at': '2026-11-08T12:00:00Z',
    'status': 'active',
    'score_count': 8,
    'is_mine': true,
  },
  {
    'id': 13,
    'user_name': '',
    'squad_name': null,
    'squad_colour': null,
    'opposition': 'Raheny',
    'finalised_at': null,
    'status': 'active',
    'score_count': 1,
    'is_mine': false,
  },
];

MatchModel model({bool finished = true}) => chartModel(
    MsSession.fromJson(session(finished: finished))!, DateTime(2026, 11, 8));

void main() {
  widgetTests();

  test('walk keeps the running score from scores only', () {
    final m = model();
    final w = walk(m);
    expect(w.rows.length, 7); // the wide is left out
    expect(w.us, '1-04');
    expect(w.opp, '0-03');
    expect(w.usT, 7);
    expect(w.oppT, 3);
    expect(m.hasH2, isTrue);
    expect(leadChip(m), ('Won by 4', LeadTone.leading));
  });

  test('halves, biggest leads and scorers', () {
    final m = model();
    final hs = halfScores(m);
    expect(hs[1], ('1-03', '0-01'));
    expect(hs[2], ('0-01', '0-02'));
    final (us, opp) = biggestLeads(m);
    expect(us.label, "+5 at 14'");
    expect(opp.label, '—');
    expect(poss('Clontarf'), "Clontarf's");
    expect(poss('St Vincents'), "St Vincents'");
    final sc = scorers(m);
    expect(sc.map((s) => s.name), ['Aimee Morris', 'Anna Ryan', '']);
    expect(sc.map((s) => s.score), ['0-02', '0-01', '1-01']);
    // scoresOnly: no non-scoring stats table.
    expect(otherStats(m), isEmpty);
  });

  test('timeline is newest first with half time, subs and runs', () {
    final t = timeline(model());
    expect(t.first.label, 'Full time');
    expect(t.first.score, '1-04 v 0-03');
    expect(t.last.label, 'Throw-in');
    expect(t[1].label, 'Score check: +1 point');
    expect(t[1].minute, "59'");
    expect(t[1].tag, TlTag.check);
    final sub = t.firstWhere((x) => x.kind == TlKind.sub);
    expect(sub.who, 'Fiadh Nolan on for Anna Ryan');
    expect(sub.minute, "34'");
    final ht = t.firstWhere((x) => x.label == 'Half time');
    expect(ht.score, '1-03 v 0-01');
    expect(t.where((x) => x.kind == TlKind.run).single.label,
        'Clontarf scored 3 in a row');
    final goal = t.firstWhere((x) => x.goal);
    expect(goal.tag, TlTag.goalUs);
    expect(goal.score, '1-01 v 0-01');
    expect(t.any((x) => x.label == 'Wide'), isFalse);
    // Live and empty: "Now" band, and no scores yet.
    expect(timeline(model(finished: false)).first.label, 'Now');
    final empty = MsSession.fromJson({...session(), 'events': [], 'subs': []})!;
    final te = timeline(chartModel(empty, DateTime.now()));
    expect(te.map((x) => x.label), ['Throw-in', 'No scores yet']);
  });

  test('minute labels, axis and chart series', () {
    final m = model();
    expect(minuteLabel(m, 1, 0), "1'");
    expect(minuteLabel(m, 1, 1850), "30+1'");
    expect(minuteLabel(m, 2, 60), "32'");
    final ax = axis(m);
    expect(ax.ticks, [0, 10, 20, 40, 50, 60]);
    final lead = leadSeries(m);
    expect(lead.maxD, 6);
    expect(lead.goals.single.$3, isTrue);
    final race = raceSeries(m);
    expect(race.maxY, 10);
    expect(race.usEnd, 7);
    expect(race.oppEnd, 3);
    expect(leadLabel(3), '+3');
    expect(leadLabel(-1.5), '-1.5');
  });

  test('live clock, timer merges and picker text', () {
    final s = MsSession.fromJson(session(finished: false))!;
    final now = DateTime(2026, 11, 8, 12);
    final c = liveClock(s, now)!;
    expect(c.half, 'Second Half');
    expect(c.time, '20:00');
    expect(c.sub, 'remaining — paused');
    expect(liveClock(MsSession.fromJson(session())!, now), isNull);
    final b = mergeBroadcast(
        s.timer,
        {
          'payload': {'status': 'running', 'elapsed_seconds': 700}
        },
        now);
    expect(b.running, isTrue);
    expect(b.localRef, isTrue);
    expect(b.elapsedAt(now.add(const Duration(seconds: 5))), 705);
    // A refresh keeps the broadcast-anchored clock.
    final kept = mergeRefresh(
        b, MsTimer(elapsed: 650, status: 'running', startedAt: DateTime(2020)));
    expect(kept.elapsed, 700);
    // Injury time ceiling: keep the smaller paused value.
    final p = mergeRefresh(MsTimer(elapsed: 1850, status: 'paused'),
        MsTimer(elapsed: 2700, status: 'paused'));
    expect(p.elapsed, 1850);

    final items = parseSessionList(list2);
    expect(pickerSubtitle(items), '2 sessions · 1 live — tap to view');
    expect(items[0].title, 'Ken Darcy · Blue');
    expect(items[1].title, 'Unknown');
    expect(items[1].meta, 'vs Raheny · 1 score');
    expect(squadColourValue('#1E88E5'), 0xFF1E88E5);
    expect(squadColourValue(''), 0xFF64748B);
    expect(
        pdfFileName('U14 League v Raheny', 'Raheny', '1-04', '0-03',
            DateTime(2026, 11, 8)),
        'U14_League_v_Raheny_vs_Raheny_1-04_0-03_2026-11-08.pdf');
    expect(MsSession.fromJson({}), isNull);
  });
}

void widgetTests() {
  Future<void> big(WidgetTester tester) async {
    tester.view.physicalSize = const Size(390 * 3, 1400 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
  }

  testWidgets('one session opens straight onto the charts', (tester) async {
    await big(tester);
    await tester.pumpWidget(MaterialApp(
        home: V3MatchStatsPage(eventId: 1, testData: {
      'list': [list2.first],
      'sessions': {'12': session()},
    })));
    await tester.pumpAndSettle();
    expect(find.text('Match Stats'), findsOneWidget);
    expect(find.text('PDF'), findsOneWidget);
    expect(find.text('U14 LEAGUE V RAHENY'), findsOneWidget);
    expect(find.text('1-04'), findsWidgets);
    expect(find.text('(7)'), findsOneWidget);
    expect(find.text('Won by 4'), findsOneWidget);
    expect(find.text('Who was ahead'), findsOneWidget);
    expect(find.text('Scores over the match'), findsOneWidget);
    expect(find.text("Clontarf's biggest lead"), findsOneWidget);
    expect(find.text('1st half'), findsOneWidget);
    expect(find.text('Final'), findsOneWidget);
    expect(find.text('Clontarf scorers'), findsOneWidget);
    expect(find.text('THROW-IN'), findsOneWidget);
    expect(find.text('FULL TIME'), findsOneWidget);
    expect(find.text('TIMELINE'), findsOneWidget);
    expect(find.text('Clontarf scored 3 in a row'), findsOneWidget);
    expect(find.text('GOAL'), findsOneWidget);
    expect(find.text('Wide'), findsNothing);
  });

  testWidgets('several sessions: picker, open one, back to the picker',
      (tester) async {
    await big(tester);
    await tester.pumpWidget(MaterialApp(
        home: V3MatchStatsPage(eventId: 1, testData: {
      'list': list2,
      'sessions': {'12': session()},
    })));
    await tester.pumpAndSettle();
    expect(find.text('2 sessions · 1 live — tap to view'), findsOneWidget);
    expect(find.text('Mine'), findsOneWidget);
    expect(find.text('Final'), findsOneWidget);
    expect(find.text('Live'), findsOneWidget);
    await tester.tap(find.text('Ken Darcy · Blue'));
    await tester.pumpAndSettle();
    expect(find.text('Won by 4'), findsOneWidget);
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    expect(find.text('Ken Darcy · Blue'), findsOneWidget);
    // A session that was reset shows the error.
    await tester.tap(find.text('Unknown'));
    await tester.pumpAndSettle();
    expect(find.text('Unable to load chart'), findsOneWidget);
  });

  testWidgets('no sessions yet: waiting for the match to start',
      (tester) async {
    await big(tester);
    await tester.pumpWidget(MaterialApp(
        home: V3MatchStatsPage(
            eventId: 1, testData: const {'list': [], 'sessions': {}})));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('WAITING FOR\nMATCH TO START'), findsOneWidget);
    expect(find.text('LISTENING FOR SCOREKEEPER'), findsOneWidget);
    expect(find.text('PDF'), findsNothing);
  });

  testWidgets('a live session with no scores waits for the first score',
      (tester) async {
    await big(tester);
    await tester.pumpWidget(MaterialApp(
        home: V3MatchStatsPage(eventId: 1, matchStatsId: 12, testData: {
      'list': [],
      'sessions': {
        '12': {...session(finished: false), 'events': [], 'subs': []}
      },
    })));
    await tester.pumpAndSettle();
    expect(find.text('Waiting for the first score…'), findsOneWidget);
    expect(find.text('No scores yet'), findsOneWidget);
    expect(find.text('SECOND HALF'), findsOneWidget);
  });
}
