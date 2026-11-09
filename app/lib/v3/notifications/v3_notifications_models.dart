// Rows of get_user_notifications and the grouping the v3 page shows
// (Today / Yesterday / Earlier). Titles and bodies stay as the server
// writes them.
import 'package:intl/intl.dart';

int _i(dynamic v) =>
    v is int ? v : (v is num ? v.toInt() : int.tryParse('$v') ?? 0);
String _s(dynamic v) => v == null ? '' : '$v';

/// created_at comes back as text: "Mon, 09 Nov 2026 at 05:30 PM" (UTC).
DateTime? parseNotifTime(String s) {
  if (s.isEmpty) return null;
  try {
    return DateFormat("EEE, dd MMM yyyy 'at' hh:mm a", 'en_US')
        .parseUtc(s)
        .toLocal();
  } catch (_) {
    return DateTime.tryParse(s)?.toLocal();
  }
}

/// "Today", "Yesterday" or "Earlier" for a time, by calendar day.
String dayGroup(DateTime? t, DateTime now) {
  if (t == null) return 'Earlier';
  final a = DateTime(t.year, t.month, t.day);
  final b = DateTime(now.year, now.month, now.day);
  final d = b.difference(a).inDays;
  if (d <= 0) return 'Today';
  if (d == 1) return 'Yesterday';
  return 'Earlier';
}

class NotifItem {
  NotifItem.fromJson(Map j)
      : id = _i(j['id']),
        createdAt = parseNotifTime(_s(j['created_at'])),
        timeLabel = _s(j['time_label']),
        title = _s(j['app_title']),
        body = _s(j['app_body']),
        isRead = j['is_read'] == true,
        teamId = _i(j['team_id']),
        teamName = _s(j['team_name']),
        eventId = _i(j['event_id']),
        memberId = _i(j['member_id']),
        action = _s(j['action']),
        actionRefId = _i(j['action_ref_id']);

  final int id, teamId, eventId, memberId, actionRefId;
  final DateTime? createdAt;
  final String timeLabel, title, body, teamName, action;
  final bool isRead;

  /// A join request to approve or decline (member_team_link id in actionRefId).
  bool get isJoinRequest => action == 'approve_member';

  /// A request to link a user to a member (user_member_link id in actionRefId).
  bool get isAccessRequest => action == 'approve_access';
  bool get isRequest => isJoinRequest || isAccessRequest;

  /// Tapping opens the event (reply requests and event alerts).
  bool get opensEvent => !isRequest && eventId > 0;
}

/// Items in groups, newest first inside each, groups in Today, Yesterday,
/// Earlier order with empty groups left out.
List<(String, List<NotifItem>)> groupNotifs(
    List<NotifItem> items, DateTime now) {
  final map = <String, List<NotifItem>>{};
  for (final n in items) {
    map.putIfAbsent(dayGroup(n.createdAt, now), () => []).add(n);
  }
  return [
    for (final g in const ['Today', 'Yesterday', 'Earlier'])
      if (map.containsKey(g)) (g, map[g]!)
  ];
}
