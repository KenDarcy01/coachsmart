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
        at = DateTime.tryParse('${j['created_at']}')?.toLocal(),
        when = j['new_start'] != null
            ? parseLocal(j['new_start'])
            : j['old_start'] != null
                ? parseLocal(j['old_start'])
                : null;
  FixtureChange._(
      this.kind, this.title, this.detail, this.unread, this.at, this.when);

  /// The same change, marked as seen.
  FixtureChange seen() => FixtureChange._(kind, title, detail, false, at, when);

  final String kind, title, detail;

  /// When the fixture is now (or was, if removed): tapping the change
  /// opens that week.
  final DateTime? when;
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
  const PitchFixturesView(
      {super.key, required this.c, this.todo = false, this.onPublish});
  final PitchController c;

  /// Phone: the week as a short checklist (Ken, 2026-11-18: "very busy,
  /// not clear what I need to do next"). The full list is one tap away.
  final bool todo;
  final VoidCallback? onPublish;
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

  Future<void> _place(
      {int? gameId,
      int? eventId,
      UnofficialMatch? u,
      OfficialFixture? f}) async {
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
        (f == null
            ? null
            : PitchBoard.fixtureItem(BoardFixture(
                gameId: f.gameId,
                start: f.start,
                code: f.code,
                age: f.age,
                comp: f.comp,
                home: f.home,
                away: f.away,
                venue: f.venue))) ??
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

  /// The group a league fixture is for: the linked event's team, else
  /// by name ("U13 Girls", "U21 Camogie", "U21 Ladies Football").
  PitchGroup? _groupOfFixture(OfficialFixture f, PitchBoard board) {
    if (f.eventId != null) {
      final team = board.events
          .where((e) => e.eventId == f.eventId)
          .map((e) => e.teamId)
          .firstOrNull;
      final g = board.groups.where((g) => g.teamId == team).firstOrNull;
      if (team != null && g != null) return g;
    }
    final code = f.code.toLowerCase();
    final age = f.age.toLowerCase().trim();
    final ladies = code.contains('lgfa') || code.contains('ladies');
    final female = ladies || code.contains('camogie');
    final names = [
      if (ladies) '$age ladies football' else '$age $code',
      '$age ${female ? 'girls' : 'boys'}',
    ];
    for (final n in names) {
      final g = board.groups
          .where((g) => g.name.toLowerCase().trim() == n)
          .firstOrNull;
      if (g != null) return g;
    }
    return null;
  }

  /// Books every unassigned home match of the week onto its group's home
  /// pitch (Ken, 2026-11-17). League fixtures keep the league time; a
  /// CoachSmart match keeps its event time (moving it would unlink the
  /// coach's event). The default time is used when a fixture has none.
  Future<void> _fill() async {
    final board = c.board;
    if (board == null) return;
    if (c.homes.isEmpty) {
      return pitchSnack(context, 'Set home pitches on the Groups tab first.');
    }
    final items = <Map<String, dynamic>>[];
    final missing = <String>{};
    Map<String, dynamic> item(
        PitchGroup g, GroupHome h, DateTime start, String title, int? age,
        {int? gameId, int? eventId}) {
      if (start.hour == 0 && start.minute == 0 && h.time != null) {
        start = atMinutes(start, h.time!);
      }
      final mins = board.durations.minutesFor('match', age);
      return {
        'pitch_id': h.pitchId,
        'part': PitchPart.full,
        'starts_at': isoLocal(start),
        'ends_at': isoLocal(start.add(Duration(minutes: mins))),
        'kind': 'match',
        'status': 'confirmed',
        'title': title,
        'group_id': g.groupId,
        if (gameId != null) 'gaa_game_id': gameId,
        if (eventId != null) 'event_id': eventId,
        'following': false,
      };
    }

    for (final f in _official ?? const <OfficialFixture>[]) {
      final status = f.status.toLowerCase();
      if (!f.isHome || f.booking != null) continue;
      if (status.contains('postpon') || status.contains('cancel')) continue;
      final g = _groupOfFixture(f, board);
      final h = g == null ? null : c.homes[g.groupId];
      if (g == null || h == null) {
        missing.add(g?.name ?? '${f.age} ${f.code}'.trim());
        continue;
      }
      items.add(item(g, h, f.start, '${g.name} v ${f.away}', ageOf(f.age),
          gameId: f.gameId, eventId: f.eventId));
    }
    for (final u in _unofficial ?? const <UnofficialMatch>[]) {
      if (u.away || u.booking != null) continue;
      final team = board.events
          .where((e) => e.eventId == u.eventId)
          .map((e) => e.teamId)
          .firstOrNull;
      final g = board.groups
          .where((g) => team != null && g.teamId == team)
          .firstOrNull;
      final h = g == null ? null : c.homes[g.groupId];
      final name =
          groupName(u.teamName, season: c.season, clubName: c.club.name);
      if (g == null || h == null) {
        missing.add(g?.name ?? name);
        continue;
      }
      items.add(item(
          g,
          h,
          u.start,
          u.opposition.isEmpty
              ? '${g.name} match'
              : '${g.name} v ${u.opposition}',
          ageOf(u.teamName, season: c.season),
          eventId: u.eventId));
    }
    if (items.isEmpty) {
      return pitchSnack(
          context,
          missing.isEmpty
              ? 'Every home match this week already has a pitch.'
              : 'No home pitch set for ${missing.join(', ')}. '
                  'Set it on the Groups tab.');
    }
    final (added, err) = await c.autofill(items);
    if (!mounted) return;
    pitchSnack(
        context,
        err ??
            '$added match${added == 1 ? '' : 'es'} filled.'
                '${missing.isEmpty ? '' : ' No home pitch for ${missing.join(', ')}.'}');
  }

  Widget _fillBar() {
    final accent = c.club.accent;
    final n = c.autoIds.length;
    final board = c.board;
    final clashes = board == null
        ? 0
        : [
            for (var i = 0; i < 7; i++)
              ...board.clashesOn(c.monday.add(Duration(days: i)))
          ].length;
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SizedBox(
              width: 200,
              child: PitchButton('Fill from defaults',
                  compact: true, accent: accent, onTap: c.busy ? null : _fill),
            ),
            if (n > 0) ...[
              PitchTag(
                  '$n auto-filled'
                  '${clashes > 0 ? ' · $clashes clash${clashes == 1 ? '' : 'es'}' : ''}',
                  colour: clashes > 0 ? PT.redText : PT.amberText),
              SizedBox(
                width: 130,
                child: PitchButton('Keep them',
                    compact: true,
                    onTap: c.busy ? null : () => c.autofillAccept()),
              ),
              SizedBox(
                width: 130,
                child: PitchButton('Undo fill',
                    compact: true,
                    danger: true,
                    onTap: c.busy ? null : () => c.autofillUndo()),
              ),
            ],
          ]),
    );
  }

  /// Phone checklist: showing the full fixture list instead.
  bool _all = false;

  /// Girls then boys, one row per match, like the club sheet (Ken, 2026-11-20).
  bool _sheet = true;

  /// League changes stay folded behind a bar until tapped (Ken 2026-11-23).
  bool _openChanges = false;
  bool _showChanges = false;

  Widget _weekRow() {
    final m = c.monday;
    final sun = m.add(const Duration(days: 6));
    return Row(children: [
      IconButton(
          onPressed: () => c.shiftDays(-7),
          icon: Icon(Icons.chevron_left, color: PT.muted)),
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
          icon: Icon(Icons.chevron_right, color: PT.muted)),
    ]);
  }

  /// One step of the week's checklist: a number (or a tick when done),
  /// a title and what to do.
  Widget _step(int n, String title, String sub,
      {required bool done, List<Widget> children = const []}) {
    final accent = c.club.accent;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
          color: PT.card,
          border:
              Border.all(color: done ? PT.line : accent.withValues(alpha: 0.6)),
          borderRadius: BorderRadius.circular(14)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          child: Row(children: [
            Container(
              width: 28,
              height: 28,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                  color: done ? PT.green : accent, shape: BoxShape.circle),
              child: done
                  ? Icon(Icons.check, size: 18, color: onAccent(PT.green))
                  : n == 0
                      ? Icon(Icons.bolt, size: 18, color: onAccent(accent))
                      : Text('$n',
                          style: PT.inter(14,
                              weight: FontWeight.w700,
                              color: onAccent(accent))),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: PT.inter(16,
                            weight: FontWeight.w700,
                            color: done ? PT.muted : PT.text)),
                    if (sub.isNotEmpty)
                      Text(sub, style: PT.inter(13, color: PT.muted)),
                  ]),
            ),
          ]),
        ),
        ...children,
      ]),
    );
  }

  /// A row inside a step: when, what, and a "Do it" arrow.
  Widget _todoRow(DateTime start, String title, String sub,
      {VoidCallback? onTap, String action = 'Place'}) {
    final accent = c.club.accent;
    return InkWell(
      onTap: onTap,
      child: Container(
        decoration:
            BoxDecoration(border: Border(top: BorderSide(color: PT.line))),
        padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
        child: Row(children: [
          SizedBox(
            width: 52,
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(kWeekdays[start.weekday - 1],
                  style: PT.inter(12, color: PT.muted)),
              Text(timeOf(start), style: PT.inter(14, weight: FontWeight.w700)),
            ]),
          ),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: PT.inter(14.5, weight: FontWeight.w600)),
              if (sub.isNotEmpty)
                Text(sub,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: PT.inter(12.5, color: PT.muted)),
            ]),
          ),
          if (onTap != null) ...[
            const SizedBox(width: 8),
            Text(action,
                style: PT.inter(13.5, weight: FontWeight.w700, color: accent)),
            Icon(Icons.chevron_right, size: 18, color: accent),
          ],
        ]),
      ),
    );
  }

  Widget _todo() {
    final board = c.board!;
    final accent = c.club.accent;
    final off = _official, un = _unofficial;
    if (_error != null || off == null || un == null) {
      return ListView(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
          children: [
            _weekRow(),
            Padding(
              padding: const EdgeInsets.all(30),
              child: Center(
                  child: _error != null
                      ? Text(_error!, style: PT.inter(14, color: PT.muted))
                      : CircularProgressIndicator(color: PT.muted)),
            ),
          ]);
    }

    // 1. Home matches with no pitch yet.
    final needs = <(DateTime, Widget)>[];
    for (final f in off) {
      final status = f.status.toLowerCase();
      if (!f.isHome || f.booking != null) continue;
      if (status.contains('postpon') || status.contains('cancel')) continue;
      final age = [f.age, f.code].where((s) => s.isNotEmpty).join(' ');
      needs.add((
        f.start,
        _todoRow(f.start, '$age v ${f.away}', f.comp,
            onTap: () => _place(gameId: f.gameId, eventId: f.eventId, f: f))
      ));
    }
    for (final u in un) {
      if (u.away || u.booking != null) continue;
      final name =
          groupName(u.teamName, season: c.season, clubName: c.club.name);
      needs.add((
        u.start,
        _todoRow(
            u.start,
            u.opposition.isEmpty ? name : '$name v ${u.opposition}',
            'On CoachSmart, not on the league list',
            onTap: () => _place(eventId: u.eventId, u: u))
      ));
    }
    needs.sort((a, b) => a.$1.compareTo(b.$1));

    // 2. Clashes this week.
    final clashes = [
      for (var i = 0; i < 7; i++)
        ...board.clashesOn(c.monday.add(Duration(days: i)))
    ];

    // 3. League changes for matches this week.
    final changes = [
      for (final x in _changes)
        if (x.when != null && mondayOf(x.when!) == c.monday) x
    ];

    final pub = board.publishedAt;
    final published = pub != null && !board.changedSincePublish;
    final ready = needs.isEmpty && clashes.isEmpty;
    final n = c.autoIds.length;

    return ListView(
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
        children: [
          _weekRow(),
          const SizedBox(height: 4),
          _step(
              1,
              needs.isEmpty
                  ? 'Every home match has a pitch'
                  : 'Needs a pitch (${needs.length})',
              needs.isEmpty ? '' : 'Tap a match to give it a pitch.',
              done: needs.isEmpty,
              children: [
                if (needs.isNotEmpty && c.homes.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
                    child: PitchButton('Fill them from the usual pitches',
                        accent: accent,
                        compact: true,
                        onTap: c.busy ? null : _fill),
                  ),
                for (final (_, w) in needs) w,
              ]),
          if (n > 0)
            _step(0, '$n filled automatically',
                'Check them on the Day tab, then keep them.',
                done: false,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
                    child: Row(children: [
                      Expanded(
                        child: PitchButton('Keep them',
                            compact: true,
                            accent: accent,
                            onTap: c.busy ? null : () => c.autofillAccept()),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: PitchButton('Undo fill',
                            compact: true,
                            danger: true,
                            onTap: c.busy ? null : () => c.autofillUndo()),
                      ),
                    ]),
                  ),
                ]),
          _step(
              2,
              clashes.isEmpty ? 'No clashes' : 'Clashes (${clashes.length})',
              clashes.isEmpty
                  ? ''
                  : 'Two bookings on the same pitch at once. Move one.',
              done: clashes.isEmpty,
              children: [
                for (final (a, b) in clashes)
                  _todoRow(a.start, '${c.titleOf(a)} and ${c.titleOf(b)}',
                      board.pitch(a.pitchId)?.name ?? '',
                      action: 'Sort', onTap: () => _openBooking(b.bookingId)),
              ]),
          if (_league)
            _step(
                3,
                changes.isEmpty
                    ? 'No league changes this week'
                    : 'League changes (${changes.length})',
                changes.isEmpty ? '' : 'Times or venues the league changed.',
                done: changes.isEmpty || _showChanges,
                children: [
                  if (changes.isNotEmpty && !_showChanges)
                    _todoRow(changes.first.when!, changes.first.title,
                        changes.first.detail,
                        action: changes.length == 1
                            ? 'Got it'
                            : 'See all ${changes.length}',
                        onTap: () => setState(() => _showChanges = true)),
                  if (_showChanges)
                    for (final x in changes)
                      _todoRow(x.when!, x.title, x.detail),
                ]),
          _step(
              _league ? 4 : 3,
              published ? 'Published' : 'Publish the week',
              published
                  ? 'Members can see it. Publish again after any change.'
                  : ready
                      ? 'Members see the pitches once you publish.'
                      : 'Best done once the steps above are clear.',
              done: published,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                  child: PitchButton(published ? 'Publish again' : 'Publish',
                      accent: published ? null : accent,
                      onTap: c.busy ? null : widget.onPublish),
                ),
              ]),
          const SizedBox(height: 6),
          Center(
            child: TextButton(
                onPressed: () => setState(() => _all = true),
                child: Text('See all fixtures this week',
                    style:
                        PT.inter(14, weight: FontWeight.w600, color: accent))),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
                'Slots, groups and pitch set-up are on the laptop version.',
                textAlign: TextAlign.center,
                style: PT.inter(12.5, color: PT.faint)),
          ),
        ]);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.todo && !_all && c.board != null) return _todo();
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
            kids.add(Divider(height: 1, thickness: 1, color: PT.line));
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
        if (widget.todo)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
                onPressed: () => setState(() => _all = false),
                icon: Icon(Icons.arrow_back, size: 18, color: accent),
                label: Text('Back to the checklist',
                    style:
                        PT.inter(14, weight: FontWeight.w600, color: accent))),
          ),
        Row(children: [
          IconButton(
              onPressed: () => c.shiftDays(-7),
              icon: Icon(Icons.chevron_left, color: PT.muted)),
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
              icon: Icon(Icons.chevron_right, color: PT.muted)),
        ]),
        _fillBar(),
        _viewSwitch(),
        if (_error != null)
          Padding(
              padding: const EdgeInsets.all(16),
              child: Text(_error!, style: PT.inter(14, color: PT.muted)))
        else if (off == null || un == null)
          Padding(
              padding: EdgeInsets.all(30),
              child: Center(child: CircularProgressIndicator(color: PT.muted)))
        else ...[
          if (_league && _changes.isNotEmpty) ...[
            const SizedBox(height: 14),
            _changesBar(),
            if (_openChanges) ...[
              const SizedBox(height: 8),
              _changesPanel(),
            ],
          ],
          if (_sheet)
            ..._sheetView(off, un, head)
          else ...[
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
        ],
      ]);
    });
  }

  Widget _viewSwitch() {
    final accent = c.club.accent;
    Widget pill(String label, bool on, VoidCallback tap) => Padding(
          padding: const EdgeInsets.only(right: 8),
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: tap,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              decoration: BoxDecoration(
                  color: on ? accent : PT.card,
                  border: Border.all(color: on ? accent : PT.line),
                  borderRadius: BorderRadius.circular(20)),
              child: Text(label,
                  style: PT.inter(13.5,
                      weight: FontWeight.w600,
                      color: on ? Colors.white : PT.text)),
            ),
          ),
        );
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Wrap(children: [
        pill('Girls and boys', _sheet, () => setState(() => _sheet = true)),
        pill('By day', !_sheet, () => setState(() => _sheet = false)),
      ]),
    );
  }

  /// Every match of the week, home and away, as rows like the club sheet:
  /// Ladies / Girls first, then Men / Boys, then anything mixed.
  List<Widget> _sheetView(List<OfficialFixture> off, List<UnofficialMatch> un,
      Widget Function(String, String, int) head) {
    final board = c.board;
    Booking? bk(FixtureBooking? f) => f == null || board == null
        ? null
        : board.bookings.where((b) => b.bookingId == f.bookingId).firstOrNull;
    final rows = <_SheetRow>[];
    for (final f in off) {
      final female = f.code.toLowerCase().contains('lgfa') ||
          f.code.toLowerCase().contains('ladies');
      final b = bk(f.booking);
      final team = f.eventTeam.isNotEmpty
          ? groupName(f.eventTeam, season: c.season, clubName: c.club.name)
          : [f.age, f.code].where((x) => x.isNotEmpty).join(' ');
      final status = f.status.toLowerCase();
      rows.add(_SheetRow(
        code: codeOf(f.code, female: female, name: '${f.comp} ${f.eventTeam}'),
        start: f.start,
        team: team,
        comp: f.comp,
        fixture: '${f.home} v ${f.away}',
        venue: f.isHome && f.booking != null && !f.booking!.offsite
            ? f.booking!.pitch
            : f.venue,
        home: f.isHome,
        referee: f.referee.isNotEmpty ? f.referee : (b?.referee ?? ''),
        rooms: b?.dressingRooms ?? '',
        note: status.contains('postpon') || status.contains('cancel')
            ? f.status
            : '',
        onTap: f.booking != null
            ? () => _openBooking(f.booking!.bookingId)
            : f.isHome
                ? () => _place(gameId: f.gameId, eventId: f.eventId, f: f)
                : null,
      ));
    }
    for (final u in un) {
      final b = bk(u.booking);
      final name =
          groupName(u.teamName, season: c.season, clubName: c.club.name);
      final ours = c.club.name;
      rows.add(_SheetRow(
        code: codeOf(u.code, female: u.female, name: u.teamName),
        start: u.start,
        team: name,
        comp: _league ? 'Not on the league list' : '',
        fixture: u.opposition.isEmpty
            ? ''
            : u.away
                ? '${u.opposition} v $ours'
                : '$ours v ${u.opposition}',
        venue: u.booking != null && !u.booking!.offsite
            ? u.booking!.pitch
            : u.location,
        home: !u.away,
        referee: b?.referee ?? '',
        rooms: b?.dressingRooms ?? '',
        onTap: u.booking != null
            ? () => _openBooking(u.booking!.bookingId)
            : !u.away
                ? () => _place(eventId: u.eventId, u: u)
                : null,
      ));
    }
    rows.sort((a, b) => a.start.compareTo(b.start));
    bool girls(_SheetRow r) =>
        r.code == PitchCode.ladies || r.code == PitchCode.camogie;
    bool boys(_SheetRow r) =>
        r.code == PitchCode.football || r.code == PitchCode.hurling;
    final sections = [
      ('Ladies / Girls', rows.where(girls).toList()),
      ('Men / Boys', rows.where(boys).toList()),
      ('Mixed and other', rows.where((r) => !girls(r) && !boys(r)).toList()),
    ];
    return [
      for (final (title, list) in sections)
        if (list.isNotEmpty || title != 'Mixed and other') ...[
          head(title, 'Home and away, all details', list.length),
          if (list.isEmpty)
            Text('None this week.', style: PT.inter(14, color: PT.muted))
          else
            _sheetTable(list),
        ],
    ];
  }

  Widget _sheetTable(List<_SheetRow> rows) {
    String dm(DateTime d) =>
        '${_dayNames[d.weekday - 1].substring(0, 3)} ${d.day} '
        '${kMonths[d.month - 1].substring(0, 3)}';
    String time(DateTime d) => d.hour == 0 && d.minute == 0 ? 'TBC' : timeOf(d);
    Widget t(String s, {bool bold = false, Color? colour}) =>
        Text(s.isEmpty ? '–' : s,
            style: PT.inter(13,
                weight: bold ? FontWeight.w600 : FontWeight.w400,
                color: s.isEmpty ? PT.faint : (colour ?? PT.text)));
    final panel = BoxDecoration(
        color: PT.card,
        border: Border.all(color: PT.line),
        borderRadius: BorderRadius.circular(12));
    if (!_wide) {
      return Container(
        clipBehavior: Clip.antiAlias,
        decoration: panel,
        child: Column(children: [
          for (final (i, r) in rows.indexed) ...[
            if (i > 0) Divider(height: 1, thickness: 1, color: PT.line),
            InkWell(
              onTap: r.onTap,
              child: Container(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                decoration: BoxDecoration(
                    border: Border(
                        left: BorderSide(color: codeColour(r.code), width: 4))),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Expanded(
                            child: Text(r.team,
                                style:
                                    PT.inter(14.5, weight: FontWeight.w700))),
                        Text('${dm(r.start)} · ${time(r.start)}',
                            style: PT.inter(12.5, color: PT.muted)),
                      ]),
                      if (r.fixture.isNotEmpty)
                        Text(r.fixture, style: PT.inter(13.5)),
                      Text(
                          [
                            if (r.comp.isNotEmpty) r.comp,
                            if (r.venue.isNotEmpty) r.venue,
                            if (r.referee.isNotEmpty) 'Ref ${r.referee}',
                            if (r.rooms.isNotEmpty) 'Rooms ${r.rooms}',
                            if (r.note.isNotEmpty) r.note,
                          ].join(' · '),
                          style: PT.inter(12.5, color: PT.muted)),
                    ]),
              ),
            ),
          ],
        ]),
      );
    }
    Widget hd(String s) => Padding(
          padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
          child: Text(s.toUpperCase(),
              style: PT.inter(11.5, weight: FontWeight.w700, color: PT.muted)),
        );
    Widget cell(Widget w, VoidCallback? tap) => InkWell(
          onTap: tap,
          child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 9, 10, 9), child: w),
        );
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: panel,
      child: Table(
        columnWidths: const {
          0: FixedColumnWidth(4),
          1: FlexColumnWidth(1.3),
          2: FixedColumnWidth(96),
          3: FixedColumnWidth(58),
          4: FlexColumnWidth(1.6),
          5: FlexColumnWidth(2),
          6: FlexColumnWidth(1.3),
          7: FlexColumnWidth(1.1),
          8: FlexColumnWidth(0.8),
        },
        defaultVerticalAlignment: TableCellVerticalAlignment.middle,
        border: TableBorder(horizontalInside: BorderSide(color: PT.line)),
        children: [
          TableRow(decoration: BoxDecoration(color: PT.card2), children: [
            const SizedBox.shrink(),
            hd('Team'),
            hd('Date'),
            hd('Time'),
            hd('Competition'),
            hd('Fixture'),
            hd('Venue'),
            hd('Referee'),
            hd('Rooms'),
          ]),
          for (final r in rows)
            TableRow(children: [
              TableCell(
                  verticalAlignment: TableCellVerticalAlignment.fill,
                  child: Container(color: codeColour(r.code))),
              cell(t(r.team, bold: true), r.onTap),
              cell(t(dm(r.start)), r.onTap),
              cell(t(time(r.start)), r.onTap),
              cell(
                  t(r.note.isEmpty ? r.comp : '${r.comp} · ${r.note}',
                      colour: r.note.isEmpty ? null : PT.redText),
                  r.onTap),
              cell(t(r.fixture), r.onTap),
              cell(
                  t(r.venue,
                      bold: r.home, colour: r.home ? c.club.accent : null),
                  r.onTap),
              cell(t(r.referee), r.onTap),
              cell(t(r.rooms), r.onTap),
            ]),
        ],
      ),
    );
  }

  /// A bar that says how many league changes there are; tap to open the
  /// list. Opening it marks them seen.
  Widget _changesBar() {
    final n = _changes.length;
    final fresh = _changes.where((x) => x.unread).length;
    return Material(
      color: PT.redTint,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () async {
          setState(() => _openChanges = !_openChanges);
          if (_openChanges && fresh > 0) {
            try {
              await c.api.fixtureChangesSeen(c.club.clubId);
              await c.loadChanges();
            } catch (_) {}
            if (mounted) {
              setState(() => _changes = [
                    for (final x in _changes) x.seen(),
                  ]);
            }
          }
        },
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
          child: Row(children: [
            Icon(Icons.warning_amber_rounded, color: PT.redText, size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                        '$n change${n == 1 ? '' : 's'} from the league'
                        '${fresh > 0 ? ' · $fresh new' : ''}',
                        style: PT.inter(15,
                            weight: FontWeight.w700, color: PT.redText)),
                    Text(
                        _openChanges
                            ? 'Last 14 days, newest first. Tap to hide.'
                            : 'Times, venues and referees changed in the last 14 days. Tap to see them.',
                        style: PT.inter(12.5, color: PT.muted)),
                  ]),
            ),
            Text(_openChanges ? 'Hide' : 'Show',
                style:
                    PT.inter(14, weight: FontWeight.w700, color: PT.redText)),
            Icon(_openChanges ? Icons.expand_less : Icons.expand_more,
                color: PT.redText),
          ]),
        ),
      ),
    );
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
          if (i > 0) Divider(height: 1, thickness: 1, color: PT.line),
          // A plain notice: tapping does nothing (Ken 2026-11-23).
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
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text(_ago(x.at), style: PT.inter(12, color: PT.muted)),
                if (x.when != null && mondayOf(x.when!) != c.monday)
                  Text(
                      'Week of ${mondayOf(x.when!).day} '
                      '${kMonths[mondayOf(x.when!).month - 1].substring(0, 3)}',
                      style: PT.inter(12, color: PT.muted)),
              ]),
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
    final auto = b != null && c.autoIds.contains(b.bookingId);
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
        if (auto) ...[
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
            decoration: BoxDecoration(
                color: PT.amberTint, borderRadius: BorderRadius.circular(4)),
            child: Text('Auto',
                style:
                    PT.inter(11, weight: FontWeight.w700, color: PT.amberText)),
          ),
        ],
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
            Padding(
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
            ? () => _place(gameId: f.gameId, eventId: f.eventId, f: f)
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

class _SheetRow {
  const _SheetRow(
      {required this.code,
      required this.start,
      required this.team,
      required this.comp,
      required this.fixture,
      required this.venue,
      required this.home,
      required this.referee,
      required this.rooms,
      this.note = '',
      this.onTap});
  final PitchCode code;
  final DateTime start;
  final String team, comp, fixture, venue, referee, rooms, note;
  final bool home;
  final VoidCallback? onTap;
}
