// Published teams for parents (Ken, 2026-11-12). An admin turns on "Show
// teams to parents" under Publish on the Attendance page; it starts off on
// every event, training included. While it is on, the event page shows each
// family which team their child is on, and every team. Turning it on tells
// each family once (one notification per person, push or email); after a
// republish only families whose child moved are told. All of that is server
// side: get_event_teams_v3 and set_event_teams_shared (migration
// 20261112063000_event_team_shares.sql). Export stays as it is.
// Design: /mnt/project-files/coachsmart/app-v3/published-teams/design.md
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '/backend/supabase/supabase.dart';
import '../v3_theme.dart';
import '/v3/tracking/v3_track.dart';

int _i(dynamic v) =>
    v is int ? v : (v is num ? v.toInt() : int.tryParse('$v') ?? 0);
String _s(dynamic v) => v == null ? '' : '$v';

Color squadColour(String hex) {
  final h = hex.replaceAll('#', '');
  if (h.length == 6) {
    final v = int.tryParse(h, radix: 16);
    if (v != null) return Color(0xFF000000 | v);
  }
  return V3.green;
}

class TeamPlayer {
  TeamPlayer.fromJson(Map j)
      : memberId = _i(j['member_id']),
        name = _s(j['name']),
        mine = j['mine'] == true;
  final int memberId;
  final String name;
  final bool mine;
}

class TeamSquad {
  TeamSquad.fromJson(Map j)
      : squadId = _i(j['squad_id']),
        name = _s(j['squad_name']),
        colour = _s(j['squad_colour']),
        image = _s(j['squad_image']),
        players = [
          for (final p in (j['members'] as List? ?? []))
            TeamPlayer.fromJson(p as Map)
        ];
  final int squadId;
  final String name, colour, image;
  final List<TeamPlayer> players;
}

/// One of the caller's own children; squadId 0 = not on a team.
class MyPlayer {
  MyPlayer.fromJson(Map j)
      : memberId = _i(j['member_id']),
        firstName = _s(j['first_name']),
        squadId = j['squad_id'] == null ? 0 : _i(j['squad_id']),
        squadName = _s(j['squad_name']),
        colour = _s(j['squad_colour']),
        image = _s(j['squad_image']);
  final int memberId, squadId;
  final String firstName, squadName, colour, image;
  bool get onTeam => squadId > 0;
}

/// The result of get_event_teams_v3.
class EventTeams {
  EventTeams.fromJson(Map j)
      : error = _s(j['error']),
        shared = j['shared'] == true,
        sharedAt = DateTime.tryParse(_s(j['shared_at']))?.toLocal(),
        isAdmin = j['is_admin'] == true,
        published = j['published'] == true,
        familiesTold = _i(j['families_told']),
        mine = [
          for (final m in (j['mine'] as List? ?? []))
            MyPlayer.fromJson(m as Map)
        ],
        squads = [
          for (final s in (j['squads'] as List? ?? []))
            TeamSquad.fromJson(s as Map)
        ];
  final String error;
  final bool shared, isAdmin, published;
  final DateTime? sharedAt;
  final int familiesTold;
  final List<MyPlayer> mine;
  final List<TeamSquad> squads;

  /// Parents see the card only while the switch is on and there is a team.
  bool get visible => error.isEmpty && shared && squads.isNotEmpty;
}

Future<EventTeams?> loadEventTeams(int eventId) async {
  try {
    final r = await SupaFlow.client
        .rpc('get_event_teams_v3', params: {'p_event_id': eventId});
    return EventTeams.fromJson(r is Map ? r : {});
  } catch (_) {
    return null;
  }
}

/// "Shared Fri 15 Nov, 19:05 · 38 families told".
String sharedLabel(DateTime? at, int told) {
  if (at == null) return 'Off: only admins can see the teams';
  const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', //
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
  ];
  final hh = at.hour.toString().padLeft(2, '0');
  final mm = at.minute.toString().padLeft(2, '0');
  final when =
      'Shared ${days[at.weekday - 1]} ${at.day} ${months[at.month - 1]}, $hh:$mm';
  if (told <= 0) return when;
  return '$when · $told ${told == 1 ? 'family' : 'families'} told';
}

