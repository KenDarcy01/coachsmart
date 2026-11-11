// Drawing for the v3 lineup: the GAA pitch (the web page's SVG, 300 x 484),
// the jersey, and the PNG the Share button sends.
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../v3_theme.dart';
import 'v3_lineup_models.dart';

const _pitchDark = Color(0xFF2D6A2D);
const _pitchStripe = Color(0xFF3A9A3A);
const _lineCol = Color(0xE0FFFFFF);
const _arcCol = Color(0xD9FFA500);

/// Pitch width / height.
const kPitchRatio = 300 / 484;

/// Jersey outline in a 40 x 44 box.
Path jerseyPath() => Path()
  ..moveTo(14, 3)
  ..quadraticBezierTo(11, 3, 6, 7)
  ..lineTo(1, 14)
  ..lineTo(6, 18)
  ..lineTo(8, 40)
  ..lineTo(32, 40)
  ..lineTo(34, 18)
  ..lineTo(39, 14)
  ..lineTo(34, 7)
  ..quadraticBezierTo(29, 3, 26, 3)
  ..quadraticBezierTo(23, 6, 20, 6)
  ..quadraticBezierTo(17, 6, 14, 3)
  ..close();

Path _dashed(Path src, double on, double off) {
  final out = Path();
  for (final m in src.computeMetrics()) {
    var d = 0.0;
    while (d < m.length) {
      out.addPath(m.extractPath(d, (d + on).clamp(0, m.length)), Offset.zero);
      d += on + off;
    }
  }
  return out;
}

/// A jersey filling [r]: kit colours when [filled], a dashed ghost when
/// empty, with the shirt number on it.
void paintJersey(Canvas c, Rect r, int number,
    {required bool keeper,
    required bool filled,
    required KitColours kit,
    bool highlight = false}) {
  c.save();
  c.translate(r.left, r.top);
  final s = r.width / 40;
  c.scale(s, r.height / 44);
  final path = jerseyPath();
  final body = filled ? (keeper ? kit.keeper : kit.primary) : null;
  c.drawPath(
      path,
      Paint()
        ..color = highlight
            ? const Color(0x47FFFFFF)
            : body ?? const Color(0x26FFFFFF));
  if (filled && !keeper && !highlight) {
    c.save();
    c.clipPath(path);
    c.drawRect(const Rect.fromLTWH(0, 18, 40, 7),
        Paint()..color = kit.stripe.withValues(alpha: .85));
    c.restore();
  }
  final stroke = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.5
    ..color =
        filled || highlight ? const Color(0xD9FFFFFF) : const Color(0x8CFFFFFF);
  c.drawPath(filled || highlight ? path : _dashed(path, 3, 2), stroke);
  c.drawPath(
      Path()
        ..moveTo(14, 3)
        ..quadraticBezierTo(20, 8, 26, 3),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.1
        ..color = const Color(0x59FFFFFF));
  final fs = filled ? 14.0 : 11.0;
  final cy = filled && !keeper ? 21.0 : 26.0;
  final label = '$number';
  TextPainter tp(Paint? fg, Color? col) => TextPainter(
      text: TextSpan(
          text: label,
          style: TextStyle(
              fontSize: fs,
              fontWeight: FontWeight.w800,
              foreground: fg,
              color: col)),
      textDirection: TextDirection.ltr)
    ..layout();
  final outline = tp(
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeJoin = StrokeJoin.round
        ..color = const Color(0xCC000000),
      null);
  final fill = tp(
      null,
      filled
          ? numberColour(keeper ? kit.keeper : kit.primary)
          : const Color(0xE6FFFFFF));
  final at = Offset(20 - fill.width / 2, cy - fill.height / 2);
  outline.paint(c, at);
  fill.paint(c, at);
  c.restore();
}

class JerseyPainter extends CustomPainter {
  JerseyPainter(this.number,
      {required this.keeper,
      required this.filled,
      required this.kit,
      this.highlight = false});
  final int number;
  final bool keeper, filled, highlight;
  final KitColours kit;

  @override
  void paint(Canvas canvas, Size size) =>
      paintJersey(canvas, Offset.zero & size, number,
          keeper: keeper, filled: filled, kit: kit, highlight: highlight);

  @override
  bool shouldRepaint(JerseyPainter o) =>
      o.number != number ||
      o.keeper != keeper ||
      o.filled != filled ||
      o.highlight != highlight ||
      o.kit != kit;
}

