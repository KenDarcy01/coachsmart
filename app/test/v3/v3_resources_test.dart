import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:coach_smart_v2/v3/games/v3_games.dart';
import 'package:coach_smart_v2/v3/resources/v3_resources_models.dart';
import 'package:coach_smart_v2/v3/resources/v3_resources_page.dart';

Map<String, dynamic> g(int id, String name, List<String> types,
        {List<String> ages = const ['u8'],
        List<String> codes = const ['Football'],
        String how = 'Play.',
        int? clubId}) =>
    {
      'game_id': id,
      'game_name': name,
      'game_age': ages,
      'game_code': codes,
      'game_type': types,
      'game_skill': <String>[],
      'game_how_to_play': how,
      'club_id': clubId,
    };

List<Map<String, dynamic>> games() => [
      g(1, 'Bulldog', ['Game']),
      g(2, 'Jog and stretch', ['Warmup']),
      g(3, 'Hand pass drill', ['Drill'], codes: ['Hurling']),
      g(4, 'Solo skill', ['Skills']),
      g(5, 'Coach video', ['Video']),
      g(6, 'Empty game', ['Game'], how: ''), // no content: hidden
      g(7, 'Older game', ['Games'], ages: ['u12']),
      g(8, 'Club game', ['Game'], clubId: 7),
    ];

