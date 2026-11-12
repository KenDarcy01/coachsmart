// "Send reminder" confirm sheet: labels, and the sheet lays out on a phone
// with names open.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:coach_smart_v2/v3/event/v3_reminder_sheet.dart';

Map<String, dynamic> body({int people = 13, String? lastAt}) => {
      'people': people,
      'push': 4,
      'email': people - 4,
      'not_replied': people == 0 ? 0 : 15,
      'players': people == 0 ? 0 : 11,
      'flos': people == 0 ? 0 : 1,
      'coaches': people == 0 ? 0 : 3,
      'names': people == 0
          ? []
          : [
              {'name': 'Aoife Byrne', 'roles': 'Player'},
              {'name': 'Ken Darcy', 'roles': 'Coach'},
            ],
      'times_sent': lastAt == null ? 0 : 2,
      'last_at': lastAt,
      'last_by': lastAt == null ? null : 'Ken',
      'last_people': lastAt == null ? null : 14,
    };

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  test('parses and labels', () {
    final now = DateTime(2026, 11, 12, 9, 0);
    final p = ReminderPreview.fromJson([
      body(lastAt: DateTime(2026, 11, 11, 19, 2).toUtc().toIso8601String())
    ]);
    expect(p.people, 13);
    expect(p.names.length, 2);
    expect(reminderMenuLine(p, now),
        'Last sent yesterday 19:02 by Ken · 14 people');
    expect(reminderLastTitle(p, now), 'Last sent yesterday at 19:02');
    expect(reminderLastDetail(p),
        'By Ken, to 14 people. Sent twice for this event.');
    expect(
        reminderNote(p),
        "15 haven't replied. A parent with two children, or a coach who is "
        'also a parent, gets one message. 4 by push, 9 by email.');
    expect(reminderMenuLine(ReminderPreview.fromJson(body()), now),
        'Not sent yet');
    expect(reminderMenuLine(null, now), "Push to everyone who hasn't replied");
    expect(reminderWhen(DateTime(2026, 11, 12, 8, 5), now), 'today 08:05');
    expect(reminderWhen(DateTime(2026, 11, 9, 20, 15), now), 'Mon 9 Nov 20:15');
    expect(ReminderPreview.fromJson(null).people, 0);
  });

  Future<bool?> open(WidgetTester tester, ReminderPreview p) async {
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    bool? result;
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: Builder(
                builder: (c) => TextButton(
                    onPressed: () async =>
                        result = await showReminderSheet(c, 1, preview: p),
                    child: const Text('open'))))));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    return result;
  }

  testWidgets('confirm sheet shows counts, names and sends', (tester) async {
    final p = ReminderPreview.fromJson(body(lastAt: '2026-11-11T19:02:00Z'));
    await open(tester, p);
    expect(tester.takeException(), isNull);
    expect(find.text('13'), findsOneWidget);
    expect(find.text('Players'), findsOneWidget);
    expect(find.text('FLO'), findsOneWidget);
    expect(find.text('Coaches'), findsOneWidget);
    await tester.tap(find.text('See who ›'));
    await tester.pumpAndSettle();
    expect(find.text('Aoife Byrne'), findsOneWidget);
    expect(tester.takeException(), isNull);
    expect(find.text('Send to 13'), findsOneWidget);
    await tester.tap(find.text('Send to 13'));
    await tester.pumpAndSettle();
    expect(find.text('Send to 13'), findsNothing);
  });

  testWidgets('nobody to remind shows Close only', (tester) async {
    await open(tester, ReminderPreview.fromJson(body(people: 0)));
    expect(find.text("Everyone has replied, so there's nobody to remind."),
        findsOneWidget);
    expect(find.text('Close'), findsOneWidget);
    expect(find.textContaining('Send to'), findsNothing);
  });
}
