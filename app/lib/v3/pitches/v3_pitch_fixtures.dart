// v3 Pitch planner, Fixtures tab (Ken, 2026-11-16): the week's matches in
// two buckets. Official = the club's games in the league feed (home and
// away); Unofficial = CoachSmart match events with no league game (go
// games, friendlies, blitzes). Each card says where the pitch stands: booked,
// needs a pitch, or away.
import 'package:flutter/material.dart';
import '/v3/sport/v3_sport.dart';

import 'v3_pitch_api.dart';
import 'v3_pitch_board.dart' show codeColour;
import 'v3_pitch_controller.dart';
import 'v3_pitch_models.dart';
import 'v3_pitch_sheets.dart';
import 'v3_pitch_theme.dart';

const _dayNames = [
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
  'Sunday'
];

class FixtureBooking {
  const FixtureBooking(
      {required this.bookingId, this.pitch = '', this.status = '', this.start});
  factory FixtureBooking.fromJson(Map j) => FixtureBooking(
      bookingId: int.tryParse('${j['booking_id']}') ?? 0,
      pitch: '${j['pitch'] ?? ''}',
      status: '${j['status'] ?? ''}',
      start: j['starts_at'] == null ? null : parseLocal(j['starts_at']));
  final int bookingId;
  final String pitch;
  final String status;
  final DateTime? start;
  bool get offsite => status == 'offsite';
}

/// A change seen in the league feed (moved, venue, referee, status, new,
/// removed).
class FixtureChange {
  FixtureChange.fromJson(Map j)
      : kind = '${j['kind'] ?? ''}',
        title = '${j['title'] ?? ''}',
        detail = '${j['detail'] ?? ''}',
        unread = j['unread'] == true,
        at = DateTime.tryParse('${j['created_at']}')?.toLocal();
  final String kind, title, detail;
  final bool unread;
  final DateTime? at;

  String get label => switch (kind) {
        'moved' => 'Time changed',
        'venue' => 'Venue changed',
        'referee' => 'Referee named',
        'status' => 'Status changed',
        'new' => 'New fixture',
        'removed' => 'No longer listed',
        _ => 'Changed',
      };
}

String _ago(DateTime? t) {
  if (t == null) return '';
  final d = DateTime.now().difference(t);
  if (d.inMinutes < 60) return '${d.inMinutes.clamp(1, 59)} min ago';
  if (d.inHours < 24) return '${d.inHours} h ago';
  return '${d.inDays} day${d.inDays == 1 ? '' : 's'} ago';
}

class OfficialFixture {
  OfficialFixture.fromJson(Map j)
      : gameId = int.tryParse('${j['game_id']}') ?? 0,
        code = '${j['code'] ?? ''}',
        age = '${j['age'] ?? ''}',
        comp = '${j['comp'] ?? ''}',
        home = '${j['home'] ?? ''}',
        away = '${j['away'] ?? ''}',
        isHome = j['is_home'] == true,
        venue = '${j['venue'] ?? ''}',
        referee = '${j['referee'] ?? ''}',
        status = '${j['status'] ?? ''}',
        note = '${j['note'] ?? ''}',
        start = parseLocal(j['starts_at']),
        eventTeam = j['event'] is Map ? '${j['event']['team_name'] ?? ''}' : '',
        eventId = j['event'] is Map
            ? int.tryParse('${j['event']['event_id']}')
            : null,
        changes = [
          if (j['changes'] is List)
            for (final x in (j['changes'] as List).whereType<Map>())
              FixtureChange.fromJson(x)
        ],
        booking = j['booking'] is Map
            ? FixtureBooking.fromJson(j['booking'] as Map)
            : null;
  final List<FixtureChange> changes;
  final int gameId;
  final String code, age, comp, home, away, venue, referee, status, note;
  final bool isHome;
  final DateTime start;
  final String eventTeam;
  final int? eventId;
  final FixtureBooking? booking;
}

