import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:coach_smart_v2/v3/game_upload/v3_game_upload_models.dart';
import 'package:coach_smart_v2/v3/game_upload/v3_game_upload_page.dart';
import 'package:coach_smart_v2/v3/game_upload/v3_game_upload_services.dart';
import 'package:coach_smart_v2/v3/games/v3_games.dart';
import 'package:coach_smart_v2/v3/games/v3_scene.dart';
import 'package:coach_smart_v2/v3/match_report/v3_voice_sheet.dart';

/// XML equal to [b] apart from numbers within 0.15 (float rounding).
void expectXmlClose(String a, String b) {
  final re = RegExp(r'-?\d+(?:\.\d+)?');
  expect(a.replaceAll(re, '#'), b.replaceAll(re, '#'));
  final na = re.allMatches(a).map((m) => double.parse(m[0]!)).toList();
  final nb = re.allMatches(b).map((m) => double.parse(m[0]!)).toList();
  expect(na.length, nb.length);
  for (var i = 0; i < na.length; i++) {
    expect((na[i] - nb[i]).abs() <= 0.15, isTrue,
        reason: 'number $i: ${na[i]} vs ${nb[i]}');
  }
}

/// A 1 x 1 PNG.
final onePx = base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==');

class FakeDictation extends V3Dictation {
  @override
  Future<bool> start() async => true;
  @override
  Future<String> stop() async => '';
  @override
  void dispose() {}
}

class FakeServices extends V3GameUploadServices {
  FakeServices({this.saveOk = true});
  final bool saveOk;
  final ai = <Map<String, dynamic>>[];
  final diagrams = <Map<String, dynamic>>[];

  @override
  Future<bool> aiEnabled() async => true;

  @override
  Future<Map<String, dynamic>> aiProcessGame(Map<String, dynamic> body) async {
    ai.add(body);
    switch (body['action']) {
      case 'split_voice':
        return {
          'success': true,
          'data': {
            'game_name': 'Four corners',
            'game_setup': 'A 20m square',
            'game_how_to_play': 'Pass round the square',
            'game_variations': '',
            'game_teaching_points': 'Call for it',
            'suggested_ages': ['u10', 'U12'],
            'suggested_sport': 'Football',
            'suggested_skills': ['Handpass'],
            'suggested_type': 'drill',
          }
        };
      case 'revise_with_feedback':
        return {
          'success': true,
          'data': {
            'game_name': 'Four corners',
            'game_setup': 'A 10m square',
            'game_how_to_play': 'Pass round the square',
            'game_variations': '',
            'game_teaching_points': 'Call for it',
          }
        };
      case 'save_game':
        return saveOk
            ? {'success': true, 'game_id': 99}
            : {'error': 'Game name taken'};
    }
    return {'error': 'unknown'};
  }

  @override
  Future<Map<String, dynamic>> diagram(Map<String, dynamic> body) async {
    diagrams.add(body);
    await Future<void>.delayed(const Duration(milliseconds: 300));
    final scene = jsonDecode(sceneFixtures.first.scene) as Map;
    return {
      'xml': sceneFixtures.first.xml,
      'game_name': 'Square passing',
      'suggested_codes': ['football'],
      'scene': {
        ...scene,
        if (body['instruction'] != null) 'tidied': 'Moved it'
      },
    };
  }

  @override
  Future<Uint8List> sketchPng(DrillSketch s) async => onePx;

  @override
  Future<Uint8List> diagramPng(V3Diagram d, double pixelRatio) async => onePx;
}

Future<void> pump(WidgetTester t, Widget w) async {
  t.view.physicalSize = const Size(1170, 2532);
  t.view.devicePixelRatio = 3;
  addTearDown(t.view.reset);
  await t.pumpWidget(MaterialApp(home: w));
  await t.pumpAndSettle();
}

/// Lets the fake futures finish while the processing timer ticks.
Future<void> settle(WidgetTester t) async {
  for (var i = 0; i < 10; i++) {
    await t.pump(const Duration(milliseconds: 100));
  }
  await t.pumpAndSettle();
}

const words = 'Four players in a square passing the ball round clockwise.';

