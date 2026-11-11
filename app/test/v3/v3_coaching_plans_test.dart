import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:coach_smart_v2/v3/coaching/v3_event_plan_entry.dart';
import 'package:coach_smart_v2/v3/coaching/v3_plan_api.dart';
import 'package:coach_smart_v2/v3/coaching/v3_plan_builder_page.dart';
import 'package:coach_smart_v2/v3/coaching/v3_plan_draft.dart';
import 'package:coach_smart_v2/v3/coaching/v3_plan_models.dart';
import 'package:coach_smart_v2/v3/coaching/v3_plans_view.dart';
import 'package:coach_smart_v2/v3/games/v3_games.dart';
import 'package:coach_smart_v2/v3/match_report/v3_voice_sheet.dart';
import 'package:coach_smart_v2/v3/session_plan/v3_session_plan_api.dart';
import 'package:coach_smart_v2/v3/session_plan/v3_session_plan_models.dart';
import 'package:coach_smart_v2/v3/session_plan/v3_session_plan_page.dart';

const zombie = V3Game(
  gameId: 1,
  name: 'Zombie Chief',
  types: ['Warmup'],
  setup: 'A 20m square.',
  howToPlay: 'Zombies chase the runners.',
  teachingPoints: '• Heads up\n• Change direction quickly\n- ok',
  variations: 'Add a second zombie',
  image: 'https://example.com/zombie.png',
  video: 'https://youtu.be/abcdefghijk',
);
const castle = V3Game(
  gameId: 2,
  name: 'Knock The Castle',
  types: ['Game'],
  howToPlay: 'Knock the cones over.',
);

String iso(DateTime d) => d.toUtc().toIso8601String();

Map<String, dynamic> aiPlan() => {
      'session_title': 'Striking, small groups',
      'session_objective': 'Clean striking off both sides.',
      'total_duration_mins': 60,
      'warm_up': {
        'duration_mins': 10,
        'game_name': 'Zombie Chief',
        'description': 'Chase and dodge.',
        'coaching_points': ['Heads up'],
      },
      'drills': [
        {
          'game_name': 'Knock The Castle',
          'duration_mins': 50,
          'description': 'Knock the cones over.',
          'coaching_points': ['Follow through'],
          'variation': 'Smaller cones',
        },
      ],
    };

Map<String, dynamic> eventRow(int id, DateTime start,
        {String title = 'U12 Tuesday training', int team = 5}) =>
    {
      'event_id': id,
      'event_title': title,
      'event_date_time': iso(start),
      'event_date_time_2': iso(start.add(const Duration(minutes: 75))),
      'team_id': team,
      'teams': {'team_name': 'U12 Boys'},
    };

Map<String, dynamic> planRow(String id, Map<String, dynamic>? event,
        {String created = '2026-11-01T10:00:00Z', Map? plan}) =>
    {
      'plan_id': id,
      'session_title': 'Striking, small groups',
      'created_at': created,
      'event_id': event?['event_id'],
      'plan_json': plan ?? aiPlan(),
      'events': event,
    };

Map<String, dynamic> getReply({Map? plan, bool? allowed = true}) => {
      'plan_id': plan == null ? null : 'ev1',
      'plan': plan,
      'branding': {'club_id': 4},
      'event': {
        'title': 'U12 Tuesday training',
        'date_time': iso(DateTime(2026, 11, 17, 19)),
        'location_name': 'Pitch 2',
        'team_name': 'U12 Boys',
        'event_code': 'Hurling',
      },
      'squad_name': null,
      'favourites': [],
      'session_plan_allowed': allowed,
    };

/// No network: answers each generate-session-plan action and the reads.
class FakePlanApi extends V3PlanApi {
  FakePlanApi({
    this.ai = false,
    this.get,
    this.rows = const [],
    this.userPlans = const [],
    this.clubPlans = const [],
    this.games = const [zombie, castle],
    this.eventInfo,
    this.attendingCount,
    this.failOnce = const {},
  });

  final bool ai;
  final Map<String, dynamic>? get;
  final List<dynamic> rows;
  final List<Map<String, dynamic>> userPlans, clubPlans;
  final List<V3Game> games;
  final PlanEvent? eventInfo;
  final int? attendingCount;

  /// Actions that fail the first time they are called.
  final Set<String> failOnce;
  final _failed = <String>{};

  final List<Map<String, dynamic>> calls = [];
  final List<String> fns = [];

  Map<String, dynamic>? last(String action) {
    for (final c in calls.reversed) {
      if (c['action'] == action) return c;
    }
    return null;
  }

  int count(String action) => calls.where((c) => c['action'] == action).length;

