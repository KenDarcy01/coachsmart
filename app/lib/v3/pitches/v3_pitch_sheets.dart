// v3 Pitch planner: the sheets shared by the laptop board and the phone
// view (a centred dialog on a wide screen, a bottom sheet on a phone):
// place an item, edit a booking, add a booking in an empty slot, close a
// pitch.
import 'package:flutter/material.dart';

import 'v3_pitch_theme.dart';
import 'v3_pitch_controller.dart';
import 'v3_pitch_models.dart';

const kWide = 900.0;

Future<T?> showPitchSheet<T>(BuildContext context, Widget child) {
  final wide = MediaQuery.sizeOf(context).width >= kWide;
  if (wide) {
    return showDialog<T>(
        context: context,
        builder: (_) => Dialog(
            backgroundColor: PT.card,
            insetPadding: const EdgeInsets.all(24),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            child: ConstrainedBox(
                constraints:
                    const BoxConstraints(maxWidth: 460, maxHeight: 760),
                child: child)));
  }
  return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      backgroundColor: PT.card,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (ctx) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
          child: ConstrainedBox(
              constraints: BoxConstraints(
                  maxHeight: MediaQuery.sizeOf(ctx).height * 0.9),
              child: child)));
}

void pitchSnack(BuildContext context, String text) =>
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        backgroundColor: PT.card2,
        content: Text(text, style: PT.inter(15, weight: FontWeight.w500))));

// ------------------------------------------------------------------ bits

class _Frame extends StatelessWidget {
  const _Frame(
      {required this.title,
      this.tag,
      this.subtitle = '',
      required this.children,
      required this.actions});

  final String title;
  final Widget? tag;
  final String subtitle;
  final List<Widget> children;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Flexible(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (tag != null) ...[tag!, const SizedBox(height: 8)],
              Text(title, style: PT.tight(21)),
              if (subtitle.isNotEmpty) ...[
                const SizedBox(height: 3),
                Text(subtitle, style: PT.inter(14, color: PT.muted)),
              ],
              const SizedBox(height: 10),
              ...children,
            ]),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
          child: Row(children: [
            for (var i = 0; i < actions.length; i++) ...[
              if (i > 0) const SizedBox(width: 8),
              Expanded(child: actions[i]),
            ]
          ]),
        ),
      ]),
    );
  }
}

class PitchTag extends StatelessWidget {
  const PitchTag(this.text, {super.key, this.colour = PT.amberText, this.bg});
  final String text;
  final Color colour;
  final Color? bg;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
            color: bg ?? colour.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(6)),
        child: Text(text,
            style: PT.inter(12, weight: FontWeight.w600, color: colour)),
      );
}

class PitchButton extends StatelessWidget {
  const PitchButton(this.label,
      {super.key,
      required this.onTap,
      this.accent,
      this.danger = false,
      this.compact = false});
  final String label;
  final VoidCallback? onTap;

  /// Filled in the club colour when set.
  final Color? accent;
  final bool danger;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final fill = accent;
    return Material(
      color: fill ?? PT.card2,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding:
              EdgeInsets.symmetric(horizontal: 14, vertical: compact ? 9 : 13),
          child: Center(
            child: Text(label,
                textAlign: TextAlign.center,
                style: PT.inter(compact ? 14 : 15,
                    weight: FontWeight.w600,
                    color: onTap == null
                        ? PT.muted
                        : fill != null
                            ? onAccent(fill)
                            : danger
                                ? PT.redText
                                : PT.text)),
          ),
        ),
      ),
    );
  }
}

class _Kv extends StatelessWidget {
  const _Kv(this.k, this.v);
  final String k;
  final String v;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: PT.line))),
        child: Row(children: [
          Text(k, style: PT.inter(15, color: PT.muted)),
          const SizedBox(width: 12),
          Expanded(
              child: Text(v,
                  textAlign: TextAlign.right,
                  style:
                      PT.inter(15, weight: FontWeight.w500, color: PT.text))),
        ]),
      );
}

InputDecoration pitchInput(String label, {String? hint}) => InputDecoration(
      labelText: label,
      hintText: hint,
      labelStyle: PT.inter(14, color: PT.muted),
      hintStyle: PT.inter(14, color: PT.muted),
      filled: true,
      fillColor: PT.bg,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: PT.line)),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: PT.line)),
    );

