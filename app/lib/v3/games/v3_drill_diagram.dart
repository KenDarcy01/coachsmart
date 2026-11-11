// Drill diagrams: a CustomPainter port of the sketch pad in
// webviews/games-resource-v2.html (Edit Game > Image / Sketch). The web page
// shows saved diagrams as a picture (games.game_image, a PNG made by
// ai-process-game); the only drawing code it runs itself is this sketch pad:
// a green pitch with a dashed halfway line, numbered players (white discs),
// orange cones, green arrows for runs and white freehand lines. The
// cs-scene.js renderer (AI diagrams) is not used by that page and is not
// ported here.
//
// Reuse:
//   DrillSketch            the drawing (normalised 0..1 coordinates)
//   DrillSketchPainter     paints a DrillSketch at any size
//   DrillSketchController  editing state: tool, undo, clear
//   DrillSketchPad         the interactive pad with its tool bar
//   renderDrillSketchPng   a PNG of the sketch to upload (image_base64)
//   loadDrillBackground    a network picture to draw over
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../v3_theme.dart';

/// Size the web canvas is drawn at (width 100% of a phone x 260px); mark
/// sizes are given at this width and scale with the canvas.
const Size kDrillSketchSize = Size(360, 260);

/// Pitch colour on screen and in the exported PNG (web: #1a2d1a / #2e6e16).
const Color kDrillPitchScreen = Color(0xFF1A2D1A);
const Color kDrillPitchExport = Color(0xFF2E6E16);
const Color kDrillArrow = Color(0xFFAAEE35);
const Color kDrillCone = Color(0xFFF07023);
const Color kDrillConeEdge = Color(0xFFC05010);

/// One thing on the pitch. Points are normalised: (0,0) top left, (1,1)
/// bottom right.
sealed class DrillMark {
  const DrillMark();
}

/// A numbered player.
class DrillPlayer extends DrillMark {
  const DrillPlayer(this.at, this.number);
  final Offset at;
  final int number;
}

/// A cone.
class DrillCone extends DrillMark {
  const DrillCone(this.at);
  final Offset at;
}

/// A run or pass: a green arrow from [from] to [to].
class DrillArrow extends DrillMark {
  const DrillArrow(this.from, this.to);
  final Offset from, to;
}

/// A freehand white line.
class DrillStroke extends DrillMark {
  const DrillStroke(this.points);
  final List<Offset> points;
}

/// A drawing: an optional picture underneath and the marks on top.
class DrillSketch {
  const DrillSketch({this.marks = const [], this.background});
  final List<DrillMark> marks;

  /// A picture drawn over the pitch, stretched to fill (when replacing an
  /// existing game picture with a sketch).
  final ui.Image? background;

  bool get isEmpty => marks.isEmpty && background == null;

  /// Number the next player gets (1, 2, 3...).
  int get nextPlayerNumber =>
      marks.whereType<DrillPlayer>().fold(0, (m, p) => math.max(m, p.number)) +
      1;
}

/// Paints a [DrillSketch]. [preview] is an arrow being dragged.
class DrillSketchPainter extends CustomPainter {
  DrillSketchPainter(this.sketch,
      {this.preview, this.pitch = kDrillPitchScreen, this.repaintOn})
      : super(repaint: repaintOn);

  final DrillSketch sketch;
  final DrillArrow? preview;
  final Color pitch;
  final Listenable? repaintOn;

  @override
  void paint(Canvas canvas, Size size) {
    paintDrillSketch(canvas, size, sketch, preview: preview, pitch: pitch);
  }

  @override
  bool shouldRepaint(DrillSketchPainter old) =>
      old.sketch != sketch || old.preview != preview || old.pitch != pitch;
}

/// Draws [sketch] on [canvas] (shared by the painter and the PNG export).
void paintDrillSketch(Canvas canvas, Size size, DrillSketch sketch,
    {DrillArrow? preview, Color pitch = kDrillPitchScreen}) {
  final s = size.width / kDrillSketchSize.width;
  Offset p(Offset n) => Offset(n.dx * size.width, n.dy * size.height);

  canvas.drawRect(Offset.zero & size, Paint()..color = pitch);
  // Dashed halfway line.
  final dash = Paint()
    ..color = const Color(0x1FFFFFFF)
    ..strokeWidth = 1;
  for (double x = 0; x < size.width; x += 14 * s) {
    canvas.drawLine(Offset(x, size.height / 2),
        Offset(math.min(x + 8 * s, size.width), size.height / 2), dash);
  }
  final bg = sketch.background;
  if (bg != null) {
    canvas.drawImageRect(
        bg,
        Rect.fromLTWH(0, 0, bg.width.toDouble(), bg.height.toDouble()),
        Offset.zero & size,
        Paint()..filterQuality = FilterQuality.medium);
  }
  // Freehand lines sit underneath players, cones and arrows (web: a
  // separate layer drawn first).
  final line = Paint()
    ..color = Colors.white
    ..strokeWidth = 2.5 * s
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;
  for (final m in sketch.marks) {
    if (m is DrillStroke && m.points.isNotEmpty) {
      final path = Path()..moveTo(p(m.points.first).dx, p(m.points.first).dy);
      for (final q in m.points.skip(1)) {
        path.lineTo(p(q).dx, p(q).dy);
      }
      if (m.points.length == 1) {
        canvas.drawCircle(
            p(m.points.first), 1.25 * s, Paint()..color = Colors.white);
      }
      canvas.drawPath(path, line);
    }
  }
  for (final m in sketch.marks) {
    switch (m) {
      case DrillPlayer(:final at, :final number):
        _player(canvas, p(at), number, s);
      case DrillCone(:final at):
        _cone(canvas, p(at), s);
      case DrillArrow(:final from, :final to):
        _arrow(canvas, p(from), p(to), s);
      case DrillStroke():
        break;
    }
  }
  if (preview != null) _arrow(canvas, p(preview.from), p(preview.to), s);
}

