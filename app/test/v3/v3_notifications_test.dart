import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:coach_smart_v2/v3/notifications/v3_notifications_models.dart';
import 'package:coach_smart_v2/v3/notifications/v3_notifications_page.dart';

String stamp(DateTime t) {
  const d = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  const m = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec'
  ];
  final u = t.toUtc();
  final h12 = u.hour % 12 == 0 ? 12 : u.hour % 12;
  final ap = u.hour < 12 ? 'AM' : 'PM';
  return '${d[u.weekday - 1]}, ${u.day.toString().padLeft(2, '0')} ${m[u.month - 1]} ${u.year} at ${h12.toString().padLeft(2, '0')}:${u.minute.toString().padLeft(2, '0')} $ap';
}

Map<String, dynamic> row(int id, DateTime at,
        {String action = '', int eventId = 0, bool read = false}) =>
    {
      'id': id,
      'created_at': stamp(at),
      'time_label': '7m ago',
      'app_title': 'Title $id',
      'app_body': 'Body $id',
      'is_read': read,
      'team_id': 5,
      'team_name': 'Clontarf Boys 2017',
      'event_id': eventId == 0 ? null : eventId,
      'member_id': null,
      'action': action.isEmpty ? null : action,
      'action_ref_id': action.isEmpty ? null : 99,
    };

void main() {
  test('created_at text parses and groups by calendar day', () {
    final now = DateTime(2026, 11, 9, 18, 0);
    expect(parseNotifTime('Mon, 09 Nov 2026 at 05:30 PM')!.toUtc(),
        DateTime.utc(2026, 11, 9, 17, 30));
    expect(dayGroup(now.subtract(const Duration(hours: 1)), now), 'Today');
    expect(dayGroup(DateTime(2026, 11, 8, 23, 59), now), 'Yesterday');
    expect(dayGroup(DateTime(2026, 11, 7, 23, 59), now), 'Earlier');
    expect(dayGroup(null, now), 'Earlier');
  });

  test('groups keep order and drop empty ones', () {
    final now = DateTime.now();
    final items = [
      NotifItem.fromJson(row(1, now)),
      NotifItem.fromJson(row(2, now.subtract(const Duration(days: 3)))),
    ];
    final g = groupNotifs(items, now);
    expect(g.map((x) => x.$1), ['Today', 'Earlier']);
  });

  test('kinds: requests and reminders need an action, notices do not', () {
    final n1 =
        NotifItem.fromJson(row(1, DateTime.now(), action: 'approve_member'));
    final n2 = NotifItem.fromJson(
        row(2, DateTime.now(), action: 'attend', eventId: 7));
    final n3 = NotifItem.fromJson(row(3, DateTime.now(), eventId: 7));
    expect(n1.isJoinRequest, isTrue);
    expect(n1.needsAction, isTrue);
    expect(n2.isAttend, isTrue);
    expect(n2.needsAction, isTrue);
    expect(n3.needsAction, isFalse);
    expect(n3.asRead().isRead, isTrue);
  });

  testWidgets(
      'notices go read after 2 seconds, requests and reminders stay unread '
      'with their buttons, and nothing opens another page', (tester) async {
    final now = DateTime.now();
    await tester.pumpWidget(MaterialApp(
        home: V3NotificationsPage(testData: [
      row(1, now, action: 'approve_member'),
      row(2, now, eventId: 7),
      row(3, now, action: 'attend', eventId: 8),
      row(4, now.subtract(const Duration(days: 1)), read: true),
    ], testMembers: {
      8: [NotifMember(11, 'Sean', 0), NotifMember(12, 'Aoife', 0)],
    })));
    await tester.pump();
    expect(find.text('TODAY'), findsOneWidget);
    expect(find.text('YESTERDAY'), findsOneWidget);
    expect(find.text('Mark all read'), findsNothing);
    expect(find.text('Approve'), findsOneWidget);
    expect(find.text('Decline'), findsOneWidget);
    expect(find.text('Sean'), findsNWidgets(2));
    expect(find.text('Aoife'), findsNWidgets(2));
    expect(find.byIcon(Icons.chevron_right), findsNothing);

    Iterable<Color?> dots() => tester
        .widgetList<Container>(find.byType(Container))
        .map((c) => c.decoration)
        .whereType<BoxDecoration>()
        .where((d) => d.shape == BoxShape.circle)
        .map((d) => d.color);
    expect(dots().where((c) => c != Colors.transparent).length, 3);

    await tester.pump(const Duration(seconds: 2));
    await tester.pump();
    // The notice is read; the request and the reminder stay unread.
    expect(dots().where((c) => c != Colors.transparent).length, 2);

    // Replying lights the chosen button.
    await tester.tap(find.text('Sean').first);
    await tester.pumpAndSettle();
    expect(find.text('Sean'), findsNWidgets(2));
  });
}
