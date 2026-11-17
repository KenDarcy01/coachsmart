// v3 Pitch planner, the members' view (Ken, 2026-11-17): the week as the
// officer last published it, read-only. "Your teams this week" lists the
// member's own sessions and matches; below, a tab per pitch shows its week
// (a grid on a laptop, a day-by-day list on a phone). Their team is outlined.
import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'v3_pitch_theme.dart';
import 'v3_pitch_api.dart';
import 'v3_pitch_board.dart' show codeColour;
import 'v3_pitch_models.dart';

class PublishedBooking {
  const PublishedBooking(
      {required this.pitchId,
      required this.start,
      required this.end,
      required this.name,
      this.part = PitchPart.full,
      this.kind = 'training',
      this.code = '',
      this.opposition = '',
      this.referee = '',
      this.rooms = '',
      this.teamId});

  factory PublishedBooking.fromJson(Map j) => PublishedBooking(
      pitchId: int.tryParse('${j['pitch_id']}') ?? 0,
      start: parseLocal(j['starts_at']),
      end: parseLocal(j['ends_at']),
      name: '${j['name'] ?? ''}',
      part: int.tryParse('${j['part']}') ?? PitchPart.full,
      kind: '${j['kind'] ?? 'training'}',
      code: '${j['code'] ?? ''}',
      opposition: '${j['opposition'] ?? ''}',
      referee: '${j['referee'] ?? ''}',
      rooms: '${j['dressing_rooms'] ?? ''}',
      teamId: int.tryParse('${j['team_id']}'));

  final int pitchId;
  final DateTime start;
  final DateTime end;
  final String name;
  final int part;
  final String kind;
  final String code;
  final String opposition;
  final String referee;
  final String rooms;
  final int? teamId;

  String get title =>
      kind == 'match' && opposition.isNotEmpty ? '$name v $opposition' : name;
}

class PublishedWeek {
  PublishedWeek.fromJson(Map j)
      : publishedAt = j['published_at'] == null
            ? null
            : DateTime.tryParse('${j['published_at']}')?.toLocal(),
        pitches = {
          if (j['pitches'] is List)
            for (final p in (j['pitches'] as List).whereType<Map>())
              int.tryParse('${p['pitch_id']}') ?? 0: (
                '${p['name'] ?? ''}',
                '${p['venue'] ?? ''}',
                int.tryParse('${p['split']}') ?? 1
              )
        },
        bookings = [
          if (j['bookings'] is List)
            for (final b in (j['bookings'] as List).whereType<Map>())
              PublishedBooking.fromJson(b)
        ],
        myTeams = {
          if (j['my_teams'] is List)
            for (final x in j['my_teams'] as List) int.tryParse('$x') ?? 0
        },
        hours = [
          if (j['hours'] is List)
            for (final h in (j['hours'] as List).whereType<Map>())
              (int.tryParse('${h['pitch_id']}') ?? 0, PitchSlot.fromJson(h))
        ],
        blocks = [
          if (j['blocks'] is List)
            for (final b in (j['blocks'] as List).whereType<Map>())
              (int.tryParse('${b['pitch_id']}') ?? 0, PitchBlock.fromJson(b))
        ],
        closures = [
          if (j['closures'] is List)
            for (final c in (j['closures'] as List).whereType<Map>())
              Closure.fromJson({...c, 'closure_id': 0})
        ];

  final DateTime? publishedAt;
  final Map<int, (String, String, int)> pitches;
  final List<PublishedBooking> bookings;
  final List<Closure> closures;

  /// The signed-in member's teams (own or a linked child's).
  final Set<int> myTeams;
  final List<(int, PitchSlot)> hours;
  final List<(int, PitchBlock)> blocks;

  bool mine(PublishedBooking b) =>
      b.teamId != null && myTeams.contains(b.teamId);

  List<PitchSlot> slotsOn(int pitchId, int weekday) => [
        for (final (id, s) in hours)
          if (id == pitchId && s.weekday == weekday) s
      ]..sort((a, b) => a.opens.compareTo(b.opens));