void _player(Canvas c, Offset o, int n, double s) {
  c.drawCircle(o, 14 * s, Paint()..color = Colors.white);
  c.drawCircle(
      o,
      14 * s,
      Paint()
        ..color = const Color(0xFF333333)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5 * s);
  final tp = TextPainter(
      text: TextSpan(
          text: '$n',
          style: TextStyle(
              color: const Color(0xFF111111),
              fontSize: 13 * s,
              fontWeight: FontWeight.bold)),
      textDirection: TextDirection.ltr)
    ..layout();
  tp.paint(c, o - Offset(tp.width / 2, tp.height / 2));
}

void _cone(Canvas c, Offset o, double s) {
  final z = 10 * s;
  final path = Path()
    ..moveTo(o.dx, o.dy - z)
    ..lineTo(o.dx + z, o.dy + z)
    ..lineTo(o.dx - z, o.dy + z)
    ..close();
  c.drawPath(path, Paint()..color = kDrillCone);
  c.drawPath(
      path,
      Paint()
        ..color = kDrillConeEdge
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1 * s);
}

void _arrow(Canvas c, Offset a, Offset b, double s) {
  final d = b - a;
  if (d.distance < 6 * s) return;
  final head = 14 * s, ang = math.atan2(d.dy, d.dx);
  final shaftEnd =
      b - Offset(math.cos(ang) * head * 0.55, math.sin(ang) * head * 0.55);
  c.drawLine(
      a,
      shaftEnd,
      Paint()
        ..color = kDrillArrow
        ..strokeWidth = 2.5 * s
        ..strokeCap = StrokeCap.round);
  final tip = Path()
    ..moveTo(b.dx, b.dy)
    ..lineTo(b.dx - head * math.cos(ang - math.pi / 6),
        b.dy - head * math.sin(ang - math.pi / 6))
    ..lineTo(b.dx - head * math.cos(ang + math.pi / 6),
        b.dy - head * math.sin(ang + math.pi / 6))
    ..close();
  c.drawPath(tip, Paint()..color = kDrillArrow);
}

/// The sketch as a PNG (the export pitch colour), [size] in logical pixels.
Future<Uint8List> renderDrillSketchPng(DrillSketch sketch,
    {Size size = kDrillSketchSize, double pixelRatio = 2}) async {
  final rec = ui.PictureRecorder();
  final canvas = Canvas(rec);
  canvas.scale(pixelRatio);
  paintDrillSketch(canvas, size, sketch, pitch: kDrillPitchExport);
  final pic = rec.endRecording();
  final img = await pic.toImage(
      (size.width * pixelRatio).round(), (size.height * pixelRatio).round());
  final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
  img.dispose();
  return bytes!.buffer.asUint8List();
}

/// Downloads a picture to draw over, or null if it cannot be loaded.
Future<ui.Image?> loadDrillBackground(String url) async {
  try {
    final r = await http.get(Uri.parse(url));
    if (r.statusCode != 200) return null;
    final codec = await ui.instantiateImageCodec(r.bodyBytes);
    return (await codec.getNextFrame()).image;
  } catch (_) {
    return null;
  }
}

/// The sketch pad tools (web: Draw, Player, Cone, Arrow).
enum DrillTool { draw, player, cone, arrow }

/// Editing state for a [DrillSketchPad]: the tool, the marks and up to 20
/// undo steps.
class DrillSketchController extends ChangeNotifier {
  DrillSketchController({DrillSketch initial = const DrillSketch()})
      : _sketch = initial;

  DrillSketch _sketch;
  DrillTool _tool = DrillTool.draw;
  final List<DrillSketch> _undo = [];
  DrillArrow? _preview;

  DrillSketch get sketch => _sketch;
  DrillTool get tool => _tool;
  DrillArrow? get preview => _preview;
  bool get canUndo => _undo.isNotEmpty;

  /// Something drawn (or a picture underneath): worth saving.
  bool get hasContent => !_sketch.isEmpty;

  set tool(DrillTool t) {
    _tool = t;
    notifyListeners();
  }

  set background(ui.Image? img) {
    _sketch = DrillSketch(marks: _sketch.marks, background: img);
    notifyListeners();
  }

  void _push() {
    _undo.add(_sketch);
    if (_undo.length > 20) _undo.removeAt(0);
  }