String shareResultMessage(int notified) {
  if (notified <= 0) return 'Teams shared. Nobody new to tell.';
  if (notified == 1) return 'Teams shared. 1 family told.';
  return 'Teams shared. $notified families told.';
}

class _Dot extends StatelessWidget {
  const _Dot(this.colour, this.image, {this.size = 12});
  final String colour, image;
  final double size;

  @override
  Widget build(BuildContext context) {
    final dot = Container(
        width: size,
        height: size,
        decoration:
            BoxDecoration(color: squadColour(colour), shape: BoxShape.circle));
    if (image.isEmpty) return dot;
    return ClipOval(
        child: Image.network(image,
            width: size,
            height: size,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => dot));
  }
}

// ------------------------------------------------------------ admin switch

/// "Show teams to parents" under Publish on the Attendance page. Admins
/// only, and only once the teams are published.
class V3ShareTeamsSwitch extends StatefulWidget {
  const V3ShareTeamsSwitch(
      {super.key,
      required this.eventId,
      this.testData,
      this.onSnack,
      this.bare = false});
  final int eventId;
  final void Function(String text, {bool warn})? onSnack;

  /// Inside a card (the event page): no rule or gap above.
  final bool bare;

  @visibleForTesting
  final Map<String, dynamic>? testData;

  @override
  State<V3ShareTeamsSwitch> createState() => _V3ShareTeamsSwitchState();
}

class _V3ShareTeamsSwitchState extends State<V3ShareTeamsSwitch> {
  EventTeams? _t;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (widget.testData != null) {
      setState(() => _t = EventTeams.fromJson(widget.testData!));
      return;
    }
    final t = await loadEventTeams(widget.eventId);
    if (mounted) setState(() => _t = t);
  }

  Future<void> _set(bool on) async {
    if (on && !await _confirm()) return;
    setState(() => _saving = true);
    try {
      final r = await SupaFlow.client.rpc('set_event_teams_shared',
          params: {'p_event_id': widget.eventId, 'p_shared': on});
      V3Track.event(
          on ? 'teams_shared' : 'teams_unshared', {'event_id': widget.eventId});
      await _load();
      final n = r is Map ? _i(r['notified']) : 0;
      widget.onSnack
          ?.call(on ? shareResultMessage(n) : 'Teams hidden from parents');
    } catch (_) {
      widget.onSnack
          ?.call('Could not change that. Please try again.', warn: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<bool> _confirm() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: V3.card,
        title: Text('Show teams to parents?',
            style: V3.tight(18, weight: FontWeight.w600)),
        content: Text(
            'Everyone in the team will see the teams on the event, and each '
            'family gets a notification with their child\'s team.',
            style: V3.inter(15, color: V3.muted, height: 1.4)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: Text('Cancel', style: V3.inter(15, color: V3.muted))),
          TextButton(
              onPressed: () => Navigator.pop(c, true),
              child: Text('Show and notify',
                  style:
                      V3.inter(15, weight: FontWeight.w700, color: V3.green))),
        ],
      ),
    );
    return ok == true;
  }

  @override
  Widget build(BuildContext context) {
    final t = _t;
    final on = t?.shared ?? false;
    return Padding(
      padding: EdgeInsets.only(top: widget.bare ? 0 : 10),
      child: Container(
        padding: const EdgeInsets.only(top: 10),
        decoration: widget.bare
            ? null
            : const BoxDecoration(
                border: Border(top: BorderSide(color: V3.line))),
        child: Row(children: [
          const Icon(Icons.groups_outlined, color: V3.green, size: 24),
          const SizedBox(width: 12),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text('Show teams to parents',
                    style: V3.inter(15, weight: FontWeight.w600)),
                Text(
                    on
                        ? sharedLabel(t?.sharedAt, t?.familiesTold ?? 0)
                        : 'Off: only admins can see the teams',
                    style: V3.inter(13, color: on ? V3.green : V3.muted)),
              ])),
          const SizedBox(width: 8),
          _saving || t == null
              ? const SizedBox(
                  width: 48,
                  child: Center(
                      child: SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: V3.green))))
              : Switch(
                  value: on,
                  activeThumbColor: V3.bg,
                  activeTrackColor: V3.green,
                  onChanged: _set),
        ]),
      ),
    );
  }
}

// --------------------------------------------------------- parent's view

