import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:coach_smart_v2/v3/analytics/v3_analytics_models.dart';
import 'package:coach_smart_v2/v3/analytics/v3_analytics_page.dart';
import 'package:coach_smart_v2/v3/analytics/v3_analytics_pdf.dart';

final now = DateTime(2026, 11, 11, 12);

Map<String, dynamic> member(int id, String name, String resp,
        {String role = 'Player', int? squad}) =>
    {
      'member_id': id,
      'name': name,
      'role': role,
      'response': resp,
      'squad_id': squad,
    };

Map<String, dynamic> event(
        int id, DateTime d, String type, List<Map<String, dynamic>> members,
        {String code = 'Football', String opp = '', String title = ''}) =>
    {
      'event_id': id,
      'date': d.toUtc().toIso8601String(),
      'title': title.isEmpty ? '$code $type' : title,
      'code': code,
      'type': type,
      'opposition': opp,
      'home_away': opp.isEmpty ? null : 'Home',
      'members': members,
    };

/// Team 1 (admin): trainings and matches through 2026 plus a few in 2025.
/// Team 2 (admin, female hurling): two camogie trainings.
/// Team 3 is not an admin team and must not show.
Map<String, dynamic> dashboard() {
  final t1 = <Map<String, dynamic>>[];
  var id = 100;
  // Training every month Jan-Oct 2026: Aoife always, Brian Feb-May only,
  // Cian never replies.
  for (var m = 1; m <= 10; m++) {
    t1.add(event(id++, DateTime(2026, m, 10, 19), 'Training', [
      member(1, 'Aoife Byrne', 'accepted'),
      member(2, 'Brian Kelly', m >= 2 && m <= 5 ? 'accepted' : 'declined'),
      member(3, 'Cian Walsh', 'no_response'),
      member(9, 'Coach Mary', 'accepted', role: 'Coach'),
    ]));
  }
  // Two matches with squads saved.
  t1.add(event(
      id++,
      DateTime(2026, 6, 14, 11),
      'Match',
      [
        member(1, 'Aoife Byrne', 'accepted', squad: 51),
        member(2, 'Brian Kelly', 'accepted', squad: 52),
        member(3, 'Cian Walsh', 'no_response', squad: 53),
      ],
      opp: 'Raheny'));
  t1.add(event(
      id++,
      DateTime(2026, 9, 20, 11),
      'Match',
      [
        member(1, 'Aoife Byrne', 'accepted', squad: 52),
        member(2, 'Brian Kelly', 'declined'),
        member(3, 'Cian Walsh', 'no_response'),
      ],
      opp: 'Clontarf'));
  // Last year, for the trend line.
  for (var m = 1; m <= 4; m++) {
    t1.add(event(id++, DateTime(2025, m, 12, 19), 'Training', [
      member(1, 'Aoife Byrne', 'declined'),
      member(2, 'Brian Kelly', 'declined'),
      member(3, 'Cian Walsh', 'accepted'),
    ]));
  }
  t1.sort((a, b) => (b['date'] as String).compareTo(a['date'] as String));
  return {
    'club_name': 'St Annes',
    'club_id': 5,
    'squads': [
      {
        'squad_id': 51,
        'squad_name': 'Blue',
        'team_id': 1,
        'seq': 1,
        'colour': '#3B82F6'
      },
      {
        'squad_id': 52,
        'squad_name': 'Red',
        'team_id': 1,
        'seq': 2,
        'colour': '0xFF000000'
      },
      {
        'squad_id': 53,
        'squad_name': 'Not selected',
        'team_id': 1,
        'seq': 3,
        'colour': ''
      },
    ],
    'teams': [
      {
        'team_id': 1,
        'team_name': 'U14 Boys',
        'team_female': false,
        'member_roles': [
          {
            'role': 'Player',
            'count': 3,
            'members': [
              {'member_id': 1, 'name': 'Aoife Byrne'},
              {'member_id': 2, 'name': 'Brian Kelly'},
              {'member_id': 3, 'name': 'Cian Walsh'},
            ]
          }
        ],
        'events': t1,
      },
      {
        'team_id': 2,
        'team_name': 'U12 Girls',
        'team_female': true,
        'member_roles': [],
        'events': [
          event(300, DateTime(2026, 10, 1, 18), 'Training',
              [member(7, 'Orla Doyle', 'accepted')],
              code: 'Hurling'),
          event(301, DateTime(2026, 10, 8, 18), 'Training',
              [member(7, 'Orla Doyle', 'declined')],
              code: 'Hurling'),
        ],
      },
      {
        'team_id': 3,
        'team_name': 'Seniors',
        'team_female': false,
        'member_roles': [],
        'events': [
          event(400, DateTime(2026, 10, 1, 18), 'Training',
              [member(8, 'Sean Hidden', 'accepted')])
        ],
      },
    ],
  };
}