class _Chips<T> extends StatelessWidget {
  const _Chips(
      {required this.values,
      required this.label,
      required this.selected,
      required this.onPick,
      required this.accent});
  final List<T> values;
  final String Function(T) label;
  final T selected;
  final ValueChanged<T> onPick;
  final Color accent;
  @override
  Widget build(BuildContext context) =>
      Wrap(spacing: 6, runSpacing: 6, children: [
        for (final v in values)
          GestureDetector(
            onTap: () => onPick(v),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                  color: v == selected ? accent.withValues(alpha: 0.18) : PT.bg,
                  border: Border.all(color: v == selected ? accent : PT.line),
                  borderRadius: BorderRadius.circular(20)),
              child: Text(label(v),
                  style: PT.inter(13.5,
                      weight: FontWeight.w600,
                      color: v == selected ? accent : PT.text)),
            ),
          )
      ]);
}

String _when(DateTime s, [DateTime? e]) =>
    '${kWeekdays[s.weekday - 1]} ${s.day} ${kMonths[s.month - 1].substring(0, 3)} · '
    '${timeOf(s)}${e == null ? '' : '–${timeOf(e)}'}';

// ------------------------------------------------------------------ place

/// Pick a free pitch for an inbox item (or confirm a matched event).
class PlaceSheet extends StatefulWidget {
  const PlaceSheet(
      {super.key, required this.c, required this.item, this.pitch, this.at});
  final PitchController c;
  final PlaceItem item;

  /// Set when the item was dropped on a pitch.
  final Pitch? pitch;
  final DateTime? at;

  @override
  State<PlaceSheet> createState() => _PlaceSheetState();
}

class _PlaceSheetState extends State<PlaceSheet> {
  late int _minutes = widget.c.minutesFor(widget.item);
  PlaceOption? _picked;
  final _ref = TextEditingController();
  final _rooms = TextEditingController();

