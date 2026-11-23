// Weekend grass (Ken's club admin, 2026-11-20): one look at every grass
// pitch on Saturday and Sunday, like the "Grass Sat-Sun" tab of the club's
// old sheet. Each held slot shows its team or "Free" (tap to book).
// Unavailable times and closed days say so; nothing here changes the plan
// except through the normal booking sheet.

import 'package:flutter/material.dart';

import 'v3_pitch_board.dart';
import 'v3_pitch_controller.dart';
import 'v3_pitch_models.dart';
import 'v3_pitch_sheets.dart';
import 'v3_pitch_theme.dart';

/// One line in a pitch's day: a booking, an event to confirm, or a free slot.
class _Line {
  const _Line(this.at, this.when, this.what,
      {this.bar,
      this.free = false,
      this.faint = false,
      this.onTap,
      this.onDrop});
  final int at;
  final String when, what;
  final Color? bar;
  final bool free, faint;
  final VoidCallback? onTap;

  /// A free slot takes a fixture or group dropped on it.
  final ValueChanged<PitchDrag>? onDrop;
}

class PitchWeekendView extends StatefulWidget {
  const PitchWeekendView({super.key, required this.c, this.wide = true});
  final PitchController c;
  final bool wide;

  @override
  State<PitchWeekendView> createState() => _PitchWeekendViewState();
}

class _PitchWeekendViewState extends State<PitchWeekendView> {
  int? _focus;

  /// Weekend (Sat, Sun) or weekdays (Mon-Fri) (Ken 2026-11-23).
  bool _weekend = true;
  PitchController get c => widget.c;
  bool get wide => widget.wide;

  @override
  Widget build(BuildContext context) {
    final board = c.board!;
    final days = [
      for (var i = _weekend ? 5 : 0; i < (_weekend ? 7 : 5); i++)
        c.monday.add(Duration(days: i))
    ];
    final first = days.first, last = days.last;
    final grass = [
      for (final p in board.pitches)
        if (p.surface == 'grass') p
    ];
    Future<void> open(Widget w) => showPitchSheet(context, w);

    // Something from the panel dropped on a pitch's day: a free slot gives
    // the time, else the fixture keeps its own time.
    Future<void> drop(PitchDrag d, Pitch p, DateTime day, PitchSlot? s) =>
        switch (d) {
          DragItem(:final item) => open(PlaceSheet(
              c: c,
              item: item,
              pitch: p,
              at: atMinutes(day, s?.opens ?? minutesOf(item.start)))),
          DragGroup(:final group) => open(BookingSheet(
              c: c,
              group: group,
              pitch: p,
              at: atMinutes(day, s?.opens ?? 10 * 60),
              minutes: s == null ? null : s.closes - s.opens)),
          DragBooking() => Future.value(),
        };

    List<_Line> lines(Pitch p, DateTime day) {
      final bookings = [
        for (final b in board.bookingsOn(day, pitchId: p.pitchId))
          if (b.confirmed) b
      ];
      final slots = p.slotsOn(day.weekday);
      final matched = board.matchedOn(day, pitchId: p.pitchId);
      final other = board.sharedBookingsOn(day, p.pitchId);
      return [
        for (final b in bookings)
          _Line(
              minutesOf(b.start),
              '${timeOf(b.start)}–${timeOf(b.end)}',
              board.earlyThrowIn(b) == null
                  ? c.titleOf(b)
                  : '${c.titleOf(b)} · throw-in ${timeOf(board.earlyThrowIn(b)!)}',
              bar: codeColour(bookingCode(c, b)),
              onTap: () => open(BookingSheet(c: c, booking: b))),
        for (final e in matched)
          _Line(minutesOf(e.start), timeOf(e.start), c.titleOfEvent(e),
              bar: codeColour(
                  codeOf(e.code, female: e.female, name: e.teamName)),
              faint: true,
              onTap: () => open(PlaceSheet(
                  c: c, item: c.itemOfEvent(e), pitch: p, at: e.start))),
        for (final b in other)
          _Line(minutesOf(b.start), '${timeOf(b.start)}–${timeOf(b.end)}',
              'In use on ${board.pitch(b.pitchId)?.name ?? ''} · ${c.titleOf(b)}',
              faint: true),
        for (final s in slots)
          if (![...bookings, ...other].any((b) =>
                  minutesOf(b.start) < s.closes &&
                  minutesOf(b.end) > s.opens) &&
              !matched.any((e) =>
                  minutesOf(e.start) < s.closes &&
                  minutesOf(e.start) >= s.opens))
            _Line(s.opens, s.label, 'Free',
                free: true,
                onDrop: (d) => drop(d, p, day, s),
                onTap: () => open(BookingSheet(
                    c: c,
                    pitch: p,
                    at: atMinutes(day, s.opens),
                    minutes: s.closes - s.opens))),
      ]..sort((a, b) => a.at.compareTo(b.at));
    }

    int freeOn(DateTime day) => grass.fold(
        0,
        (n, p) => board.closureOn(p.pitchId, day) != null
            ? n
            : n + lines(p, day).where((l) => l.free).length);

    Widget cell(Pitch p, DateTime day) {
      final closure = board.closureOn(p.pitchId, day);
      if (closure != null) {
        return _note(
            'Closed${closure.reason.isEmpty ? '' : ' · ${closure.reason}'}',
            PT.redText,
            PT.redTint);
      }
      final ls = lines(p, day);
      return DragTarget<PitchDrag>(
        onWillAcceptWithDetails: (d) => d.data is! DragBooking,
        onAcceptWithDetails: (d) => drop(d.data, p, day, null),
        builder: (context, cand, _) => Container(
          decoration: cand.isEmpty
              ? null
              : BoxDecoration(
                  border: Border.all(color: c.club.accent, width: 2),
                  borderRadius: BorderRadius.circular(10)),
          child: ls.isEmpty
              ? _note('Unavailable', PT.muted, PT.card2)
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [for (final l in ls) _lineRow(l)]),
        ),
      );
    }

