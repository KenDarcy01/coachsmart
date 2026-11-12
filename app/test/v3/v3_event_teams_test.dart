import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:coach_smart_v2/v3/event/v3_event_teams.dart';

Map<String, dynamic> teams({bool shared = true}) => {
      'shared': shared,
      'shared_at': '2026-11-15T19:05:00Z',
      'is_admin': false,
      'published': true,
      'families_told': 38,
      'mine': [
        {
          'member_id': 1,
          'first_name': 'Cian',
          'squad_id': 12,
          'squad_name': 'Red Team',
          'squad_colour': '#e5484d',
          'squad_image': ''
        },
        {
          'member_id': 2,
          'first_name': 'Saoirse',
          'squad_id': null,
          'squad_name': null,
          'squad_colour': null,
          'squad_image': null
        },
      ],
      'squads': [
        {
          'squad_id': 11,
          'squad_name': 'Blue Team',
          'squad_colour': '#3b82f6',
          'squad_image': '',
          'members': [
            {'member_id': 3, 'name': 'Aoife Byrne', 'mine': false},
          ]
        },
        {
          'squad_id': 12,
          'squad_name': 'Red Team',
          'squad_colour': '#e5484d',
          'squad_image': '',
          'members': [
            {'member_id': 1, 'name': 'Cian Kelly', 'mine': true},
            {'member_id': 4, 'name': 'Tom Walsh', 'mine': false},
          ]
        },
      ],
    };

void main() {
  test('parses the teams and hides them until shared', () {
    final t = EventTeams.fromJson(teams());
    expect(t.visible, isTrue);
    expect(t.mine.first.onTeam, isTrue);
    expect(t.mine.last.onTeam, isFalse);
    expect(t.squads.last.players.first.mine, isTrue);
    expect(EventTeams.fromJson(teams(shared: false)).visible, isFalse);
    expect(EventTeams.fromJson({'error': 'x'}).visible, isFalse);
  });

  test('labels', () {
    expect(shareResultMessage(0), 'Teams shared. Nobody new to tell.');
    expect(shareResultMessage(1), 'Teams shared. 1 family told.');
    expect(shareResultMessage(38), 'Teams shared. 38 families told.');
    final at = DateTime(2026, 11, 15, 19, 5);
    expect(sharedLabel(at, 38), 'Shared Sun 15 Nov, 19:05 · 38 families told');
    expect(sharedLabel(at, 0), 'Shared Sun 15 Nov, 19:05');
    expect(squadColour('#e5484d'), const Color(0xFFE5484D));
  });

  testWidgets('parent card shows own team, then every team', (tester) async {
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: V3EventTeamsCard(eventId: 1, testData: teams()))));
    await tester.pumpAndSettle();
    expect(find.text('YOUR TEAM'), findsOneWidget);
    expect(find.text('Cian'), findsOneWidget);
    expect(find.text('Red Team'), findsOneWidget);
    expect(find.text('Not on a team yet'), findsOneWidget);
    await tester.tap(find.text('See all teams'));
    await tester.pumpAndSettle();
    // Opens on the family's own team.
    expect(find.text('Cian Kelly'), findsOneWidget);
    expect(find.text('Aoife Byrne'), findsNothing);
    await tester.tap(find.text('Blue Team 1'));
    await tester.pumpAndSettle();
    expect(find.text('Aoife Byrne'), findsOneWidget);
  });

  testWidgets('parent card is empty until shared', (tester) async {
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body:
                V3EventTeamsCard(eventId: 1, testData: teams(shared: false)))));
    await tester.pumpAndSettle();
    expect(find.text('YOUR TEAM'), findsNothing);
    expect(find.text('See all teams'), findsNothing);
  });

  testWidgets('admin switch shows its state', (tester) async {
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: V3ShareTeamsSwitch(
                eventId: 1, testData: teams(shared: false)))));
    await tester.pumpAndSettle();
    expect(find.text('Show teams to parents'), findsOneWidget);
    expect(find.text('Off: only admins can see the teams'), findsOneWidget);
    expect(tester.widget<Switch>(find.byType(Switch)).value, isFalse);
  });
}