Map<String, dynamic> data({bool pathway = true}) => {
      'club_id': 7,
      'club_name': 'Clontarf',
      'games': games(),
      'favourites': [2],
      'pathways': pathway
          ? [
              {
                'pathway_types': {'pathway_type_id': 1, 'pathway_name': 'TURAS'}
              }
            ]
          : [],
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

void main() {
  group('models', () {
    final all = parseGames(games());
    final stages = parseStages(data()['stages']);
    final details = parseDetails(data()['details']);

    test('pathways, stages (in order) and details parse', () {
      expect(parsePathways(data()['pathways']).single.name, 'TURAS');
      expect(stages.map((s) => s.id), [9, 10]);
      expect(stages[1].agesLabel, 'U7, U8, U9');
      expect(details[1].codeText, 'Hurling');
      expect(details[0].codeText, isNull);
    });

    test('stage counts, codes and sections', () {
      final s = stages[1];
      expect(stageResourceCount(s, all), 6); // all u8 games with content
      expect(resourceCount(6), '6 resources');
      expect(resourceCount(1), '1 resource');
      expect(stageCodes(s, details, all), ['All', 'Football', 'Hurling']);
      final sec = stageSections(s, details, all, 'All', 'All');
      expect(sec.playerPathways.length, 1);
      expect(sec.sampleSessions.length, 1);
      expect(sec.games.keys, [
        GameKind.video,
        GameKind.warmup,
        GameKind.drill,
        GameKind.game,
        GameKind.skill
      ]);
      expect(sec.games[GameKind.game]!.map((g) => g.name),
          ['Bulldog', 'Club game']);
      // Football: the hurling session and drill drop out; no-code rows stay.
      final fb = stageSections(s, details, all, 'Football', 'All');
      expect(fb.sampleSessions, isEmpty);
      expect(fb.playerPathways.length, 1);
      expect(fb.games.containsKey(GameKind.drill), isFalse);
      // Type filter keeps picture rows, shows one games section.
      final w = stageSections(s, details, all, 'All', 'Warmups');
      expect(w.games.keys, [GameKind.warmup]);
      expect(w.playerPathways.length, 1);
      expect(nextTypeFilter('Warmups', 'Warmups'), 'All');
      expect(nextTypeFilter('All', 'Drills'), 'Drills');
      expect(stageSections(stages[0], [], all, 'All', 'All').isEmpty, isTrue);
    });

    test('fallback stages and filters', () {
      final vis = visibleFallbackStages(all);
      expect(vis.map((s) => s.id), [2, 4]);
      expect(visibleFallbackStages([]).length, 6);
      final s2 = kFallbackStages[1];
      expect(fallbackStageCount(s2, all), 7);
      expect(fallbackSports(s2, all), ['All', 'Football', 'Hurling']);
      expect(fallbackTypes(s2, all), ['All', 'Drill']); // exact names
      expect(fallbackTypes(kFallbackStages[3], all), ['All', 'Games']);
      expect(fallbackFiltered(s2, all, 'Hurling', 'All').single.name,
          'Hand pass drill');
      expect(fallbackFiltered(s2, all, 'All', 'All').length, 6);
    });
  });

  testWidgets('one pathway: stages, stage page, filters and a game',
      (tester) async {
    tester.view.physicalSize = const Size(390 * 3, 1400 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester
        .pumpWidget(MaterialApp(home: V3ResourcesPage(testData: data())));
    await tester.pumpAndSettle();
    expect(find.text('Player Pathway'), findsOneWidget);
    expect(find.text('DEVELOPMENT STAGES'), findsOneWidget);
    expect(find.text('Learning to Master the Ball'), findsOneWidget);
    expect(find.text('6 resources'), findsOneWidget);
    await tester.tap(find.text('Learning to Use the Ball Well'));
    await tester.pumpAndSettle();
    expect(find.text('PLAYER PATHWAYS'), findsOneWidget);
    expect(find.text('SAMPLE SESSIONS'), findsOneWidget);
    expect(find.text('WARMUPS'), findsOneWidget);
    expect(find.text('Bulldog'), findsOneWidget);
    expect(find.text('Clontarf'), findsOneWidget); // club tag
    expect(find.text('Empty game'), findsNothing);
    // The warmup is a favourite already.
    expect(find.byIcon(Icons.favorite), findsOneWidget);
    // Type filter, then tap again for All.
    await tester.ensureVisible(find.text('Drills'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Drills'));
    await tester.pumpAndSettle();
    expect(find.text('Bulldog'), findsNothing);
    expect(find.text('Hand pass drill'), findsOneWidget);
    expect(find.text('PLAYER PATHWAYS'), findsOneWidget);
    await tester.ensureVisible(find.text('Drills'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Drills'));
    await tester.pumpAndSettle();
    expect(find.text('Bulldog'), findsOneWidget);
    // Code filter.
    await tester.tap(find.text('Hurling'));
    await tester.pumpAndSettle();
    expect(find.text('Bulldog'), findsNothing);
    expect(find.text('Hurling session'), findsOneWidget);
    await tester.tap(find.text('All').first);
    await tester.pumpAndSettle();
    // Heart a game from the list.
    await tester.tap(find.descendant(
        of: find.ancestor(
            of: find.text('Bulldog'), matching: find.byType(V3GameCard)),
        matching: find.byIcon(Icons.favorite_border)));
    await tester.pumpAndSettle();
    expect(find.text('Added to favourites'), findsOneWidget);
    // Open the game: detail page with the heart on.
    await tester.tap(find.text('Bulldog'));
    await tester.pumpAndSettle();
    expect(find.text('PDF Card'), findsOneWidget);
    expect(find.text('HOW TO PLAY'), findsOneWidget);
    expect(find.byTooltip('Remove from favourites'), findsOneWidget);
    expect(find.byTooltip('Edit game'), findsNothing); // public game
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('no pathway: fixed stages and the games list', (tester) async {
    tester.view.physicalSize = const Size(390 * 3, 1400 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
        MaterialApp(home: V3ResourcesPage(testData: data(pathway: false))));
    await tester.pumpAndSettle();
    expect(find.text('SELECT DEVELOPMENT STAGE'), findsOneWidget);
    expect(find.text('Learning to Use the Ball Well'), findsOneWidget);
    expect(find.text('Learning to Master the Ball'), findsNothing);
    await tester.tap(find.text('Learning to Use the Ball Well'));
    await tester.pumpAndSettle();
    expect(find.text('Bulldog'), findsOneWidget);
    await tester.tap(find.text('Hurling'));
    await tester.pumpAndSettle();
    expect(find.text('Bulldog'), findsNothing);
    expect(find.text('Hand pass drill'), findsOneWidget);
  });

  testWidgets('two pathways: pick one first', (tester) async {
    final d = data();
    d['pathways'] = [
      {
        'pathway_types': {'pathway_type_id': 1, 'pathway_name': 'TURAS'}
      },
      {
        'pathway_types': {'pathway_type_id': 2, 'pathway_name': 'Camogie'}
      },
    ];
    await tester.pumpWidget(MaterialApp(home: V3ResourcesPage(testData: d)));
    await tester.pumpAndSettle();
    expect(find.text('SELECT A PATHWAY'), findsOneWidget);
    await tester.tap(find.text('TURAS'));
    await tester.pumpAndSettle();
    expect(find.text('Learning to Master the Ball'), findsOneWidget);
  });
}
