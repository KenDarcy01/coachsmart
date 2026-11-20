// v3 Pitch planner, Insights tab (Ken, 2026-11-20): how well the club's
// pitches are used over time, the busiest times, closures, teams' training
// and what unused rented slots cost. One call: pitch_insights. Minutes
// throughout; a half-pitch booking counts half. Data starts 16 Nov 2026.
import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'v3_pitch_api.dart';
import 'v3_pitch_controller.dart';
import 'v3_pitch_models.dart';
import 'v3_pitch_sheets.dart';
import 'v3_pitch_theme.dart';

/// Validated categorical pair (blue, orange), stepped per surface.
Color get _astroCol =>
    PT.dark ? const Color(0xFF3987E5) : const Color(0xFF2A78D6);
Color get _grassCol =>
    PT.dark ? const Color(0xFFD95926) : const Color(0xFFEB6834);

class InsPitch {
  InsPitch.fromJson(Map j)
      : id = int.tryParse('${j['pitch_id']}') ?? 0,
        name = '${j['name'] ?? ''}',
        venue = '${j['venue'] ?? ''}',
        astro = '${j['surface']}' != 'grass',
        rented = j['rented'] == true,
        cost = double.tryParse('${j['cost']}');
  final int id;
  final String name, venue;
  final bool astro, rented;
  final double? cost;
}

/// Held, booked and closed minutes.
class Mins {
  int held = 0, booked = 0, closed = 0;
  void add(Map j) {
    held += _i(j['held']);
    booked += _i(j['booked']);
    closed += _i(j['closed']);
  }

  int get open => math.max(0, held - closed);
  int get used => math.min(booked, open);
  int get free => math.max(0, open - used);
  double? get rate => open == 0 ? null : used / open;
}

int _i(Object? v) => (num.tryParse('$v') ?? 0).round();
String _h(int mins) {
  final h = mins / 60;
  return h >= 10 || h == h.roundToDouble()
      ? '${h.round()} h'
      : '${h.toStringAsFixed(1)} h';
}

String _pc(double? r) => r == null ? '–' : '${(r * 100).round()}%';

enum InsRange { last4, next4, year }

class PitchInsightsView extends StatefulWidget {
  const PitchInsightsView({super.key, required this.c});
  final PitchController c;
  @override
  State<PitchInsightsView> createState() => _PitchInsightsViewState();
}

class _PitchInsightsViewState extends State<PitchInsightsView> {
  PitchController get c => widget.c;
  InsRange _range = InsRange.last4;
  Map? _d;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  (DateTime, DateTime) get _period {
    final t = c.today;
    return switch (_range) {
      InsRange.last4 => (t.subtract(const Duration(days: 27)), t),
      InsRange.next4 => (t, t.add(const Duration(days: 27))),
      InsRange.year => (DateTime(t.year, 1, 1), t),
    };
  }

  Future<void> _load() async {
    final (f, t) = _period;
    setState(() {
      _d = null;
      _error = null;
    });
    try {
      final r = await c.api.insights(c.club.clubId, f, t);
      if (mounted) setState(() => _d = r);
    } catch (e) {
      if (mounted) setState(() => _error = pitchErrorText(e));
    }
  }

