// Native copy of webviews/cs-match-charts.js for the v3 live match page:
// the "Who's ahead" lead chart, the score race chart, the Stats section and
// the Timeline. Charts are CustomPainters drawn on the same 358-wide grid as
// the web page's SVGs, scaled to the card.
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../v3_theme.dart';
import 'v3_live_shared.dart' show scoreStyle;
import 'v3_matches_models.dart';

const _usC = V3.green;
const _oppC = Color(0xFFE05252);
const _axisC = Color(0xFFA1A1A2);
const _amberC = Color(0xFFF5A524);

void _label(Canvas c, String text, Offset at, Color color,
    {double size = 11,
    FontWeight weight = FontWeight.w400,
    TextAlign align = TextAlign.left}) {
  final tp = TextPainter(
      text: TextSpan(
          text: text,
          style: TextStyle(
              color: color,
              fontSize: size,
              fontWeight: weight,
              fontFamily: V3.inter(size).fontFamily)),
      textDirection: TextDirection.ltr)
    ..layout();
  // SVG text y is the baseline; nudge up by the ascent.
  final dx = align == TextAlign.center
      ? at.dx - tp.width / 2
      : align == TextAlign.right
          ? at.dx - tp.width
          : at.dx;
  tp.paint(c, Offset(dx, at.dy - size * .95));
}

void _dashed(Canvas c, Offset a, Offset b, Paint p, double on, double off) {
  final len = (b - a).distance;
  final dir = (b - a) / len;
  var d = 0.0;
  while (d < len) {
    final e = math.min(d + on, len);
    c.drawLine(a + dir * d, a + dir * e, p);
    d = e + off;
  }
}

void _xAxis(Canvas c, MatchModel m, double Function(double) x, double base) {
  final (_, ticks) = m.axis;
  if (m.hasH2) {
    _dashed(
        c,
        Offset(x(m.duration.toDouble()), 14),
        Offset(x(m.duration.toDouble()), base),
        Paint()
          ..color = _amberC
          ..strokeWidth = 1,
        3,
        4);
    _label(c, 'HT', Offset(x(m.duration.toDouble()), base + 22), _amberC,
        weight: FontWeight.w700, align: TextAlign.center);
  }
  for (final t in ticks) {
    _label(c, "$t'", Offset(x(t * 60.0), base + 22), _axisC,
        align: TextAlign.center);
  }
}

/// "Who was ahead": the lead over time, green above the line, red below.
class LeadChartPainter extends CustomPainter {
  LeadChartPainter(this.m);
  final MatchModel m;
  static const w = 358.0, h = 220.0;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / w);
    const l = 34.0, r = 10.0, t = 14.0, b = 30.0;
    const cw = w - l - r, ch = h - t - b;
    final rows = m.walk();
    final (end, _) = m.axis;
    var maxD = 3;
    for (final r in rows) {
      maxD = math.max(maxD, (r.us.t - r.opp.t).abs());
    }
    maxD = (maxD / 3).ceil() * 3;
    final endX = m.nowAbs != null ? m.nowAbs!.clamp(0, end).toDouble() : end;
    double x(double s) => l + (s / end) * cw;
    double y(num d) => t + ch / 2 - (d / maxD) * (ch / 2);

    for (final v in [-maxD, -maxD / 2, 0, maxD / 2, maxD]) {
      final p = Paint()
        ..strokeWidth = 1
        ..color = v == 0
            ? Colors.white.withValues(alpha: .28)
            : Colors.white.withValues(alpha: .06);
      if (v == 0) {
        _dashed(canvas, Offset(l, y(v)), Offset(w - r, y(v)), p, 4, 4);
      } else {
        canvas.drawLine(Offset(l, y(v)), Offset(w - r, y(v)), p);
      }
      final txt = v is double && v != v.roundToDouble()
          ? v.toStringAsFixed(1)
          : '${v.round()}';
      _label(canvas, v > 0 ? '+$txt' : txt, Offset(l - 6, y(v) + 4), _axisC,
          align: TextAlign.right);
    }
    _xAxis(canvas, m, x, t + ch);

    var d = 0;
    final pts = <Offset>[Offset(x(0), y(0))];
    double lastS = 0;
    for (final r in rows) {
      pts.add(Offset(x(r.abs), y(d)));
      d = r.us.t - r.opp.t;
      pts.add(Offset(x(r.abs), y(d)));
      lastS = r.abs;
    }
    pts.add(Offset(x(math.max(endX, lastS)), y(d)));
    final line = Path()..addPolygon(pts, false);
    final area = Path()
      ..addPolygon(
          [...pts, Offset(pts.last.dx, y(0)), Offset(x(0), y(0))], true);
    final up = Rect.fromLTWH(0, 0, w, y(0));
    final down = Rect.fromLTWH(0, y(0), w, h);
    canvas.save();
    canvas.clipRect(up);
    canvas.drawPath(area, Paint()..color = _usC.withValues(alpha: .22));
    canvas.drawPath(
        line,
        Paint()
          ..color = _usC
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5);
    canvas.restore();
    canvas.save();
    canvas.clipRect(down);
    canvas.drawPath(area, Paint()..color = _oppC.withValues(alpha: .22));
    canvas.drawPath(
        line,
        Paint()
          ..color = _oppC
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5);
    canvas.restore();
    for (final r in rows.where((r) => r.e.value == 3 && !r.e.correction)) {
      final c = Offset(x(r.abs), y(r.us.t - r.opp.t));
      canvas.drawCircle(c, 9, Paint()..color = r.e.side == 'us' ? _usC : _oppC);
      _label(canvas, 'G', c + const Offset(0, 4), V3.bg,
          weight: FontWeight.w800, align: TextAlign.center);
    }
    _label(canvas, '${m.usName} ahead', const Offset(l + 4, t + 11), _usC,
        weight: FontWeight.w700);
    _label(canvas, '${m.oppName} ahead', const Offset(l + 4, t + ch - 4), _oppC,
        weight: FontWeight.w700);
    canvas.restore();
  }

  @override
  bool shouldRepaint(LeadChartPainter old) => true;
}

