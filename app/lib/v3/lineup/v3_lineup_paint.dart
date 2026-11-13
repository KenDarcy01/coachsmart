// Drawing for the v3 lineup: the GAA pitch (the web page's SVG, 300 x 484),
// the jersey, and the PNG the Share button sends.
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;

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

/// The lineup image, a line-for-line copy of the v2 export
/// (generateLineupCanvas in webviews/team_selector.html): Bebas Neue team
/// name, DM Sans names, a plain mown pitch, jerseys, name pills and the
/// subs in two numbered columns. Ken (2026-11-12) prefers it to the earlier
/// v3 image, which reused the on-screen pitch.
Future<Uint8List> renderLineupPng(LineupData d, LineupBoard b,
    {double scale = 3, bool webFonts = true}) async {
  // Same as the web: wait up to 1.5s for the fonts, then draw anyway.
  String? bebas, dm;
  if (webFonts) {
    try {
      bebas = GoogleFonts.bebasNeue().fontFamily;
      dm = GoogleFonts.dmSans().fontFamily;
      await GoogleFonts.pendingFonts()
          .timeout(const Duration(milliseconds: 1500));
    } catch (_) {}
  }
  final crest = await _crestImage(d.crestUrl);
  TextStyle sans(double size, FontWeight w, Color col) =>
      TextStyle(fontFamily: dm, fontSize: size, fontWeight: w, color: col);

  const pw = 380.0, pad = 12.0, hdr = 66.0, jh0 = 44.0 * 44 / 40;
  final ph = (pw * 145 / 90).roundToDouble();
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
  // Header: club colour bar, team, event.
  c.drawRect(const Rect.fromLTWH(0, 0, tw, 5), Paint()..color = d.kit.primary);
  c.drawRect(const Rect.fromLTWH(0, 5, tw, 2), Paint()..color = d.kit.stripe);
  // Club crest top left, as tall as the title and event lines together
  // (Ken, 2026-11-13); the text moves right of it. No crest, no gap.
  var tx = pad;
  if (crest != null) {
    const box = 46.0;
    final k = box / (crest.width > crest.height ? crest.width : crest.height);
    final w = crest.width * k, h = crest.height * k;
    c.drawImageRect(
        crest,
        Rect.fromLTWH(0, 0, crest.width.toDouble(), crest.height.toDouble()),
        Rect.fromLTWH(pad + (box - w) / 2, 14 + (box - h) / 2, w, h),
        Paint()..filterQuality = FilterQuality.high);
    tx = pad + box + 10;
  }
  final textW = pw - (tx - pad);
  final title = _text(
      (d.teamName.isEmpty ? 'Line-up' : d.teamName).toUpperCase(),
      TextStyle(fontFamily: bebas, fontSize: 26, color: V3.text),
      maxW: textW);
  title.paint(c, Offset(tx, 40 - _baseline(title)));
  final sub =
      _text(d.imageSub, sans(12, FontWeight.w500, V3.muted), maxW: textW);
  sub.paint(c, Offset(tx, 58 - _baseline(sub)));

  // Pitch: soft mowing stripes and plain white lines.
  const py = hdr;
  final pitch = Rect.fromLTWH(pad, py, pw, ph);
  final pitchR = RRect.fromRectAndRadius(pitch, const Radius.circular(10));
  c.save();
  c.clipRRect(pitchR);
  final sh = ph / 10;
  for (var i = 0; i < 10; i++) {
    c.drawRect(
        Rect.fromLTWH(pad, py + i * sh, pw, sh + 1),
        Paint()
          ..color =
              i.isOdd ? const Color(0xFF3D8C3A) : const Color(0xFF357E33));
  }
  Paint ln(Color col, [double w = 1.5]) => Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = w
    ..color = col;
  final white70 = ln(const Color(0xB3FFFFFF));
  final sqw = pw * 0.149, sqh = ph * 0.033, sqx = pad + (pw - sqw) / 2;
  c.drawRect(Rect.fromLTWH(sqx, py, sqw, sqh), white70);
  c.drawRect(Rect.fromLTWH(sqx, py + ph - sqh, sqw, sqh), white70);
  final lrw = pw * 0.217, lrh = ph * 0.095, lrx = pad + (pw - lrw) / 2;
  c.drawRect(Rect.fromLTWH(lrx, py, lrw, lrh), white70);
  c.drawRect(Rect.fromLTWH(lrx, py + ph - lrh, lrw, lrh), white70);
  final white45 = ln(const Color(0x73FFFFFF));
  for (final yp in const [0.146, 0.328, 0.474, 0.526, 0.672, 0.854]) {
    c.drawLine(
        Offset(pad, py + yp * ph), Offset(pad + pw, py + yp * ph), white45);
  }
  final r = pw * 0.149;
  c.drawArc(
      Rect.fromCircle(center: Offset(pad + pw / 2, py + ph * .146), radius: r),
      0,
      3.14159265,
      false,
      white45);
  c.drawArc(
      Rect.fromCircle(center: Offset(pad + pw / 2, py + ph * .854), radius: r),
      3.14159265,
      3.14159265,
      false,
      white45);
  c.drawPath(
      _dashed(
          Path()
            ..moveTo(pad, py + ph / 2)
            ..lineTo(pad + pw, py + ph / 2),
          6,
          4),
      ln(const Color(0x99FFFFFF)));
  c.restore();
  c.drawRRect(pitchR, ln(const Color(0xD9FFFFFF), 2));

  // Players: jersey on the spot, first name / surname under it.
  for (final pos in positionsFor(b.format)) {
    final id = b.assign[pos.n];
    final pl = id == null ? null : d.player(id);
    final cx = pad + pos.x / 100 * pw, cy = py + dispY(pos.y) / 100 * ph;
    _v2Jersey(c, cx, cy, pos.n, pos.n == 1, pl != null, d.kit);
    if (pl == null) continue;
    final parts = pl.name.trim().split(RegExp(r'\s+'));
    final lines =
        parts.length > 1 ? [parts[0], parts.sublist(1).join(' ')] : [parts[0]];
    final tps = <TextPainter>[];
    for (var i = 0; i < lines.length; i++) {
      final w = i == 0 ? FontWeight.w700 : FontWeight.w600;
      final probe = _text(lines[i], sans(12, FontWeight.w700, Colors.white));
      final fs = probe.width > nameW
          ? (12 * nameW / probe.width).clamp(8.5, 12.0).toDouble()
          : 12.0;
      tps.add(_text(lines[i], sans(fs, w, Colors.white), maxW: nameW));
    }
    final pillW = tps.map((t) => t.width).reduce((a, b) => a > b ? a : b) + 12;
    final pillH = lines.length * 14.0 + 5;
    final ly = cy + jh0 / 2 + 2;
    c.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(cx - pillW / 2, ly, pillW, pillH),
            const Radius.circular(5)),
        Paint()..color = const Color(0x99000000));
    for (var i = 0; i < tps.length; i++) {
      tps[i].paint(c, Offset(cx - tps[i].width / 2, ly + 3 + i * 14));
    }
  }

  // Subs: numbered, two columns.
  if (subs.isNotEmpty) {
    var y = py + ph + pad + 6;
    _text('SUBSTITUTES', sans(11, FontWeight.w700, V3.green))
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
      final n = _text('${subShirt(b.format, subs[i].key)}',
          sans(11, FontWeight.w800, numberColour(d.kit.primary)));
      n.paint(c, Offset(x + 12 - n.width / 2, yy + 9.5 - n.height / 2));
      final t =
          _text(pl.name, sans(13, FontWeight.w500, V3.text), maxW: colW - 40);
      t.paint(c, Offset(x + 32, yy + 9.5 - t.height / 2));
    }
  }
  final brand = _text(
      'COACHSMART',
      TextStyle(
          fontFamily: bebas,
          fontSize: 12,
          letterSpacing: 1,
          color: const Color(0xB387C232)));
  brand.paint(c, Offset(pad + pw - brand.width, th - 6 - _baseline(brand)));

  final img = await rec
      .endRecording()
      .toImage((tw * scale).round(), (th * scale).round());
  final png = await img.toByteData(format: ui.ImageByteFormat.png);
  img.dispose();
  crest?.dispose();
  return png!.buffer.asUint8List();
}

