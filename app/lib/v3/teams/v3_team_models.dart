// Plain models parsed from the team RPCs (get_user_team_summary,
// get_team_members_by_role, get_member_team_details). The exported
// FlutterFlow structs miss the newer fields, so the raw JSON is read here.
import 'package:flutter/material.dart';

import '../v3_crest_image.dart';
import '../v3_theme.dart';
import '/v3/v3_squads.dart';

int _i(dynamic v) =>
    v is int ? v : (v is num ? v.toInt() : int.tryParse('$v') ?? 0);
String _s(dynamic v) => v == null ? '' : '$v';
List<Map<String, dynamic>> _l(dynamic v) => v is List
    ? v.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
    : const [];

class TeamSummary {
  TeamSummary.fromJson(Map<String, dynamic> j)
      : teamId = _i(j['team_id']),
        teamName = _s(j['team_name']),
        teamCode = _s(j['team_unique_code']),
        clubId = _i(j['club_id']),
        clubName = _s(j['club_name']),
        clubCrest = _s(j['club_crest']),
        roleLevel = _i(j['team_highest_role_level']),
        roleName = _s(j['team_role_name']),
        roleNames = (j['role_names'] is List)
            ? (j['role_names'] as List).map((e) => '$e').toList()
            : [_s(j['team_role_name'])],
        players = _i(j['player_count']),
        coaches = _i(j['coach_count']),
        admins = _i(j['admin_count']),
        pending = _i(j['pending_approvals']);
  final int teamId;
  final String teamName, teamCode, clubName, clubCrest, roleName;
  final int clubId, roleLevel, players, coaches, admins, pending;
  final List<String> roleNames;

  /// Roles in the order they are shown: highest first.
  List<String> get rolesSorted {
    const order = ['SuperUser', 'Admin', 'Coach', 'FLO', 'Player'];
    final out = [...roleNames]..sort((a, b) {
        final ia = order.indexOf(a), ib = order.indexOf(b);
        return (ia < 0 ? 99 : ia).compareTo(ib < 0 ? 99 : ib);
      });
    return out;
  }
}

class SquadCode {
  SquadCode.fromJson(Map<String, dynamic> j)
      : codeId = _i(j['code_id']),
        codeName = _s(j['code_name']),
        // No Team counts as Unassigned (0), the same as no squad.
        squadId = isNoTeamSquad(_s(j['squad_name'])) ? 0 : _i(j['squad_id']),
        squadName =
            isNoTeamSquad(_s(j['squad_name'])) ? '' : _s(j['squad_name']),
        squadImage =
            isNoTeamSquad(_s(j['squad_name'])) ? '' : _s(j['squad_image']);
  final int codeId, squadId;
  final String codeName, squadName, squadImage;
}

class TeamMember {
  TeamMember.fromJson(Map<String, dynamic> j)
      : memberId = _i(j['member_id']),
        firstName = _s(j['first_name']),
        lastName = _s(j['last_name']),
        squadCodes = _l(j['squad_codes']).map(SquadCode.fromJson).toList();
  final int memberId;
  final String firstName, lastName;
  final List<SquadCode> squadCodes;
  String get fullName => '$firstName $lastName'.trim();
  SquadCode? squadFor(int codeId) {
    for (final s in squadCodes) {
      if (s.codeId == codeId) return s;
    }
    return null;
  }
}

class RoleGroup {
  RoleGroup.fromJson(Map<String, dynamic> j)
      : roleName = _s(j['role_name']),
        roleNamePlural = _s(j['role_name_plural']),
        roleLevel = _i(j['role_level']),
        members = _l(j['members']).map(TeamMember.fromJson).toList()
          ..sort((a, b) =>
              a.firstName.toLowerCase().compareTo(b.firstName.toLowerCase()));
  final String roleName, roleNamePlural;
  final int roleLevel;
  final List<TeamMember> members;
}

class ClubCode {
  ClubCode.fromJson(Map<String, dynamic> j)
      : codeId = _i(j['code_id']),
        name = _s(j['event_code']);
  final int codeId;
  final String name;
}

class TeamRoster {
  TeamRoster.fromJson(Map<String, dynamic> j)
      : teamId = _i(j['team_id']),
        teamName = _s(j['team_name']),
        teamCode = _s(j['team_unique_code']),
        clubId = _i(j['club_id']),
        userRoleLevel = _i(j['user_highest_role_level']),
        groups = _l(j['role_groups']).map(RoleGroup.fromJson).toList()
          ..sort((a, b) => a.roleLevel.compareTo(b.roleLevel)),
        // Code 1 is "-" (events with no code). v2 still lists it, but v3
        // never uses it for squads (Ken, 2026-11-11): event squads fall
        // back to the team's first real code (get_updated_event_code).
        codes = _l(j['club_codes'])
            .map(ClubCode.fromJson)
            .where((c) => c.codeId > 1)
            .toList()
          ..sort((a, b) => a.codeId.compareTo(b.codeId));
  final int teamId, clubId, userRoleLevel;
  final String teamName, teamCode;
  final List<RoleGroup> groups;
  final List<ClubCode> codes;

