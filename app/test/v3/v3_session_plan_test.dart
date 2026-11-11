import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:coach_smart_v2/v3/games/v3_games.dart';
import 'package:coach_smart_v2/v3/match_report/v3_voice_sheet.dart';
import 'package:coach_smart_v2/v3/session_plan/v3_session_plan_api.dart';
import 'package:coach_smart_v2/v3/session_plan/v3_session_plan_models.dart';
import 'package:coach_smart_v2/v3/session_plan/v3_session_plan_page.dart';

Map<String, dynamic> samplePlan() => {
      'session_title': 'Hand passing under pressure',
      'session_objective': 'Quick, accurate hand passing.',
      'total_duration_mins': 60,
      'player_count': 18,
      'coach_count': 3,
      'weather': {'summary': 'Dry, 9°C', 'temp_c': 9, 'precip_pct': 10},
      'warm_up': {
        'duration_mins': 10,
        'game_name': 'Rondo',
        'description': 'Light jog and passing.',
        'coaching_points': ['Heads up'],
      },
      'drills': [
        {
          'game_name': 'Box Passing',
          'duration_mins': 20,
          'setup': 'Four cones in a square.',
          'description': 'Pass around the box.',
          'coaching_points': ['Call for it', 'Move after the pass'],
          'variation': 'Add a defender',
        },
        {
          'game_name': 'Three Lanes',
          'duration_mins': 20,
          'description': 'Run the lanes.',
          'coaching_points': [],
        },
      ],
      'cool_down': {'duration_mins': 10, 'description': 'Stretch.'},
    };

Map<String, dynamic> getReply({Map? plan, bool? allowed = true}) => {
      'plan_id': plan == null ? null : 'p1',
      'plan': plan,
      'branding': {'club_id': 4, 'club_name': 'Clontarf'},
      'event': {
        'title': 'U12 Training',
        'date_time': DateTime(2026, 11, 12, 19, 0).toUtc().toIso8601String(),
        'location_name': 'Clontarf Pitch 2',
        'event_code': 'Football',
      },
      'squad_name': 'Blue',
      'favourites': [
        {
          'game_id': 1,
          'game_name': 'Box Passing',
          'game_code': ['Football'],
        },
        {
          'game_id': 2,
          'game_name': 'Three Lanes',
          'game_code': ['Football'],
        },
        {
          'game_id': 3,
          'game_name': 'Hurling Grip',
          'game_code': ['Hurling'],
        },
      ],
      'session_plan_allowed': allowed,
    };

/// Records calls and answers by action.
class FakeBackend {
  FakeBackend(this.get);
  final Map<String, dynamic> get;
  final List<Map<String, dynamic>> calls = [];
  final List<String> fns = [];

  Future<SpResult> call(String fn, Map<String, dynamic> body) async {
    fns.add(fn);
    calls.add(body);
    if (fn == kSpPdfFn) return const SpResult(false, {'error': 'offline'});
    switch (body['action']) {
      case 'get':
        return SpResult(true, get);
      case 'generate':
        return SpResult(true, {
          'plan_id': 'p9',
          'plan': samplePlan(),
          'event': get['event'],
          'squad_name': 'Blue',
        });
      case 'update_plan':
        return const SpResult(true, {'ok': true});
      case 'revise_plan':
        final p = samplePlan()..['session_title'] = 'Revised plan';
        return SpResult(true, {'plan_id': 'p1', 'plan': p});
      case 'get_user_plans':
        return const SpResult(true, {
          'plans': [
            {
              'plan_id': 'lib1',
              'session_title': 'My library plan',
              'created_at': '2026-11-03T10:00:00Z'
            }
          ]
        });
      case 'attach_plan':
        return SpResult(
            true, {'ok': true, 'plan_id': 'p5', 'plan_json': samplePlan()});
    }
    return const SpResult(false, {'error': 'Unknown action'});
  }

