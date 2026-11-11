import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:coach_smart_v2/v3/lineup/v3_lineup_models.dart';
import 'package:coach_smart_v2/v3/lineup/v3_lineup_page.dart';
import 'package:coach_smart_v2/v3/lineup/v3_lineup_paint.dart';
import 'package:coach_smart_v2/v3/lineup/v3_teamsheet.dart';

Map<String, dynamic> sample({bool saved = true}) => {
      'team_name': 'U14 Girls',
      'teamsheet': true,
      'club': {
        'primary_colour': '#004a2f',
        'secondary_colour': 'ffd700',
        'third_colour': '#004a2f',
      },
      'image_sub': 'Football Match  ·  15 Nov 2026',
      'players': [
        {'member_id': 1, 'name': 'Aimee Morris'},
        {'member_id': 2, 'name': 'Anna Ryan'},
        {'member_id': 3, 'name': 'Fiadh Nolan'},
        {'member_id': 4, 'name': 'Saoirse Ní Bhriain'},
      ],
      if (saved)
        'lineup': {
          'format': 13,
          'details': [
            {'member_id': 1, 'position_num': 1, 'is_sub': false},
            {'member_id': 2, 'position_num': 2, 'is_sub': true},
            // Not in this squad any more: dropped.
            {'member_id': 99, 'position_num': 5, 'is_sub': false},
          ],
        },
    };

void main() {
  widgetTests();

  test('data: players sorted, club colours, saved lineup restored', () {
    final d = LineupData.fromJson(sample());
    expect(d.players.map((p) => p.name).first, 'Aimee Morris');
    expect(d.kit.primary, const Color(0xFF004A2F));
    expect(d.kit.stripe, const Color(0xFFFFD700));
    // Third colour same as primary: keeper in white.
    expect(d.kit.keeper, const Color(0xFFFFFFFF));
    final b = d.initialBoard();
    expect(b.format, 13);
    expect(b.assign, {1: 1});
    expect(b.subs, {2: 2});
    expect(
        LineupData.fromJson({'message': 'No eligible players found'})
            .hasMessage,
        isTrue);
    expect(KitColours.fromClub(null).primary, const Color(0xFFCC0000));
  });

  test('drops: swap on the pitch, strip displaces to the bench', () {
    final b = LineupBoard(assign: {1: 10, 2: 20}, subs: {1: 30});
    // Pitch to pitch: swap.
    b.dropOnPosition(const LineupDrag(10, DragFrom.pos, 1), 2);
    expect(b.assign, {1: 20, 2: 10});
    // Strip onto a filled spot: the old player goes to the first free sub.
    b.dropOnPosition(const LineupDrag(40, DragFrom.strip), 2);
    expect(b.assign[2], 40);
    expect(b.subs, {1: 30, 2: 10});
    // Sub onto the pitch: swaps with the pitch player.
    b.dropOnPosition(const LineupDrag(30, DragFrom.sub, 1), 1);
    expect(b.assign[1], 30);
    expect(b.subs[1], 20);
    // Pitch onto an empty sub slot: leaves the pitch.
    b.dropOnSub(const LineupDrag(40, DragFrom.pos, 2), 4);
    expect(b.assign.containsKey(2), isFalse);
    expect(b.subs[4], 40);
    // Back to the strip.
    b.remove(const LineupDrag(40, DragFrom.sub, 4));
    expect(b.onPitch(40), isFalse);
  });

  test('format change keeps positions that exist, subs stay', () {
    final b = LineupBoard(assign: {1: 1, 12: 2, 15: 3}, subs: {1: 4});
    b.setFormat(11);
    expect(b.assign, {1: 1});
    expect(b.subs, {1: 4});
    expect(subShirt(11, 1), 12);
    expect(subShirt(15, 5), 20);
  });

  test('lineup_details rows', () {
    final b = LineupBoard(format: 9, assign: {3: 7}, subs: {2: 8});
    expect(b.details(5), [
      {
        'lineup_id': 5,
        'member_id': 7,
        'position_num': 3,
        'position_label': 'FB',
        'is_sub': false
      },
      {
        'lineup_id': 5,
        'member_id': 8,
        'position_num': 2,
        'position_label': 'SUB',
        'is_sub': true
      },
    ]);
  });

  test('load helpers match the web page', () {
    expect(
        latestMemberIds([
          {'member_id': 3},
          {'member_id': 1},
          {'member_id': 3}
        ]),
        [3, 1]);
    expect(
        attendingMemberIds([
          {'member_id': 1, 'response_id': 3},
          {'member_id': 1, 'response_id': 4},
          {'member_id': 2, 'response_id': 4},
          {'member_id': 2, 'response_id': 3},
        ]),
        [1]);
    expect(
        membersWithRoleLevel([
          {
            'member_id': 1,
            'member_team_role_link': [
              {
                'roles': {'role_level': 10}
              }
            ]
          },
          {
            'member_id': 2,
            'member_team_role_link': [
              {
                'roles': {'role_level': 30}
              }
            ]
          },
        ], {
          10
        }),
        {1});
    expect(shortName('Adam Lynch'), 'Adam L.');
    expect(shortName('Cher'), 'Cher');
    expect(nameLines('Saoirse Ní Bhriain'), ['Saoirse', 'Ní Bhriain']);
    expect(imageSubtitle('Football', 'Match', DateTime(2026, 11, 15)),
        'Football Match  ·  15 Nov 2026');
    expect(lineupFileName('U14 Girls'), 'CoachSmart_U14_Girls_lineup.png');
    expect(numberColour(const Color(0xFFFFFFFF)), const Color(0xFF000000));
    expect(numberColour(const Color(0xFF004A2F)), const Color(0xFFFFFFFF));
  });

  test('teamsheet helpers and PDF', () async {
    expect(tsDob('2012-03-04'), '04/03/2012');
    expect(tsDob(null), 'blank');
    expect(pdfSafe('Ní Łucja'), 'Ní ?ucja');
    expect(
        teamsheetFileName('U14 Girls'), 'CoachSmart_U14_Girls_teamsheet.pdf');
    final bytes = await buildTeamsheetPdf(
        const TeamsheetData(
            clubIrish: 'Cluain Tarbh',
            teamName: 'U14 Girls',
            players: [
              TsPerson('Aoife de Búrca', 'Aoife Burke', 'blank', '01/02/2012')
            ],
            managers: [
              TsPerson('Ciarán Ó Dálaigh', 'Kieran Daly', '123')
            ]),
        DateTime(2026, 11, 11, 9, 30));
    expect(String.fromCharCodes(bytes.take(4)), '%PDF');
  });

  testWidgets('share image renders', (tester) async {
    await tester.runAsync(() async {
      final d = LineupData.fromJson(sample());
      final png = await renderLineupPng(d, d.initialBoard(), scale: 1);
      expect(png.length, greaterThan(1000));
    });
  });
}