  TeamMember? member(int id) {
    for (final g in groups) {
      for (final m in g.members) {
        if (m.memberId == id) return m;
      }
    }
    return null;
  }

  int count(bool Function(int level) test) {
    final ids = <int>{};
    for (final g in groups) {
      if (test(g.roleLevel)) ids.addAll(g.members.map((m) => m.memberId));
    }
    return ids.length;
  }
}

class MemberRole {
  MemberRole.fromJson(Map<String, dynamic> j)
      : roleId = _i(j['role_id']),
        roleName = _s(j['role_name']),
        roleLevel = _i(j['role_level']),
        roleGrade = _i(j['role_grade']);
  final int roleId, roleLevel, roleGrade;
  final String roleName;
}

class LinkedUser {
  LinkedUser.fromJson(Map<String, dynamic> j)
      : userId = _s(j['user_id']),
        email = _s(j['email']),
        name = '${_s(j['first_name'])} ${_s(j['last_name'])}'.trim();
  final String userId, email, name;
}

class MemberDetails {
  MemberDetails.fromJson(Map<String, dynamic> j)
      : memberId = _i(j['member_id']),
        firstName = _s(j['first_name']),
        lastName = _s(j['last_name']),
        memberCode = _s(j['member_code']),
        teamId = _i(j['team_id']),
        teamName = _s(j['team_name']),
        roles = _l(j['member_roles']).map(MemberRole.fromJson).toList(),
        validRoles = _l(j['valid_team_roles']).map(MemberRole.fromJson).toList()
          ..sort((a, b) => a.roleLevel.compareTo(b.roleLevel)),
        linkedUsers = _l(j['linked_users']).map(LinkedUser.fromJson).toList();
  final int memberId, teamId;
  final String firstName, lastName, memberCode, teamName;
  final List<MemberRole> roles, validRoles;
  final List<LinkedUser> linkedUsers;
  String get fullName => '$firstName $lastName'.trim();
  bool hasRole(int roleId) => roles.any((r) => r.roleId == roleId);
}

// ---- small shared widgets ---------------------------------------------------

String initials(String first, String last) {
  final a = first.isNotEmpty ? first[0] : '';
  final b = last.isNotEmpty ? last[0] : '';
  final s = (a + b).toUpperCase();
  return s.isEmpty ? '?' : s;
}

class V3Avatar extends StatelessWidget {
  const V3Avatar(this.text,
      {super.key, this.size = 40, this.highlight = false});
  final String text;
  final double size;
  final bool highlight;
  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
            color: highlight ? const Color(0xFF1D5A2E) : V3.line,
            shape: BoxShape.circle),
        child: Text(text,
            style: V3.tight(size * .35,
                weight: FontWeight.w700,
                color: highlight ? const Color(0xFFF4D03F) : V3.text)),
      );
}

class V3Crest extends StatelessWidget {
  const V3Crest(this.url, {super.key, this.size = 48});
  final String url;
  final double size;
  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        padding: EdgeInsets.all(size * .08),
        decoration: BoxDecoration(
            color: const Color(0xFF20272F),
            borderRadius: BorderRadius.circular(size * .22)),
        child: url.isEmpty
            ? Icon(Icons.shield_outlined, color: V3.muted, size: size * .5)
            : V3CrestImage(url,
                size: size * .84,
                fallback: Icon(Icons.shield_outlined,
                    color: V3.muted, size: size * .5)),
      );
}

/// "A squad" chip with the squad's colour dot or image; dashed "No squad".
class V3SquadChip extends StatelessWidget {
  const V3SquadChip(this.squad, {super.key, this.onTap});
  final SquadCode? squad;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) {
    final s = squad;
    final none = s == null || s.squadId == 0;
    final chip = Container(
      padding: EdgeInsets.fromLTRB(none ? 9 : 5, 4, 9, 4),
      decoration: BoxDecoration(
        color: none ? Colors.transparent : V3.card2,
        borderRadius: BorderRadius.circular(9),
        border: none ? Border.all(color: V3.barGrey, width: 1) : null,
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (!none) ...[
          ClipOval(
            child: s.squadImage.isNotEmpty
                ? Image.network(s.squadImage,
                    width: 18,
                    height: 18,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) =>
                        Container(width: 18, height: 18, color: V3.green))
                : Container(width: 18, height: 18, color: V3.green),
          ),
          const SizedBox(width: 6),
        ],
        Text(none ? kUnassigned : s.squadName,
            style: V3.inter(13,
                weight: FontWeight.w600, color: none ? V3.muted : V3.text)),
        if (onTap != null) ...[
          const SizedBox(width: 2),
          Icon(Icons.expand_more, size: 16, color: none ? V3.muted : V3.text),
        ],
      ]),
    );
    return onTap == null ? chip : GestureDetector(onTap: onTap, child: chip);
  }
}