class UnofficialMatch {
  UnofficialMatch.fromJson(Map j)
      : eventId = int.tryParse('${j['event_id']}') ?? 0,
        teamName = '${j['team_name'] ?? ''}',
        female = j['female'] == true,
        code = '${j['code'] ?? ''}',
        opposition = '${j['opposition'] ?? ''}'.trim(),
        homeAway = '${j['home_away'] ?? ''}',
        location = '${j['location'] ?? ''}'.trim(),
        start = parseLocal(j['starts_at']),
        booking = j['booking'] is Map
            ? FixtureBooking.fromJson(j['booking'] as Map)
            : null;
  final int eventId;
  final String teamName, code, opposition, homeAway, location;
  final bool female;
  final DateTime start;
  final FixtureBooking? booking;
  bool get away => homeAway.toLowerCase() == 'away';
}

class PitchFixturesView extends StatefulWidget {
  const PitchFixturesView({super.key, required this.c});
  final PitchController c;
  @override
  State<PitchFixturesView> createState() => _PitchFixturesViewState();
}

class _PitchFixturesViewState extends State<PitchFixturesView> {
  PitchController get c => widget.c;
  DateTime? _loadedFor;
  List<OfficialFixture>? _official;
  List<UnofficialMatch>? _unofficial;
  List<FixtureChange> _changes = const [];
  String? _error;

  /// Official league fixtures come from the GAA fixture list, so soccer
  /// and rugby clubs see only their own matches (multi-sport).
  bool _league = true;

  @override
  void initState() {
    super.initState();
    V3Sport.forClub(c.club.clubId).then((s) {
      if (mounted && !s.isGaa) setState(() => _league = false);
    });
    c.addListener(_maybeLoad);
    _maybeLoad();
    _loadChanges();
  }

  @override
  void dispose() {
    c.removeListener(_maybeLoad);
    super.dispose();
  }

  // Reload when the week changes, or after a save reloads the board.
  void _maybeLoad() {
    if (c.loading || c.board == null) return;
    if (_loadedFor == c.monday && identical(_lastBoard, c.board)) return;
    _load(c.monday);
  }

  Object? _lastBoard;

  Future<void> _load(DateTime m) async {
    _loadedFor = m;
    _lastBoard = c.board;
    try {
      final r = await c.api.fixturesWeek(c.club.clubId, m);
      if (!mounted || _loadedFor != m) return;
      setState(() {
        _error = null;
        _official = [
          if (r['official'] is List)
            for (final x in (r['official'] as List).whereType<Map>())
              OfficialFixture.fromJson(x)
        ];
        _unofficial = [
          if (r['unofficial'] is List)
            for (final x in (r['unofficial'] as List).whereType<Map>())
              UnofficialMatch.fromJson(x)
        ];
      });
    } catch (e) {
      if (mounted) setState(() => _error = pitchErrorText(e));
    }
  }

  // The club's recent league changes; opening the tab marks them seen.
  Future<void> _loadChanges() async {
    try {
      final r = await c.api.fixtureChanges(c.club.clubId);
      final cutoff = DateTime.now().subtract(const Duration(days: 14));
      final list = [
        if (r['alerts'] is List)
          for (final x in (r['alerts'] as List).whereType<Map>())
            FixtureChange.fromJson(x)
      ].where((x) => x.at == null || x.at!.isAfter(cutoff)).toList();
      if (!mounted) return;
      setState(() => _changes = list);
      if (list.any((x) => x.unread)) {
        await c.api.fixtureChangesSeen(c.club.clubId);
        await c.loadChanges();
      }
    } catch (_) {
      // Change tracking not set up for this club yet.
    }
  }

  Future<void> _openBooking(int id) async {
    final b = c.board?.bookings.where((x) => x.bookingId == id).firstOrNull;
    if (b == null) return;
    await showPitchSheet(context, BookingSheet(c: c, booking: b));
    _load(c.monday);
  }

