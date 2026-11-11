// Helpers that turn get_user_home_events rows into what the v3 home shows:
// local times, the timeline (one day marker per day, one "next" event) and
// the reply state of each row. Spec: docs/design/home-v3/HOME-V3-DESIGN.md.
import '/backend/schema/structs/index.dart';

import 'package:intl/intl.dart';

/// The event's time as Irish wall-clock time.
///
/// events.event_date_time stores the wall-clock time labelled UTC, so the
/// clock components are taken as-is (never shifted into the phone's zone).
/// Prefers the raw `event_date_time` the RPC carries since 2026-11-11 and
/// falls back to the formatted text for an older RPC.
DateTime? eventLocalTime(EventsStruct e) {
  final raw = e.eventDateTime;
  if (raw.isNotEmpty) {
    final p = DateTime.tryParse(raw);
    if (p != null) {
      final u = p.isUtc ? p : p.toUtc();
      return DateTime(u.year, u.month, u.day, u.hour, u.minute);
    }
  }
  try {
    final t = DateFormat(
      "EEEE, dd MMMM, yyyy 'at' HH:mm",
      'en_US',
    ).parseUtc(e.eventDateTimeFormatted);
    return DateTime(t.year, t.month, t.day, t.hour, t.minute);
  } catch (_) {
    return null;
  }
}

String hhmm(DateTime t) => DateFormat('HH:mm').format(t);

/// 'in 2h 30m' under 24 hours, 'in 2 days' otherwise, '' once started
/// (design §6.1).
String countdown(DateTime t, DateTime now) {
  final d = t.difference(now);
  if (d.inMinutes < 1) return '';
  if (d.inHours < 1) return 'in ${d.inMinutes}m';
  if (d.inHours < 24) {
    final m = d.inMinutes % 60;
    return m == 0 ? 'in ${d.inHours}h' : 'in ${d.inHours}h ${m}m';
  }
  final days = (d.inHours / 24).ceil();
  return days == 1 ? 'in 1 day' : 'in $days days';
}

bool isCancelled(EventsStruct e) => e.eventStatus == 'cancelled';

/// The user's member on this event can answer at all. The home RPC picks the
/// user's lowest-level member on the team and includes admins (level 100+)
/// even though they are not asked to attend; the event page only lists
/// player-grade members (level below 100), so match it here
/// (Ken, 2026-11-09: admin on 2018 Boys saw buttons on home but not details).
bool canReply(EventsStruct e) => e.memberRoleLevel < 100;

/// The user still owes an answer on this event.
bool needsReply(EventsStruct e) =>
    e.requestAttendance && canReply(e) && e.responseId == 0 && !isCancelled(e);

/// Three equal-weight numbers for coaches, "14 attending" + muted rest for
/// everyone else; the words are always in this order (Attending, No reply,
/// Declined).
String attendanceLabel(EventsStruct e) =>
    '${e.acceptedCount} attending, ${e.noResponseCount} no reply, '
    '${e.declinedCount} declined';

/// One row of the timeline: an event, or today's quiet-day marker.
class TimelineItem {
  TimelineItem.event(
    this.event,
    this.time, {
    required this.showDay,
    required this.isNext,
  }) : quiet = false;

  TimelineItem.quietDay(this.time)
    : event = null,
      showDay = true,
      isNext = false,
      quiet = true;

  final EventsStruct? event;
  final DateTime time;
  final bool showDay; // first row of a calendar day: draw the numeral
  final bool isNext; // the one pulsing dot
  final bool quiet; // "Nothing on today"

  DateTime get day => DateTime(time.year, time.month, time.day);
}

/// Events in date order with a day marker on the first row of each day, the
/// first non-cancelled upcoming event marked as next, and a quiet-day row for
/// today when today has nothing on (design §5.4, §6.1, §6.6, §6.7).
List<TimelineItem> buildTimeline(List<EventsStruct> events, DateTime now) {
  final today = DateTime(now.year, now.month, now.day);
  final timed = <(EventsStruct, DateTime)>[];
  for (final e in events) {
    final t = eventLocalTime(e);
    if (t != null) timed.add((e, t));
  }
  timed.sort((a, b) => a.$2.compareTo(b.$2));

  final items = <TimelineItem>[];
  final hasToday = timed.any(
    (x) => DateTime(x.$2.year, x.$2.month, x.$2.day).isAtSameMomentAs(today),
  );
  if (!hasToday) items.add(TimelineItem.quietDay(today));

  DateTime? lastDay;
  var nextFound = false;
  for (final (e, t) in timed) {
    final day = DateTime(t.year, t.month, t.day);
    final showDay = lastDay == null || !day.isAtSameMomentAs(lastDay);
    final isNext = !nextFound && !isCancelled(e);
    if (isNext) nextFound = true;
    items.add(TimelineItem.event(e, t, showDay: showDay, isNext: isNext));
    lastDay = day;
  }
  return items;
}

/// The day whose numeral is green: the day of the next event.
DateTime? nextDay(List<TimelineItem> items) {
  for (final i in items) {
    if (i.isNext) return i.day;
  }
  return null;
}
