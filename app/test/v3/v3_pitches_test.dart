import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:coach_smart_v2/v3/pitches/v3_pitch_api.dart';
import 'package:coach_smart_v2/v3/pitches/v3_pitch_controller.dart';
import 'package:coach_smart_v2/v3/pitches/v3_pitch_models.dart';
import 'package:coach_smart_v2/v3/pitches/v3_pitches_page.dart';

// Saturday 21 November 2026, a week from the club's own sheet.
final _today = DateTime(2026, 11, 21);

List<Map<String, dynamic>> _hourly(int day, int from, int to,
        [int each = 60]) =>
    [
      for (var m = from * 60; m + each <= to * 60; m += each)
        {
          'weekday': day,
          'opens':
              '${(m ~/ 60).toString().padLeft(2, '0')}:${(m % 60).toString().padLeft(2, '0')}',
          'closes':
              '${((m + each) ~/ 60).toString().padLeft(2, '0')}:${((m + each) % 60).toString().padLeft(2, '0')}'
        }
    ];

Map<String, dynamic> _pitch(int id, String name, String venue,
        {String surface = 'grass',
        int split = 1,
        bool lights = false,
        List<Map<String, dynamic>> hours = const []}) =>
    {
      'pitch_id': id,
      'venue_id': venue.hashCode,
      'venue': venue,
      'name': name,
      'surface': surface,
      'split': split,
      'floodlit': lights,
      'hours': hours,
    };

Map<String, dynamic> _b(int id, int pitch, String from, String to, String title,
        {int part = 15,
        String kind = 'training',
        String code = 'Football',
        int? group,
        bool female = false}) =>
    {
      'booking_id': id,
      'pitch_id': pitch,
      'part': part,
      'starts_at': '2026-11-21T$from:00',
      'ends_at': '2026-11-21T$to:00',
      'kind': kind,
      'title': title,
      'status': 'confirmed',
      'code': code,
      'female': female,
      'group_id': group,
    };

