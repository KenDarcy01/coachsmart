// v3 Pitch planner, Fixtures tab (Ken, 2026-11-16): the week's matches in
// two buckets. Official = the club's games in the league feed (home and
// away); Unofficial = CoachSmart match events with no league game (go
// games, friendlies, blitzes). Each card says where the pitch stands: booked,
// needs a pitch, or away.
import 'package:flutter/material.dart';

import 'v3_pitch_api.dart';
import 'v3_pitch_board.dart' show codeColour;
import 'v3_pitch_controller.dart';
import 'v3_pitch_models.dart';
import 'v3_pitch_sheets.dart';
import 'v3_pitch_theme.dart';

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
        booking = j['booking'] is Map
            ? FixtureBooking.fromJson(j['booking'] as Map)
            : null;
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
  String? _error;

  @override
  void initState() {
    super.initState();
    c.addListener(_maybeLoad);
    _maybeLoad();
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

  Future<void> _openBooking(int id) async {
    final b = c.board?.bookings.where((x) => x.bookingId == id).firstOrNull;
    if (b == null) return;
    await showPitchSheet(context, BookingSheet(c: c, booking: b));
    _load(c.monday);
  }

  Future<void> _place({int? gameId, int? eventId}) async {
    final board = c.board;
    if (board == null) return;
    final item = board
        .inbox(clubName: c.club.name, season: c.season)
        .where((i) =>
            (gameId != null && i.fixture?.gameId == gameId) ||
            (eventId != null && i.event?.eventId == eventId))
        .firstOrNull;
    if (item == null) {
      pitchSnack(context, 'Open its day on the board to place it.');
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
      final cols = box.maxWidth >= 1100
          ? 3
          : box.maxWidth >= 700
              ? 2
              : 1;
      final cardW =
          (box.maxWidth - 12 * (cols - 1) - (cols == 1 ? 0 : 4)) / cols;
      Widget grid(List<Widget> cards) => Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [for (final w in cards) SizedBox(width: cardW, child: w)]);

      return ListView(padding: const EdgeInsets.only(bottom: 24), children: [
        Row(children: [
          IconButton(
              onPressed: () => c.shiftDays(-7),
              icon: const Icon(Icons.chevron_left, color: PT.muted)),
          Text(
              'Week of ${m.day} ${kMonths[m.month - 1].substring(0, 3)} – '
              '${sun.day} ${kMonths[sun.month - 1].substring(0, 3)}',
              style: PT.tight(18)),
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
          head('Official fixtures', 'From the league fixture list', off.length),
          if (off.isEmpty)
            Text('No league fixtures this week.',
                style: PT.inter(14, color: PT.muted))
          else
            grid([for (final f in off) _officialCard(f)]),
          head('Unofficial matches', 'On CoachSmart but not on the league list',
              un.length),
          if (un.isEmpty)
            Text('None this week.', style: PT.inter(14, color: PT.muted))
          else
            grid([for (final u in un) _unofficialCard(u)]),
        ],
      ]);
    });
  }

  Widget _status(FixtureBooking? b, {required bool home, String venue = ''}) {
    if (b != null && !b.offsite) {
      return PitchTag(
          'Booked · ${b.pitch}${b.start == null ? '' : ' ${timeOf(b.start!)}'}',
          colour: PT.green);
    }
    if (b != null && b.offsite) {
      return const PitchTag('Not on our pitches', colour: PT.muted);
    }
    if (!home) {
      return PitchTag(venue.isEmpty ? 'Away' : 'Away · $venue',
          colour: PT.muted);
    }
    return const PitchTag('Needs a pitch');
  }

  Widget _card(
      {required Color bar,
      required DateTime start,
      required String title,
      required List<String> lines,
      required List<Widget> tags,
      VoidCallback? onTap}) {
    return Material(
      color: PT.card,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
          decoration: BoxDecoration(
              border: Border(left: BorderSide(color: bar, width: 5)),
              borderRadius: BorderRadius.circular(14)),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              width: 50,
              padding: const EdgeInsets.symmetric(vertical: 6),
              decoration: BoxDecoration(
                  color: PT.card2, borderRadius: BorderRadius.circular(10)),
              child: Column(children: [
                Text(kWeekdays[start.weekday - 1].toUpperCase(),
                    style: PT.inter(10.5,
                        weight: FontWeight.w700, color: PT.muted)),
                Text('${start.day}',
                    style: PT.inter(18, weight: FontWeight.w700)),
                Text(timeOf(start), style: PT.inter(11, color: PT.muted)),
              ]),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: PT.inter(15, weight: FontWeight.w600)),
                    for (final l in lines)
                      if (l.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(l,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: PT.inter(12.5, color: PT.muted)),
                        ),
                    const SizedBox(height: 8),
                    Wrap(spacing: 6, runSpacing: 6, children: tags),
                  ]),
            ),
          ]),
        ),
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
    return _card(
      bar: codeColour(codeOf(f.code, female: female)),
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
        if (f.isHome) PitchTag('Home', colour: c.club.accent),
        if (off) PitchTag(f.status, colour: PT.redText),
        _status(f.booking, home: f.isHome),
        PitchTag(
            f.eventId != null
                ? 'On CoachSmart · ${groupName(f.eventTeam, season: c.season, clubName: c.club.name)}'
                : 'Not on CoachSmart',
            colour: f.eventId != null ? PT.green : PT.muted),
      ],
      onTap: f.booking != null
          ? () => _openBooking(f.booking!.bookingId)
          : f.isHome
              ? () => _place(gameId: f.gameId, eventId: f.eventId)
              : null,
    );
  }

  Widget _unofficialCard(UnofficialMatch u) {
    final name = groupName(u.teamName, season: c.season, clubName: c.club.name);
    final home = !u.away;
    return _card(
      bar: codeColour(codeOf(u.code, female: u.female)),
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
        _status(u.booking, home: home, venue: u.location),
      ],
      onTap: u.booking != null
          ? () => _openBooking(u.booking!.bookingId)
          : home
              ? () => _place(eventId: u.eventId)
              : null,
    );
  }
}
