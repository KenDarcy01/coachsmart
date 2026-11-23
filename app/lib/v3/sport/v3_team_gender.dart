import '/backend/supabase/supabase.dart';

/// Female teams show the Hurling code as "Camogie", as v2's database
/// functions do (Ken, 2026-11-23). Most RPCs v3 reads already send the
/// swapped title; this covers the screens that get the raw code.
class V3TeamGender {
  V3TeamGender._();

  static final Map<int, bool> _female = {};

  /// Keeps a team's teams.team_female when a screen has already read it.
  static void remember(int? teamId, Object? female) {
    if (teamId == null || teamId == 0) return;
    _female[teamId] = female == true;
  }

  /// True if the team is already known to be female.
  static bool isFemale(int? teamId) =>
      teamId != null && (_female[teamId] ?? false);

  /// Reads teams.team_female for the teams not yet known. Errors leave
  /// them unknown, which shows the code as it is.
  static Future<void> load(Iterable<int?> teamIds) async {
    final ids = teamIds
        .whereType<int>()
        .where((id) => id > 0 && !_female.containsKey(id))
        .toSet()
        .toList();
    if (ids.isEmpty) return;
    try {
      final rows = await SupaFlow.client
          .from('teams')
          .select('team_id,team_female')
          .inFilter('team_id', ids);
      for (final r in rows) {
        final id = r['team_id'];
        remember(id is int ? id : int.tryParse('$id'), r['team_female']);
      }
    } catch (_) {}
  }

  /// The code as the team reads it: Hurling is Camogie on a female team.
  static String code(String code, int? teamId) =>
      codeFor(code, isFemale(teamId));

  static String codeFor(String code, bool female) =>
      female && code.trim().toLowerCase() == 'hurling' ? 'Camogie' : code;

  /// Swaps the word Hurling in a title, as v2's RPCs do for female teams.
  static String titleFor(String title, bool female) => female
      ? title
          .replaceAll(RegExp(r'\bHurling\b'), 'Camogie')
          .replaceAll(RegExp(r'\bhurling\b'), 'camogie')
      : title;

  /// The title an event reads when the coach left it empty: code + type,
  /// plus " (Opposition)" on matches, like get_user_home_events.
  static String defaultTitle(
      {required String title,
      required String code,
      required String type,
      String opposition = '',
      bool female = false}) {
    if (title.trim().isNotEmpty) return titleFor(title.trim(), female);
    final base = [codeFor(code.trim(), female), type.trim()]
        .where((s) => s.isNotEmpty)
        .join(' ');
    final opp = opposition.trim();
    return opp.isNotEmpty && type.trim().toLowerCase() == 'match'
        ? '$base ($opp)'
        : base;
  }
}

/// An event's title as the home list shows it: the coach's title, or code +
/// type (+ opposition), with Camogie for female teams. Empty if it can't be
/// read. For screens whose RPC sends only the raw events.event_title.
Future<String> v3EventTitle(int eventId) async {
  if (eventId <= 0) return '';
  try {
    final e = await SupaFlow.client
        .from('events')
        .select('event_title,opposition,team_id,event_codes(event_code),'
            'event_types(event_type),teams!events_team_id_fkey(team_female)')
        .eq('event_id', eventId)
        .maybeSingle();
    if (e == null) return '';
    final female = (e['teams'] as Map?)?['team_female'] == true;
    final t = e['team_id'];
    V3TeamGender.remember(t is int ? t : int.tryParse('$t'), female);
    return V3TeamGender.defaultTitle(
        title: '${e['event_title'] ?? ''}',
        code: '${(e['event_codes'] as Map?)?['event_code'] ?? ''}',
        type: '${(e['event_types'] as Map?)?['event_type'] ?? ''}',
        opposition: '${e['opposition'] ?? ''}',
        female: female);
  } catch (_) {
    return '';
  }
}
