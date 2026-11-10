// Data for the v3 Profile page: get_edit_user_data (user, clubs, members)
// plus each member's roles, and the local push-notification preference.
import 'package:shared_preferences/shared_preferences.dart';

int _i(dynamic v) =>
    v is int ? v : (v is num ? v.toInt() : int.tryParse('$v') ?? 0);
String _s(dynamic v) => v == null ? '' : '$v';

class ProfileClub {
  ProfileClub.fromJson(Map j)
      : clubId = _i(j['club_id']),
        clubName = _s(j['club_name']);
  final int clubId;
  final String clubName;
}

/// One member linked to the user in one team.
class UserMember {
  UserMember.fromJson(Map j)
      : memberId = _i(j['member_id']),
        memberTeamId = _i(j['member_team_id']),
        firstName = _s(j['first_name']),
        lastName = _s(j['last_name']),
        fullName = _s(j['full_name']),
        memberCode = _s(j['unique_member_code']),
        teamId = _i(j['team_id']),
        teamName = _s(j['team_name']),
        clubName = _s(j['club_name']);
  final int memberId, memberTeamId, teamId;
  final String firstName, lastName, fullName, memberCode, teamName, clubName;

  /// Filled from member_team_role_link: names and the highest level.
  List<String> roleNames = [];
  int roleLevel = 0;

  /// "Clontarf Boys 2017 · Coach" (roles joined when more than one).
  String get subtitle =>
      roleNames.isEmpty ? teamName : '$teamName · ${roleNames.join(', ')}';

  /// The member page is for coaches and up (as on the team page).
  bool get canOpenMemberPage => roleLevel >= 30;
}

class ProfileData {
  ProfileData.fromJson(Map j)
      : userId = _s((j['user'] as Map?)?['user_id']),
        email = _s((j['user'] as Map?)?['email_address']),
        firstName = _s((j['user'] as Map?)?['first_name']),
        lastName = _s((j['user'] as Map?)?['last_name']),
        phone = _s((j['user'] as Map?)?['phone_number']),
        defaultClub = _i((j['user'] as Map?)?['default_club']),
        clubs = [
          for (final c in (j['clubs'] as List? ?? []))
            if (c is Map) ProfileClub.fromJson(c)
        ],
        members = [
          for (final m in (j['userMembers'] as List? ?? []))
            if (m is Map) UserMember.fromJson(m)
        ];
  final String userId, email, firstName, lastName, phone;
  final int defaultClub;
  final List<ProfileClub> clubs;
  final List<UserMember> members;

  /// Apply role rows (member_team_id, roles{role_name, role_level}) to members.
  void applyRoles(List rows) {
    for (final r in rows) {
      if (r is! Map) continue;
      final id = _i(r['member_team_id']);
      final role = r['roles'];
      if (role is! Map) continue;
      for (final m in members) {
        if (m.memberTeamId != id) continue;
        final name = _s(role['role_name']);
        if (name.isNotEmpty && !m.roleNames.contains(name)) {
          m.roleNames.add(name);
        }
        final lvl = _i(role['role_level']);
        if (lvl > m.roleLevel) m.roleLevel = lvl;
      }
    }
  }
}

String initialsFor(String first, String last) {
  final a = first.isNotEmpty ? first[0] : '';
  final b = last.isNotEmpty ? last[0] : '';
  final s = (a + b).toUpperCase();
  return s.isEmpty ? '?' : s;
}

/// Push notifications on this device. Stored locally: off clears the
/// user's FCM token and stops the home page registering a new one.
class PushPref {
  static const _key = 'v3_push_off';
  static Future<bool> enabled() async {
    try {
      final p = await SharedPreferences.getInstance();
      return !(p.getBool(_key) ?? false);
    } catch (_) {
      return true;
    }
  }

  static Future<void> setEnabled(bool on) async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.setBool(_key, !on);
    } catch (_) {}
  }
}

const String kV3VersionLabel = 'CoachSmart 3.0 preview';
