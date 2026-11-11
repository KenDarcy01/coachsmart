// v3 Match Stats charts: "Who was ahead" and "Scores over the match",
// drawn with CustomPainter from the same numbers cs-match-charts.js uses
// for its SVGs. Drawn in the SVG's own coordinates, then scaled to fit.
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../v3_theme.dart';
import 'v3_match_stats_models.dart';

const kOppRed = Color(0xFFE05252);
const _grid = Color(0x0FFFFFFF);
const _zero = Color(0x47FFFFFF);
const _axisText = Color(0xFFA1A1A2);

void _text(Canvas c, String s, Offset at,
    {Color color = _axisText,
    double size = 12,
    FontWeight weight = FontWeight.w400,
    TextAlign align = TextAlign.left}) {
  final tp = TextPainter(
      text: TextSpan(
          text: s, style: V3.inter(size, weight: weight, color: color)),
      textDirection: TextDirection.ltr)
    ..layout();
  // `at` is the SVG text baseline anchor.
  final dx = switch (align) {
    TextAlign.right => at.dx - tp.width,
    TextAlign.center => at.dx - tp.width / 2,
    _ => at.dx,
  };
  tp.paint(
      c,
      Offset(dx,
          at.dy - tp.computeDistanceToActualBaseline(TextBaseline.alphabetic)));
}

void _dashed(Canvas c, Offset a, Offset b, Paint p, double on, double off) {
  final len = (b - a).distance;
  if (len == 0) return;
  final dir = (b - a) / len;
  var d = 0.0;
  while (d < len) {
    c.drawLine(a + dir * d, a + dir * math.min(d + on, len), p);
    d += on + off;
  }
}

void _timeAxis(Canvas c, MatchModel m, MatchAxis ax, double Function(double) x,
    double top, double bottom) {
  if (m.hasH2) {
    final hx = x(m.duration.toDouble());
    _dashed(
        c,
        Offset(hx, top),
        Offset(hx, bottom),
        Paint()
          ..color = V3.amber
          ..strokeWidth = 1,
        3,
        4);
    _text(c, 'HT', Offset(hx, bottom + 22),
        color: V3.amber, weight: FontWeight.w700, align: TextAlign.center);
  }
  for (final t in ax.ticks) {
    _text(c, "$t'", Offset(x(t * 60.0), bottom + 22), align: TextAlign.center);
  }
}

/// Above the line we led, below it they led. Goals are marked with a G.
class LeadChartPainter extends CustomPainter {
  LeadChartPainter(this.m) : s = leadSeries(m);
  final MatchModel m;
  final LeadSeries s;

  static const w = 358.0, h = 220.0;
  static const _l = 34.0, _r = 10.0, _t = 14.0, _b = 30.0;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / w, size.height / h);
    const cw = w - _l - _r, ch = h - _t - _b;
    final ax = s.axis;
    double x(double sec) => _l + (sec / ax.end) * cw;
    double y(num d) => _t + ch / 2 - (d / s.maxD) * (ch / 2);

    for (final v in [-s.maxD, -s.maxD / 2, 0, s.maxD / 2, s.maxD]) {
      final p = Paint()
        ..color = v == 0 ? _zero : _grid
        ..strokeWidth = 1;
      if (v == 0) {
        _dashed(canvas, Offset(_l, y(v)), Offset(w - _r, y(v)), p, 4, 4);
      } else {
        canvas.drawLine(Offset(_l, y(v)), Offset(w - _r, y(v)), p);
      }
      _text(canvas, leadLabel(v), Offset(_l - 6, y(v) + 4),
          align: TextAlign.right);
    }
    _timeAxis(canvas, m, ax, x, _t, _t + ch);

    final line = Path();
    for (var i = 0; i < s.points.length; i++) {
      final q = s.points[i];
      i == 0 ? line.moveTo(x(q.$1), y(q.$2)) : line.lineTo(x(q.$1), y(q.$2));
    }
    final area = Path.from(line)
      ..lineTo(x(s.points.last.$1), y(0))
      ..lineTo(x(0), y(0))
      ..close();
    final up = Rect.fromLTWH(0, 0, w, y(0));
    final down = Rect.fromLTWH(0, y(0), w, h);
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeJoin = StrokeJoin.round;
    canvas.save();
    canvas.clipRect(up);
    canvas.drawPath(area, Paint()..color = V3.green.withValues(alpha: .22));
    canvas.drawPath(line, stroke..color = V3.green);
    canvas.restore();
    canvas.save();
    canvas.clipRect(down);
    canvas.drawPath(area, Paint()..color = kOppRed.withValues(alpha: .22));
    canvas.drawPath(line, stroke..color = kOppRed);
    canvas.restore();

    for (final g in s.goals) {
      final c = Offset(x(g.$1), y(g.$2));
      canvas.drawCircle(c, 9, Paint()..color = g.$3 ? V3.green : kOppRed);
      _text(canvas, 'G', Offset(c.dx, c.dy + 4),
          size: 11,
          color: V3.bg,
          weight: FontWeight.w800,
          align: TextAlign.center);
    }
    _text(canvas, '${m.usName} ahead', const Offset(_l + 4, _t + 11),
        color: V3.green, weight: FontWeight.w700);
    _text(canvas, '${m.oppName} ahead', const Offset(_l + 4, _t + ch - 4),
        color: kOppRed, weight: FontWeight.w700);
    canvas.restore();
  }

  @override
  bool shouldRepaint(LeadChartPainter old) => true;
}