/// The pitch, drawn into [r].
void paintPitch(Canvas c, Rect r) {
  c.save();
  c.clipRRect(RRect.fromRectAndRadius(r, const Radius.circular(10)));
  c.translate(r.left, r.top);
  c.scale(r.width / 300, r.height / 484);
  c.drawRect(const Rect.fromLTWH(0, 0, 300, 484), Paint()..color = _pitchDark);
  for (final y in [0.0, 96.0, 192.0, 288.0, 384.0]) {
    c.drawRect(Rect.fromLTWH(0, y, 300, 48), Paint()..color = _pitchStripe);
  }
  Paint ln(double w, [Color col = _lineCol]) => Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = w
    ..color = col;
  void line(double y, double w) =>
      c.drawLine(Offset(4, y), Offset(296, y), ln(w));
  c.drawRect(const Rect.fromLTWH(4, 4, 292, 476), ln(1.8));
  for (final y in [73.0, 160.0, 324.0, 411.0]) {
    line(y, 1.5);
  }
  for (final y in [49.0, 229.0, 255.0, 435.0]) {
    line(y, 1.1);
  }
  c.drawPath(
      _dashed(
          Path()
            ..moveTo(4, 242)
            ..lineTo(296, 242),
          6,
          4),
      ln(1.4));
  final box = Paint()..color = const Color(0x0DFFFFFF);
  final small = Paint()..color = const Color(0x12FFFFFF);
  final goal = Paint()..color = const Color(0x38FFFFFF);
  for (final top in [true, false]) {
    final big = top
        ? const Rect.fromLTWH(118, 4, 64, 45)
        : const Rect.fromLTWH(118, 435, 64, 45);
    final sm = top
        ? const Rect.fromLTWH(127, 4, 46, 15)
        : const Rect.fromLTWH(127, 465, 46, 15);
    final g = top
        ? const Rect.fromLTWH(139, 4, 22, 9)
        : const Rect.fromLTWH(139, 471, 22, 9);
    c.drawRect(big, box);
    c.drawRect(big, ln(1.4));
    c.drawRect(sm, small);
    c.drawRect(sm, ln(1.1));
    c.drawRect(g, goal);
    c.drawRect(g, ln(1.8, Colors.white));
    c.drawCircle(Offset(150, top ? 43 : 441), 2.2, Paint()..color = _lineCol);
    // The D and the 40 m arc, inside the pitch only.
    final yLine = top ? 73.0 : 411.0;
    c.save();
    c.clipRect(top
        ? const Rect.fromLTWH(-5, 73, 310, 52)
        : const Rect.fromLTWH(-5, 359, 310, 52));
    c.drawPath(
        Path()
          ..moveTo(107, yLine)
          ..arcToPoint(Offset(193, yLine),
              radius: const Radius.elliptical(43, 44), clockwise: !top),
        ln(1.1));
    c.restore();
    c.save();
    c.clipRect(top
        ? const Rect.fromLTWH(-5, 73, 310, 160)
        : const Rect.fromLTWH(-5, 251, 310, 160));
    final arc = Path()
      ..moveTo(33, yLine)
      ..arcToPoint(Offset(267, yLine),
          radius: const Radius.elliptical(132, 137), clockwise: !top);
    c.drawPath(arc, Paint()..color = const Color(0x12FFA500));
    c.drawPath(_dashed(arc, 4, 3), ln(1.6, _arcCol));
    c.restore();
  }
  c.restore();
}

class PitchPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) =>
      paintPitch(canvas, Offset.zero & size);
  @override
  bool shouldRepaint(PitchPainter oldDelegate) => false;
}

// ------------------------------------------------------------ share image

TextPainter _text(String s, TextStyle st, {double? maxW, TextAlign? align}) =>
    TextPainter(
        text: TextSpan(text: s, style: st),
        textDirection: TextDirection.ltr,
        textAlign: align ?? TextAlign.left,
        maxLines: 1,
        ellipsis: '…')
      ..layout(maxWidth: maxW ?? double.infinity);