Map<String, dynamic> sampleBoard() => {
      'durations': {'u12': 50, 'u16': 60, 'adult': 90, 'training': 60},
      'pitches': [
        _pitch(1, 'Clubhouse Astro', 'Clubhouse',
            surface: 'astro',
            split: 2,
            lights: true,
            hours: [
              for (var d = 1; d <= 5; d++) ..._hourly(d, 17, 21, 50),
              ..._hourly(6, 9, 17),
              ..._hourly(7, 9, 17),
            ]),
        _pitch(2, 'DCC Astro', 'Alfie Byrne Rd', surface: 'astro', hours: [
          {'weekday': 6, 'opens': '09:00', 'closes': '11:00'},
          {'weekday': 6, 'opens': '13:00', 'closes': '14:20'},
          {'weekday': 6, 'opens': '14:20', 'closes': '15:40'},
        ]),
        _pitch(3, 'Pitch 19', "St Anne's", hours: [
          {'weekday': 6, 'opens': '10:00', 'closes': '11:00'},
          {'weekday': 6, 'opens': '12:00', 'closes': '13:30'},
          {'weekday': 6, 'opens': '14:15', 'closes': '15:15'},
        ]),
        _pitch(4, 'Pitch 21', "St Anne's", hours: [
          {'weekday': 6, 'opens': '10:00', 'closes': '11:00'},
          {'weekday': 6, 'opens': '11:00', 'closes': '12:15'},
          {'weekday': 6, 'opens': '12:15', 'closes': '13:30'},
          {'weekday': 6, 'opens': '14:45', 'closes': '16:15'},
        ]),
        _pitch(5, 'Pitch 23', "St Anne's", split: 2, hours: [
          {'weekday': 6, 'opens': '08:00', 'closes': '10:00'},
          {'weekday': 6, 'opens': '11:00', 'closes': '12:00'},
          {'weekday': 6, 'opens': '12:30', 'closes': '14:00'},
          {'weekday': 6, 'opens': '17:00', 'closes': '18:00'},
        ]),
        _pitch(6, 'Pitch 30', "St Anne's", hours: [
          {'weekday': 6, 'opens': '09:30', 'closes': '11:00'},
        ]),
        _pitch(7, 'Pitch 34', "St Anne's", lights: true, hours: [
          {'weekday': 6, 'opens': '09:00', 'closes': '10:45'},
          {'weekday': 6, 'opens': '11:30', 'closes': '13:45'},
          {'weekday': 6, 'opens': '14:30', 'closes': '16:45'},
        ]),
      ],
      'closures': [
        {
          'closure_id': 1,
          'pitch_id': 6,
          'starts_on': '2026-11-21',
          'ends_on': '2026-11-22',
          'reason': 'Waterlogged'
        }
      ],
      'bookings': [
        _b(1, 1, '09:00', '10:00', '', group: 1),
        _b(2, 1, '10:00', '11:00', '', group: 1),
        _b(3, 1, '11:00', '12:00', '', group: 2),
        _b(4, 1, '14:00', '15:00', '', group: 3),
        _b(5, 2, '09:00', '11:00', 'U12 B v St Sylvesters', kind: 'match'),
        _b(6, 2, '13:00', '14:20', 'U9/10 Boys'),
        _b(7, 3, '12:00', '13:30', '', group: 5, female: true),
        _b(8, 4, '11:00', '12:15', '',
            group: 4, kind: 'match', code: 'Hurling'),
        _b(9, 5, '12:30', '14:00', 'U12 Girls v Naomh Barróg',
            kind: 'match', female: true),
        _b(10, 5, '17:00', '18:00', '', group: 6, part: 3),
        _b(11, 5, '17:00', '18:00', '', group: 7, part: 3, code: 'Hurling'),
        _b(12, 7, '09:00', '10:45', '', group: 1),
      ],
      'booking_groups': {},
      'events': [
        {
          'event_id': 50,
          'team_id': 8,
          'team_name': 'Clontarf Boys 2012',
          'title': 'Match',
          'opposition': 'Raheny',
          'home_away': 'Home',
          'location': 'TBC',
          'type': 'Match',
          'code': 'Football',
          'starts_at': '2026-11-21T14:00:00',
        },
        {
          'event_id': 51,
          'team_id': 9,
          'team_name': 'Clontarf Girls 2015',
          'title': 'Training',
          'location': 'P34',
          'type': 'Training',
          'code': 'Football',
          'female': true,
          'starts_at': '2026-11-21T14:30:00',
          'matched_pitch_id': 7,
        },
        {
          // S&C in the gym: never needs a pitch.
          'event_id': 52,
          'team_id': 8,
          'team_name': 'Clontarf Boys 2012',
          'title': 'S&C',
          'location': 'Clubhouse',
          'type': 'Other',
          'code': 'S&C',
          'starts_at': '2026-11-21T10:00:00',
        },
      ],
      'fixtures': [
        {
          'game_id': 86376,
          'code': 'Camogie',
          'age': 'U21',
          'comp': 'U21 Division 2 Championship',
          'home': 'Clontarf',
          'away': 'Fingallians',
          'venue': 'Clontarf',
          'starts_at': '2026-11-22T10:30:00',
        }
      ],
      'teams': [
        {'team_id': 8, 'team_name': 'Clontarf Boys 2012'},
        {'team_id': 9, 'team_name': 'Clontarf Girls 2015', 'female': true},
      ],
      'groups': [
        {
          'group_id': 1,
          'name': 'Nursery',
          'code': 'Football',
          'sessions': 0,
          'booked': 3
        },
        {
          'group_id': 2,
          'name': 'U8 Boys',
          'code': 'Football',
          'sessions': 2,
          'booked': 2
        },
        {
          'group_id': 3,
          'name': 'U13 Boys',
          'code': 'Football',
          'team_id': 7,
          'team_name': 'Clontarf Boys 2013',
          'sessions': 2,
          'booked': 2
        },
        {
          'group_id': 4,
          'name': 'U12 Boys',
          'code': 'Hurling',
          'sessions': 2,
          'booked': 2
        },
        {
          'group_id': 5,
          'name': 'Minor Girls',
          'code': 'Ladies Football',
          'sessions': 2,
          'booked': 1
        },
        {
          'group_id': 6,
          'name': 'U10 Girls',
          'code': 'Ladies Football',
          'sessions': 2,
          'booked': 2
        },
        {
          'group_id': 7,
          'name': 'U10 Hurling',
          'code': 'Hurling',
          'sessions': 2,
          'booked': 2
        },
        {
          'group_id': 8,
          'name': 'U14 Boys',
          'code': 'Football',
          'team_id': 8,
          'team_name': 'Clontarf Boys 2012',
          'sessions': 2,
          'booked': 1
        },
        {
          'group_id': 9,
          'name': 'All Stars',
          'code': 'Other',
          'sessions': 1,
          'booked': 0
        },
      ],
      'week': {'published_at': '2026-11-20T18:05:00Z', 'changed': true},
    };

