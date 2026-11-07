// Helpers that turn get_user_home_events rows into what the v3 home shows:
// local times, day groups and the reply state of each card.
import '/backend/schema/structs/index.dart';
import 'package:intl/intl.dart';

/// The RPC formats event_date_time in UTC as
/// 'Saturday, 07 November, 2026 at 10:00'. Parse it back and show local time.
DateTime? eventLocalTime(EventsStruct e) {
  try {
    final utc = DateFormat("EEEE, dd MMMM, yyyy 'at' HH:mm", 'en_US')
        .parseUtc(e.eventDateTimeFormatted);
    return utc.toLocal();
  } catch (_) {
    return null;
  }
}

String hhmm(DateTime t) => DateFormat('HH:mm').format(t);

/// 'in 2h 15m', 'in 3 days', 'now'.
String countdown(DateTime t, DateTime now) {
  final d = t.difference(now);
  if (d.inMinutes < 1) return 'now';
  if (d.inHours < 1) return 'in ${d.inMinutes}m';
  if (d.inHours < 24) {
    final m = d.inMinutes % 60;
    return m == 0 ? 'in ${d.inHours}h' : 'in ${d.inHours}h ${m}m';
  }
  final days = d.inDays;
  return days == 1 ? 'in 1 day' : 'in $days days';
}

class EventGroup {
  EventGroup(this.label, this.dateText, this.events, {this.far = false});
  final String label; // Today, Tomorrow, Saturday ...
  final String dateText; // 'Thu 5 Nov' or ''
  final List<EventsStruct> events;
  final bool far; // cards in far groups show their date instead of meet time
}

List<EventGroup> groupEvents(List<EventsStruct> events, DateTime now) {
  final today = DateTime(now.year, now.month, now.day);
  final groups = <String, EventGroup>{};
  final order = <String>[];
  for (final e in events) {
    final t = eventLocalTime(e);
    if (t == null) continue;
    final day = DateTime(t.year, t.month, t.day);
    final diff = day.difference(today).inDays;
    String key, label, date = DateFormat('EEE d MMM').format(day);
    if (diff <= 0) {
      key = 'd$diff';
      label = 'Today';
    } else if (diff == 1) {
      key = 'd1';
      label = 'Tomorrow';
    } else {
      // Day and date for everything else; no "Next week" / "Later"
      // buckets (Ken, 2026-11-07).
      key = 'd$diff';
      label = DateFormat('EEEE').format(day);
      date = DateFormat('d MMM').format(day);
    }
    if (!groups.containsKey(key)) {
      groups[key] = EventGroup(label, date, []);
      order.add(key);
    }
    groups[key]!.events.add(e);
  }
  return [for (final k in order) groups[k]!];
}

bool isCancelled(EventsStruct e) => e.eventStatus == 'cancelled';

/// The user still owes an answer on this event.
bool needsReply(EventsStruct e) =>
    e.requestAttendance && e.responseId == 0 && !isCancelled(e);