  @override
  String get userId => 'u1';
  @override
  SpCall? get callOverride => call;
  @override
  String? get userIdOverride => 'u1';
  @override
  Future<bool> Function()? get aiProbe => () async => ai;
  @override
  Future<bool> aiFeatures() async => ai;
  @override
  Future<PlanEvent?> event(int eventId) async => eventInfo;
  @override
  Future<int?> attending(int eventId) async => attendingCount;
  @override
  Future<List<dynamic>> myPlanRows() async => rows;
  @override
  Future<List<V3Game>> gamesByIds(List<int> ids) async => [
        for (final g in games)
          if (ids.contains(g.gameId)) g
      ];

  @override
  Future<SpResult> call(String fn, Map<String, dynamic> body) async {
    fns.add(fn);
    calls.add(body);
    if (fn == kSpPdfFn) return const SpResult(false, {'error': 'offline'});
    final action = '${body['action']}';
    if (failOnce.contains(action) && _failed.add(action)) {
      return const SpResult(false, {'error': 'Server is busy'});
    }
    switch (action) {
      case 'get':
        return SpResult(true, get ?? getReply());
      case 'generate':
        return SpResult(true, {
          'plan_id': body['event_id'] == null ? null : 'gen1',
          'plan': {...aiPlan(), 'player_count': 14},
          'branding': {'club_id': 4},
        });
      case 'save_plan':
        return const SpResult(true, {'ok': true, 'plan_id': 'new1'});
      case 'update_plan':
        return const SpResult(true, {'ok': true});
      case 'attach_plan':
        final src = body['plan_json'] is Map ? body['plan_json'] : aiPlan();
        return SpResult(true, {
          'ok': true,
          'plan_id': 'att1',
          'plan_json': {
            ...(src as Map),
            'session_title': 'U12 Tuesday training',
            'player_count': 14,
            'coach_count': 2,
          },
        });
      case 'get_user_plans':
        return SpResult(true, {'plans': userPlans});
      case 'get_club_plans':
        return SpResult(true, {'plans': clubPlans});
      case 'get_plan':
        final club = body['plan_id'] == 'club1';
        return SpResult(true, {
          'plan_id': body['plan_id'],
          'plan': aiPlan(),
          'event_id': null,
          'club_id': club ? 4 : null,
          'is_own': !club,
          'branding': {'club_id': 4},
        });
      case 'revise_plan':
        final p = aiPlan();
        (p['drills'] as List)[0]['description'] = 'Now with two castles.';
        return SpResult(true, {'plan_id': null, 'plan': p});
      case 'deactivate_plan':
      case 'set_plan_club':
        return const SpResult(true, {'ok': true, 'club_id': 4});
    }
    return const SpResult(false, {'error': 'Unknown action'});
  }
}

class FakeDictation extends V3Dictation {
  @override
  Future<bool> start() async => true;
  @override
  Future<String> stop() async => '';
  @override
  void dispose() {}
}

V3PlanDraft twoGames() => V3PlanDraft(persist: false)
  ..add(1, 'Zombie Chief')
  ..add(2, 'Knock The Castle', mins: 15);

void tall(WidgetTester t) {
  t.view.physicalSize = const Size(1170, 6600);
  t.view.devicePixelRatio = 3;
  addTearDown(t.view.reset);
}

Future<void> pumpBuilder(WidgetTester t, FakePlanApi api, V3PlanDraft draft,
    {int? eventId,
    void Function(BuildContext)? onAddGames,
    Set<int> saved = const {1, 2}}) async {
  tall(t);
  await t.pumpWidget(MaterialApp(
      home: V3PlanBuilderPage(
    eventId: eventId,
    draft: draft,
    onAddGames: onAddGames,
    api: api,
    gamesApi: V3OfflineGamesApi(favourites: {...saved}),
    dictation: FakeDictation(),
  )));
  await t.pumpAndSettle();
}

String lineOf(WidgetTester t) => t
    .widget<Text>(find.byKey(const ValueKey('minutes-line')))
    .textSpan!
    .toPlainText();