/// Each side's running total, with the score at the end of each line.
class RaceChartPainter extends CustomPainter {
  RaceChartPainter(this.m) : s = raceSeries(m);
  final MatchModel m;
  final RaceSeries s;

  static const w = 358.0, h = 200.0;
  static const _l = 30.0, _r = 58.0, _t = 12.0, _b = 28.0;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / w, size.height / h);
    const cw = w - _l - _r, ch = h - _t - _b;
    final ax = s.axis;
    double x(double sec) => _l + (sec / ax.end) * cw;
    double y(num v) => _t + ch - (v / s.maxY) * ch;

    final step = s.maxY <= 10 ? 5 : 10;
    for (var v = 0; v <= s.maxY; v += step) {
      canvas.drawLine(
          Offset(_l, y(v)), Offset(w - _r, y(v)), Paint()..color = _grid);
      _text(canvas, '$v', Offset(_l - 6, y(v) + 4), align: TextAlign.right);
    }
    _timeAxis(canvas, m, ax, x, _t, _t + ch);

    Path path(List<(double, int)> pts) {
      final p = Path();
      for (var i = 0; i < pts.length; i++) {
        i == 0
            ? p.moveTo(x(pts[i].$1), y(pts[i].$2))
            : p.lineTo(x(pts[i].$1), y(pts[i].$2));
      }
      return p;
    }

    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(path(s.opp), stroke..color = kOppRed);
    canvas.drawPath(path(s.us), stroke..color = V3.green);

    var yu = y(s.usEnd) + 4, yo = y(s.oppEnd) + 4;
    if ((yu - yo).abs() < 14) {
      if (s.usEnd >= s.oppEnd) {
        yu -= 7;
        yo += 7;
      } else {
        yu += 7;
        yo -= 7;
      }
    }
    _text(canvas, s.usLabel, Offset(x(s.endX) + 6, yu),
        color: V3.green, size: 13, weight: FontWeight.w700);
    _text(canvas, s.oppLabel, Offset(x(s.endX) + 6, yo),
        color: kOppRed, size: 13, weight: FontWeight.w700);
    canvas.restore();
  }

  @override
  bool shouldRepaint(RaceChartPainter old) => true;
}

/// A chart at its SVG aspect ratio, full card width.
class V3MatchChart extends StatelessWidget {
  const V3MatchChart.lead(this.m, {super.key}) : lead = true;
  const V3MatchChart.race(this.m, {super.key}) : lead = false;
  final MatchModel m;
  final bool lead;

  @override
  Widget build(BuildContext context) {
    final ratio = lead
        ? LeadChartPainter.w / LeadChartPainter.h
        : RaceChartPainter.w / RaceChartPainter.h;
    return Semantics(
      label: lead ? 'Lead over time' : 'Scores over the match',
      child: AspectRatio(
        aspectRatio: ratio,
        child: CustomPaint(
            painter: lead ? LeadChartPainter(m) : RaceChartPainter(m)),
      ),
    );
  }
}
