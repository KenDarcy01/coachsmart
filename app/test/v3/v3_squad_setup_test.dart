import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:coach_smart_v2/v3/teams/v3_squad_setup_models.dart';
import 'package:coach_smart_v2/v3/teams/v3_squad_setup_page.dart';

Map<String, dynamic> sample() => {
      'team_id': 7,
      'team_name': 'Under 12 Boys',
      'club_name': 'Clontarf GAA',
      'squads': [
        {'squad_id': 1, 'name': 'Blues', 'colour': '#2F6FD6', 'players': 14},
        {
          'squad_id': 2,
          'name': 'Reds',
          'colour': '#D63B3B',
          'players': 13,
          'grade': 'B'
        },
        {
          'squad_id': 9,
          'name': 'No Team',
          'colour': '#9AA0A6',
          'players': 3,
          'no_team': true
        },
      ],
      'disabled': [
        {
          'squad_id': 4,
          'name': 'Oranges',
          'colour': '#F07B22',
          'disabled_at': '2026-11-03T10:00:00Z',
          'past_events': 21
        },
      ],
    };

class FakeApi extends SquadSetupApi {
  FakeApi();
  final calls = <String>[];
  Map<String, dynamic> data = sample();

  @override
  Future<SquadSetup> load(int teamId) async => SquadSetup.fromJson(data);

  @override
  Future<SquadSetup> save(int teamId, int? squadId, String name, String colour,
      {String grade = ''}) async {
    calls.add('save $squadId $name $colour $grade');
    return load(teamId);
  }

  @override
  Future<SquadSetup> reorder(int teamId, List<int> squadIds) async {
    calls.add('reorder $squadIds');
    return load(teamId);
  }

  @override
  Future<SquadSetup> disable(int teamId, int squadId) async {
    calls.add('disable $squadId');
    return load(teamId);
  }

  @override
  Future<SquadSetup> enable(int teamId, int squadId) async {
    calls.add('enable $squadId');
    return load(teamId);
  }
}

Future<FakeApi> pump(WidgetTester t) async {
  t.view.physicalSize = const Size(390 * 3, 1100 * 3);
  t.view.devicePixelRatio = 3;
  addTearDown(t.view.reset);
  final api = FakeApi();
  await t.pumpWidget(MaterialApp(home: V3SquadSetupPage(teamId: 7, api: api)));
  await t.pumpAndSettle();
  return api;
}

void main() {
  test('parses active, No Team and turned-off squads', () {
    final d = SquadSetup.fromJson(sample());
    expect(d.movable.map((s) => s.name), ['Blues', 'Reds']);
    expect(d.noTeam?.squadId, 9);
    expect(d.squads[1].grade, 'B');
    expect(d.disabled.single.pastEvents, 21);
    expect(disabledLine(d.disabled.single), 'Off since 3 Nov · 21 past events');
    expect(playersLine(0), 'No players yet');
    expect(playersLine(1), '1 player');
  });

  test('name rules', () {
    final d = SquadSetup.fromJson(sample());
    final all = [...d.squads, ...d.disabled];
    expect(squadNameError(' ', all), 'Give the squad a name.');
    expect(squadNameError('no team', all), 'That name is kept for No Team.');
    expect(
        squadNameError('blues', all), 'There is already a squad called Blues.');
    expect(squadNameError('Oranges', all), isNotNull);
    expect(squadNameError('Blues', all, squadId: 1), isNull);
    expect(squadNameError('Greens', all), isNull);
  });

  testWidgets('shows squads, No Team and turned off', (t) async {
    await pump(t);
    expect(find.text('Blues'), findsOneWidget);
    expect(find.text('14 players'), findsOneWidget);
    expect(find.text('3 players not placed yet'), findsOneWidget);
    expect(find.text('TURNED OFF'), findsOneWidget);
    expect(find.text('Off since 3 Nov · 21 past events'), findsOneWidget);
  });

  testWidgets('add a squad', (t) async {
    final api = await pump(t);
    await t.tap(find.byKey(const ValueKey('ss-add')));
    await t.pumpAndSettle();
    expect(find.text('Add a squad'), findsWidgets);
    await t.tap(find.byKey(const ValueKey('ss-save')));
    await t.pump();
    expect(find.text('Give the squad a name.'), findsOneWidget);
    await t.enterText(find.byKey(const ValueKey('ss-name')), 'Greens');
    await t.tap(find.byKey(const ValueKey('ss-save')));
    await t.pumpAndSettle();
    expect(api.calls.single, startsWith('save null Greens #'));
  });

  testWidgets('edit keeps the grade', (t) async {
    final api = await pump(t);
    await t.tap(find.byKey(const ValueKey('ss-edit-2')));
    await t.pumpAndSettle();
    await t.enterText(find.byKey(const ValueKey('ss-name')), 'Reds Two');
    await t.tap(find.byKey(const ValueKey('ss-save')));
    await t.pumpAndSettle();
    expect(api.calls.single, 'save 2 Reds Two #D63B3B B');
  });

  testWidgets('turn off asks first, turn on', (t) async {
    final api = await pump(t);
    await t.tap(find.byKey(const ValueKey('ss-edit-2')));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const ValueKey('ss-off')));
    await t.pumpAndSettle();
    expect(find.text('Turn off Reds?'), findsOneWidget);
    expect(api.calls, isEmpty);
    await t.tap(find.byKey(const ValueKey('ss-confirm-off')));
    await t.pumpAndSettle();
    expect(api.calls, ['disable 2']);
    await t.tap(find.byKey(const ValueKey('ss-on-4')));
    await t.pumpAndSettle();
    expect(api.calls.last, 'enable 4');
  });
}