void main() {
  group('scene engine (cs-scene.js port)', () {
    for (final (i, f) in sceneFixtures.indexed) {
      test('scene $i matches cs-scene.js', () {
        final d = sceneToDiagram(
            V3Scene.fromJson(jsonDecode(f.scene) as Map), f.w, f.h);
        expectXmlClose(d.toXml(), f.xml);
      });
    }

    test('players are one standard size and kept apart', () {
      final d = sceneToDiagram(
          V3Scene.fromJson({
            'items': [
              for (var i = 0; i < 4; i++)
                {
                  'kind': 'player',
                  'label': '${i + 1}',
                  'team': 'home',
                  'x': 400 + i * 8,
                  'y': 500,
                  'w': 0,
                  'h': 0
                },
            ],
            'lines': [],
          }),
          1000,
          1000);
      final people = d.cells.where((c) => c.style.contains('ellipse')).toList();
      expect(people, hasLength(4));
      for (final c in people) {
        expect(c.w, kScenePlayerSize);
        expect(c.h, kScenePlayerSize);
      }
      for (var i = 0; i < people.length; i++) {
        for (var j = i + 1; j < people.length; j++) {
          final a = people[i], b = people[j];
          final gap =
              math.sqrt(math.pow(a.x - b.x, 2) + math.pow(a.y - b.y, 2));
          expect(gap, greaterThan(kScenePlayerSize));
        }
      }
    });

    test('a run past a cone goes round it', () {
      final d = sceneToDiagram(
          V3Scene.fromJson({
            'items': [
              {
                'kind': 'cone',
                'label': '',
                'team': 'none',
                'x': 500,
                'y': 500,
                'w': 0,
                'h': 0
              },
              {
                'kind': 'player',
                'label': '1',
                'team': 'home',
                'x': 100,
                'y': 500,
                'w': 0,
                'h': 0
              },
            ],
            'lines': [
              {
                'kind': 'run',
                'points': [
                  {'x': 150, 'y': 500},
                  {'x': 900, 'y': 500}
                ]
              }
            ],
          }),
          1000,
          1000);
      final cone = d.cells.firstWhere((c) => c.style.contains('triangle'));
      final centre = Offset(cone.x + cone.w / 2, cone.y + cone.h / 2);
      final run = d.cells.firstWhere((c) => c.edge);
      expect(run.points.length, greaterThan(2));
      expect(run.style, contains('curved=1'));
      final nearest =
          run.points.map((p) => (p - centre).distance).reduce(math.min);
      expect(nearest, greaterThan(30));
    });

    test('XML round trip and old diagrams get ball and coach styles', () {
      final xml = sceneFixtures[1].xml;
      final d = parseMxGraphXml(xml)!;
      expect(d.v2, isTrue);
      expectXmlClose(d.toXml(), xml);
      final old = fixCircleStyles(parseMxGraphXml(
          '<mxGraphModel><root><mxCell id="2" value="" style="ellipse;fillColor=#C62828;" vertex="1" parent="1"><mxGeometry x="10" y="10" width="40" height="40" as="geometry"/></mxCell>'
          '<mxCell id="3" value="C" style="ellipse;fillColor=#C62828;" vertex="1" parent="1"><mxGeometry x="60" y="10" width="40" height="40" as="geometry"/></mxCell>'
          '<mxCell id="4" value="7" style="ellipse;fillColor=#C62828;" vertex="1" parent="1"><mxGeometry x="90" y="10" width="40" height="40" as="geometry"/></mxCell></root></mxGraphModel>')!);
      expect(old.cells[0].style, contains('fillColor=#ffffff'));
      expect(old.cells[0].w, 24);
      expect(old.cells[1].style, contains('fillColor=#1a1a1a'));
      expect(old.cells[2].style, 'ellipse;fillColor=#C62828;');
    });

    test('image size from PNG and JPEG headers', () {
      expect(sceneImageSize(onePx), (w: 1, h: 1));
      final jpeg = Uint8List.fromList([
        0xff, 0xd8, 0xff, 0xe0, 0x00, 0x04, 0x00, 0x00, //
        0xff, 0xc0, 0x00, 0x11, 0x08, 0x02, 0x58, 0x03, 0x20, 0x03, 0, 0, 0
      ]);
      expect(sceneImageSize(jpeg), (w: 800, h: 600));
    });

    testWidgets('renders the 600 x 600 PNG at the pixel ratio', (tester) async {
      final d = sceneToDiagram(
          V3Scene.fromJson(jsonDecode(sceneFixtures[1].scene) as Map),
          1200,
          900);
      final png = await tester.runAsync(() => renderDiagramPng(d));
      expect(sceneImageSize(png!), (w: 1200, h: 1200));
    });
  });

  group('models', () {
    test('create rules', () {
      expect(
          guCanCreate(
              tab: GuMedia.photo,
              photos: 0,
              drawn: false,
              ai: false,
              words: words),
          isFalse);
      expect(
          guCanCreate(
              tab: GuMedia.photo,
              photos: 0,
              drawn: false,
              ai: true,
              words: words),
          isTrue);
      expect(
          guCanCreate(
              tab: GuMedia.sketch,
              photos: 0,
              drawn: true,
              ai: false,
              words: ''),
          isTrue);
      expect(
          guFromWords(
              tab: GuMedia.sketch,
              photos: 2,
              drawn: false,
              ai: true,
              words: words),
          isTrue);
      expect(
          guFromWords(
              tab: GuMedia.photo,
              photos: 1,
              drawn: false,
              ai: true,
              words: words),
          isFalse);
      expect(
          guMissingSource(
              tab: GuMedia.photo, photos: 0, drawn: false, ai: false),
          'Add at least one photo to continue');
    });

    test('preselect, codes, skills and wording', () {
      expect(guPreselect(kGuAges, ['U6'], ['u10', 'Adult']), ['U10', 'Adult']);
      expect(guPreselect(kGuAges, ['U6'], []), ['U6']);
      expect(guMatchType('warmup'), 'Warmup');
      expect(guDraftCodes(['hurling', 'camogie'], 'Football'),
          ['hurling', 'camogie']);
      expect(guDraftCodes([], 'Football'), ['Football']);
      expect(guVisibleSkills(['Hurling']), isNot(contains('Kick Pass')));
      expect(guVisibleSkills(['Hurling', 'Football']), contains('Kick Pass'));
      expect(guRevisePlaceholder(['Camogie']), isNot(contains('kick')));
      expect(guElapsed(5), '5s elapsed — usually takes 60–90 seconds');
      expect(guElapsed(95), '1:35 elapsed — almost there…');
      expect(guTidied({'tidied': ' Spaced it. '}), 'Tidied: Spaced it.');
    });

    test('bodies and answers', () {
      final save = guSaveBody(
          name: ' Rondo ',
          type: 'Drill',
          ages: [],
          codes: ['Hurling'],
          skills: [],
          setup: '',
          howTo: '',
          variations: '',
          teaching: '',
          video: ' ');
      expect(save['game_name'], 'Rondo');
      expect(save['game_type'], ['Drill']);
      expect(save['game_skill'], isNull);
      expect(save['game_video'], isNull);
      expect(guSaveProblem(name: 'x', type: 'Game', codes: []),
          'Please select a Code (Football / Hurling / Camogie)');
      final fix = guDiagramBody(
          fix: const GuFix(scene: {'items': []}, instruction: 'add a cone'),
          drawing: 'ignored');
      expect(fix['instruction'], 'add a cone');
      expect(fix['drawing'], 'ignored');
      expect(fix.containsKey('image_base64'), isFalse);
      expect(guDiagramBody(drawing: words, notes: '')['notes'], '');
      expect(
          () => guUnwrapAi({'error': 'AI processing failed', 'detail': 'x'}),
          throwsA(isA<GuError>().having(
              (e) => e.message, 'message', 'AI processing failed (x)')));
      expect(GuDiagramAnswer.fromJson({'error': 'nope'}).ok, isFalse);
      expect(GuDiagramAnswer.fromJson({'xml': '<x/>'}).ok, isTrue);
    });
  });

  group('page', () {
    testWidgets('without AI: sketch, form and save checks', (tester) async {
      final svc = FakeServices();
      await pump(tester, V3GameUploadPage(services: svc, testAiEnabled: false));
      expect(find.text('Add Game / Drill'), findsOneWidget);
      expect(find.text('Import from a document'), findsNothing);
      expect(find.text('How to draw'), findsNothing);
      expect(find.byTooltip('Speak instead'), findsNothing);
      final cont = find.widgetWithText(FilledButton, 'Continue');
      expect(tester.widget<FilledButton>(cont).onPressed, isNull);

      await tester.tap(find.text('Sketch'));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(DrillSketchPad), warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(tester.widget<FilledButton>(cont).onPressed, isNotNull);
      await tester.tap(cont);
      await tester.pumpAndSettle();
      expect(find.text('Review & Edit'), findsOneWidget);
      expect(find.text('Revise with feedback'), findsNothing);

      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pump();
      expect(find.text('Game name is required'), findsOneWidget);
      await tester.scrollUntilVisible(
          find.byKey(const ValueKey('v3-game-name')), 200,
          scrollable: find.byType(Scrollable).first);
      await tester.enterText(
          find.byKey(const ValueKey('v3-game-name')), 'Rondo');
      await tester.scrollUntilVisible(find.text('Game'), -200,
          scrollable: find.byType(Scrollable).first);
      await tester.ensureVisible(find.text('Game'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Game'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();
      expect(find.text('Please select a Code (Football / Hurling / Camogie)'),
          findsOneWidget);
      expect(svc.ai, isEmpty);
    });

    testWidgets('with AI: draw from words, fix the drawing, save',
        (tester) async {
      final svc = FakeServices();
      await pump(
          tester,
          V3GameUploadPage(
              services: svc,
              testAiEnabled: true,
              testDictation: FakeDictation()));
      expect(find.text('How to draw'), findsOneWidget);
      expect(find.text('Import from a document'), findsNothing);
      await tester.enterText(find.byType(TextField).first, words);
      await tester.pump();
      await tester.tap(find.widgetWithText(FilledButton, 'Create Draft'));
      await tester.pump();
      expect(find.text('This takes 60–90 seconds — keep this screen open'),
          findsOneWidget);
      await settle(tester);

      expect(find.text('Review & Edit'), findsOneWidget);
      // Drawn from words, then one look at its own drawing.
      expect(svc.diagrams, hasLength(2));
      expect(svc.diagrams[0]['drawing'], words);
      expect(svc.diagrams[0].containsKey('image_base64'), isFalse);
      expect(svc.diagrams[1]['check_image_base64'], base64Encode(onePx));
      expect(svc.ai.first['action'], 'split_voice');
      expect(svc.ai.first['images'], isEmpty);
      expect(find.text('Tidied: Spaced the cones evenly.'), findsOneWidget);
      // (The 1 px test picture is not decoded, so it has no height yet.)
      expect(find.byKey(const ValueKey('v3-game-diagram'), skipOffstage: false),
          findsOneWidget);

      await tester.tap(find.text('Fix the drawing'));
      await tester.pumpAndSettle();
      await tester.enterText(
          find.descendant(
              of: find.byType(V3VoiceSheet), matching: find.byType(TextField)),
          'add a cone beside player 3');
      await tester.pump();
      await tester.tap(find.text('Update'));
      await settle(tester);
      expect(svc.diagrams.last['instruction'], 'add a cone beside player 3');
      expect(svc.diagrams.last['scene'], isA<Map>());
      expect(find.text('Tidied: Moved it'), findsOneWidget);
      expect(find.text('Undo last fix'), findsOneWidget);
      await tester.tap(find.text('Undo last fix'));
      await tester.pumpAndSettle();
      expect(find.text('Tidied: Spaced the cones evenly.'), findsOneWidget);

      // The diagram's title wins over the text AI's name.
      await tester.scrollUntilVisible(
          find.byKey(const ValueKey('v3-game-name')), 200,
          scrollable: find.byType(Scrollable).first);
      expect(find.text('Square passing'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pump();
      final save = svc.ai.last;
      expect(save['action'], 'save_game');
      expect(save['game_name'], 'Square passing');
      expect(save['game_type'], ['Drill']);
      expect(save['game_code'], ['Football']);
      expect(save['game_age'], ['U10', 'U12']);
      expect(save['game_skill'], ['Handpass']);
      expect(save['image_base64'], base64Encode(onePx));
      expect(save['image_mime_type'], 'image/png');
      await tester.pump(const Duration(milliseconds: 1300));
      await tester.pumpAndSettle();
    });
  });
}

// Scenes and the XML webviews/cs-scene.js (main) makes from them.
const sceneFixtures = <({int w, int h, String scene, String xml})>[
  (
    w: 1000,
    h: 1000,
    scene:
        r'''{"game_name":"Square passing","sport":"football","tidied":"Spaced the cones evenly.","symmetry":{"left_right":true,"top_bottom":true},"items":[{"kind":"player","label":"1","team":"home","x":200,"y":200,"w":0,"h":0},{"kind":"player","label":"2","team":"home","x":805,"y":195,"w":0,"h":0},{"kind":"player","label":"3","team":"home","x":795,"y":810,"w":0,"h":0},{"kind":"player","label":"4","team":"home","x":210,"y":800,"w":0,"h":0},{"kind":"coach","label":"C","team":"none","x":500,"y":505,"w":0,"h":0},{"kind":"cone","label":"","team":"none","x":250,"y":160,"w":0,"h":0},{"kind":"cone","label":"","team":"none","x":500,"y":200,"w":0,"h":0},{"kind":"ball","label":"","team":"none","x":180,"y":260,"w":0,"h":0},{"kind":"ball","label":"","team":"none","x":185,"y":272,"w":0,"h":0},{"kind":"ball","label":"","team":"none","x":190,"y":284,"w":0,"h":0},{"kind":"text","label":"Start here with the first ball","team":"none","x":120,"y":950,"w":0,"h":0}],"lines":[{"kind":"pass","points":[{"x":230,"y":200},{"x":770,"y":205}]},{"kind":"run","points":[{"x":800,"y":230},{"x":805,"y":770}]},{"kind":"pass","points":[{"x":770,"y":805},{"x":240,"y":800}]},{"kind":"run","points":[{"x":200,"y":770},{"x":205,"y":240}]},{"kind":"run","points":[{"x":300,"y":250},{"x":420,"y":180},{"x":500,"y":170},{"x":580,"y":180},{"x":700,"y":250}]}]}''',
    xml:
        r'''<mxGraphModel background="#2E7D32" csEngine="v2"><root><mxCell id="0"/><mxCell id="1" parent="0"/><mxCell id="2" value="" style="fillColor=#2E7D32;strokeColor=none;" vertex="1" parent="1"><mxGeometry x="0" y="0" width="616" height="700" as="geometry"/></mxCell><mxCell id="3" value="" style="edgeStyle=none;curved=1;html=1;endArrow=open;endFill=0;dashed=1;dashPattern=8 4;strokeColor=#FFD700;strokeWidth=2.5;" edge="1" parent="1"><mxGeometry relative="1" as="geometry"><mxPoint x="128.2" y="66.8" as="sourcePoint"/><mxPoint x="545.4" y="69.2" as="targetPoint"/><Array as="points"><mxPoint x="142" y="68"/><mxPoint x="338.3" y="102"/></Array></mxGeometry></mxCell><mxCell id="4" value="" style="edgeStyle=none;html=1;endArrow=block;endFill=1;strokeColor=#ffffff;strokeWidth=2.5;" edge="1" parent="1"><mxGeometry relative="1" as="geometry"><mxPoint x="578" y="97" as="sourcePoint"/><mxPoint x="578" y="517" as="targetPoint"/></mxGeometry></mxCell><mxCell id="5" value="" style="edgeStyle=none;html=1;endArrow=open;endFill=0;dashed=1;dashPattern=8 4;strokeColor=#FFD700;strokeWidth=2.5;" edge="1" parent="1"><mxGeometry relative="1" as="geometry"><mxPoint x="545" y="550" as="sourcePoint"/><mxPoint x="135" y="550" as="targetPoint"/></mxGeometry></mxCell><mxCell id="6" value="" style="edgeStyle=none;html=1;endArrow=block;endFill=1;strokeColor=#ffffff;strokeWidth=2.5;" edge="1" parent="1"><mxGeometry relative="1" as="geometry"><mxPoint x="98.7" y="517.2" as="sourcePoint"/><mxPoint x="98.7" y="96.8" as="targetPoint"/></mxGeometry></mxCell><mxCell id="7" value="" style="edgeStyle=none;curved=1;html=1;endArrow=block;endFill=1;strokeColor=#ffffff;strokeWidth=2.5;" edge="1" parent="1"><mxGeometry relative="1" as="geometry"><mxPoint x="178" y="109" as="sourcePoint"/><mxPoint x="498" y="106" as="targetPoint"/><Array as="points"><mxPoint x="338" y="-23.5"/></Array></mxGeometry></mxCell><mxCell id="8" value="" style="triangle;direction=north;whiteSpace=wrap;html=1;fillColor=#FF6D00;gradientColor=#FFAB40;gradientDirection=north;strokeColor=#E65100;shadow=1;" vertex="1" parent="1"><mxGeometry x="129" y="16.5" width="26" height="31" as="geometry"/></mxCell><mxCell id="9" value="" style="triangle;direction=north;whiteSpace=wrap;html=1;fillColor=#FF6D00;gradientColor=#FFAB40;gradientDirection=north;strokeColor=#E65100;shadow=1;" vertex="1" parent="1"><mxGeometry x="325" y="50.5" width="26" height="31" as="geometry"/></mxCell><mxCell id="10" value="" style="ellipse;whiteSpace=wrap;html=1;aspect=fixed;fillColor=#ffffff;strokeColor=#555555;shadow=0;" vertex="1" parent="1"><mxGeometry x="83.3" y="83.7" width="24" height="24" as="geometry"/></mxCell><mxCell id="11" value="" style="ellipse;whiteSpace=wrap;html=1;aspect=fixed;fillColor=#ffffff;strokeColor=#555555;shadow=0;" vertex="1" parent="1"><mxGeometry x="83.3" y="109" width="24" height="24" as="geometry"/></mxCell><mxCell id="12" value="" style="ellipse;whiteSpace=wrap;html=1;aspect=fixed;fillColor=#ffffff;strokeColor=#555555;shadow=0;" vertex="1" parent="1"><mxGeometry x="83.3" y="135.1" width="24" height="24" as="geometry"/></mxCell><mxCell id="13" value="Start here with the first ball" style="text;html=1;align=left;verticalAlign=middle;strokeColor=none;fillColor=none;fontColor=#ffffff;fontSize=13;fontStyle=1;" vertex="1" parent="1"><mxGeometry x="24" y="656" width="240" height="20" as="geometry"/></mxCell><mxCell id="14" value="1" style="ellipse;whiteSpace=wrap;html=1;aspect=fixed;fontSize=15;fontStyle=1;fillColor=#C62828;gradientColor=#EF5350;gradientDirection=north;strokeColor=#B71C1C;shadow=1;fontColor=#ffffff;" vertex="1" parent="1"><mxGeometry x="73.3" y="42" width="44" height="44" as="geometry"/></mxCell><mxCell id="15" value="2" style="ellipse;whiteSpace=wrap;html=1;aspect=fixed;fontSize=15;fontStyle=1;fillColor=#C62828;gradientColor=#EF5350;gradientDirection=north;strokeColor=#B71C1C;shadow=1;fontColor=#ffffff;" vertex="1" parent="1"><mxGeometry x="556" y="42" width="44" height="44" as="geometry"/></mxCell><mxCell id="16" value="3" style="ellipse;whiteSpace=wrap;html=1;aspect=fixed;fontSize=15;fontStyle=1;fillColor=#C62828;gradientColor=#EF5350;gradientDirection=north;strokeColor=#B71C1C;shadow=1;fontColor=#ffffff;" vertex="1" parent="1"><mxGeometry x="556" y="528" width="44" height="44" as="geometry"/></mxCell><mxCell id="17" value="4" style="ellipse;whiteSpace=wrap;html=1;aspect=fixed;fontSize=15;fontStyle=1;fillColor=#C62828;gradientColor=#EF5350;gradientDirection=north;strokeColor=#B71C1C;shadow=1;fontColor=#ffffff;" vertex="1" parent="1"><mxGeometry x="80" y="528" width="44" height="44" as="geometry"/></mxCell><mxCell id="18" value="C" style="ellipse;whiteSpace=wrap;html=1;aspect=fixed;fontSize=15;fontStyle=1;fillColor=#1a1a1a;gradientColor=#3a3a3a;gradientDirection=north;strokeColor=#000000;shadow=1;fontColor=#ffffff;" vertex="1" parent="1"><mxGeometry x="316" y="288" width="44" height="44" as="geometry"/></mxCell></root></mxGraphModel>''',
  ),
  (
    w: 1200,
    h: 900,
    scene:
        r'''{"game_name":"","sport":"hurling","tidied":"","symmetry":{"left_right":true,"top_bottom":false},"items":[{"kind":"goalposts","label":"","team":"none","x":500,"y":90,"w":120,"h":120},{"kind":"player","label":"2","team":"home","x":300,"y":500,"w":0,"h":0},{"kind":"player","label":"15","team":"away","x":340,"y":505,"w":0,"h":0},{"kind":"player","label":"3","team":"home","x":700,"y":495,"w":0,"h":0},{"kind":"player","label":"14","team":"away","x":660,"y":500,"w":0,"h":0},{"kind":"cone","label":"","team":"none","x":500,"y":650,"w":0,"h":0},{"kind":"zone","label":"Zone A","team":"none","x":500,"y":820,"w":300,"h":150}],"lines":[{"kind":"pitch_line","points":[{"x":50,"y":150},{"x":950,"y":152}]},{"kind":"pitch_line","points":[{"x":50,"y":148},{"x":55,"y":950}]},{"kind":"pitch_line","points":[{"x":948,"y":160},{"x":950,"y":950}]},{"kind":"pitch_line","points":[{"x":60,"y":400},{"x":940,"y":400}]},{"kind":"pitch_arc","points":[{"x":380,"y":400},{"x":500,"y":480},{"x":620,"y":400}]},{"kind":"dotted_line","points":[{"x":60,"y":600},{"x":500,"y":602},{"x":940,"y":600}]},{"kind":"run","points":[{"x":300,"y":540},{"x":350,"y":600},{"x":450,"y":640},{"x":500,"y":660},{"x":550,"y":700},{"x":600,"y":720}]},{"kind":"pass","points":[{"x":600,"y":720},{"x":690,"y":530}]},{"kind":"shot","points":[{"x":700,"y":460},{"x":520,"y":100}]}]}''',
    xml:
        r'''<mxGraphModel background="#2E7D32" csEngine="v2"><root><mxCell id="0"/><mxCell id="1" parent="0"/><mxCell id="2" value="" style="fillColor=#2E7D32;strokeColor=none;" vertex="1" parent="1"><mxGeometry x="0" y="0" width="700" height="553" as="geometry"/></mxCell><mxCell id="3" value="Zone A" style="rounded=0;whiteSpace=wrap;html=1;fillColor=#ffffff;opacity=12;strokeColor=#ffffff;strokeWidth=1.5;fontColor=#ffffff;fontSize=13;fontStyle=1;" vertex="1" parent="1"><mxGeometry x="244.7" y="410.6" width="210.7" height="79" as="geometry"/></mxCell><mxCell id="4" value="" style="edgeStyle=none;html=1;endArrow=none;endFill=0;strokeColor=#ffffff;strokeWidth=1.5;opacity=50;" edge="1" parent="1"><mxGeometry relative="1" as="geometry"><mxPoint x="35.8" y="97.7" as="sourcePoint"/><mxPoint x="665.3" y="97.7" as="targetPoint"/></mxGeometry></mxCell><mxCell id="5" value="" style="edgeStyle=none;html=1;endArrow=none;endFill=0;strokeColor=#ffffff;strokeWidth=1.5;opacity=50;" edge="1" parent="1"><mxGeometry relative="1" as="geometry"><mxPoint x="35.8" y="97.7" as="sourcePoint"/><mxPoint x="35.8" y="518.5" as="targetPoint"/></mxGeometry></mxCell><mxCell id="6" value="" style="edgeStyle=none;html=1;endArrow=none;endFill=0;strokeColor=#ffffff;strokeWidth=1.5;opacity=50;" edge="1" parent="1"><mxGeometry relative="1" as="geometry"><mxPoint x="665.3" y="97.7" as="sourcePoint"/><mxPoint x="665.3" y="518.5" as="targetPoint"/></mxGeometry></mxCell><mxCell id="7" value="" style="edgeStyle=none;html=1;endArrow=none;endFill=0;strokeColor=#ffffff;strokeWidth=1.5;opacity=50;" edge="1" parent="1"><mxGeometry relative="1" as="geometry"><mxPoint x="35.8" y="228.9" as="sourcePoint"/><mxPoint x="665.3" y="228.9" as="targetPoint"/></mxGeometry></mxCell><mxCell id="8" value="" style="edgeStyle=none;html=1;endArrow=none;endFill=0;dashed=1;dashPattern=6 6;strokeColor=#ffffff;strokeWidth=1.5;opacity=50;" edge="1" parent="1"><mxGeometry relative="1" as="geometry"><mxPoint x="41.5" y="334.2" as="sourcePoint"/><mxPoint x="659.5" y="334.2" as="targetPoint"/></mxGeometry></mxCell><mxCell id="9" value="" style="edgeStyle=none;curved=1;html=1;endArrow=none;endFill=0;strokeColor=#ffffff;strokeWidth=1.5;opacity=50;" edge="1" parent="1"><mxGeometry relative="1" as="geometry"><mxPoint x="266.3" y="228.9" as="sourcePoint"/><mxPoint x="434.8" y="228.9" as="targetPoint"/><Array as="points"><mxPoint x="350.5" y="271"/></Array></mxGeometry></mxCell><mxCell id="10" value="" style="edgeStyle=none;curved=1;html=1;endArrow=block;endFill=1;strokeColor=#ffffff;strokeWidth=2.5;" edge="1" parent="1"><mxGeometry relative="1" as="geometry"><mxPoint x="186.9" y="312.1" as="sourcePoint"/><mxPoint x="398.2" y="396.8" as="targetPoint"/><Array as="points"><mxPoint x="174.2" y="329.2"/><mxPoint x="340.9" y="395.2"/></Array></mxGeometry></mxCell><mxCell id="11" value="" style="edgeStyle=none;html=1;endArrow=open;endFill=0;dashed=1;dashPattern=8 4;strokeColor=#FFD700;strokeWidth=2.5;" edge="1" parent="1"><mxGeometry relative="1" as="geometry"><mxPoint x="430.6" y="380.3" as="sourcePoint"/><mxPoint x="477.9" y="302.4" as="targetPoint"/></mxGeometry></mxCell><mxCell id="12" value="" style="edgeStyle=none;html=1;endArrow=block;endFill=1;csShot=1;strokeColor=#FFD700;strokeWidth=3.5;" edge="1" parent="1"><mxGeometry relative="1" as="geometry"><mxPoint x="476.8" y="260.7" as="sourcePoint"/><mxPoint x="350.5" y="81.6" as="targetPoint"/></mxGeometry></mxCell><mxCell id="13" value="" style="gaa_goalpost;whiteSpace=wrap;html=1;" vertex="1" parent="1"><mxGeometry x="308.4" y="34" width="84.3" height="63.2" as="geometry"/></mxCell><mxCell id="14" value="" style="triangle;direction=north;whiteSpace=wrap;html=1;fillColor=#FF6D00;gradientColor=#FFAB40;gradientDirection=north;strokeColor=#E65100;shadow=1;" vertex="1" parent="1"><mxGeometry x="337.5" y="345" width="26" height="31" as="geometry"/></mxCell><mxCell id="15" value="2" style="ellipse;whiteSpace=wrap;html=1;aspect=fixed;fontSize=15;fontStyle=1;fillColor=#C62828;gradientColor=#EF5350;gradientDirection=north;strokeColor=#B71C1C;shadow=1;fontColor=#ffffff;" vertex="1" parent="1"><mxGeometry x="176.1" y="259.1" width="44" height="44" as="geometry"/></mxCell><mxCell id="16" value="15" style="ellipse;whiteSpace=wrap;html=1;aspect=fixed;fontSize=15;fontStyle=1;fillColor=#1565C0;gradientColor=#42A5F5;gradientDirection=north;strokeColor=#0D47A1;shadow=1;fontColor=#ffffff;" vertex="1" parent="1"><mxGeometry x="228.1" y="259.1" width="44" height="44" as="geometry"/></mxCell><mxCell id="17" value="3" style="ellipse;whiteSpace=wrap;html=1;aspect=fixed;fontSize=15;fontStyle=1;fillColor=#C62828;gradientColor=#EF5350;gradientDirection=north;strokeColor=#B71C1C;shadow=1;fontColor=#ffffff;" vertex="1" parent="1"><mxGeometry x="480.9" y="258.9" width="44" height="44" as="geometry"/></mxCell><mxCell id="18" value="14" style="ellipse;whiteSpace=wrap;html=1;aspect=fixed;fontSize=15;fontStyle=1;fillColor=#1565C0;gradientColor=#42A5F5;gradientDirection=north;strokeColor=#0D47A1;shadow=1;fontColor=#ffffff;" vertex="1" parent="1"><mxGeometry x="428.9" y="258.9" width="44" height="44" as="geometry"/></mxCell></root></mxGraphModel>''',
  ),
  (
    w: 800,
    h: 600,
    scene:
        r'''{"game_name":"Wall ball","sport":"hurling","tidied":"","symmetry":{"left_right":false,"top_bottom":false},"items":[{"kind":"wall","label":"","team":"none","x":500,"y":80,"w":800,"h":60},{"kind":"player","label":"1","team":"home","x":200,"y":600,"w":0,"h":0},{"kind":"player","label":"2","team":"home","x":420,"y":610,"w":0,"h":0},{"kind":"player","label":"3","team":"home","x":640,"y":590,"w":0,"h":0},{"kind":"player","label":"4","team":"home","x":655,"y":600,"w":0,"h":0},{"kind":"cone","label":"","team":"none","x":200,"y":850,"w":0,"h":0},{"kind":"cone","label":"","team":"none","x":410,"y":860,"w":0,"h":0},{"kind":"cone","label":"","team":"none","x":620,"y":845,"w":0,"h":0},{"kind":"cone","label":"","team":"none","x":830,"y":855,"w":0,"h":0}],"lines":[{"kind":"pass","points":[{"x":200,"y":560},{"x":200,"y":120}]},{"kind":"pass","points":[{"x":420,"y":570},{"x":425,"y":140}]},{"kind":"run","points":[{"x":200,"y":640},{"x":200,"y":900}]},{"kind":"run","points":[{"x":640,"y":640},{"x":630,"y":845},{"x":700,"y":900}]},{"kind":"pass","points":[{"x":640,"y":550},{"x":640,"y":100}]}]}''',
    xml:
        r'''<mxGraphModel background="#2E7D32" csEngine="v2"><root><mxCell id="0"/><mxCell id="1" parent="0"/><mxCell id="2" value="" style="fillColor=#2E7D32;strokeColor=none;" vertex="1" parent="1"><mxGeometry x="0" y="0" width="700" height="572" as="geometry"/></mxCell><mxCell id="3" value="WALL" style="rounded=0;whiteSpace=wrap;html=1;fillColor=#455A64;strokeColor=#B0BEC5;strokeWidth=3;fontColor=#ffffff;fontSize=16;fontStyle=1;" vertex="1" parent="1"><mxGeometry x="34" y="34" width="632" height="35.6" as="geometry"/></mxCell><mxCell id="4" value="" style="edgeStyle=none;html=1;endArrow=open;endFill=0;dashed=1;dashPattern=8 4;strokeColor=#FFD700;strokeWidth=2.5;" edge="1" parent="1"><mxGeometry relative="1" as="geometry"><mxPoint x="113" y="326.9" as="sourcePoint"/><mxPoint x="113" y="78.5" as="targetPoint"/></mxGeometry></mxCell><mxCell id="5" value="" style="edgeStyle=none;html=1;endArrow=open;endFill=0;dashed=1;dashPattern=8 4;strokeColor=#FFD700;strokeWidth=2.5;" edge="1" parent="1"><mxGeometry relative="1" as="geometry"><mxPoint x="288.8" y="332.9" as="sourcePoint"/><mxPoint x="288.8" y="81.4" as="targetPoint"/></mxGeometry></mxCell><mxCell id="6" value="" style="edgeStyle=none;html=1;endArrow=block;endFill=1;strokeColor=#ffffff;strokeWidth=2.5;" edge="1" parent="1"><mxGeometry relative="1" as="geometry"><mxPoint x="113" y="392.9" as="sourcePoint"/><mxPoint x="113" y="537.6" as="targetPoint"/></mxGeometry></mxCell><mxCell id="7" value="" style="edgeStyle=none;curved=1;html=1;endArrow=block;endFill=1;strokeColor=#ffffff;strokeWidth=2.5;" edge="1" parent="1"><mxGeometry relative="1" as="geometry"><mxPoint x="452.2" y="388.5" as="sourcePoint"/><mxPoint x="508" y="537.6" as="targetPoint"/><Array as="points"><mxPoint x="409.6" y="497.3"/><mxPoint x="419.1" y="562.8"/></Array></mxGeometry></mxCell><mxCell id="8" value="" style="edgeStyle=none;html=1;endArrow=open;endFill=0;dashed=1;dashPattern=8 4;strokeColor=#FFD700;strokeWidth=2.5;" edge="1" parent="1"><mxGeometry relative="1" as="geometry"><mxPoint x="462.6" y="330.7" as="sourcePoint"/><mxPoint x="462.6" y="78.5" as="targetPoint"/></mxGeometry></mxCell><mxCell id="9" value="" style="triangle;direction=north;whiteSpace=wrap;html=1;fillColor=#FF6D00;gradientColor=#FFAB40;gradientDirection=north;strokeColor=#E65100;shadow=1;" vertex="1" parent="1"><mxGeometry x="100" y="492.5" width="26" height="31" as="geometry"/></mxCell><mxCell id="10" value="" style="triangle;direction=north;whiteSpace=wrap;html=1;fillColor=#FF6D00;gradientColor=#FFAB40;gradientDirection=north;strokeColor=#E65100;shadow=1;" vertex="1" parent="1"><mxGeometry x="265.9" y="498.4" width="26" height="31" as="geometry"/></mxCell><mxCell id="11" value="" style="triangle;direction=north;whiteSpace=wrap;html=1;fillColor=#FF6D00;gradientColor=#FFAB40;gradientDirection=north;strokeColor=#E65100;shadow=1;" vertex="1" parent="1"><mxGeometry x="431.8" y="489.5" width="26" height="31" as="geometry"/></mxCell><mxCell id="12" value="" style="triangle;direction=north;whiteSpace=wrap;html=1;fillColor=#FF6D00;gradientColor=#FFAB40;gradientDirection=north;strokeColor=#E65100;shadow=1;" vertex="1" parent="1"><mxGeometry x="597.7" y="495.5" width="26" height="31" as="geometry"/></mxCell><mxCell id="13" value="1" style="ellipse;whiteSpace=wrap;html=1;aspect=fixed;fontSize=15;fontStyle=1;fillColor=#C62828;gradientColor=#EF5350;gradientDirection=north;strokeColor=#B71C1C;shadow=1;fontColor=#ffffff;" vertex="1" parent="1"><mxGeometry x="91" y="337.9" width="44" height="44" as="geometry"/></mxCell><mxCell id="14" value="2" style="ellipse;whiteSpace=wrap;html=1;aspect=fixed;fontSize=15;fontStyle=1;fillColor=#C62828;gradientColor=#EF5350;gradientDirection=north;strokeColor=#B71C1C;shadow=1;fontColor=#ffffff;" vertex="1" parent="1"><mxGeometry x="264.8" y="343.8" width="44" height="44" as="geometry"/></mxCell><mxCell id="15" value="3" style="ellipse;whiteSpace=wrap;html=1;aspect=fixed;fontSize=15;fontStyle=1;fillColor=#C62828;gradientColor=#EF5350;gradientDirection=north;strokeColor=#B71C1C;shadow=1;fontColor=#ffffff;" vertex="1" parent="1"><mxGeometry x="420.5" y="334.9" width="44" height="44" as="geometry"/></mxCell><mxCell id="16" value="4" style="ellipse;whiteSpace=wrap;html=1;aspect=fixed;fontSize=15;fontStyle=1;fillColor=#C62828;gradientColor=#EF5350;gradientDirection=north;strokeColor=#B71C1C;shadow=1;fontColor=#ffffff;" vertex="1" parent="1"><mxGeometry x="472.5" y="334.9" width="44" height="44" as="geometry"/></mxCell></root></mxGraphModel>''',
  ),
];
