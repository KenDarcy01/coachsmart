import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:coach_smart_v2/v3/member_stats/v3_member_stats_models.dart';
import 'package:coach_smart_v2/v3/member_stats/v3_member_stats_page.dart';

final now = DateTime(2026, 11, 11, 12);

String at(int y, int m, int d, [int h = 19]) =>
    DateTime(y, m, d, h).toUtc().toIso8601String();

Map<String, dynamic> ev(
        int id, String date, String type, String? code, int? response,
        {String? title, String? opp, String? homeAway}) =>
    {
      'event_id': id,
      'event_title': title ?? type,
      'event_date_time': date,
      'event_type': type,
      'event_code': code,
      'team_id': 7,
      'team_name': 'U14 Girls',
      'opposition': opp,
      'home_away': homeAway,
      'response_id': response,
    };

Map<String, dynamic> sel(int id, String date, String code, String squad,
        {String? opp, String role = 'Player'}) =>
    {
      'event_id': id,
      'event_title': 'League',
      'event_date_time': date,
      'event_type': 'Match',
      'event_code': code,
      'opposition': opp,
      'home_away': 'Home',
      'team_id': 7,
      'team_name': 'U14 Girls',
      'squad_id': 1,
      'squad_name': squad,
      'role_id': 1,
      'role_name': role,
    };

Map<String, dynamic> sample() => {
      'member': {
        'member_id': 5,
        'first_name': 'Aoife',
        'last_name': 'Ní Bhriain'
      },
      'teams': [
        {'team_id': 7, 'team_name': 'U14 Girls', 'team_female': true}
      ],
      'events': [
        ev(1, at(2026, 11, 4), 'Training', 'Football', 3),
        ev(1, at(2026, 11, 4), 'Training', 'Football', 3), // duplicate
        ev(2, at(2026, 11, 6), 'Training', 'Hurling', 4),
        ev(3, at(2026, 10, 20), 'Match', 'Football', 3,
            title: 'League', opp: 'Raheny', homeAway: 'Away'),
        ev(4, at(2026, 10, 10), 'Match', 'Hurling', null, opp: 'Crokes'),
        ev(5, at(2026, 10, 1), 'Meeting', '-', 3),
        ev(6, at(2026, 11, 15), 'Training', 'Football', null),
        ev(7, at(2025, 3, 1), 'Training', 'Football', 3),
        ev(8, at(2025, 4, 1), 'Training', 'Football', 3),
        ev(9, at(2025, 5, 1), 'Training', 'Football', 4),
        {'event_id': 99, 'event_date_time': null}, // no date: dropped
      ],
      'matchSelections': [
        sel(3, at(2026, 10, 20), 'Football', 'Blue', opp: 'Raheny'),
        sel(4, at(2026, 10, 10), 'Hurling', 'Not selected', opp: 'Crokes'),
        sel(10, at(2026, 9, 12), 'Football', 'Blue',
            opp: 'Vincents', role: 'Captain'),
      ],
    };

