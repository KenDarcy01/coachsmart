// v3 Pitch planner, phone view (mock-up pa-mtoday): the day by pitch, a
// clash banner, a "need a pitch" banner and the same sheets as the board.
// No dragging on the phone: tap to place, move or edit.
import 'package:flutter/material.dart';

import 'v3_pitch_theme.dart';
import 'v3_pitch_board.dart' show codeColour, bookingCode;
import 'v3_pitch_controller.dart';
import 'v3_pitch_models.dart';
import 'v3_pitch_sheets.dart';

class PitchPhoneDay extends StatelessWidget {
  const PitchPhoneDay({super.key, required this.c});
  final PitchController c;

  @override
  Widget build(BuildContext context) {
    final board = c.board;
    if (board == null) return const SizedBox.shrink();
    final day = c.day;
    final clashes = board.clashesOn(day);
    final clashIds = board.clashIds(day);
    final inbox = board
        .inbox(clubName: c.club.name, season: c.season)
        .where((i) => !dayOf(i.start).isBefore(c.today))
        .toList();
    final short = board.groups.where((g) => g.short).toList();

    Future<void> open(Widget w) => showPitchSheet(context, w);

    return ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: [
          _DayStrip(c: c),
          const SizedBox(height: 10),
          if (clashes.isNotEmpty)
            _Banner(
                colour: PT.redTint,
                text: clashes.length == 1
                    ? '1 clash: ${c.titleOf(clashes.first.$1)} and ${c.titleOf(clashes.first.$2)} '
                        'on ${board.pitch(clashes.first.$1.pitchId)?.name ?? ''} at ${timeOf(clashes.first.$1.start)}. Tap one to fix.'
                    : '${clashes.length} clashes today. Tap a red booking to fix it.',
                textColour: PT.redText),
          if (inbox.isNotEmpty)
            _Banner(
                colour: PT.amberTint,
                big: '${inbox.length}',
                text: 'need a pitch this week',
                textColour: PT.amberText,
                onTap: () => open(_InboxList(c: c, items: inbox))),
          if (short.isNotEmpty)
            _Banner(
                colour: PT.card,
                big: '${short.length}',
                text:
                    'group${short.length == 1 ? '' : 's'} short of training slots: '
                    '${short.take(4).map((g) => g.name).join(', ')}${short.length > 4 ? '…' : ''}',
                textColour: PT.muted),
          if (c.rolledNote != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text(c.rolledNote!, style: PT.inter(13, color: PT.muted)),
            ),
          if (board.pitches.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 30),
              child: Center(
                  child: Text('Add your pitches in Setup to start.',
                      style: PT.inter(15, color: PT.muted))),
            ),
          for (final p in board.pitches)
            _PitchCard(c: c, pitch: p, clashIds: clashIds, open: open),
        ]);
  }
}

class _DayStrip extends StatelessWidget {
  const _DayStrip({required this.c});
  final PitchController c;
  @override
  Widget build(BuildContext context) {
    final m = c.monday;
    final accent = c.club.accent;
    return Row(children: [
      IconButton(
          onPressed: () => c.shiftDays(-7),
          icon: const Icon(Icons.chevron_left, color: PT.muted)),
      for (var i = 0; i < 7; i++)
        Expanded(
          child: GestureDetector(
            onTap: () => c.pickDay(m.add(Duration(days: i))),
            child: Builder(builder: (_) {
              final d = m.add(Duration(days: i));
              final on = d == c.day;
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 2),
                padding: const EdgeInsets.symmetric(vertical: 6),
                decoration: BoxDecoration(
                    color: on ? accent : PT.card,
                    borderRadius: BorderRadius.circular(10)),
                child: Column(children: [
                  Text(kWeekdays[i],
                      style: PT.inter(11,
                          color: on ? onAccent(accent) : PT.muted)),
                  Text('${d.day}',
                      style: PT.inter(16,
                          weight: FontWeight.w700,
                          color: on ? onAccent(accent) : PT.text)),
                ]),
              );
            }),
          ),
        ),
      IconButton(
          onPressed: () => c.shiftDays(7),
          icon: const Icon(Icons.chevron_right, color: PT.muted)),
    ]);
  }
}

class _Banner extends StatelessWidget {
  const _Banner(
      {required this.colour,
      required this.text,
      required this.textColour,
      this.big,
      this.onTap});
  final Color colour;
  final String text;
  final Color textColour;
  final String? big;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          decoration: BoxDecoration(
              color: colour, borderRadius: BorderRadius.circular(12)),
          child: Row(children: [
            if (big != null) ...[
              Text(big!,
                  style:
                      PT.inter(20, weight: FontWeight.w700, color: textColour)),
              const SizedBox(width: 10),
            ],
            Expanded(child: Text(text, style: PT.inter(14, color: textColour))),
            if (onTap != null) Icon(Icons.chevron_right, color: textColour),
          ]),
        ),
      );
}

class _PitchCard extends StatelessWidget {
  const _PitchCard(
      {required this.c,
      required this.pitch,
      required this.clashIds,
      required this.open});
  final PitchController c;
  final Pitch pitch;
  final Set<int> clashIds;
  final Future<void> Function(Widget) open;

