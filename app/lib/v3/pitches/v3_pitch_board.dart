// v3 Pitch planner, laptop day board (mock-up pa-day): the "Needs a pitch"
// list and the groups on the left, pitches across and times down on the
// right. Drag a card or a group onto a pitch, drag a booking to move it,
// tap anything to edit. Slots the club holds are drawn lighter; the rest of
// the day is shaded ("No slot").
import 'package:flutter/material.dart';

import '../v3_theme.dart';
import 'v3_pitch_controller.dart';
import 'v3_pitch_models.dart';
import 'v3_pitch_sheets.dart';

const _pxPerMin = 1.15;
const _colWidth = 150.0;
const _timeCol = 52.0;

Color codeColour(PitchCode c) => kCodeColours[c]!;

PitchCode bookingCode(PitchController c, Booking b) {
  final g = c.board?.group(b.groupId);
  if (g != null && g.code != 'Other') return g.codeKey;
  return codeOf(b.code, female: b.female);
}

/// What can be dragged onto a pitch.
sealed class PitchDrag {}

class DragItem extends PitchDrag {
  DragItem(this.item);
  final PlaceItem item;
}

class DragGroup extends PitchDrag {
  DragGroup(this.group);
  final PitchGroup group;
}

class DragBooking extends PitchDrag {
  DragBooking(this.booking);
  final Booking booking;
}

class PitchDayBoard extends StatefulWidget {
  const PitchDayBoard({super.key, required this.c});
  final PitchController c;
  @override
  State<PitchDayBoard> createState() => _PitchDayBoardState();
}

class _PitchDayBoardState extends State<PitchDayBoard> {
  String _venue = '';
  final _hScroll = ScrollController();
  final _vScroll = ScrollController();

  PitchController get c => widget.c;

  @override
  void dispose() {
    _hScroll.dispose();
    _vScroll.dispose();
    super.dispose();
  }

  Future<void> _open(Widget sheet) async {
    await showPitchSheet(context, sheet);
  }

  Future<void> _quick(Future<String?> call, String done) async {
    final err = await call;
    if (!mounted) return;
    pitchSnack(context, err ?? done);
  }

