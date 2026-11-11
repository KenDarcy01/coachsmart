import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:coach_smart_v2/v3/games/v3_games.dart';

Map<String, dynamic> gameRow(int id, String name,
        {List<String> types = const ['Game'],
        List<String> ages = const ['u8'],
        List<String> codes = const ['Football'],
        int? clubId,
        String createdBy = '',
        String howToPlay = 'Play it.',
        String variations = '',
        String setup = '',
        String teaching = '',
        String video = ''}) =>
    {
      'game_id': id,
      'game_name': name,
      'game_age': ages,
      'game_code': codes,
      'game_type': types,
      'game_skill': ['Passing', 'Catching', 'Solo'],
      'game_setup': setup,
      'game_how_to_play': howToPlay,
      'game_variations': variations,
      'game_teaching_points': teaching,
      'game_pdf': null,
      'game_video': video,
      'game_image': null,
      'club_id': clubId,
      'created_by': createdBy,
    };

class _FailingApi extends V3OfflineGamesApi {
  @override
  Future<void> toggleFavourite(int gameId) async => throw Exception('down');
}

void main() {
  group('models', () {
    test('parses rows, arrays and old comma strings', () {
      final g = V3Game.fromJson(gameRow(1, 'Bulldog', clubId: 7));
      expect(g.gameId, 1);
      expect(g.ages, ['u8']);
      expect(g.kind, GameKind.game);
      expect(g.clubId, 7);
      final old = V3Game.fromJson({
        'game_id': '2',
        'game_name': 'Old',
        'game_age': '{u8,u9}',
        'game_type': 'Warmup',
      });
      expect(old.gameId, 2);
      expect(old.ages, ['u8', 'u9']);
      expect(old.kind, GameKind.warmup);
      expect(old.hasContent, isFalse);
      expect(parseGames([gameRow(1, 'a'), 'junk', gameRow(2, 'b')]).length, 2);
    });

    test('kinds, sections and content', () {
      final games = parseGames([
        gameRow(1, 'G'),
        gameRow(2, 'W', types: ['Warmup']),
        gameRow(3, 'D', types: ['Drill', 'Video']),
        gameRow(4, 'S', types: ['Skills']),
      ]);
      final by = groupByKind(games);
      expect(by[GameKind.game]!.map((g) => g.name), ['G']);
      expect(by[GameKind.warmup]!.map((g) => g.name), ['W']);
      expect(by[GameKind.drill]!.map((g) => g.name), ['D']);
      expect(by[GameKind.video]!.map((g) => g.name), ['D']);
      expect(by[GameKind.skill]!.map((g) => g.name), ['S']);
      expect(games[3].canFavourite, isFalse);
      expect(games.first.matchesAges(['U8']), isTrue);
      expect(games.first.matchesAges(['u9']), isFalse);
      expect(kindSectionLabel(GameKind.drill), 'Drills');
    });

    test('steps and make-it-harder ideas', () {
      final s = splitSteps('Split into two teams. 1. Pass the ball 2. Run to '
          'the cone 3. Shoot');
      expect(s.intro, ['Split into two teams.']);
      expect(s.steps, ['Pass the ball', 'Run to the cone', 'Shoot']);
      final lines = splitSteps('1) Start\nkeep going\n2) Stop');
      expect(lines.steps, ['Start keep going', 'Stop']);
      expect(splitSteps('Just play.').steps, isEmpty);
      expect(splitSteps('Just play.').intro, ['Just play.']);
      expect(splitIdeas('• Smaller area • Two touches'),
          ['Smaller area', 'Two touches']);
      expect(splitIdeas('- Weak foot only - Add a defender'),
          ['Weak foot only', 'Add a defender']);
      expect(splitIdeas('1. One\n2. Two'), ['One', 'Two']);
      expect(splitIdeas(''), isEmpty);
    });

    test('youtube ids and favourite ids', () {
      expect(youtubeIdOf('https://youtu.be/dQw4w9WgXcQ'), 'dQw4w9WgXcQ');
      expect(youtubeIdOf('https://www.youtube.com/shorts/dQw4w9WgXcQ?x=1'),
          'dQw4w9WgXcQ');
      expect(youtubeIdOf('https://vimeo.com/1'), isNull);
      expect(parseFavouriteIds([1, '2', 0]), {1, 2});
      expect(
          parseFavouriteIds([
            {'game_id': 5}
          ]),
          {5});
    });

    test('edit and delete gates', () {
      final club = V3Game.fromJson(gameRow(1, 'C', clubId: 7, createdBy: 'u1'));
      final pub = V3Game.fromJson(gameRow(2, 'P'));
      expect(club.canEdit(7), isTrue);
      expect(club.canEdit(8), isFalse);
      expect(pub.canEdit(7), isFalse);
      expect(club.canDelete(userId: 'u1', email: 'a@b.ie'), isTrue);
      expect(club.canDelete(userId: 'u2', email: 'a@b.ie'), isFalse);
      expect(pub.canDelete(userId: 'u2', email: 'Ken.Darcy@gmail.com'), isTrue);
      final skill =
          V3Game.fromJson(gameRow(3, 'S', types: ['Skills'], createdBy: 'u1'));
      expect(
          skill.canDelete(userId: 'u1', email: 'ken.darcy@gmail.com'), isFalse);
      expect(deleteGameText(club), startsWith('"C" will be removed'));
    });
  });

  group('favourites', () {
    test('toggle is optimistic and saved', () async {
      final api = V3OfflineGamesApi(favourites: {1});
      final f = V3GameFavourites(api);
      await f.load();
      expect(f.isFav(1), isTrue);
      expect(await f.toggle(2), 'Added to favourites');
      expect(api.favourites, {1, 2});
      expect(await f.toggle(1), 'Removed from favourites');
      expect(f.ids, {2});
    });

    test('a failed toggle flips back', () async {
      final f = V3GameFavourites(_FailingApi());
      expect(await f.toggle(3), 'Could not save — please try again');
      expect(f.isFav(3), isFalse);
    });
  });

  group('drill diagram', () {
    test('players number up, short arrows drop, undo and clear', () {
      final c = DrillSketchController();
      c.tool = DrillTool.player;
      c.start(const Offset(.2, .2));
      c.start(const Offset(.4, .2));
      expect(
          c.sketch.marks.whereType<DrillPlayer>().map((p) => p.number), [1, 2]);
      c.tool = DrillTool.arrow;
      c.start(const Offset(.5, .5));
      c.move(const Offset(.505, .5));
      c.end();
      expect(c.sketch.marks.whereType<DrillArrow>(), isEmpty);
      c.start(const Offset(.1, .5));
      c.move(const Offset(.6, .5));
      expect(c.preview, isNotNull);
      c.end();
      expect(c.sketch.marks.whereType<DrillArrow>().length, 1);
      c.tool = DrillTool.draw;
      c.start(const Offset(.1, .1));
      c.move(const Offset(.2, .2));
      c.move(const Offset(.3, .2));
      expect((c.sketch.marks.last as DrillStroke).points.length, 3);
      c.undo();
      expect(c.sketch.marks.last, isA<DrillArrow>());
      c.tool = DrillTool.cone;
      c.start(const Offset(.9, .9));
      expect(c.sketch.marks.last, isA<DrillCone>());
      expect(c.hasContent, isTrue);
      c.clear();
      expect(c.hasContent, isFalse);
      expect(c.canUndo, isFalse);
    });

    testWidgets('sketch renders to a PNG and the pad paints', (tester) async {
      final sketch = DrillSketch(marks: const [
        DrillPlayer(Offset(.2, .3), 1),
        DrillCone(Offset(.5, .5)),
        DrillArrow(Offset(.2, .3), Offset(.8, .3)),
        DrillStroke([Offset(.1, .9), Offset(.9, .9)]),
      ]);
      final png = await tester.runAsync(() => renderDrillSketchPng(sketch));
      expect(png!.sublist(1, 4), 'PNG'.codeUnits);
      tester.view.physicalSize = const Size(390 * 3, 900 * 3);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      final c = DrillSketchController(initial: sketch);
      await tester.pumpWidget(
          MaterialApp(home: Scaffold(body: DrillSketchPad(controller: c))));
      expect(find.byType(CustomPaint), findsWidgets);
      await tester.tap(find.text('Player'));
      await tester.pump();
      expect(c.tool, DrillTool.player);
      await tester.tap(find.text('Clear'));
      await tester.pump();
      expect(c.sketch.marks, isEmpty);
    });
  });

  group('widgets', () {
    testWidgets('game card shows tags and its heart', (tester) async {
      var hearts = 0;
      await tester.pumpWidget(MaterialApp(
          home: Scaffold(
              body: V3GameCard(
        game: V3Game.fromJson(
            gameRow(1, 'Bulldog', types: ['Warmup'], clubId: 7)),
        clubName: 'Clontarf',
        onFavourite: () => hearts++,
      ))));
      expect(find.text('Bulldog'), findsOneWidget);
      expect(find.text('Warmup'), findsOneWidget);
      expect(find.text('Passing'), findsOneWidget);
      expect(find.text('Solo'), findsNothing); // only two skills
      expect(find.text('Clontarf'), findsOneWidget);
      await tester.tap(find.byIcon(Icons.favorite_border));
      expect(hearts, 1);
    });

    testWidgets('detail page: steps, variations, gates, heart, notes',
        (tester) async {
      tester.view.physicalSize = const Size(390 * 3, 1600 * 3);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      final g = V3Game.fromJson(gameRow(9, 'Pass and Move',
          clubId: 7,
          createdBy: 'me',
          setup: '20m square',
          howToPlay: '1. Pass 2. Move 3. Repeat',
          variations: '• One touch • Weak side',
          teaching: 'Eyes up'));
      final api = V3OfflineGamesApi(
          games: [g], clubId: 7, uid: 'me', notes: {9: 'Good for U8s'});
      final favs = V3GameFavourites(api);
      int? deleted;
      await tester.pumpWidget(MaterialApp(
          home: V3GameDetailPage(
              game: g,
              api: api,
              favourites: favs,
              myClubId: 7,
              onDeleted: (id) => deleted = id)));
      await tester.pumpAndSettle();
      expect(find.text('PDF Card'), findsOneWidget);
      expect(find.text('SETUP'), findsOneWidget);
      expect(find.text('Pass'), findsOneWidget);
      expect(find.text('Repeat'), findsOneWidget);
      expect(find.text('One touch'), findsOneWidget);
      expect(find.text('Weak side'), findsOneWidget);
      expect(find.text('Eyes up'), findsOneWidget);
      expect(find.text('Good for U8s'), findsOneWidget);
      expect(find.byTooltip('Edit game'), findsOneWidget);
      expect(find.byTooltip('Delete game'), findsOneWidget);
      await tester.tap(find.byTooltip('Add to favourites'));
      await tester.pumpAndSettle();
      expect(api.favourites, {9});
      expect(find.text('Added to favourites'), findsOneWidget);
      // Delete asks first.
      await tester.tap(find.byTooltip('Delete game'));
      await tester.pumpAndSettle();
      expect(find.text('Delete this game?'), findsOneWidget);
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      expect(deleted, 9);
      expect(api.calls, contains('delete:9'));
      await tester.pump(const Duration(seconds: 5));
    });

    testWidgets('detail page hides edit and delete for a public game',
        (tester) async {
      final g = V3Game.fromJson(gameRow(4, 'Public', types: ['Skills']));
      final api = V3OfflineGamesApi(games: [g], uid: 'me');
      await tester.pumpWidget(MaterialApp(
          home: V3GameDetailPage(
              game: g,
              api: api,
              favourites: V3GameFavourites(api),
              myClubId: 7,
              showNotes: false)));
      await tester.pumpAndSettle();
      expect(find.byTooltip('Edit game'), findsNothing);
      expect(find.byTooltip('Delete game'), findsNothing);
      expect(find.byTooltip('Add to favourites'), findsNothing); // Skills
    });

    testWidgets('edit page saves through the api', (tester) async {
      tester.view.physicalSize = const Size(390 * 3, 2400 * 3);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      final g = V3Game.fromJson(gameRow(5, 'Old name', clubId: 7));
      final api = V3OfflineGamesApi(games: [g], clubId: 7);
      V3Game? saved;
      await tester.pumpWidget(MaterialApp(
          home: Builder(
              builder: (context) => Scaffold(
                  body: TextButton(
                      onPressed: () async {
                        saved = await Navigator.of(context).push<V3Game>(
                            MaterialPageRoute(
                                builder: (_) =>
                                    V3GameEditPage(game: g, api: api)));
                      },
                      child: const Text('open'))))));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.text('Edit Game'), findsOneWidget);
      await tester.enterText(find.widgetWithText(TextField, 'Old name'), 'New');
      await tester.tap(find.text('Hurling'));
      await tester.tap(find.text('Drill'));
      await tester.pump();
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(saved!.name, 'New');
      expect(saved!.codes, ['Football', 'Hurling']);
      expect(saved!.types, ['Drill']);
      expect(api.calls, ['update:5']);
    });
  });
}