Map<String, dynamic> boardWithGroups() {
  final b = sampleBoard();
  b['booking_groups'] = {
    for (final x in b['bookings'] as List)
      if ((x as Map)['group_id'] != null) '${x['booking_id']}': x['group_id']
  };
  // DCC has no slot on Saturday lunchtime or evening.
  b['blocks'] = [
    {
      'pitch_id': 2,
      'weekday': 6,
      'opens': '11:00',
      'closes': '13:00',
      'reason': 'No slot'
    },
    {
      'pitch_id': 2,
      'weekday': 6,
      'opens': '17:00',
      'closes': '22:00',
      'reason': 'No slot'
    },
  ];
  return b;
}

/// Holds every save until [release] is called.
class SlowPitchApi extends FakePitchApi {
  final _gate = Completer<void>();
  void release() => _gate.complete();
  @override
  Future<void> saveBooking(int clubId, Map<String, dynamic> booking) async {
    await _gate.future;
    await super.saveBooking(clubId, booking);
  }
}

class FakePitchApi extends PitchApi {
  FakePitchApi({this.officer = true});
  final bool officer;
  final saved = <Map<String, dynamic>>[];

  static const clontarf = PitchClub(
      clubId: 1,
      name: 'Clontarf GAA',
      primary: '#e61e28',
      secondary: '#ffffff',
      third: '#0357a3');

  @override
  Future<List<PitchClub>> clubs() async => officer ? [clontarf] : [];
  @override
  Future<List<PitchClub>> memberClubs() async => [clontarf];
  @override
  Future<int> rollWeek(int clubId, DateTime monday) async => 0;
  @override
  Future<PitchBoard> board(int clubId, DateTime from, DateTime to) async =>
      PitchBoard.fromJson(boardWithGroups());
  @override
  Future<void> saveBooking(int clubId, Map<String, dynamic> booking) async =>
      saved.add(booking);
  final filled = <Map<String, dynamic>>[];
  Set<int> autos = {};
  @override
  Future<Map<int, GroupHome>> groupHomes(int clubId) async =>
      {8: const GroupHome(3, day: 6, time: 11 * 60)};
  @override
  Future<Set<int>> autoIds(int clubId, DateTime monday) async => autos;
  @override
  Future<Map> autofill(int clubId, List<Map<String, dynamic>> items) async {
    filled.addAll(items);
    autos = {9};
    return {'added': items.length, 'skipped': 0};
  }