/// "Scores over the match": total points for each team.
class RaceChartPainter extends CustomPainter {
  RaceChartPainter(this.m);
  final MatchModel m;
  static const w = 358.0, h = 200.0;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / w);
    const l = 30.0, r = 58.0, t = 12.0, b = 28.0;
    const cw = w - l - r, ch = h - t - b;
    final rows = m.walk();
    final (end, _) = m.axis;
    var maxY = 5;
    for (final r in rows) {
      maxY = math.max(maxY, math.max(r.us.t, r.opp.t));
    }
    maxY = (maxY / 5).ceil() * 5;
    final endX = m.nowAbs != null ? m.nowAbs!.clamp(0, end).toDouble() : end;
    double x(double s) => l + (s / end) * cw;
    double y(num v) => t + ch - (v / maxY) * ch;
    final step = maxY <= 10 ? 5 : 10;
    for (var v = 0; v <= maxY; v += step) {
      canvas.drawLine(Offset(l, y(v)), Offset(w - r, y(v)),
          Paint()..color = Colors.white.withValues(alpha: .06));
      _label(canvas, '$v', Offset(l - 6, y(v) + 4), _axisC,
          align: TextAlign.right);
    }
    _xAxis(canvas, m, x, t + ch);
    (Path, int) path(bool us) {
      var v = 0;
      final p = Path()..moveTo(x(0), y(0));
      for (final r in rows) {
        p.lineTo(x(r.abs), y(v));
        v = us ? r.us.t : r.opp.t;
        p.lineTo(x(r.abs), y(v));
      }
      p.lineTo(x(endX), y(v));
      return (p, v);
    }

    final pu = path(true), po = path(false);
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;
    canvas.drawPath(po.$1, stroke..color = _oppC);
    canvas.drawPath(pu.$1, stroke..color = _usC);
    final tot = m.totals;
    var yu = y(pu.$2) + 4, yo = y(po.$2) + 4;
    if ((yu - yo).abs() < 14) {
      if (pu.$2 >= po.$2) {
        yu -= 7;
        yo += 7;
      } else {
        yu += 7;
        yo -= 7;
      }
    }
    _label(canvas, tot.us.gaa, Offset(x(endX) + 6, yu), _usC,
        size: 12, weight: FontWeight.w700);
    _label(canvas, tot.opp.gaa, Offset(x(endX) + 6, yo), _oppC,
        size: 12, weight: FontWeight.w700);
    canvas.restore();
  }

  @override
  bool shouldRepaint(RaceChartPainter old) => true;
}