Map<String, dynamic> testData() => {
      'admin_teams': [
        {
          'team_id': 1,
          'team_name': 'U14 Boys',
          'club_id': 5,
          'club_name': 'St Annes'
        },
        {
          'team_id': 2,
          'team_name': 'U12 Girls',
          'club_id': 5,
          'club_name': 'St Annes'
        },
      ],
      'default_club': 5,
      'dashboard': dashboard(),
    };

AnData data() => normalise(dashboard(), {1, 2}, 5, DateTime(2025, 1, 1));

void main() {
  group('models', modelTests);
  group('page', widgetTests);
}

void modelTests() {
  test('normalise keeps admin teams, Camogie label and real squads', () {
    final d = data();
    expect(d.teams.map((t) => t.name), ['U14 Boys', 'U12 Girls']);
    expect(d.events.any((e) => e.teamId == 3), isFalse);
    expect(d.events.first.date.isAfter(d.events.last.date), isTrue);
    final camogie = d.events.firstWhere((e) => e.teamId == 2);
    expect(camogie.code, 'Camogie');
    final match = d.events.firstWhere((e) => e.id == 110);
    // "Not selected" is not a real squad.
    expect(match.members.firstWhere((m) => m.id == 3).squadId, isNull);
    // Black is too dark to see, so Red gets a palette colour.
    expect(d.squads[51]!.hex, const Color(0xFF3B82F6));
    expect(d.squads[52]!.hex, isNot(const Color(0xFF000000)));
    expect(d.squads[52]!.hex, isNot(d.squads[51]!.hex));
  });

  test('compact v3 rows: roster once, id lists per event, merge older', () {
    Map ev(int id, String date, List y, List n, List x, [List p = const []]) =>
        {
          'event_id': id,
          'date': date,
          'title': 'Training',
          'code': 'Hurling',
          'type': 'Training',
          'y': y,
          'n': n,
          'x': x,
          'p': p,
        };
    Map json(List events) => {
          'club_name': 'Clontarf',
          'squads': [
            {
              'squad_id': 4,
              'squad_name': 'Red',
              'team_id': 1,
              'colour': '#e53935'
            }
          ],
          'teams': [
            {
              'team_id': 1,
              'team_name': 'U14 Girls',
              'team_female': true,
              'people': [
                [10, 'Aoife B', 'Player', 10],
                [11, 'Ciara D', 'Player', 10],
                [12, 'Pat Coach', 'Coach', 30],
              ],
              'events': events,
            }
          ],
        };
    final now = normalise(
        json([
          ev(2, '2026-03-02T19:00:00Z', [
            10
          ], [
            11
          ], [
            12
          ], [
            [10, 4]
          ])
        ]),
        {1},
        1,
        DateTime(2026));
    final e = now.events.single;
    expect(e.code, 'Camogie');
    expect([for (final m in e.members) m.name],
        ['Aoife B', 'Ciara D', 'Pat Coach']);
    expect([for (final m in e.members) m.response],
        ['accepted', 'declined', 'no_response']);
    expect(e.members.first.squadId, 4);
    expect(e.total, 3);
    expect(e.nr, 1);
    expect(
        [for (final r in now.teams.single.roles) r.role], ['Player', 'Coach']);
    final older = normalise(
        json([
          ev(1, '2025-03-02T19:00:00Z', [], [], [10, 11])
        ]),
        {1},
        1,
        DateTime(2025));
    final all = mergeOlder(now, older);
    expect(all.from, DateTime(2025));
    expect([for (final e in all.events) e.id], [2, 1]);
  });

  test('clubs and default club', () {
    final clubs = clubsOf([
      const AdminTeam(1, 'A', 9, 'Zeta'),
      const AdminTeam(2, 'B', 5, 'Alpha'),
    ]);
    expect(clubs.map((c) => c.name), ['Alpha', 'Zeta']);
    expect(defaultClubFor(clubs, 9), 9);
    expect(defaultClubFor(clubs, 77), 5);
    expect(defaultClubFor(clubs, null), 5);
  });

  test('periods and the comparison window', () {
    final s = periodRange(AnPeriod.season, null, now);
    expect(s.label, '2026 season');
    expect(s.from, DateTime(2026, 1, 1));
    expect(s.prevFrom, DateTime(2025, 1, 1));
    expect(s.prevLabel, 'this time last year');
    expect(periodRange(AnPeriod.month, null, now).label, 'Nov 2026');
    expect(
        periodRange(AnPeriod.threeMonths, null, now).label, 'Sep – Nov 2026');
    final all = periodRange(AnPeriod.all, null, now);
    expect(all.from, isNull);
    expect(needFrom(all), kAllFrom);
    expect(monthsAgo(DateTime(2026, 3, 31), 1), DateTime(2026, 2, 28, 23, 59));
    final c = periodRange(AnPeriod.season,
        AnCustom(DateTime(2026, 9, 1), DateTime(2026, 9, 30, 23, 59)), now);
    expect(c.label, '1 Sep 2026 – 30 Sep 2026');
    expect(c.prevLabel, 'the period before');
  });

  test('filters: no code off by default, labels and chips', () {
    final d = data();
    final f = AnFilters()..rebuild(d);
    expect(f.options['code']!.map((o) => o.$1), ['Camogie', 'Football']);
    expect(f.label('team'), 'All');
    expect(f.changedLabels(), isEmpty);
    f.toggle('team', '2');
    expect(f.changedLabels(), ['Teams: U14 Boys']);
    f.none('type');
    expect(f.label('type'), 'None');
    // Rebuilding keeps a changed group's picks.
    f.rebuild(d);
    expect(f.on['team'], {'1'});
    f.resetAll();
    expect(f.changed, isEmpty);
  });

  test('totals, team ranking and trend', () {
    final d = data();
    final f = AnFilters()..rebuild(d);
    final ctx = contextFor(d, f, periodRange(AnPeriod.season, null, now));
    // 12 team 1 events this season + 2 team 2 events.
    expect(ctx.evs.length, 14);
    final teams = teamRanking(ctx, 'az');
    expect(teams.map((t) => t.name), ['U12 Girls', 'U14 Boys']);
    final u14 = teams.last;
    expect(u14.players, 4);
    expect(u14.trend, isNotNull); // 4 events last year
    expect(trendText(0, 'x')!.text, 'Same as x');
    expect(trendText(-12, 'this time last year')!.text,
        '▼ 12% on this time last year');
    final t = totals(ctx.evs);
    expect(t.total, t.acc + t.dec + t.nr);
  });

  test('players: stats, movers, sorts and badges', () {
    final d = data();
    final f = AnFilters()..rebuild(d);
    final ctx =
        contextFor(d, f, periodRange(AnPeriod.season, null, now), teamId: 1);
    final stats = playerStats(ctx.evs);
    movers(ctx, stats);
    expect(stats[1]!.rate, 100);
    expect(stats[3]!.rate, 0);
    expect(stats[3]!.nr, stats[3]!.events);
    // Brian went in the first half and stopped in the second.
    expect(stats[2]!.delta, lessThan(0));
    expect(playerList(stats.values, '', 'dropping').map((p) => p.id), [2]);
    expect(playerList(stats.values, 'aoi', 'low').map((p) => p.id), [1]);
    expect(playerList(stats.values, '', 'low').first.id, 3);
    final b = playerBadges(stats[3]!, 'low', false);
    expect(b.first.text, 'No reply ${stats[3]!.nr}');
    final (lo, mid, hi) = spread(stats.values);
    expect(lo + mid + hi, stats.length);
  });

  test('months chart covers the period', () {
    final d = data();
    final f = AnFilters()..rebuild(d);
    final ctx = contextFor(d, f, periodRange(AnPeriod.season, null, now));
    final ms = months(ctx);
    expect(ms.length, 11); // Jan to Nov
    expect(ms.last.pct, isNull); // nothing in November
    expect(monthLabel(DateTime(2026, 1), 11), 'J');
    expect(monthLabel(DateTime(2026, 1), 3), 'Jan');
  });

  test('squads: picks, chances and buckets', () {
    final d = data();
    final f = AnFilters()..rebuild(d);
    final ctx = contextFor(d, f, periodRange(AnPeriod.season, null, now));
    final sm = SquadModel(d, ctx);
    expect(sm.withPicks.length, 2);
    expect(sm.picked, 2); // Aoife and Brian; Cian's "Not selected" is no pick
    expect(sm.poolN, 4);
    expect(sm.multi, 1); // Aoife played Blue and Red
    expect(sm.most.first.name, 'Aoife Byrne');
    expect(sm.most.first.total, 2);
    expect(sm.most.first.of, 2);
    final b = sm.buckets();
    expect(b[0], 1); // Cian never picked
    expect(b[4], 1); // Aoife every match
    expect(b[2], 1); // Brian 1 of 2
    expect(sm.squadList.map((s) => sm.sqName(s.id)), ['Blue', 'Red']);
    expect(squadMembers(sm, 52).first.$3, 1);
  });

  test('event titles and subs', () {
    final d = data();
    final m = d.events.firstWhere((e) => e.id == 110);
    expect(eventTitle(m), 'vs Raheny');
    final tr = d.events.firstWhere((e) => e.id == 100);
    expect(eventTitle(tr), 'Training');
    expect(eventSub(tr), 'U14 Boys · Football training · Sat 10 Jan 2026');
    final camogie = d.events.firstWhere((e) => e.id == 300);
    expect(eventTitle(camogie), 'Training');
    final ordered = eventMembers(m, 'all');
    expect(ordered.last.response, 'no_response');
  });

  test('colours, names and numbers', () {
    expect(hexOf('#000'), isNull);
    expect(hexOf('#FFFFFF'), const Color(0xFFE2E6EE));
    expect(hexOf('0xFF3B82F6'), const Color(0xFF3B82F6));
    expect(hexOf('nope'), isNull);
    expect(fmtN(1234567), '1,234,567');
    expect(plural(1, 'match', 'matches'), '1 match');
    expect(plural(2, 'player'), '2 players');
    expect(initials('aoife byrne'), 'AB');
    expect(pdfFileBase('Seán Ó Briain team'), 'Sean-O-Briain-team');
  });

  test('reports and the PDF build', () async {
    final d = data();
    final f = AnFilters()..rebuild(d);
    final r = periodRange(AnPeriod.season, null, now);
    final ctx = contextFor(d, f, r);
    final reports = [
      teamsReport(d, f, ctx, 'att', r.label),
      playersReport(d, ctx, 'low', '', r.label),
      squadsReport(d, ctx, r.label),
      teamPageReport(
          d, d.team(1)!, f, contextFor(d, f, r, teamId: 1), 'low', r.label),
      eventReport(d, d.events.firstWhere((e) => e.id == 110), 'all'),
    ];
    expect(reports[2].title, 'St Annes · Match squads');
    final bytes = await buildReportPdf(reports[3], now);
    expect(bytes.length, greaterThan(500));
  });
}

