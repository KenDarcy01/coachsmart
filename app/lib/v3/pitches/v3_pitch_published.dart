// v3 Pitch planner, the members' view: the week as the officer last
// published it (Ken, 2026-11-16), read-only. Day by day, pitch by pitch,
// with a search box to find your own group.
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
      this.rooms = ''});

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
      rooms: '${j['dressing_rooms'] ?? ''}');

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
        closures = [
          if (j['closures'] is List)
            for (final c in (j['closures'] as List).whereType<Map>())
              Closure.fromJson({...c, 'closure_id': 0})
        ];

  final DateTime? publishedAt;
  final Map<int, (String, String, int)> pitches;
  final List<PublishedBooking> bookings;
  final List<Closure> closures;
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
  String _find = '';

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
    final accent = widget.club.accent;
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

    final children = <Widget>[
      head,
      const SizedBox(height: 8),
      TextField(
        style: PT.inter(15),
        onChanged: (v) => setState(() => _find = v.trim().toLowerCase()),
        decoration: InputDecoration(
            hintText: 'Find your group (U14 Boys, Nursery…)',
            hintStyle: PT.inter(14, color: PT.muted),
            prefixIcon: const Icon(Icons.search, color: PT.muted),
            filled: true,
            fillColor: PT.card,
            isDense: true,
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none)),
      ),
      const SizedBox(height: 12),
    ];

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
            textAlign: TextAlign.center, style: PT.inter(15, color: PT.muted)),
      ));
    } else {
      for (var i = 0; i < 7; i++) {
        final day = _monday.add(Duration(days: i));
        final list = [
          for (final b in w.bookings)
            if (dayOf(b.start) == day &&
                (_find.isEmpty || b.name.toLowerCase().contains(_find)))
              b
        ]..sort((a, b) {
            final t = a.start.compareTo(b.start);
            return t != 0 ? t : a.pitchId.compareTo(b.pitchId);
          });
        final closed = [
          for (final c in w.closures)
            if (c.covers(day)) c
        ];
        if (list.isEmpty && closed.isEmpty) continue;
        children.add(Padding(
          padding: const EdgeInsets.fromLTRB(2, 10, 2, 6),
          child: Text(longDay(day).toUpperCase(),
              style: PT.inter(12.5,
                  weight: FontWeight.w700, color: accent, letterSpacing: 0.6)),
        ));
        for (final c in closed) {
          children.add(Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text(
                '${w.pitches[c.pitchId]?.$1 ?? 'A pitch'} closed${c.reason.isEmpty ? '' : ': ${c.reason}'}',
                style: PT.inter(13.5, color: PT.redText)),
          ));
        }
        children.add(Container(
          decoration: BoxDecoration(
              color: PT.card, borderRadius: BorderRadius.circular(14)),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Column(children: [
            for (var k = 0; k < list.length; k++) _row(w, list[k], k > 0),
          ]),
        ));
      }
      if (children.length == 4) {
        children.add(Padding(
          padding: const EdgeInsets.symmetric(vertical: 30),
          child: Text(
              _find.isEmpty
                  ? 'Nothing on the pitches this week.'
                  : 'No slots for "$_find" this week.',
              textAlign: TextAlign.center,
              style: PT.inter(15, color: PT.muted)),
        ));
      }
    }

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: ListView(
            padding: widget.padding ?? const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: children),
      ),
    );
  }

  Widget _row(PublishedWeek w, PublishedBooking b, bool line) {
    final p = w.pitches[b.pitchId];
    final col = codeColour(codeOf(b.code, name: b.name));
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
          border: line ? const Border(top: BorderSide(color: PT.line)) : null),
      child: Row(children: [
        SizedBox(
            width: 96,
            child: Text('${timeOf(b.start)}–${timeOf(b.end)}',
                style: PT.inter(13, color: PT.muted))),
        Container(
            width: 4,
            height: 34,
            margin: const EdgeInsets.only(right: 10),
            decoration: BoxDecoration(
                color: col, borderRadius: BorderRadius.circular(2))),
        Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(
                b.kind == 'match' && b.opposition.isNotEmpty
                    ? '${b.name} v ${b.opposition}'
                    : b.name,
                style: PT.inter(15, weight: FontWeight.w600)),
            Text(
                [
                  if (p != null) p.$1,
                  if (p != null && p.$2.isNotEmpty) p.$2,
                  if (p != null && p.$3 > 1 && b.part != PitchPart.full)
                    PitchPart.label(b.part, p.$3),
                  if (b.rooms.isNotEmpty) 'Rooms ${b.rooms}',
                  if (b.referee.isNotEmpty) 'Ref ${b.referee}',
                ].join(' · '),
                style: PT.inter(12.5, color: PT.muted)),
          ]),
        ),
      ]),
    );
  }
}