  List<PlaceOption> get _options {
    final b = widget.c.board!;
    final start = widget.at ?? widget.item.start;
    final all =
        b.optionsFor(start, _minutes, except: widget.item.request?.bookingId);
    if (widget.pitch != null) {
      // Dropped on a pitch: that pitch first, even if busy.
      final p = widget.pitch!;
      final mine = all.where((o) => o.pitch.pitchId == p.pitchId).toList();
      final rest = all.where((o) => o.pitch.pitchId != p.pitchId);
      final s = widget.at ?? widget.item.start;
      return [
        if (mine.isEmpty)
          PlaceOption(p, s, s.add(Duration(minutes: _minutes)), PitchPart.full)
        else
          ...mine,
        ...rest
      ];
    }
    final m = widget.item.matchedPitchId;
    if (m != null) {
      all.sort((a, b) => (a.pitch.pitchId == m ? 0 : 1)
          .compareTo(b.pitch.pitchId == m ? 0 : 1));
    }
    return all;
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.c;
    final item = widget.item;
    final accent = c.club.accent;
    final opts = _options;
    // The options are rebuilt on every build, so find the picked one again
    // by pitch, part and time rather than by identity.
    final pick = (_picked == null
            ? null
            : opts.where((o) => _same(o, _picked!)).firstOrNull) ??
        (opts.isEmpty ? null : opts.first);
    final b = c.board!;
    final busy = pick != null &&
        !b.isFree(pick.pitch, pick.start, pick.end, pick.part,
            except: item.request?.bookingId);
    return _Frame(
      tag: PitchTag(item.fixture != null
          ? 'Fixture · from league'
          : item.request != null
              ? 'Request'
              : item.matchedPitchId != null
                  ? 'Event · confirm its pitch'
                  : item.kind == 'match'
                      ? 'Match event'
                      : 'Event'),
      title: item.title,
      subtitle: item.subtitle,
      actions: [
        PitchButton(item.request != null ? 'Decline' : 'Not on our pitches',
            danger: true,
            onTap: c.busy
                ? null
                : () async {
                    final err = await c.offsite(item);
                    if (!context.mounted) return;
                    if (err != null) return pitchSnack(context, err);
                    Navigator.pop(context, true);
                  }),
        PitchButton(
            pick == null ? 'No free pitch' : 'Place on ${pick.pitch.name}',
            accent: pick == null ? null : accent,
            onTap: pick == null || c.busy
                ? null
                : () async {
                    final err = await c.place(
                        item, pick.pitch, pick.start, pick.end, pick.part,
                        referee: _ref.text.trim(), rooms: _rooms.text.trim());
                    if (!context.mounted) return;
                    if (err != null) return pitchSnack(context, err);
                    Navigator.pop(context, true);
                  }),
      ],
      children: [
        _Kv('When', _when(item.start)),
        Row(children: [
          Expanded(child: Text('Needs', style: PT.inter(15, color: PT.muted))),
          IconButton(
              onPressed: _minutes > 15
                  ? () => setState(() {
                        _minutes -= 5;
                        _picked = null;
                      })
                  : null,
              icon: const Icon(Icons.remove, color: PT.muted, size: 18)),
          Text('$_minutes min', style: PT.inter(15, weight: FontWeight.w600)),
          IconButton(
              onPressed: () => setState(() {
                    _minutes += 5;
                    _picked = null;
                  }),
              icon: const Icon(Icons.add, color: PT.muted, size: 18)),
        ]),
        const SizedBox(height: 6),
        Text(opts.isEmpty ? 'Nothing free that day' : 'Free pitches',
            style: PT.inter(15, weight: FontWeight.w600)),
        const SizedBox(height: 4),
        for (final o in opts.take(8))
          _OptionRow(
              option: o,
              selected: pick != null && _same(pick, o),
              accent: accent,
              onTap: () => setState(() => _picked = o)),
        if (busy)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
                'That part of ${pick.pitch.name} is already in use then.',
                style: PT.inter(14, color: PT.redText)),
          ),
        if (item.kind == 'match') ...[
          const SizedBox(height: 12),
          TextField(
              controller: _ref,
              style: PT.inter(15),
              decoration: pitchInput('Referee (optional)')),
          const SizedBox(height: 8),
          TextField(
              controller: _rooms,
              style: PT.inter(15),
              decoration:
                  pitchInput('Dressing rooms (optional)', hint: '1 & 2')),
        ],
        if (item.event != null) ...[
          const SizedBox(height: 10),
          Text(
              'The pitch goes onto the ${c.group(item.event!.teamName)} event, '
              'so coaches and parents see it.',
              style: PT.inter(13.5, color: PT.muted)),
        ],
      ],
    );
  }
}

bool _same(PlaceOption a, PlaceOption b) =>
    a.pitch.pitchId == b.pitch.pitchId &&
    a.part == b.part &&
    a.start == b.start;

class _OptionRow extends StatelessWidget {
  const _OptionRow(
      {required this.option,
      required this.selected,
      required this.accent,
      required this.onTap});
  final PlaceOption option;
  final bool selected;
  final Color accent;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final o = option;
    final half = o.part != PitchPart.full;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(top: 6),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
            color: selected ? accent.withValues(alpha: 0.12) : PT.bg,
            border: Border.all(color: selected ? accent : PT.line),
            borderRadius: BorderRadius.circular(12)),
        child: Row(children: [
          Container(
              width: 9,
              height: 9,
              decoration: BoxDecoration(
                  color: o.exact && !half ? PT.green : PT.amber,
                  shape: BoxShape.circle)),
          const SizedBox(width: 10),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(o.pitch.name, style: PT.inter(15, weight: FontWeight.w600)),
              Text(
                  [
                    o.pitch.venue,
                    PitchPart.label(o.part, o.pitch.split),
                    '${timeOf(o.start)}–${timeOf(o.end)}',
                    if (!o.exact) 'later slot',
                  ].where((s) => s.isNotEmpty).join(' · '),
                  style: PT.inter(13, color: PT.muted)),
            ]),
          ),
          if (selected) Icon(Icons.check_circle, color: accent, size: 20),
        ]),
      ),
    );
  }
}

// ------------------------------------------------------------------ edit

/// Edit or add a booking. [booking] null = a new booking on [pitch] at [at].
class BookingSheet extends StatefulWidget {
  const BookingSheet(
      {super.key,
      required this.c,
      this.booking,
      this.pitch,
      this.at,
      this.minutes,
      this.group});
  final PitchController c;
  final Booking? booking;

