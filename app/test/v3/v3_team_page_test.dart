import 'dart:ui' show ImageByteFormat;
import 'package:flutter/rendering.dart' show RenderRepaintBoundary;
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:coach_smart_v2/v3/teams/v3_team_page.dart';

// Parents and players see only their own children's squads (Ken,
// 2026-11-13). Set SHOTS=dir to also save phone-size PNGs of each view.

Map<String, dynamic> _member(
        int id, String first, String last, int? squad, String squadName) =>
    {
      'member_id': id,
      'first_name': first,
      'last_name': last,
      'squad_codes': [
        {
          'code_id': 2,
          'code_name': 'Football',
          'squad_id': squad ?? 0,
          'squad_name': squadName,
        }
      ],
    };

final _roster = {
  'team_id': 9,
  'team_name': 'Boys 2014',
  'team_unique_code': 'K7Q2MX',
  'club_id': 1,
  'club_codes': [
    {'code_id': 2, 'event_code': 'Football'}
  ],
  'role_groups': [
    {
      'role_name': 'Player',
      'role_name_plural': 'Players',
      'role_level': 10,
      'members': [
        _member(1, 'Aoife', 'Byrne', 12, 'Red'),
        _member(2, 'Cian', 'Doyle', 11, 'Blue'),
        _member(3, 'Darragh', 'Kelly', 13, 'Green'),
        _member(4, 'Eoin', 'Walsh', 11, 'Blue'),
        _member(5, 'Fionn', 'Murphy', 12, 'Red'),
        _member(6, 'Liam', 'Nolan', 13, 'Green'),
        _member(7, 'Oisín', 'Ryan', 11, 'Blue'),
        _member(8, 'Seán', 'Brady', 12, 'Red'),
      ],
    },
    {
      'role_name': 'Coach',
      'role_name_plural': 'Coaches',
      'role_level': 30,
      'members': [_member(20, 'Mary', 'Byrne', null, '')],
    },
    {
      'role_name': 'Admin',
      'role_name_plural': 'Admins',
      'role_level': 100,
      'members': [_member(21, 'Paul', 'Kelly', null, '')],
    },
  ],
};

const _squads = [
  {'squad_id': 11, 'name': 'Blue', 'colour': '#2F6FD6'},
  {'squad_id': 12, 'name': 'Red', 'colour': '#D64545'},
  {'squad_id': 13, 'name': 'Green', 'colour': '#3BA55C'},
];

Future<void> _loadFonts() async {
  final dir = Platform.environment['SHOT_FONTS'];
  if (dir == null) return;
  for (final f in Directory(dir).listSync().whereType<File>()) {
    if (!f.path.endsWith('.ttf') && !f.path.endsWith('.otf')) continue;
    final name = f.uri.pathSegments.last.split('.').first;
    final family = name == 'MaterialIcons-Regular' ? 'MaterialIcons' : name;
    final loader = FontLoader(family)
      ..addFont(Future.value(ByteData.view(f.readAsBytesSync().buffer)));
    await loader.load();
  }
}

Future<void> _pump(WidgetTester t, int role) async {
  t.view.physicalSize = const Size(390 * 3, 1100 * 3);
  t.view.devicePixelRatio = 3;
  await t.pumpWidget(MaterialApp(
      debugShowCheckedModeBanner: false,
      home: RepaintBoundary(
          child: V3TeamPage(teamId: 9, testData: {
        'roster': _roster,
        'role': role,
        'squads': _squads,
        'mine': [1], // Aoife is the signed-in parent's child
      }))));
  await t.pumpAndSettle();
}

Future<void> _shot(WidgetTester t, String name) async {
  final dir = Platform.environment['SHOTS'];
  if (dir == null) return;
  await t.runAsync(() async {
    final ro = t.firstRenderObject<RenderRepaintBoundary>(
        find.byType(RepaintBoundary).first);
    final img = await ro.toImage(pixelRatio: 2);
    final png = await img.toByteData(format: ImageByteFormat.png);
    File('$dir/$name.png').writeAsBytesSync(png!.buffer.asUint8List());
  });
}

void main() {
  setUpAll(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    await _loadFonts();
  });

  testWidgets('parent sees only their own child\'s squad', (t) async {
    await _pump(t, 10);
    expect(find.text('Aoife Byrne'), findsOneWidget);
    expect(find.text('Cian Doyle'), findsOneWidget);
    expect(find.text('Red'), findsOneWidget); // Aoife's only
    expect(find.text('Blue'), findsNothing);
    expect(find.text('Green'), findsNothing);
    await _shot(t, 'team-parent');
  });

  testWidgets('coach sees every squad', (t) async {
    await _pump(t, 30);
    expect(find.text('Blue'), findsWidgets);
    expect(find.text('Green'), findsWidgets);
    await _shot(t, 'team-coach');
  });
}
