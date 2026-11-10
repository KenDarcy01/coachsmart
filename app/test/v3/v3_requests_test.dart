import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:coach_smart_v2/v3/teams/v3_requests_models.dart';
import 'package:coach_smart_v2/v3/teams/v3_requests_page.dart';

Map<String, dynamic> sample() => {
      'success': true,
      'member_requests': [
        {
          'member_team_id': 11,
          'member_id': 101,
          'first_name': 'Seán',
          'last_name': 'Byrne',
          'requested_at': DateTime.now()
              .subtract(const Duration(hours: 2))
              .toIso8601String(),
          'requesting_user_id': 'u1',
          'requesting_user_name': 'Mary Byrne',
          'requesting_user_email': 'mary@example.com',
        },
        {
          'member_team_id': 12,
          'member_id': 102,
          'first_name': 'Cillian',
          'last_name': 'Walsh',
          'requested_at': DateTime.now()
              .subtract(const Duration(days: 1))
              .toIso8601String(),
          'requesting_user_id': null,
          'requesting_user_name': null,
          'requesting_user_email': null,
        },
      ],
      'access_requests': [
        {
          'user_member_id': 31,
          'member_id': 103,
          'first_name': 'Aoife',
          'last_name': 'Darcy',
          'requested_at': DateTime.now()
              .subtract(const Duration(days: 10))
              .toIso8601String(),
          'requesting_user_id': 'u2',
          'requesting_user_name': 'Paul Darcy',
          'requesting_user_email': 'paul@example.com',
        },
      ],
      'available_roles': [
        {
          'role_id': 1,
          'role_name': 'Admin',
          'role_grade': 100,
          'role_level': 100
        },
        {
          'role_id': 2,
          'role_name': 'Player',
          'role_grade': 10,
          'role_level': 10
        },
      ],
    };

void main() {
  test('rows parse with subtitles and when labels', () {
    final d = TeamRequests.fromJson(sample());
    expect(d.ok, isTrue);
    expect(d.joins.length, 2);
    expect(d.access.length, 1);
    expect(d.roles.length, 2);
    expect(d.joins[0].name, 'Seán Byrne');
    expect(d.joins[0].subtitle('Boys 2014'),
        'Wants to join Boys 2014\nRequested by Mary Byrne (mary@example.com)');
    expect(d.joins[1].subtitle('Boys 2014'), 'Wants to join Boys 2014');
    expect(d.access[0].isAccess, isTrue);
    expect(d.access[0].refId, 31);
    expect(d.access[0].subtitle('Boys 2014'),
        'Paul Darcy (paul@example.com) asks for access');
    final now = DateTime(2026, 11, 10, 12);
    expect(whenLabel(now, now), 'Today');
    expect(whenLabel(DateTime(2026, 11, 9, 23), now), 'Yesterday');
    expect(whenLabel(DateTime(2026, 11, 8, 9), now), 'Sun');
    expect(whenLabel(DateTime(2026, 11, 1, 9), now), '1 Nov');
    expect(whenLabel(null, now), '');
  });

  test('empty result and failure', () {
    expect(TeamRequests.fromJson({'success': true}).isEmpty, isTrue);
    expect(
        TeamRequests.fromJson({'success': false, 'message': 'x'}).ok, isFalse);
  });

  testWidgets('page shows both sections with their buttons', (tester) async {
    await tester.pumpWidget(MaterialApp(
        home: V3RequestsPage(
            teamId: 1, testData: sample(), testTeamName: 'Boys 2014')));
    await tester.pumpAndSettle();
    expect(find.text('JOIN REQUESTS'), findsOneWidget);
    expect(find.text('ACCESS REQUESTS'), findsOneWidget);
    expect(find.text('Approve'), findsNWidgets(2));
    expect(find.text('Give access'), findsOneWidget);
    expect(find.text('Decline'), findsNWidgets(3));
    expect(find.textContaining('Wants to join Boys 2014'), findsNWidgets(2));
  });

  testWidgets('empty state', (tester) async {
    await tester.pumpWidget(MaterialApp(
        home: V3RequestsPage(
            teamId: 1,
            testData: const {'success': true},
            testTeamName: 'Boys 2014')));
    await tester.pumpAndSettle();
    expect(find.text('No requests waiting.'), findsOneWidget);
    expect(find.textContaining('Boys 2014'), findsOneWidget);
  });
}
