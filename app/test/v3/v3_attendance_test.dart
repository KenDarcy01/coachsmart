import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:coach_smart_v2/v3/event/v3_attendance_page.dart';

import 'package:coach_smart_v2/v3/event/v3_attendance_models.dart';

Map<String, dynamic> sample() => {
      'event_id': 1,
      'event_title': 'Football Match v Raheny',
      'is_match': true,
      'user_role_level': 100,
      'team_id': 7,
      'code_id': 2,
      'event_squad_id': null,
      'allow_lineup': true,
      'match_squad_id': null,
      'published_at': null,
      'squads': [
        {'squad_id': 11, 'squad_name': 'Blue', 'squad_list_seq': 1},
        {'squad_id': 12, 'squad_name': 'Red', 'squad_list_seq': 2},
      ],
      'roles': [
        {
          'role_id': 1,
          'role_name': 'Player',
          'role_name_plural': 'Players',
          'role_level': 10
        },
        {
          'role_id': 3,
          'role_name': 'Coach',
          'role_name_plural': 'Coaches',
          'role_level': 30
        },
      ],
      'members': [
        {
          'member_id': 1,
          'member_name': 'Aimee Morris',
          'first_name': 'Aimee',
          'last_name': 'Morris',
          'role_id': 1,
          'role_level': 10,
          'squad_id': 11,
          'squad_name': 'Blue',
          'response_id': 3
        },
        {
          'member_id': 2,
          'member_name': 'Anna Ryan',
          'first_name': 'Anna',
          'last_name': 'Ryan',
          'role_id': 1,
          'role_level': 10,
          'squad_id': 12,
          'squad_name': 'Red',
          'response_id': 3
        },
        {
          'member_id': 3,
          'member_name': 'Fiadh Nolan',
          'first_name': 'Fiadh',
          'last_name': 'Nolan',
          'role_id': 1,
          'role_level': 10,
          'squad_id': null,
          'squad_name': null,
          'response_id': null
        },
        {
          'member_id': 4,
          'member_name': 'Ken Darcy',
          'first_name': 'Ken',
          'last_name': 'Darcy',
          'role_id': 3,
          'role_level': 30,
          'squad_id': 11,
          'squad_name': 'Blue',
          'response_id': 3
        },
        // Ken is also a player: two rows, one person.
        {
          'member_id': 4,
          'member_name': 'Ken Darcy',
          'first_name': 'Ken',
          'last_name': 'Darcy',
          'role_id': 1,
          'role_level': 10,
          'squad_id': 11,
          'squad_name': 'Blue',
          'response_id': 3
        },
        {
          'member_id': 5,
          'member_name': 'Tom Kelly',
          'first_name': 'Tom',
          'last_name': 'Kelly',
          'role_id': 3,
          'role_level': 30,
          'squad_id': 12,
          'squad_name': 'Red',
          'response_id': 4
        },
      ],
    };

void main() {
  widgetTests();
  test('tab counts are distinct people and no reply catches the rest', () {
    final d = AttendanceData.fromJson(sample());
    expect(d.count(kAttending), 3); // Aimee, Anna, Ken (once)
    expect(d.count(kNoReply), 1); // Fiadh
    expect(d.count(kDeclined), 1); // Tom
    expect(d.admin, isTrue);
    expect(d.published, isFalse);
  });

  test('role groups follow role order and squad filter applies', () {
    final d = AttendanceData.fromJson(sample());
    final all = d.groups(d.rows(kAttending, null));
    expect(all.map((g) => g.$1.plural), ['Players', 'Coaches']);
    // Inside a role: squad sequence first (Blue, then Red), then name.
    expect(all.first.$2.map((m) => m.memberName),
        ['Aimee Morris', 'Ken Darcy', 'Anna Ryan']);
    final red = d.groups(d.rows(kAttending, 12));
    expect(red.length, 1);
    expect(red.first.$2.single.memberName, 'Anna Ryan');
    expect(d.rows(kNoReply, 0).single.memberName, 'Fiadh Nolan');
  });

  test('squad cards: each squad, No squad only when someone has none', () {
    final d = AttendanceData.fromJson(sample());
    final att = d.squadCards(kAttending);
    expect(att.map((c) => c.name), ['Blue', 'Red']);
    expect(att[0].count, 2); // Aimee + Ken
    expect(att[0].lines, ['Players: 2', 'Coaches: 1']);
    final none = d.squadCards(kNoReply);
    expect(none.map((c) => c.name), ['Blue', 'Red', 'No squad']);
    expect(none.last.count, 1);
  });

  test('published label and empty text', () {
    expect(publishedLabel(null), 'Not published yet');
    expect(publishedLabel(DateTime(2026, 11, 7, 10, 2)),
        'Published Sat 7 Nov, 10:02');
    expect(emptyText(kNoReply), 'Everyone has replied.');
    final d = AttendanceData.fromJson({'error': 'nope'});
    expect(d.hasError, isTrue);
  });
}

// Widget smoke test: the page renders tabs, squad cards and rows from data.
void widgetTests() {
  testWidgets('attendance page shows tabs, squad cards and grouped rows',
      (tester) async {
    tester.view.physicalSize = const Size(390 * 3, 1200 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
        home: V3AttendancePage(eventId: 1, responseId: 3, testData: sample())));
    await tester.pumpAndSettle();
    expect(find.text('Football Match v Raheny'), findsOneWidget);
    expect(find.text('Attending'), findsOneWidget);
    expect(find.text('Match day squads'), findsOneWidget);
    expect(find.text('Publish'), findsOneWidget);
    expect(find.text('PLAYERS'), findsOneWidget);
    expect(find.text('COACHES'), findsOneWidget);
    expect(find.text('Aimee Morris'), findsOneWidget);
    expect(find.text('Tom Kelly'), findsNothing); // declined, other tab
    // Squad cards: Blue, Red, none selected, everyone listed.
    expect(find.text('All'), findsNothing);
    expect(find.text('Blue'), findsWidgets);
    expect(find.textContaining('Players: 2'), findsOneWidget);
    expect(find.text('Anna Ryan'), findsOneWidget);
    // Tap Blue to filter, tap again to show everyone.
    await tester.tap(find.text('Blue').first);
    await tester.pumpAndSettle();
    expect(find.text('Anna Ryan'), findsNothing);
    await tester.tap(find.text('Blue').first);
    await tester.pumpAndSettle();
    expect(find.text('Anna Ryan'), findsOneWidget);
    // Switch to Declined.
    await tester.tap(find.text('Declined'));
    await tester.pumpAndSettle();
    expect(find.text('Tom Kelly'), findsOneWidget);
    expect(find.text('Aimee Morris'), findsNothing);
  });
}
