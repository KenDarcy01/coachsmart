import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:coach_smart_v2/v3/create_team/v3_create_team_models.dart';
import 'package:coach_smart_v2/v3/create_team/v3_create_team_page.dart';

Map<String, dynamic> sample({Map<String, dynamic>? extra}) => {
      'user': {'first_name': 'Ken', 'last_name': 'Darcy'},
      'clubs': [
        {'club_id': 1, 'club_name': 'Clontarf GAA'},
        {'club_id': 2, 'club_name': 'Raheny GAA'},
      ],
      'codes': [
        {'code_id': 2, 'name': 'Football'},
        {'code_id': 3, 'name': 'Hurling'},
        {'code_id': 9, 'name': 'S&C'},
      ],
      'result': {'team_id': 77, 'team_unique_code': 'TMAB2CD'},
      ...?extra,
    };

Future<void> pump(WidgetTester tester, Map<String, dynamic> data) async {
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(home: V3CreateTeamPage(testData: data)));
  await tester.pumpAndSettle();
}

void main() {
  group('models', () {
    test('parse clubs and codes', () {
      expect(parseClubs(sample()['clubs']).map((c) => c.clubName),
          ['Clontarf GAA', 'Raheny GAA']);
      expect(parseCodes(sample()['codes']).length, 3);
      expect(parseCodes(null), isEmpty);
    });

    test('filter clubs', () {
      final clubs = parseClubs(sample()['clubs']);
      expect(filterClubs(clubs, 'rah').single.clubId, 2);
      expect(filterClubs(clubs, '').length, 2);
    });

    test('code labels for a female team', () {
      expect(codeLabel('Hurling', true), 'Camogie');
      expect(codeSub('Hurling', true), ''); // same as the label
      expect(codeSub('Hurling', false), ''); // same as the label
      expect(codeSub('Football', true), 'Ladies / girls football');
      expect(codeSub('Football', false), 'Gaelic football');
      expect(codeSub('S&C', false), 'Strength and conditioning');
    });

    test('default codes', () {
      final codes = parseCodes(sample()['codes']);
      expect(defaultCodeIds(codes, null), [2, 3]);
      expect(defaultCodeIds(codes, [9, 44]), [9]);
      expect(defaultCodeIds([const CtCode(9, 'S&C')], null), [9]);
      expect(defaultCodeIds(codes, [44]), [2, 3]);
    });

    test('squad checks', () {
      expect(squadsError([]), isNull);
      expect(squadsError([CtSquad('Blue', '#2F6FD6'), CtSquad(' ', '#fff')]),
          'Give every squad a name, or lower the number of squads.');
      expect(squadsError([CtSquad('no team', '#2F6FD6')]),
          'No Team is added for you. Pick another name.');
      expect(squadsError([CtSquad('Blue', '#2F6FD6'), CtSquad('blue ', '#1')]),
          'Two squads have the same name.');
    });

    test('next squad colour skips used ones', () {
      expect(nextSquadColour([]), '#2F6FD6');
      expect(nextSquadColour([CtSquad('a', '#2F6FD6')]), '#D63B3B');
    });

    test('create params', () {
      final d = CreateTeamDraft(
          firstName: 'Ken',
          lastName: 'Darcy',
          clubId: 1,
          teamName: 'U13 Boys',
          juvenile: true,
          codeIds: [2],
          squads: [CtSquad(' Blue ', '#2F6FD6')]);
      final p = createTeamParams(d, clubHasCodes: true);
      expect(p['p_club_id'], 1);
      expect(p['p_team_juvenile'], true);
      expect(p['p_car_pooling_allowed'], false);
      expect(p['p_code_ids'], [2]);
      expect(p['p_squads'], [
        {'name': 'Blue', 'colour': '#2F6FD6'}
      ]);
      expect(createTeamParams(d, clubHasCodes: false)['p_code_ids'], isNull);
      expect(teamCodeFrom({'team_unique_code': 'TMX'}), 'TMX');
    });

    test('draft round trip', () {
      final d = CreateTeamDraft(
          clubId: 1,
          clubName: 'Clontarf GAA',
          teamName: 'U13',
          female: true,
          codeIds: [2, 3],
          squads: [CtSquad('Blue', '#2f6fd6')]);
      final back = CreateTeamDraft.fromJson(d.toJson());
      expect(back.clubId, 1);
      expect(back.female, true);
      expect(back.codeIds, [2, 3]);
      expect(back.squads.single.colour, '#2F6FD6');
      expect(back.worthResuming, true);
      expect(CreateTeamDraft().worthResuming, false);
    });

    test('colours', () {
      expect(hslToHex(0, 1, 0.5), '#FF0000');
      expect(textOnHex('#F1F4F8'), const Color(0xFF111418));
      expect(textOnHex('#1A1A1A'), const Color(0xFFFFFFFF));
      final (h, l) = hexToHueLight('#FF0000');
      expect(h, 0);
      expect(l, 0.5);
    });
  });

  testWidgets('walks the whole flow and shows the team code', (tester) async {
    await pump(tester, sample());
    expect(find.text('Select your club'), findsOneWidget);

    await tester.enterText(find.byType(TextField).first, 'clon');
    await tester.pump();
    expect(find.text('Raheny GAA'), findsNothing);
    await tester.tap(find.text('Clontarf GAA'));
    await tester.pump();
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();

    expect(find.text('Team details'), findsOneWidget);
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    expect(find.text('Please enter a team name.'), findsOneWidget);

    await tester.enterText(find.byKey(const ValueKey('ct-team-name')), 'U13');
    await tester.tap(find.text('Female team'));
    await tester.pump();
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();

    expect(find.text('What does this team play?'), findsOneWidget);
    expect(find.text('Camogie'), findsOneWidget);
    // Untick both main codes: an error.
    await tester.tap(find.text('Football'));
    await tester.tap(find.text('Camogie'));
    await tester.pump();
    await tester.tap(find.text('Next'));
    await tester.pump();
    expect(find.text('Pick at least one code.'), findsOneWidget);
    await tester.tap(find.text('Football'));
    await tester.pump();
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();

    expect(find.text('Squads'), findsOneWidget);
    await tester.tap(find.byTooltip('More squads'));
    await tester.pump();
    await tester.tap(find.text('Create Team'));
    await tester.pump();
    expect(find.text('Give every squad a name, or lower the number of squads.'),
        findsOneWidget);
    await tester.enterText(find.byKey(const ValueKey('ct-squad-0')), 'Blue');
    await tester.tap(find.text('Create Team'));
    await tester.pumpAndSettle();

    expect(find.text('U13 — Created!'), findsOneWidget);
    expect(find.text('TMAB2CD'), findsOneWidget);
  });

  testWidgets('back walks back a step', (tester) async {
    await pump(tester, sample());
    await tester.tap(find.text('Raheny GAA'));
    await tester.pump();
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    expect(find.text('Team details'), findsOneWidget);
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    expect(find.text('Select your club'), findsOneWidget);
  });

  testWidgets('a saved draft offers to continue', (tester) async {
    await pump(
        tester,
        sample(extra: {
          'draft': {'clubId': 1, 'clubName': 'Clontarf GAA', 'teamName': 'U9'}
        }));
    expect(find.text('Continue where you left off?'), findsOneWidget);
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(find.text('Team details'), findsOneWidget);
    expect(find.text('U9'), findsOneWidget);
  });

  testWidgets('shows the create error', (tester) async {
    await pump(
        tester,
        sample(extra: {
          'codes': [],
          'error': 'That code is not used by this club',
          'draft': {'clubId': 1, 'clubName': 'Clontarf GAA', 'teamName': 'U9'}
        }));
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    // No codes for the club: straight to squads.
    expect(find.text('Squads'), findsOneWidget);
    await tester.tap(find.text('Create Team'));
    await tester.pumpAndSettle();
    expect(find.text('That code is not used by this club'), findsOneWidget);
  });
}
