import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:coach_smart_v2/v3/profile/v3_notification_settings_page.dart';

const teams = [
  AdminAlertPref(5, 'Girls 2014', 'Clontarf GAA', 'event'),
  AdminAlertPref(6, 'Boys 2013', 'Clontarf GAA', 'off'),
];

Future<void> pump(WidgetTester t,
    {bool web = false, List<AdminAlertPref> list = teams}) async {
  await t.binding.setSurfaceSize(const Size(390, 1200));
  await t.pumpWidget(MaterialApp(
      home: V3NotificationSettingsPage(
          testTeams: list, testIsWeb: web, testPush: true)));
  await t.pumpAndSettle();
}

void main() {
  test('rows parse with a default choice', () {
    final l = AdminAlertPref.listFrom([
      {
        'team_id': 1,
        'team_name': 'A',
        'club_name': 'C',
        'attendance_alerts': null
      }
    ]);
    expect(l.single.choice, 'event');
    expect(alertChoiceLabel('changes'), 'Only changes of mind');
  });

  testWidgets('phone: push/email choice and team alerts', (t) async {
    await pump(t);
    expect(find.text('Push'), findsOneWidget);
    expect(find.text('Email'), findsOneWidget);
    expect(find.text('Girls 2014'), findsOneWidget);
    expect(find.text('As set on each event'), findsOneWidget);
    expect(find.text('Off'), findsOneWidget);
    await t.tap(find.text('Girls 2014'));
    await t.pumpAndSettle();
    await t.tap(find.text('Only changes of mind').last);
    await t.pumpAndSettle();
    expect(find.text('Only changes of mind'), findsOneWidget);
  });

  testWidgets('web: no push option', (t) async {
    await pump(t, web: true);
    expect(find.text('Push'), findsNothing);
    expect(find.textContaining('come by email'), findsOneWidget);
  });

  testWidgets('non-admins see no attendance section', (t) async {
    await pump(t, list: const []);
    expect(find.text('ATTENDANCE ALERTS'), findsNothing);
  });
}