class V3Pill extends StatelessWidget {
  const V3Pill(this.text, {super.key, this.green = false});
  final String text;
  final bool green;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
        decoration: BoxDecoration(
            color: green ? V3.greenTint : V3.card2,
            borderRadius: BorderRadius.circular(8)),
        child: Text(text,
            style: V3.inter(12.5,
                weight: FontWeight.w600, color: green ? V3.green : V3.muted)),
      );
}

/// Amber "N requests waiting for approval" strip.
class V3PendingStrip extends StatelessWidget {
  const V3PendingStrip(this.count, {super.key, required this.onTap});
  final int count;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
          decoration: BoxDecoration(
              color: V3.amberTint,
              border: Border.all(color: V3.amberLine),
              borderRadius: BorderRadius.circular(12)),
          child: Row(children: [
            Text('$count',
                style:
                    V3.inter(15, weight: FontWeight.w700, color: V3.amberText)),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                  count == 1
                      ? 'request waiting for approval'
                      : 'requests waiting for approval',
                  style: V3.inter(14.5,
                      weight: FontWeight.w500, color: V3.amberText)),
            ),
            const Icon(Icons.chevron_right, color: V3.amberText, size: 22),
          ]),
        ),
      );
}

String countsLine(int players, int coaches, int admins) {
  String p(int n, String one, String many) => '$n ${n == 1 ? one : many}';
  return [
    p(players, 'player', 'players'),
    if (coaches > 0) p(coaches, 'coach', 'coaches'),
    if (admins > 0) p(admins, 'admin', 'admins'),
  ].join(' · ');
}

/// One of the team's squads (squads table), in squad_list_seq order.
class TeamSquad {
  const TeamSquad(this.squadId, this.name, this.image, this.colour);
  final int squadId;
  final String name, image, colour;

  Color get colourValue {
    final hex = colour.replaceAll('#', '');
    if (hex.length == 6) {
      final v = int.tryParse(hex, radix: 16);
      if (v != null) return Color(0xFF000000 | v);
    }
    return V3.green;
  }
}

/// A squad card on the Team page: squad (null = No squad), distinct people
/// in it for the code picked, and "Players: 12" lines per role.
class TeamSquadCard {
  const TeamSquadCard(this.squadId, this.squad, this.count, this.lines);
  final int squadId; // 0 = No squad
  final TeamSquad? squad;
  final int count;
  final List<String> lines;
  String get name => squad?.name ?? kUnassigned;
}

int memberSquadId(TeamMember m, int codeId) => m.squadFor(codeId)?.squadId ?? 0;

/// Squad cards for one code: each squad, then No squad when anyone has none.
List<TeamSquadCard> teamSquadCards(
    TeamRoster r, int codeId, List<TeamSquad> squads) {
  TeamSquadCard card(int squadId, TeamSquad? s) {
    final ids = <int>{};
    final lines = <String>[];
    for (final g in r.groups) {
      final inGroup = {
        for (final m in g.members)
          if (memberSquadId(m, codeId) == squadId) m.memberId
      };
      // The big number is the players; the lines are every other role.
      if (g.roleLevel == 10) {
        ids.addAll(inGroup);
      } else if (g.roleLevel < 100) {
        // Grade 10 roles only (FLO, Coach), zero or not (Ken, 2026-11-11).
        lines.add('${g.roleNamePlural}: ${inGroup.length}');
      }
    }
    return TeamSquadCard(squadId, s, ids.length, lines);
  }

  final anyNone =
      r.groups.any((g) => g.members.any((m) => memberSquadId(m, codeId) == 0));
  return [
    for (final s in squads) card(s.squadId, s),
    if (anyNone) card(0, null),
  ];
}

/// Members in squad order (squad_list_seq, no squad last), then by name.
List<TeamMember> orderBySquad(
    List<TeamMember> members, int? codeId, List<TeamSquad> squads) {
  if (codeId == null) return members;
  int rank(TeamMember m) {
    final i = squads.indexWhere((s) => s.squadId == memberSquadId(m, codeId));
    return i < 0 ? squads.length : i;
  }

  final order = {for (var i = 0; i < members.length; i++) members[i]: i};
  return [...members]..sort((a, b) {
      final c = rank(a).compareTo(rank(b));
      return c != 0 ? c : order[a]!.compareTo(order[b]!);
    });
}
