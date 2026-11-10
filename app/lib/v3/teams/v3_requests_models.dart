// Rows of get_pending_team_requests for the v3 Requests page: people
// wanting to join a team (member_team_link pending) and people wanting
// access to an existing member (user_member_link pending).
import 'package:intl/intl.dart';

int _i(dynamic v) =>
    v is int ? v : (v is num ? v.toInt() : int.tryParse('$v') ?? 0);
String _s(dynamic v) => v == null ? '' : '$v';

/// "Today", "Yesterday", a weekday inside the last week, else "4 Nov".
String whenLabel(DateTime? t, DateTime now) {
  if (t == null) return '';
  final a = DateTime(t.year, t.month, t.day);
  final b = DateTime(now.year, now.month, now.day);
  final d = b.difference(a).inDays;
  if (d <= 0) return 'Today';
  if (d == 1) return 'Yesterday';
  if (d < 7) return DateFormat('EEE').format(t);
  return DateFormat('d MMM').format(t);
}

class TeamRequest {
  TeamRequest.join(Map j)
      : isAccess = false,
        refId = _i(j['member_team_id']),
        memberId = _i(j['member_id']),
        firstName = _s(j['first_name']),
        lastName = _s(j['last_name']),
        requestedAt = DateTime.tryParse(_s(j['requested_at']))?.toLocal(),
        requesterName = _s(j['requesting_user_name']).trim(),
        requesterEmail = _s(j['requesting_user_email']).trim();

  TeamRequest.access(Map j)
      : isAccess = true,
        refId = _i(j['user_member_id']),
        memberId = _i(j['member_id']),
        firstName = _s(j['first_name']),
        lastName = _s(j['last_name']),
        requestedAt = DateTime.tryParse(_s(j['requested_at']))?.toLocal(),
        requesterName = _s(j['requesting_user_name']).trim(),
        requesterEmail = _s(j['requesting_user_email']).trim();

  /// Access requests confirm/deny a user_member_link id; join requests a
  /// member_team_link id.
  final bool isAccess;
  final int refId, memberId;
  final String firstName, lastName, requesterName, requesterEmail;
  final DateTime? requestedAt;

  String get name => '$firstName $lastName'.trim();

  /// "Mary Byrne (mary@example.com)", or whichever part is known.
  String get requester {
    if (requesterName.isEmpty) return requesterEmail;
    if (requesterEmail.isEmpty) return requesterName;
    return '$requesterName ($requesterEmail)';
  }

  /// The line under the name.
  String subtitle(String teamName) {
    if (isAccess) {
      return requester.isEmpty
          ? 'Someone asks for access'
          : '$requester asks for access';
    }
    final join = teamName.isEmpty ? 'Wants to join' : 'Wants to join $teamName';
    return requester.isEmpty ? join : '$join\nRequested by $requester';
  }
}

class TeamRequests {
  TeamRequests.fromJson(Map j)
      : ok = j['success'] != false,
        message = _s(j['message']),
        joins = [
          for (final r in (j['member_requests'] is List
              ? j['member_requests'] as List
              : const []))
            if (r is Map) TeamRequest.join(r)
        ],
        access = [
          for (final r in (j['access_requests'] is List
              ? j['access_requests'] as List
              : const []))
            if (r is Map) TeamRequest.access(r)
        ],
        roles = j['available_roles'] is List
            ? (j['available_roles'] as List)
            : const [];

  final bool ok;
  final String message;
  final List<TeamRequest> joins, access;

  /// Roles of the team (role_id, role_name, role_grade, role_level).
  final List roles;

  bool get isEmpty => joins.isEmpty && access.isEmpty;
}