  /// Length preset for a new booking (e.g. the held slot tapped).
  final int? minutes;

  /// Preset when a group was dropped on an empty slot.
  final PitchGroup? group;
  final Pitch? pitch;
  final DateTime? at;

  @override
  State<BookingSheet> createState() => _BookingSheetState();
}

class _BookingSheetState extends State<BookingSheet> {
  late final Booking? b = widget.booking;
  late Pitch? _pitch = widget.c.board!.pitch(b?.pitchId) ?? widget.pitch;
  late int _part = b?.part ?? PitchPart.full;
  late String _kind = b?.kind ?? 'training';
  late DateTime _start = b?.start ?? widget.at ?? DateTime.now();
  late int _minutes = b == null
      ? widget.minutes ?? widget.c.board!.durations.training
      : b!.end.difference(b!.start).inMinutes;
  late int? _groupId = b?.groupId ?? widget.group?.groupId;
  late final _title = TextEditingController(text: b?.title ?? '');
  late final _ref = TextEditingController(text: b?.referee ?? '');
  late final _rooms = TextEditingController(text: b?.dressingRooms ?? '');
  late final _note = TextEditingController(text: b?.note ?? '');
  late final _time = TextEditingController(text: timeOf(_start));
  bool _following = true;

  bool get _fixedTime => b?.gameId != null;