  Map<String, dynamic>? last(String action) {
    for (final c in calls.reversed) {
      if (c['action'] == action) return c;
    }
    return null;
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

Future<FakeBackend> pump(WidgetTester t, Map<String, dynamic> get,
    {int? eventId = 1}) async {
  t.view.physicalSize = const Size(1170, 2532);
  t.view.devicePixelRatio = 3;
  addTearDown(t.view.reset);
  final b = FakeBackend(get);
  await t.pumpWidget(MaterialApp(
      home: V3SessionPlanPage(
    eventId: eventId,
    gamesApi: V3OfflineGamesApi(favourites: {1, 2, 3}),
    testCall: b.call,
    testUserId: 'u1',
    testDictation: FakeDictation(),
  )));
  await t.pumpAndSettle();
  return b;
}

Future<void> scrollTo(WidgetTester t, Finder f, double delta) async {
  await t.scrollUntilVisible(f, delta,
      scrollable: find.byType(Scrollable).first);
  await t.ensureVisible(f.first);
  await t.pumpAndSettle();
}

void main() {
  group('models', () {
    test('favourites filter by the event code, falling back to all', () {
      final favs = parseFavourites(getReply()['favourites']);
      expect(filterByEventCode(favs, 'Football').map((f) => f.gameId), [1, 2]);
      expect(filterByEventCode(favs, 'Camogie').length, 3);
      expect(filterByEventCode(favs, '').length, 3);
    });

    test('sections, minutes and start times', () {
      final p = samplePlan();
      expect(planSections(p).map((s) => s.label),
          ['WARM UP', 'DRILL 1', 'DRILL 2', 'COOL DOWN']);
      expect(sumDurations(p), 60);
      final starts = sectionStarts(p, DateTime(2026, 1, 1, 19));
      expect(spClock(starts['drills.1']!), '19:30');
      expect(spClock(starts['cool_down']!), '19:50');
      setDuration(p, 'drills.0', 25);
      expect(p['total_duration_mins'], 65);
    });

    test('paths, drill order and removal', () {
      final p = samplePlan();
      expect(getPath(p, 'drills.0.coaching_points.1'), 'Move after the pass');
      setPath(p, 'drills.1.description', 'New words');
      expect(getPath(p, 'drills.1.description'), 'New words');
      setPath(p, 'missing.x', 'y');
      expect(p.containsKey('missing'), isFalse);
      moveDrill(p, 1, 0);
      expect(spDrills(p).first['game_name'], 'Three Lanes');
      removeDrill(p, 0);
      expect(spDrills(p).length, 1);
      expect(p['total_duration_mins'], 40);
    });

    test('gate, picker meta, weather and errors', () {
      final off = SpLoad.fromJson(getReply(allowed: false));
      expect(spIsOff(eventId: 1, load: off), isTrue);
      expect(spIsOff(eventId: null, load: off), isFalse);
      final withPlan =
          SpLoad.fromJson(getReply(plan: samplePlan(), allowed: false));
      expect(spIsOff(eventId: 1, load: withPlan), isFalse);
      final unknown = SpLoad.fromJson(getReply(allowed: null));
      expect(spIsOff(eventId: 1, load: unknown), isFalse);

      final s = SpPlanSummary.fromJson({
        'plan_id': 'a',
        'session_title': '',
        'created_at': '2026-11-03T10:00:00',
        'created_by': 'Ann Coach',
      });
      expect(s.title, 'Untitled Plan');
      expect(spPlanMeta(s, club: false), '3 Nov 2026');
      expect(spPlanMeta(s, club: true), 'Ann Coach · 3 Nov 2026');

      expect(weatherIcon({'precip_pct': 70, 'temp_c': 10}), '🌧');
      expect(weatherIcon({'precip_pct': 0, 'temp_c': 3}), '🥶');
      expect(spErrorText({'message': 'Busy'}, 'x'), 'Busy');
      expect(spErrorText(null, 'Fallback'), 'Fallback');
      expect(clampSessionMinutes(200), 180);
    });
  });

  group('page', () {
    testWidgets('opens the event plan with times, minutes and wording',
        (t) async {
      await pump(t, getReply(plan: samplePlan()));
      expect(find.text('Change Plan'), findsOneWidget);
      expect(find.text('📍 Clontarf Pitch 2'), findsOneWidget);
      expect(find.text('🏷 Blue'), findsOneWidget);
      expect(find.text('Add session image'), findsOneWidget);
      expect(find.text('Share'), findsOneWidget);
      await scrollTo(t, find.text('DRILL 1'), 300);
      expect(find.text('19:10'), findsOneWidget); // drill 1 starts
      await scrollTo(t, find.text('MAKE IT HARDER'), 300);
      // Share with Club is for library plans only.
      await scrollTo(t, find.byKey(const ValueKey('save')), 300);
      expect(find.text('Share with Club'), findsNothing);
    });

    testWidgets('team without session plans shows the off screen', (t) async {
      await pump(t, getReply(allowed: false));
      expect(
          find.text("Session plans aren't on for this team"), findsOneWidget);
    });

    testWidgets('generates from the ticked games in order', (t) async {
      final b = await pump(t, getReply());
      expect(find.text('Generate Session Plan'), findsOneWidget);
      // Code filter: the hurling game is left out for a football event.
      expect(find.text('Hurling Grip'), findsNothing);
      await t.tap(find.byTooltip('Longer'));
      await t.pump();
      expect(find.text('65 min'), findsOneWidget);
      await scrollTo(t, find.text('Add games from the library'), 300);
      await t.tap(find.byType(Checkbox).last); // untick Three Lanes
      await t.pump();
      await t.tap(find.text('Generate Session Plan'));
      await t.pumpAndSettle();
      final g = b.last('generate')!;
      expect(g['game_ids'], [1]);
      expect(g['duration_mins'], 65);
      expect(g['rotate_stations'], isTrue);
      expect(g['event_id'], 1);
      expect(g['user_id'], 'u1');
      expect(find.text('Change Plan'), findsOneWidget);
    });

    testWidgets('edits text and minutes, then saves', (t) async {
      final b = await pump(t, getReply(plan: samplePlan()));
      await scrollTo(t, find.byKey(const ValueKey('dur-DRILL 1')), 300);
      await t.tap(find.byKey(const ValueKey('dur-DRILL 1')));
      await t.pumpAndSettle();
      await t.tap(find.byTooltip('More'));
      await t.pump();
      expect(find.text('25 min'), findsWidgets);
      await t.tap(find.text('Done'));
      await t.pumpAndSettle();
      await scrollTo(t, find.text('Four cones in a square.'), 300);
      await t.enterText(
          find.widgetWithText(TextFormField, 'Four cones in a square.'),
          'Six cones.');
      await scrollTo(t, find.byKey(const ValueKey('save')), 300);
      await t.tap(find.byKey(const ValueKey('save')));
      await t.pumpAndSettle();
      final u = b.last('update_plan')!;
      expect(u['plan_id'], 'p1');
      final plan = u['plan_json'] as Map;
      expect(getPath(plan, 'drills.0.setup'), 'Six cones.');
      expect(getPath(plan, 'drills.0.duration_mins'), 25);
      expect(plan['total_duration_mins'], 65);
      expect(find.text('Saved ✓'), findsOneWidget);
    });

    testWidgets('moves a drill with its menu', (t) async {
      final b = await pump(t, getReply(plan: samplePlan()));
      await scrollTo(t, find.byKey(const ValueKey('menu-DRILL 2')), 300);
      await t.tap(find.byKey(const ValueKey('menu-DRILL 2')));
      await t.pumpAndSettle();
      await t.tap(find.text('Move up'));
      await t.pumpAndSettle();
      await scrollTo(t, find.byKey(const ValueKey('save')), 300);
      await t.tap(find.byKey(const ValueKey('save')));
      await t.pumpAndSettle();
      final plan = b.last('update_plan')!['plan_json'] as Map;
      expect(spDrills(plan).map((d) => d['game_name']),
          ['Three Lanes', 'Box Passing']);
    });

    testWidgets('changes the plan through the voice panel', (t) async {
      final b = await pump(t, getReply(plan: samplePlan()));
      await scrollTo(t, find.byKey(const ValueKey('voice-rest')), 300);
      await t.tap(find.byKey(const ValueKey('voice-rest')));
      await t.pumpAndSettle();
      expect(find.text('Say or type what you would like changed.'),
          findsOneWidget);
      await t.enterText(find.byType(TextField).last, 'More possession drills');
      await t.pump();
      await t.tap(find.text('Update'));
      await t.pumpAndSettle();
      final r = b.last('revise_plan')!;
      expect(r['feedback'], 'More possession drills');
      expect(r['plan_id'], 'p1');
      expect((r['existing_plan'] as Map)['session_title'],
          'Hand passing under pressure');
      await scrollTo(t, find.text('Revised plan'), -300);
      expect(find.text('Revised plan'), findsOneWidget);
    });

    testWidgets('PDF asks phone or A4 and calls the PDF function', (t) async {
      final b = await pump(t, getReply(plan: samplePlan()));
      await t.tap(find.byKey(const ValueKey('share-pdf')));
      await t.pumpAndSettle();
      expect(find.text('Phone version'), findsOneWidget);
      await t.tap(find.byKey(const ValueKey('pdf-a4')));
      await t.pumpAndSettle();
      expect(b.fns.last, kSpPdfFn);
      expect(b.calls.last['format'], 'a4');
      expect(b.calls.last['plan_id'], 'p1');
      expect(find.text('Could not generate PDF — please try again'),
          findsOneWidget);
    });

    testWidgets('attaches a saved plan from the picker', (t) async {
      final b = await pump(t, getReply());
      await t.tap(find.text('Attach a Saved Plan'));
      await t.pumpAndSettle();
      expect(find.text('My library plan'), findsOneWidget);
      expect(find.text('3 Nov 2026'), findsOneWidget);
      await t.tap(find.byKey(const ValueKey('use-lib1')));
      await t.pumpAndSettle();
      expect(b.last('attach_plan')!['plan_id'], 'lib1');
      expect(find.text('Hand passing under pressure'), findsOneWidget);
    });
  });
}