class LeadChart extends StatelessWidget {
  const LeadChart(this.m, {super.key});
  final MatchModel m;
  @override
  Widget build(BuildContext context) => Semantics(
        label: 'Lead over time',
        child: AspectRatio(
            aspectRatio: LeadChartPainter.w / LeadChartPainter.h,
            child: CustomPaint(painter: LeadChartPainter(m))),
      );
}

class RaceChart extends StatelessWidget {
  const RaceChart(this.m, {super.key});
  final MatchModel m;
  @override
  Widget build(BuildContext context) => Semantics(
        label: 'Scores over the match',
        child: AspectRatio(
            aspectRatio: RaceChartPainter.w / RaceChartPainter.h,
            child: CustomPaint(painter: RaceChartPainter(m))),
      );
}

// ───────────────────────────────────────────────────────────── sections

Widget _card(Widget child, {EdgeInsets? padding}) => Container(
      margin: const EdgeInsets.only(top: 10),
      padding: padding ?? const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: V3.card, borderRadius: BorderRadius.circular(14)),
      child: child,
    );

String _poss(String n) =>
    RegExp(r's$', caseSensitive: false).hasMatch(n) ? "$n'" : "$n's";

/// The Stats tab: lead chart, biggest leads, score race, halves, scorers.
class ChartSection extends StatelessWidget {
  const ChartSection(this.m, {super.key});
  final MatchModel m;

  @override
  Widget build(BuildContext context) {
    final t = m.totals;
    final (ud, ua, od, oa) = m.biggestLeads;
    final hs = m.halfScores;
    final sc = m.scorers;
    final named = sc.any((r) => r.$1.isNotEmpty);
    Widget kpi(String big, String small, Color c) => Expanded(
          child: Container(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            decoration: BoxDecoration(
                color: V3.card, borderRadius: BorderRadius.circular(14)),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(big, style: scoreStyle(21, color: c)),
              const SizedBox(height: 2),
              Text(small, style: V3.inter(13, color: V3.muted)),
            ]),
          ),
        );
    Widget hrow(String a, String b, String c,
            {bool head = false, bool last = false, bool bold = false}) =>
        Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
              border: last
                  ? null
                  : const Border(bottom: BorderSide(color: V3.line))),
          child: Row(children: [
            Expanded(
                child: Text(a,
                    style: head
                        ? V3.inter(12, color: V3.muted, letterSpacing: 1)
                        : V3.inter(16,
                            weight: bold ? FontWeight.w700 : FontWeight.w400))),
            for (final (i, v) in [b, c].indexed)
              Expanded(
                  child: Text(v,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: head
                          ? V3.inter(12, color: V3.muted, letterSpacing: 1)
                          : scoreStyle(21,
                              color: bold && i == 0 ? _usC : V3.text))),
          ]),
        );
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _card(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Who was ahead', style: V3.inter(17, weight: FontWeight.w700)),
        const SizedBox(height: 2),
        Text('Above the line ${m.usName} led, below it ${m.oppName} led',
            style: V3.inter(14, color: V3.muted)),
        const SizedBox(height: 8),
        LeadChart(m),
      ])),
      const SizedBox(height: 10),
      Row(children: [
        kpi(ud > 0 ? '+$ud at $ua' : '—', '${_poss(m.usName)} biggest lead',
            _usC),
        const SizedBox(width: 8),
        kpi(od > 0 ? '+$od at $oa' : '—', '${_poss(m.oppName)} biggest lead',
            _oppC),
      ]),
      _card(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Scores over the match',
            style: V3.inter(17, weight: FontWeight.w700)),
        const SizedBox(height: 2),
        Text('Total points for each team',
            style: V3.inter(14, color: V3.muted)),
        const SizedBox(height: 8),
        RaceChart(m),
      ])),
      _card(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          Column(children: [
            hrow('', m.usName.toUpperCase(), m.oppName.toUpperCase(),
                head: true),
            hrow('1st half', hs[1]!.us.gaa, hs[1]!.opp.gaa),
            if (m.hasH2) hrow('2nd half', hs[2]!.us.gaa, hs[2]!.opp.gaa),
            hrow(m.finished ? 'Final' : 'Now', t.us.gaa, t.opp.gaa,
                bold: true, last: true),
          ])),
      if (named)
        _card(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('${m.usName} scorers',
              style: V3.inter(17, weight: FontWeight.w700)),
          const SizedBox(height: 4),
          for (final (i, r) in sc.indexed)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                  border: i == sc.length - 1
                      ? null
                      : const Border(bottom: BorderSide(color: V3.line))),
              child: Row(children: [
                Expanded(
                    child: Text(r.$1.isEmpty ? 'No player named' : r.$1,
                        style: V3.inter(16,
                            color: r.$1.isEmpty ? V3.muted : V3.text))),
                Text(r.$2.gaa, style: scoreStyle(20)),
              ]),
            ),
        ])),
    ]);
  }
}