  /// Unavailable: set by the admin, plus any time outside the slots.
  List<PitchBlock> unavailableOn(int pitchId, int weekday) {
    final own = [
      for (final (id, b) in blocks)
        if (id == pitchId && b.slot.weekday == weekday) b
    ];
    final slots = slotsOn(pitchId, weekday);
    if (!hours.any((h) => h.$1 == pitchId)) return own;
    return [...own, ...noSlotGaps(slots, own, weekday)];
  }
}

class PitchPublishedView extends StatefulWidget {
  const PitchPublishedView(
      {super.key,
      required this.club,
      this.api = const PitchApi(),
      this.today,
      this.padding});
  final PitchClub club;
  final PitchApi api;
  final DateTime? today;
  final EdgeInsets? padding;
  @override
  State<PitchPublishedView> createState() => _PitchPublishedViewState();
}

class _PitchPublishedViewState extends State<PitchPublishedView> {
  late DateTime _monday = mondayOf(widget.today ?? DateTime.now());
  PublishedWeek? _week;
  String? _error;
  int? _pitchId;

  /// A team picked in the pill row (by group name), or null for all.
  String? _team;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _week = null;
      _error = null;
    });
    try {
      final r = await widget.api.publishedWeek(widget.club.clubId, _monday);
      if (!mounted) return;
      setState(() => _week = PublishedWeek.fromJson(r));
    } catch (e) {
      if (mounted) setState(() => _error = pitchErrorText(e));
    }
  }

  void _shift(int weeks) {
    _monday = _monday.add(Duration(days: 7 * weeks));
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final w = _week;
    final sunday = _monday.add(const Duration(days: 6));
    final head = Row(children: [
      IconButton(
          onPressed: () => _shift(-1),
          icon: const Icon(Icons.chevron_left, color: PT.muted)),
      Expanded(
        child: Column(children: [
          Text(
              'Week of ${_monday.day} ${kMonths[_monday.month - 1].substring(0, 3)}'
              ' – ${sunday.day} ${kMonths[sunday.month - 1].substring(0, 3)}',
              style: PT.tight(18)),
          if (w?.publishedAt != null)
            Text(
                'Published ${w!.publishedAt!.day}/${w.publishedAt!.month} at ${timeOf(w.publishedAt!)}',
                style: PT.inter(12.5, color: PT.muted)),
        ]),
      ),
      IconButton(
          onPressed: () => _shift(1),
          icon: const Icon(Icons.chevron_right, color: PT.muted)),
    ]);

    return LayoutBuilder(builder: (context, box) {
      final wide = box.maxWidth >= 760;
      final children = <Widget>[head, const SizedBox(height: 8)];
      if (_error != null) {
        children.add(Text(_error!, style: PT.inter(15, color: PT.muted)));
      } else if (w == null) {
        children.add(const Center(
            child: Padding(
                padding: EdgeInsets.all(30),
                child: CircularProgressIndicator(color: PT.muted))));
      } else if (w.publishedAt == null) {
        children.add(Padding(
          padding: const EdgeInsets.symmetric(vertical: 30),
          child: Text('This week\'s pitches aren\'t published yet.',
              textAlign: TextAlign.center,
              style: PT.inter(15, color: PT.muted)),
        ));
      } else {
        final mine = [
          for (final b in w.bookings)
            if (w.mine(b)) b
        ]..sort((a, b) => a.start.compareTo(b.start));
        final names = {for (final b in w.bookings) b.name}.toList()
          ..sort((a, b) {
            final x = ageOf(a) ?? 99, y = ageOf(b) ?? 99;
            return x != y ? x.compareTo(y) : a.compareTo(b);
          });
        if (names.isNotEmpty) {
          children.add(_teamPills(names));
          children.add(const SizedBox(height: 10));
        }
        if (_team != null) {
          children.add(_mineCard(
              w,
              [
                for (final b in w.bookings)
                  if (b.name == _team) b
              ]..sort((a, b) => a.start.compareTo(b.start)),
              heading: '${_team!} this week'));
        } else if (mine.isNotEmpty) {
          children.add(_mineCard(w, mine));
        }
        final ids = w.pitches.keys.toList();
        if (ids.isNotEmpty) {
          final pid = ids.contains(_pitchId) ? _pitchId! : ids.first;
          children.add(const SizedBox(height: 12));
          children.add(_tabs(w, ids, pid));
          children.add(const SizedBox(height: 10));
          children.add(wide ? _grid(w, pid) : _dayList(w, pid));
        }
      }
      return Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: wide ? 1200 : 720),
          child: ListView(
              padding:
                  widget.padding ?? const EdgeInsets.fromLTRB(16, 8, 16, 24),
              children: children),
        ),
      );
    });
  }

  Widget _panel(Widget child, {EdgeInsets? padding}) => Container(
        clipBehavior: Clip.antiAlias,
        padding: padding,
        decoration: BoxDecoration(
            color: PT.card,
            border: Border.all(color: PT.line),
            borderRadius: BorderRadius.circular(14)),
        child: child,
      );

  String _place(PublishedWeek w, PublishedBooking b) {
    final p = w.pitches[b.pitchId];
    return [
      if (p != null) p.$1,
      if (p != null && p.$2.isNotEmpty) p.$2,
      if (p != null && p.$3 > 1 && b.part != PitchPart.full)
        PitchPart.label(b.part, p.$3),
      if (b.rooms.isNotEmpty) 'Rooms ${b.rooms}',
    ].join(' · ');
  }

  /// The member's own sessions and matches, one row each.
  /// One scrolling row: All teams, then every team on the week's plan
  /// (Ken, 2026-11-17), signed in or not.
  Widget _teamPills(List<String> names) {
    final accent = widget.club.accent;
    Widget pill(String label, bool on, VoidCallback tap) => Padding(
          padding: const EdgeInsets.only(right: 6),
          child: GestureDetector(
            onTap: tap,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                  color: on ? accent : PT.card,
                  border: Border.all(color: on ? accent : PT.line),
                  borderRadius: BorderRadius.circular(18)),
              child: Text(label,
                  style: PT.inter(13.5,
                      weight: FontWeight.w600,
                      color: on ? onAccent(accent) : PT.text)),
            ),
          ),
        );
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(children: [
        pill('All teams', _team == null, () => setState(() => _team = null)),
        for (final n in names)
          pill(n, _team == n, () => setState(() => _team = n)),
      ]),
    );
  }

  Widget _mineCard(PublishedWeek w, List<PublishedBooking> mine,
      {String heading = 'Your teams this week'}) {
    final accent = widget.club.accent;
    return _panel(
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 4),
          child: Text(heading.toUpperCase(),
              style: PT.inter(12.5,
                  weight: FontWeight.w700, color: accent, letterSpacing: 0.6)),
        ),
        if (mine.isEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 4, 14, 12),
            child: Text('No pitch slots this week.',
                style: PT.inter(14, color: PT.muted)),
          ),
        for (final (i, b) in mine.indexed) ...[
          if (i > 0) const Divider(height: 1, thickness: 1, color: PT.line),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 9, 14, 9),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(
                  width: 4,
                  height: 36,
                  margin: const EdgeInsets.only(right: 10),
                  decoration: BoxDecoration(
                      color: codeColour(codeOf(b.code, name: b.name)),
                      borderRadius: BorderRadius.circular(2))),
              SizedBox(
                width: 104,
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${kWeekdays[b.start.weekday - 1]} ${b.start.day}',
                          style: PT.inter(13.5, weight: FontWeight.w700)),
                      Text('${timeOf(b.start)}–${timeOf(b.end)}',
                          style: PT.inter(12.5, color: PT.muted)),
                    ]),
              ),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Flexible(
                          child: Text(
                              b.kind == 'match'
                                  ? b.title
                                  : '${b.name} training',
                              style: PT.inter(14.5, weight: FontWeight.w600)),
                        ),
                        if (b.kind == 'match') ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 1),
                            decoration: BoxDecoration(
                                color: PT.redTint,
                                borderRadius: BorderRadius.circular(5)),
                            child: Text('Match',
                                style: PT.inter(11,
                                    weight: FontWeight.w700,
                                    color: PT.redText)),
                          ),
                        ],
                      ]),
                      Text(_place(w, b),
                          style: PT.inter(12.5, color: PT.muted)),
                    ]),
              ),
            ]),
          ),
        ],
      ]),
    );
  }

  Widget _tabs(PublishedWeek w, List<int> ids, int on) {
    final accent = widget.club.accent;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(children: [
        for (final id in ids)
          Padding(
            padding: const EdgeInsets.only(right: 6),
            child: GestureDetector(
              onTap: () => setState(() => _pitchId = id),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                    color: id == on ? accent.withValues(alpha: 0.14) : PT.card,
                    border: Border.all(color: id == on ? accent : PT.line),
                    borderRadius: BorderRadius.circular(18)),
                child: Text(w.pitches[id]?.$1 ?? 'Pitch',
                    style: PT.inter(13.5,
                        weight: FontWeight.w600,
                        color: id == on ? accent : PT.text)),
              ),
            ),
          ),
      ]),
    );
  }

  List<PublishedBooking> _on(PublishedWeek w, int pid, DateTime day) => [
        for (final b in w.bookings)
          if (b.pitchId == pid && dayOf(b.start) == day) b
      ]..sort((a, b) => a.start.compareTo(b.start));

  Closure? _closed(PublishedWeek w, int pid, DateTime day) {
    for (final c in w.closures) {
      if (c.pitchId == pid && c.covers(day)) return c;
    }
    return null;
  }

  Widget _block(PublishedWeek w, PublishedBooking b,
      {bool compact = false, String extra = ''}) {
    final col = codeColour(codeOf(b.code, name: b.name));
    final mine = _team != null ? b.name == _team : w.mine(b);
    return Container(
      padding: EdgeInsets.fromLTRB(8, compact ? 3 : 6, 6, compact ? 3 : 6),
      decoration: BoxDecoration(
          color: Color.alphaBlend(col.withValues(alpha: 0.16), PT.card),
          border: Border(left: BorderSide(color: col, width: 4)),
          borderRadius: BorderRadius.circular(6)),
      foregroundDecoration: mine
          ? BoxDecoration(
              border: Border.all(color: PT.text, width: 2),
              borderRadius: BorderRadius.circular(6))
          : null,
      child: Text(
          '${b.title}$extra${mine && _team == null ? ' · your team' : ''}',
          maxLines: compact ? 2 : 1,
          overflow: TextOverflow.ellipsis,
          style: PT.inter(compact ? 12 : 14, weight: FontWeight.w600)),
    );
  }

  /// Phone: the chosen pitch day by day, bookings and free slots in order.
  Widget _dayList(PublishedWeek w, int pid) {
    final kids = <Widget>[];
    for (var i = 0; i < 7; i++) {
      final day = _monday.add(Duration(days: i));
      final books = _on(w, pid, day);
      final free = [
        for (final s in w.slotsOn(pid, day.weekday))
          if (!books.any((b) =>
              minutesOf(b.start) < s.closes && s.opens < minutesOf(b.end)))
            s
      ];
      final rows = <(int, Widget)>[
        for (final b in books)
          (
            minutesOf(b.start),
            _timeRow('${timeOf(b.start)}–${timeOf(b.end)}', _block(w, b))
          ),
        for (final s in free)
          (
            s.opens,
            _timeRow(
                s.label, Text('Free', style: PT.inter(14, color: PT.faint)))
          ),
      ]..sort((a, b) => a.$1.compareTo(b.$1));
      final closed = _closed(w, pid, day);
      kids.add(Container(
        width: double.infinity,
        color: PT.card2,
        padding: const EdgeInsets.fromLTRB(14, 7, 14, 7),
        child: Text(longDay(day),
            style: PT.inter(12.5, weight: FontWeight.w700, color: PT.muted)),
      ));
      if (closed != null) {
        kids.add(_timeRow(
            'All day',
            Text('Closed${closed.reason.isEmpty ? '' : ': ${closed.reason}'}',
                style: PT.inter(14, color: PT.redText))));
      } else if (rows.isEmpty) {
        kids.add(_timeRow(
            '', Text('Unavailable', style: PT.inter(14, color: PT.faint))));
      } else {
        kids.addAll(rows.map((r) => r.$2));
      }
    }
    return _panel(Column(children: kids));
  }

  Widget _timeRow(String time, Widget child) => Padding(
        padding: const EdgeInsets.fromLTRB(14, 6, 14, 6),
        child: Row(children: [
          SizedBox(
              width: 96,
              child: Text(time, style: PT.inter(13, color: PT.muted))),
          Expanded(child: child),
        ]),
      );

  /// Laptop: the chosen pitch's week as a grid, like the admin board.
  Widget _grid(PublishedWeek w, int pid) {
    const px = 0.9; // pixels per minute
    var lo = 8 * 60, hi = 22 * 60;
    for (final b in w.bookings.where((b) => b.pitchId == pid)) {
      lo = math.min(lo, minutesOf(b.start) ~/ 60 * 60);
      hi = math.max(hi, (minutesOf(b.end) + 59) ~/ 60 * 60);
    }
    final height = (hi - lo) * px;
    double y(int m) => (m - lo) * px;

    Widget column(DateTime day) {
      final closed = _closed(w, pid, day);
      final books = _on(w, pid, day);
      return Stack(children: [
        for (var m = lo; m < hi; m += 60)
          Positioned(
              top: y(m),
              left: 0,
              right: 0,
              child: Container(height: 1, color: PT.line)),
        for (final u in w.unavailableOn(pid, day.weekday))
          if (u.slot.closes > lo && u.slot.opens < hi)
            Positioned(
              top: y(math.max(u.slot.opens, lo)),
              height:
                  (math.min(u.slot.closes, hi) - math.max(u.slot.opens, lo)) *
                      px,
              left: 0,
              right: 0,
              child: const CustomPaint(painter: _Hatch()),
            ),
        for (final s in w.slotsOn(pid, day.weekday))
          if (!books.any((b) =>
              minutesOf(b.start) < s.closes && s.opens < minutesOf(b.end)))
            Positioned(
              top: y(s.opens) + 4,
              left: 6,
              child: Text('Free', style: PT.inter(11.5, color: PT.faint)),
            ),
        for (final b in books)
          Positioned(
            top: y(minutesOf(b.start)) + 1,
            height:
                math.max(18, (minutesOf(b.end) - minutesOf(b.start)) * px - 2),
            left: 3,
            right: 3,
            child: Tooltip(
              message:
                  '${b.title}\n${timeOf(b.start)}–${timeOf(b.end)} · ${_place(w, b)}',
              child: _block(w, b, compact: true),
            ),
          ),
        if (closed != null)
          Positioned.fill(
            child: Container(
              color: const Color(0xE6FBEFEF),
              alignment: Alignment.center,
              child: Text(
                  'Closed${closed.reason.isEmpty ? '' : '\n${closed.reason}'}',
                  textAlign: TextAlign.center,
                  style: PT.inter(12.5,
                      weight: FontWeight.w600, color: PT.redText)),
            ),
          ),
      ]);
    }

    final days = [for (var i = 0; i < 7; i++) _monday.add(Duration(days: i))];
    return _panel(Column(children: [
      Container(
        decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: PT.line))),
        child: Row(children: [
          const SizedBox(width: 52),
          for (final d in days)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 9, 4, 9),
                child: Text('${kWeekdays[d.weekday - 1]} ${d.day}',
                    style: PT.inter(13, weight: FontWeight.w700)),
              ),
            ),
        ]),
      ),
      SizedBox(
        height: height,
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(
            width: 52,
            child: Stack(children: [
              for (var m = lo; m < hi; m += 60)
                Positioned(
                    top: y(m) + 2,
                    left: 8,
                    child: Text(hhmm(m), style: PT.inter(11, color: PT.faint))),
            ]),
          ),
          for (final d in days)
            Expanded(
              child: Container(
                height: height,
                decoration: const BoxDecoration(
                    border: Border(left: BorderSide(color: PT.line))),
                child: column(d),
              ),
            ),
        ]),
      ),
    ]));
  }
}

class _Hatch extends CustomPainter {
  const _Hatch();
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
        Offset.zero & size, Paint()..color = const Color(0xFFF1F2F4));
    final line = Paint()
      ..color = const Color(0xFFE2E4E8)
      ..strokeWidth = 1;
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    for (var x = -size.height; x < size.width; x += 9) {
      canvas.drawLine(Offset(x, size.height), Offset(x + size.height, 0), line);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _Hatch oldDelegate) => false;
}