  final savedPitches = <Map<String, dynamic>>[];
  final savedBlocks = <int, List<PitchBlock>>{};
  @override
  Future<PitchSetup> setup(int clubId) async => PitchSetup.fromJson({
        'venues': [
          {'venue_id': 1, 'name': 'All', 'pitches': sampleBoard()['pitches']}
        ]
      });
  @override
  Future<List<(int, PitchBlock)>> blocks(int clubId) async =>
      PitchBoard.fromJson(boardWithGroups()).blocks;
  @override
  Future<void> savePitch(int clubId, Map<String, dynamic> pitch) async =>
      savedPitches.add(pitch);
  @override
  Future<void> saveBlocks(int clubId, int pitchId, List<PitchBlock> b) async =>
      savedBlocks[pitchId] = b;
  bool changesSeen = false;
  @override
  Future<Map> fixtureChanges(int clubId) async => {
        'unread': changesSeen ? 0 : 1,
        'alerts': [
          {
            'kind': 'moved',
            'title': 'U16 Football: Naomh Barrog v Clontarf',
            'detail': 'Moved from Sat 21 Nov 13:00 to Sat 21 Nov 14:30',
            'unread': !changesSeen,
            'created_at': DateTime.now()
                .subtract(const Duration(hours: 2))
                .toUtc()
                .toIso8601String(),
          }
        ],
      };
  @override
  Future<void> fixtureChangesSeen(int clubId) async => changesSeen = true;
  @override
  Future<Map> fixturesWeek(int clubId, DateTime monday) async => {
        'official': [
          {
            'game_id': 86467,
            'code': 'Camogie',
            'age': 'U21',
            'comp': 'Camogie U21 Division 2 Championship',
            'home': 'Clontarf',
            'away': 'Fingallians',
            'is_home': true,
            'venue': 'Clontarf',
            'referee': 'R Somerfield',
            'status': 'fixture',
            'note': '',
            'starts_at': '2026-11-17T20:00:00',
            'booking': {
              'booking_id': 9,
              'pitch': 'Pitch 34',
              'status': 'confirmed',
              'starts_at': '2026-11-17T20:00:00'
            },
          },
          {
            'game_id': 86447,
            'code': 'Football',
            'age': 'U16',
            'comp': 'U16 Football B Shield',
            'home': 'Naomh Barrog',
            'away': 'Clontarf',
            'is_home': false,
            'venue': 'St Annes 14',
            'referee': 'D Harrington',
            'status': 'fixture',
            'note': 'Final .. ET if req.',
            'changes': [
              {
                'kind': 'moved',
                'detail': 'Moved from Sat 21 Nov 13:00 to Sat 21 Nov 14:30'
              }
            ],
            'starts_at': '2026-11-21T14:30:00',
          },
          {
            'game_id': 86500,
            'code': 'Football',
            'age': 'U14',
            'comp': 'U14 Football Division 3',
            'home': 'Clontarf',
            'away': 'Raheny',
            'is_home': true,
            'venue': 'TBC',
            'status': 'fixture',
            'starts_at': '2026-11-21T14:00:00',
            'event': {'event_id': 50, 'team_name': 'Clontarf Boys 2012'},
          },
        ],
        'unofficial': [
          {
            'event_id': 1779,
            'team_name': 'Clontarf Girls 2018',
            'female': true,
            'code': 'Football',
            'opposition': "St Vincent's",
            'location': "Pitch 30, St Anne's Park",
            'starts_at': '2026-11-22T09:30:00',
            'booking': {
              'booking_id': 3,
              'pitch': 'Pitch 30',
              'status': 'confirmed',
              'starts_at': '2026-11-22T09:30:00'
            },
          },
          {
            'event_id': 9001,
            'team_name': 'Clontarf Girls 2013',
            'female': true,
            'code': 'Football',
            'opposition': 'T1 / T3 Vincents Away. T2 TBC',
            'location': "Vincent's",
            'starts_at': '2026-11-21T13:45:00',
          },
          {
            'event_id': 1777,
            'team_name': 'Clontarf Girls 2012',
            'female': true,
            'code': 'Football',
            'opposition': 'Sylvesters',
            'home_away': 'Away',
            'location': 'Broomfield',
            'starts_at': '2026-11-20T19:30:00',
          },
        ],
      };

