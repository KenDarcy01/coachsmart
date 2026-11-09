import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:coach_smart_v2/v3/event/v3_event_form_page.dart';

void main() {
  test('repeat rule sessions and labels', () {
    expect(RepeatRule.none.sessions(), 1);
    expect(const RepeatRule(1, 8).sessions(), 8);
    expect(const RepeatRule(2, 8).sessions(), 4);
    expect(const RepeatRule(1, 6).label(), 'Every week · 6 weeks');
    expect(RepeatRule.none.label(), "Doesn't repeat");
  });

  test('repeat summary names the first and last dates', () {
    final s = repeatSummary(
        const RepeatRule(1, 8), DateTime(2026, 11, 10, 18, 30), 'Training');
    expect(s,
        '8 training sessions, Tue 10 Nov to Tue 29 Dec, each with its own replies.');
    final f = repeatSummary(
        const RepeatRule(2, 8), DateTime(2026, 11, 10, 18, 30), 'Match');
    expect(f, startsWith('4 matches, Tue 10 Nov to Tue 22 Dec'));
    expect(repeatSummary(RepeatRule.none, null, ''), 'One event only.');
  });

  test('auto title from code, type and opposition', () {
    expect(autoTitle('Football', 'Match', 'Raheny'), 'Football Match v Raheny');
    expect(autoTitle('Hurling', 'Training', ''), 'Hurling Training');
    expect(autoTitle('', 'Match', ''), 'Match');
  });

  test('meet time parsing accepts the common typed forms', () {
    expect(parseMeetTime('09:30'), const TimeOfDay(hour: 9, minute: 30));
    expect(parseMeetTime('1245'), const TimeOfDay(hour: 12, minute: 45));
    expect(parseMeetTime('9.15'), const TimeOfDay(hour: 9, minute: 15));
    expect(parseMeetTime('half nine'), isNull);
    expect(parseMeetTime('25:00'), isNull);
    expect(formatMeetTime(const TimeOfDay(hour: 9, minute: 5)), '09:05');
    expect(formatMeetTime(null), isNull);
  });

  test('euro and cents', () {
    expect(euroToCents('12'), 1200);
    expect(euroToCents('12.50'), 1250);
    expect(euroToCents('€7,5'), 750);
    expect(euroToCents('abc'), isNull);
    expect(centsToEuro(1200), '12');
    expect(centsToEuro(1250), '12.50');
  });

  test('changedFields sends only what differs', () {
    final current = {
      'event_title': '',
      'event_date_time': '2026-11-14T12:45:00',
      'location_name': 'Whitehall',
      'opposition': 'T1 Whitehall',
      'squad_id': null,
      'request_attendance': true,
    };
    final wanted = {
      'event_title': '',
      'event_date_time': '2026-11-14 12:45:00.000',
      'location_name': 'Seafield',
      'opposition': 'T1 Whitehall',
      'squad_id': null,
      'request_attendance': true,
    };
    expect(changedFields(current, wanted), {'location_name': 'Seafield'});
    expect(
        changedFields(
            current, {...wanted, 'event_date_time': '2026-11-14 13:00:00.000'}),
        containsPair('event_date_time', '2026-11-14 13:00:00.000'));
    expect(changedFields(current, {'event_title': null}), isEmpty);
  });
}
