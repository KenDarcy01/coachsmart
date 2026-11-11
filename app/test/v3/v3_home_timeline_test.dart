import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:coach_smart_v2/backend/schema/structs/index.dart';
import 'package:coach_smart_v2/v3/home/v3_home_data.dart';
import 'package:coach_smart_v2/v3/home/v3_team_chip.dart';
import 'package:coach_smart_v2/v3/home/v3_timeline_row.dart';

final now = DateTime(2026, 11, 11, 15, 0);

EventsStruct ev(
  int id,
  DateTime t, {
  String status = 'active',
  int response = 0,
  bool ask = true,
  bool paid = false,
  int roleLevel = 10,
  int accepted = 14,
  int noReply = 3,
  int declined = 2,
  String squad = '',
}) =>
    EventsStruct.fromMap({
      'event_id': id,
      'event_date_time': '${t.toIso8601String()}+00:00',
      'event_date_time_formatted': '',
      'meet_time': '17:30',
      'event_title': 'Football Training',
      'team_name': 'Boys 2013',
      'team_id': 7,
      'club_id': 1,
      'squad_name': squad,
      'squad_id': squad.isEmpty ? 0 : 5,
      'location_name': 'Club Astro',
      'response_id': response,
      'request_attendance': ask,
      'event_status': status,
      'payment_required': paid,
      'event_paid': paid,
      'member_role_level': roleLevel,
      'user_highest_role_on_team': roleLevel,
      'accepted_count': accepted,
      'no_response_count': noReply,
      'declined_count': declined,
    });

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  group('eventLocalTime', () {
    test('takes the UTC-labelled wall clock as-is', () {
      final e = ev(1, DateTime(2026, 11, 12, 17, 50));
      expect(eventLocalTime(e), DateTime(2026, 11, 12, 17, 50));
    });

    test('falls back to the formatted text for an older RPC', () {
      final e = EventsStruct.fromMap({
        'event_id': 2,
        'event_date_time_formatted': 'Thursday, 12 November, 2026 at 19:00',
      });
      expect(eventLocalTime(e), DateTime(2026, 11, 12, 19, 0));
    });
  });

  group('countdown', () {
    test('formats', () {
      expect(
        countdown(now.add(const Duration(hours: 2, minutes: 30)), now),
        'in 2h 30m',
      );
      expect(countdown(now.add(const Duration(hours: 3)), now), 'in 3h');
      expect(countdown(now.add(const Duration(minutes: 40)), now), 'in 40m');
      expect(countdown(now.add(const Duration(hours: 30)), now), 'in 2 days');
      expect(countdown(now.add(const Duration(hours: 24)), now), 'in 1 day');
      expect(countdown(now.subtract(const Duration(minutes: 5)), now), '');
    });
  });

  group('buildTimeline', () {
    test('one day marker per day, one next, skipping cancelled', () {
      final items = buildTimeline([
        ev(3, DateTime(2026, 11, 12, 19, 0)),
        ev(1, DateTime(2026, 11, 11, 17, 50), status: 'cancelled'),
        ev(2, DateTime(2026, 11, 11, 19, 30)),
        ev(4, DateTime(2026, 11, 14, 10, 0)),
      ], now);
      expect(items.where((i) => i.quiet), isEmpty);
      expect(items.map((i) => i.event!.eventId), [1, 2, 3, 4]);
      expect(items.map((i) => i.showDay), [true, false, true, true]);
      expect(items.where((i) => i.isNext).map((i) => i.event!.eventId), [2]);
      expect(nextDay(items), DateTime(2026, 11, 11));
    });

    test('quiet-day row for today when today has nothing on', () {
      final items = buildTimeline([ev(3, DateTime(2026, 11, 12, 19, 0))], now);
      expect(items.first.quiet, isTrue);
      expect(items.first.day, DateTime(2026, 11, 11));
      expect(items.length, 2);
      expect(items[1].isNext, isTrue);
    });

    test('nothing upcoming: quiet marker only', () {
      final items = buildTimeline([], now);
      expect(items.length, 1);
      expect(items.single.quiet, isTrue);
      expect(nextDay(items), isNull);
    });
  });

  Widget host(Widget child) => MaterialApp(
        home: Scaffold(body: ListView(children: [child])),
      );

  Widget row(
    EventsStruct e, {
    bool isNext = true,
    bool isCoach = false,
    void Function(int)? onReply,
  }) {
    final t = eventLocalTime(e)!;
    return V3TimelineRow(
      item: TimelineItem.event(e, t, showDay: true, isNext: isNext),
      now: now,
      isCoach: isCoach,
      busy: false,
      firstRow: true,
      nextDayGreen: isNext,
      crestUrl: '',
      clubName: 'Clontarf GAA',
      onTap: () {},
      onReply: onReply ?? (_) {},
    );
  }

  testWidgets('unreplied event shows the tick/cross pair and countdown', (
    tester,
  ) async {
    var replied = 0;
    final e = ev(1, now.add(const Duration(hours: 2, minutes: 50)));
    await tester.pumpWidget(host(row(e, onReply: (r) => replied = r)));
    expect(find.text('in 2h 50m'), findsOneWidget);
    expect(find.text('Meet 17:30'), findsOneWidget);
    expect(find.text('BOYS 2013'), findsOneWidget);
    expect(find.text('14'), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
    expect(find.bySemanticsLabel('Attending'), findsOneWidget);
    expect(find.bySemanticsLabel('Declined'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.check_rounded));
    expect(replied, 3);
  });

  testWidgets('replied event shows the one-word status', (tester) async {
    final e = ev(1, now.add(const Duration(hours: 2)), response: 3);
    await tester.pumpWidget(host(row(e)));
    expect(find.byIcon(Icons.check_rounded), findsOneWidget);
    expect(find.byIcon(Icons.close_rounded), findsNothing);
  });

  testWidgets('cancelled: tag, no ring, no reply control', (tester) async {
    final e = ev(1, now.add(const Duration(hours: 2)), status: 'cancelled');
    await tester.pumpWidget(host(row(e, isNext: false)));
    expect(find.text('CANCELLED'), findsOneWidget);
    expect(find.byIcon(Icons.check_rounded), findsNothing);
    expect(find.text('14'), findsNothing);
  });

  testWidgets('paid tag and squad on line 3', (tester) async {
    final e = ev(
      1,
      now.add(const Duration(hours: 2)),
      paid: true,
      squad: 'Blue',
    );
    await tester.pumpWidget(host(row(e)));
    expect(find.text('PAID'), findsOneWidget);
    expect(find.text('BOYS 2013'), findsOneWidget);
    expect(find.text('Blue'), findsOneWidget);
  });

  testWidgets('coach footer is three numbers; admins get no reply pair', (
    tester,
  ) async {
    final e = ev(1, now.add(const Duration(hours: 2)), roleLevel: 100);
    await tester.pumpWidget(host(row(e, isCoach: true)));
    expect(find.text('14'), findsOneWidget);
    expect(find.byIcon(Icons.question_mark_rounded), findsNothing);
    expect(find.byIcon(Icons.check_rounded), findsNothing);
  });

  testWidgets('quiet day row', (tester) async {
    await tester.pumpWidget(
      host(V3QuietDayRow(day: DateTime(2026, 11, 11), firstRow: true)),
    );
    expect(find.text('Nothing on today'), findsOneWidget);
    expect(find.text('11'), findsOneWidget);
    expect(find.text('WED'), findsOneWidget);
  });

  testWidgets('team chip', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      host(
        Row(
          children: [
            V3TeamChip(label: 'All', selected: true, onTap: () {}),
            V3TeamChip(
              label: 'Boys 2013',
              selected: false,
              crestUrl: '',
              clubName: 'Clontarf GAA',
              onTap: () => taps++,
            ),
          ],
        ),
      ),
    );
    expect(find.text('All'), findsOneWidget);
    await tester.tap(find.text('Boys 2013'));
    expect(taps, 1);
  });
}