  @override
  Widget build(BuildContext context) {
    final c = widget.c;
    final board = c.board!;
    final accent = c.club.accent;
    final linked = b?.eventId != null;
    final isNew = b == null;
    final end = _start.add(Duration(minutes: _minutes));
    final clash = _pitch != null &&
        !board.isFree(_pitch!, _start, end, _part, except: b?.bookingId);
    final groups = board.groups;
    final title = isNew ? 'New booking' : c.titleOf(b!);

    return _Frame(
      tag: isNew
          ? null
          : PitchTag(
              b!.gameId != null
                  ? 'Fixture'
                  : linked
                      ? 'Linked to the team event'
                      : b!.rolledFrom != null
                          ? 'Weekly slot'
                          : b!.kind == 'match'
                              ? 'Match'
                              : 'Booking',
              colour: linked ? PT.green : PT.amberText),
      title: title,
      subtitle: isNew ? '' : _when(b!.start, b!.end),
      actions: [
        if (!isNew)
          PitchButton('Remove',
              danger: true,
              onTap: c.busy
                  ? null
                  : () async {
                      final err = await c.deleteBooking(b!,
                          following: _following && b!.kind == 'training');
                      if (!context.mounted) return;
                      if (err != null) return pitchSnack(context, err);
                      Navigator.pop(context, true);
                    }),
        PitchButton(isNew ? 'Add booking' : 'Save',
            accent: accent,
            onTap: c.busy || _pitch == null
                ? null
                : () async {
                    if (isNew &&
                        _groupId == null &&
                        _title.text.trim().isEmpty) {
                      return pitchSnack(
                          context, 'Pick a group or type a name.');
                    }
                    final p = <String, dynamic>{
                      if (!isNew) 'booking_id': b!.bookingId,
                      'pitch_id': _pitch!.pitchId,
                      'part': _part,
                      'starts_at': isoLocal(_start),
                      'ends_at': isoLocal(end),
                      'kind': _kind,
                      'status': 'confirmed',
                      if (!linked) 'title': _title.text.trim(),
                      if (!linked) 'group_id': _groupId,
                      'note': _note.text.trim(),
                      if (_kind == 'match') 'referee': _ref.text.trim(),
                      if (_kind == 'match')
                        'dressing_rooms': _rooms.text.trim(),
                      'following': _following,
                    };
                    final err = await c.saveBooking(p);
                    if (!context.mounted) return;
                    if (err != null) return pitchSnack(context, err);
                    Navigator.pop(context, true);
                  }),
      ],
      children: [
        if (!linked) ...[
          DropdownButtonFormField<int?>(
            initialValue: _groupId,
            isExpanded: true,
            dropdownColor: PT.card2,
            style: PT.inter(15),
            decoration: pitchInput('Group'),
            items: [
              DropdownMenuItem<int?>(
                  value: null,
                  child: Text('No group (type a name)',
                      style: PT.inter(15, color: PT.muted))),
              for (final g in groups)
                DropdownMenuItem<int?>(
                    value: g.groupId,
                    child: Text(
                        g.teamName.isEmpty
                            ? g.name
                            : '${g.name}  ·  ${g.teamName}',
                        overflow: TextOverflow.ellipsis)),
            ],
            onChanged: (v) => setState(() => _groupId = v),
          ),
          const SizedBox(height: 8),
        ],
        if (isNew) ...[
          Text('What', style: PT.inter(14, color: PT.muted)),
          const SizedBox(height: 6),
          _Chips<String>(
              values: const ['training', 'match', 'other'],
              label: (k) => k[0].toUpperCase() + k.substring(1),
              selected: _kind,
              accent: accent,
              onPick: (k) => setState(() {
                    _kind = k;
                    _minutes = board.durations.minutesFor(k, null);
                  })),
          const SizedBox(height: 8),
        ],
        if (!linked)
          TextField(
              controller: _title,
              style: PT.inter(15),
              decoration: pitchInput(
                  _groupId == null ? 'Name' : 'Extra label (optional)',
                  hint: 'Nursery, All Stars, Schools…')),
        const SizedBox(height: 10),
        DropdownButtonFormField<int>(
          initialValue: _pitch?.pitchId,
          isExpanded: true,
          dropdownColor: PT.card2,
          style: PT.inter(15),
          decoration: pitchInput('Pitch'),
          items: [
            for (final p in board.pitches)
              DropdownMenuItem(
                  value: p.pitchId,
                  child: Text('${p.name}  ·  ${p.venue}',
                      overflow: TextOverflow.ellipsis)),
          ],
          onChanged: (v) => setState(() {
            _pitch = board.pitch(v);
            if (!PitchPart.options(_pitch?.split ?? 1).contains(_part)) {
              _part = PitchPart.full;
            }
          }),
        ),
        if ((_pitch?.split ?? 1) > 1) ...[
          const SizedBox(height: 10),
          _Chips<int>(
              values: PitchPart.options(_pitch!.split),
              label: (p) => PitchPart.label(p, _pitch!.split),
              selected: _part,
              accent: accent,
              onPick: (p) => setState(() => _part = p)),
        ],
        const SizedBox(height: 10),
        Row(children: [
          Expanded(
            child: TextField(
              controller: _time,
              enabled: !_fixedTime,
              style: PT.inter(15),
              decoration: pitchInput('Starts', hint: '18:40'),
              onChanged: (v) {
                final m = parseHhmm(v);
                if (m != null) setState(() => _start = atMinutes(_start, m));
              },
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
              onPressed:
                  _minutes > 15 ? () => setState(() => _minutes -= 5) : null,
              icon: const Icon(Icons.remove, color: PT.muted, size: 18)),
          Text('$_minutes min', style: PT.inter(15, weight: FontWeight.w600)),
          IconButton(
              onPressed: () => setState(() => _minutes += 5),
              icon: const Icon(Icons.add, color: PT.muted, size: 18)),
        ]),
        if (_pitch != null) ...[
          const SizedBox(height: 6),
          Text(
              '${kWeekdays[_start.weekday - 1]} ${timeOf(_start)}–${timeOf(end)}'
              '${_pitch!.slotAt(_start.weekday, minutesOf(_start)) == null ? ' · outside the club\'s slots' : ''}',
              style: PT.inter(13.5, color: PT.muted)),
        ],
        if (clash)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text('That part of ${_pitch!.name} is already in use then.',
                style: PT.inter(14, color: PT.redText)),
          ),
        if (_kind == 'match') ...[
          const SizedBox(height: 10),
          TextField(
              controller: _ref,
              style: PT.inter(15),
              decoration: pitchInput('Referee')),
          const SizedBox(height: 8),
          TextField(
              controller: _rooms,
              style: PT.inter(15),
              decoration: pitchInput('Dressing rooms', hint: '1 & 2')),
        ],
        const SizedBox(height: 8),
        TextField(
            controller: _note,
            style: PT.inter(15),
            decoration: pitchInput('Note (optional)')),
        if (!isNew && b!.kind == 'training') ...[
          const SizedBox(height: 12),
          Text('Weekly slot', style: PT.inter(14, color: PT.muted)),
          const SizedBox(height: 6),
          _Chips<bool>(
              values: const [true, false],
              label: (v) => v ? 'This and following weeks' : 'This week only',
              selected: _following,
              accent: accent,
              onPick: (v) => setState(() => _following = v)),
        ],
        if (linked) ...[
          const SizedBox(height: 10),
          Text(
              'The team\'s event shows this pitch. Moving the slot more than '
              '45 minutes from the event\'s time unlinks it, and the coach keeps their own time.',
              style: PT.inter(13, color: PT.muted)),
        ],
      ],
    );
  }
}