  /// Something dropped on [pitch] at [minute].
  Future<void> _drop(PitchDrag d, Pitch pitch, int minute) async {
    final board = c.board!;
    final day = c.day;
    final slot = pitch.slotAt(day.weekday, minute);
    final startMin = slot?.opens ?? (minute ~/ 15) * 15;
    final start = atMinutes(day, startMin);
    switch (d) {
      case DragItem(:final item):
        await _open(PlaceSheet(c: c, item: item, pitch: pitch, at: start));
      case DragGroup(:final group):
        final len = slot == null
            ? board.durations.training
            : (slot.closes - slot.opens)
                .clamp(15, board.durations.training * 2);
        final end = start.add(Duration(minutes: len));
        final part = PitchPart.options(pitch.split).firstWhere(
            (p) => board.isFree(pitch, start, end, p),
            orElse: () => 0);
        if (part == 0 || slot == null) {
          await _open(
              BookingSheet(c: c, group: group, pitch: pitch, at: start));
        } else {
          await _quick(c.placeGroup(group, pitch, start, end, part),
              '${group.name} on ${pitch.name} ${timeOf(start)} every week from now.');
        }
      case DragBooking(:final booking):
        final len = booking.end.difference(booking.start);
        final s =
            booking.gameId != null ? booking.start : atMinutes(day, startMin);
        final e = s.add(len);
        var part = booking.part;
        if (!PitchPart.options(pitch.split).contains(part))
          part = PitchPart.full;
        if (!board.isFree(pitch, s, e, part, except: booking.bookingId)) {
          final alt = PitchPart.options(pitch.split).firstWhere(
              (p) => board.isFree(pitch, s, e, p, except: booking.bookingId),
              orElse: () => 0);
          if (alt == 0) {
            pitchSnack(context, '${pitch.name} is in use then.');
            return;
          }
          part = alt;
        }
        await _quick(
            c.saveBooking({
              'booking_id': booking.bookingId,
              'pitch_id': pitch.pitchId,
              'part': part,
              'starts_at': isoLocal(s),
              'ends_at': isoLocal(e),
              'following': true,
            }),
            '${c.titleOf(booking)} moved to ${pitch.name} ${timeOf(s)}'
            '${booking.kind == 'training' ? ' for this and following weeks' : ''}.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final board = c.board;
    if (board == null) return const SizedBox.shrink();
    final venues = <String>[];
    for (final p in board.pitches) {
      if (!venues.contains(p.venue)) venues.add(p.venue);
    }
    final pitches = [
      for (final p in board.pitches)
        if (_venue.isEmpty || p.venue == _venue) p
    ];
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SizedBox(width: 290, child: _Inbox(c: c, open: _open)),
      const SizedBox(width: 16),
      Expanded(
        child: Container(
          decoration: BoxDecoration(
              color: V3.card, borderRadius: BorderRadius.circular(14)),
          clipBehavior: Clip.antiAlias,
          child: Column(children: [
            if (venues.length > 1)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(children: [
                    for (final v in ['', ...venues])
                      Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: _Chip(
                            label: v.isEmpty ? 'All venues' : v,
                            on: _venue == v,
                            accent: c.club.accent,
                            onTap: () => setState(() => _venue = v)),
                      )
                  ]),
                ),
              ),
            Expanded(
                child: pitches.isEmpty
                    ? Center(
                        child: Text('Add your pitches in Setup to start.',
                            style: V3.inter(15, color: V3.muted)))
                    : _grid(board, pitches)),
            _legend(board),
          ]),
        ),
      ),
    ]);
  }

  Widget _grid(PitchBoard board, List<Pitch> pitches) {
    final wd = c.day.weekday;
    var lo = 24 * 60, hi = 0;
    for (final p in pitches) {
      for (final s in p.slotsOn(wd)) {
        if (s.opens < lo) lo = s.opens;
        if (s.closes > hi) hi = s.closes;
      }
    }
    for (final b in board.bookingsOn(c.day)) {
      lo = minutesOf(b.start) < lo ? minutesOf(b.start) : lo;
      hi = minutesOf(b.end) > hi ? minutesOf(b.end) : hi;
    }
    if (hi <= lo) {
      lo = 8 * 60;
      hi = 22 * 60;
    }
    lo = (lo ~/ 60) * 60;
    hi = ((hi + 59) ~/ 60) * 60;
    final height = (hi - lo) * _pxPerMin;
    final clashes = board.clashIds(c.day);

    return LayoutBuilder(builder: (context, box) {
      final colW =
          ((box.maxWidth - _timeCol) / pitches.length).clamp(_colWidth, 320.0);
      final width = _timeCol + colW * pitches.length;
      return Scrollbar(
        controller: _hScroll,
        child: SingleChildScrollView(
          controller: _hScroll,
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            width: width,
            child: Column(children: [
              // Pitch names.
              Container(
                decoration: const BoxDecoration(
                    border: Border(bottom: BorderSide(color: V3.line))),
                child: Row(children: [
                  const SizedBox(width: _timeCol),
                  for (final p in pitches)
                    SizedBox(
                      width: colW,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(10, 10, 6, 9),
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(p.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: V3.inter(14, weight: FontWeight.w600)),
                              Text(
                                  [p.venue, p.surfaceLabel]
                                      .where((s) => s.isNotEmpty)
                                      .join(' · '),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: V3.inter(11.5, color: V3.muted)),
                            ]),
                      ),
                    ),
                ]),
              ),
              Expanded(
                child: SingleChildScrollView(
                  controller: _vScroll,
                  child: SizedBox(
                    height: height + 12,
                    child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            width: _timeCol,
                            child: Stack(children: [
                              for (var m = lo; m < hi; m += 60)
                                Positioned(
                                  top: (m - lo) * _pxPerMin + 2,
                                  left: 10,
                                  child: Text(hhmm(m),
                                      style: V3.inter(11, color: V3.muted)),
                                )
                            ]),
                          ),
                          for (final p in pitches)
                            SizedBox(
                                width: colW,
                                height: height + 12,
                                child:
                                    _column(board, p, lo, hi, colW, clashes)),
                        ]),
                  ),
                ),
              ),
            ]),
          ),
        ),
      );
    });
  }

  Widget _column(
      PitchBoard board, Pitch p, int lo, int hi, double w, Set<int> clashes) {
    final day = c.day;
    final closure = board.closureOn(p.pitchId, day);
    final slots = p.slotsOn(day.weekday);
    double y(int m) => (m - lo) * _pxPerMin;

    final booked = [
      for (final b in board.bookingsOn(day, pitchId: p.pitchId))
        if (b.confirmed) b
    ];
    // Overlapping bookings on the same part sit side by side in lanes.
    final lane = <int, (int, int)>{};
    for (final b in booked) {
      final peers = [
        for (final o in booked)
          if (o.start.isBefore(b.end) &&
              o.end.isAfter(b.start) &&
              (p.split == 1 || (o.part & b.part) != 0))
            o
      ]..sort((x, y) => x.bookingId.compareTo(y.bookingId));
      lane[b.bookingId] = (peers.indexOf(b), peers.length);
    }

    final children = <Widget>[
      // Hour lines.
      for (var m = lo; m < hi; m += 60)
        Positioned(
            top: y(m),
            left: 0,
            right: 0,
            child: Container(height: 1, color: V3.line.withValues(alpha: 0.6))),
      // Held slots.
      for (final s in slots)
        Positioned(
          top: y(s.opens) + 1,
          height: (s.closes - s.opens) * _pxPerMin - 2,
          left: 2,
          right: 2,
          child: GestureDetector(
            onTap: closure != null
                ? null
                : () => _open(
                    BookingSheet(c: c, pitch: p, at: atMinutes(day, s.opens))),
            child: Container(
              decoration: BoxDecoration(
                  color: const Color(0xFF242A33),
                  border: Border.all(color: const Color(0xFF2F3642)),
                  borderRadius: BorderRadius.circular(6)),
              alignment: Alignment.topRight,
              padding: const EdgeInsets.fromLTRB(0, 3, 6, 0),
              child: (s.closes - s.opens) * _pxPerMin > 22 &&
                      p.slots.isNotEmpty &&
                      !booked.any((b) =>
                          minutesOf(b.start) < s.closes &&
                          minutesOf(b.end) > s.opens)
                  ? Text('Free',
                      style: V3.inter(10.5, color: const Color(0xFF59606B)))
                  : null,
            ),
          ),
        ),
    ];

    // Events whose own location names this pitch, not yet confirmed.
    for (final e in board.matchedOn(day, pitchId: p.pitchId)) {
      final item = c.itemOfEvent(e);
      final m = minutesOf(e.start);
      final len = c.minutesFor(item);
      final col = codeColour(item.codeKey);
      children.add(Positioned(
        top: y(m) + 2,
        height: (len * _pxPerMin - 4).clamp(18, 9999).toDouble(),
        left: 4,
        right: 4,
        child: GestureDetector(
          onTap: () =>
              _open(PlaceSheet(c: c, item: item, pitch: p, at: e.start)),
          child: Container(
            padding: const EdgeInsets.fromLTRB(7, 4, 6, 3),
            decoration: BoxDecoration(
                color: col.withValues(alpha: 0.07),
                border:
                    Border.all(color: col.withValues(alpha: 0.55), width: 1.2),
                borderRadius: BorderRadius.circular(8)),
            child: _blockText(item.title, '${timeOf(e.start)} · tap to confirm',
                faint: true),
          ),
        ),
      ));
    }

    for (final b in booked) {
      final (li, ln) = lane[b.bookingId] ?? (0, 1);
      final (a, z) = PitchPart.span(p.split == 1 ? PitchPart.full : b.part);
      final col = codeColour(bookingCode(c, b));
      final top = y(minutesOf(b.start)) + 2;
      final h = (b.end.difference(b.start).inMinutes * _pxPerMin - 4)
          .clamp(18, 9999)
          .toDouble();
      final inner = w - 8;
      final laneW = inner * (z - a) / ln;
      final block = Container(
        width: laneW - 3,
        height: h,
        padding: const EdgeInsets.fromLTRB(7, 4, 5, 3),
        decoration: BoxDecoration(
            color: col.withValues(alpha: b.kind == 'match' ? 0.28 : 0.13),
            border: Border(left: BorderSide(color: col, width: 3)),
            borderRadius: BorderRadius.circular(8)),
        foregroundDecoration: clashes.contains(b.bookingId)
            ? BoxDecoration(
                border: Border.all(color: V3.red, width: 2),
                borderRadius: BorderRadius.circular(8))
            : null,
        child: _blockText(
            c.titleOf(b),
            [
              timeOf(b.start),
              if (b.kind == 'match') 'Match',
              if (p.split > 1 && b.part != PitchPart.full)
                PitchPart.label(b.part, p.split),
              if (b.eventId != null) '✓ event',
            ].join(' · ')),
      );
      children.add(Positioned(
        top: top,
        left: 4 + inner * a + laneW * li,
        child: Draggable<PitchDrag>(
          data: DragBooking(b),
          feedback: Material(
              color: Colors.transparent,
              child: Opacity(opacity: 0.85, child: block)),
          childWhenDragging: Opacity(opacity: 0.3, child: block),
          child: GestureDetector(
              onTap: () => _open(BookingSheet(c: c, booking: b)), child: block),
        ),
      ));
    }

    if (closure != null) {
      children.add(Positioned.fill(
        child: GestureDetector(
          onTap: () => _reopen(closure, p),
          child: Container(
            color: const Color(0xCC2A2025),
            alignment: Alignment.center,
            padding: const EdgeInsets.all(8),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text('Closed',
                  style:
                      V3.inter(14, weight: FontWeight.w600, color: V3.redText)),
              if (closure.reason.isNotEmpty)
                Text(closure.reason,
                    textAlign: TextAlign.center,
                    style: V3.inter(12, color: V3.muted)),
              Text('tap to reopen', style: V3.inter(11, color: V3.muted)),
            ]),
          ),
        ),
      ));
    }

    return DragTarget<PitchDrag>(
      onWillAcceptWithDetails: (_) => closure == null,
      onAcceptWithDetails: (d) {
        final box = context.findRenderObject();
        if (box is! RenderBox) return;
        // Find this column's box from the drop position.
        final local = _columnLocal(d.offset, p);
        final m = lo + (local / _pxPerMin).round();
        _drop(d.data, p, m.clamp(lo, hi - 15));
      },
      builder: (ctx, cand, rej) => Container(
        key: _keys.putIfAbsent(p.pitchId, () => GlobalKey()),
        decoration: BoxDecoration(
            color:
                cand.isNotEmpty ? c.club.accent.withValues(alpha: 0.06) : null,
            border: const Border(left: BorderSide(color: V3.line))),
        child: Stack(clipBehavior: Clip.none, children: children),
      ),
    );
  }

  final Map<int, GlobalKey> _keys = {};

  double _columnLocal(Offset global, Pitch p) {
    final box = _keys[p.pitchId]?.currentContext?.findRenderObject();
    if (box is! RenderBox) return 0;
    // The drag feedback's top-left is the drop point; aim a little lower.
    return box.globalToLocal(global).dy + 8;
  }

  Future<void> _reopen(Closure cl, Pitch p) async {
    final yes = await showPitchSheet<bool>(
        context,
        Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Reopen ${p.name}?', style: V3.tight(20)),
                const SizedBox(height: 6),
                Text(
                    'Closed ${cl.from.day}/${cl.from.month}'
                    '${cl.to != cl.from ? ' to ${cl.to.day}/${cl.to.month}' : ''}'
                    '${cl.reason.isEmpty ? '' : ' (${cl.reason})'}.',
                    style: V3.inter(15, color: V3.muted)),
                const SizedBox(height: 16),
                Row(children: [
                  Expanded(
                      child: PitchButton('Keep closed',
                          onTap: () => Navigator.pop(context, false))),
                  const SizedBox(width: 8),
                  Expanded(
                      child: PitchButton('Reopen',
                          accent: c.club.accent,
                          onTap: () => Navigator.pop(context, true))),
                ]),
              ]),
        ));
    if (yes == true) await _quick(c.reopen(cl), '${p.name} is open again.');
  }

  Widget _blockText(String title, String sub, {bool faint = false}) =>
      LayoutBuilder(builder: (ctx, box) {
        final tall = box.maxHeight > 34;
        return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(title,
                    maxLines: tall ? 2 : 1,
                    overflow: TextOverflow.ellipsis,
                    style: V3.inter(12.5,
                        weight: FontWeight.w600,
                        height: 1.2,
                        color: faint ? V3.muted : V3.text)),
              ),
              if (tall)
                Text(sub,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: V3.inter(11, color: const Color(0xFFC8CCD2))),
            ]);
      });

  Widget _legend(PitchBoard board) {
    final n = board.clashesOn(c.day).length;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      decoration:
          const BoxDecoration(border: Border(top: BorderSide(color: V3.line))),
      child: Row(children: [
        for (final code
            in PitchCode.values.where((x) => x != PitchCode.other)) ...[
          Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                  color: codeColour(code), shape: BoxShape.circle)),
          const SizedBox(width: 5),
          Text(kCodeNames[code]!, style: V3.inter(12, color: V3.muted)),
          const SizedBox(width: 14),
        ],
        Expanded(
          child: Text(
              'Solid = match · light = training · outline = event to confirm',
              textAlign: TextAlign.right,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: V3.inter(12, color: V3.muted)),
        ),
        if (n > 0) ...[
          const SizedBox(width: 14),
          Text('● $n clash${n == 1 ? '' : 'es'}',
              style: V3.inter(12, weight: FontWeight.w600, color: V3.redText)),
        ],
      ]),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip(
      {required this.label,
      required this.on,
      required this.accent,
      required this.onTap});
  final String label;
  final bool on;
  final Color accent;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
              color: on ? accent.withValues(alpha: 0.16) : Colors.transparent,
              border: Border.all(color: on ? accent : V3.line),
              borderRadius: BorderRadius.circular(18)),
          child: Text(label,
              style: V3.inter(12.5,
                  weight: FontWeight.w600, color: on ? accent : V3.text)),
        ),
      );
}

