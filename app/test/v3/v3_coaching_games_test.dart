import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:coach_smart_v2/v3/coaching/v3_coaching_games.dart';
import 'package:coach_smart_v2/v3/coaching/v3_coaching_games_models.dart';
import 'package:coach_smart_v2/v3/coaching/v3_coaching_page.dart';
import 'package:coach_smart_v2/v3/coaching/v3_plan_draft.dart';
import 'package:coach_smart_v2/v3/games/v3_games.dart';
import 'package:coach_smart_v2/v3/resources/v3_resources_models.dart';

Map<String, dynamic> g(int id, String name, List<String> types,
        {List<String> ages = const ['u8'],
        List<String> codes = const ['Football'],
        List<String> skills = const [],
        String how = 'Play.',
        int? clubId}) =>
    {
      'game_id': id,
      'game_name': name,
      'game_age': ages,
      'game_code': codes,
      'game_type': types,
      'game_skill': skills,
      'game_how_to_play': how,
      'club_id': clubId,
    };

List<Map<String, dynamic>> games() => [
      g(1, 'Bulldog', ['Game'], skills: ['Agility']),
      g(2, 'Jog and stretch', ['Warmup']),
      g(3, 'Hand pass drill', ['Drill'], codes: ['Hurling']),
      g(4, 'Solo skill', ['Skills']),
      g(5, 'Coach video', ['Video']),
      g(6, 'Empty game', ['Game'], how: ''), // no content: hidden
      g(7, 'Older game', ['Games'], ages: ['u12']),
      g(8, 'Club game', ['Game'], clubId: 7),
    ];

Map<String, dynamic> data({bool pathway = true, int pathways = 1}) => {
      'club_id': 7,
      'club_name': 'Clontarf',
      'games': games(),
      'favourites': [2],
      'pathways': [
        if (pathway)
          {
            'pathway_types': {'pathway_type_id': 1, 'pathway_name': 'TURAS'}
          },
        if (pathway && pathways > 1)
          {
            'pathway_types': {'pathway_type_id': 2, 'pathway_name': 'Camogie'}
          },
      ],
      'stages': [
        {
          'pathway_type_id': 1,
          'pathway_stage_id': 10,
          'pathway_stage': 'Learning to Use the Ball Well',
          'pathway_stage_desc': 'Fun first',
          'pathway_ages': ['u7', 'u8', 'u9'],
          'pathway_display_seq': 2,
        },
        {
          'pathway_type_id': 1,
          'pathway_stage_id': 9,
          'pathway_stage': 'Learning to Master the Ball',
          'pathway_ages': ['u4', 'u5', 'u6'],
          'pathway_display_seq': 1,
        },
        {
          'pathway_type_id': 2,
          'pathway_stage_id': 20,
          'pathway_stage': 'First touch',
          'pathway_ages': ['u12'],
          'pathway_display_seq': 1,
        },
      ],
      'details': [
        {
          'pathway_stage_id': 10,
          'pathway_stage_details_id': 100,
          'detail_heading': 'Stage 2 overview',
          'detail_subheading': 'What to expect',
          'image_link': '',
          'detail_category': 'Player Pathways',
          'event_codes': null,
        },
        {
          'pathway_stage_id': 10,
          'pathway_stage_details_id': 101,
          'detail_heading': 'Hurling session',
          'detail_category': 'Sample Sessions',
          'event_codes': {'event_code': 'Hurling'},
        },
      ],
    };

void phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(390 * 3, 1600 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
}

Finder inCard(String game, Finder what) => find.descendant(
    of: find.ancestor(of: find.text(game), matching: find.byType(V3GameCard)),
    matching: what);

