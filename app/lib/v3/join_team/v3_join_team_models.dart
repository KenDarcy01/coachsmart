// Pure data and rules for the v3 Join Team flow, a native copy of
// webviews/join-team.html. No Supabase here, so tests can cover every
// branch: how each RPC answer is read and which screen comes next.

int _i(dynamic v) =>
    v is int ? v : (v is num ? v.toInt() : int.tryParse('${v ?? ''}') ?? 0);
String _s(dynamic v) => v == null ? '' : '$v';

/// The screens of the flow, as on the web page.
enum JoinStep {
  who,
  theirName,
  memberCode,
  code,
  found,
  alreadyPending,
  pendingOther,
  sent,
  newTeam,
  newTeamSent,
  done,
}

/// Screens with no way back on the web page: the result screens.
/// The app bar back closes the whole flow there.
bool isEndStep(JoinStep s) => const {
      JoinStep.alreadyPending,
      JoinStep.pendingOther,
      JoinStep.sent,
      JoinStep.newTeamSent,
      JoinStep.done,
    }.contains(s);

/// Who is being added: the signed-in user or someone else.
class Registering {
  const Registering(this.firstName, this.lastName, {this.isMyself = false});
  final String firstName, lastName;
  final bool isMyself;
  String get name => '$firstName $lastName'.trim();
}

/// An existing member the user can ask to be linked to.
class FoundMember {
  const FoundMember(this.memberId, this.name, this.teamName);
  final int? memberId;
  final String name, teamName;
}

/// Codes are upper case and trimmed, as the page does on input.
String cleanCode(String raw) => raw.trim().toUpperCase();

/// The live team lookup starts at three characters.
bool shouldLookUp(String code) => cleanCode(code).length >= 3;

/// get_team_by_code: the team name, or null when the code is not known.
String? teamNameFromLookup(dynamic data) {
  if (data is Map) {
    final n = _s(data['team_name']);
    if (n.isNotEmpty) return n;
  }
  return null;
}

String requestButtonLabel(String? teamName) =>
    teamName == null ? 'Request to Join' : 'Request to Join $teamName';

/// The answer of create_new_member_by_code, read into what to show next.
enum JoinOutcome {
  error,
  alreadyMember,
  duplicate,
  alreadyPending,
  pendingOther,
  pending,
  unknown,
}

class JoinResult {
  JoinResult(this.outcome,
      {this.message = '', this.teamName = '', this.memberId});
  final JoinOutcome outcome;
  final String message, teamName;
  final int? memberId;

  /// [resolvedTeam] is the name the live lookup found, used when the RPC
  /// does not return one; [memberName] fills the already-member message.
  factory JoinResult.fromRpc(dynamic data,
      {String? resolvedTeam, required String memberName}) {
    final j = data is Map ? data : const {};
    final status = _s(j['status']);
    final team = _s(j['team_name']).isNotEmpty
        ? _s(j['team_name'])
        : (resolvedTeam ?? 'the team');
    final msg = _s(j['message']);
    switch (status) {
      case 'error':
        return JoinResult(JoinOutcome.error,
            message: msg.isNotEmpty ? msg : kTryAgain, teamName: team);
      case 'already_member':
        return JoinResult(JoinOutcome.alreadyMember,
            message: msg.isNotEmpty
                ? msg
                : '$memberName is already linked to your account on $team.',
            teamName: team);
      case 'duplicate':
        final id = j['member_id'] == null ? null : _i(j['member_id']);
        return JoinResult(JoinOutcome.duplicate,
            teamName: team, memberId: id == 0 ? null : id);
      case 'already_pending':
        return JoinResult(JoinOutcome.alreadyPending, teamName: team);
      case 'pending_other':
        return JoinResult(JoinOutcome.pendingOther, teamName: team);
      case 'pending':
        return JoinResult(JoinOutcome.pending, teamName: team);
    }
    return JoinResult(JoinOutcome.unknown, message: kTryAgain, teamName: team);
  }
}

const kTryAgain = 'Something went wrong. Please try again.';

/// lookup_member_by_code: found (with the member and their team code),
/// or the error text to show under the field.
class MemberLookup {
  MemberLookup._(
      {this.error,
      this.memberId,
      this.firstName = '',
      this.lastName = '',
      this.teamName = '',
      this.teamCode = ''});
  final String? error;
  final int? memberId;
  final String firstName, lastName, teamName, teamCode;
  bool get found => error == null;
  String get name => '$firstName $lastName'.trim();

  factory MemberLookup.fromRpc(dynamic data) {
    if (data is! Map) return MemberLookup._(error: kTryAgain);
    final status = _s(data['status']);
    if (status == 'error') {
      final m = _s(data['message']);
      return MemberLookup._(error: m.isNotEmpty ? m : kTryAgain);
    }
    if (status == 'not_found') {
      return MemberLookup._(
          error: 'No member found with that code. Please check and try again.');
    }
    return MemberLookup._(
        memberId: _i(data['member_id']),
        firstName: _s(data['first_name']),
        lastName: _s(data['last_name']),
        teamName: _s(data['team_name']),
        teamCode: _s(data['team_code']));
  }
}

/// request_member_access: null when it worked, else the error text.
String? accessRequestError(dynamic data) {
  if (data is Map && data['success'] == true) return null;
  final m = data is Map ? _s(data['message']) : '';
  return m.isNotEmpty ? m : kTryAgain;
}

/// The "all set" line, singular or plural as on the page.
String doneText(int pendingCount) => pendingCount == 1
    ? "Your request has been sent. You'll receive a notification once the team admin approves it."
    : "Your requests have been sent. You'll receive a notification once the team admin approves them.";

/// Checks for the new team request form; null when it can be sent.
String? newTeamError({required String club, required String county}) {
  if (club.trim().isEmpty) return 'Please enter your club name.';
  if (county.trim().isEmpty) return 'Please select your county.';
  return null;
}

/// The body sent to the request-new-team edge function.
Map<String, dynamic> newTeamBody(
        {required String name,
        required String email,
        required String club,
        required String county,
        required String notes}) =>
    {
      'name': name.trim(),
      'email': email.trim(),
      'club_name': club.trim(),
      'county': county.trim(),
      'notes': notes.trim().isEmpty ? null : notes.trim(),
    };

const kCounties = [
  'Antrim', 'Armagh', 'Carlow', 'Cavan', 'Clare', 'Cork', 'Derry', //
  'Donegal', 'Down', 'Dublin', 'Fermanagh', 'Galway', 'Kerry', 'Kildare',
  'Kilkenny', 'Laois', 'Leitrim', 'Limerick', 'Longford', 'Louth', 'Mayo',
  'Meath', 'Monaghan', 'Offaly', 'Roscommon', 'Sligo', 'Tipperary', 'Tyrone',
  'Waterford', 'Westmeath', 'Wexford', 'Wicklow',
];
