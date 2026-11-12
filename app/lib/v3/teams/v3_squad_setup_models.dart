// v3 Squad setup (super users, Ken approved 2026-11-12): the data behind
// get_team_squads_v3 and the calls the page makes, kept apart from the page
// so tests run without a network.
import '/backend/supabase/supabase.dart';

int _int(dynamic v) => v is int ? v : int.tryParse('${v ?? ''}') ?? 0;
String _s(dynamic v) => v == null ? '' : '$v';

class SetupSquad {
  const SetupSquad(
      {required this.squadId,
      required this.name,
      required this.colour,
      this.players = 0,
      this.grade = '',
      this.noTeam = false,
      this.disabledAt,
      this.pastEvents = 0});

  factory SetupSquad.fromJson(Map j) => SetupSquad(
      squadId: _int(j['squad_id']),
      name: _s(j['name']),
      colour: _s(j['colour']).isEmpty ? '#9AA0A6' : _s(j['colour']),
      players: _int(j['players']),
      grade: _s(j['grade']),
      noTeam: j['no_team'] == true,
      disabledAt: DateTime.tryParse(_s(j['disabled_at']))?.toLocal(),
      pastEvents: _int(j['past_events']));

  final int squadId;
  final String name;
  final String colour;
  final int players;

  /// Kept as it is when the sheet saves (the web Team setup page edits it).
  final String grade;
  final bool noTeam;
  final DateTime? disabledAt;
  final int pastEvents;
}

class SquadSetup {
  const SquadSetup(
      {required this.teamName,
      required this.clubName,
      required this.squads,
      required this.disabled});

  factory SquadSetup.fromJson(Map j) => SquadSetup(
          teamName: _s(j['team_name']),
          clubName: _s(j['club_name']),
          squads: [
            if (j['squads'] is List)
              for (final s in (j['squads'] as List).whereType<Map>())
                SetupSquad.fromJson(s)
          ],
          disabled: [
            if (j['disabled'] is List)
              for (final s in (j['disabled'] as List).whereType<Map>())
                SetupSquad.fromJson(s)
          ]);

  final String teamName;
  final String clubName;

  /// Active squads in list order, No Team last.
  final List<SetupSquad> squads;

  /// Turned-off squads, newest first.
  final List<SetupSquad> disabled;

  List<SetupSquad> get movable => [
        for (final s in squads)
          if (!s.noTeam) s
      ];
  SetupSquad? get noTeam {
    for (final s in squads) {
      if (s.noTeam) return s;
    }
    return null;
  }
}

/// Grade choices on the squad sheet (reporting only, Ken 2026-11-12).
const kSquadGrades = ['A', 'B', 'C', 'D', 'E'];

/// "14 players", "1 player", "No players yet".
String playersLine(int n) =>
    n == 0 ? 'No players yet' : '$n ${n == 1 ? 'player' : 'players'}';

/// "Off since 3 Nov · 21 past events".
String disabledLine(SetupSquad s) {
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', //
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
  ];
  final d = s.disabledAt;
  return [
    if (d != null) 'Off since ${d.day} ${months[d.month - 1]}' else 'Off',
    if (s.pastEvents > 0)
      '${s.pastEvents} past ${s.pastEvents == 1 ? 'event' : 'events'}',
  ].join(' · ');
}

/// The name rules save_team_squad enforces, checked first so the sheet can
/// say so without a round trip. Null when fine.
String? squadNameError(String name, List<SetupSquad> squads, {int? squadId}) {
  final n = name.trim();
  if (n.isEmpty) return 'Give the squad a name.';
  if (n.toLowerCase() == 'no team' || n.toLowerCase() == 'unassigned') {
    return 'That name is kept for Unassigned.';
  }
  for (final s in squads) {
    if (s.squadId != squadId && s.name.toLowerCase() == n.toLowerCase()) {
      return 'There is already a squad called ${s.name}.';
    }
  }
  return null;
}

/// The calls. Tests pass a fake.
class SquadSetupApi {
  const SquadSetupApi();

  Future<SquadSetup> _call(String fn, Map<String, dynamic> params) async {
    final r = await SupaFlow.client.rpc(fn, params: params);
    return SquadSetup.fromJson(r is Map ? r : const {});
  }

  Future<SquadSetup> load(int teamId) =>
      _call('get_team_squads_v3', {'p_team_id': teamId});

  Future<SquadSetup> save(int teamId, int? squadId, String name, String colour,
      {String grade = ''}) async {
    await SupaFlow.client.rpc('save_team_squad', params: {
      'p_team_id': teamId,
      'p_squad_id': squadId,
      'p_name': name.trim(),
      'p_colour': colour,
      'p_grade': grade,
    });
    return load(teamId);
  }

  Future<SquadSetup> reorder(int teamId, List<int> squadIds) async {
    await SupaFlow.client.rpc('reorder_team_squads',
        params: {'p_team_id': teamId, 'p_squad_ids': squadIds});
    return load(teamId);
  }

  Future<SquadSetup> disable(int teamId, int squadId) =>
      _call('disable_team_squad', {'p_team_id': teamId, 'p_squad_id': squadId});

  Future<SquadSetup> enable(int teamId, int squadId) =>
      _call('enable_team_squad', {'p_team_id': teamId, 'p_squad_id': squadId});
}

/// A Postgres error's message without the "PostgrestException" wrapper.
String squadErrorText(Object e) {
  if (e is PostgrestException) return e.message;
  return 'Something went wrong. Please try again.';
}
