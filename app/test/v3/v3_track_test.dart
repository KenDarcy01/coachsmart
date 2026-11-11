import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:coach_smart_v2/v3/tracking/v3_track.dart';

class _Rec implements V3TrackSink {
  final log = <String>[];
  @override
  Future<void> event(String name, Map<String, Object> params) async =>
      log.add('event $name $params');
  @override
  Future<void> screen(String name) async => log.add('screen $name');
  @override
  Future<void> userId(String? id) async => log.add('user $id');
  @override
  Future<void> userProperty(String name, String? value) async =>
      log.add('prop $name=$value');
}

void main() {
  late _Rec rec;
  setUp(() {
    rec = _Rec();
    V3Track.sink = rec;
    V3Track.reset();
  });
  tearDown(() => V3Track.sink = null);

  test('event names follow GA4 rules', () {
    expect(V3Track.cleanName('generate-session-plan'), 'generate_session_plan');
    expect(V3Track.cleanName('Button tap!'), 'button_tap');
    expect(V3Track.cleanName('9lives'), 'e_9lives');
    expect(V3Track.cleanName('x' * 60).length, 40);
  });

  test('params drop nulls and empties, cap strings, bools become 0/1', () {
    final p = V3Track.cleanParams({
      'a': null,
      'b': '',
      'c': 'y' * 150,
      'd': true,
      'e': 7,
    });
    expect(p.keys, ['c', 'd', 'e']);
    expect((p['c'] as String).length, 100);
    expect(p['d'], 1);
  });

  test('attendance and feature events', () async {
    V3Track.attendance(12, 3, 'home');
    V3Track.attendance(12, 4, 'event');
    V3Track.feature('generate-session-plan', 'generate');
    await Future<void>.delayed(Duration.zero);
    expect(rec.log, [
      'event attendance_responded {event_id: 12, response: accepted, from: home}',
      'event attendance_responded {event_id: 12, response: declined, from: event}',
      'event generate_session_plan {action: generate}',
    ]);
  });

  test('start tags the install as v3 once', () async {
    V3Track.start();
    V3Track.start();
    await Future<void>.delayed(Duration.zero);
    expect(rec.log.where((l) => l == 'prop app_gen=v3').length, 1);
  });

  test('sign out clears the user', () async {
    V3Track.identify(null); // already signed out: nothing
    await Future<void>.delayed(Duration.zero);
    expect(rec.log, isEmpty);
  });

  test('labels', () {
    expect(V3Track.teamsBucket(2), '2');
    expect(V3Track.teamsBucket(9), '5+');
    expect(V3Track.clubLabel('  '), isNull);
    expect(V3Track.clubLabel('C' * 50)!.length, 36);
  });

  test('observer logs named page routes only', () {
    expect(
        V3TrackObserver.nameOf(MaterialPageRoute(
            settings: const RouteSettings(name: 'V3MatchesPage'),
            builder: (_) => const SizedBox())),
        'V3MatchesPage');
    expect(
        V3TrackObserver.nameOf(
            MaterialPageRoute(builder: (_) => const SizedBox())),
        isNull);
    expect(
        V3TrackObserver.nameOf(MaterialPageRoute(
            settings: const RouteSettings(name: '_initialize'),
            builder: (_) => const SizedBox())),
        isNull);
  });

  test('no sink and no Firebase: calls are silent no-ops', () {
    V3Track.sink = null;
    V3Track.event('anything');
    V3Track.screen('X');
    V3Track.identify('u1');
  });
}
