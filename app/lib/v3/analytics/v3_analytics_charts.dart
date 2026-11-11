// v3 Club Analytics charts, drawn with CustomPainter: the percentage ring,
// the squad donut, month bars, stacked month bars, the team sparkline and
// flat segmented bars.
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../v3_theme.dart';

const _track = V3.card2;

TextPainter _tp(String s, double size, Color color,
    {FontWeight weight = FontWeight.w400}) {
  return TextPainter(
      text: TextSpan(
          text: s,
          style: TextStyle(fontSize: size, fontWeight: weight, color: color)),
      textDirection: TextDirection.ltr)
    ..layout();
}

/// A percentage ring with the number in the middle.
class AnRing extends StatelessWidget {
  const AnRing(
      {super.key, required this.pct, required this.color, this.size = 96});
  final int pct;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) => Semantics(
        label: '$pct%',
        child: SizedBox(
            width: size,
            height: size,
            child: CustomPaint(painter: AnRingPainter(pct, color))),
      );
}

class AnRingPainter extends CustomPainter {
  AnRingPainter(this.pct, this.color);
  final int pct;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final s = math.min(size.width, size.height);
    final stroke = s * 4 / 36;
    final r = s * 15.5 / 36;
    final c = Offset(size.width / 2, size.height / 2);
    final p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..color = _track;
    canvas.drawCircle(c, r, p);
    if (pct > 0) {
      p
        ..color = color
        ..strokeCap = StrokeCap.round;
      canvas.drawArc(Rect.fromCircle(center: c, radius: r), -math.pi / 2,
          2 * math.pi * math.min(pct, 100) / 100, false, p);
    }
    final t = _tp('$pct%', s * (s < 50 ? 0.27 : 0.22), V3.text,
        weight: FontWeight.w700);
    t.paint(canvas, c - Offset(t.width / 2, t.height / 2));
  }

  @override
  bool shouldRepaint(AnRingPainter o) => o.pct != pct || o.color != color;
}

class AnSeg {
  const AnSeg(this.value, this.color);
  final double value;
  final Color color;
}

/// The squad split donut with the total and a caption in the middle.
class AnDonutPainter extends CustomPainter {
  AnDonutPainter(this.segs, this.big, this.small);
  final List<AnSeg> segs;
  final String big;
  final String small;

  @override
  void paint(Canvas canvas, Size size) {
    final s = math.min(size.width, size.height);
    final stroke = s * 6 / 42;
    final r = s * 15.5 / 42;
    final c = Offset(size.width / 2, size.height / 2);
    final p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..color = _track;
    canvas.drawCircle(c, r, p);
    final total = segs.fold<double>(0, (a, x) => a + x.value);
    final sum = total == 0 ? 1.0 : total;
    final gap = segs.length > 1 ? 1.2 : 0.0;
    var off = 0.0;
    for (final x in segs) {
      final len = x.value / sum * 100;
      final d = math.max(len - gap, 0.4);
      p.color = x.color;
      canvas.drawArc(
          Rect.fromCircle(center: c, radius: r),
          -math.pi / 2 + off / 100 * 2 * math.pi,
          d / 100 * 2 * math.pi,
          false,
          p);
      off += len;
    }
    final b = _tp(big, s * 0.19, V3.text, weight: FontWeight.w700);
    final sm = _tp(small, s * 0.1, V3.muted);
    final h = b.height + sm.height;
    b.paint(canvas, Offset(c.dx - b.width / 2, c.dy - h / 2));
    sm.paint(canvas, Offset(c.dx - sm.width / 2, c.dy - h / 2 + b.height));
  }

  @override
  bool shouldRepaint(AnDonutPainter o) => true;
}

/// One column of a bar chart: stacked pieces (bottom first), the label
/// above and the label below. No pieces draws a flat grey stub.
class AnBar {
  const AnBar(this.pieces, this.top, this.bottom);
  final List<AnSeg> pieces;
  final String top;
  final String bottom;
}

/// Month bars (attendance %, or squad places stacked by squad).
class AnBarsPainter extends CustomPainter {
  AnBarsPainter(this.bars, this.max);
  final List<AnBar> bars;

  /// Value that fills the full bar height.
  final double max;

