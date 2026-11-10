import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:coach_smart_v2/v3/search/v3_search_models.dart';
import 'package:coach_smart_v2/v3/search/v3_search_page.dart';

Map<String, dynamic> team(int id, String name) => {
      'team_id': id,
      'team_name': name,
      'club_id': 1,
      'club_name': 'Clontarf',
      'event_types': [
        {'id': 1, 'name': 'Training'},
        {'id': 2, 'name': 'Match'},
      ],
      'event_codes': [
        {'id': 1, 'name': 'Football'},
        {'id': 2, 'name': 'Hurling'},
      ],
    };

Map<String, dynamic> ev(int id, String title, {String status = 'active'}) => {
      'event_id': id,
      'team_id': 5,
      'event_title': title,
      'team_name': 'Boys 2014',
      'event_type': 'Match',
      'event_code': 'Football',
      'opposition': 'Raheny',
      'event_status': status,
      'event_date_time_formatted': 'Saturday, 07 November, 2026 at 10:00',
      'accepted_count': 12,
      'declined_count': 2,
      'no_response_count': 5,
      'total_eligible_members': 19,
    };

void main() {
  test('rows parse and dates shorten', () {
    final e = SearchEvent.fromJson(ev(1, 'Football Match v Raheny'));
    expect(e.eventId, 1);
    expect(e.accepted, 12);
    expect(e.time!.toUtc(), DateTime.utc(2026, 11, 7, 10));
    expect(e.dateLabel, startsWith('Sat 7 Nov 2026 · '));
    expect(SearchEvent.fromJson(ev(2, 'x', status: 'cancelled')).cancelled,
        isTrue);
    expect(searchDateLabel('odd'), 'odd');
  });

  test('filters send 0 and empty for any', () {
    final p = SearchFilters(teamId: 5).toParams();
    expect(p['p_team_id'], 5);
    expect(p['p_type_id'], 0);
    expect(p['p_date_from'], '');
    final q = SearchFilters(
            teamId: 5,
            from: DateTime(2026, 11, 1),
            to: DateTime(2026, 11, 30),
            opposition: ' Raheny ')
        .toParams();
    expect(q['p_date_from'], '2026-11-01');
    expect(q['p_date_to'], '2026-12-01');
    expect(q['p_opposition'], 'Raheny');
  });

  testWidgets('page shows chips, searches and lists results', (tester) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
        home: V3SearchPage(testTeams: [
      team(5, 'Boys 2014'),
      team(6, 'Girls 2015')
    ], testResults: [
      ev(1, 'Football Match v Raheny'),
      ev(2, 'Training')
    ])));
    await tester.pumpAndSettle();
    expect(find.text('Boys 2014'), findsOneWidget);
    expect(find.text('Girls 2015'), findsOneWidget);
    await tester.tap(find.text('Boys 2014'));
    await tester.pumpAndSettle();
    expect(find.text('Match'), findsOneWidget);
    expect(find.text('Hurling'), findsOneWidget);
    await tester.tap(find.text('Search'));
    await tester.pumpAndSettle();
    expect(find.text('2 events'), findsOneWidget);
    expect(find.text('Football Match v Raheny'), findsOneWidget);
    expect(find.text('12'), findsNWidgets(2));
  });
}