/// "Teams" on the event page, by role (Ken, 2026-11-12, layout A).
/// Parent: "Your team", one row per child, then See all teams; nothing
/// until an admin shares. FLO and coach: the squads with player counts,
/// read only, once shared. Admin: the "Show teams to parents" switch, the
/// squads and Edit teams, as soon as the teams are published.
class V3EventTeamsCard extends StatefulWidget {
  const V3EventTeamsCard(
      {super.key,
      required this.eventId,
      this.role = 10,
      this.onEdit,
      this.onSnack,
      this.testData});
  final int eventId;

  /// The viewer's highest role level on the team.
  final int role;

  /// Admins: opens the page where teams are picked and published.
  final VoidCallback? onEdit;
  final void Function(String text, {bool warn})? onSnack;

  @visibleForTesting
  final Map<String, dynamic>? testData;

  @override
  State<V3EventTeamsCard> createState() => _V3EventTeamsCardState();
}

class _V3EventTeamsCardState extends State<V3EventTeamsCard> {
  EventTeams? _t;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(V3EventTeamsCard old) {
    super.didUpdateWidget(old);
    if (old.eventId != widget.eventId) _load();
  }

  Future<void> _load() async {
    if (widget.testData != null) {
      setState(() => _t = EventTeams.fromJson(widget.testData!));
      return;
    }
    final t = await loadEventTeams(widget.eventId);
    if (mounted) setState(() => _t = t);
  }

  // Floodlights heading and card, matching the event page (2026-11-13).
  Widget _heading(String text) => Padding(
        padding: const EdgeInsets.only(top: 8, bottom: 10),
        child: Row(children: [
          Text(text,
              style: GoogleFonts.bebasNeue(
                  fontSize: 22,
                  height: 1,
                  color: const Color(0xFF9BE33A),
                  letterSpacing: 1.6)),
          const SizedBox(width: 12),
          Expanded(
            child: Container(
              height: 1,
              decoration: const BoxDecoration(
                  gradient: LinearGradient(
                      colors: [Color(0xFF2B3A14), Color(0x002B3A14)])),
            ),
          ),
        ]),
      );

  Widget _rows(List<Widget> rows) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
            color: const Color(0xFF0F1214),
            border: Border.all(color: const Color(0xFF20252B)),
            borderRadius: BorderRadius.circular(16)),
        child: Column(children: [
          for (var i = 0; i < rows.length; i++)
            Container(
              decoration: BoxDecoration(
                  border: i == rows.length - 1
                      ? null
                      : const Border(
                          bottom: BorderSide(color: Color(0xFF1A1E23)))),
              child: rows[i],
            ),
        ]),
      );

  Widget _link(String text, VoidCallback onTap) => InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 13),
          child: Row(children: [
            Expanded(
                child: Text(text,
                    style: V3.inter(15,
                        weight: FontWeight.w600,
                        color: const Color(0xFF9BE33A)))),
            const Icon(Icons.chevron_right,
                color: const Color(0xFF9BE33A), size: 22),
          ]),
        ),
      );

  void _seeAll(EventTeams t) {
    V3Track.event('teams_viewed', {'event_id': widget.eventId});
    showAllTeams(context, t);
  }

  List<Widget> _squadRows(EventTeams t) => [
        for (final s in t.squads)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 13),
            child: Row(children: [
              _Dot(s.colour, s.image, size: 12),
              const SizedBox(width: 10),
              Expanded(
                  child: Text(s.name,
                      style: V3.inter(15, weight: FontWeight.w500))),
              Text(
                  '${s.players.length} '
                  '${s.players.length == 1 ? 'player' : 'players'}',
                  style: V3.inter(14, color: V3.muted)),
            ]),
          ),
      ];

  @override
  Widget build(BuildContext context) {
    final t = _t;
    if (t == null || t.error.isNotEmpty) return const SizedBox.shrink();
    final admin = t.isAdmin || widget.role >= 100;

    // Admin: switch, squads, Edit teams, once published.
    if (admin) {
      if (!t.published || t.squads.isEmpty) return const SizedBox.shrink();
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _heading('TEAMS'),
        _rows([
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: V3ShareTeamsSwitch(
                eventId: widget.eventId,
                testData: widget.testData,
                onSnack: widget.onSnack,
                bare: true),
          ),
          ..._squadRows(t),
          if (widget.onEdit != null) _link('Edit teams', widget.onEdit!),
        ]),
        const SizedBox(height: 10),
      ]);
    }

    if (!t.visible) return const SizedBox.shrink();

    // FLO and coach: read only.
    if (widget.role >= 20) {
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _heading('TEAMS'),
        _rows([
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 13),
            child:
                Text('Shown to parents', style: V3.inter(14, color: V3.muted)),
          ),
          ..._squadRows(t),
          _link('See all teams', () => _seeAll(t)),
        ]),
        const SizedBox(height: 10),
      ]);
    }

    // Parent.
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _heading(t.mine.isEmpty ? 'TEAMS' : 'YOUR TEAM'),
      _rows([
        for (final m in t.mine)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 13),
            child: Row(children: [
              Expanded(
                  child: Text(m.firstName,
                      style: V3.inter(16, weight: FontWeight.w500))),
              if (m.onTeam)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                      color: squadColour(m.colour).withValues(alpha: .15),
                      borderRadius: BorderRadius.circular(20)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    _Dot(m.colour, m.image, size: 10),
                    const SizedBox(width: 6),
                    Text(m.squadName,
                        style: V3.inter(14,
                            weight: FontWeight.w600,
                            color: squadColour(m.colour))),
                  ]),
                )
              else
                Text('Not on a team yet', style: V3.inter(15, color: V3.muted)),
            ]),
          ),
        _link('See all teams', () => _seeAll(t)),
      ]),
      const SizedBox(height: 10),
    ]);
  }
}

