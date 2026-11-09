// Data for the v3 attendance page: the result of get_event_attendance_v3
// (one call: event, squads, visible roles, members with their latest reply)
// plus the grouping the page shows (Ken, 2026-11-09: squad cards at the top
// as today, squad under each name, tabs Attending / No reply / Declined).

const int kAttending = 3;
const int kDeclined = 4;
const int kNoReply = 0;

int _i(dynamic v) =>
    v is int ? v : (v is num ? v.toInt() : int.tryParse('$v') ?? 0);
String _s(dynamic v) => v == null ? '' : '$v';

class AttSquad {
  AttSquad.fromJson(Map j)
      : squadId = _i(j['squad_id']),
        squadName = _s(j['squad_name']),
        squadImage = _s(j['squad_image']),
        squadColour = _s(j['squad_colour']);
  final int squadId;
  final String squadName, squadImage, squadColour;
}

class AttRole {
  AttRole.fromJson(Map j)
      : roleId = _i(j['role_id']),
        roleName = _s(j['role_name']),
        roleNamePlural = _s(j['role_name_plural']),
        roleLevel = _i(j['role_level']);
  final int roleId, roleLevel;
  final String roleName, roleNamePlural;
  String get plural => roleNamePlural.isNotEmpty ? roleNamePlural : roleName;
}

class AttMember {
  AttMember.fromJson(Map j)
      : memberId = _i(j['member_id']),
        memberName = _s(j['member_name']),
        firstName = _s(j['first_name']),
        lastName = _s(j['last_name']),
        roleId = _i(j['role_id']),
        roleLevel = _i(j['role_level']),
        squadId = _i(j['squad_id']),
        squadName = _s(j['squad_name']),
        responseId = j['response_id'] == null ? kNoReply : _i(j['response_id']);
  final int memberId, roleId, roleLevel, squadId, responseId;
  final String memberName, firstName, lastName, squadName;

  /// Which tab the member sits in: 3, 4, or 0 for anything else.
  int get tab => responseId == kAttending || responseId == kDeclined
      ? responseId
      : kNoReply;
}

class AttendanceData {
  AttendanceData.fromJson(Map j)
      : error = _s(j['error']),
        eventId = _i(j['event_id']),
        eventTitle = _s(j['event_title']),
        isMatch = j['is_match'] == true,
        userRoleLevel = _i(j['user_role_level']),
        teamId = _i(j['team_id']),
        codeId = _i(j['code_id']),
        eventSquadId = _i(j['event_squad_id']),
        allowLineup = j['allow_lineup'] == true,
        matchSquadId =
            j['match_squad_id'] == null ? 0 : _i(j['match_squad_id']),
        publishedAt = DateTime.tryParse(_s(j['published_at']))?.toLocal(),
        squads = [
          for (final s in (j['squads'] as List? ?? [])) AttSquad.fromJson(s)
        ],
        roles = [
          for (final r in (j['roles'] as List? ?? [])) AttRole.fromJson(r)
        ],
        members = [
          for (final m in (j['members'] as List? ?? [])) AttMember.fromJson(m)
        ];

  final String error, eventTitle;
  final int eventId, userRoleLevel, teamId, codeId, eventSquadId, matchSquadId;
  final bool isMatch, allowLineup;
  final DateTime? publishedAt;
  final List<AttSquad> squads;
  final List<AttRole> roles;
  final List<AttMember> members;

  bool get hasError => error.isNotEmpty;
  bool get admin => userRoleLevel >= 100;
  bool get published => matchSquadId > 0;
  bool get hasSquads => squads.isNotEmpty;

  /// Rows on one tab (a member with two roles appears under each role).
  List<AttMember> onTab(int tab) => [
        for (final m in members)
          if (m.tab == tab) m
      ];

  /// Distinct people on one tab, for the tab counts.
  int count(int tab) => {for (final m in onTab(tab)) m.memberId}.length;

  /// Rows on one tab in one squad (0 = no squad, null = every squad).
  List<AttMember> rows(int tab, int? squadId) => [
        for (final m in onTab(tab))
          if (squadId == null || m.squadId == squadId) m
      ];

  /// Role groups in role order for the rows given, empty groups left out.
  List<(AttRole, List<AttMember>)> groups(List<AttMember> rows) => [
        for (final r in roles)
          if (rows.any((m) => m.roleId == r.roleId))
            (
              r,
              [
                for (final m in rows)
                  if (m.roleId == r.roleId) m
              ]
            )
      ];

  /// Squad cards for one tab: All, each squad, and No squad when anyone on
  /// the tab has none. Count = distinct people, lines = "Players: 7" per role.
  List<SquadCard> squadCards(int tab) {
    final out = <SquadCard>[];
    SquadCard card(int? squadId, String name, AttSquad? squad) {
      final rs = rows(tab, squadId);
      final lines = <String>[
        for (final g in groups(rs))
          '${g.$1.plural}: ${{for (final m in g.$2) m.memberId}.length}'
      ];
      return SquadCard(
          squadId, name, squad, {for (final m in rs) m.memberId}.length, lines);
    }

    out.add(card(null, 'All', null));
    for (final s in squads) {
      out.add(card(s.squadId, s.squadName, s));
    }
    if (onTab(tab).any((m) => m.squadId == 0)) {
      out.add(card(0, 'No squad', null));
    }
    return out;
  }

  AttSquad? squad(int id) {
    for (final s in squads) {
      if (s.squadId == id) return s;
    }
    return null;
  }
}

class SquadCard {
  const SquadCard(this.squadId, this.name, this.squad, this.count, this.lines);
  final int? squadId; // null = All, 0 = No squad
  final String name;
  final AttSquad? squad;
  final int count;
  final List<String> lines;
}

/// "Published Sat 9 Nov, 10:02" or "Not published yet".
String publishedLabel(DateTime? at) {
  if (at == null) return 'Not published yet';
  const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec'
  ];
  final hh = at.hour.toString().padLeft(2, '0');
  final mm = at.minute.toString().padLeft(2, '0');
  return 'Published ${days[at.weekday - 1]} ${at.day} ${months[at.month - 1]}, $hh:$mm';
}

String tabLabel(int tab) => tab == kAttending
    ? 'Attending'
    : tab == kDeclined
        ? 'Declined'
        : 'No reply';

String emptyText(int tab) => tab == kAttending
    ? 'Nobody has said they are attending yet.'
    : tab == kDeclined
        ? 'Nobody has declined.'
        : 'Everyone has replied.';
