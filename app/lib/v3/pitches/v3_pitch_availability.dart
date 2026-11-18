// v3 Pitch planner, Availability (Ken, 2026-11-16): each pitch's week as
// the club holds it. "Free" times are the slots the club holds (the sheet's
// Free cells); any other time is "Unavailable", shaded the same on every
// pitch. The admin changes them here, e.g.
// when the clocks change, instead of in the club's sheet.
import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'v3_pitch_theme.dart';
import 'v3_pitch_api.dart';
import 'v3_pitch_controller.dart';
import 'v3_pitch_models.dart';
import 'v3_pitch_sheets.dart';

class PitchAvailabilityView extends StatefulWidget {
  const PitchAvailabilityView({super.key, required this.c});
  final PitchController c;
  @override
  State<PitchAvailabilityView> createState() => _PitchAvailabilityViewState();
}

class _PitchAvailabilityViewState extends State<PitchAvailabilityView> {
  List<Pitch> _pitches = const [];
  List<(int, PitchBlock)> _blocks = const [];
  int? _pitchId;
  String? _error;
  bool _loaded = false;
  bool _busy = false;

  PitchController get c => widget.c;
  PitchApi get api => c.api;
  int get club => c.club.clubId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final s = await api.setup(club);
      final b = await api.blocks(club);
      if (!mounted) return;
      setState(() {
        _pitches = s.pitches;
        _blocks = b;
        _error = null;
        _loaded = true;
        if (_pitches.isNotEmpty &&
            !_pitches.any((p) => p.pitchId == _pitchId)) {
          _pitchId = _pitches.first.pitchId;
        }
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = pitchErrorText(e);
          _loaded = true;
        });
      }
    }
  }

  Pitch? get _pitch {
    for (final p in _pitches) {
      if (p.pitchId == _pitchId) return p;
    }
    return null;
  }

  List<PitchBlock> _blocksOf(int pitchId) => [
        for (final (id, b) in _blocks)
          if (id == pitchId) b
      ];

  Future<void> _edit(Pitch p, int weekday,
      {PitchSlot? slot, PitchBlock? block}) async {
    final res = await showPitchSheet<_Change>(
        context,
        _TimeSheet(
            accent: c.club.accent,
            pitch: p.name,
            hourly: p.surface == 'grass',
            weekday: weekday,
            slot: slot,
            block: block));
    if (res == null) return;
    var slots = [...p.slots];
    var blocks = _blocksOf(p.pitchId);
    // An edit replaces what was tapped.
    if (slot != null) slots.remove(slot);
    if (block != null) blocks.remove(block);
    if (!res.delete) {
      bool overlaps(PitchSlot a, int d) =>
          a.weekday == d && a.opens < res.to && res.from < a.closes;
      for (final d in res.days) {
        if (res.free) {
          slots = [
            for (final s in slots)
              if (!overlaps(s, d)) s,
            if (res.each <= 0)
              PitchSlot(d, res.from, res.to)
            else
              for (var m = res.from; m + res.each <= res.to; m += res.each)
                PitchSlot(d, m, m + res.each),
          ];
        } else {
          blocks = [
            for (final b in blocks)
              if (!overlaps(b.slot, d)) b,
            PitchBlock(PitchSlot(d, res.from, res.to), res.reason),
          ];
        }
      }
    }
    final slotsChanged = slot != null || res.free;
    final blocksChanged = block != null || (!res.delete && !res.free);
    setState(() => _busy = true);
    try {
      if (slotsChanged) {
        await api.savePitch(club, p.copyWith(slots: slots).toJson());
      }
      if (blocksChanged) await api.saveBlocks(club, p.pitchId, blocks);
      await _load();
      c.load(force: true);
      if (mounted) pitchSnack(context, '${p.name} saved.');
    } catch (e) {
      if (mounted) pitchSnack(context, pitchErrorText(e));
    }
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) {
      return Center(child: CircularProgressIndicator(color: PT.muted));
    }
    if (_error != null) {
      return Center(
          child: Text(_error!,
              textAlign: TextAlign.center,
              style: PT.inter(15, color: PT.muted)));
    }
    if (_pitches.isEmpty) {
      return Center(
          child: Text('Add pitches under Pitches and venues first.',
              style: PT.inter(15, color: PT.muted)));
    }
    final accent = c.club.accent;
    final p = _pitch!;
    final astros = [
      for (final x in _pitches)
        if (x.surface == 'astro') x
    ];
    final others = [
      for (final x in _pitches)
        if (x.surface != 'astro') x
    ];
    Widget group(String label, List<Pitch> list) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SizedBox(
                width: 64,
                child: Padding(
                  padding: const EdgeInsets.only(top: 7),
                  child: Text(label, style: PT.inter(13, color: PT.muted)),
                )),
            Expanded(
              child: Wrap(spacing: 6, runSpacing: 6, children: [
                for (final x in list)
                  _Pill(
                      label: x.name,
                      on: x.pitchId == _pitchId,
                      accent: accent,
                      onTap: () => setState(() => _pitchId = x.pitchId)),
              ]),
            ),
          ]),
        );
    final blocks = _blocksOf(p.pitchId);
    final phone = MediaQuery.sizeOf(context).width < kWide;
    return ListView(
        padding: EdgeInsets.fromLTRB(
            phone ? 14 : 0, phone ? 12 : 0, phone ? 14 : 0, 24),
        children: [
          Text(
              'Free times are the slots the club holds. Any other time is '
              'unavailable, shaded the same on every pitch. Tap a time to change it, or + to add one. '
              'Update them here when the clocks change.',
              style: PT.inter(14, color: PT.muted)),
          const SizedBox(height: 12),
          if (astros.isNotEmpty) group('Astros', astros),
          if (others.isNotEmpty) group('Grass', others),
          const SizedBox(height: 6),
          Container(
            decoration: BoxDecoration(
                color: PT.card,
                border: Border.all(color: PT.line),
                borderRadius: BorderRadius.circular(14)),
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 4),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(children: [
                    Expanded(child: Text(p.name, style: PT.tight(19))),
                    if (_busy)
                      SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: PT.muted)),
                  ]),
                  const SizedBox(height: 4),
                  Row(children: [
                    const _Key(free: true),
                    Text(' Free   ', style: PT.inter(12.5, color: PT.muted)),
                    const _Key(free: false),
                    Text(' Unavailable',
                        style: PT.inter(12.5, color: PT.muted)),
                  ]),
                  const SizedBox(height: 6),
                  for (var d = 1; d <= 7; d++)
                    _DayRow(
                      weekday: d,
                      astro: true,
                      slots: [
                        for (final s in p.slots)
                          if (s.weekday == d) s
                      ]..sort((a, b) => a.opens.compareTo(b.opens)),
                      blocks: [
                        for (final b in blocks)
                          if (b.slot.weekday == d) b
                      ]..sort((a, b) => a.slot.opens.compareTo(b.slot.opens)),
                      accent: accent,
                      onAdd: _busy ? null : () => _edit(p, d),
                      onSlot: _busy ? null : (s) => _edit(p, d, slot: s),
                      onBlock: _busy ? null : (b) => _edit(p, d, block: b),
                    ),
                ]),
          ),
        ]);
  }
}

