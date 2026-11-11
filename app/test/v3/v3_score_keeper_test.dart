import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:coach_smart_v2/v3/score_keeper/sk_controller.dart';
import 'package:coach_smart_v2/v3/score_keeper/sk_models.dart';
import 'package:coach_smart_v2/v3/score_keeper/sk_services.dart';
import 'package:coach_smart_v2/v3/score_keeper/sk_voice_parser.dart';
import 'package:coach_smart_v2/v3/score_keeper/v3_score_keeper_page.dart';

Map<String, dynamic> state({Map? timer, Map? session, List? actions}) => {
      'event': {
        'event_id': 1,
        'event_date_time': '2026-11-15T11:00:00+00:00',
        'event_title': 'U14 League v Raheny',
        'opposition': 'Raheny',
        'team_id': 7,
        'team_name': 'U14 Boys',
        'club_name': 'Clontarf GAA',
        'event_code': 'Football',
        'event_type': 'Match',
      },
      'is_member': true,
      'timer': timer,
      'session': session,
      'squads': [
        {'squad_id': 11, 'squad_name': 'Blue'},
      ],
      'score_types': [
        {'id': 2, 'score_type': 'Point', 'score_value': 1, 'button': true},
        {'id': 1, 'score_type': 'Goal', 'score_value': 3, 'button': true},
        {'id': 3, 'score_type': 'Wide', 'score_value': null, 'button': true},
        {
          'id': 4,
          'score_type': 'Free',
          'score_value': null,
          'source': true,
          'button': false
        },
      ],
      'actions': actions ?? [],
      'subs': [],
      'lineup': {
        'players': [
          {
            'member_id': 101,
            'number': 11,
            'is_sub': false,
            'first_name': 'Ciarán',
            'last_name': 'Byrne'
          },
          {
            'member_id': 102,
            'number': 14,
            'is_sub': false,
            'first_name': 'Luke',
            'last_name': "O'Shea"
          },
          {
            'member_id': 103,
            'number': 17,
            'is_sub': true,
            'first_name': 'Murrough',
            'last_name': 'Kelly'
          },
        ]
      },
      'players': [
        {
          'member_id': 104,
          'first_name': 'Seán',
          'last_name': 'Ryan',
          'squads': [11]
        },
        {
          'member_id': 105,
          'first_name': 'Tom',
          'last_name': 'Nolan',
          'squads': []
        },
      ],
    };

SkInfo info() => SkInfo(SkInfo.pick(state()));

VoiceCtx vctx() {
  final c = info();
  final s = SkState(setup: SkSetup(opp: 'Raheny'));
  return VoiceCtx(
    types: [
      for (final t in c.types)
        VoiceType(id: t.id, name: t.name, value: t.value, source: t.source)
    ],
    usName: 'Clontarf U14 Boys',
    oppName: 'Raheny',
    players: [
      for (final p in roster(s, c).values)
        VoicePlayer(
            memberId: p.id,
            firstName: p.first,
            lastName: p.last,
            number: p.number)
    ],
  );
}

/// A backend that turns down any batch holding a 'bad' entry.
class _PickyBackend extends SkMemoryBackend {
  _PickyBackend() : super(state());
  @override
  Future<Map<String, dynamic>?> sync(int id, List<Map<String, dynamic>> actions,
      Map<String, dynamic>? timer) async {
    if (actions.any((a) => a['score_type'] == 999)) throw SkBadRequest();
    return super.sync(id, actions, timer);
  }
}

