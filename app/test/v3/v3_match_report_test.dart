import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:coach_smart_v2/v3/match_report/v3_match_report_models.dart';
import 'package:coach_smart_v2/v3/match_report/v3_match_report_page.dart';
import 'package:coach_smart_v2/v3/match_report/v3_voice_sheet.dart';

Map<String, dynamic> sample(
        {List squads = const [
          {'squad_id': 11, 'squad_name': 'Blue'},
          {'squad_id': 12, 'squad_name': 'Red'},
        ],
        bool ai = true,
        List? reports = const [
          {
            'id': 5,
            'created_at': '2026-11-08T14:30:00Z',
            'author': 'Ken Darcy',
            'squad_name': 'Blue',
            'opposition': 'Raheny',
            'report': 'A great win in the wind. Aoife scored two goals.',
          }
        ]}) =>
    {
      'event': {
        'event_id': 1,
        'event_title': 'U12 Football Match',
        'event_date_time': '2026-11-08T11:00:00Z',
        'home_away': 'home',
      },
      'team_name': 'Clontarf U12 Girls',
      'squads': squads,
      'ai_enabled': ai,
      'reports': reports,
    };

/// Records nothing; hands back a fixed phrase when released.
class FakeDictation extends V3Dictation {
  FakeDictation(this.words);
  final String words;
  @override
  Future<bool> start() async => true;
  @override
  Future<String> stop() async => words;
  @override
  void dispose() {}
}

Future<void> pump(WidgetTester t, Widget w) async {
  t.view.physicalSize = const Size(1170, 2532);
  t.view.devicePixelRatio = 3;
  addTearDown(t.view.reset);
  await t.pumpWidget(MaterialApp(home: w));
  await t.pumpAndSettle();
}