    String dm(DateTime d) => '${d.day} ${kMonths[d.month - 1].substring(0, 3)}';
    final nav = Row(children: [
      IconButton(
          tooltip: 'Last week',
          onPressed: () => c.shiftDays(-7),
          icon: Icon(Icons.chevron_left, color: PT.text)),
      Flexible(
        child: Text(
            '${kWeekdays[first.weekday - 1]} ${dm(first)} – '
            '${kWeekdays[last.weekday - 1]} ${dm(last)}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: PT.inter(16, weight: FontWeight.w600)),
      ),
      IconButton(
          tooltip: 'Next week',
          onPressed: () => c.shiftDays(7),
          icon: Icon(Icons.chevron_right, color: PT.text)),
    ]);
    final counts = [
      for (final d in days)
        _count(_weekend ? kDayNames[d.weekday - 1] : kWeekdays[d.weekday - 1],
            freeOn(d)),
    ];
    Widget chip(String label, bool on, VoidCallback tap) => Padding(
          padding: const EdgeInsets.only(right: 8),
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: tap,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              decoration: BoxDecoration(
                  color: on ? c.club.accent : PT.card,
                  border: Border.all(color: on ? c.club.accent : PT.line),
                  borderRadius: BorderRadius.circular(20)),
              child: Text(label,
                  style: PT.inter(13.5,
                      weight: FontWeight.w600,
                      color: on ? Colors.white : PT.text)),
            ),
          ),
        );
    final toggle = Row(mainAxisSize: MainAxisSize.min, children: [
      chip('Weekdays', !_weekend, () => setState(() => _weekend = false)),
      chip('Weekend', _weekend, () => setState(() => _weekend = true)),
    ]);
    final weekBar = wide
        ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [toggle, Flexible(child: nav)]),
            const SizedBox(height: 4),
            Wrap(spacing: 8, runSpacing: 6, children: counts),
          ])
        : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Padding(padding: const EdgeInsets.only(left: 8), child: toggle),
            nav,
            Padding(
              padding: const EdgeInsets.only(left: 8),
              child: Wrap(spacing: 8, runSpacing: 6, children: counts),
            ),
          ]);

    if (grass.isEmpty) {
      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        weekBar,
        const SizedBox(height: 20),
        Text('No grass pitches set up yet.',
            style: PT.inter(14, color: PT.muted)),
      ]);
    }

    Widget dayHead(String label) => Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
          child: Text(label,
              style: PT.inter(13, weight: FontWeight.w700, color: PT.muted)),
        );

    if (wide) {
      return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(
            width: 290,
            child: PitchInbox(
                c: c,
                open: open,
                days: {for (final d in days) d.weekday},
                focus: _focus,
                onFocus: (id) => setState(() => _focus = id),
                onDay: (d) => c.pickDay(d))),
        const SizedBox(width: 16),
        Expanded(
            child: ListView(children: [
          weekBar,
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
                color: PT.card,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: PT.line)),
            clipBehavior: Clip.antiAlias,
            child: Table(
              columnWidths: {
                0: FixedColumnWidth(_weekend ? 170 : 120),
                for (var i = 1; i <= days.length; i++)
                  i: const FlexColumnWidth(),
              },
              border: TableBorder(
                  horizontalInside: BorderSide(color: PT.line),
                  verticalInside: BorderSide(color: PT.line)),
              children: [
                TableRow(decoration: BoxDecoration(color: PT.card2), children: [
                  dayHead('PITCH'),
                  for (final d in days)
                    dayHead(
                        '${(_weekend ? kDayNames : kWeekdays)[d.weekday - 1].toUpperCase()} '
                        '${dm(d).toUpperCase()}'),
                ]),
                for (final p in grass)
                  TableRow(children: [
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(p.name,
                                style: PT.inter(15, weight: FontWeight.w700)),
                            Text(p.venue, style: PT.inter(12, color: PT.muted)),
                          ]),
                    ),
                    for (final d in days)
                      Padding(
                          padding: EdgeInsets.all(_weekend ? 8 : 5),
                          child: cell(p, d)),
                  ]),
              ],
            ),
          ),
          const SizedBox(height: 24),
        ])),
      ]);
    }

    // Phone: a card per pitch, Saturday then Sunday.
    return ListView(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
        children: [
          weekBar,
          const SizedBox(height: 8),
          for (final p in grass)
            Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.fromLTRB(12, 11, 12, 10),
              decoration: BoxDecoration(
                  color: PT.card, borderRadius: BorderRadius.circular(14)),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(children: [
                      Text(p.name,
                          style: PT.inter(16, weight: FontWeight.w700)),
                      const SizedBox(width: 8),
                      Expanded(
                          child: Text(p.venue,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: PT.inter(12.5, color: PT.muted))),
                    ]),
                    for (final (label, day) in [
                      for (final d in days) (kDayNames[d.weekday - 1], d)
                    ]) ...[
                      Padding(
                        padding: const EdgeInsets.only(top: 10, bottom: 4),
                        child: Text(label.toUpperCase(),
                            style: PT.inter(11.5,
                                weight: FontWeight.w700, color: PT.muted)),
                      ),
                      cell(p, day),
                    ],
                  ]),
            ),
        ]);
  }

  static Widget _count(String day, int n) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
            color: n > 0 ? PT.greenTint : PT.card2,
            borderRadius: BorderRadius.circular(20)),
        child: Text('$day: $n free',
            style: PT.inter(13,
                weight: FontWeight.w600, color: n > 0 ? PT.green : PT.muted)),
      );

  static Widget _note(String text, Color fg, Color bg) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        decoration:
            BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
        child: Text(text,
            style: PT.inter(13.5, weight: FontWeight.w600, color: fg)),
      );

  Widget _lineRow(_Line l) => l.onDrop == null
      ? _lineBody(l, false)
      : DragTarget<PitchDrag>(
          onWillAcceptWithDetails: (d) => d.data is! DragBooking,
          onAcceptWithDetails: (d) => l.onDrop!(d.data),
          builder: (context, cand, _) => _lineBody(l, cand.isNotEmpty));

  Widget _lineBody(_Line l, bool hover) => GestureDetector(
        onTap: l.onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          margin: const EdgeInsets.only(bottom: 4),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
              color: l.free ? PT.greenTint : null,
              border: hover ? Border.all(color: PT.green, width: 2) : null,
              borderRadius: BorderRadius.circular(8)),
          child: Row(children: [
            SizedBox(
                width: _weekend || !wide ? 96 : 84,
                child: Text(l.when,
                    style: PT.inter(_weekend || !wide ? 13 : 12,
                        color: PT.muted))),
            if (l.bar != null)
              Container(
                  width: 4,
                  height: 18,
                  margin: const EdgeInsets.only(right: 8),
                  decoration: BoxDecoration(
                      color: l.faint ? l.bar!.withValues(alpha: 0.4) : l.bar,
                      borderRadius: BorderRadius.circular(2))),
            Expanded(
                child: Text(l.what,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: PT.inter(13.5,
                        weight: l.free ? FontWeight.w700 : FontWeight.w500,
                        color: l.free
                            ? PT.green
                            : l.faint
                                ? PT.muted
                                : PT.text))),
            if (l.free)
              Icon(Icons.add_circle_outline, size: 17, color: PT.green),
          ]),
        ),
      );
}