  @override
  void paint(Canvas canvas, Size size) {
    if (bars.isEmpty) return;
    const gap = 6.0;
    final w = (size.width - gap * (bars.length - 1)) / bars.length;
    const labelH = 18.0;
    final plotTop = labelH + 4;
    final plotBottom = size.height - labelH - 2;
    final plotH = plotBottom - plotTop;
    for (var i = 0; i < bars.length; i++) {
      final b = bars[i];
      final x = i * (w + gap);
      final top = _tp(b.top, 13, kLabel);
      top.paint(canvas, Offset(x + (w - top.width) / 2, 0));
      final bottom = _tp(b.bottom, 13, V3.muted);
      bottom.paint(
          canvas, Offset(x + (w - bottom.width) / 2, size.height - labelH));
      final total = b.pieces.fold<double>(0, (a, p) => a + p.value);
      if (total <= 0) {
        canvas.drawRRect(
            RRect.fromRectAndRadius(Rect.fromLTWH(x, plotBottom - 2, w, 2),
                const Radius.circular(1)),
            Paint()..color = _track);
        continue;
      }
      final barH = math.max(plotH * math.min(total / max, 1), 2.0);
      final rect = Rect.fromLTWH(x, plotBottom - barH, w, barH);
      canvas.save();
      canvas.clipRRect(RRect.fromRectAndCorners(rect,
          topLeft: const Radius.circular(5),
          topRight: const Radius.circular(5),
          bottomLeft: const Radius.circular(2),
          bottomRight: const Radius.circular(2)));
      var y = plotBottom;
      for (final p in b.pieces) {
        final h = barH * p.value / total;
        canvas.drawRect(
            Rect.fromLTWH(x, y - h, w, h), Paint()..color = p.color);
        y -= h;
        if (b.pieces.length > 1) {
          canvas.drawRect(Rect.fromLTWH(x, y, w, 1), Paint()..color = V3.card);
        }
      }
      canvas.restore();
    }
  }

  static const kLabel = Color(0xFFB0B8C8);

  @override
  bool shouldRepaint(AnBarsPainter o) => true;
}

/// The small month sparkline on a team card (null = no events that month).
class AnSparkPainter extends CustomPainter {
  AnSparkPainter(this.values, this.avg);
  final List<int?> values;
  final int avg;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;
    const gap = 3.0;
    final w = (size.width - gap * (values.length - 1)) / values.length;
    for (var i = 0; i < values.length; i++) {
      final v = values[i];
      final x = i * (w + gap);
      final h = v == null ? 2.0 : size.height * math.max(v, 4) / 100;
      final color = v == null
          ? _track
          : V3.green.withValues(alpha: v < avg - 15 ? 0.45 : 1);
      canvas.drawRRect(
          RRect.fromRectAndCorners(Rect.fromLTWH(x, size.height - h, w, h),
              topLeft: const Radius.circular(2),
              topRight: const Radius.circular(2)),
          Paint()..color = color);
    }
  }

  @override
  bool shouldRepaint(AnSparkPainter o) => true;
}

/// A flat bar of coloured pieces on a grey track. With [fill] null the
/// pieces share the whole width by value; otherwise they fill [fill] of it
/// (0 to 1) left to right.
class AnSegBar extends StatelessWidget {
  const AnSegBar(
      {super.key,
      required this.segs,
      this.height = 8,
      this.gap = 0,
      this.fill,
      this.track = true});
  final List<AnSeg> segs;
  final double height;
  final double gap;
  final double? fill;
  final bool track;

  @override
  Widget build(BuildContext context) => SizedBox(
      height: height,
      width: double.infinity,
      child: CustomPaint(painter: _SegBarPainter(segs, gap, fill, track)));
}

class _SegBarPainter extends CustomPainter {
  _SegBarPainter(this.segs, this.gap, this.fill, this.track);
  final List<AnSeg> segs;
  final double gap;
  final double? fill;
  final bool track;

  @override
  void paint(Canvas canvas, Size size) {
    final r = Radius.circular(size.height / 2);
    final all = RRect.fromRectAndRadius(Offset.zero & size, r);
    if (track) canvas.drawRRect(all, Paint()..color = _track);
    final shown = segs.where((s) => s.value > 0).toList();
    if (shown.isEmpty) return;
    canvas.save();
    canvas.clipRRect(all);
    final total = shown.fold<double>(0, (a, s) => a + s.value);
    final width = size.width * (fill ?? 1).clamp(0.0, 1.0);
    final usable = width - gap * (shown.length - 1);
    var x = 0.0;
    for (final s in shown) {
      final w = math.max(usable * s.value / total, fill != null ? 3.0 : 0.0);
      canvas.drawRect(
          Rect.fromLTWH(x, 0, w, size.height), Paint()..color = s.color);
      x += w + gap;
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_SegBarPainter o) => true;
}
