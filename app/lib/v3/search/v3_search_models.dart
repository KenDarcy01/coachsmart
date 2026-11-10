// Rows of get_events_list for the v3 Search events page.
import 'package:intl/intl.dart';

int _i(dynamic v) =>
    v is int ? v : (v is num ? v.toInt() : int.tryParse('$v') ?? 0);
String _s(dynamic v) => v == null ? '' : '$v';

/// The RPC formats event_date_time (UTC) as
/// 'Saturday, 07 November, 2026 at 10:00'.
DateTime? parseSearchTime(String s) {
  try {
    return DateFormat("EEEE, dd MMMM, yyyy 'at' HH:mm", 'en_US')
        .parseUtc(s)
        .toLocal();
  } catch (_) {
    return null;
  }
}

/// 'Sat 7 Nov 2026 · 10:00', else the text as the server sent it.
String searchDateLabel(String formatted) {
  final t = parseSearchTime(formatted);
  if (t == null) return formatted;
  return '${DateFormat('EEE d MMM yyyy').format(t)} · ${DateFormat('HH:mm').format(t)}';
}

class SearchEvent {
  SearchEvent.fromJson(Map j)
      : eventId = _i(j['event_id']),
        teamId = _i(j['team_id']),
        title = _s(j['event_title']),
        teamName = _s(j['team_name']),
        eventType = _s(j['event_type']),
        eventCode = _s(j['event_code']),
        opposition = _s(j['opposition']),
        locationName = _s(j['location_name']),
        status = _s(j['event_status']),
        dateText = _s(j['event_date_time_formatted']),
        accepted = _i(j['accepted_count']),
        declined = _i(j['declined_count']),
        noReply = _i(j['no_response_count']),
        eligible = _i(j['total_eligible_members']);

  final int eventId, teamId, accepted, declined, noReply, eligible;
  final String title,
      teamName,
      eventType,
      eventCode,
      opposition,
      locationName,
      status,
      dateText;

  DateTime? get time => parseSearchTime(dateText);
  String get dateLabel => searchDateLabel(dateText);
  bool get cancelled => status.toLowerCase() == 'cancelled';
}

/// Parameters for get_events_list. 0 or empty means "any".
class SearchFilters {
  SearchFilters(
      {this.teamId = 0,
      this.typeId = 0,
      this.codeId = 0,
      this.opposition = '',
      this.from,
      this.to});
  final int teamId, typeId, codeId;
  final String opposition;
  final DateTime? from, to;

  Map<String, dynamic> toParams() => {
        'p_team_id': teamId,
        'p_code_id': codeId,
        'p_type_id': typeId,
        'p_date_from':
            from == null ? '' : DateFormat('yyyy-MM-dd').format(from!),
        'p_date_to': to == null
            ? ''
            : DateFormat('yyyy-MM-dd').format(to!.add(const Duration(days: 1))),
        'p_opposition': opposition.trim(),
      };
}