  Future<void> _place({int? gameId, int? eventId, UnofficialMatch? u}) async {
    final board = c.board;
    if (board == null) return;
    // Straight from the list, whether or not the board's "Needs a pitch"
    // has it (Ken, 2026-11-16: "why can't I just add?").
    final item = board
            .inbox(clubName: c.club.name, season: c.season)
            .where((i) =>
                (gameId != null && i.fixture?.gameId == gameId) ||
                (eventId != null && i.event?.eventId == eventId))
            .firstOrNull ??
        [
          for (final f in board.fixtures)
            if (gameId != null && f.gameId == gameId) PitchBoard.fixtureItem(f)
        ].firstOrNull ??
        [
          for (final e in board.events)
            if (eventId != null && e.eventId == eventId) c.itemOfEvent(e)
        ].firstOrNull ??
        (u == null
            ? null
            : c.itemOfEvent(BoardEvent(
                eventId: u.eventId,
                start: u.start,
                teamName: u.teamName,
                female: u.female,
                code: u.code,
                opposition: u.opposition,
                homeAway: u.homeAway,
                location: u.location,
                type: 'Match')));
    if (item == null) {
      pitchSnack(context, "Couldn't find this match. Pull down to refresh.");
      return;
    }
    await showPitchSheet(context, PlaceSheet(c: c, item: item));
    _load(c.monday);
  }