void widgetTests() {
  Future<void> pump(WidgetTester tester, Map<String, dynamic> td) async {
    tester.view.physicalSize = const Size(390 * 3, 1400 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
        MaterialApp(home: V3AnalyticsPage(testData: td, testNow: now)));
    await tester.pumpAndSettle();
  }

  testWidgets('teams tab, team page and back', (tester) async {
    await pump(tester, testData());
    expect(find.text('Club Analytics'), findsOneWidget);
    expect(find.text('Teams'), findsOneWidget);
    expect(find.text('Season'), findsOneWidget);
    expect(find.text('U14 Boys'), findsOneWidget);
    expect(find.text('U12 Girls'), findsOneWidget);
    expect(find.text('Seniors'), findsNothing);

    await tester.tap(find.text('U14 Boys'));
    await tester.pumpAndSettle();
    expect(find.text('2026 season · 4 players · 12 events'), findsOneWidget);
    expect(find.text('Training attendance'), findsOneWidget);
    expect(find.text('Match availability'), findsOneWidget);
    expect(find.text('Player 3'), findsOneWidget);
    expect(find.text('PLAYERS'), findsOneWidget);

    await tester.tap(find.byTooltip('Teams'));
    await tester.pumpAndSettle();
    expect(find.text('U12 Girls'), findsOneWidget);
  });

  testWidgets('players and squads tabs', (tester) async {
    await pump(tester, testData());
    await tester.tap(find.text('Players'));
    await tester.pumpAndSettle();
    expect(find.text('5 players'), findsOneWidget);
    expect(find.text('Search players'), findsOneWidget);
    expect(find.text('Tap a player to open their full stats page'),
        findsOneWidget);
    await tester.enterText(find.byType(TextField), 'zzz');
    await tester.pumpAndSettle();
    expect(find.text('No players match'), findsOneWidget);

    await tester.tap(find.text('Squads'));
    await tester.pumpAndSettle();
    expect(find.text('2 of 4 players picked'), findsOneWidget);
    expect(find.text('SQUAD SPLIT'), findsOneWidget);
    expect(find.text('Blue'), findsWidgets);
  });

  testWidgets('month period with no events shows the empty state',
      (tester) async {
    await pump(tester, testData());
    await tester.tap(find.text('Month'));
    await tester.pumpAndSettle();
    expect(find.text('No events in this period'), findsOneWidget);
  });

  testWidgets('filter sheet changes the view and shows a chip', (tester) async {
    await pump(tester, testData());
    await tester.tap(find.byTooltip('Filters'));
    await tester.pumpAndSettle();
    expect(find.text('Filters'), findsOneWidget);
    expect(find.text('CUSTOM DATES'), findsOneWidget);
    await tester.tap(find.text('U12 Girls').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    expect(find.text('Teams: U14 Boys'), findsOneWidget);
    expect(find.text('U12 Girls'), findsNothing);
    await tester.tap(find.text('Teams: U14 Boys'));
    await tester.pumpAndSettle();
    expect(find.text('U12 Girls'), findsOneWidget);
  });

  testWidgets('event sheet from the team page', (tester) async {
    await pump(tester, testData());
    await tester.tap(find.text('U14 Boys'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('vs Clontarf'), 300,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(find.text('vs Clontarf'));
    await tester.pumpAndSettle();
    expect(find.text('Going'), findsWidgets);
    expect(find.text('Share PDF'), findsOneWidget);
    expect(find.text('Aoife Byrne'), findsWidgets);
  });

  testWidgets('no admin teams', (tester) async {
    await pump(tester, {'admin_teams': [], 'dashboard': dashboard()});
    expect(find.text('No admin teams'), findsOneWidget);
  });
}
