import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:coach_smart_v2/v3/favourites/v3_favourites_api.dart';
import 'package:coach_smart_v2/v3/favourites/v3_favourites_models.dart';
import 'package:coach_smart_v2/v3/favourites/v3_favourites_page.dart';
import 'package:coach_smart_v2/v3/favourites/v3_my_plans_page.dart';
import 'package:coach_smart_v2/v3/favourites/v3_session_plan_page.dart';
import 'package:coach_smart_v2/v3/match_report/v3_voice_sheet.dart';

Map<String, dynamic> fav(int id, String name,
        {List<String> type = const ['Game'],
        List<String> code = const ['Football'],
        List<String> age = const ['u10', 'u12']}) =>
    {
      'game_id': id,
      'game_name': name,
      'game_image': null,
      'game_code': code,
      'game_type': type,
      'game_age': age,
      'has_video': false,
      'position': id,
    };

List<Map<String, dynamic>> favs(int n) =>
    [for (var i = 1; i <= n; i++) fav(i, 'Game $i')];

Map<String, dynamic> samplePlan() => {
      'session_title': 'Kicking session',
      'session_objective': 'Accurate kick passing',
      'player_count': 18,
      'coach_count': 2,
      'total_duration_mins': 60,
      'warm_up': {
        'game_name': 'Rondo',
        'duration_mins': 10,
        'description': 'Pass in a circle',
        'coaching_points': ['Head up', 'Soft hands'],
      },
      'drills': [
        {
          'game_name': 'Target ball',
          'duration_mins': 20,
          'setup': 'Two boxes',
          'description': 'Kick to the target',
          'coaching_points': ['Lock the ankle'],
          'variation': 'Use the weaker foot',
        },
      ],
      'cool_down': {'duration_mins': 5, 'description': 'Stretch'},
    };