  Future<void> _editCost(InsPitch p) async {
    final ctl = TextEditingController(
        text: p.cost == null ? '' : p.cost!.toStringAsFixed(2));
    final ok = await showPitchSheet<bool>(
        context,
        Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('${p.name}: cost per hour', style: PT.tight(20)),
                const SizedBox(height: 6),
                Text(
                    'What the club pays for one hour of a slot. Leave empty if it isn\'t paid for.',
                    style: PT.inter(14, color: PT.muted)),
                const SizedBox(height: 12),
                TextField(
                    controller: ctl,
                    autofocus: true,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    style: PT.inter(16),
                    decoration: pitchInput('€ per hour')),
                const SizedBox(height: 14),
                Row(children: [
                  Expanded(
                      child: PitchButton('Cancel',
                          onTap: () => Navigator.pop(context, false))),
                  const SizedBox(width: 8),
                  Expanded(
                      child: PitchButton('Save',
                          accent: c.club.accent,
                          onTap: () => Navigator.pop(context, true))),
                ]),
              ]),
        ));
    if (ok != true) return;
    final v = double.tryParse(ctl.text.replaceAll('€', '').trim());
    try {
      await c.api.saveCost(c.club.clubId, p.id, v);
      _load();
    } catch (e) {
      if (mounted) pitchSnack(context, pitchErrorText(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final accent = c.club.accent;
    final d = _d;
    Widget chip(InsRange r, String label) => Padding(
          padding: const EdgeInsets.only(right: 6),
          child: ChoiceChip(
            label: Text(label,
                style: PT.inter(13.5,
                    weight: FontWeight.w600,
                    color: _range == r ? onAccent(accent) : PT.text)),
            selected: _range == r,
            selectedColor: accent,
            backgroundColor: PT.card,
            showCheckmark: false,
            side: BorderSide(color: _range == r ? accent : PT.line),
            onSelected: (_) {
              setState(() => _range = r);
              _load();
            },
          ),
        );
    final (f, t) = _period;
    final head = Wrap(
        spacing: 0,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          chip(InsRange.last4, 'Last 4 weeks'),
          chip(InsRange.next4, 'Next 4 weeks'),
          chip(InsRange.year, 'This year'),
          const SizedBox(width: 8),
          Text(
              '${f.day} ${kMonths[f.month - 1].substring(0, 3)} – '
              '${t.day} ${kMonths[t.month - 1].substring(0, 3)} · '
              'from 16 Nov, when the planner started',
              style: PT.inter(13, color: PT.muted)),
        ]);
    if (_error != null || d == null) {
      return ListView(padding: const EdgeInsets.all(4), children: [
        head,
        Padding(
          padding: const EdgeInsets.all(40),
          child: Center(
              child: _error != null
                  ? Text(_error!, style: PT.inter(15, color: PT.muted))
                  : CircularProgressIndicator(color: PT.muted)),
        ),
      ]);
    }

    final pitches = [
      if (d['pitches'] is List)
        for (final x in (d['pitches'] as List).whereType<Map>())
          InsPitch.fromJson(x)
    ];
    final byId = {for (final p in pitches) p.id: p};
    final weeks = [
      if (d['weeks'] is List) ...(d['weeks'] as List).whereType<Map>()
    ];
    final total = Mins(), astro = Mins(), grass = Mins();
    final perPitch = <int, Mins>{};
    final perWeek = <String, (Mins, Mins)>{};
    for (final w in weeks) {
      final p = byId[_i(w['pitch_id'])];
      if (p == null) continue;
      total.add(w);
      (p.astro ? astro : grass).add(w);
      perPitch.putIfAbsent(p.id, Mins.new).add(w);
      final k = '${w['week']}';
      final pair = perWeek.putIfAbsent(k, () => (Mins(), Mins()));
      (p.astro ? pair.$1 : pair.$2).add(w);
    }
    final closures = [
      if (d['closures'] is List) ...(d['closures'] as List).whereType<Map>()
    ];
    final kinds = d['kinds'] is Map ? d['kinds'] as Map : const {};
    final closedDays = closures.fold<int>(0, (a, x) => a + _i(x['days']));
    final wide = MediaQuery.sizeOf(context).width >= kWide;

    // Unused paid time: rented pitches with a cost.
    var unusedSpend = 0.0, paidSpend = 0.0;
    for (final p in pitches) {
      final m = perPitch[p.id];
      if (p.cost == null || m == null) continue;
      unusedSpend += m.free / 60 * p.cost!;
      paidSpend += m.held / 60 * p.cost!;
    }

    final tiles = [
      _tile('Utilisation', _pc(total.rate),
          '${_h(total.used)} of ${_h(total.open)} held'),
      _tile('Astros', _pc(astro.rate), '${_h(astro.used)} booked'),
      _tile('Grass', _pc(grass.rate), '${_h(grass.used)} booked'),
      _tile(
          'Closures',
          '${closures.length}',
          closures.isEmpty
              ? 'None'
              : '$closedDays pitch-day${closedDays == 1 ? '' : 's'} lost'),
      _tile('Home matches', '${_i(kinds['matches'])}', 'on our pitches'),
      _tile('Training', _h(_i(kinds['training_min'])),
          '${_i(kinds['training'])} sessions'),
      if (paidSpend > 0)
        _tile('Unused paid slots', '€${unusedSpend.round()}',
            'of €${paidSpend.round()} rented'),
    ];

    final sections = <Widget>[
      _card(
          'Utilisation by week',
          'Booked share of usable time. Unavailable and closed time don\'t count.',
          _WeekChart(weeks: perWeek)),
      _card(
          'Busiest times',
          'Hours booked across all pitches, by day and hour. Darker is busier.',
          _Heat(cells: [
            if (d['heat'] is List) ...(d['heat'] as List).whereType<Map>()
          ])),
      _card(
          'Each pitch',
          'Booked, free and closed hours of usable time. Unavailable times are left out.',
          _pitchBars(pitches, perPitch)),
      _card(
          'Rented pitches',
          'Set what the club pays per hour to see the cost of slots nobody used.',
          _rented(pitches, perPitch)),
      _card('Closures', '', _closures(closures, byId)),
      _card('Teams', 'Training sessions on our pitches in this period.',
          _teams(d)),
    ];

    return ListView(padding: const EdgeInsets.only(bottom: 30), children: [
      head,
      const SizedBox(height: 14),
      Wrap(spacing: 10, runSpacing: 10, children: tiles),
      const SizedBox(height: 14),
      if (wide)
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
              child: Column(children: [sections[0], sections[2], sections[4]])),
          const SizedBox(width: 14),
          Expanded(
              child: Column(children: [sections[1], sections[3], sections[5]])),
        ])
      else
        ...sections,
    ]);
  }

  Widget _tile(String label, String value, String sub) => Container(
        width: 170,
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        decoration: BoxDecoration(
            color: PT.card,
            border: Border.all(color: PT.line),
            borderRadius: BorderRadius.circular(12)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: PT.inter(13, color: PT.muted)),
          const SizedBox(height: 4),
          Text(value, style: PT.tight(26)),
          Text(sub,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: PT.inter(12.5, color: PT.muted)),
        ]),
      );

  Widget _card(String title, String sub, Widget child) => Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
        decoration: BoxDecoration(
            color: PT.card,
            border: Border.all(color: PT.line),
            borderRadius: BorderRadius.circular(12)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: PT.inter(16, weight: FontWeight.w700)),
          if (sub.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(sub, style: PT.inter(13, color: PT.muted)),
            ),
          const SizedBox(height: 12),
          child,
        ]),
      );

  Widget _pitchBars(List<InsPitch> pitches, Map<int, Mins> per) {
    Widget seg(int mins, int total, Color col, String tip) => mins <= 0
        ? const SizedBox.shrink()
        : Expanded(
            flex: math.max(1, (mins * 1000 / math.max(1, total)).round()),
            child: Tooltip(
              message: tip,
              child: Container(
                  height: 14,
                  margin: const EdgeInsets.only(right: 2),
                  decoration: BoxDecoration(
                      color: col, borderRadius: BorderRadius.circular(4))),
            ),
          );
    return Column(children: [
      for (final p in pitches)
        if ((per[p.id]?.held ?? 0) > 0)
          Builder(builder: (_) {
            final m = per[p.id]!;
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(children: [
                SizedBox(
                    width: 120,
                    child: Text(p.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: PT.inter(13.5, weight: FontWeight.w600))),
                Expanded(
                  child: Row(children: [
                    seg(m.used, m.held, p.astro ? _astroCol : _grassCol,
                        '${p.name}: ${_h(m.used)} booked'),
                    seg(m.free, m.held, PT.card2,
                        '${p.name}: ${_h(m.free)} free'),
                    seg(m.closed, m.held, PT.redText.withValues(alpha: 0.5),
                        '${p.name}: ${_h(m.closed)} closed'),
                  ]),
                ),
                SizedBox(
                    width: 52,
                    child: Text(_pc(m.rate),
                        textAlign: TextAlign.right,
                        style: PT.inter(13.5, weight: FontWeight.w600))),
              ]),
            );
          }),
      Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Wrap(spacing: 14, runSpacing: 6, children: [
          _key(_astroCol, 'Booked, astro'),
          _key(_grassCol, 'Booked, grass'),
          _key(PT.card2, 'Free'),
          _key(PT.redText.withValues(alpha: 0.5), 'Closed'),
        ]),
      ),
    ]);
  }

  Widget _rented(List<InsPitch> pitches, Map<int, Mins> per) {
    final rented = [
      for (final p in pitches)
        if (p.rented) p
    ];
    if (rented.isEmpty) {
      return Text(
          'No rented pitches. Mark a venue as rented in Pitches and venues.',
          style: PT.inter(14, color: PT.muted));
    }
    return Column(children: [
      for (final p in rented)
        Builder(builder: (_) {
          final m = per[p.id] ?? Mins();
          return InkWell(
            onTap: () => _editCost(p),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(children: [
                Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(p.name,
                            style: PT.inter(14.5, weight: FontWeight.w600)),
                        Text(
                            p.cost == null
                                ? 'Tap to set the cost per hour'
                                : '€${p.cost!.toStringAsFixed(p.cost! % 1 == 0 ? 0 : 2)} an hour · '
                                    '${_h(m.held)} held, ${_h(m.free)} unused',
                            style: PT.inter(12.5, color: PT.muted)),
                      ]),
                ),
                if (p.cost != null)
                  Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    Text('€${(m.free / 60 * p.cost!).round()}',
                        style: PT.inter(15, weight: FontWeight.w700)),
                    Text('unused', style: PT.inter(12, color: PT.muted)),
                  ])
                else
                  Icon(Icons.edit_outlined, size: 18, color: PT.muted),
              ]),
            ),
          );
        }),
    ]);
  }

  Widget _closures(List<Map> list, Map<int, InsPitch> byId) {
    if (list.isEmpty) {
      return Text('No pitch was closed in this period.',
          style: PT.inter(14, color: PT.muted));
    }
    // Per pitch: how many times and days.
    final count = <int, (int, int)>{};
    for (final x in list) {
      final id = _i(x['pitch_id']);
      final (n, dd) = count[id] ?? (0, 0);
      count[id] = (n + 1, dd + _i(x['days']));
    }
    String d(String iso) {
      final t = DateTime.tryParse(iso);
      return t == null
          ? ''
          : '${t.day} ${kMonths[t.month - 1].substring(0, 3)}';
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Wrap(spacing: 6, runSpacing: 6, children: [
        for (final e in count.entries)
          PitchTag(
              '${byId[e.key]?.name ?? 'Pitch'}: ${e.value.$1}× · ${e.value.$2} day${e.value.$2 == 1 ? '' : 's'}',
              colour: PT.redText,
              bg: PT.redTint),
      ]),
      const SizedBox(height: 8),
      for (final x in list.take(12))
        Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration:
              BoxDecoration(border: Border(top: BorderSide(color: PT.line))),
          child: Row(children: [
            SizedBox(
                width: 120,
                child: Text(
                    '${d('${x['starts_on']}')}'
                    '${x['starts_on'] == x['ends_on'] ? '' : '–${d('${x['ends_on']}')}'}',
                    style: PT.inter(13.5, weight: FontWeight.w600))),
            Expanded(
                child: Text(
                    '${byId[_i(x['pitch_id'])]?.name ?? ''}'
                    '${'${x['reason']}'.isEmpty ? '' : ' · ${x['reason']}'}',
                    style: PT.inter(13.5))),
            if (_i(x['still_on']) > 0)
              Text('${_i(x['still_on'])} still booked on it',
                  style: PT.inter(12.5, color: PT.redText)),
          ]),
        ),
    ]);
  }

  Widget _teams(Map d) {
    final weeks = math.max(
        1, ((_period.$2.difference(_period.$1).inDays + 1) / 7).round());
    final groups = [
      if (d['groups'] is List)
        for (final g in (d['groups'] as List).whereType<Map>())
          if (_i(g['sessions']) > 0 || _i(g['target']) > 0) g
    ];
    if (groups.isEmpty) {
      return Text('No training booked in this period.',
          style: PT.inter(14, color: PT.muted));
    }
    final short = [
      for (final g in groups)
        if (_i(g['target']) > 0 && _i(g['sessions']) < _i(g['target']) * weeks)
          g
    ];
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (short.isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(
              '${short.length} team${short.length == 1 ? '' : 's'} got fewer sessions than they need.',
              style:
                  PT.inter(13.5, weight: FontWeight.w600, color: PT.amberText)),
        ),
      for (final g in groups.take(30))
        Container(
          padding: const EdgeInsets.symmetric(vertical: 7),
          decoration:
              BoxDecoration(border: Border(top: BorderSide(color: PT.line))),
          child: Row(children: [
            Expanded(
                child: Text('${g['name']}',
                    style: PT.inter(14, weight: FontWeight.w600))),
            Text(
                '${_i(g['sessions'])}'
                '${_i(g['target']) > 0 ? ' of ${_i(g['target']) * weeks}' : ''} sessions · ${_h(_i(g['mins']))}',
                style: PT.inter(13,
                    color: short.contains(g) ? PT.amberText : PT.muted)),
          ]),
        ),
    ]);
  }
}