class _Pill extends StatelessWidget {
  const _Pill(
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
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
          decoration: BoxDecoration(
              color: on ? accent.withValues(alpha: 0.16) : PT.card,
              border: Border.all(color: on ? accent : PT.line),
              borderRadius: BorderRadius.circular(18)),
          child: Text(label,
              style: PT.inter(13,
                  weight: FontWeight.w600, color: on ? accent : PT.text)),
        ),
      );
}

class _Key extends StatelessWidget {
  const _Key({required this.free});
  final bool free;
  @override
  Widget build(BuildContext context) => Container(
        width: 12,
        height: 12,
        decoration: BoxDecoration(
            color: free ? PT.greenTint : null,
            border: Border.all(color: free ? PT.green : PT.faint),
            borderRadius: BorderRadius.circular(3)),
        child: free ? null : const CustomPaint(painter: _Hatch()),
      );
}

const _dayStart = 8 * 60, _dayEnd = 22 * 60;

class _DayRow extends StatelessWidget {
  const _DayRow(
      {required this.weekday,
      this.astro = false,
      required this.slots,
      required this.blocks,
      required this.accent,
      required this.onAdd,
      required this.onSlot,
      required this.onBlock});
  final int weekday;

  /// Shade time outside the held slots as unavailable.
  final bool astro;
  final List<PitchSlot> slots;
  final List<PitchBlock> blocks;
  final Color accent;
  final VoidCallback? onAdd;
  final ValueChanged<PitchSlot>? onSlot;
  final ValueChanged<PitchBlock>? onBlock;