  @override
  Future<Map> publishedWeek(int clubId, DateTime monday) async {
    final b = boardWithGroups();
    final names = {
      for (final g in b['groups'] as List) (g as Map)['group_id']: g['name']
    };
    final teams = {
      for (final g in b['groups'] as List) (g as Map)['group_id']: g['team_id']
    };
    return {
      'published_at': '2026-11-20T18:05:00Z',
      'pitches': b['pitches'],
      'closures': b['closures'],
      'my_teams': [7],
      'hours': [
        for (final p in b['pitches'] as List)
          for (final h in ((p as Map)['hours'] as List? ?? const []))
            {...(h as Map), 'pitch_id': p['pitch_id']}
      ],
      'blocks': b['blocks'],
      'bookings': [
        for (final x in b['bookings'] as List)
          {
            ...(x as Map),
            'team_id': teams[x['group_id']],
            'name': names[x['group_id']] ??
                (x['title'] == '' ? 'Training' : x['title']),
          }
      ],
    };
  }
}

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

Future<void> _pump(WidgetTester t, Size size, FakePitchApi api) async {
  t.view.physicalSize = size * 2;
  t.view.devicePixelRatio = 2;
  addTearDown(t.view.reset);
  await t.pumpWidget(MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(),
      home: RepaintBoundary(
          child: V3PitchesPage(clubId: 1, api: api, today: _today))));
  await t.pumpAndSettle();
}

