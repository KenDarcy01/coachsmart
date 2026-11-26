import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:coach_smart_v2/v3/messages/v3_message_widgets.dart';
import 'package:coach_smart_v2/v3/messages/v3_messages_models.dart';
import 'package:coach_smart_v2/v3/messages/v3_messages_page.dart';

Map<String, dynamic> sample() => {
      'is_super_user': true,
      'important': [
        {
          'id': 1,
          'kind': 'important',
          'title': 'All pitches closed this weekend',
          'body': 'Weather warning.',
          'from_name': 'CoachSmart',
          'scope': 'all',
          'starts_at': '2026-11-14T14:05:00Z',
        },
        {
          'id': 2,
          'kind': 'important',
          'title': 'AGM moved',
          'from_name': 'Clontarf GAA',
          'scope': 'club',
          'club_id': 1,
          'link_url': 'https://example.com',
          'link_label': 'Read the full notice',
        },
      ],
      'news': [
        {'id': 3, 'kind': 'news', 'title': 'Jerseys are in', 'seen': false},
        {'id': 4, 'kind': 'news', 'title': 'Blitz sign-up', 'seen': true},
      ],
    };

class FakeApi extends MessagesApi {
  FakeApi();
  final calls = <String>[];

  @override
  Future<MyMessages> mine() async => MyMessages.fromJson(sample());

  @override
  Future<void> dismiss(int id) async => calls.add('dismiss $id');

  @override
  Future<void> markSeen(List<int> ids) async => calls.add('seen $ids');

  @override
  Future<List<TargetClub>> targets() async => [
        TargetClub.fromJson({
          'club_id': 1,
          'club_name': 'Clontarf GAA',
          'teams': [
            {'team_id': 84, 'team_name': 'Test Team'}
          ]
        })
      ];

  @override
  Future<int> count(int? clubId, List<int> teamIds, MessageAudience a) async =>
      teamIds.isEmpty ? 673 : 2;

  @override
  Future<List<AppMessage>> sent() async => [
        AppMessage.fromJson({
          'id': 9,
          'kind': 'news',
          'title': 'Live one',
          'scope': 'team',
          'team_names': ['Test Team'],
          'starts_at': '2026-01-01T00:00:00Z',
          'ends_at': '2099-01-01T00:00:00Z',
          'reach': 40,
          'seen_count': 10,
          'dismissed_count': 0,
        }),
      ];

  @override
  Future<int> save({
    int? id,
    required MessageKind kind,
    required String title,
    required String body,
    String linkUrl = '',
    String linkLabel = '',
    int? clubId,
    List<int> teamIds = const [],
    MessageAudience audience = MessageAudience.all,
    required DateTime startsAt,
    required DateTime endsAt,
  }) async {
    calls.add(
        'save ${kind.name} $title $clubId $teamIds ${audience.name} $linkUrl');
    return 1;
  }
}

Widget wrap(Widget w) => MaterialApp(home: w);