/// The crest for the share image, or null if there is none or it fails to
/// load within 3 seconds (the image is then drawn without it).
Future<ui.Image?> _crestImage(String url) async {
  if (url.isEmpty) return null;
  try {
    final r =
        await http.get(Uri.parse(url)).timeout(const Duration(seconds: 3));
    if (r.statusCode != 200) return null;
    final codec =
        await ui.instantiateImageCodec(r.bodyBytes, targetHeight: 276);
    return (await codec.getNextFrame()).image;
  } catch (_) {
    return null;
  }
}

double _baseline(TextPainter t) =>
    t.computeDistanceToActualBaseline(TextBaseline.alphabetic);

/// The v2 export's jersey (drawCanvasJersey): 46px wide, no collar line,
/// number outlined in black.
void _v2Jersey(Canvas c, double cx, double cy, int number, bool keeper,
    bool filled, KitColours kit) {
  const jw = 46.0, jh = jw * 44 / 40, s = jw / 40;
  c.save();
  c.translate(cx - jw / 2, cy - jh / 2);
  c.scale(s, s);
  final path = jerseyPath();
  if (filled) {
    c.drawPath(path, Paint()..color = keeper ? kit.keeper : kit.primary);
    if (!keeper) {
      c.save();
      c.clipPath(path);
      c.drawRect(const Rect.fromLTWH(0, 18, 40, 7),
          Paint()..color = kit.stripe.withValues(alpha: .85));
      c.restore();
    }
  } else {
    c.drawPath(path, Paint()..color = const Color(0x26FFFFFF));
  }
  final stroke = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.5 / s
    ..color = filled ? const Color(0xD9FFFFFF) : const Color(0x8CFFFFFF);
  c.drawPath(filled ? path : _dashed(path, 3 / s, 2 / s), stroke);
  final fs = filled ? 14.0 : 11.0;
  final yn = filled && !keeper ? 21.0 : 26.0;
  TextPainter tp(Paint? fg, Color? col) => TextPainter(
      text: TextSpan(
          text: '$number',
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
        ..strokeWidth = 4 / s
        ..strokeJoin = StrokeJoin.round
        ..color = const Color(0xCC000000),
      null);
  final fill = tp(
      null,
      filled
          ? numberColour(keeper ? kit.keeper : kit.primary)
          : const Color(0xE6FFFFFF));
  final at = Offset(20 - fill.width / 2, yn - fill.height / 2);
  outline.paint(c, at);
  fill.paint(c, at);
  c.restore();
}