void main() {
  group('models', () {
    test('load parses and applies the squad rule', () {
      final d = MrLoad.fromJson(sample());
      expect(d.title, 'U12 Football Match');
      expect(d.subtitle, startsWith('Clontarf U12 Girls · '));
      expect(d.needsSquad, isTrue);
      expect(d.showSquadPicker, isTrue);
      expect(d.initialSquadId, isNull);
      expect(d.reports, hasLength(1));
      expect(d.reports!.first.subtitle, contains('Blue · v Raheny'));

      final one = MrLoad.fromJson(sample(squads: [
        {'squad_id': 11, 'squad_name': 'Blue'}
      ]));
      expect(one.needsSquad, isFalse);
      expect(one.showSquadPicker, isFalse);
      expect(one.initialSquadId, 11);

      final none = MrLoad.fromJson(sample(squads: [], reports: null));
      expect(none.needsSquad, isFalse);
      expect(none.initialSquadId, isNull);
      expect(none.showReports, isFalse);
    });

    test('save checks in the web order', () {
      expect(
          saveProblem(
              needsSquad: true, squadId: null, opposition: '', report: ''),
          'Please select a squad');
      expect(
          saveProblem(
              needsSquad: true, squadId: 11, opposition: ' ', report: ''),
          'Please enter the opposition');
      expect(
          saveProblem(
              needsSquad: false,
              squadId: null,
              opposition: 'Raheny',
              report: ' '),
          'The match report is empty');
      expect(
          saveProblem(
              needsSquad: false,
              squadId: null,
              opposition: 'Raheny',
              report: 'ok'),
          isNull);
    });

    test('voice body drafts first, then revises', () {
      final a = voiceBody(
          current: '', transcript: 'we won', squadId: 11, opposition: ' ');
      expect(a['action'], 'draft');
      expect(a['transcript'], 'we won');
      expect(a['opposition'], isNull);
      final b = voiceBody(
          current: 'We won.',
          transcript: 'add Aoife',
          squadId: null,
          opposition: 'Raheny');
      expect(b['action'], 'revise');
      expect(b['report'], 'We won.');
      expect(b['changes'], 'add Aoife');
      expect(b['opposition'], 'Raheny');
      expect(MrVoiceText.forReport('').submit, 'Write report');
      expect(MrVoiceText.forReport('x').submit, 'Update');
    });

    test('unwrap, fillers and meta', () {
      expect(
          unwrapMr({
            'success': true,
            'data': {'a': 1}
          }),
          {'a': 1});
      expect(() => unwrapMr({'error': 'Match not found'}),
          throwsA(isA<MrError>()));
      expect(cleanSpeech('um we uh won  the match'), 'we won the match');
      expect(appendSpoken('Hello ', 'there'), 'Hello there');
      final r = MrReport.fromJson({'author': 'Ken', 'report': 'x'});
      expect(r.meta.map((e) => e.key), ['By']);
    });
  });

  group('page', () {
    testWidgets('shows the form, the AI box and the reports list', (t) async {
      await pump(t, V3MatchReportPage(eventId: 1, testData: sample()));
      expect(find.text('Match Report'), findsOneWidget);
      expect(find.text('U12 Football Match'), findsOneWidget);
      expect(find.text('Select a squad'), findsOneWidget);
      expect(find.text('TALK THROUGH THE MATCH'), findsOneWidget);
      await t.scrollUntilVisible(find.text('Ken Darcy'), 200,
          scrollable: find.byType(Scrollable).first);
      expect(find.text('Ken Darcy'), findsOneWidget);
      expect(find.text('Save Match Report'), findsOneWidget);

      await t.tap(find.text('Ken Darcy'));
      await t.pumpAndSettle();
      expect(find.text('A great win in the wind. Aoife scored two goals.'),
          findsOneWidget);
      expect(find.text('Raheny'), findsOneWidget);
    });

    testWidgets('no AI and no list below role 100', (t) async {
      await pump(
          t,
          V3MatchReportPage(
              eventId: 1,
              testData: sample(ai: false, reports: null, squads: [
                {'squad_id': 11, 'squad_name': 'Blue'}
              ])));
      expect(find.text('TALK THROUGH THE MATCH'), findsNothing);
      expect(find.text('REPORTS FOR THIS MATCH'), findsNothing);
      expect(find.text('SQUAD'), findsNothing);
      expect(find.text('Type your match report…'), findsOneWidget);
    });

    testWidgets('save validates, then sends the fields', (t) async {
      final sent = <Map<String, dynamic>>[];
      await pump(
          t,
          V3MatchReportPage(
              eventId: 1,
              testData: sample(),
              testCall: (b) async {
                sent.add(b);
                return {
                  'success': true,
                  'data': {'id': 9, 'emailed': true}
                };
              }));
      await t.tap(find.byKey(const ValueKey('save')));
      await t.pumpAndSettle();
      expect(find.text('Please select a squad'), findsWidgets);
      await t.tap(find.text('Red').last);
      await t.pumpAndSettle();

      await t.enterText(find.byKey(const ValueKey('opposition')), 'Raheny');
      await t.enterText(find.byKey(const ValueKey('report')), 'We won.');
      await t.tap(find.byKey(const ValueKey('save')));
      await t.pump();
      await t.pump(const Duration(seconds: 2));
      await t.pumpAndSettle();
      expect(sent, hasLength(1));
      expect(sent.first, {
        'event_id': 1,
        'action': 'save',
        'report': 'We won.',
        'squad_id': 12,
        'opposition': 'Raheny',
      });
    });

    testWidgets('voice panel drafts the report, then undo', (t) async {
      final sent = <Map<String, dynamic>>[];
      await pump(
          t,
          V3MatchReportPage(
              eventId: 1,
              testData: sample(),
              testDictation: FakeDictation('we won by three points'),
              testCall: (b) async {
                sent.add(b);
                return {
                  'success': true,
                  'data': {'report': 'We won by three points.'}
                };
              }));
      await t.tap(find.byKey(const ValueKey('voice-rest')));
      await t.pumpAndSettle();
      expect(find.text('Write report'), findsOneWidget);

      final mic = t.getCenter(find.byKey(const ValueKey('voice-mic')));
      final g = await t.startGesture(mic);
      await t.pump();
      await g.up();
      await t.pumpAndSettle();
      expect(find.text('we won by three points'), findsOneWidget);

      await t.tap(find.byKey(const ValueKey('voice-submit')));
      await t.pumpAndSettle();
      expect(sent.single['action'], 'draft');
      expect(sent.single['transcript'], 'we won by three points');
      expect(find.text('We won by three points.'), findsOneWidget);
      expect(find.text('ADD TO OR CORRECT THE REPORT'), findsOneWidget);

      await t.tap(find.text('Undo last change'));
      await t.pumpAndSettle();
      expect(find.text('We won by three points.'), findsNothing);
      expect(find.text('Undo last change'), findsNothing);
    });

    testWidgets('AI failure on the first draft keeps the spoken words',
        (t) async {
      await pump(
          t,
          V3MatchReportPage(
              eventId: 1,
              testData: sample(),
              testCall: (b) async => {'error': 'Gemini down'}));
      await t.tap(find.byKey(const ValueKey('voice-rest')));
      await t.pumpAndSettle();
      await t.enterText(
          find.byKey(const ValueKey('voice-text')), 'we lost narrowly');
      await t.pump();
      await t.tap(find.byKey(const ValueKey('voice-submit')));
      await t.pumpAndSettle();
      expect(find.text('we lost narrowly'), findsOneWidget);
      expect(find.text('AI is unavailable, so your words were added as spoken'),
          findsOneWidget);
    });
  });
}