void main() {
  group('rules', () {
    test('simple plan has the shape of a server plan', () {
      final draft = twoGames();
      final p = buildSimplePlan(
          title: '',
          games: draft.games,
          details: {1: zombie},
          players: 16,
          notes: ' Striking off both sides ');
      expect(p['session_title'], 'Training plan');
      expect(p['session_objective'], 'Striking off both sides');
      expect(p['total_duration_mins'], 25);
      expect(p['player_count'], 16);
      for (final k in ['pre_session', 'warm_up', 'cool_down', 'post_session']) {
        expect(p.containsKey(k) && p[k] == null, isTrue, reason: k);
      }
      expect(p['station_setup'], isNull);
      final d = spDrills(p);
      expect(
          d.map((x) => x['game_name']), ['Zombie Chief', 'Knock The Castle']);
      expect(d[0]['duration_mins'], 10);
      expect(d[0]['setup'], 'A 20m square.');
      expect(d[0]['description'], 'Zombies chase the runners.');
      expect(d[0]['coaching_points'], ['Heads up', 'Change direction quickly']);
      expect(d[0]['variation'], 'Add a second zombie');
      expect(d[0]['game_image'], 'https://example.com/zombie.png');
      expect(d[0]['game_video'], 'https://youtu.be/abcdefghijk');
      // A game whose details could not be read keeps its name and minutes.
      expect(d[1]['description'], '');
      expect(d[1]['coaching_points'], isEmpty);
      expect(d[1]['setup'], isNull);
      expect(d[1]['game_image'], isNull);
      // The plan screen's own rules read it as two drills that add up.
      expect(planSections(p).map((s) => s.label), ['DRILL 1', 'DRILL 2']);
      expect(sumDurations(p), p['total_duration_mins']);
      expect(
          buildSimplePlan(
              title: ' U12 training ', games: const [])['session_title'],
          'U12 training');
    });

    test('minutes maths', () {
      expect(stepLength(60, 1), 65);
      expect(stepLength(62, -1), 60);
      expect(stepLength(15, -1), 15);
      expect(stepLength(180, 1), 180);
      expect(stepGameMins(10, 1), 15);
      expect(stepGameMins(12, -1), 10);
      expect(stepGameMins(5, -1), 5);
      expect(stepGameMins(120, 1), 120);
      expect(stepPlayers(null, 1), 15);
      expect(stepPlayers(null, -1), isNull);
      expect(stepPlayers(4, -1), isNull);
      expect(stepPlayers(60, 1), 60);
      expect(minutesLine(45, 60),
          (text: '45 of 60 min', hint: '15 min to spare', over: false));
      expect(minutesLine(70, 60).over, isTrue);
      expect(minutesLine(70, 60).hint, '10 min over');
      expect(minutesLine(60, 60).hint, 'Fills the session');
      expect(gamesCount(1), '1 game');
    });

    test('event length, line and attending players', () {
      final e = PlanEvent.fromJson(eventRow(7, DateTime(2026, 11, 17, 19)));
      expect(e.lengthMins, 75);
      expect(e.line, 'Tue 17 Nov · 19:00 · U12 Boys');
      expect(const PlanEvent(eventId: 1).lengthMins, isNull);
      expect(
          attendingPlayers({
            'members': [
              {'member_id': 1, 'response_id': 3, 'role_level': 10},
              {'member_id': 2, 'response_id': 3, 'role_level': 10},
              {'member_id': 2, 'response_id': 3, 'role_level': 30},
              {'member_id': 3, 'response_id': 4, 'role_level': 10},
              {'member_id': 4, 'response_id': null, 'role_level': 10},
            ]
          }),
          1);
      expect(attendingPlayers({'members': []}), isNull);
      expect(attendingPlayers(null), isNull);
    });

    test('plans group into On events and Reusable', () {
      final rows = [
        planRow('lib1', null, plan: {
          'total_duration_mins': 40,
          'drills': [{}, {}]
        }),
        planRow('old', eventRow(3, DateTime(2026, 11, 10, 19))),
        planRow('next', eventRow(7, DateTime(2026, 11, 17, 19))),
        // A second, older plan on event 7 is not listed twice.
        planRow('dupe', eventRow(7, DateTime(2026, 11, 17, 19)),
            created: '2026-10-01T10:00:00Z'),
        planRow('other', eventRow(9, DateTime(2026, 11, 12, 19), team: 6)),
      ];
      final ev = eventPlanItems(rows);
      expect(ev.map((p) => p.planId), ['next', 'other', 'old']);
      expect(ev.first.title, 'U12 Tuesday training');
      expect(planLine(ev.first), 'Tue 17 Nov · U12 Boys · 60 min · 2 games');

      final re = reusablePlanItems({
        'plans': [
          {
            'plan_id': 'lib1',
            'session_title': 'Wet night indoors',
            'created_at': '2026-11-03T10:00:00Z',
            'club_id': 4
          },
          {
            'plan_id': 'lib2',
            'session_title': '',
            'created_at': '2026-11-02T10:00:00'
          },
        ]
      }, rows);
      expect(re.map((p) => p.title), ['Wet night indoors', 'Untitled plan']);
      expect(planLine(re[0]), '40 min · 2 games · shared with club');
      expect(planLine(re[1]), '2 Nov 2026'); // minutes not known

      final club = clubPlanItems({
        'plans': [
          {
            'plan_id': 'c1',
            'session_title': 'Tackling',
            'created_at': '2026-11-02T10:00:00',
            'created_by': 'Ann Coach',
            'is_own': false
          }
        ]
      });
      expect(clubPlanLine(club.single), 'Ann Coach · 2 Nov 2026');

      // Repeat last session: same team, earlier event, newest first.
      final here = PlanEvent.fromJson(eventRow(7, DateTime(2026, 11, 17, 19)));
      expect(lastSessionPlan(ev, here)!.planId, 'old');
      final first = PlanEvent.fromJson(eventRow(3, DateTime(2026, 11, 10, 19)));
      expect(lastSessionPlan(ev, first), isNull);
      expect(eventPlanItems(null), isEmpty);
    });

    test('changes after "Tell me what to change" and the save pill', () {
      final a = aiPlan(), b = aiPlan();
      (b['drills'] as List)[0]['description'] = 'New words';
      b['warm_up']['duration_mins'] = 15;
      b['warm_up']['game_image'] = 'x.png'; // pictures don't count
      final c = diffPlans(a, b);
      expect(c.names, ['Warm up', 'Knock The Castle']);
      expect(c.paths, {'warm_up', 'drills.0'});
      expect(diffPlans(a, aiPlan()).isEmpty, isTrue);
      expect(sectionName(a, 'warm_up'), 'Zombie Chief');
      expect(sectionName({'cool_down': {}}, 'cool_down'), 'Cool down');
      expect(spSavePill(saved: false, dirty: true), 'Not saved');
      expect(spSavePill(saved: true, dirty: false), 'Saved');
      expect(spSavePill(saved: true, dirty: true), 'Unsaved changes');
      expect(spSavePill(saved: true, dirty: false, readOnly: true), isNull);
    });
  });

  group('builder', () {
    testWidgets('shows the games, steps the minutes, hides AI when off',
        (t) async {
      final api = FakePlanApi();
      final draft = twoGames();
      await pumpBuilder(t, api, draft);
      expect(find.text('New plan'), findsOneWidget);
      expect(find.text('No event · reusable plan'), findsOneWidget);
      expect(find.text('Zombie Chief'), findsOneWidget);
      expect(find.text('Knock The Castle'), findsOneWidget);
      expect(lineOf(t), '25 of 60 min · 35 min to spare');
      expect(find.byKey(const ValueKey('write-plan')), findsNothing);
      expect(find.byKey(const ValueKey('rotate')), findsNothing);
      expect(find.text('Keep it simple'), findsOneWidget);
      // No onAddGames: no button.
      expect(find.byKey(const ValueKey('add-games')), findsNothing);

      await t.tap(find.byKey(const ValueKey('plus-1')));
      await t.pump();
      expect(draft.games.first.mins, 15);
      expect(find.byKey(const ValueKey('mins-1')), findsOneWidget);
      expect(lineOf(t), '30 of 60 min · 30 min to spare');
      // Tap targets are at least 44.
      expect(t.getSize(find.byKey(const ValueKey('plus-1'))).height,
          greaterThanOrEqualTo(44));
      await t.tap(find.byKey(const ValueKey('length-minus')));
      await t.pump();
      expect(find.text('55 min'), findsOneWidget);

      await t.tap(find.byKey(const ValueKey('remove-2')));
      await t.pump();
      expect(find.text('Knock The Castle'), findsNothing);
      expect(draft.count, 1);
    });

    testWidgets('no games: the buttons wait and Add games is offered',
        (t) async {
      final api = FakePlanApi(ai: true);
      var asked = 0;
      await pumpBuilder(t, api, V3PlanDraft(persist: false),
          onAddGames: (_) => asked++);
      expect(
          find.text('Add at least one game to make a plan.'), findsOneWidget);
      expect(find.text('Write the plan for me'), findsOneWidget);
      await t.tap(find.byKey(const ValueKey('keep-simple')));
      await t.tap(find.byKey(const ValueKey('write-plan')));
      await t.pumpAndSettle();
      expect(api.calls, isEmpty);
      await t.tap(find.byKey(const ValueKey('add-games')));
      expect(asked, 1);
    });

    testWidgets('Keep it simple saves a reusable plan and opens it', (t) async {
      final api = FakePlanApi();
      final draft = twoGames();
      await pumpBuilder(t, api, draft);
      await t.enterText(find.byKey(const ValueKey('notes')), 'Striking');
      await t.tap(find.byKey(const ValueKey('keep-simple')));
      await t.pumpAndSettle();
      final body = api.last('save_plan')!;
      expect(body['user_id'], 'u1');
      expect(body.containsKey('event_id'), isFalse);
      final plan = body['plan_json'] as Map;
      expect(plan['session_title'], 'Training plan');
      expect(plan['session_objective'], 'Striking');
      expect(plan['total_duration_mins'], 25);
      expect(spDrills(plan).map((d) => d['game_name']),
          ['Zombie Chief', 'Knock The Castle']);
      expect(spDrills(plan).map((d) => d['duration_mins']), [10, 15]);
      expect(api.count('generate'), 0);
      // The plan screen, saved, with no AI controls; the draft is empty.
      expect(find.text('Session plan'), findsOneWidget);
      expect(find.text('Saved'), findsOneWidget);
      expect(find.text('DRILL 2'), findsOneWidget);
      expect(find.text('Zombies chase the runners.'), findsOneWidget);
      expect(find.byKey(const ValueKey('voice-rest')), findsNothing);
      expect(find.byKey(const ValueKey('menu-WARM UP')), findsNothing);
      expect(find.byKey(const ValueKey('share-club')), findsOneWidget);
      expect(draft.isEmpty, isTrue);
      expect(find.text('New plan'), findsNothing);
    });

    testWidgets('for an event: fills in the event and attaches the plan',
        (t) async {
      // The team's switch allows AI even though the coach's own is off.
      final api = FakePlanApi(
          get: getReply(allowed: true),
          eventInfo:
              PlanEvent.fromJson(eventRow(7, DateTime(2026, 11, 17, 19))),
          attendingCount: 14);
      final draft = twoGames()..setEvent(7);
      await pumpBuilder(t, api, draft);
      expect(find.text('U12 Tuesday training'), findsOneWidget);
      expect(find.text('Tue 17 Nov · 19:00 · U12 Boys'), findsOneWidget);
      expect(find.text('75 min'), findsOneWidget); // the event's own length
      expect(find.text('14'), findsOneWidget);
      expect(find.text('Write the plan for me'), findsOneWidget);
      // The coach knows better: 12 players.
      await t.tap(find.byKey(const ValueKey('players-minus')));
      await t.tap(find.byKey(const ValueKey('players-minus')));
      await t.pump();
      await t.tap(find.byKey(const ValueKey('keep-simple')));
      await t.pumpAndSettle();
      final body = api.last('attach_plan')!;
      expect(body['event_id'], 7);
      expect(
          (body['plan_json'] as Map)['session_title'], 'U12 Tuesday training');
      expect(spDrills(body['plan_json'] as Map).length, 2);
      expect(api.count('save_plan'), 0);
      // The server's count (14) gives way to the coach's 12.
      final up = api.last('update_plan')!;
      expect(up['plan_id'], 'att1');
      expect((up['plan_json'] as Map)['player_count'], 12);
      expect(find.text('Session plan'), findsOneWidget);
      expect(find.text('📍 Pitch 2'), findsOneWidget);
      expect(find.byKey(const ValueKey('voice-rest')), findsOneWidget);
      expect(draft.isEmpty, isTrue);
      expect(draft.eventId, isNull);
    });

    testWidgets('team without session plans still gets the simple plan',
        (t) async {
      final api = FakePlanApi(get: getReply(allowed: false));
      await pumpBuilder(t, api, twoGames(), eventId: 7);
      expect(find.byKey(const ValueKey('write-plan')), findsNothing);
      await t.tap(find.byKey(const ValueKey('keep-simple')));
      await t.pumpAndSettle();
      expect(api.last('attach_plan')!['event_id'], 7);
      expect(find.byKey(const ValueKey('voice-rest')), findsNothing);
      expect(find.byKey(const ValueKey('save')), findsOneWidget);
    });

    testWidgets('Write the plan for me sends the games in order', (t) async {
      final api = FakePlanApi(ai: true);
      final draft = twoGames()..move(1, 0); // castle first
      final games = V3OfflineGamesApi(favourites: {2});
      tall(t);
      await t.pumpWidget(MaterialApp(
          home: V3PlanBuilderPage(
              draft: draft,
              api: api,
              gamesApi: games,
              dictation: FakeDictation())));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const ValueKey('players-plus')));
      await t.enterText(find.byKey(const ValueKey('notes')), 'Lots of touches');
      await t.tap(find.byKey(const ValueKey('rotate')));
      await t.pump();
      await t.tap(find.byKey(const ValueKey('write-plan')));
      await t.pumpAndSettle();
      // Zombie Chief is not a saved game: it is used anyway, and the
      // coach's Saved list is left alone.
      expect(find.text('Save this game first?'), findsNothing);
      expect(games.calls, isEmpty);
      final g = api.last('generate')!;
      expect(g['game_ids'], [2, 1]);
      expect(g['use_game_ids'], isTrue);
      expect(g['duration_mins'], 60);
      expect(g['player_count'], 15);
      expect(g['session_notes'], 'Lots of touches');
      expect(g['rotate_stations'], isFalse);
      expect(g['event_id'], isNull);
      expect(g['user_id'], 'u1');
      // With no event the plan is not saved until the coach saves it.
      expect(find.text('Not saved'), findsOneWidget);
      expect(find.byKey(const ValueKey('voice-rest')), findsOneWidget);
      expect(draft.count, 2);
      await t.tap(find.byKey(const ValueKey('save')));
      await t.pumpAndSettle();
      expect(api.count('save_plan'), 1);
      expect(find.text('Saved'), findsOneWidget);
      expect(draft.isEmpty, isTrue);
    });

    testWidgets('a failed save shows the reason and Try again', (t) async {
      final api = FakePlanApi(failOnce: {'save_plan'});
      final draft = twoGames();
      await pumpBuilder(t, api, draft);
      await t.tap(find.byKey(const ValueKey('keep-simple')));
      await t.pumpAndSettle();
      expect(find.text('Server is busy'), findsOneWidget);
      expect(draft.count, 2);
      await t.tap(find.byKey(const ValueKey('retry')));
      await t.pumpAndSettle();
      expect(api.count('save_plan'), 2);
      expect(find.text('Saved'), findsOneWidget);
    });
  });

  group('plan screen', () {
    Future<void> pumpPlan(
        WidgetTester t, FakePlanApi api, String planId) async {
      tall(t);
      await t.pumpWidget(MaterialApp(
          home: V3SessionPlanPage.open(
        planId: planId,
        gamesApi: V3OfflineGamesApi(),
        call: api.call,
        userId: 'u1',
        dictation: FakeDictation(),
        aiProbe: api.aiProbe,
      )));
      await t.pumpAndSettle();
    }

    testWidgets('a saved plan: update or copy, change with undo', (t) async {
      final api = FakePlanApi(ai: true);
      await pumpPlan(t, api, 'lib1');
      expect(api.last('get_plan')!['plan_id'], 'lib1');
      expect(find.text('Saved'), findsOneWidget);
      expect(find.text('MAKE IT HARDER'), findsOneWidget);
      expect(find.text('Change plan'), findsNothing);
      // A section's own Change, from its menu.
      await t.tap(find.byKey(const ValueKey('menu-DRILL 1')));
      await t.pumpAndSettle();
      await t.tap(find.text('Change this part'));
      await t.pumpAndSettle();
      expect(find.text('Change: Knock The Castle'), findsOneWidget);
      await t.enterText(find.byType(TextField).last, 'Two castles');
      await t.pump();
      await t.tap(find.text('Update'));
      await t.pumpAndSettle();
      expect(api.last('revise_plan')!['target'], 'drills.0');
      expect(find.text('Plan updated · 1 change'), findsOneWidget);
      expect(find.text('Changed'), findsOneWidget);
      expect(find.text('Now with two castles.'), findsOneWidget);
      expect(find.text('Unsaved changes'), findsOneWidget);
      await t.tap(find.byKey(const ValueKey('undo')));
      await t.pumpAndSettle();
      expect(find.text('Now with two castles.'), findsNothing);
      expect(find.text('Knock the cones over.'), findsOneWidget);
      expect(find.text('Saved'), findsOneWidget);

      await t.tap(find.byKey(const ValueKey('save')));
      await t.pumpAndSettle();
      expect(find.text('Update this plan'), findsOneWidget);
      await t.tap(find.byKey(const ValueKey('save-copy')));
      await t.pumpAndSettle();
      expect(api.count('save_plan'), 1);
      expect(api.count('update_plan'), 0);
      await t.tap(find.byKey(const ValueKey('save')));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const ValueKey('save-update')));
      await t.pumpAndSettle();
      expect(api.last('update_plan')!['plan_id'], 'new1');
    });

    testWidgets('AI off hides every AI control but text still edits',
        (t) async {
      final api = FakePlanApi();
      await pumpPlan(t, api, 'lib1');
      expect(find.byKey(const ValueKey('voice-rest')), findsNothing);
      expect(find.byKey(const ValueKey('menu-WARM UP')), findsNothing);
      await t.tap(find.byKey(const ValueKey('menu-DRILL 1')));
      await t.pumpAndSettle();
      expect(find.text('Change this part'), findsNothing);
      expect(find.text('Remove drill'), findsOneWidget);
      await t.tapAt(const Offset(10, 10));
      await t.pumpAndSettle();
      await t.enterText(
          find.widgetWithText(TextFormField, 'Knock the cones over.'),
          'Knock them all.');
      await t.pump();
      expect(find.text('Unsaved changes'), findsOneWidget);
    });

    testWidgets("another coach's club plan is read-only until used", (t) async {
      final api = FakePlanApi();
      await pumpPlan(t, api, 'club1');
      expect(find.byType(TextFormField), findsNothing);
      expect(find.byKey(const ValueKey('save')), findsNothing);
      expect(find.byKey(const ValueKey('save-pill')), findsNothing);
      await t.tap(find.byKey(const ValueKey('use-plan')));
      await t.pumpAndSettle();
      expect(find.text('Not saved'), findsOneWidget);
      expect(find.byType(TextFormField), findsWidgets);
      await t.tap(find.byKey(const ValueKey('save')));
      await t.pumpAndSettle();
      // A copy of my own: saved new, never an update of the club's plan.
      expect(api.count('save_plan'), 1);
      expect(api.count('update_plan'), 0);
    });
  });

  group('plans view', () {
    Future<void> pumpView(WidgetTester t, FakePlanApi api,
        {void Function(BuildContext)? onNewPlan}) async {
      tall(t);
      await t.pumpWidget(MaterialApp(
          home: Scaffold(
              body: V3PlansView(
        onNewPlan: onNewPlan,
        api: api,
        gamesApi: V3OfflineGamesApi(),
        dictation: FakeDictation(),
      ))));
      await t.pumpAndSettle();
    }

    FakePlanApi full() => FakePlanApi(rows: [
          planRow('lib1', null),
          planRow('ev7', eventRow(7, DateTime(2026, 11, 17, 19))),
          planRow(
              'ev3',
              eventRow(3, DateTime(2026, 11, 12, 19),
                  title: 'U12 Thursday training')),
        ], userPlans: [
          {
            'plan_id': 'lib1',
            'session_title': 'Wet night indoors',
            'created_at': '2026-11-03T10:00:00Z',
            'club_id': 4
          },
        ], clubPlans: [
          {
            'plan_id': 'club1',
            'session_title': 'Tackling basics',
            'created_at': '2026-11-02T10:00:00',
            'created_by': 'Ann Coach',
            'is_own': false
          },
        ]);

    testWidgets('Mine: On events and Reusable, then Club', (t) async {
      final api = full();
      var asked = 0;
      await pumpView(t, api, onNewPlan: (_) => asked++);
      expect(find.text('ON EVENTS'), findsOneWidget);
      expect(find.text('REUSABLE'), findsOneWidget);
      expect(find.text('U12 Tuesday training'), findsOneWidget);
      expect(find.text('Tue 17 Nov · U12 Boys · 60 min · 2 games'),
          findsOneWidget);
      expect(find.text('Wet night indoors'), findsOneWidget);
      expect(find.text('60 min · 2 games · shared with club'), findsOneWidget);
      // Newest event first.
      expect(t.getTopLeft(find.text('U12 Tuesday training')).dy,
          lessThan(t.getTopLeft(find.text('U12 Thursday training')).dy));
      // Pills sit on the left.
      expect(t.getTopLeft(find.byKey(const ValueKey('pill-Mine'))).dx, 16);
      await t.tap(find.byKey(const ValueKey('new-plan')));
      expect(asked, 1);

      await t.tap(find.byKey(const ValueKey('pill-Club')));
      await t.pumpAndSettle();
      expect(find.text('Tackling basics'), findsOneWidget);
      expect(find.text('Ann Coach · 2 Nov 2026'), findsOneWidget);
      expect(find.text('ON EVENTS'), findsNothing);
      // A club plan opens read-only with Use This Plan.
      await t.tap(find.text('Tackling basics'));
      await t.pumpAndSettle();
      expect(api.last('get_plan')!['plan_id'], 'club1');
      expect(find.text('Use This Plan'), findsOneWidget);
    });

    testWidgets('empty states and no New plan button without a callback',
        (t) async {
      final api = FakePlanApi();
      await pumpView(t, api);
      expect(find.text('No plans yet'), findsOneWidget);
      expect(find.byKey(const ValueKey('new-plan')), findsNothing);
      await t.tap(find.byKey(const ValueKey('pill-Club')));
      await t.pumpAndSettle();
      expect(find.text('No club plans yet'), findsOneWidget);
    });

    testWidgets('swipe to deactivate asks first', (t) async {
      final api = full();
      await pumpView(t, api);
      await t.drag(find.text('Wet night indoors'), const Offset(-400, 0));
      await t.pumpAndSettle();
      expect(find.text('Deactivate this plan?'), findsOneWidget);
      await t.tap(find.text('Cancel'));
      await t.pumpAndSettle();
      expect(api.count('deactivate_plan'), 0);
      expect(find.text('Wet night indoors'), findsOneWidget);
      await t.drag(find.text('Wet night indoors'), const Offset(-400, 0));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const ValueKey('confirm-deactivate')));
      await t.pumpAndSettle();
      expect(api.last('deactivate_plan')!['plan_id'], 'lib1');
      expect(find.text('Wet night indoors'), findsNothing);
    });

    testWidgets('a saved plan elsewhere reloads the list', (t) async {
      final api = full();
      await pumpView(t, api);
      final before = api.count('get_user_plans');
      spPlansChanged.value++;
      await t.pumpAndSettle();
      expect(api.count('get_user_plans'), before + 1);
    });
  });

  group('event entry', () {
    Future<V3PlanDraft> pumpEntry(WidgetTester t, FakePlanApi api) async {
      tall(t);
      final draft = V3PlanDraft(persist: false);
      await t.pumpWidget(MaterialApp(
          home: Scaffold(
              body: Builder(
                  builder: (context) => TextButton(
                      onPressed: () => openEventPlan(context,
                          eventId: 7,
                          api: api,
                          gamesApi: V3OfflineGamesApi(),
                          draft: draft,
                          dictation: FakeDictation()),
                      child: const Text('Session plan button'))))));
      await t.tap(find.text('Session plan button'));
      await t.pumpAndSettle();
      return draft;
    }

    final here = PlanEvent.fromJson(eventRow(7, DateTime(2026, 11, 17, 19)));

    testWidgets('no plan yet: the choices, and Start a new plan', (t) async {
      // Session plans are off for the team: the sheet still opens.
      final api = FakePlanApi(get: getReply(allowed: false), eventInfo: here);
      final draft = await pumpEntry(t, api);
      expect(find.text('Tue 17 Nov · U12 Tuesday training'), findsOneWidget);
      expect(find.text('Start a new plan'), findsOneWidget);
      expect(find.text('Use a saved plan'), findsOneWidget);
      // No earlier plan for this team: no Repeat.
      expect(find.byKey(const ValueKey('repeat-last')), findsNothing);
      await t.tap(find.byKey(const ValueKey('start-new')));
      await t.pumpAndSettle();
      expect(draft.eventId, 7);
      expect(find.text('New plan'), findsOneWidget);
      expect(find.text('Keep it simple'), findsOneWidget);
      expect(find.byKey(const ValueKey('write-plan')), findsNothing);
    });

    testWidgets("Repeat last session's plan attaches a copy", (t) async {
      final api = FakePlanApi(eventInfo: here, rows: [
        planRow('older', eventRow(2, DateTime(2026, 11, 3, 19))),
        planRow('last', eventRow(3, DateTime(2026, 11, 10, 19))),
        planRow('elsewhere', eventRow(9, DateTime(2026, 11, 12, 19), team: 6)),
      ]);
      await pumpEntry(t, api);
      expect(find.text("Repeat last session's plan"), findsOneWidget);
      expect(find.text('Tue 10 Nov · U12 Boys · 60 min · 2 games'),
          findsOneWidget);
      await t.tap(find.byKey(const ValueKey('repeat-last')));
      await t.pumpAndSettle();
      final a = api.last('attach_plan')!;
      expect(a['event_id'], 7);
      expect(a['plan_id'], 'last');
      expect(find.text('Session plan'), findsOneWidget);
      expect(find.text('Change plan'), findsOneWidget);
      expect(find.text('Saved'), findsOneWidget);
    });

    testWidgets('Use a saved plan picks from Mine and attaches it', (t) async {
      final api = FakePlanApi(eventInfo: here, userPlans: [
        {
          'plan_id': 'lib1',
          'session_title': 'Wet night indoors',
          'created_at': '2026-11-03T10:00:00Z'
        },
      ]);
      await pumpEntry(t, api);
      await t.tap(find.byKey(const ValueKey('use-saved')));
      await t.pumpAndSettle();
      expect(find.text('Use a saved plan'), findsOneWidget);
      expect(find.text('ON EVENTS'), findsNothing);
      await t.tap(find.text('Wet night indoors'));
      await t.pumpAndSettle();
      await t.tap(find.text('Use This Plan'));
      await t.pumpAndSettle();
      expect(api.last('attach_plan')!['plan_id'], 'lib1');
      expect(find.text('Change plan'), findsOneWidget);
    });

    testWidgets('an event with a plan opens it; Change plan shows the choices',
        (t) async {
      final api = FakePlanApi(get: getReply(plan: aiPlan()), eventInfo: here);
      await pumpEntry(t, api);
      expect(find.text('Session plan'), findsOneWidget);
      expect(find.text('Striking, small groups'), findsOneWidget);
      expect(find.byKey(const ValueKey('voice-rest')), findsOneWidget);
      await t.tap(find.byKey(const ValueKey('change-plan')));
      await t.pumpAndSettle();
      expect(find.text('Start a new plan'), findsOneWidget);
      expect(find.textContaining('This event has a plan'), findsOneWidget);
    });
  });
}
