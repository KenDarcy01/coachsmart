// "Tell the team" sheet on create/edit/cancel/delete: off by default, the
// button only names the action, switch on shows counts and the message.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:coach_smart_v2/v3/event/v3_event_notify_sheet.dart';

NotifyPreview preview({bool past = false, int people = 27}) =>
    NotifyPreview.fromJson({
      'people': people,
      'push': 7,
      'email': people - 7,
      'members': 31,
      'players': 26,
      'flos': 1,
      'coaches': 3,
      'admins': 1,
      'going': 14,
      'cant_go': 3,
      'not_replied': 14,
      'is_past': past,
    });

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  test('messages', () {
    final t = DateTime(2026, 11, 13, 18, 30);
    expect(notifyWhen(t), 'Fri 13 Nov, 18:30');
    expect(notifyMessage(EventAction.cancel, 'U14 Training', notifyWhen(t)),
        'Cancelled: U14 Training, Fri 13 Nov, 18:30.');
    expect(
        notifyMessage(EventAction.cancel, 'U14 Training', notifyWhen(t),
            events: 3, note: 'Pitch closed'),
        'Cancelled: U14 Training, Fri 13 Nov, 18:30 and the 2 after it. Pitch closed');
    expect(
        notifyMessage(EventAction.create, 'U14 Training', notifyWhen(t),
            events: 6),
        'U14 Training: 6 events from Fri 13 Nov, 18:30.');
    expect(editNote({'event_date_time': 'x', 'location_name': 'y'}, t, 'Park'),
        'New time: Fri 13 Nov, 18:30. New venue: Park.');
    expect(tellLine(preview(), false), 'Off. Turn on to tell 27 people.');
    expect(tellLine(preview(), true), '27 people, covering 31 team members');
    expect(tellLine(preview(people: 0), false), 'Nobody else to tell.');
  });

  Future<EventActionChoice?> Function() open(
      WidgetTester tester, EventAction a, NotifyPreview p,
      {int later = 0}) {
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    EventActionChoice? got;
    var done = false;
    return () async {
      await tester.pumpWidget(MaterialApp(
          home: Scaffold(
              body: Builder(
                  builder: (c) => TextButton(
                      onPressed: () async {
                        got = await showEventActionSheet(c,
                            action: a,
                            title: 'U14 Football Training',
                            when: 'Fri 13 Nov, 18:30',
                            venue: "St Anne's Park",
                            later: later,
                            load: () async => p);
                        done = true;
                      },
                      child: const Text('open'))))));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      return done ? got : null;
    };
  }

  testWidgets('cancel: off by default, on shows counts, returns choice',
      (tester) async {
    EventActionChoice? got;
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: Builder(
                builder: (c) => TextButton(
                    onPressed: () async => got = await showEventActionSheet(c,
                        action: EventAction.cancel,
                        title: 'U14 Football Training',
                        when: 'Fri 13 Nov, 18:30',
                        later: 5,
                        load: () async => preview()),
                    child: const Text('open'))))));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Cancel event'), findsOneWidget);
    expect(find.text('Players'), findsNothing);
    expect(find.text('Off. Turn on to tell 27 people.'), findsOneWidget);
    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    expect(find.text('Players'), findsOneWidget);
    expect(find.text('Admin'), findsOneWidget);
    await tester.tap(find.text('This and 4 later'));
    await tester.pumpAndSettle();
    expect(find.text('Cancel 5 events'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'Pitch closed');
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.ensureVisible(find.text('Cancel 5 events'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel 5 events'));
    await tester.pumpAndSettle();
    expect(got?.tell, isTrue);
    expect(got?.scope, 'following');
    expect(got?.note, 'Pitch closed');
  });

  testWidgets('create without telling anyone', (tester) async {
    final run = open(tester, EventAction.create, preview());
    await run();
    expect(find.text('Create event'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
  });

  testWidgets('delete of a past event shows it is over', (tester) async {
    final run = open(tester, EventAction.delete, preview(past: true));
    await run();
    expect(find.text('This event is over. 14 went.'), findsOneWidget);
    expect(find.text('Delete'), findsOneWidget);
  });
}