Future<void> pump(WidgetTester t, Widget w) async {
  t.view.physicalSize = const Size(1170, 2532);
  t.view.devicePixelRatio = 3;
  addTearDown(t.view.reset);
  await t.pumpWidget(MaterialApp(home: w));
  await t.pumpAndSettle();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('models', () {
    test('tags: type, ages, codes and video', () {
      expect(ageText(['u8', 'u12', 'u10']), 'U8–U12');
      expect(ageText(['U9']), 'U9');
      expect(ageText([]), '');
      final f = FavGame.fromJson({
        ...fav(1, 'A', code: ['Football', 'Hurling']),
        'has_video': true
      });
      expect(tagsOf(f).map((t) => t.text).toList(),
          ['Game', 'U10–U12', 'Both codes', '▶ Video']);
      expect(tagsOf(f).first.type, isTrue);
    });

    test('chips only when they split a list of 5 or more', () {
      final four = parseFavourites({
        'favourites': [
          fav(1, 'a', type: ['Warmup']),
          ...favs(3).skip(1)
        ]
      });
      expect(favChips(four), isEmpty);
      final list = parseFavourites({
        'favourites': [
          fav(1, 'a', type: ['Warmup']),
          fav(2, 'b', type: ['Drill'], code: ['Hurling']),
          ...[for (var i = 3; i <= 5; i++) fav(i, 'g$i')],
        ]
      });
      final chips = favChips(list);
      expect(chips.map((c) => c.label).toList(),
          ['All', 'Warm-ups', 'Drills', 'Games', 'Football', 'Hurling']);
      expect(favMatches(list[1], 'code:Hurling'), isTrue);
      expect(favMatches(list[0], 'type:Warm-ups'), isTrue);
      expect(favMatches(list[0], 'type:Drills'), isFalse);
    });

    test('picks: first 10, counts and labels', () {
      final list = parseFavourites({'favourites': favs(12)});
      expect(initialPicks(list), [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]);
      expect(pickCountText(10, 12).rest, " · that's the limit");
      expect(pickCountText(3, 12).rest, ' · up to 10');
      expect(pickCountText(3, 5).bold, '3 of 5');
      expect(pickMeter(5, 5), 1);
      expect(buildPlanLabel(1), 'Build plan with 1 game');
      expect(buildPlanLabel(0), 'Pick games to build a plan');
      expect(exportLabel(2, false), 'Export 2 games');
      expect(exportLabel(0, false), 'Export Games');
      expect(exportLabel(2, true), 'PDF');
    });

    test('reorder keeps hidden picks in their slots', () {
      // Picked 1..4; the filter shows 1, 3, 4. Drag 4 to the top.
      expect(reorderPicked([1, 2, 3, 4], [1, 3, 4], 2, 0), [4, 2, 1, 3]);
    });

    test('diffPlans names what changed and the old length', () {
      final a = samplePlan();
      final b = copyPlan(a);
      (b['drills'] as List)[0]['duration_mins'] = 25;
      b['session_objective'] = 'Something else';
      final c = diffPlans(a, b);
      expect(c.list, ['Focus', 'Target ball']);
      expect(c.changed['drills.0'], 20);
      expect(c.has('warm_up'), isFalse);
      // Pictures don't count as a change.
      final d = copyPlan(a);
      (d['warm_up'] as Map)['game_image'] = 'x.png';
      expect(diffPlans(a, d).list, isEmpty);
    });

    test('setPlanPath and sectionName', () {
      final p = samplePlan();
      setPlanPath(p, 'drills.0.coaching_points.0', 'Strike through');
      setPlanPath(p, 'warm_up.description', 'New');
      setPlanPath(p, 'missing.x', 'nothing');
      expect(p['drills'][0]['coaching_points'][0], 'Strike through');
      expect(p['warm_up']['description'], 'New');
      expect(p.containsKey('missing'), isFalse);
      expect(sectionName(p, 'drills.0'), 'Target ball');
      expect(sectionName(p, 'cool_down'), 'Cool down');
    });

    test('planBar: buttons and the save pill', () {
      var b = planBar(
          planId: null,
          isDraft: true,
          isOwn: true,
          isShared: false,
          isDirty: false);
      expect([b.save, b.share, b.remove, b.pill],
          [true, false, false, 'Not saved']);
      b = planBar(
          planId: 4,
          isDraft: false,
          isOwn: true,
          isShared: false,
          isDirty: false);
      expect(
          [b.save, b.share, b.remove, b.pill], [false, true, false, 'Saved']);
      b = planBar(
          planId: 4,
          isDraft: false,
          isOwn: true,
          isShared: true,
          isDirty: true);
      expect([b.save, b.share, b.remove, b.pill],
          [true, false, false, 'Unsaved changes']);
      b = planBar(
          planId: 4,
          isDraft: false,
          isOwn: false,
          isShared: true,
          isDirty: false);
      expect([b.save, b.share, b.remove, b.pill], [false, false, false, null]);
    });

    test('steppers and dates', () {
      expect(adjustPlayers(null, 1), 15);
      expect(adjustPlayers(null, -1), isNull);
      expect(adjustPlayers(4, -1), isNull);
      expect(adjustPlayers(60, 1), 60);
      expect(adjustDuration(15, -5), 15);
      expect(adjustDuration(180, 5), 180);
      expect(planDate(DateTime(2026, 11, 3)), '3 Nov 2026');
      final plans = parsePlans({
        'plans': [
          {
            'plan_id': 3,
            'session_title': 'Tuesday',
            'created_at': '2026-11-03T10:00:00Z',
            'club_id': 9,
          }
        ]
      });
      expect(plans.single.clubId, 9);
      expect(plans.single.isOwn, isTrue);
    });
  });

  group('favourites page', () {
    testWidgets('AI off: list and Export Games only', (t) async {
      final api = V3OfflineFavouritesApi(answers: {
        'get': {'favourites': favs(3)}
      });
      await pump(t, V3FavouritesPage(api: api));
      expect(find.text('Game 1'), findsOneWidget);
      expect(find.text('3 of 3 picked', findRichText: true), findsOneWidget);
      expect(find.text('Export 3 games'), findsOneWidget);
      expect(find.textContaining('Build plan'), findsNothing);
      expect(find.text('My Plans'), findsNothing);
      expect(find.text('Tip: swipe a game left to remove it'), findsOneWidget);

      await t.tap(find.text('Clear'));
      await t.pumpAndSettle();
      expect(find.text('Export Games'), findsOneWidget);
      expect(find.text('NOT PICKED'), findsOneWidget);
    });

    testWidgets('AI on: Build plan, the 10 game cap and unpick', (t) async {
      final api = V3OfflineFavouritesApi(ai: true, answers: {
        'get': {'favourites': favs(11)}
      });
      await pump(t, V3FavouritesPage(api: api));
      expect(find.text('Build plan with 10 games'), findsOneWidget);
      expect(find.text('PDF'), findsOneWidget);
      expect(find.text('My Plans'), findsOneWidget);

      // Game 11 is not picked: picking it hits the cap.
      await t.scrollUntilVisible(find.text('Game 11'), 300);
      await t.tap(find.bySemanticsLabel('Pick').last);
      await t.pump();
      expect(find.text('You can pick up to 10 games'), findsOneWidget);
      await t.pumpAndSettle(const Duration(seconds: 3));

      await t.scrollUntilVisible(find.text('Game 1'), -300);
      await t.tap(find.bySemanticsLabel('Unpick').first);
      await t.pumpAndSettle();
      expect(find.text('Build plan with 9 games'), findsOneWidget);
    });

    testWidgets('swipe removes, Undo adds it back', (t) async {
      final api = V3OfflineFavouritesApi(answers: {
        'get': {'favourites': favs(2)}
      });
      await pump(t, V3FavouritesPage(api: api));
      await t.drag(find.text('Game 1'), const Offset(-500, 0));
      await t.pumpAndSettle();
      expect(find.text('Game 1'), findsNothing);
      expect(find.text('Removed "Game 1"'), findsOneWidget);
      expect(api.calls, contains('toggle:1'));
      await t.tap(find.text('Undo'));
      await t.pumpAndSettle();
      expect(find.text('Game 1'), findsOneWidget);
      expect(api.calls.where((c) => c == 'toggle:1').length, 2);
    });

    testWidgets('empty state', (t) async {
      final api = V3OfflineFavouritesApi(answers: {
        'get': {'favourites': []}
      });
      await pump(t, V3FavouritesPage(api: api));
      expect(find.text('No Favourites Yet'), findsOneWidget);
    });

    testWidgets('quick look loads the game and saves the note', (t) async {
      final api = V3OfflineFavouritesApi(answers: {
        'get': {'favourites': favs(2)},
        'get_game': {
          'game': {
            'game_id': 1,
            'game_name': 'Game 1',
            'game_setup': 'Cones in a square',
            'game_type': ['Game'],
            'game_code': ['Football'],
            'game_age': ['u10'],
          },
          'coach_note': 'Old note',
        },
        'save_coach_note': {'ok': true},
      });
      await pump(t, V3FavouritesPage(api: api));
      await t.tap(find.text('Game 1'));
      await t.pumpAndSettle();
      expect(find.text('Cones in a square'), findsOneWidget);
      expect(find.text('Export Game Card'), findsOneWidget);
      expect(find.text('Old note'), findsOneWidget);
      await t.scrollUntilVisible(find.text('Save Note'), 200,
          scrollable: find.byType(Scrollable).last);
      await t.tap(find.text('Save Note'));
      await t.pumpAndSettle();
      expect(api.bodies.last['note'], 'Old note');
      expect(find.text('Note saved ✓'), findsOneWidget);
    });
  });

  group('session plan page', () {
    testWidgets('save, then add to club', (t) async {
      final api = V3OfflineFavouritesApi(ai: true, answers: {
        'save_plan': {'plan_id': 77},
        'set_plan_club': {'ok': true, 'club_id': 5},
      });
      await pump(
          t, V3SessionPlanPage(plan: samplePlan(), isDraft: true, api: api));
      expect(find.text('Not saved'), findsOneWidget);
      await t.scrollUntilVisible(find.text('Target ball'), 300,
          scrollable: find.byType(Scrollable).first);
      expect(find.text('DRILL 1'), findsOneWidget);

      await t.tap(find.text('Save Plan'));
      await t.pumpAndSettle();
      expect(api.bodies.last['action'], 'save_plan');
      expect(find.text('Saved'), findsOneWidget);

      await t.tap(find.text('Add to Club'));
      await t.pumpAndSettle();
      expect(api.bodies.last['plan_id'], 77);
      expect(find.text('Remove from Club'), findsOneWidget);
    });

    testWidgets('a typed edit is kept and marks unsaved changes', (t) async {
      final api = V3OfflineFavouritesApi(ai: true, answers: {
        'update_plan': {'ok': true},
      });
      await pump(t, V3SessionPlanPage(plan: samplePlan(), planId: 3, api: api));
      expect(find.text('Saved'), findsOneWidget);
      await t.enterText(
          find.widgetWithText(TextField, 'Kicking session'), 'Tuesday kicking');
      await t.pumpAndSettle();
      expect(find.text('Unsaved changes'), findsOneWidget);
      await t.tap(find.text('Save Plan'));
      await t.pumpAndSettle();
      await t.tap(find.text('Update this plan'));
      await t.pumpAndSettle();
      expect(api.bodies.last['action'], 'update_plan');
      expect(api.bodies.last['plan_json']['session_title'], 'Tuesday kicking');
      expect(find.text('Saved'), findsOneWidget);
    });

    testWidgets('change one section with the voice panel, then undo',
        (t) async {
      final api = V3OfflineFavouritesApi(ai: true, answers: {
        'revise_plan': (Map<String, dynamic> b) {
          final p = copyPlan(b['existing_plan'] as Map);
          (p['drills'] as List)[0]['description'] = 'Kick off the ground';
          return FavResult(true, {'plan': p});
        },
      });
      await pump(t, V3SessionPlanPage(plan: samplePlan(), planId: 3, api: api));
      await t.scrollUntilVisible(find.text('DRILL 1'), 300,
          scrollable: find.byType(Scrollable).first);
      await t.pumpAndSettle();
      await t.tap(find.descendant(
          of: find.ancestor(
              of: find.text('DRILL 1'), matching: find.byType(Row)),
          matching: find.text('Change')));
      await t.pumpAndSettle();
      expect(find.text('Change: Target ball'), findsOneWidget);
      await t.enterText(
          find.descendant(
              of: find.byType(V3VoiceSheet), matching: find.byType(TextField)),
          'make it harder');
      await t.pump();
      await t.tap(find.byKey(const ValueKey('voice-submit')));
      await t.pumpAndSettle();
      expect(api.bodies.last['target'], 'drills.0');
      expect(api.bodies.last['feedback'], 'make it harder');
      expect(find.text('Plan updated · 1 change'), findsOneWidget);
      expect(find.text('Unsaved changes'), findsOneWidget);
      await t.scrollUntilVisible(find.text('Kick off the ground'), 300,
          scrollable: find.byType(Scrollable).first);
      await t.scrollUntilVisible(find.text('Undo'), -300,
          scrollable: find.byType(Scrollable).first);

      await t.tap(find.text('Undo'));
      await t.pumpAndSettle();
      await t.scrollUntilVisible(find.text('Kick to the target'), 300,
          scrollable: find.byType(Scrollable).first);
      expect(find.text('Saved'), findsOneWidget);
    });
  });

  group('my plans', () {
    testWidgets('lists mine and club plans', (t) async {
      final api = V3OfflineFavouritesApi(ai: true, answers: {
        'get_user_plans': {
          'plans': [
            {
              'plan_id': 1,
              'session_title': 'Tuesday',
              'created_at': '2026-11-03T10:00:00Z',
              'club_id': 4
            }
          ]
        },
        'get_club_plans': {
          'plans': [
            {
              'plan_id': 2,
              'session_title': 'Shared one',
              'created_at': '2026-11-01T10:00:00Z',
              'is_own': false,
              'created_by': 'Mary'
            }
          ]
        },
      });
      await pump(t, V3MyPlansPage(api: api, eventId: 9));
      expect(find.text('Tuesday'), findsOneWidget);
      expect(find.text('CLUB PLAN'), findsOneWidget);
      expect(find.text('3 Nov 2026'), findsOneWidget);
      expect(find.text('Attach to Event'), findsOneWidget);
      expect(find.text('Build New Plan'), findsOneWidget);
      await t.tap(find.text('Club Plans'));
      await t.pumpAndSettle();
      expect(find.text('From Mary'), findsOneWidget);
      expect(find.text('Shared one'), findsOneWidget);
    });

    testWidgets('empty lists', (t) async {
      await pump(t, V3MyPlansPage(api: V3OfflineFavouritesApi()));
      expect(find.text('No saved plans yet'), findsOneWidget);
    });
  });
}