/// The Timeline tab, newest first.
class TimelineSection extends StatelessWidget {
  const TimelineSection(this.m, {super.key});
  final MatchModel m;

  @override
  Widget build(BuildContext context) {
    final items = m.timeline();
    if (items.isEmpty) {
      return Column(children: [
        _band(const TimelineItem.band('Throw-in', '0-00 v 0-00')),
        Padding(
            padding: const EdgeInsets.symmetric(vertical: 30),
            child: Text('No scores yet', style: V3.inter(15, color: V3.muted))),
      ]);
    }
    return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [for (final it in items) _item(it)]);
  }

  Widget _band(TimelineItem it) => Container(
        margin: const EdgeInsets.fromLTRB(0, 10, 0, 6),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
            color: it.ft ? V3.greenTint : V3.card2,
            borderRadius: BorderRadius.circular(12)),
        child: Row(children: [
          Expanded(
              child: Text(it.title.toUpperCase(),
                  style: V3.inter(13,
                      weight: FontWeight.w600,
                      color: it.ft ? V3.green : V3.muted,
                      letterSpacing: 1))),
          Text(it.right, style: scoreStyle(20)),
        ]),
      );

  Widget _item(TimelineItem it) {
    switch (it.kind) {
      case TimelineKind.band:
        return _band(it);
      case TimelineKind.run:
        return Padding(
          padding: const EdgeInsets.fromLTRB(4, 2, 0, 6),
          child: Text(it.title,
              style: V3.inter(13,
                  weight: FontWeight.w600, color: it.opp ? _oppC : _usC)),
        );
      case TimelineKind.sub:
        return _row(
            edge: const Color(0xFF5B8DEF),
            minute: it.minute,
            title: Text('Sub', style: V3.inter(16)),
            small: it.right,
            right: '');
      case TimelineKind.score:
        final r = it.row!;
        final opp = r.e.side == 'opp';
        final goal = r.e.value == 3 && !r.e.correction;
        final (tag, tagBg, tagFg) = r.e.correction
            ? ('CHECK', _amberC, V3.bg)
            : goal
                ? ('GOAL', opp ? _oppC : _usC, opp ? Colors.white : V3.bg)
                : r.e.value == 2
                    ? ('+2', _amberC, V3.bg)
                    : ('', V3.card, V3.text);
        return _row(
          edge: opp ? _oppC : _usC,
          goal: goal,
          minute: it.minute,
          title: Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 6,
              children: [
                Text(it.scoreName, style: V3.inter(16)),
                if (tag.isNotEmpty)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                        color: tagBg, borderRadius: BorderRadius.circular(6)),
                    child: Text(tag,
                        style: V3.inter(11,
                            weight: FontWeight.w700, color: tagFg)),
                  ),
              ]),
          small: it.right,
          right: '${r.us.gaa} v ${r.opp.gaa}',
        );
    }
  }

  Widget _row(
          {required Color edge,
          required String minute,
          required Widget title,
          required String small,
          required String right,
          bool goal = false}) =>
      Container(
        margin: const EdgeInsets.only(bottom: 6),
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: V3.card,
          gradient: goal
              ? LinearGradient(colors: [
                  edge.withValues(alpha: .16),
                  V3.card,
                ], stops: const [
                  0,
                  .6
                ])
              : null,
          borderRadius: BorderRadius.circular(12),
        ),
        child: IntrinsicHeight(
          child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Container(width: 4, color: edge),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 10, 12, 10),
                child: Row(children: [
                  SizedBox(
                      width: 50,
                      child: Text(minute,
                          style: V3.inter(14,
                              weight: FontWeight.w700, color: V3.muted))),
                  Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        title,
                        if (small.isNotEmpty)
                          Text(small, style: V3.inter(13, color: V3.muted)),
                      ])),
                  if (right.isNotEmpty) Text(right, style: scoreStyle(19)),
                ]),
              ),
            ),
          ]),
        ),
      );
}