/// The planner opens on Fixtures; most tests start from the day board.
Future<void> _pumpBoard(WidgetTester t, Size size, FakePitchApi api,
    {bool week = false}) async {
  await _pump(t, size, api);
  final day = find.text(size.width >= 1000 ? 'Day board' : 'Day');
  if (day.evaluate().isNotEmpty) {
    await t.tap(day.first);
    await t.pumpAndSettle();
  }
  // The laptop board opens on Week; most tests want the day.
  if (size.width >= 1000 && !week) {
    await t.tap(find.text('Day').first);
    await t.pumpAndSettle();
  }
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

  group('rules', () {
    test('age-group names from birth-year teams', () {
      expect(
          groupName('Clontarf Boys 2012',
              season: 2026, clubName: 'Clontarf GAA'),
          'U14 Boys');
      expect(groupName('Clontarf Senior Footballers', clubName: 'Clontarf GAA'),
          'Senior Footballers');
      expect(ageOf('U21'), 21);
      expect(ageOf('Minor'), 18);
    });

    test('club accent: a clear club colour that reads on the white page', () {
      expect(pickAccent(['#e61e28', '#ffffff']), const Color(0xFFE61E28));
      // On white the club's main colour usually reads; a pale one is skipped.
      expect(pickAccent(['#1e3f94', '#f04e23']), const Color(0xFF1E3F94));
      expect(pickAccent(['#6e1a2a', '#e8b230']), const Color(0xFF6E1A2A));
      expect(pickAccent(['#ffe600', '#1e3f94']), const Color(0xFF1E3F94));
      // Nothing usable: CoachSmart green.
      expect(pickAccent(['#ffffff', '#000000']), const Color(0xFF3F7D0B));
    });

    test('clashes need the same part of a pitch at the same time', () {
      final b = PitchBoard.fromJson(boardWithGroups());
      final c = b.clashesOn(_today);
      expect(c.length, 1);
      expect({c.first.$1.bookingId, c.first.$2.bookingId}, {10, 11});
      // Left half and right half do not clash.
      final l = Booking(
          bookingId: 1,
          start: _today,
          end: _today.add(const Duration(hours: 1)),
          part: PitchPart.left);
      final r = Booking(
          bookingId: 2,
          start: _today,
          end: _today.add(const Duration(hours: 1)),
          part: PitchPart.right);
      expect(l.overlaps(r), isFalse);
    });

    test('free places use the slots the club holds and skip closed pitches',
        () {
      final b = PitchBoard.fromJson(boardWithGroups());
      final at = DateTime(2026, 11, 21, 12, 0);
      final opts = b.optionsFor(at, 60);
      final names = opts.map((o) => o.pitch.name).toList();
      expect(names, contains('Clubhouse Astro'));
      expect(names, isNot(contains('Pitch 30'))); // closed
      // Minor Girls has Pitch 19 at 12:00, so only its later slot is offered.
      final p19 = opts.firstWhere((o) => o.pitch.name == 'Pitch 19');
      expect(p19.exact, isFalse);
      expect(timeOf(p19.start), '14:15');
      final astro = opts.firstWhere((o) => o.pitch.name == 'Clubhouse Astro');
      expect(astro.exact, isTrue);
      expect(timeOf(astro.start), '12:00');
    });

    test('an event is not shown again when its team has a booking that day',
        () {
      final j = boardWithGroups();
      final day = DateTime(2026, 11, 21);
      expect(PitchBoard.fromJson(j).matchedOn(day).map((e) => e.eventId),
          contains(51));
      (j['bookings'] as List).add({
        'booking_id': 99,
        'pitch_id': 7,
        'part': 15,
        'starts_at': '2026-11-21T15:00:00',
        'ends_at': '2026-11-21T16:00:00',
        'kind': 'training',
        'status': 'confirmed',
        'team_id': 9,
      });
      expect(PitchBoard.fromJson(j).matchedOn(day).map((e) => e.eventId),
          isNot(contains(51)));
    });

    test('a dropped booking moves on the board before the save returns',
        () async {
      final api = SlowPitchApi();
      final c = PitchController(FakePitchApi.clontarf, api: api, today: _today);
      await c.load();
      final b = c.board!.bookings.firstWhere((x) => x.bookingId == 10);
      final to = DateTime(2026, 11, 21, 19);
      final done = c.moveBooking(
          b, 1, PitchPart.full, to, to.add(const Duration(hours: 1)));
      final now = c.board!.bookings.firstWhere((x) => x.bookingId == 10);
      expect(now.start, to);
      expect(now.pitchId, 1);
      expect(api.saved, isEmpty);
      api.release();
      expect(await done, isNull);
      expect(api.saved.single['booking_id'], 10);
    });

    test('slot lookup', () {
      final p = PitchBoard.fromJson(sampleBoard()).pitches.first;
      expect(p.slotAt(1, 17 * 60 + 55)?.label, '17:50–18:40');
      expect(p.slotAt(1, 16 * 60), isNull);
    });

    test('inbox: unplaced events and fixtures, not matched ones', () {
      final b = PitchBoard.fromJson(boardWithGroups());
      final items = b.inbox(clubName: 'Clontarf GAA', season: 2026);
      expect(items.map((i) => i.title),
          ['U14 Boys v Raheny', 'U21 Camogie v Fingallians']);
    });
  });

  testWidgets('laptop: day board with inbox, groups, clash and closed pitch',
      (t) async {
    final api = FakePitchApi();
    await _pumpBoard(t, const Size(1440, 900), api);
    expect(find.text('Saturday 21 November'), findsOneWidget);
    expect(find.text('Clubhouse Astro'), findsWidgets);
    expect(find.text('U14 Boys v Raheny'), findsOneWidget);
    expect(find.text('Closed'), findsOneWidget);
    // Only times marked unavailable are shaded, not every gap.
    expect(find.text('Unavailable'), findsWidgets);
    expect(find.text('Publish changes'), findsOneWidget);
    expect(find.textContaining('1 clash'), findsOneWidget);
    await _shot(t, 'pp-board');

    await t.tap(find.text('U14 Boys v Raheny'));
    await t.pumpAndSettle();
    expect(find.text('Free pitches'), findsOneWidget);
    // Picking another pitch moves the tick and the button to it.
    final second = find
        .descendant(
            of: find.byType(Dialog), matching: find.textContaining('Pitch'))
        .evaluate()
        .map((e) => (e.widget as Text).data ?? '')
        .firstWhere((s) => RegExp(r'^Pitch \w+$').hasMatch(s));
    await t.tap(find.text(second).last);
    await t.pumpAndSettle();
    expect(find.text('Place on $second'), findsOneWidget);
    expect(find.byIcon(Icons.check_circle), findsOneWidget);
    // It can be moved to another day or time to find a free pitch.
    await t.tap(find.text('Sun 22'));
    await t.pumpAndSettle();
    expect(find.textContaining('Booking it for Sun'), findsOneWidget);
    await _shot(t, 'pp-place');
  });

  testWidgets('laptop: week view shows one pitch over seven days', (t) async {
    // The board opens on Week, on the first pitch (Clubhouse Astro).
    await _pumpBoard(t, const Size(1440, 900), FakePitchApi(), week: true);
    for (final d in ['Mon 16', 'Tue 17', 'Sat 21', 'Sun 22']) {
      expect(find.text(d), findsOneWidget);
    }
    expect(find.text('Nursery'), findsWidgets);
    await _shot(t, 'pp-week');
    // A day heading opens that day on the day board.
    await t.tap(find.text('Mon 16'));
    await t.pumpAndSettle();
    expect(find.text('Monday 16 November'), findsOneWidget);
  });

  test('time outside the slots is Unavailable on every pitch', () {
    final b = PitchBoard.fromJson(boardWithGroups());
    final dcc = b.blocksOn(2, 6);
    String l(PitchBlock x) => '${x.slot.label} ${x.reason}';
    expect(dcc.map(l),
        containsAll(['15:40–17:00 Unavailable', '08:00–09:00 Unavailable']));
    expect(dcc.any((x) => x.slot.opens == 9 * 60), isFalse);
    expect(b.blocksOn(3, 6).map(l), contains('11:00–12:00 Unavailable'));
  });

  testWidgets('laptop: fill fixtures from the home defaults', (t) async {
    final api = FakePitchApi();
    await _pump(t, const Size(1440, 900), api);
    await t.tap(find.text('Fill from defaults'));
    await t.pumpAndSettle();
    // U14 Boys v Raheny goes on its group's pitch at the league time.
    expect(api.filled.length, 1);
    expect(api.filled.first['gaa_game_id'], 86500);
    expect(api.filled.first['event_id'], 50);
    expect(api.filled.first['pitch_id'], 3);
    expect(api.filled.first['starts_at'], startsWith('2026-11-21T14:00'));
    expect(find.text('Auto'), findsOneWidget);
    expect(find.text('Undo fill'), findsOneWidget);
    await _shot(t, 'pp-fill');
  });

  testWidgets('laptop: availability, add a not-available time', (t) async {
    final api = FakePitchApi();
    await _pump(t, const Size(1440, 900), api);
    await t.tap(find.text('Availability').first);
    await t.pumpAndSettle();
    expect(find.text('Astros'), findsOneWidget);
    await t.tap(find.text('DCC Astro').first);
    await t.pumpAndSettle();
    expect(find.text('11:00–13:00 · Unavailable'), findsOneWidget);
    expect(find.text('09:00–11:00'), findsOneWidget);
    await _shot(t, 'pp-availability');
    // Monday: not available 08:00-22:00.
    await t.tap(find.byTooltip('Add a time').first);
    await t.pumpAndSettle();
    await t.tap(find.text('Unavailable').last);
    await t.pumpAndSettle();
    await t.enterText(find.widgetWithText(TextField, 'From'), '08:00');
    await t.enterText(find.widgetWithText(TextField, 'To'), '22:00');
    await t.tap(find.text('Save'));
    await t.pumpAndSettle();
    final saved = api.savedBlocks[2]!;
    expect(saved.length, 3);
    expect(saved.last.slot.weekday, 1);
    expect(saved.last.reason, 'Unavailable');
    expect(api.savedPitches, isEmpty);
  });

  testWidgets('phone: availability', (t) async {
    await _pump(t, const Size(390, 844), FakePitchApi());
    await t.tap(find.text('Slots'));
    await t.pumpAndSettle();
    expect(find.text('Clubhouse Astro'), findsWidgets);
    await _shot(t, 'pp-availability-phone');
  });

  testWidgets('laptop: tapping a group shows its sessions', (t) async {
    await _pumpBoard(t, const Size(1440, 900), FakePitchApi());
    await t.tap(find.text('Nursery').first);
    await t.pumpAndSettle();
    expect(find.text('+ Add a session'), findsOneWidget);
    expect(find.text('Nursery  ×'), findsOneWidget);
    await _shot(t, 'pp-focus');
    await t.tap(find.text('Nursery  ×'));
    await t.pumpAndSettle();
    expect(find.text('+ Add a session'), findsNothing);
  });

  testWidgets('laptop: fixtures tab, official and unofficial', (t) async {
    await _pump(t, const Size(1440, 900), FakePitchApi());
    await t.tap(find.text('Fixtures').first);
    await t.pumpAndSettle();
    expect(find.text('OFFICIAL FIXTURES'), findsOneWidget);
    expect(find.text('UNOFFICIAL MATCHES'), findsOneWidget);
    expect(find.text('U21 Camogie: Clontarf v Fingallians'), findsOneWidget);
    expect(find.text('Pitch 34 · 20:00'), findsOneWidget);
    expect(find.text('Unassigned'), findsNWidgets(2));
    expect(find.text("U8 Girls v St Vincent's"), findsOneWidget);
    // League changes: listed at the top and flagged on the fixture.
    expect(find.text('CHANGES FROM THE LEAGUE'), findsOneWidget);
    expect(find.text('⚠ Time changed'), findsOneWidget);
    await _shot(t, 'pp-fixtures');
    // The Unassigned chip opens the place sheet.
    await t.tap(find.text('Unassigned').first);
    await t.pumpAndSettle();
    expect(find.text('Free pitches'), findsOneWidget);
    Navigator.of(t.element(find.text('Free pitches'))).pop();
    await t.pumpAndSettle();
    // So does an unofficial match the board's list doesn't have.
    await t.tap(find.text('Unassigned').last);
    await t.pumpAndSettle();
    expect(find.text('Free pitches'), findsOneWidget);
  });

  testWidgets('laptop: tap an empty part of a pitch to add a booking',
      (t) async {
    await _pumpBoard(t, const Size(1440, 900), FakePitchApi());
    await t.tap(find.text('+ New booking'));
    await t.pumpAndSettle();
    expect(find.text('New booking'), findsOneWidget);
    expect(find.text('Add booking'), findsOneWidget);
    Navigator.of(t.element(find.text('New booking'))).pop();
    await t.pumpAndSettle();
    // Pitch 19 at 08:30: no held slot there, so the grid itself takes the tap.
    final head = t.getRect(find.text('Pitch 19'));
    await t.tapAt(Offset(head.center.dx, head.bottom + 60));
    await t.pumpAndSettle();
    expect(find.text('New booking'), findsOneWidget);
  });

  testWidgets('phone: day by pitch', (t) async {
    await _pumpBoard(t, const Size(390, 1400), FakePitchApi());
    expect(find.textContaining('need a pitch'), findsOneWidget);
    expect(find.textContaining('1 clash'), findsOneWidget);
    await _shot(t, 'pp-phone');
    await t.tap(find.text('Add a booking').first);
    await t.pumpAndSettle();
    expect(find.text('New booking'), findsOneWidget);
  });

  testWidgets('member: published week, read-only', (t) async {
    await _pump(t, const Size(390, 1100), FakePitchApi(officer: false));
    expect(find.textContaining('Published'), findsOneWidget);
    expect(find.text('Close a pitch'), findsNothing);
    expect(find.text('YOUR TEAMS THIS WEEK'), findsOneWidget);
    await _shot(t, 'pp-member');
  });

  testWidgets('member on a laptop: week grid per pitch', (t) async {
    await _pump(t, const Size(1440, 1000), FakePitchApi(officer: false));
    expect(find.text('YOUR TEAMS THIS WEEK'), findsOneWidget);
    expect(find.text('Sat 21'), findsWidgets);
    await t.tap(find.text('Pitch 21').last);
    await t.pumpAndSettle();
    await _shot(t, 'pp-member-wide');
    // Team pills filter to one team.
    expect(find.text('All teams'), findsOneWidget);
    await t.tap(find.text('U8 Boys').first);
    await t.pumpAndSettle();
    expect(find.text('U8 BOYS THIS WEEK'), findsOneWidget);
    await _shot(t, 'pp-member-team');
  });
}