void main() {
  test('parses my messages', () {
    final m = MyMessages.fromJson(sample());
    expect(m.isSuperUser, isTrue);
    expect(m.important.map((e) => e.id), [1, 2]);
    expect(m.important[1].scope, 'club');
    expect(m.unreadNews, 1);
    expect(normaliseLink('coachsmart.app'), 'https://coachsmart.app');
    expect(normaliseLink(''), '');
  });

  test('sent message status', () {
    final now = DateTime(2026, 11, 14, 12);
    AppMessage m(String s, String e, {String? ended}) => AppMessage.fromJson({
          'id': 1,
          'kind': 'news',
          'title': 't',
          'starts_at': s,
          'ends_at': e,
          'ended_at': ended
        });
    expect(m('2026-11-01', '2026-12-01').status(now), 'live');
    expect(m('2026-11-20', '2026-12-01').status(now), 'scheduled');
    expect(m('2026-11-01', '2026-11-10').status(now), 'ended');
    expect(m('2026-11-01', '2026-12-01', ended: '2026-11-13').status(now),
        'ended');
  });

  testWidgets('pop-up shows each message and dismisses it', (t) async {
    final api = FakeApi();
    final msgs = MyMessages.fromJson(sample()).important;
    await t.pumpWidget(wrap(Builder(
        builder: (ctx) => Scaffold(
            body: TextButton(
                onPressed: () => showImportantMessages(ctx, msgs, api),
                child: const Text('open'))))));
    await t.tap(find.text('open'));
    await t.pumpAndSettle();
    expect(find.text('All pitches closed this weekend'), findsOneWidget);
    expect(find.text('1 of 2 messages'), findsOneWidget);
    await t.tap(find.byTooltip('Close'));
    await t.pumpAndSettle();
    expect(find.text('AGM moved'), findsOneWidget);
    expect(find.text('Read the full notice'), findsOneWidget);
    await t.tap(find.text('Got it'));
    await t.pumpAndSettle();
    expect(find.text('AGM moved'), findsNothing);
    expect(api.calls, ['dismiss 1', 'dismiss 2']);
  });

  testWidgets('news cards show every item and the sheet marks unread as seen',
      (t) async {
    final api = FakeApi();
    final news = MyMessages.fromJson(sample()).news;
    await t.pumpWidget(wrap(Builder(
        builder: (ctx) => Scaffold(
            body: V3NewsCards(
                news: news, onTap: () => showNewsSheet(ctx, news, api))))));
    // CoachSmart-wide items: the heading says News, not Club news.
    expect(find.text('News'), findsOneWidget);
    expect(find.text('Jerseys are in'), findsOneWidget);
    expect(find.text('See all ${news.length}'), findsOneWidget);
    await t.tap(find.text('Jerseys are in'));
    await t.pumpAndSettle();
    expect(find.text('News'), findsNWidgets(2));
    await t.tapAt(const Offset(10, 10));
    await t.pumpAndSettle();
    expect(api.calls, ['seen [3]']);
    expect(news.every((n) => n.seen), isTrue);
  });

  testWidgets('no news, no cards', (t) async {
    await t.pumpWidget(
        wrap(Scaffold(body: V3NewsCards(news: const [], onTap: () {}))));
    expect(find.byType(InkWell), findsNothing);
  });

  testWidgets('messages page lists sent messages', (t) async {
    await t.pumpWidget(wrap(V3MessagesPage(api: FakeApi())));
    await t.pumpAndSettle();
    expect(find.text('LIVE NOW'), findsOneWidget);
    expect(find.text('Live one'), findsOneWidget);
    expect(find.text('Seen by 10 of 40'), findsOneWidget);
  });

  testWidgets('compose to a team and send', (t) async {
    t.view.physicalSize = const Size(1170, 2532);
    t.view.devicePixelRatio = 3;
    addTearDown(t.view.reset);
    final api = FakeApi();
    await t.pumpWidget(wrap(V3MessageFormPage(api: api)));
    await t.pumpAndSettle();
    await t.enterText(find.widgetWithText(TextField, 'Title'), 'Hello');
    await t.scrollUntilVisible(find.text('Send to 673 people'), 300,
        scrollable: find.byType(Scrollable).first);
    await t.scrollUntilVisible(find.text('Everyone on CoachSmart'), -300,
        scrollable: find.byType(Scrollable).first);
    await t.tap(find.text('Everyone on CoachSmart'));
    await t.pumpAndSettle();
    await t.tap(find.text('Clontarf GAA'));
    await t.pumpAndSettle();
    await t.tap(find.text('Test Team'));
    await t.tap(find.text('Done'));
    await t.pumpAndSettle();
    await t.scrollUntilVisible(find.text('Send to 2 people'), 300,
        scrollable: find.byType(Scrollable).first);
    await t.tap(find.text('Send to 2 people'));
    await t.pumpAndSettle();
    expect(find.text('Pop this up for 2 people?'), findsOneWidget);
    await t.tap(find.text('Send now'));
    await t.pumpAndSettle();
    expect(api.calls, ['save important Hello 1 [84] all ']);
  });
}