void main() {
  test('parses, dedupes, cleans codes and says Camogie for girls', () {
    final d = MemberStats.fromJson(sample());
    expect(d.name, 'Aoife Ní Bhriain');
    expect(d.events.length, 9);
    expect(d.events.firstWhere((e) => e.eventId == 5).code, isNull);
    expect(d.isFemale, isTrue);
    expect(d.codeLabel('Hurling'), 'Camogie');
    expect(d.multiCode, isTrue);
    final o = d.options;
    expect(o.code.map((p) => p.$1), ['Camogie', 'Football', kNoCode]);
    expect(o.defaults['code'], {'Camogie', 'Football'}); // no code starts off
    expect(o.any, isTrue);
  });

  test('season view: hero, trend, splits, matches', () {
    final d = MemberStats.fromJson(sample());
    final f = Filters.initial(d.options);
    final v = computeView(d, f, now);
    expect(v.past.map((e) => e.eventId), [2, 1, 3, 4]);
    expect(v.upcoming.map((e) => e.eventId), [6]);
    final h = heroStats(v)!;
    expect(h.rate, 50);
    expect(h.replied, 3);
    expect(h.trend, '▼ 17% on this time last year');
    expect(h.last, [Reply.none, Reply.yes, Reply.yes, Reply.no]);
    expect(v.trainings.length, 2);
    expect(v.pastMatches.length, 2);
    // "Not selected" isn't a pick; a pick with no event row still counts.
    expect(v.matches.map((m) => m.e.eventId), [3, 4, 10]);
    expect(v.matches.map((m) => m.squad), ['Blue', null, 'Blue']);
    expect(matchTitle(v.matches.first), 'vs Raheny');
    expect(meta(matchMeta(v.matches.first), 'vs Raheny'), 'League · Away');
    expect(meta(matchMeta(v.matches.last), 'vs Vincents'),
        'League · Home · Captain');
    expect(topSquad(v.matches), 'Blue');
  });

  test('code cards, squad cards and month bars', () {
    final d = MemberStats.fromJson(sample());
    final v = computeView(d, Filters.initial(d.options), now);
    final cards = codeCards(d, v);
    expect(cards.map((c) => c.code), ['Camogie', 'Football']);
    expect(cards[0].went, 0);
    expect(cards[0].total, 2);
    expect(cards[1].picked, 2);
    expect(cards[1].matches, 2);
    final sq = squadCards(d, v);
    expect(sq.single.code, 'Football');
    expect(sq.single.rows, [('Blue', 2)]);
    final bars = monthBars(v, now);
    expect(bars.length, 11); // Jan to Nov
    expect(bars.first.label, 'J');
    expect(bars[9].pct, 50); // Oct
    expect(bars[8].pct, isNull); // Sep
  });

  test('focus narrows the lists; filters and periods', () {
    final d = MemberStats.fromJson(sample());
    final f = Filters.initial(d.options);
    final v = computeView(d, f, now);
    final oct = monthBars(v, now)[9];
    final fm = StatsFocus.month(oct);
    expect(fm.label, 'Oct 2026');
    expect(fm.events(d, v, v.past).map((e) => e.eventId), [3, 4]);
    final fs = StatsFocus.squad('Football', 'Blue', showCode: false);
    expect(fs.events(d, v, v.past).map((e) => e.eventId), [3]);
    expect(fs.matches(d, v.matches).length, 2);
    expect(StatsFocus.type(false).matches(d, v.matches), isEmpty);

    f.on['code']!.add(kNoCode);
    expect(computeView(d, f, now).past.length, 5);
    expect(f.label(d.options, 'code'), 'Camogie, Football, - (no code)');
    f.on['type'] = {};
    expect(f.label(d.options, 'type'), 'No event type');
    expect(f.changed(d.options), ['code', 'type']);

    final f2 = Filters.initial(d.options)..period = Period.month;
    final v2 = computeView(d, f2, now);
    expect(v2.range.label, 'Nov 2026');
    expect(v2.past.map((e) => e.eventId), [2, 1]);
    expect(periodRange(Period.threeMonths, now).label, 'Sep – Nov 2026');
  });

  test('row wording and pdf names', () {
    final d = MemberStats.fromJson(sample());
    final e = d.events.firstWhere((e) => e.eventId == 3);
    expect(eventTitle(e), 'vs Raheny');
    expect(typeLabel(e), isNull);
    expect(dateBlock(e.date!, now), ('20', 'OCT'));
    expect(dateBlock(DateTime(2025, 3, 1), now), ('1', 'MAR ’25'));
    expect(dayTime(DateTime(2026, 11, 15, 9, 5)), 'Sun 09:05');
    expect(pdfFileName('Aoife Ní Bhriain'), 'Aoife-Ni-Bhriain-stats.pdf');
    expect(pdfFileName(''), 'player-stats.pdf');
    final f = Filters.initial(d.options);
    expect(pdfSubtitle(d, f, periodRange(Period.season, now)),
        '2026 season · U14 Girls');
  });

  testWidgets('page shows every section and the focus works', (tester) async {
    tester.view.physicalSize = const Size(390 * 3, 2600 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
        home: V3MemberStatsPage(memberId: 5, testData: sample(), now: now)));
    await tester.pumpAndSettle();
    expect(find.text('Aoife Ní Bhriain'), findsOneWidget);
    expect(find.text('Attended 2 of 4'), findsOneWidget);
    expect(find.text('Trainings attended'), findsOneWidget);
    expect(find.text('Squad selections'), findsOneWidget);
    expect(find.text('Coming up'), findsOneWidget);
    expect(find.text('Reply needed'), findsOneWidget);
    expect(find.text('Attendance by month'), findsOneWidget);
    expect(find.text('Matches'), findsOneWidget);
    expect(find.text('History'), findsOneWidget);
    expect(find.text('vs Raheny'), findsWidgets);
    expect(find.text('Not selected'), findsOneWidget);

    // Tap the trainings card: lists show trainings, Matches list hides.
    await tester.tap(find.text('Trainings attended'));
    await tester.pumpAndSettle();
    expect(find.text('Showing: Trainings ✕'), findsOneWidget);
    expect(find.text('Matches'), findsNothing);
    await tester.tap(find.text('Showing: Trainings ✕'));
    await tester.pumpAndSettle();
    expect(find.text('Matches'), findsOneWidget);

    // History segment.
    await tester.tap(find.text('Missed'));
    await tester.pumpAndSettle();
    expect(find.text('Declined'), findsOneWidget);
    expect(find.text('Went'), findsOneWidget); // the segment label only

    // A code card filters the page to that code, with a chip to undo.
    await tester.tap(find.text('CAMOGIE').first);
    await tester.pumpAndSettle();
    expect(find.text('Camogie ✕'), findsOneWidget);
    expect(find.text('Attended 0 of 2'), findsOneWidget);
    await tester.tap(find.text('Camogie ✕'));
    await tester.pumpAndSettle();
    expect(find.text('Attended 2 of 4'), findsOneWidget);

    // Period switch.
    await tester.tap(find.text('Month'));
    await tester.pumpAndSettle();
    expect(find.text('Attended 1 of 2'), findsOneWidget);
  });
}