void main() {
  group('voice reader', () {
    test('a score and a wide for them in one go', () {
      final r = parseVoice('Point Kieran and a wide for them', vctx());
      expect(r.items, hasLength(2));
      expect(r.items[0].typeId, 2);
      expect(r.items[0].side, 'us');
      expect(r.items[0].memberId, 101); // Kieran = Ciarán
      expect(r.items[1].typeId, 3);
      expect(r.items[1].side, 'opp');
      expect(r.items[1].memberId, isNull);
    });

    test('counts, numbers, sources and frees given away', () {
      expect(parseVoice('two wides for them', vctx()).items.single.count, 2);
      final g = parseVoice('goal number eleven', vctx()).items.single;
      expect((g.typeId, g.memberId), (1, 101));
      final f = parseVoice('point Murrough free', vctx()).items.single;
      expect((f.typeId, f.memberId, f.fromId), (2, 103, 4));
      final a = parseVoice('free against Luke', vctx()).items.single;
      expect((a.typeId, a.side, a.memberId, a.against), (4, 'opp', 102, true));
      expect(parseVoice('banana', vctx()).unknown, ['banana']);
    });

    test('subs by number or name', () {
      final s = parseVoice('sub 17 for 11', vctx()).items.single;
      expect((s.kind, s.onId, s.offId), ('sub', 103, 101));
      final n = parseVoice('Murrough on for Luke', vctx()).items.single;
      expect((n.onId, n.offId), (103, 102));
    });
  });

  group('outbox', () {
    const at = SkAt(1, 75, true);
    test('taking off an entry still waiting means it never goes', () {
      final s = SkState(setup: SkSetup(opp: 'Raheny'));
      final a = addScore(s, 2, 'us', at, 1);
      expect(s.out.single['type'], 'score');
      expect(s.out.single['timer_status'], 'running');
      removeAct(s, a.id, {});
      expect(s.out, isEmpty);
      expect(s.acts, isEmpty);
    });

    test('an entry uploading gets a remove; edits go as edit ops', () {
      final s = SkState(setup: SkSetup(opp: 'Raheny'));
      final c = info();
      final a = addScore(s, 2, 'us', at, 1, mem: 101);
      editAct(s, c, a.id, {'st': 3}, {});
      expect(s.out.single['score_type'], 3); // still waiting: rewritten
      s.out.clear(); // uploaded
      editAct(s, c, a.id, {'side': 'opp'}, {});
      final e = s.out.single;
      expect(e['type'], 'edit');
      expect(e['target'], a.id);
      expect(e.containsKey('member_id'), isTrue);
      removeAct(s, a.id, {a.id});
      expect(s.out.last['type'], 'remove');
    });

    test('server entries with the outbox on top', () {
      final server = mapServerActs([
        {
          'id': 'srv-1',
          'kind': 'score',
          'score_type': 2,
          'side': 'us',
          'second': 30,
          'half': 1
        },
        {
          'id': 'abc',
          'kind': 'score',
          'score_type': 1,
          'side': 'opp',
          'second': 60,
          'half': 1
        },
      ]);
      final (acts, subs) = mergeWithOutbox(
          server,
          [],
          [
            {'type': 'remove', 'id': 'x', 'target': 'abc'},
            {
              'type': 'score',
              'id': 'new',
              'score_type': 1,
              'side': 'us',
              'second': 90,
              'half': 1,
              'timer_status': 'running'
            },
            {
              'type': 'sub',
              'id': 's1',
              'second': 95,
              'half': 1,
              'member_off': 101,
              'member_on': 103
            },
          ],
          5);
      expect(acts.map((a) => a.id), ['srv-1', 'new']);
      expect(subs.single.on, 103);
    });
  });

  group('state', () {
    test('half time from the server, and a finished match', () {
      final ht = stateFromServer(state(timer: {
        'status': 'paused',
        'elapsed_seconds': 1840,
        'current_half': 1,
        'duration_seconds': 1800,
        'injury_seconds': 300,
        'phase': 'ht'
      }, session: {
        'id': 12,
        'status': 'active',
        'opposition': 'Raheny'
      }));
      expect(ht.phase, 'ht');
      expect(ht.clock.ended[1], 1840);
      expect(ht.sessionId, 12);
      expect(ht.needSetup, isFalse);
      final done = stateFromServer(state(
          session: {'id': 12, 'status': 'finalised', 'opposition': 'Raheny'}));
      expect(done.phase, 'done');
      expect(done.needSetup, isFalse); // finished: no clock row needed
      expect(stateFromServer(state()).phase, 'setup');
      // Round trip through the phone's storage
      final again = SkState.fromJson(ht.toJson())!;
      expect((again.phase, again.sessionId, again.clock.ended[1]),
          ('ht', 12, 1840));
    });

    test('clock, minutes and what followers see', () {
      final s = SkState(setup: SkSetup(opp: 'Raheny', dur: 1800));
      expect(timerPayload(s, DateTime(2026))['phase'], 'setup');
      s.clock
        ..run = true
        ..startedAt = 0;
      expect(secInHalf(s, 61500), 61);
      expect(timerPayload(s, DateTime(2026))['phase'], 'play');
      expect(minuteFor(1800, 1, 61), "2'");
      expect(minuteFor(1800, 1, 1850), "30+1'");
      expect(minuteFor(1800, 2, 0), "31'");
    });

    test('players, line-up and labels', () {
      final c = info();
      final s = SkState(setup: SkSetup(opp: 'Raheny', squadId: 11));
      final r = roster(s, c);
      expect(r.keys, [101, 102, 103, 104]); // Tom isn't in the Blue squad
      expect(r[102]!.short, "Luke O'S.");
      addSub(s, 101, 103, const SkAt(1, 600, true), 1);
      expect(onPitch(s, c)!.map((p) => p.id), [102, 103]);
      expect(usName(c), 'Clontarf');
      final a =
          addScore(s, 2, 'us', const SkAt(1, 60, true), 1, mem: 103, fr: 4);
      expect(actLabel(s, c, a), ('Point from a free', 'Murrough Kelly'));
      addScore(s, 1, 'opp', const SkAt(1, 70, true), 2);
      addScore(s, 3, 'us', const SkAt(1, 80, true), 3);
      expect(halfTable(s, c, 1), [('Goals', 0, 1), ('Points', 1, 0)]);
      expect(c.padTypes.map((t) => t.name), ['Goal', 'Point', 'Wide']);
      expect(pillText(s, 'offline', false).$1, '4 waiting · no signal');
      expect(skPdfName('Clontarf', 'Raheny', '0-01', '1-00'),
          'Clontarf_v_Raheny_0-01_1-00.pdf');
    });

    test('tones and clips are WAV files', () {
      final w = toneWav([0, 0.4], 740, 0.25, 0.7);
      expect(String.fromCharCodes(w.sublist(0, 4)), 'RIFF');
      expect(String.fromCharCodes(w.sublist(8, 12)), 'WAVE');
      expect(pcmToWav(List.filled(100, 0)).length, 144);
    });
  });

  test('a batch the server turns down: the bad entry is set aside', () async {
    final be = _PickyBackend();
    final ctl = SkController(
        eventId: 1,
        backend: be,
        store: MemorySkStore(),
        device: const SkDevice(quiet: true),
        mic: SkMic(enabled: false));
    ctl.s = SkState(setup: SkSetup(opp: 'Raheny'))..sessionId = 5;
    ctl.c = info();
    const at = SkAt(1, 10, true);
    addScore(ctl.s!, 2, 'us', at, 1);
    addScore(ctl.s!, 999, 'us', at, 2);
    addScore(ctl.s!, 1, 'opp', at, 3);
    await ctl.sync();
    expect(ctl.s!.out, isEmpty);
    expect(ctl.s!.rejected.single['score_type'], 999);
    expect(ctl.netState, 'ok');
    ctl.dispose();
  });

  widgetTests();
}