/// The lineup image: team name and event, the pitch with each jersey and
/// name, then the subs in two numbered columns (as the web page draws it).
Future<Uint8List> renderLineupPng(LineupData d, LineupBoard b,
    {double scale = 3}) async {
  const pw = 380.0, pad = 12.0, hdr = 66.0, jw = 44.0, jh = jw * 44 / 40;
  const ph = pw * 484 / 300;
  const nameW = pw * 0.30 - 8;
  final subs = b.subs.entries.toList()..sort((a, c) => a.key - c.key);
  final subRows = (subs.length / 2).ceil();
  final subH = subs.isEmpty ? 0.0 : 28.0 + subRows * 26;
  const tw = pw + pad * 2;
  final th = hdr + ph + pad * 2 + subH + 26;

  final rec = ui.PictureRecorder();
  final c = Canvas(rec);
  c.scale(scale);
  c.drawRect(Rect.fromLTWH(0, 0, tw, th), Paint()..color = V3.bg);
  c.drawRect(const Rect.fromLTWH(0, 0, tw, 5), Paint()..color = d.kit.primary);
  c.drawRect(const Rect.fromLTWH(0, 5, tw, 2), Paint()..color = d.kit.stripe);
  _text(
          (d.teamName.isEmpty ? 'Line-up' : d.teamName).toUpperCase(),
          const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.5,
              color: V3.text),
          maxW: pw)
      .paint(c, const Offset(pad, 14));
  _text(
          d.imageSub,
          const TextStyle(
              fontSize: 12, fontWeight: FontWeight.w500, color: V3.muted),
          maxW: pw)
      .paint(c, const Offset(pad, 45));

  const pitch = Rect.fromLTWH(pad, hdr, pw, ph);
  paintPitch(c, pitch);
  c.drawRRect(
      RRect.fromRectAndRadius(pitch, const Radius.circular(10)),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = const Color(0xD9FFFFFF));

  for (final pos in positionsFor(b.format)) {
    final id = b.assign[pos.n];
    final pl = id == null ? null : d.player(id);
    final cx = pad + pos.x / 100 * pw, cy = hdr + dispY(pos.y) / 100 * ph;
    paintJersey(c,
        Rect.fromCenter(center: Offset(cx, cy), width: jw, height: jh), pos.n,
        keeper: pos.n == 1, filled: pl != null, kit: d.kit);
    if (pl == null) continue;
    final lines = nameLines(pl.name);
    final tps = [
      for (var i = 0; i < lines.length; i++)
        _fitText(lines[i], nameW, i == 0 ? FontWeight.w700 : FontWeight.w600)
    ];
    final w = tps.map((t) => t.width).reduce((a, b) => a > b ? a : b) + 12;
    final h = lines.length * 14.0 + 5;
    final ly = cy + jh / 2 + 2;
    c.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(cx - w / 2, ly, w, h), const Radius.circular(5)),
        Paint()..color = const Color(0x99000000));
    for (var i = 0; i < tps.length; i++) {
      tps[i].paint(
          c,
          Offset(cx - tps[i].width / 2,
              ly + 3 + i * 14 + (14 - tps[i].height) / 2));
    }
  }

  if (subs.isNotEmpty) {
    var y = hdr + ph + pad + 6;
    _text(
            'SUBSTITUTES',
            const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: .5,
                color: V3.green))
        .paint(c, Offset(pad, y));
    y += 22;
    const colW = pw / 2;
    for (var i = 0; i < subs.length; i++) {
      final pl = d.player(subs[i].value);
      if (pl == null) continue;
      final x = pad + (i % 2) * colW, yy = y + (i ~/ 2) * 26;
      c.drawRRect(
          RRect.fromRectAndRadius(
              Rect.fromLTWH(x, yy, 24, 18), const Radius.circular(4)),
          Paint()..color = d.kit.primary);
      final n = _text(
          '${subShirt(b.format, subs[i].key)}',
          TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: numberColour(d.kit.primary)));
      n.paint(c, Offset(x + 12 - n.width / 2, yy + 9 - n.height / 2));
      final t = _text(
          pl.name,
          const TextStyle(
              fontSize: 13, fontWeight: FontWeight.w500, color: V3.text),
          maxW: colW - 40);
      t.paint(c, Offset(x + 32, yy + 9 - t.height / 2));
    }
  }
  final brand = _text(
      'COACHSMART',
      const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 1,
          color: Color(0xB387C232)));
  brand.paint(c, Offset(pad + pw - brand.width, th - 6 - brand.height));

  final img = await rec
      .endRecording()
      .toImage((tw * scale).round(), (th * scale).round());
  final png = await img.toByteData(format: ui.ImageByteFormat.png);
  img.dispose();
  return png!.buffer.asUint8List();
}

TextPainter _fitText(String s, double maxW, FontWeight w) {
  var fs = 12.0;
  var tp =
      _text(s, TextStyle(fontSize: fs, fontWeight: w, color: Colors.white));
  if (tp.width > maxW) {
    fs = (12 * maxW / tp.width).clamp(8.5, 12);
    tp = _text(s, TextStyle(fontSize: fs, fontWeight: w, color: Colors.white),
        maxW: maxW);
  }
  return tp;
}