// ------------------------------------------------------------------ inbox

class _Inbox extends StatelessWidget {
  const _Inbox({required this.c, required this.open});
  final PitchController c;
  final Future<void> Function(Widget) open;

  @override
  Widget build(BuildContext context) {
    final board = c.board!;
    final items = board
        .inbox(clubName: c.club.name, season: c.season)
        .where((i) => !dayOf(i.start).isBefore(c.today))
        .toList();
    final today = items.where((i) => board.sameDay(i.start, c.day)).toList();
    final later = items.where((i) => !board.sameDay(i.start, c.day)).toList();
    final groups = [...board.groups]
      ..sort((a, b) => (a.short ? 0 : 1).compareTo(b.short ? 0 : 1));
    final accent = c.club.accent;

    Widget head(String t, int n) => Padding(
          padding: const EdgeInsets.fromLTRB(2, 10, 2, 6),
          child: Row(children: [
            Expanded(
              child: Text(t.toUpperCase(),
                  overflow: TextOverflow.ellipsis,
                  style: V3.inter(12,
                      weight: FontWeight.w700,
                      color: accent,
                      letterSpacing: 0.6)),
            ),
            Text('$n', style: V3.inter(12, color: V3.muted)),
          ]),
        );

    return ListView(padding: EdgeInsets.zero, children: [
      head('Needs a pitch', items.length),
      if (items.isEmpty)
        Text('Nothing waiting this week.',
            style: V3.inter(13.5, color: V3.muted)),
      for (final i in [...today, ...later])
        _drag(
            DragItem(i),
            _ItemCard(c: c, item: i, dim: !board.sameDay(i.start, c.day)),
            () => open(PlaceSheet(c: c, item: i))),
      head('Groups · training this week', groups.length),
      if (groups.isEmpty)
        Text('No groups yet. Add them in Groups.',
            style: V3.inter(13.5, color: V3.muted)),
      for (final g in groups)
        _drag(
            DragGroup(g),
            _GroupCard(g: g),
            () => open(BookingSheet(
                c: c,
                group: g,
                pitch: board.pitches.isEmpty ? null : board.pitches.first,
                at: atMinutes(c.day, 18 * 60)))),
      const SizedBox(height: 8),
      Text('Drag a card or a group onto a pitch, or tap it.',
          style: V3.inter(12.5, color: V3.muted)),
      const SizedBox(height: 16),
    ]);
  }

