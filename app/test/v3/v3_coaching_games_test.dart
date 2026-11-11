import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:coach_smart_v2/v3/coaching/v3_coaching_games.dart';
import 'package:coach_smart_v2/v3/coaching/v3_coaching_games_models.dart';
import 'package:coach_smart_v2/v3/coaching/v3_coaching_games_widgets.dart';
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
    of: find.ancestor(
        of: find.text(game), matching: find.byType(CoachingGameCard)),
    matching: what);

Future<void> pumpPage(WidgetTester tester, Map<String, dynamic> testData,
    {V3PlanDraft? draft, void Function(BuildContext)? onOpenPlan}) async {
  phone(tester);
  await tester.pumpWidget(MaterialApp(
      home: V3CoachingPage(
          testData: testData,
          draft: draft ?? V3PlanDraft(persist: false),
          onOpenPlan: onOpenPlan)));
  await tester.pumpAndSettle();
}

const stage1 = ValueKey('stage-9');
const stage2 = ValueKey('stage-10');
const other = ValueKey('stage-other');

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

  group('pathway', () {
    const p = Pathway(1, 'TURAS');
    final stages = coachingStages(p, const [
      PathwayStage(id: 9, name: 'Master', ages: ['u4', 'u5', 'u6'], seq: 1),
      PathwayStage(id: 10, name: 'Use', ages: ['u7', 'u8', 'u9'], seq: 2),
      PathwayStage(id: 11, name: 'Play', ages: ['u8', 'u12'], seq: 3),
    ]);

    test('stage title: the words, not "Stage 1"', () {
      const named = PathwayStage(id: 1, name: 'Stage 1', desc: 'Master it');
      expect(stageTitle(named), 'Master it');
      expect(stageBlurb(named), '');
      const worded = PathwayStage(id: 1, name: 'Master it', desc: 'Fun first');
      expect(stageTitle(worded), 'Master it');
      expect(stageBlurb(worded), 'Fun first');
      expect(stageTitle(const PathwayStage(id: 1, name: 'Stage 1')), 'Stage 1');
      expect(
          stageHeading(
              const PathwayStage(id: 1, name: 'Master it', ages: ['u4', 'u5'])),
          'Master it · U4 to U5');
    });

    test('ages and the card line', () {
      expect(agesRange(['u4', 'u5', 'u6']), 'U4 to U6');
      expect(agesRange(['u11', 'u10']), 'U10 to U11');
      expect(agesRange(['u8']), 'U8');
      expect(agesRange(['u8', 'u10']), 'U8, U10');
      expect(agesRange([]), '');
      expect(stageCardLine(['u4', 'u5', 'u6'], 14), 'U4 to U6 · 14 games');
      expect(stageCardLine([], 1), '1 game');
      expect(pathwayHeading('TURAS'), 'TURAS pathway');
      expect(pathwayHeading('Camogie Pathway'), 'Camogie Pathway');
    });

    test('games in a stage follow Code and Type; the rest are Other', () {
      expect(stageGames(all, stages[0]), isEmpty);
      expect(stageGames(all, stages[1]).length, 6);
      expect(names(stageGames(all, stages[1], code: 'Hurling')),
          ['Hand pass drill']);
      expect(names(stageGames(all, stages[1], kind: GameKind.game)),
          ['Bulldog', 'Club game']);
      expect(names(otherGames(all, stages.sublist(0, 2))), ['Older game']);
      expect(otherGames(all, stages.sublist(0, 2), code: 'Hurling'), isEmpty);
      expect(otherGames(all, stages), isEmpty);
    });

    test('stage tag and results count', () {
      expect(stageTag(all[6], stages.sublist(0, 2)), '');
      expect(stageTag(all[0], stages.sublist(0, 2)), 'Stage 2');
      expect(stageTag(all[0], stages), 'Stages 2, 3');
      expect(resultsCountText(3, saved: true), '3 saved games');
      expect(resultsCountText(1, saved: true), '1 saved game');
      expect(resultsCountText(5, saved: false), '5 games');
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

  testWidgets('landing: the pathway, its stages and their counts',
      (tester) async {
    await pumpPage(tester, data());

    expect(find.text('Coaching'), findsOneWidget);
    expect(find.text('Pathway'), findsOneWidget); // the switch
    expect(find.text('Games'), findsNothing);
    expect(find.text('Plans'), findsOneWidget);
    expect(find.text('TURAS PATHWAY'), findsOneWidget);
    // Saved, Code and Type only: the stage cards replace the Stage pill.
    expect(find.byKey(const ValueKey('pill-saved')), findsOneWidget);
    expect(find.byKey(const ValueKey('pill-code')), findsOneWidget);
    expect(find.byKey(const ValueKey('pill-type')), findsOneWidget);
    expect(find.byKey(const ValueKey('pill-all')), findsNothing);
    expect(find.byKey(const ValueKey('pill-age')), findsNothing);
    expect(find.text('Stage'), findsNothing);

    // Stages in order, each with its ages and games; no games listed yet.
    expect(find.text('Learning to Master the Ball'), findsOneWidget);
    expect(find.text('U4 to U6 · 0 games'), findsOneWidget);
    expect(find.text('Learning to Use the Ball Well'), findsOneWidget);
    expect(find.text('U7 to U9 · 6 games'), findsOneWidget);
    expect(
        tester.getTopLeft(find.byKey(stage1)).dy <
            tester.getTopLeft(find.byKey(stage2)).dy,
        isTrue);
    expect(tester.getSize(find.byKey(stage2)).height, greaterThanOrEqualTo(64));
    expect(find.descendant(of: find.byKey(stage2), matching: find.text('2')),
        findsOneWidget);
    expect(find.byType(CoachingGameCard), findsNothing);
    expect(find.text(kPathwayLinkLabel), findsOneWidget);

    // The u12 game is in no stage: it stays reachable.
    expect(
        find.descendant(
            of: find.byKey(other), matching: find.text('Other games')),
        findsOneWidget);
    expect(
        find.descendant(of: find.byKey(other), matching: find.text('1 game')),
        findsOneWidget);

    // The counts follow Code and Type.
    await tester.tap(find.byKey(const ValueKey('pill-code')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hurling'));
    await tester.pumpAndSettle();
    expect(find.text('U7 to U9 · 1 game'), findsOneWidget);
    expect(
        find.descendant(of: find.byKey(other), matching: find.text('0 games')),
        findsOneWidget);

    await tester.tap(find.byKey(other));
    await tester.pumpAndSettle();
    expect(find.text('Other games'), findsOneWidget); // the page title
    expect(find.text(kNoMatchText), findsOneWidget);
    await tester.tap(find.text('Clear filters'));
    await tester.pumpAndSettle();
    expect(find.text('Older game'), findsOneWidget);
    expect(find.text('Bulldog'), findsNothing);
  });

  testWidgets('a stage: its content, its games, + to the plan, the plan bar',
      (tester) async {
    final draft = V3PlanDraft(persist: false);
    var opened = 0;
    await pumpPage(tester, data(), draft: draft, onOpenPlan: (_) => opened++);

    await tester.tap(find.byKey(stage2));
    await tester.pumpAndSettle();
    expect(find.text('Stage 2'), findsOneWidget);
    expect(
        find.text('Learning to Use the Ball Well · U7 to U9'), findsOneWidget);
    expect(find.text('Fun first'), findsOneWidget);
    expect(find.text('Pathway'), findsNothing); // a pushed page
    // Pathway content first, then the games by kind.
    expect(find.text('PLAYER PATHWAYS'), findsOneWidget);
    expect(find.text('Stage 2 overview'), findsOneWidget);
    expect(find.text('SAMPLE SESSIONS'), findsOneWidget);
    expect(find.text('Hurling session'), findsOneWidget);
    expect(find.text('WARM-UPS'), findsOneWidget);
    expect(find.text('DRILLS'), findsOneWidget);
    expect(find.text('VIDEOS'), findsOneWidget);
    expect(find.text('Bulldog'), findsOneWidget);
    expect(find.text('Clontarf'), findsOneWidget); // club tag
    expect(find.text('Older game'), findsNothing); // u12
    expect(find.text('Empty game'), findsNothing);
    expect(
        tester.getTopLeft(find.text('Stage 2 overview')).dy <
            tester.getTopLeft(find.text('Bulldog')).dy,
        isTrue);
    // Skills have no heart and no +.
    expect(inCard('Solo skill', find.byType(IconButton)), findsNothing);
    expect(find.byKey(const ValueKey('plan-bar')), findsNothing);

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

    // The heart saves.
    await tester.tap(inCard('Bulldog', find.byIcon(Icons.favorite_border)));
    await tester.pumpAndSettle();
    expect(inCard('Bulldog', find.byIcon(Icons.favorite)), findsOneWidget);

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

    // Back on the landing view the bar is still there.
    await tester.tap(find.byIcon(Icons.chevron_left).last);
    await tester.pumpAndSettle();
    expect(find.text('TURAS PATHWAY'), findsOneWidget);
    expect(find.text('2 games in your plan · 20 min'), findsOneWidget);

    // Plans half: a placeholder until one is passed in.
    await tester.tap(find.text('Plans'));
    await tester.pumpAndSettle();
    expect(find.text('Plans are coming soon'), findsOneWidget);
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('a stage: Code and Type pills', (tester) async {
    await pumpPage(tester, data());
    await tester.tap(find.byKey(stage2));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('pill-type')).last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Drills'));
    await tester.pumpAndSettle();
    expect(find.text('Bulldog'), findsNothing);
    expect(find.text('Hand pass drill'), findsOneWidget);
    expect(find.text('PLAYER PATHWAYS'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('pill-code')).last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Football'));
    await tester.pumpAndSettle();
    expect(find.text('Hand pass drill'), findsNothing);
    expect(find.text('Hurling session'), findsNothing);
    expect(find.text('Stage 2 overview'), findsOneWidget); // for every code

    // The picks carry back to the landing view's counts.
    await tester.tap(find.byIcon(Icons.chevron_left).last);
    await tester.pumpAndSettle();
    expect(find.text('U7 to U9 · 0 games'), findsOneWidget);
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
    await tester.tap(find.byKey(stage2));
    await tester.pumpAndSettle();
    await tester.tap(inCard('Bulldog', find.byTooltip('Add to plan')));
    await tester.pump();
    expect(find.text(kPlanFullText), findsOneWidget);
    expect(draft.contains(1), isFalse);
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('search and Saved swap the stages for games from every stage',
      (tester) async {
    await pumpPage(tester, data());

    // Search as you type: results carry their stage.
    await tester.enterText(find.byType(TextField), 'hurling');
    await tester.pumpAndSettle();
    expect(find.byKey(stage2), findsNothing);
    expect(find.text('TURAS PATHWAY'), findsNothing);
    expect(find.text('1 game'), findsOneWidget);
    expect(find.text('Hand pass drill'), findsOneWidget);
    expect(inCard('Hand pass drill', find.text('Stage 2')), findsOneWidget);
    expect(find.text('Bulldog'), findsNothing);

    await tester.enterText(find.byType(TextField), 'game');
    await tester.pumpAndSettle();
    expect(find.text('3 games'), findsOneWidget);
    expect(inCard('Bulldog', find.text('Stage 2')), findsOneWidget);
    // In no stage: found all the same, with no stage tag.
    expect(find.text('Older game'), findsOneWidget);
    expect(inCard('Older game', find.textContaining('Stage')), findsNothing);
    // Type applies to the results too.
    await tester.tap(find.byKey(const ValueKey('pill-type')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Warm-ups'));
    await tester.pumpAndSettle();
    expect(find.text(kNoMatchText), findsOneWidget);
    await tester.tap(find.text('Clear filters'));
    await tester.pumpAndSettle();
    // Clearing brings the stages back.
    expect(find.byKey(stage2), findsOneWidget);
    expect(find.text('U7 to U9 · 6 games'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'zzz');
    await tester.pumpAndSettle();
    expect(find.text(kNoMatchText), findsOneWidget);
    await tester.tap(find.byTooltip('Clear search'));
    await tester.pumpAndSettle();
    expect(find.byKey(stage2), findsOneWidget);

    // Saved is a filter across stages.
    await tester.tap(find.byKey(const ValueKey('pill-saved')));
    await tester.pumpAndSettle();
    expect(find.byKey(stage2), findsNothing);
    expect(find.text('1 saved game'), findsOneWidget);
    expect(inCard('Jog and stretch', find.text('Stage 2')), findsOneWidget);
    expect(find.text('Bulldog'), findsNothing);
    // Un-heart the only saved game: the hint shows.
    await tester.tap(inCard('Jog and stretch', find.byIcon(Icons.favorite)));
    await tester.pumpAndSettle();
    expect(find.text(kNoSavedText), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('pill-saved')));
    await tester.pumpAndSettle();
    expect(find.byKey(stage2), findsOneWidget);
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('two pathways: stages grouped under each pathway',
      (tester) async {
    await pumpPage(tester, data(pathways: 2));
    expect(find.text('TURAS PATHWAY'), findsOneWidget);
    expect(find.text('CAMOGIE PATHWAY'), findsOneWidget);
    expect(
        tester.getTopLeft(find.text('CAMOGIE PATHWAY')).dy <
            tester.getTopLeft(find.byKey(const ValueKey('stage-20'))).dy,
        isTrue);
    expect(find.text('U12 · 1 game'), findsOneWidget);
    expect(find.byKey(other), findsNothing); // every game is in a stage
    await tester.tap(find.text('First touch'));
    await tester.pumpAndSettle();
    expect(find.text('Stage 1'), findsOneWidget);
    expect(find.text('First touch · U12'), findsOneWidget);
    expect(find.text('Older game'), findsOneWidget);
    expect(find.text('Bulldog'), findsNothing);
  });

  testWidgets('no pathway: the flat games list, with Age', (tester) async {
    final draft = V3PlanDraft(persist: false);
    await pumpPage(tester, data(pathway: false), draft: draft);
    expect(
        find.descendant(
            of: find.byKey(const ValueKey('coaching-tab-0')),
            matching: find.text('Games')),
        findsOneWidget);
    expect(find.text('Pathway'), findsNothing);
    expect(find.byKey(const ValueKey('pill-all')), findsOneWidget);
    expect(find.text('Age'), findsOneWidget);
    expect(find.text('WARM-UPS'), findsOneWidget);
    expect(find.text('DRILLS'), findsOneWidget);
    expect(find.text('Bulldog'), findsOneWidget);
    expect(find.text('Older game'), findsOneWidget);
    expect(find.text('Empty game'), findsNothing);
    expect(find.textContaining('Stage'), findsNothing);
    expect(find.byKey(const ValueKey('results-count')), findsNothing);

    await tester.tap(find.byKey(const ValueKey('pill-age')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('U12'));
    await tester.pumpAndSettle();
    expect(find.text('Older game'), findsOneWidget);
    expect(find.text('Bulldog'), findsNothing);
    await tester.tap(find.byKey(const ValueKey('pill-all')));
    await tester.pumpAndSettle();
    expect(find.text('Bulldog'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'hurling');
    await tester.pumpAndSettle();
    expect(find.text('Hand pass drill'), findsOneWidget);
    expect(find.text('Bulldog'), findsNothing);
    await tester.enterText(find.byType(TextField), '');
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('pill-saved')));
    await tester.pumpAndSettle();
    expect(find.text('Jog and stretch'), findsOneWidget);
    expect(find.text('Bulldog'), findsNothing);
    await tester.tap(find.byKey(const ValueKey('pill-saved')));
    await tester.pumpAndSettle();

    await tester.tap(inCard('Bulldog', find.byTooltip('Add to plan')));
    await tester.pumpAndSettle();
    expect(draft.contains(1), isTrue);
    expect(find.text('1 game in your plan · 10 min'), findsOneWidget);
  });

  Future<void> openPicker(WidgetTester tester, V3PlanDraft draft,
      {bool pathway = true}) async {
    phone(tester);
    await tester.pumpWidget(MaterialApp(
        home: Builder(
            builder: (context) => Scaffold(
                body: TextButton(
                    onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(
                            builder: (_) => V3CoachingPage(
                                pickMode: true,
                                testData: data(pathway: pathway),
                                draft: draft))),
                    child: const Text('open'))))));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets(
      'pickMode: Add games, no switch, Done on a stage goes all the '
      'way back', (tester) async {
    final draft = V3PlanDraft(persist: false);
    await openPicker(tester, draft);
    expect(find.text('Add games'), findsOneWidget);
    expect(find.text('Coaching'), findsNothing);
    expect(find.text('Plans'), findsNothing);
    expect(find.text('Pathway'), findsNothing);
    expect(find.text('Done · 0 games in your plan'), findsOneWidget);

    await tester.tap(find.byKey(stage2));
    await tester.pumpAndSettle();
    await tester.tap(inCard('Bulldog', find.byTooltip('Add to plan')));
    await tester.pumpAndSettle();
    expect(find.text('Done · 1 game in your plan'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('plan-bar')));
    await tester.pumpAndSettle();
    expect(find.text('Stage 2'), findsNothing);
    expect(find.text('Add games'), findsNothing);
    expect(find.text('open'), findsOneWidget);
    expect(draft.contains(1), isTrue);
  });

  testWidgets('pickMode: Done on the landing view and on the flat list',
      (tester) async {
    final draft = V3PlanDraft(persist: false);
    await openPicker(tester, draft);
    await tester.tap(find.byKey(const ValueKey('plan-bar')));
    await tester.pumpAndSettle();
    expect(find.text('Add games'), findsNothing);
    expect(find.text('open'), findsOneWidget);

    await openPicker(tester, draft, pathway: false);
    expect(find.text('Add games'), findsOneWidget);
    await tester.tap(inCard('Bulldog', find.byTooltip('Add to plan')));
    await tester.pumpAndSettle();
    expect(find.text('Done · 1 game in your plan'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('plan-bar')));
    await tester.pumpAndSettle();
    expect(find.text('open'), findsOneWidget);
    expect(draft.contains(1), isTrue);
  });
}