void widgetTests() {
  Future<void> big(WidgetTester tester) async {
    tester.view.physicalSize = const Size(390 * 3, 1600 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
  }

  testWidgets('setup, kick-off, tap, undo, half time and the stats tab',
      (tester) async {
    await big(tester);
    var now = DateTime(2026, 11, 15, 11).millisecondsSinceEpoch;
    final be = SkMemoryBackend(state());
    await tester.pumpWidget(MaterialApp(
        home: V3ScoreKeeperPage(
            eventId: 1, testBackend: be, testNow: () => now)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // Setup: opposition filled in from the event
    expect(find.text('Clontarf v Raheny'), findsOneWidget);
    expect(find.text('OPPOSITION'), findsOneWidget);
    expect(find.text('HALF LENGTH'), findsOneWidget);
    await tester.tap(find.text('Ready'));
    await tester.pump(const Duration(milliseconds: 600));

    // Playing: clock, board, buttons; nothing scores before kick-off
    expect(find.text('Start 1st half'), findsOneWidget);
    expect(find.text('00:00'), findsOneWidget);
    expect(find.text('Score'), findsNothing); // no Score/Stats tabs
    await tester.tap(find.byKey(const ValueKey('btn-us-2')));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Start the 1st half first'), findsOneWidget);

    await tester.tap(find.text('Start 1st half'));
    now += 125000;
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('02:05'), findsOneWidget);
    expect(find.text('Pause'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('btn-us-2')));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('0-01'), findsOneWidget);
    expect(find.text('Point for Clontarf at 3\''), findsOneWidget);
    expect(find.text('LATEST'), findsOneWidget);

    // Undo on the bar
    await tester.tap(find.text('Undo'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('0-01'), findsNothing);

    // A goal for them, then end the half
    await tester.tap(find.byKey(const ValueKey('btn-opp-1')));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('1-00'), findsOneWidget);
    await tester.tap(find.text('End half'));
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('Half time'), findsOneWidget);
    expect(find.text("Does this match the ref's score?"), findsOneWidget);
    await tester.tap(find.text('Yes'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text("✓ Matches the ref's score"), findsOneWidget);
    expect(find.text('Start 2nd half'), findsOneWidget);

    // Score/Stats tabs at half time
    await tester.tap(find.text('Stats'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Who was ahead'), findsOneWidget);
    expect(find.text('Download PDF'), findsOneWidget);
    expect(find.text('TIMELINE'), findsOneWidget);

    // Everything went up with a client id and the clock for followers
    final syncs = be.calls.where((c) => c.$1 == 'sync').toList();
    expect(syncs, isNotEmpty);
    expect(be.calls.any((c) => c.$1 == 'upsert'), isTrue);
    final timers = [
      for (final c in syncs)
        if ((c.$2 as Map)['timer'] != null) (c.$2 as Map)['timer'] as Map
    ];
    expect(timers.last['phase'], 'ht');

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 6));
  });

  testWidgets('a match that was finished opens on full time', (tester) async {
    await big(tester);
    await tester.pumpWidget(MaterialApp(
        home: V3ScoreKeeperPage(
            eventId: 1,
            testData: state(timer: {
              'status': 'paused',
              'elapsed_seconds': 1900,
              'current_half': 2,
              'duration_seconds': 1800,
              'injury_seconds': 300,
              'phase': 'ft'
            }, session: {
              'id': 12,
              'status': 'finalised',
              'opposition': 'Raheny'
            }, actions: [
              {
                'id': 'a1',
                'kind': 'score',
                'score_type': 1,
                'side': 'us',
                'second': 300,
                'half': 1,
                'member_id': 101,
                'created_at': '2026-11-15T11:05:00Z'
              },
            ]))));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Full time'), findsOneWidget);
    expect(find.text('Match saved'), findsOneWidget);
    expect(find.text('Match report'), findsOneWidget);
    expect(find.text('EVERYTHING RECORDED'), findsOneWidget);
    expect(find.text('Ciarán Byrne'), findsOneWidget);
    // Tap the goal: the edit sheet
    await tester.tap(find.text('Ciarán Byrne'));
    await tester.pumpAndSettle();
    expect(find.text('WHAT WAS IT?'), findsOneWidget);
    expect(find.text('How many?'), findsOneWidget);
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 6));
  });
}