/// Every team, one tab per team, the caller's own children in green.
Future<void> showAllTeams(BuildContext context, EventTeams t) {
  var first = 0;
  for (var i = 0; i < t.squads.length; i++) {
    if (t.squads[i].players.any((p) => p.mine)) {
      first = i;
      break;
    }
  }
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: V3.bg,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (c) => _AllTeamsSheet(teams: t, first: first),
  );
}

class _AllTeamsSheet extends StatefulWidget {
  const _AllTeamsSheet({required this.teams, required this.first});
  final EventTeams teams;
  final int first;

  @override
  State<_AllTeamsSheet> createState() => _AllTeamsSheetState();
}

class _AllTeamsSheetState extends State<_AllTeamsSheet> {
  late int _sel = widget.first;

  @override
  Widget build(BuildContext context) {
    final squads = widget.teams.squads;
    final s = squads[_sel];
    return SafeArea(
      child: ConstrainedBox(
        constraints:
            BoxConstraints(maxHeight: MediaQuery.of(context).size.height * .85),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(top: 10, bottom: 12),
              decoration: BoxDecoration(
                  color: V3.barGrey, borderRadius: BorderRadius.circular(2))),
          Text('Teams', style: V3.tight(18, weight: FontWeight.w600)),
          const SizedBox(height: 12),
          SizedBox(
            height: 40,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: squads.length,
              separatorBuilder: (_, __) => const SizedBox(width: 6),
              itemBuilder: (_, i) {
                final on = i == _sel;
                return GestureDetector(
                  onTap: () => setState(() => _sel = i),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                        color: on ? V3.green : V3.card2,
                        borderRadius: BorderRadius.circular(10)),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      _Dot(squads[i].colour, squads[i].image, size: 10),
                      const SizedBox(width: 6),
                      Text('${squads[i].name} ${squads[i].players.length}',
                          style: V3.inter(13,
                              weight: FontWeight.w600,
                              color: on ? V3.bg : V3.muted)),
                    ]),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                      color: V3.card, borderRadius: BorderRadius.circular(14)),
                  child: Column(children: [
                    for (var i = 0; i < s.players.length; i++)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                            border: i == s.players.length - 1
                                ? null
                                : const Border(
                                    bottom: BorderSide(color: V3.line))),
                        child: Text(s.players[i].name,
                            style: V3.inter(16,
                                weight: s.players[i].mine
                                    ? FontWeight.w600
                                    : FontWeight.w400,
                                color: s.players[i].mine ? V3.green : V3.text)),
                      ),
                  ]),
                ),
              ],
            ),
          ),
        ]),
      ),
    );
  }
}
