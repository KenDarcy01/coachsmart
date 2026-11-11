// v3 Onboarding: the pure rules behind webviews/onboarding.html, kept out of
// the page so tests can run them without a network.

/// The screens of the flow, named after the web page's screen ids.
enum ObScreen {
  details, // screen-details: step 1, your name
  who, // screen-who: myself / someone else / new team
  theirName, // screen-their-name
  memberCode, // screen-member-code
  code, // screen-code: team joining code
  found, // screen-found: already on the roster
  alreadyPending, // screen-already-pending
  pendingOther, // screen-pending-other
  pendingStatus, // screen-pending-status: resume screen
  sent, // screen-sent
  newTeam, // screen-new-team
  newTeamSent, // screen-new-team-sent
}

/// Screens that show the web page's back chevron. screen-details only had
/// closeFlow, which the native wrapper ignored, so it has none here.
bool obHasBack(ObScreen s) => const {
      ObScreen.who,
      ObScreen.theirName,
      ObScreen.memberCode,
      ObScreen.code,
      ObScreen.found,
      ObScreen.newTeam,
    }.contains(s);

/// Progress dots and step label for a screen: (total, current, label).
/// [codeTotal] is 3 when joining as myself and 4 for someone else.
({int total, int current, String label})? obProgress(ObScreen s,
    {int codeTotal = 3}) {
  switch (s) {
    case ObScreen.details:
      return (total: 3, current: 1, label: 'Step 1 of 3');
    case ObScreen.who:
      return (total: 3, current: 2, label: 'Step 2 of 3');
    case ObScreen.theirName:
    case ObScreen.memberCode:
      return (total: 4, current: 3, label: 'Step 3 of 4');
    case ObScreen.code:
      return (
        total: codeTotal,
        current: codeTotal,
        label: 'Step $codeTotal of $codeTotal'
      );
    case ObScreen.newTeam:
      return (total: 3, current: 3, label: 'New Team Request');
    default:
      return null;
  }
}

/// The web page's screen history: push skips a repeat of the top screen.
class ObHistory {
  final List<ObScreen> stack = [];

  ObScreen? get top => stack.isEmpty ? null : stack.last;

  /// The screen under the top one, if any.
  ObScreen? get previous => stack.length >= 2 ? stack[stack.length - 2] : null;

  void push(ObScreen s) {
    if (top != s) stack.add(s);
  }

  /// goBack(): pop one; never go back past "who" into "details" once the
  /// user has a first name. Returns the screen to show, or null to stay.
  ObScreen? back({required bool hasFirstName}) {
    if (stack.length <= 1) return null;
    stack.removeLast();
    if (stack.last == ObScreen.details && hasFirstName) {
      stack
        ..clear()
        ..add(ObScreen.who);
    }
    return stack.last;
  }

  void reset(ObScreen s) {
    stack
      ..clear()
      ..add(s);
  }
}

/// Where loadUser() + checkAndRoute() send the user.
enum ObRoute { details, who, pendingStatus, home }

/// loadUser(): no users row or no first name goes to step 1.
bool obNeedsDetails(Map<String, dynamic>? user) {
  final first = (user?['first_name'] ?? '').toString().trim();
  return user == null || first.isEmpty;
}

/// checkAndRoute(): an active team link for any member the user owns goes
/// home; otherwise any pending request shows the pending list; otherwise
/// the user picks how to start.
ObRoute obDecideRoute({
  required List<int> ownedIds,
  required bool hasActiveLink,
  required int pendingCount,
}) {
  if (ownedIds.isNotEmpty) {
    if (hasActiveLink) return ObRoute.home;
    if (pendingCount > 0) return ObRoute.pendingStatus;
  }
  return ObRoute.who;
}

int _int(dynamic v) => v is int ? v : int.tryParse('${v ?? ''}') ?? 0;

String _s(dynamic v) => v == null ? '' : v.toString();

/// member_id values from user_member_link rows.
List<int> obMemberIds(List<dynamic> rows) => [
      for (final r in rows)
        if (r is Map && _int(r['member_id']) != 0) _int(r['member_id'])
    ];

/// One card on the pending status screen.
class ObPendingItem {
  const ObPendingItem(
      {required this.name, required this.label, required this.isLink});
  final String name;
  final String label;

  /// true for an account link request (🔗), false for a join request (🏃).
  final bool isLink;
}

Map<String, dynamic> _map(dynamic v) =>
    v is Map ? Map<String, dynamic>.from(v) : const {};

String _memberName(dynamic members) {
  final m = _map(members);
  return '${_s(m['first_name'])} ${_s(m['last_name'])}';
}

/// renderPendingList(): join requests first, then account link requests.
List<ObPendingItem> obPendingItems(
    List<dynamic> memberRequests, List<dynamic> accessRequests) {
  final out = <ObPendingItem>[];
  for (final r in memberRequests) {
    final row = _map(r);
    final team = _s(_map(row['teams'])['team_name']);
    out.add(ObPendingItem(
        name: _memberName(row['members']),
        label: 'Join request pending for ${team.isEmpty ? 'your team' : team}',
        isLink: false));
  }
  for (final r in accessRequests) {
    final row = _map(r);
    final member = _map(row['members']);
    final links = member['member_team_link'];
    var team = '';
    if (links is List) {
      for (final l in links) {
        final link = _map(l);
        if (link['status'] == 'active') {
          team = _s(_map(link['teams'])['team_name']);
          break;
        }
      }
    }
    out.add(ObPendingItem(
        name: _memberName(member),
        label: 'Account link request pending for '
            '${team.isEmpty ? 'your team' : team}',
        isLink: true));
  }
  return out;
}