  @override
  Widget build(BuildContext context) {
    final start = math.min(
        _dayStart,
        [...slots.map((s) => s.opens), ...blocks.map((b) => b.slot.opens)]
            .fold(_dayStart, math.min));
    final end = math.max(
        _dayEnd,
        [...slots.map((s) => s.closes), ...blocks.map((b) => b.slot.closes)]
            .fold(_dayEnd, math.max));
    final span = (end - start).toDouble();
    Widget chip(String text, bool free, VoidCallback? tap) => GestureDetector(
          onTap: tap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
                color: free ? PT.greenTint : PT.card2,
                border: Border.all(
                    color: free ? PT.green.withValues(alpha: 0.4) : PT.line),
                borderRadius: BorderRadius.circular(8)),
            child: Text(text,
                style: PT.inter(12.5,
                    weight: FontWeight.w600,
                    color: free ? PT.green : PT.muted)),
          ),
        );
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration:
          BoxDecoration(border: Border(top: BorderSide(color: PT.line))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          SizedBox(
              width: 40,
              child: Text(kWeekdays[weekday - 1],
                  style: PT.inter(14, weight: FontWeight.w600))),
          Expanded(
            child: LayoutBuilder(builder: (context, box) {
              double x(int m) => (m - start) / span * box.maxWidth;
              return SizedBox(
                height: 22,
                child: Stack(children: [
                  Positioned.fill(
                      child: Container(
                          decoration: BoxDecoration(
                              color: PT.slot,
                              border: Border.all(color: PT.slotLine),
                              borderRadius: BorderRadius.circular(5)))),
                  for (final b in [
                    ...blocks,
                    if (astro && slots.isNotEmpty)
                      ...noSlotGaps(slots, blocks, weekday)
                  ])
                    Positioned(
                        left: x(b.slot.opens),
                        width: x(b.slot.closes) - x(b.slot.opens),
                        top: 0,
                        bottom: 0,
                        child: const CustomPaint(painter: _Hatch())),
                  for (final s in slots)
                    Positioned(
                        left: x(s.opens) + 0.5,
                        width: math.max(1, x(s.closes) - x(s.opens) - 1),
                        top: 2,
                        bottom: 2,
                        child: Container(
                            decoration: BoxDecoration(
                                color: PT.green.withValues(alpha: 0.55),
                                borderRadius: BorderRadius.circular(3)))),
                ]),
              );
            }),
          ),
          IconButton(
              tooltip: 'Add a time',
              visualDensity: VisualDensity.compact,
              onPressed: onAdd,
              icon: Icon(Icons.add_circle_outline, color: accent, size: 22)),
        ]),
        Padding(
          padding: const EdgeInsets.only(left: 40, top: 4, right: 40),
          child: Row(children: [
            Text(hhmm(start), style: PT.inter(10.5, color: PT.faint)),
            const Spacer(),
            Text(hhmm(end), style: PT.inter(10.5, color: PT.faint)),
          ]),
        ),
        const SizedBox(height: 4),
        if (slots.isEmpty && blocks.isEmpty)
          Padding(
            padding: const EdgeInsets.only(left: 40),
            child: Text('Nothing set', style: PT.inter(13, color: PT.faint)),
          )
        else
          Padding(
            padding: const EdgeInsets.only(left: 40),
            child: Wrap(spacing: 6, runSpacing: 6, children: [
              for (final s in slots)
                chip(s.label, true, onSlot == null ? null : () => onSlot!(s)),
              for (final b in blocks)
                chip('${b.slot.label} · Unavailable', false,
                    onBlock == null ? null : () => onBlock!(b)),
            ]),
          ),
      ]),
    );
  }
}

class _Change {
  const _Change(
      {required this.free,
      required this.from,
      required this.to,
      required this.days,
      this.each = 0,
      this.reason = 'Unavailable',
      this.delete = false});
  final bool free;
  final int from;
  final int to;
  final Set<int> days;
  final int each;
  final String reason;
  final bool delete;
}

/// Add or change one time on a pitch, on one or more days.
class _TimeSheet extends StatefulWidget {
  const _TimeSheet(
      {required this.accent,
      required this.pitch,
      this.hourly = false,
      required this.weekday,
      this.slot,
      this.block});
  final Color accent;
  final String pitch;

  /// Grass slots default to on the hour, an hour each (Ken, 2026-11-16).
  final bool hourly;
  final int weekday;
  final PitchSlot? slot;
  final PitchBlock? block;
  @override
  State<_TimeSheet> createState() => _TimeSheetState();
}