Widget _key(Color c, String label) =>
    Row(mainAxisSize: MainAxisSize.min, children: [
      Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
              color: c,
              border: Border.all(color: PT.line),
              borderRadius: BorderRadius.circular(3))),
      const SizedBox(width: 6),
      Text(label, style: PT.inter(12.5, color: PT.muted)),
    ]);

/// Weekly utilisation: two series (astros, grass) as paired bars, one
/// scale (0–100%), legend plus a value on hover.
class _WeekChart extends StatelessWidget {
  const _WeekChart({required this.weeks});
  final Map<String, (Mins, Mins)> weeks;
  @override
  Widget build(BuildContext context) {
    final keys = weeks.keys.toList()..sort();
    if (keys.isEmpty) {
      return Text('No weeks in this period.',
          style: PT.inter(14, color: PT.muted));
    }
    const h = 140.0;
    Widget bar(double? r, Color col, String tip) => Tooltip(
          message: tip,
          child: Container(
            width: 14,
            height: math.max(2, (r ?? 0) * h),
            margin: const EdgeInsets.symmetric(horizontal: 1),
            decoration: BoxDecoration(
                color: r == null ? PT.line : col,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(4))),
          ),
        );
    Widget week(String k) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
            Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
              bar(weeks[k]!.$1.rate, _astroCol,
                  'Astros, week of ${_wk(k)}: ${_pc(weeks[k]!.$1.rate)}'),
              bar(weeks[k]!.$2.rate, _grassCol,
                  'Grass, week of ${_wk(k)}: ${_pc(weeks[k]!.$2.rate)}'),
            ]),
            const SizedBox(height: 4),
            SizedBox(
                height: 16,
                child: Text(_wk(k), style: PT.inter(11, color: PT.muted))),
          ]),
        );
    // Grid line + label at a fraction of the bar height.
    Widget grid(double f, String label) => Positioned(
          left: 0,
          right: 0,
          bottom: 20 + f * h - 8,
          child: Row(children: [
            SizedBox(
                width: 36,
                child: Text(label,
                    textAlign: TextAlign.right,
                    style: PT.inter(11, color: PT.faint))),
            const SizedBox(width: 8),
            Expanded(child: Container(height: 1, color: PT.line)),
          ]),
        );
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SizedBox(
        height: h + 40,
        child: Stack(children: [
          grid(0, '0%'),
          grid(.5, '50%'),
          grid(1, '100%'),
          Positioned.fill(
            left: 44,
            child: LayoutBuilder(builder: (context, box) {
              final fits = keys.length * 46.0 <= box.maxWidth;
              final row = Row(
                  mainAxisAlignment: fits
                      ? MainAxisAlignment.spaceEvenly
                      : MainAxisAlignment.start,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [for (final k in keys) week(k)]);
              return fits
                  ? row
                  : SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      reverse: true,
                      child: row);
            }),
          ),
        ]),
      ),
      const SizedBox(height: 8),
      Wrap(spacing: 14, children: [
        _key(_astroCol, 'Astros'),
        _key(_grassCol, 'Grass'),
      ]),
    ]);
  }

  static String _wk(String iso) {
    final t = DateTime.tryParse(iso);
    return t == null ? iso : '${t.day} ${kMonths[t.month - 1].substring(0, 3)}';
  }
}