  @override
  Widget build(BuildContext context) {
    final board = c.board!;
    final day = c.day;
    final closure = board.closureOn(pitch.pitchId, day);
    final bookings = [
      for (final b in board.bookingsOn(day, pitchId: pitch.pitchId))
        if (b.confirmed) b
    ];
    final matched = board.matchedOn(day, pitchId: pitch.pitchId);
    final slots =
        pitch.slots.isEmpty ? <PitchSlot>[] : pitch.slotsOn(day.weekday);
    final free = [
      for (final s in slots)
        if (!bookings.any(
            (b) => minutesOf(b.start) < s.closes && minutesOf(b.end) > s.opens))
          s
    ];
    final hasClash = bookings.any((b) => clashIds.contains(b.bookingId));

    return Opacity(
      opacity: closure != null ? 0.55 : 1,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.fromLTRB(12, 11, 12, 6),
        decoration: BoxDecoration(
            color: PT.card, borderRadius: BorderRadius.circular(14)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Flexible(
                child: Text(pitch.name,
                    overflow: TextOverflow.ellipsis,
                    style: PT.inter(16, weight: FontWeight.w600))),
            const SizedBox(width: 8),
            Expanded(
                child: Text(pitch.venue,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: PT.inter(12.5, color: PT.muted))),
            if (closure != null)
              const PitchTag('Closed', colour: PT.redText)
            else if (hasClash)
              const PitchTag('Clash', colour: PT.redText)
            else if (free.isNotEmpty)
              PitchTag('${free.length} free slot${free.length == 1 ? '' : 's'}',
                  colour: PT.green),
          ]),
          if (closure != null)
            _row(context, 'All day',
                closure.reason.isEmpty ? 'Closed' : closure.reason, null, null),
          if (closure == null && bookings.isEmpty && matched.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                  slots.isEmpty && pitch.slots.isNotEmpty
                      ? 'No slot today'
                      : 'Nothing booked',
                  style: PT.inter(13.5, color: PT.muted)),
            ),
          for (final b in bookings)
            _row(
                context,
                '${timeOf(b.start)}–${timeOf(b.end)}',
                c.titleOf(b),
                [
                  if (b.kind == 'match') 'Match',
                  if (pitch.split > 1) PitchPart.label(b.part, pitch.split),
                  if (clashIds.contains(b.bookingId)) 'clash',
                ].join(' · '),
                codeColour(bookingCode(c, b)),
                red: clashIds.contains(b.bookingId),
                onTap: () => open(BookingSheet(c: c, booking: b))),
          for (final e in matched)
            _row(
                context,
                timeOf(e.start),
                c.titleOfEvent(e),
                'From the event · tap to confirm',
                codeColour(codeOf(e.code, female: e.female)),
                faint: true,
                onTap: () => open(PlaceSheet(
                    c: c, item: c.itemOfEvent(e), pitch: pitch, at: e.start))),
        ]),
      ),
    );
  }

  Widget _row(BuildContext context, String when, String what, String? sub,
          Color? bar,
          {bool red = false, bool faint = false, VoidCallback? onTap}) =>
      GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: PT.line))),
          child: Row(children: [
            SizedBox(
                width: 92,
                child: Text(when, style: PT.inter(13, color: PT.muted))),
            if (bar != null)
              Container(
                  width: 4,
                  height: 34,
                  margin: const EdgeInsets.only(right: 10),
                  decoration: BoxDecoration(
                      color: faint ? bar.withValues(alpha: 0.4) : bar,
                      borderRadius: BorderRadius.circular(2))),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(what,
                        style: PT.inter(14.5,
                            weight: FontWeight.w500,
                            color: red
                                ? PT.redText
                                : faint
                                    ? PT.muted
                                    : PT.text)),
                    if (sub != null && sub.isNotEmpty)
                      Text(sub, style: PT.inter(12, color: PT.muted)),
                  ]),
            ),
          ]),
        ),
      );
}

class _InboxList extends StatelessWidget {
  const _InboxList({required this.c, required this.items});
  final PitchController c;
  final List<PlaceItem> items;
  @override
  Widget build(BuildContext context) => SafeArea(
        top: false,
        child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
            children: [
              Text('Needs a pitch', style: PT.tight(20)),
              const SizedBox(height: 8),
              for (final i in items)
                GestureDetector(
                  onTap: () async {
                    Navigator.pop(context);
                    await showPitchSheet(context, PlaceSheet(c: c, item: i));
                  },
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                        color: PT.bg,
                        border: Border(
                            left: BorderSide(
                                color: codeColour(i.codeKey), width: 4)),
                        borderRadius: BorderRadius.circular(12)),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(i.title,
                              style: PT.inter(15, weight: FontWeight.w600)),
                          Text(
                              '${kWeekdays[i.start.weekday - 1]} ${i.start.day} · ${timeOf(i.start)}'
                              '${i.subtitle.isEmpty ? '' : ' · ${i.subtitle}'}',
                              style: PT.inter(12.5, color: PT.muted)),
                        ]),
                  ),
                ),
            ]),
      );
}