  @override
  Widget build(BuildContext context) {
    final m = c.monday;
    final sun = m.add(const Duration(days: 6));
    final accent = c.club.accent;
    final off = _official, un = _unofficial;

    Widget head(String t, String sub, int n) => Padding(
          padding: const EdgeInsets.fromLTRB(2, 18, 2, 8),
          child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(t.toUpperCase(),
                style: PT.inter(12.5,
                    weight: FontWeight.w700,
                    color: accent,
                    letterSpacing: 0.6)),
            const SizedBox(width: 8),
            Expanded(
                child: Text(sub,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: PT.inter(12, color: PT.muted))),
            Text('$n', style: PT.inter(12.5, color: PT.muted)),
          ]),
        );

    return LayoutBuilder(builder: (context, box) {
      _wide = box.maxWidth >= 760;
      // One white panel per section: a day heading, then a row per match.
      Widget list(List<(DateTime, Widget)> rows) {
        rows = [...rows]..sort((a, b) => a.$1.compareTo(b.$1));
        final kids = <Widget>[];
        DateTime? last;
        for (final (start, row) in rows) {
          final d = dayOf(start);
          if (last == null || d != last) {
            kids.add(Container(
              width: double.infinity,
              color: PT.card2,
              padding: const EdgeInsets.fromLTRB(14, 7, 14, 7),
              child: Text(
                  '${_dayNames[d.weekday - 1]} ${d.day} '
                  '${kMonths[d.month - 1]}',
                  style:
                      PT.inter(12.5, weight: FontWeight.w700, color: PT.muted)),
            ));
          } else {
            kids.add(const Divider(height: 1, thickness: 1, color: PT.line));
          }
          kids.add(row);
          last = d;
        }
        return Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
              color: PT.card,
              border: Border.all(color: PT.line),
              borderRadius: BorderRadius.circular(12)),
          child: Column(children: kids),
        );
      }

      return ListView(padding: const EdgeInsets.only(bottom: 24), children: [
        Row(children: [
          IconButton(
              onPressed: () => c.shiftDays(-7),
              icon: const Icon(Icons.chevron_left, color: PT.muted)),
          Flexible(
            child: Text(
                'Week of ${m.day} ${kMonths[m.month - 1].substring(0, 3)} – '
                '${sun.day} ${kMonths[sun.month - 1].substring(0, 3)}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: PT.tight(18)),
          ),
          IconButton(
              onPressed: () => c.shiftDays(7),
              icon: const Icon(Icons.chevron_right, color: PT.muted)),
        ]),
        if (_error != null)
          Padding(
              padding: const EdgeInsets.all(16),
              child: Text(_error!, style: PT.inter(14, color: PT.muted)))
        else if (off == null || un == null)
          const Padding(
              padding: EdgeInsets.all(30),
              child: Center(child: CircularProgressIndicator(color: PT.muted)))
        else ...[
          if (_league && _changes.isNotEmpty) ...[
            head('Changes from the league', 'Last 14 days, newest first',
                _changes.length),
            _changesPanel(),
          ],
          if (_league) ...[
            head('Official fixtures', 'From the league fixture list',
                off.length),
            if (off.isEmpty)
              Text('No league fixtures this week.',
                  style: PT.inter(14, color: PT.muted))
            else
              list([for (final f in off) (f.start, _officialCard(f))]),
          ],
          _league
              ? head('Unofficial matches',
                  'On CoachSmart but not on the league list', un.length)
              : head('Matches', 'On CoachSmart this week', un.length),
          if (un.isEmpty)
            Text('None this week.', style: PT.inter(14, color: PT.muted))
          else
            list([for (final u in un) (u.start, _unofficialCard(u))]),
        ],
      ]);
    });
  }

  Widget _changesPanel() {
    final shown = _changes.take(8).toList();
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
          color: PT.card,
          border: Border.all(color: PT.line),
          borderRadius: BorderRadius.circular(12)),
      child: Column(children: [
        for (final (i, x) in shown.indexed) ...[
          if (i > 0) const Divider(height: 1, thickness: 1, color: PT.line),
          Container(
            color: x.unread ? PT.redTint : null,
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Padding(
                padding: const EdgeInsets.only(top: 1, right: 10),
                child: PitchTag(x.label, colour: PT.redText),
              ),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(x.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: PT.inter(14, weight: FontWeight.w600)),
                      Text(x.detail, style: PT.inter(12.5, color: PT.muted)),
                    ]),
              ),
              const SizedBox(width: 10),
              Text(_ago(x.at), style: PT.inter(12, color: PT.muted)),
            ]),
          ),
        ],
      ]),
    );
  }

  /// The pitch chip: the slot given to the match, or Unassigned. Tapping
  /// it opens the booking (to change it) or the place sheet.
  Widget _slot(FixtureBooking? b,
      {required bool home, String venue = '', VoidCallback? onTap}) {
    final String text;
    final IconData icon;
    final Color fg;
    final Color bg;
    var border = Colors.transparent;
    if (b != null && !b.offsite) {
      text =
          '${b.pitch.isEmpty ? 'Pitch' : b.pitch}${b.start == null ? '' : ' · ${timeOf(b.start!)}'}';
      icon = Icons.place;
      fg = PT.green;
      bg = PT.greenTint;
    } else if (b != null && b.offsite) {
      text = 'Not on our pitches';
      icon = Icons.block;
      fg = PT.muted;
      bg = PT.card2;
    } else if (!home) {
      text = venue.isEmpty ? 'Away' : 'Away · $venue';
      icon = Icons.directions_bus_outlined;
      fg = PT.muted;
      bg = PT.card2;
    } else {
      text = 'Unassigned';
      icon = Icons.add_circle_outline;
      fg = PT.amberText;
      bg = PT.amberTint;
      border = PT.amber;
    }
    final chip = Container(
      padding: const EdgeInsets.fromLTRB(9, 5, 9, 5),
      decoration: BoxDecoration(
          color: bg,
          border: Border.all(color: border),
          borderRadius: BorderRadius.circular(8)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 15, color: fg),
        const SizedBox(width: 5),
        Flexible(
          child: Text(text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: PT.inter(13, weight: FontWeight.w700, color: fg)),
        ),
        if (onTap != null) ...[
          const SizedBox(width: 6),
          Icon(Icons.edit_outlined, size: 14, color: fg),
        ],
      ]),
    );
    if (onTap == null) return chip;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(onTap: onTap, child: chip),
    );
  }

  bool _wide = true;

  /// One match as a list row: time, colour bar, what and where, then tags.
  Widget _card(
      {required Color bar,
      required DateTime start,
      required String title,
      required List<String> lines,
      required List<Widget> tags,
      required Widget slot,
      VoidCallback? onTap}) {
    final text =
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: PT.inter(14.5, weight: FontWeight.w600)),
      if (lines.any((l) => l.isNotEmpty))
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Text(lines.where((l) => l.isNotEmpty).join(' · '),
              maxLines: _wide ? 1 : 2,
              overflow: TextOverflow.ellipsis,
              style: PT.inter(12.5, color: PT.muted)),
        ),
    ]);
    final tagWrap = Wrap(
        spacing: 6,
        runSpacing: 6,
        alignment: _wide ? WrapAlignment.end : WrapAlignment.start,
        children: tags);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(
              width: 54,
              child: Padding(
                padding: const EdgeInsets.only(top: 1),
                child: Text(timeOf(start),
                    style: PT.inter(14, weight: FontWeight.w700)),
              )),
          Container(
              width: 4,
              height: 36,
              margin: const EdgeInsets.only(right: 12),
              decoration: BoxDecoration(
                  color: bar, borderRadius: BorderRadius.circular(2))),
          Expanded(
            child: _wide
                ? Row(children: [
                    Expanded(flex: 5, child: text),
                    const SizedBox(width: 12),
                    SizedBox(
                        width: 220,
                        child: Align(
                            alignment: Alignment.centerLeft, child: slot)),
                    const SizedBox(width: 12),
                    Expanded(flex: 3, child: tagWrap),
                  ])
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                        text,
                        const SizedBox(height: 6),
                        slot,
                        const SizedBox(height: 6),
                        tagWrap
                      ]),
          ),
          if (onTap != null)
            const Padding(
              padding: EdgeInsets.only(left: 6, top: 8),
              child: Icon(Icons.chevron_right, size: 18, color: PT.faint),
            ),
        ]),
      ),
    );
  }

  Widget _officialCard(OfficialFixture f) {
    final female = f.code.toLowerCase().contains('lgfa') ||
        f.code.toLowerCase().contains('ladies');
    final title = '${[
      f.age,
      f.code
    ].where((s) => s.isNotEmpty).join(' ')}: ${f.home} v ${f.away}';
    final status = f.status.toLowerCase();
    final off = status.contains('postpon') || status.contains('cancel');
    final VoidCallback? tapF = f.booking != null
        ? () => _openBooking(f.booking!.bookingId)
        : f.isHome
            ? () => _place(gameId: f.gameId, eventId: f.eventId)
            : null;
    return _card(
      bar: codeColour(
          codeOf(f.code, female: female, name: '${f.comp} ${f.eventTeam}')),
      start: f.start,
      title: title,
      lines: [
        f.comp,
        [
          if (f.venue.isNotEmpty) 'Venue: ${f.venue}',
          if (f.referee.isNotEmpty) 'Ref: ${f.referee}',
        ].join(' · '),
        if (f.note.isNotEmpty) f.note,
      ],
      tags: [
        if (f.changes.isNotEmpty)
          Tooltip(
            message: f.changes.map((x) => x.detail).join('\n'),
            child: PitchTag('⚠ ${f.changes.first.label}',
                colour: PT.redText, bg: PT.redTint),
          ),
        if (f.isHome) PitchTag('Home', colour: c.club.accent),
        if (off) PitchTag(f.status, colour: PT.redText),
        PitchTag(
            f.eventId != null
                ? 'On CoachSmart · ${groupName(f.eventTeam, season: c.season, clubName: c.club.name)}'
                : 'Not on CoachSmart',
            colour: f.eventId != null ? PT.green : PT.muted),
      ],
      slot: _slot(f.booking, home: f.isHome, onTap: tapF),
      onTap: tapF,
    );
  }

  Widget _unofficialCard(UnofficialMatch u) {
    final name = groupName(u.teamName, season: c.season, clubName: c.club.name);
    final home = !u.away;
    final VoidCallback? tapU = u.booking != null
        ? () => _openBooking(u.booking!.bookingId)
        : home
            ? () => _place(eventId: u.eventId, u: u)
            : null;
    return _card(
      bar: codeColour(codeOf(u.code, female: u.female, name: u.teamName)),
      start: u.start,
      title: u.opposition.isEmpty ? name : '$name v ${u.opposition}',
      lines: [
        [u.teamName, if (u.code.isNotEmpty) u.code].join(' · '),
        if (u.location.isNotEmpty) 'Location: ${u.location}',
      ],
      tags: [
        if (!u.away)
          PitchTag(u.homeAway.isEmpty ? 'Home?' : 'Home',
              colour: c.club.accent),
      ],
      slot: _slot(u.booking, home: home, venue: u.location, onTap: tapU),
      onTap: tapU,
    );
  }
}