class _TimeSheetState extends State<_TimeSheet> {
  late bool _free = widget.block == null;
  late final _from = TextEditingController(
      text: hhmm(widget.slot?.opens ?? widget.block?.slot.opens ?? 18 * 60));
  late final _to = TextEditingController(
      text: hhmm(widget.slot?.closes ?? widget.block?.slot.closes ?? 19 * 60));
  late final _each =
      TextEditingController(text: widget.hourly && !_editing ? '60' : '');
  late final Set<int> _days = {widget.weekday};
  String? _problem;

  bool get _editing => widget.slot != null || widget.block != null;

  void _save() {
    final a = parseHhmm(_from.text), b = parseHhmm(_to.text);
    if (a == null || b == null || b <= a) {
      setState(
          () => _problem = 'Enter times like 18:00, ending after the start.');
      return;
    }
    final each = int.tryParse(_each.text.trim()) ?? 0;
    Navigator.pop(
        context,
        _Change(
            free: _free,
            from: a,
            to: b,
            days: _days,
            each: _free ? each : 0,
            reason: 'Unavailable'));
  }

  @override
  Widget build(BuildContext context) {
    final accent = widget.accent;
    Widget pill(String label, bool on, VoidCallback tap) =>
        _Pill(label: label, on: on, accent: accent, onTap: () => setState(tap));
    return SafeArea(
      top: false,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Flexible(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${widget.pitch}, ${kDayNames[widget.weekday - 1]}',
                  style: PT.tight(20)),
              const SizedBox(height: 12),
              Wrap(spacing: 6, children: [
                pill('Free', _free, () => _free = true),
                pill('Unavailable', !_free, () => _free = false),
              ]),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(
                    child: TextField(
                        controller: _from,
                        style: PT.inter(15),
                        decoration: pitchInput('From', hint: '18:00'))),
                const SizedBox(width: 8),
                Expanded(
                    child: TextField(
                        controller: _to,
                        style: PT.inter(15),
                        decoration: pitchInput('To', hint: '19:00'))),
              ]),
              const SizedBox(height: 8),
              if (_free) ...[
                TextField(
                    controller: _each,
                    keyboardType: TextInputType.number,
                    style: PT.inter(15),
                    decoration: pitchInput('Split into slots of (minutes)',
                        hint: 'Leave empty for one slot, e.g. 50 or 60')),
              ] else
                Text(
                    'Use this to block time inside a slot or to mark a whole '
                    'day, e.g. weekdays on grass.',
                    style: PT.inter(13, color: PT.faint)),
              const SizedBox(height: 12),
              Text(_editing ? 'Also set it on' : 'Days',
                  style: PT.inter(14, color: PT.muted)),
              const SizedBox(height: 6),
              Wrap(spacing: 6, runSpacing: 6, children: [
                for (var d = 1; d <= 7; d++)
                  pill(kWeekdays[d - 1], _days.contains(d), () {
                    if (d == widget.weekday) return;
                    _days.contains(d) ? _days.remove(d) : _days.add(d);
                  }),
                pill('Mon–Fri', false, () => _days.addAll([1, 2, 3, 4, 5])),
              ]),
              const SizedBox(height: 8),
              Text('Anything it overlaps on those days is replaced.',
                  style: PT.inter(13, color: PT.faint)),
              if (_problem != null) ...[
                const SizedBox(height: 8),
                Text(_problem!, style: PT.inter(13.5, color: PT.redText)),
              ],
            ]),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
          child: Row(children: [
            if (_editing) ...[
              Expanded(
                  child: PitchButton('Remove',
                      danger: true,
                      onTap: () => Navigator.pop(
                          context,
                          const _Change(
                              free: true,
                              from: 0,
                              to: 0,
                              days: {},
                              delete: true)))),
              const SizedBox(width: 8),
            ],
            Expanded(
                child:
                    PitchButton('Cancel', onTap: () => Navigator.pop(context))),
            const SizedBox(width: 8),
            Expanded(child: PitchButton('Save', accent: accent, onTap: _save)),
          ]),
        ),
      ]),
    );
  }
}

class _Hatch extends CustomPainter {
  const _Hatch();
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
        Offset.zero & size,
        Paint()
          ..color =
              PT.dark ? const Color(0xFF1A1E24) : const Color(0xFFE9EBEF));
    final line = Paint()
      ..color = PT.dark ? const Color(0xFF2E333E) : const Color(0xFFCDD1D7)
      ..strokeWidth = 1;
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    for (var x = -size.height; x < size.width; x += 6) {
      canvas.drawLine(Offset(x, size.height), Offset(x + size.height, 0), line);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _Hatch oldDelegate) => false;
}