/// Day × hour heat map, one hue light→dark (08:00–22:00).
class _Heat extends StatelessWidget {
  const _Heat({required this.cells});
  final List<Map> cells;
  @override
  Widget build(BuildContext context) {
    final m = <(int, int), int>{};
    for (final c in cells) {
      m[(_i(c['dow']), _i(c['hour']))] = _i(c['mins']);
    }
    final mx = m.values.fold<int>(1, math.max);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        const SizedBox(width: 36),
        for (var h = 8; h < 22; h++)
          Expanded(
              child: Text(h % 2 == 0 ? '$h' : '',
                  textAlign: TextAlign.center,
                  style: PT.inter(10.5, color: PT.faint))),
      ]),
      const SizedBox(height: 4),
      for (var dw = 1; dw <= 7; dw++)
        Padding(
          padding: const EdgeInsets.only(bottom: 2),
          child: Row(children: [
            SizedBox(
                width: 36,
                child: Text(kWeekdays[dw - 1],
                    style: PT.inter(12, color: PT.muted))),
            for (var h = 8; h < 22; h++)
              Expanded(
                child: Tooltip(
                  message: '${kWeekdays[dw - 1]} $h:00 · ${_h(m[(
                        dw,
                        h
                      )] ?? 0)} booked',
                  child: Container(
                    height: 20,
                    margin: const EdgeInsets.only(right: 2),
                    decoration: BoxDecoration(
                        color: (m[(dw, h)] ?? 0) == 0
                            ? PT.card2
                            : _astroCol.withValues(
                                alpha: 0.15 + 0.85 * (m[(dw, h)]! / mx)),
                        borderRadius: BorderRadius.circular(3)),
                  ),
                ),
              ),
          ]),
        ),
    ]);
  }
}