// ------------------------------------------------------------------ close

class ClosePitchSheet extends StatefulWidget {
  const ClosePitchSheet({super.key, required this.c, this.pitch});
  final PitchController c;
  final Pitch? pitch;
  @override
  State<ClosePitchSheet> createState() => _ClosePitchSheetState();
}

class _ClosePitchSheetState extends State<ClosePitchSheet> {
  late Pitch? _pitch = widget.pitch ??
      (widget.c.board!.pitches.isEmpty ? null : widget.c.board!.pitches.first);
  late DateTime _from = widget.c.day;
  late DateTime _to = widget.c.day;
  final _reason = TextEditingController(text: 'Waterlogged');

  Future<DateTime?> _date(DateTime d) => showDatePicker(
      context: context,
      initialDate: d,
      firstDate: DateTime(d.year - 1),
      lastDate: DateTime(d.year + 2));

  String _d(DateTime d) =>
      '${kWeekdays[d.weekday - 1]} ${d.day} ${kMonths[d.month - 1].substring(0, 3)}';

  @override
  Widget build(BuildContext context) {
    final c = widget.c;
    final board = c.board!;
    final affected = _pitch == null
        ? 0
        : board.bookings
            .where((b) =>
                b.pitchId == _pitch!.pitchId &&
                b.confirmed &&
                !dayOf(b.start).isBefore(_from) &&
                !dayOf(b.start).isAfter(_to))
            .length;
    return _Frame(
      title: 'Close a pitch',
      subtitle:
          'Bookings stay put so you can move them; the board shows the pitch shaded.',
      actions: [
        PitchButton('Cancel', onTap: () => Navigator.pop(context)),
        PitchButton('Close ${_pitch?.name ?? ''}',
            accent: c.club.accent,
            onTap: _pitch == null || c.busy
                ? null
                : () async {
                    final err = await c.closePitch(
                        _pitch!.pitchId, _from, _to, _reason.text.trim());
                    if (!context.mounted) return;
                    if (err != null) return pitchSnack(context, err);
                    Navigator.pop(context, true);
                  }),
      ],
      children: [
        DropdownButtonFormField<int>(
          initialValue: _pitch?.pitchId,
          isExpanded: true,
          dropdownColor: PT.card2,
          style: PT.inter(15),
          decoration: pitchInput('Pitch'),
          items: [
            for (final p in board.pitches)
              DropdownMenuItem(value: p.pitchId, child: Text(p.name)),
          ],
          onChanged: (v) => setState(() => _pitch = board.pitch(v)),
        ),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(
              child: PitchButton('From ${_d(_from)}', compact: true,
                  onTap: () async {
            final d = await _date(_from);
            if (d != null) {
              setState(() {
                _from = dayOf(d);
                if (_to.isBefore(_from)) _to = _from;
              });
            }
          })),
          const SizedBox(width: 8),
          Expanded(
              child:
                  PitchButton('To ${_d(_to)}', compact: true, onTap: () async {
            final d = await _date(_to);
            if (d != null && !dayOf(d).isBefore(_from)) {
              setState(() => _to = dayOf(d));
            }
          })),
        ]),
        const SizedBox(height: 10),
        TextField(
            controller: _reason,
            style: PT.inter(15),
            decoration: pitchInput('Reason')),
        const SizedBox(height: 10),
        Text(
            affected == 0
                ? 'Nothing booked on it this week.'
                : '$affected booking${affected == 1 ? '' : 's'} this week will need a new pitch.',
            style:
                PT.inter(14, color: affected == 0 ? PT.muted : PT.amberText)),
      ],
    );
  }
}
