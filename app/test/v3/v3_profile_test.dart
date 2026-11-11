import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:coach_smart_v2/v3/profile/v3_profile_models.dart';
import 'package:coach_smart_v2/v3/profile/v3_profile_page.dart';

Map<String, dynamic> sample() => {
      'user': {
        'user_id': 'u1',
        'email_address': 'ken@example.com',
        'first_name': 'Ken',
        'last_name': 'Darcy',
        'phone_number': null,
        'default_club': 1,
      },
      'clubs': [
        {'club_id': 1, 'club_name': 'Clontarf GAA'},
        {'club_id': 2, 'club_name': "St Anne's"},
      ],
      'userMembers': [
        {
          'member_id': 10,
          'member_team_id': 100,
          'first_name': 'Aoife',
          'last_name': 'Darcy',
          'full_name': 'Aoife Darcy',
          'unique_member_code': 'AD4K2P7',
          'team_id': 5,
          'team_name': 'Girls 2014',
          'club_id': 1,
          'club_name': 'Clontarf GAA'
        },
        {
          'member_id': 11,
          'member_team_id': 101,
          'first_name': 'Ken',
          'last_name': 'Darcy',
          'full_name': 'Ken Darcy',
          'unique_member_code': 'KD9Q1Z2',
          'team_id': 6,
          'team_name': 'Boys 2017',
          'club_id': 1,
          'club_name': 'Clontarf GAA'
        },
      ],
      'roles': [
        {
          'member_team_id': 100,
          'roles': {'role_name': 'Player', 'role_level': 10}
        },
        {
          'member_team_id': 101,
          'roles': {'role_name': 'Coach', 'role_level': 30}
        },
        {
          'member_team_id': 101,
          'roles': {'role_name': 'Admin', 'role_level': 100}
        },
      ],
    };

void main() {
  test('profile data parses and roles attach to members', () {
    final d = ProfileData.fromJson(sample());
    d.applyRoles(sample()['roles'] as List);
    expect(d.email, 'ken@example.com');
    expect(d.clubs.length, 2);
    expect(d.members[0].subtitle, 'Girls 2014 · Player');
    expect(d.members[0].canOpenMemberPage, isFalse);
    expect(d.members[1].subtitle, 'Boys 2017 · Coach, Admin');
    expect(d.members[1].roleLevel, 100);
    expect(d.members[1].canOpenMemberPage, isTrue);
    expect(initialsFor('Ken', 'Darcy'), 'KD');
    expect(initialsFor('', ''), '?');
  });

  testWidgets('profile page shows details, members, account and about',
      (tester) async {
    tester.view.physicalSize = const Size(390 * 3, 1400 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester
        .pumpWidget(MaterialApp(home: V3ProfilePage(testData: sample())));
    await tester.pumpAndSettle();
    expect(find.text('Ken Darcy'), findsNWidgets(2)); // hero + member row
    expect(find.text('ken@example.com'), findsOneWidget);
    expect(find.text('Clontarf GAA'), findsOneWidget);
    expect(find.text('Aoife Darcy'), findsOneWidget);
    expect(find.text('Change password'), findsOneWidget);
    expect(find.text('Notification settings'), findsOneWidget);
    expect(find.text('Delete account'), findsOneWidget);
    // Save is disabled until something changes.
    final save = find.widgetWithText(TextButton, 'Save');
    expect(tester.widget<TextButton>(save).onPressed, isNull);
    await tester.enterText(
        find.widgetWithText(TextField, 'First name'), 'Kenneth');
    await tester.pump();
    expect(tester.widget<TextButton>(save).onPressed, isNotNull);
  });
}
