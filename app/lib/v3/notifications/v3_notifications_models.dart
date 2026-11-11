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

  NotifItem._read(NotifItem n)
      : id = n.id,
        createdAt = n.createdAt,
        timeLabel = n.timeLabel,
        title = n.title,
        body = n.body,
        isRead = true,
        teamId = n.teamId,
        teamName = n.teamName,
        eventId = n.eventId,
        memberId = n.memberId,
        action = n.action,
        actionRefId = n.actionRefId;

  /// The same row, read.
  NotifItem asRead() => NotifItem._read(this);

  final int id, teamId, eventId, memberId, actionRefId;
  final DateTime? createdAt;
  final String timeLabel, title, body, teamName, action;
  final bool isRead;

  /// A join request to approve or decline (member_team_link id in actionRefId).
  bool get isJoinRequest => action == 'approve_member';

  /// A request to link a user to a member (user_member_link id in actionRefId).
  bool get isAccessRequest => action == 'approve_access';
  bool get isRequest => isJoinRequest || isAccessRequest;

  /// An event reminder: the user's children still need to answer.
  bool get isAttend => action == 'attend' && eventId > 0;

  /// Needs the user to do something, so it stays unread until done (by this
  /// user or, for requests and shared children, by someone else). Every other
  /// row is a plain notice and is marked read 2 seconds after the page opens,
  /// as the FlutterFlow page does (mark_all_notifications_read only touches
  /// rows with no action).
  bool get needsAction => action.isNotEmpty;
}

/// One of the user's children on an event reminder, with the answer saved
/// so far (3 going, 4 can't go, anything else no answer).
class NotifMember {
  NotifMember(this.memberId, this.name, this.responseId);
  final int memberId;
  final String name;
  int responseId;
  bool get answered => responseId == 3 || responseId == 4;
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