/// Team joining code: uppercase, and the preview lookup starts at 3
/// characters after a 500 ms pause.
String obNormaliseCode(String raw) => raw.toUpperCase().trim();
bool obShouldLookUp(String code) => code.trim().length >= 3;
const obLookupDelay = Duration(milliseconds: 500);

/// get_team_by_code result: the team name, or null when not recognised.
String? obTeamNameFromLookup(dynamic data) {
  final name = _s(_map(data)['team_name']);
  return name.isEmpty ? null : name;
}

String obJoinLabel(String? teamName) =>
    teamName == null ? 'Request to Join' : 'Request to Join $teamName';

/// What create_new_member_by_code said.
enum ObJoinKind {
  error,
  duplicate,
  alreadyPending,
  pendingOther,
  pending,
  other
}

class ObJoinResult {
  const ObJoinResult(this.kind,
      {this.message = '', this.memberId, this.teamName = ''});
  final ObJoinKind kind;
  final String message;
  final int? memberId;
  final String teamName;
}

/// Parses create_new_member_by_code. [resolvedTeamName] is the preview's
/// name, used when the result has none; then 'the team'.
ObJoinResult obParseJoin(dynamic data, {String? resolvedTeamName}) {
  final d = _map(data);
  final status = _s(d['status']);
  final rawTeam = _s(d['team_name']);
  final team = rawTeam.isNotEmpty
      ? rawTeam
      : (resolvedTeamName?.isNotEmpty == true ? resolvedTeamName! : 'the team');
  final memberId = _int(d['member_id']);
  switch (status) {
    case 'error':
      return ObJoinResult(ObJoinKind.error, message: _s(d['message']));
    case 'duplicate':
      return ObJoinResult(ObJoinKind.duplicate,
          memberId: memberId == 0 ? null : memberId, teamName: team);
    case 'already_pending':
      return ObJoinResult(ObJoinKind.alreadyPending, teamName: team);
    case 'pending_other':
      return ObJoinResult(ObJoinKind.pendingOther, teamName: team);
    case 'pending':
      return ObJoinResult(ObJoinKind.pending, teamName: team);
    default:
      return ObJoinResult(ObJoinKind.other, teamName: team);
  }
}

/// lookup_member_by_code result.
class ObMemberLookup {
  const ObMemberLookup(
      {this.error,
      this.memberId = 0,
      this.firstName = '',
      this.lastName = '',
      this.teamName = '',
      this.teamCode = ''});

  /// Message to show, or null when the member was found.
  final String? error;
  final int memberId;
  final String firstName;
  final String lastName;
  final String teamName;
  final String teamCode;

  String get name => '$firstName $lastName';
}

const obTryAgain = 'Something went wrong. Please try again.';

ObMemberLookup obParseMemberLookup(dynamic data) {
  if (data is! Map) return const ObMemberLookup(error: obTryAgain);
  final d = Map<String, dynamic>.from(data);
  switch (_s(d['status'])) {
    case 'error':
      final m = _s(d['message']);
      return ObMemberLookup(error: m.isEmpty ? obTryAgain : m);
    case 'not_found':
      return const ObMemberLookup(
          error: 'No member found with that code. Please check and try again.');
  }
  return ObMemberLookup(
      memberId: _int(d['member_id']),
      firstName: _s(d['first_name']),
      lastName: _s(d['last_name']),
      teamName: _s(d['team_name']),
      teamCode: _s(d['team_code']));
}

/// request_member_access: null on success, else the message to show.
String? obAccessError(dynamic data) {
  final d = _map(data);
  if (d['success'] == true) return null;
  final m = _s(d['message']);
  return m.isEmpty ? obTryAgain : m;
}

/// The request-new-team error: the function's `error`, else the default.
String obNewTeamError(dynamic details) {
  final e = _s(_map(details)['error']);
  return e.isEmpty ? 'Something went wrong' : e;
}

const obCounties = [
  'Antrim', 'Armagh', 'Carlow', 'Cavan', 'Clare', 'Cork', 'Derry', //
  'Donegal', 'Down', 'Dublin', 'Fermanagh', 'Galway', 'Kerry', 'Kildare',
  'Kilkenny', 'Laois', 'Leitrim', 'Limerick', 'Longford', 'Louth', 'Mayo',
  'Meath', 'Monaghan', 'Offaly', 'Roscommon', 'Sligo', 'Tipperary',
  'Tyrone', 'Waterford', 'Westmeath', 'Wexford', 'Wicklow',
];

/// submitTeamRequest() checks, in order. Null when the form can be sent.
String? obNewTeamProblem({required String club, required String county}) {
  if (club.trim().isEmpty) return 'Please enter your club name.';
  if (county.trim().isEmpty) return 'Please select your county.';
  return null;
}

/// The request-new-team body.
Map<String, dynamic> obNewTeamBody({
  required String name,
  required String email,
  required String club,
  required String county,
  required String notes,
}) =>
    {
      'name': name,
      'email': email,
      'club_name': club.trim(),
      'county': county.trim(),
      'notes': notes.trim().isEmpty ? null : notes.trim(),
    };