  Widget _drag(PitchDrag data, Widget card, VoidCallback onTap) => Padding(
        padding: const EdgeInsets.only(bottom: 7),
        child: Draggable<PitchDrag>(
          data: data,
          feedback: Material(
              color: Colors.transparent,
              child: SizedBox(
                  width: 240, child: Opacity(opacity: 0.9, child: card))),
          childWhenDragging: Opacity(opacity: 0.35, child: card),
          child: GestureDetector(onTap: onTap, child: card),
        ),
      );
}

class _ItemCard extends StatelessWidget {
  const _ItemCard({required this.c, required this.item, this.dim = false});
  final PitchController c;
  final PlaceItem item;
  final bool dim;
  @override
  Widget build(BuildContext context) {
    final col = codeColour(item.codeKey);
    return Opacity(
      opacity: dim ? 0.75 : 1,
      child: Container(
        padding: const EdgeInsets.fromLTRB(11, 9, 10, 9),
        decoration: BoxDecoration(
            color: V3.card,
            border: Border(left: BorderSide(color: col, width: 4)),
            borderRadius: BorderRadius.circular(12)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(item.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: V3.inter(14, weight: FontWeight.w600)),
          const SizedBox(height: 2),
          Text(
              '${kWeekdays[item.start.weekday - 1]} ${item.start.day} · ${timeOf(item.start)}'
              '${item.subtitle.isEmpty ? '' : ' · ${item.subtitle}'}',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: V3.inter(12, color: V3.muted)),
          const SizedBox(height: 6),
          Row(children: [
            PitchTag(item.fixture != null
                ? 'Fixture'
                : item.request != null
                    ? 'Request'
                    : item.kind == 'match'
                        ? 'Match'
                        : 'Event'),
            if (item.fixture != null) ...[
              const SizedBox(width: 6),
              const PitchTag('From league', colour: Color(0xFF4DA3FF)),
            ],
          ]),
        ]),
      ),
    );
  }
}

class _GroupCard extends StatelessWidget {
  const _GroupCard({required this.g});
  final PitchGroup g;
  @override
  Widget build(BuildContext context) {
    final col = codeColour(g.codeKey);
    return Container(
      padding: const EdgeInsets.fromLTRB(11, 8, 10, 8),
      decoration: BoxDecoration(
          color: V3.card,
          border: Border(left: BorderSide(color: col, width: 4)),
          borderRadius: BorderRadius.circular(12)),
      child: Row(children: [
        Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(g.name, style: V3.inter(14, weight: FontWeight.w600)),
            Text(g.teamId == null ? 'Not on CoachSmart' : g.teamName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: V3.inter(11.5, color: V3.muted)),
          ]),
        ),
        if (g.sessions > 0)
          PitchTag('${g.booked}/${g.sessions}',
              colour: g.short ? V3.amberText : V3.green)
        else if (g.booked > 0)
          PitchTag('${g.booked}', colour: V3.green),
      ]),
    );
  }
}