void widgetTests() {
  Future<void> pump(WidgetTester tester, Map<String, dynamic> data) async {
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
        MaterialApp(home: V3LineupPage(eventId: 1, teamId: 7, testData: data)));
    await tester.pumpAndSettle();
  }

  testWidgets('lineup page: formats, strip, saved lineup, bench',
      (tester) async {
    await pump(tester, sample());
    expect(find.text('Lineup'), findsOneWidget);
    expect(find.text('Teamsheet'), findsOneWidget);
    expect(find.text('Previous lineup loaded'), findsOneWidget);
    for (final f in ['9', '11', '13', '15']) {
      expect(find.text(f), findsWidgets);
    }
    // Strip lists everyone; the bench shows the short name of sub 2.
    expect(find.text('Anna Ryan'), findsOneWidget);
    expect(find.text('Anna R.'), findsOneWidget);
    // The keeper's name sits under the jersey on the pitch.
    expect(find.text('Morris'), findsOneWidget);
    expect(find.text('Save'), findsOneWidget);
    expect(find.text('Share'), findsOneWidget);
  });

  testWidgets('tap an empty position to pick a player, drag to the bench',
      (tester) async {
    await pump(tester, sample(saved: false));
    expect(find.text('4 players loaded'), findsOneWidget);
    expect(find.text('Teamsheet'), findsOneWidget);
    // FF (position 14 in 15-a-side) is empty: tap it and pick Fiadh.
    // The label sits under the jersey and ignores taps: tap the jersey.
    await tester.tapAt(tester.getCenter(find.text('FF')) - const Offset(0, 22));
    await tester.pumpAndSettle();
    expect(find.text('Position 14 · FF'), findsOneWidget);
    await tester.tap(find.text('Fiadh Nolan').last);
    await tester.pumpAndSettle();
    expect(find.text('Nolan'), findsOneWidget);

    // Drag Anna from the strip down to sub slot 1 (shirt 16).
    final from = tester.getCenter(find.text('Anna Ryan'));
    final to = tester.getCenter(find.text('16'));
    final g = await tester.startGesture(from);
    await tester.pump(const Duration(milliseconds: 50));
    await g.moveBy(const Offset(0, 40));
    await tester.pump();
    await g.moveTo(to);
    await tester.pump();
    await g.up();
    await tester.pumpAndSettle();
    expect(find.text('Anna R.'), findsOneWidget);
  });

  testWidgets('empty state uses the web wording', (tester) async {
    await pump(tester, {'message': 'No players have accepted for this event'});
    expect(
        find.text('No players have accepted for this event'), findsOneWidget);
    expect(find.text('Save'), findsNothing);
  });
}