void main() {
  final all = parseGames(games());
  List<String> names(Iterable<V3Game> l) => [for (final x in l) x.name];

  group('search', () {
    test('matches name, skills, type and code; every word must match', () {
      final bulldog = all[0], drill = all[2];
      expect(matchesSearch(bulldog, ''), isTrue);
      expect(matchesSearch(bulldog, '  '), isTrue);
      expect(matchesSearch(bulldog, 'BULL'), isTrue);
      expect(matchesSearch(bulldog, 'agility'), isTrue); // skill
      expect(matchesSearch(bulldog, 'football'), isTrue); // code
      expect(matchesSearch(bulldog, 'hurling'), isFalse);
      expect(matchesSearch(drill, 'drill hurling'), isTrue);
      expect(matchesSearch(drill, 'drill football'), isFalse);
      expect(matchesSearch(all[1], 'warm-up'), isTrue);
      expect(matchesSearch(all[1], 'warmup'), isTrue);
      expect(matchesSearch(all[4], 'video'), isTrue); // type
    });
  });

  group('filterGames', () {
    test('hides games with nothing to show', () {
      final out = filterGames(all, const GamesFilter(), {});
      expect(out.length, 7);
      expect(names(out), isNot(contains('Empty game')));
    });

    test('saved, ages, code and kind combine', () {
      expect(names(filterGames(all, const GamesFilter(saved: true), {2, 6})),
          ['Jog and stretch']);
      expect(
          names(filterGames(all, const GamesFilter(ages: ['u12', 'u13']), {})),
          ['Older game']);
      expect(names(filterGames(all, const GamesFilter(code: 'Hurling'), {})),
          ['Hand pass drill']);
      expect(
          names(filterGames(all, const GamesFilter(kind: GameKind.game), {})),
          ['Bulldog', 'Older game', 'Club game']);
      expect(
          filterGames(
              all,
              const GamesFilter(
                  query: 'bulldog', code: 'Hurling', kind: GameKind.game),
              {}),
          isEmpty);
    });

    test('hasFilters ignores the search box', () {
      expect(const GamesFilter(query: 'x').hasFilters, isFalse);
      expect(const GamesFilter(query: 'x').isEmpty, isFalse);
      expect(const GamesFilter(saved: true).hasFilters, isTrue);
      expect(const GamesFilter().isEmpty, isTrue);
    });
  });

  group('sections and options', () {
    test('sections in list order, empty ones left out', () {
      final s = coachingSections(filterGames(all, const GamesFilter(), {}));
      expect([for (final (k, _) in s) coachingKindLabel(k)],
          ['Warm-ups', 'Drills', 'Games', 'Skills', 'Videos']);
      final only = coachingSections(all, only: GameKind.drill);
      expect(only.length, 1);
      expect(names(only.first.$2), ['Hand pass drill']);
    });

    test('codes, kinds and ages on offer', () {
      expect(gameCodes(all), ['Football', 'Hurling']);
      expect(gameCodes(all, ['Camogie']), ['Camogie', 'Football', 'Hurling']);
      expect(gameKinds(all), kCoachingKinds);
      expect(gameKinds([all[2]]), [GameKind.drill]);
      expect(gameAges(all), ['u8', 'u12']);
      expect(ageLabel('u8'), 'U8');
    });

    test('stages are numbered by sequence, else by position', () {
      const p = Pathway(1, 'TURAS');
      final s = coachingStages(p, const [
        PathwayStage(id: 1, name: 'A'),
        PathwayStage(id: 2, name: 'B', seq: 5),
      ]);
      expect([for (final x in s) x.label], ['Stage 1', 'Stage 5']);
    });
  });

  group('wording', () {
    test('plan bar', () {
      expect(planBarText(1, 10), '1 game in your plan · 10 min');
      expect(planBarText(3, 45), '3 games in your plan · 45 min');
      expect(pickDoneText(2), 'Done · 2 games in your plan');
    });

    test('empty states', () {
      expect(emptyText(all, const GamesFilter(saved: true), {}), kNoSavedText);
      expect(
          emptyText(all, const GamesFilter(saved: true, code: 'Hurling'), {2}),
          kNoMatchText);
      expect(emptyText(all, const GamesFilter(query: 'zzz'), {}), kNoMatchText);
      expect(emptyText(const [], const GamesFilter(), {}), 'No games yet.');
    });
  });

  testWidgets('search, Saved, + to the plan and the plan bar', (tester) async {
    phone(tester);
    final draft = V3PlanDraft(persist: false);
    var opened = 0;
    await tester.pumpWidget(MaterialApp(
        home: V3CoachingPage(
            testData: data(), draft: draft, onOpenPlan: (_) => opened++)));
    await tester.pumpAndSettle();

    expect(find.text('Coaching'), findsOneWidget);
    expect(find.text('Plans'), findsOneWidget);
    expect(find.text('WARM-UPS'), findsOneWidget);
    expect(find.text('DRILLS'), findsOneWidget);
    expect(find.text('Bulldog'), findsOneWidget);
    expect(find.text('Older game'), findsOneWidget);
    expect(find.text('Empty game'), findsNothing);
    expect(find.text('Clontarf'), findsOneWidget); // club tag
    expect(find.byKey(const ValueKey('plan-bar')), findsNothing);
    // Skills have no heart and no +.
    expect(inCard('Solo skill', find.byType(IconButton)), findsNothing);

    // Search as you type.
    await tester.enterText(find.byType(TextField), 'hurling');
    await tester.pumpAndSettle();
    expect(find.text('Hand pass drill'), findsOneWidget);
    expect(find.text('Bulldog'), findsNothing);
    await tester.enterText(find.byType(TextField), 'zzz');
    await tester.pumpAndSettle();
    expect(find.text(kNoMatchText), findsOneWidget);
    await tester.tap(find.text('Clear filters'));
    await tester.pumpAndSettle();
    expect(find.text('Bulldog'), findsOneWidget);

    // Saved is a filter.
    await tester.tap(find.byKey(const ValueKey('pill-saved')));
    await tester.pumpAndSettle();
    expect(find.text('Jog and stretch'), findsOneWidget);
    expect(find.text('Bulldog'), findsNothing);
    // Un-heart the only saved game: the hint shows.
    await tester.tap(inCard('Jog and stretch', find.byIcon(Icons.favorite)));
    await tester.pumpAndSettle();
    expect(find.text(kNoSavedText), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('pill-all')));
    await tester.pumpAndSettle();
    expect(find.text('Bulldog'), findsOneWidget);

    // + adds to the plan, the bar appears; tap again takes it out.
    await tester.tap(inCard('Bulldog', find.byTooltip('Add to plan')));
    await tester.pumpAndSettle();
    expect(draft.contains(1), isTrue);
    expect(find.text('1 game in your plan · 10 min'), findsOneWidget);
    expect(inCard('Bulldog', find.byIcon(Icons.check)), findsOneWidget);
    await tester.tap(inCard('Club game', find.byTooltip('Add to plan')));
    await tester.pumpAndSettle();
    expect(find.text('2 games in your plan · 20 min'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('plan-bar')));
    expect(opened, 1);
    await tester.tap(inCard('Club game', find.byTooltip('Remove from plan')));
    await tester.pumpAndSettle();
    expect(draft.count, 1);

    // The game page has the same switch.
    await tester.tap(find.text('Jog and stretch'));
    await tester.pumpAndSettle();
    expect(find.text('PDF Card'), findsOneWidget);
    await tester.tap(find.text('Add to plan'));
    await tester.pumpAndSettle();
    expect(find.text('In your plan ✓'), findsOneWidget);
    expect(draft.contains(2), isTrue);
    await tester.tap(find.byIcon(Icons.chevron_left).last);
    await tester.pumpAndSettle();
    expect(find.text('2 games in your plan · 20 min'), findsOneWidget);

    // Plans half: a placeholder until one is passed in.
    await tester.tap(find.text('Plans'));
    await tester.pumpAndSettle();
    expect(find.text('Plans are coming soon'), findsOneWidget);
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('a full plan says so', (tester) async {
    phone(tester);
    final draft = V3PlanDraft(persist: false);
    for (var i = 100; i < 100 + kPlanMaxGames; i++) {
      draft.add(i, 'Game $i');
    }
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: V3CoachingGames(testData: data(), draft: draft))));
    await tester.pumpAndSettle();
    await tester.tap(inCard('Bulldog', find.byTooltip('Add to plan')));
    await tester.pump();
    expect(find.text(kPlanFullText), findsOneWidget);
    expect(draft.contains(1), isFalse);
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('Stage, Code and Type sheets; stage content shows',
      (tester) async {
    phone(tester);
    await tester.pumpWidget(MaterialApp(
        home: V3CoachingPage(
            testData: data(), draft: V3PlanDraft(persist: false))));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('pill-stage')));
    await tester.pumpAndSettle();
    expect(find.text('All stages'), findsOneWidget);
    expect(find.text('TURAS'), findsNothing); // one pathway: no grouping
    await tester.tap(find.text('Stage 2'));
    await tester.pumpAndSettle();
    // The pill shows the pick; the stage's content sits above its games.
    expect(
        find.descendant(
            of: find.byKey(const ValueKey('pill-stage')),
            matching: find.text('Stage 2')),
        findsOneWidget);
    expect(find.text('Learning to Use the Ball Well'), findsOneWidget);
    expect(find.text('PLAYER PATHWAYS'), findsOneWidget);
    expect(find.text('Stage 2 overview'), findsOneWidget);
    expect(find.text('SAMPLE SESSIONS'), findsOneWidget);
    expect(find.text('Bulldog'), findsOneWidget);
    expect(find.text('Older game'), findsNothing); // u12

    await tester.ensureVisible(find.byKey(const ValueKey('pill-type')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('pill-type')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Drills'));
    await tester.pumpAndSettle();
    expect(find.text('Bulldog'), findsNothing);
    expect(find.text('Hand pass drill'), findsOneWidget);
    expect(find.text('PLAYER PATHWAYS'), findsOneWidget);

    await tester.ensureVisible(find.byKey(const ValueKey('pill-code')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('pill-code')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Football'));
    await tester.pumpAndSettle();
    expect(find.text('Hand pass drill'), findsNothing);
    expect(find.text('Hurling session'), findsNothing);
    expect(find.text('Stage 2 overview'), findsOneWidget); // for every code

    await tester.ensureVisible(find.byKey(const ValueKey('pill-all')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('pill-all')));
    await tester.pumpAndSettle();
    expect(find.text('Older game'), findsOneWidget);
    expect(find.text('PLAYER PATHWAYS'), findsNothing);
  });

  testWidgets('two pathways: the Stage sheet groups by pathway',
      (tester) async {
    phone(tester);
    await tester.pumpWidget(MaterialApp(
        home: V3CoachingPage(
            testData: data(pathways: 2), draft: V3PlanDraft(persist: false))));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('pill-stage')));
    await tester.pumpAndSettle();
    expect(find.text('TURAS'), findsOneWidget);
    expect(find.text('CAMOGIE'), findsOneWidget);
    await tester.tap(find.text('First touch · U12'));
    await tester.pumpAndSettle();
    expect(find.text('Older game'), findsOneWidget);
    expect(find.text('Bulldog'), findsNothing);
  });

  testWidgets('no pathway: Age in place of Stage', (tester) async {
    phone(tester);
    await tester.pumpWidget(MaterialApp(
        home: V3CoachingPage(
            testData: data(pathway: false),
            draft: V3PlanDraft(persist: false))));
    await tester.pumpAndSettle();
    expect(find.text('Age'), findsOneWidget);
    expect(find.text('Stage'), findsNothing);
    await tester.tap(find.byKey(const ValueKey('pill-stage')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('U12'));
    await tester.pumpAndSettle();
    expect(find.text('Older game'), findsOneWidget);
    expect(find.text('Bulldog'), findsNothing);
  });

  testWidgets('pickMode: Add games, no switch, Done pops', (tester) async {
    phone(tester);
    final draft = V3PlanDraft(persist: false);
    await tester.pumpWidget(MaterialApp(
        home: Builder(
            builder: (context) => Scaffold(
                body: TextButton(
                    onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(
                            builder: (_) => V3CoachingPage(
                                pickMode: true,
                                testData: data(),
                                draft: draft))),
                    child: const Text('open'))))));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('Add games'), findsOneWidget);
    expect(find.text('Coaching'), findsNothing);
    expect(find.text('Plans'), findsNothing);
    expect(find.text('Done · 0 games in your plan'), findsOneWidget);
    await tester.tap(inCard('Bulldog', find.byTooltip('Add to plan')));
    await tester.pumpAndSettle();
    expect(find.text('Done · 1 game in your plan'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('plan-bar')));
    await tester.pumpAndSettle();
    expect(find.text('Add games'), findsNothing);
    expect(find.text('open'), findsOneWidget);
    expect(draft.contains(1), isTrue);
  });
}