  void _setMarks(List<DrillMark> marks) {
    _sketch = DrillSketch(marks: marks, background: _sketch.background);
    notifyListeners();
  }

  /// Pointer down at a normalised point.
  void start(Offset n) {
    switch (_tool) {
      case DrillTool.draw:
        _push();
        _setMarks([
          ..._sketch.marks,
          DrillStroke([n])
        ]);
      case DrillTool.player:
        _push();
        _setMarks([..._sketch.marks, DrillPlayer(n, _sketch.nextPlayerNumber)]);
      case DrillTool.cone:
        _push();
        _setMarks([..._sketch.marks, DrillCone(n)]);
      case DrillTool.arrow:
        _preview = DrillArrow(n, n);
        notifyListeners();
    }
  }

  /// Pointer moved to a normalised point.
  void move(Offset n) {
    if (_tool == DrillTool.draw &&
        _sketch.marks.isNotEmpty &&
        _sketch.marks.last is DrillStroke) {
      final last = _sketch.marks.last as DrillStroke;
      _setMarks([
        ..._sketch.marks.take(_sketch.marks.length - 1),
        DrillStroke([...last.points, n])
      ]);
    } else if (_tool == DrillTool.arrow && _preview != null) {
      _preview = DrillArrow(_preview!.from, n);
      notifyListeners();
    }
  }

  /// Pointer up. An arrow shorter than 8px (at [scaleWidth]) is dropped.
  void end({double scaleWidth = 360, double scaleHeight = 260}) {
    final a = _preview;
    if (a == null) return;
    _preview = null;
    final d = Offset((a.to.dx - a.from.dx) * scaleWidth,
        (a.to.dy - a.from.dy) * scaleHeight);
    if (d.distance > 8) {
      _push();
      _setMarks([..._sketch.marks, a]);
    } else {
      notifyListeners();
    }
  }

  void undo() {
    if (_undo.isEmpty) return;
    _sketch = _undo.removeLast();
    notifyListeners();
  }

  /// Wipes everything, the picture underneath too (as the web Clear does).
  void clear() {
    _undo.clear();
    _sketch = const DrillSketch();
    notifyListeners();
  }
}

/// The interactive sketch pad: the pitch (aspect of the web canvas) and a
/// tool bar with Draw, Player, Cone, Arrow, Undo and Clear.
class DrillSketchPad extends StatelessWidget {
  const DrillSketchPad({super.key, required this.controller});
  final DrillSketchController controller;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: DecoratedBox(
        decoration: BoxDecoration(
            border: Border.all(color: V3.line),
            borderRadius: BorderRadius.circular(14)),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          AspectRatio(
            aspectRatio: kDrillSketchSize.aspectRatio,
            child: LayoutBuilder(builder: (context, box) {
              Offset n(Offset local) => Offset(
                  (local.dx / box.maxWidth).clamp(0.0, 1.0),
                  (local.dy / box.maxHeight).clamp(0.0, 1.0));
              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onPanStart: (d) => controller.start(n(d.localPosition)),
                onPanUpdate: (d) => controller.move(n(d.localPosition)),
                onPanEnd: (_) => controller.end(
                    scaleWidth: box.maxWidth, scaleHeight: box.maxHeight),
                onTapUp: (d) {
                  controller.start(n(d.localPosition));
                  controller.end(
                      scaleWidth: box.maxWidth, scaleHeight: box.maxHeight);
                },
                child: ListenableBuilder(
                  listenable: controller,
                  builder: (_, __) => CustomPaint(
                    size: Size(box.maxWidth, box.maxHeight),
                    painter: DrillSketchPainter(controller.sketch,
                        preview: controller.preview),
                  ),
                ),
              );
            }),
          ),
          Container(
            color: V3.card2,
            padding: const EdgeInsets.all(8),
            child: ListenableBuilder(
              listenable: controller,
              builder: (_, __) => Wrap(spacing: 6, runSpacing: 6, children: [
                for (final t in DrillTool.values)
                  _ToolButton(
                      label: switch (t) {
                        DrillTool.draw => 'Draw',
                        DrillTool.player => 'Player',
                        DrillTool.cone => 'Cone',
                        DrillTool.arrow => 'Arrow',
                      },
                      active: controller.tool == t,
                      onTap: () => controller.tool = t),
                _ToolButton(
                    label: 'Undo',
                    onTap: controller.canUndo ? controller.undo : null),
                _ToolButton(label: 'Clear', onTap: controller.clear),
              ]),
            ),
          ),
        ]),
      ),
    );
  }
}

class _ToolButton extends StatelessWidget {
  const _ToolButton({required this.label, this.active = false, this.onTap});
  final String label;
  final bool active;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: active ? V3.greenTint : V3.card,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(color: active ? V3.green : V3.line)),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 44, minWidth: 60),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Center(
              widthFactor: 1,
              child: Text(label,
                  style: V3.inter(15,
                      weight: FontWeight.w600,
                      color: onTap == null
                          ? V3.barGrey
                          : active
                              ? V3.green
                              : V3.muted)),
            ),
          ),
        ),
      ),
    );
  }
}
