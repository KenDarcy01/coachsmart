// AI drill diagrams, natively: a Dart port of the CSScene engine
// (webviews/cs-scene.js, built from supabase/functions/diagram-to-drawio/
// scene.ts) and of the page's own mxGraph renderer (renderMxGraphToPng in
// webviews/game-upload.html).
//
// The diagram-to-drawio edge function answers with a "scene" (what was drawn
// and where, on a 0..1000 grid) and the mxGraph XML scene.ts made from it. The
// page draws that XML onto a 600 x 600 canvas and uploads the PNG. Here:
//   V3Scene               the scene JSON (kept as received, to send back)
//   sceneToDiagram        scene.ts sceneToXml: the same tidy-up rules (one
//                         standard player size, runs go round cones, players,
//                         cones and lines kept clear of each other, rows lined
//                         up and evenly spaced, mirror symmetry, arrows stop
//                         short of what they meet)
//   parseMxGraphXml       the XML the function returns
//   fixCircleStyles       the page's clean-up for old (non-v2) diagrams
//   V3DiagramPainter      a CustomPainter of a diagram (the page's renderer)
//   renderDiagramPng      the 600 x 600 PNG the page uploads (x pixelRatio)
//   sceneImageSize        width and height of a PNG or JPEG, as scene.ts reads
//                         them, to place a scene on the picture it came from
import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

// ------------------------------------------------------------------ scene

/// A point. Mutable and compared by identity, like the JS objects the
/// engine shares between arrows (a run that turns into a pass shares the
/// joint).
class ScenePt {
  ScenePt(this.x, this.y);
  double x, y;
  ScenePt copy() => ScenePt(x, y);
  void setFrom(ScenePt o) {
    x = o.x;
    y = o.y;
  }

  @override
  String toString() => 'ScenePt($x, $y)';
}

double _num(dynamic v) => v is num ? v.toDouble() : double.nan;

/// One thing drawn: player, coach, ball, cone, goalposts, wall, zone, text.
class SceneItem {
  SceneItem(
      {required this.kind,
      this.label = '',
      this.team = 'none',
      required this.x,
      required this.y,
      this.w = 0,
      this.h = 0});
  factory SceneItem.fromJson(Map m) => SceneItem(
      kind: '${m['kind'] ?? ''}',
      label: m['label'] is String ? m['label'] as String : '',
      team: '${m['team'] ?? 'none'}',
      x: _num(m['x']),
      y: _num(m['y']),
      w: _num(m['w']),
      h: _num(m['h']));
  final String kind, label, team;
  final double x, y, w, h;
}

/// A line: pitch_line, pitch_arc, dotted_line, run, pass or shot.
class SceneLine {
  SceneLine(this.kind, this.points);
  factory SceneLine.fromJson(Map m) => SceneLine('${m['kind'] ?? ''}', [
        for (final p in (m['points'] is List ? m['points'] as List : const []))
          if (p is Map) ScenePt(_num(p['x']), _num(p['y']))
      ]);
  final String kind;
  final List<ScenePt> points;
}

/// The scene diagram-to-drawio describes. [json] is kept exactly as received
/// so "Fix the drawing" can send it back.
class V3Scene {
  V3Scene(
      {this.gameName = '',
      this.sport = 'unknown',
      this.items = const [],
      this.lines = const [],
      this.leftRight = false,
      this.topBottom = false,
      this.tidied = '',
      this.json = const {}});

  factory V3Scene.fromJson(Map m) {
    final sym = m['symmetry'] is Map ? m['symmetry'] as Map : const {};
    return V3Scene(
        gameName: m['game_name'] is String ? m['game_name'] as String : '',
        sport: '${m['sport'] ?? 'unknown'}',
        items: [
          for (final i in (m['items'] is List ? m['items'] as List : const []))
            if (i is Map) SceneItem.fromJson(i)
        ],
        lines: [
          for (final l in (m['lines'] is List ? m['lines'] as List : const []))
            if (l is Map) SceneLine.fromJson(l)
        ],
        leftRight: sym['left_right'] == true,
        topBottom: sym['top_bottom'] == true,
        tidied: m['tidied'] is String ? m['tidied'] as String : '',
        json: Map<String, dynamic>.from(m));
  }

  final String gameName, sport, tidied;
  final List<SceneItem> items;
  final List<SceneLine> lines;
  final bool leftRight, topBottom;
  final Map<String, dynamic> json;
}

/// Width and height of a PNG or JPEG (scene.ts imageSize), or null.
({int w, int h})? sceneImageSize(Uint8List b) {
  try {
    if (b.length > 24 && b[0] == 0x89 && b[1] == 0x50) {
      final w = (b[16] << 24) | (b[17] << 16) | (b[18] << 8) | b[19];
      final h = (b[20] << 24) | (b[21] << 16) | (b[22] << 8) | b[23];
      return w > 0 && h > 0 ? (w: w, h: h) : null;
    }
    if (b.length > 4 && b[0] == 0xff && b[1] == 0xd8) {
      final n = math.min(b.length, 300000);
      var i = 2;
      while (i + 9 < n) {
        if (b[i] != 0xff) {
          i++;
          continue;
        }
        final m = b[i + 1];
        if (m >= 0xc0 && m <= 0xcf && m != 0xc4 && m != 0xc8 && m != 0xcc) {
          final h = (b[i + 5] << 8) | b[i + 6], w = (b[i + 7] << 8) | b[i + 8];
          return w > 0 && h > 0 ? (w: w, h: h) : null;
        }
        i += 2 + ((b[i + 2] << 8) | b[i + 3]);
      }
    }
  } catch (_) {/* fall through */}
  return null;
}

// ---------------------------------------------------------------- diagram

/// One mxGraph cell: a vertex (x, y, w, h) or an edge ([points]: start,
/// bends, end).
class DiagramCell {
  DiagramCell.vertex(this.value, this.style, this.x, this.y, this.w, this.h)
      : edge = false,
        points = const [];
  DiagramCell.edge(this.style, this.points)
      : edge = true,
        value = '',
        x = 0,
        y = 0,
        w = 0,
        h = 0;
  final bool edge;
  final String value;
  String style;
  final double x, y;
  double w, h;
  final List<Offset> points;
}

/// A diagram ready to paint. [v2] = drawn by the scene engine (its circles
/// are never re-coloured).
class V3Diagram {
  V3Diagram(this.cells, {this.v2 = false});
  final List<DiagramCell> cells;
  final bool v2;

  /// The same XML scene.ts writes (used to compare the port with it).
  String toXml() {
    final sb = StringBuffer(
        '<mxGraphModel background="#2E7D32"${v2 ? ' csEngine="v2"' : ''}>'
        '<root><mxCell id="0"/><mxCell id="1" parent="0"/>');
    var id = 2;
    for (final c in cells) {
      if (c.edge) {
        final a = c.points.first, b = c.points.last;
        final mid = c.points.length > 2
            ? '<Array as="points">${c.points.sublist(1, c.points.length - 1).map((p) => '<mxPoint x="${_fmt(p.dx)}" y="${_fmt(p.dy)}"/>').join()}</Array>'
            : '';
        sb.write('<mxCell id="${id++}" value="" style="${c.style}" edge="1" '
            'parent="1"><mxGeometry relative="1" as="geometry"><mxPoint '
            'x="${_fmt(a.dx)}" y="${_fmt(a.dy)}" as="sourcePoint"/><mxPoint '
            'x="${_fmt(b.dx)}" y="${_fmt(b.dy)}" as="targetPoint"/>$mid'
            '</mxGeometry></mxCell>');
      } else {
        sb.write('<mxCell id="${id++}" value="${_esc(c.value)}" '
            'style="${c.style}" vertex="1" parent="1"><mxGeometry '
            'x="${_fmt(c.x)}" y="${_fmt(c.y)}" width="${_fmt(c.w)}" '
            'height="${_fmt(c.h)}" as="geometry"/></mxCell>');
      }
    }
    sb.write('</root></mxGraphModel>');
    return sb.toString();
  }
}

String _esc(String s) => s
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;');

String _unesc(String s) =>
    s.replaceAllMapped(RegExp(r'&(#x[0-9a-fA-F]+|#\d+|amp|lt|gt|quot|apos);'),
        (m) {
      final e = m[1]!;
      switch (e) {
        case 'amp':
          return '&';
        case 'lt':
          return '<';
        case 'gt':
          return '>';
        case 'quot':
          return '"';
        case 'apos':
          return "'";
      }
      final code = e.startsWith('#x')
          ? int.tryParse(e.substring(2), radix: 16)
          : int.tryParse(e.substring(1));
      return code == null ? m[0]! : String.fromCharCode(code);
    });

/// JS Number to string for the values scene.ts writes (12, 12.5, -3.2).
String _fmt(double v) =>
    v == v.roundToDouble() && v.abs() < 1e15 ? '${v.toInt()}' : '$v';

/// JS Math.round (halves go up).
double _jsRound(double n) => (n + 0.5).floorToDouble();
double _r1(double n) => _jsRound(n * 10) / 10;

/// Reads the mxGraph XML diagram-to-drawio returns, or null if it has no
/// cells.
V3Diagram? parseMxGraphXml(String xml) {
  Map<String, String> attrs(String s) => {
        for (final m in RegExp(r'([\w:-]+)\s*=\s*"([^"]*)"').allMatches(s))
          m[1]!: _unesc(m[2]!)
      };
  double n(Map<String, String> a, String k) => double.tryParse(a[k] ?? '') ?? 0;
  final v2 = RegExp(r'<mxGraphModel\b[^>]*\bcsEngine="v2"').hasMatch(xml);
  final cells = <DiagramCell>[];
  for (final m in RegExp(r'<mxCell\b([^>]*?)(?:/>|>([\s\S]*?)</mxCell>)')
      .allMatches(xml)) {
    final a = attrs(m[1]!);
    final inner = m[2] ?? '';
    final style = a['style'] ?? '';
    if (a['vertex'] == '1') {
      final g = RegExp(r'<mxGeometry\b([^>]*?)/?>').firstMatch(inner);
      if (g == null) continue;
      final ga = attrs(g[1]!);
      cells.add(DiagramCell.vertex(a['value'] ?? '', style, n(ga, 'x'),
          n(ga, 'y'), n(ga, 'width'), n(ga, 'height')));
    } else if (a['edge'] == '1') {
      Offset? src, tgt;
      final way = <Offset>[];
      final arr = RegExp(r'<Array\b[^>]*as="points"[^>]*>([\s\S]*?)</Array>')
          .firstMatch(inner);
      final rest =
          arr == null ? inner : inner.replaceRange(arr.start, arr.end, '');
      for (final p in RegExp(r'<mxPoint\b([^>]*?)/?>').allMatches(rest)) {
        final pa = attrs(p[1]!);
        final o = Offset(n(pa, 'x'), n(pa, 'y'));
        if (pa['as'] == 'sourcePoint') src = o;
        if (pa['as'] == 'targetPoint') tgt = o;
      }
      if (arr != null) {
        for (final p in RegExp(r'<mxPoint\b([^>]*?)/?>').allMatches(arr[1]!)) {
          final pa = attrs(p[1]!);
          way.add(Offset(n(pa, 'x'), n(pa, 'y')));
        }
      }
      // The page skips an edge without both ends.
      if (src == null || tgt == null) continue;
      cells.add(DiagramCell.edge(style, [src, ...way, tgt]));
    }
  }
  return cells.isEmpty ? null : V3Diagram(cells, v2: v2);
}

/// The page's fixCircleStylesClient: in an old (non-v2) diagram an empty
/// circle is a ball and a lettered one is the coach. Numbered players keep
/// their colour.
V3Diagram fixCircleStyles(V3Diagram d) {
  if (d.v2) return d;
  const football =
      'ellipse;whiteSpace=wrap;html=1;aspect=fixed;fillColor=#ffffff;strokeColor=#555555;shadow=0;';
  const coach =
      'ellipse;whiteSpace=wrap;html=1;aspect=fixed;fontSize=15;fontStyle=1;fillColor=#1a1a1a;gradientColor=#3a3a3a;gradientDirection=north;strokeColor=#000000;shadow=1;fontColor=#ffffff;';
  for (final c in d.cells) {
    if (!c.style.contains('ellipse')) continue;
    final v = c.value.trim();
    if (RegExp(r'^\d+$').hasMatch(v)) continue;
    if (v == '' || v == '.' || v == '·' || v == '•') {
      c.style = football;
      c.w = 24;
      c.h = 24;
    } else {
      c.style = coach;
    }
  }
  return d;
}

// ------------------------------------------------------- scene -> diagram

const _sBg = 'fillColor=#2E7D32;strokeColor=none;';
const _sHome =
    'ellipse;whiteSpace=wrap;html=1;aspect=fixed;fontSize=15;fontStyle=1;fillColor=#C62828;gradientColor=#EF5350;gradientDirection=north;strokeColor=#B71C1C;shadow=1;fontColor=#ffffff;';
const _sAway =
    'ellipse;whiteSpace=wrap;html=1;aspect=fixed;fontSize=15;fontStyle=1;fillColor=#1565C0;gradientColor=#42A5F5;gradientDirection=north;strokeColor=#0D47A1;shadow=1;fontColor=#ffffff;';
const _sCoach =
    'ellipse;whiteSpace=wrap;html=1;aspect=fixed;fontSize=15;fontStyle=1;fillColor=#1a1a1a;gradientColor=#3a3a3a;gradientDirection=north;strokeColor=#000000;shadow=1;fontColor=#ffffff;';
const _sBall =
    'ellipse;whiteSpace=wrap;html=1;aspect=fixed;fillColor=#ffffff;strokeColor=#555555;shadow=0;';
const _sCone =
    'triangle;direction=north;whiteSpace=wrap;html=1;fillColor=#FF6D00;gradientColor=#FFAB40;gradientDirection=north;strokeColor=#E65100;shadow=1;';
const _sGoal = 'gaa_goalpost;whiteSpace=wrap;html=1;';
const _sWall =
    'rounded=0;whiteSpace=wrap;html=1;fillColor=#455A64;strokeColor=#B0BEC5;strokeWidth=3;fontColor=#ffffff;fontSize=16;fontStyle=1;';
const _sZone =
    'rounded=0;whiteSpace=wrap;html=1;fillColor=#ffffff;opacity=12;strokeColor=#ffffff;strokeWidth=1.5;fontColor=#ffffff;fontSize=13;fontStyle=1;';
const _sText =
    'text;html=1;align=left;verticalAlign=middle;strokeColor=none;fillColor=none;fontColor=#ffffff;fontSize=13;fontStyle=1;';
const _sLine =
    'edgeStyle=none;html=1;endArrow=none;endFill=0;strokeColor=#ffffff;strokeWidth=1.5;opacity=50;';
const _sDotted =
    'edgeStyle=none;html=1;endArrow=none;endFill=0;dashed=1;dashPattern=6 6;strokeColor=#ffffff;strokeWidth=1.5;opacity=50;';
const _sArc =
    'edgeStyle=none;curved=1;html=1;endArrow=none;endFill=0;strokeColor=#ffffff;strokeWidth=1.5;opacity=50;';
const _sRun =
    'edgeStyle=none;html=1;endArrow=block;endFill=1;strokeColor=#ffffff;strokeWidth=2.5;';
const _sRunCurve =
    'edgeStyle=none;curved=1;html=1;endArrow=block;endFill=1;strokeColor=#ffffff;strokeWidth=2.5;';
const _sPass =
    'edgeStyle=none;html=1;endArrow=open;endFill=0;dashed=1;dashPattern=8 4;strokeColor=#FFD700;strokeWidth=2.5;';
const _sPassCurve =
    'edgeStyle=none;curved=1;html=1;endArrow=open;endFill=0;dashed=1;dashPattern=8 4;strokeColor=#FFD700;strokeWidth=2.5;';
const _sShot =
    'edgeStyle=none;html=1;endArrow=block;endFill=1;csShot=1;strokeColor=#FFD700;strokeWidth=3.5;';
const _sShotCurve =
    'edgeStyle=none;curved=1;html=1;endArrow=block;endFill=1;csShot=1;strokeColor=#FFD700;strokeWidth=3.5;';

/// Every player and coach is drawn this size (Ken, 2026-11-10).
const double kScenePlayerSize = 44;

double _hypot(double x, double y) => math.sqrt(x * x + y * y);
double _dist(ScenePt a, ScenePt b) => _hypot(a.x - b.x, a.y - b.y);
double _or(double v, double d) => (v.isNaN || v == 0) ? d : v;
double _get(ScenePt p, String k) => k == 'x' ? p.x : p.y;
void _set(ScenePt p, String k, double v) {
  if (k == 'x') {
    p.x = v;
  } else {
    p.y = v;
  }
}

/// A stable sort (JS Array.sort is stable; Dart's is not guaranteed).
List<T> _stable<T>(Iterable<T> list, int Function(T a, T b) cmp) {
  final idx = list.toList().asMap().entries.toList()
    ..sort((a, b) {
      final c = cmp(a.value, b.value);
      return c != 0 ? c : a.key - b.key;
    });
  return [for (final e in idx) e.value];
}

int _cmpNum(double a, double b) => a < b ? -1 : (a > b ? 1 : 0);

class _Side {
  const _Side(this.d, this.nx, this.ny, this.inside);
  final double d, nx, ny;
  final bool inside;
}

_Side _lineSide(ScenePt p, ScenePt a, ScenePt b) {
  final dx = b.x - a.x, dy = b.y - a.y;
  var len = _hypot(dx, dy);
  if (len == 0 || len.isNaN) len = 1;
  final nx = -dy / len, ny = dx / len;
  final t = ((p.x - a.x) * dx + (p.y - a.y) * dy) / (len * len);
  return _Side(
      (p.x - a.x) * nx + (p.y - a.y) * ny, nx, ny, t > -0.02 && t < 1.02);
}

void _alignAxis(List<ScenePt> pts, String key, double tol, double sep,
    double span, Set<ScenePt> solid) {
  final other = key == 'x' ? 'y' : 'x';
  final groups = <List<ScenePt>>[];
  double mean(List<ScenePt> g) =>
      g.fold<double>(0, (t, q) => t + _get(q, key)) / g.length;
  for (final p
      in _stable(pts, (a, b) => _cmpNum(_get(a, other), _get(b, other)))) {
    List<ScenePt>? home;
    for (final g in groups) {
      if ((mean(g) - _get(p, key)).abs() <= tol &&
          g.any((q) => (_get(q, other) - _get(p, other)).abs() <= span) &&
          !(solid.contains(p) &&
              g.any((q) {
                if (!solid.contains(q)) return false;
                final after = (_get(q, other) - _get(p, other)).abs();
                return after < sep && after < _dist(q, p) - 2;
              }))) {
        home = g;
        break;
      }
    }
    if (home != null) {
      home.add(p);
    } else {
      groups.add([p]);
    }
  }
  for (final g in groups) {
    if (g.length >= 2) {
      final m = mean(g);
      for (final p in g) {
        _set(p, key, m);
      }
    }
  }
}

List<ScenePt> _simplifyPath(List<ScenePt> pts, [double slack = 0.04]) {
  if (pts.length <= 2) return pts;
  final a = pts.first, b = pts.last, len = _dist(a, b);
  if (len < 1) return pts;
  final ok =
      pts.every((p) => _lineSide(p, a, b).d.abs() < math.max(4, len * slack));
  return ok ? [a, b] : pts;
}

class _Feature {
  _Feature(this.kind, this.pts, this.tol);
  final String kind;
  final List<ScenePt> pts;
  final double tol;
}

int _symmetrise(List<_Feature> features, String key, double axis,
    [bool dry = false]) {
  ScenePt refl(ScenePt p) =>
      key == 'x' ? ScenePt(2 * axis - p.x, p.y) : ScenePt(p.x, 2 * axis - p.y);
  int Function(int) order(int n, bool rev) => (i) => rev ? n - 1 - i : i;
  final cands = <({_Feature f, _Feature g, double cost, bool rev})>[];
  for (final f in features) {
    for (final g in features) {
      if (f.kind != g.kind || f.pts.length != g.pts.length) continue;
      for (final rev in [false, true]) {
        final o = order(f.pts.length, rev);
        var cost = double.negativeInfinity;
        for (var i = 0; i < f.pts.length; i++) {
          cost = math.max(cost, _dist(refl(f.pts[i]), g.pts[o(i)]));
        }
        if (cost < math.min(f.tol, g.tol)) {
          cands.add((f: f, g: g, cost: cost, rev: rev));
        }
      }
    }
  }
  final sorted = _stable(cands, (a, b) => _cmpNum(a.cost, b.cost));
  final done = <_Feature>{};
  for (final c in sorted) {
    final f = c.f, g = c.g;
    if (done.contains(f) || done.contains(g)) continue;
    if (dry) {
      done.add(f);
      done.add(g);
      continue;
    }
    final o = order(f.pts.length, c.rev);
    final next = [
      for (var i = 0; i < f.pts.length; i++)
        () {
          final p = f.pts[i], q = refl(g.pts[o(i)]);
          return ScenePt((p.x + q.x) / 2, (p.y + q.y) / 2);
        }()
    ];
    if (identical(f, g)) {
      for (var i = 0; i < next.length; i++) {
        f.pts[i].setFrom(next[i]);
      }
    } else {
      for (var i = 0; i < next.length; i++) {
        f.pts[i].setFrom(next[i]);
      }
      for (var i = 0; i < next.length; i++) {
        g.pts[o(i)].setFrom(refl(next[i]));
      }
    }
    done.add(f);
    done.add(g);
  }
  return done.length;
}

void _evenOut(List<({String kind, ScenePt p})> groups, List<ScenePt> everything,
    String key, double minGap) {
  final other = key == 'x' ? 'y' : 'x';
  final rows = <String, List<ScenePt>>{};
  for (final g in groups) {
    final k = '${g.kind}|${_jsRound(_get(g.p, other) * 100).toInt()}';
    rows.putIfAbsent(k, () => []).add(g.p);
  }
  final moves = <(double, double)>[];
  for (final row0 in rows.values) {
    if (row0.length < 3) continue;
    final row = _stable(row0, (a, b) => _cmpNum(_get(a, key), _get(b, key)));
    final first = _get(row.first, key), last = _get(row.last, key);
    final step = (last - first) / (row.length - 1);
    if (step < minGap) continue;
    var uneven = false;
    for (var i = 1; i < row.length; i++) {
      final g = _get(row[i], key) - _get(row[i - 1], key);
      if (g < step * 0.7 || g > step * 1.3) uneven = true;
    }
    if (uneven) continue;
    for (var i = 0; i < row.length; i++) {
      moves.add((_get(row[i], key), first + i * step));
    }
  }
  if (moves.isEmpty) return;
  for (final p in everything) {
    for (final m in moves) {
      if ((_get(p, key) - m.$1).abs() < 0.01) {
        _set(p, key, m.$2);
        break;
      }
    }
  }
}

List<ScenePt> _smoothPath(List<ScenePt> pts) {
  if (pts.length <= 2) return pts;
  final a = pts.first, b = pts.last, L = _dist(a, b);
  if (L < 1) return pts;
  final ux = (b.x - a.x) / L, uy = (b.y - a.y) / L;
  ScenePt at(double t, double d) =>
      ScenePt(a.x + ux * t - uy * d, a.y + uy * t + ux * d);
  final td = [
    for (final p in pts)
      (
        t: (p.x - a.x) * ux + (p.y - a.y) * uy,
        d: -(p.x - a.x) * uy + (p.y - a.y) * ux
      )
  ];
  // A run that doubles back or loops (round a cone and back) is kept as
  // drawn.
  var pathLen = 0.0;
  for (var i = 1; i < pts.length; i++) {
    pathLen += _dist(pts[i - 1], pts[i]);
  }
  if (pathLen > L * 1.8 || td.any((q) => q.t < -L * 0.08 || q.t > L * 1.08)) {
    return pts;
  }
  final ext = <({double t, double d})>[];
  for (var i = 0; i < td.length - 2; i++) {
    final q = td[i + 1];
    bool peak(({double t, double d}) n) =>
        n.d.sign != q.d.sign || q.d.abs() >= n.d.abs() - 0.5;
    if (q.d.abs() > L * 0.04 && peak(td[i]) && peak(td[i + 2])) ext.add(q);
  }
  final swings = <({double t, double d})>[];
  for (final q in ext) {
    if (swings.isNotEmpty && swings.last.d.sign == q.d.sign) {
      if (q.d.abs() > swings.last.d.abs()) swings[swings.length - 1] = q;
    } else {
      swings.add(q);
    }
  }
  if (swings.isEmpty) return [a, b];
  if (swings.length == 1) {
    final apex = at(swings[0].t, swings[0].d);
    final mid = ScenePt((a.x + b.x) / 2, (a.y + b.y) / 2);
    return [a, ScenePt(2 * apex.x - mid.x, 2 * apex.y - mid.y), b];
  }
  final amp = swings.fold<double>(0, (t, q) => t + q.d.abs()) / swings.length;
  final t0 = swings.first.t, t1 = swings.last.t, n = swings.length;
  return [
    a,
    for (var i = 0; i < n; i++)
      at(n > 1 ? t0 + ((t1 - t0) * i) / (n - 1) : swings[i].t,
          swings[i].d.sign * amp * 1.35),
    b
  ];
}

class _Arrow {
  _Arrow(this.kind, this.pts);
  final String kind;
  List<ScenePt> pts;
}

class _Circle {
  _Circle(this.p, this.orig, this.kind, this.item);
  ScenePt p;
  final ScenePt orig;
  final String kind;
  final SceneItem item;
}

class _Attach {
  _Attach(this.to, this.cone, this.dx, this.dy);
  final ScenePt to, cone;
  final double dx, dy;
}

class _Box {
  _Box(this.x0, this.x1, this.y0, this.y1, this.wall);
  final double x0, x1, y0, y1;
  final bool wall;
}

/// scene.ts sceneToXml: lays out [scene] (positions on a 0..1000 grid over
/// an [imgW] x [imgH] picture) with fixed sizes and styles.
V3Diagram sceneToDiagram(V3Scene scene, num imgW0, num imgH0) {
  final imgW = imgW0.toDouble(), imgH = imgH0.toDouble();
  const canvas = 700.0, pad = 34.0;
  ScenePt toPx(double x, double y) =>
      ScenePt((x / 1000) * imgW, (y / 1000) * imgH);

  final items =
      scene.items.where((it) => it.x.isFinite && it.y.isFinite).toList();
  final lines = scene.lines
      .map((l) => SceneLine(
          l.kind, l.points.where((p) => p.x.isFinite && p.y.isFinite).toList()))
      .where((l) => l.points.length >= 2)
      .toList();

  var minX = double.infinity, minY = double.infinity;
  var maxX = double.negativeInfinity, maxY = double.negativeInfinity;
  void grow(ScenePt p, [double hw = 0, double hh = 0]) {
    minX = math.min(minX, p.x - hw);
    maxX = math.max(maxX, p.x + hw);
    minY = math.min(minY, p.y - hh);
    maxY = math.max(maxY, p.y + hh);
  }

  for (final it in items) {
    grow(toPx(it.x, it.y), (_or(it.w, 0) / 2000) * imgW,
        (_or(it.h, 0) / 2000) * imgH);
  }
  for (final l in lines) {
    for (final p in l.points) {
      grow(toPx(p.x, p.y));
    }
  }
  if (!minX.isFinite) {
    minX = 0;
    minY = 0;
    maxX = imgW;
    maxY = imgH;
  }
  final bw = math.max(maxX - minX, 1.0), bh = math.max(maxY - minY, 1.0);
  final s = (canvas - 2 * pad) / math.max(bw, bh);
  final cw = _jsRound(bw * s + 2 * pad), ch = _jsRound(bh * s + 2 * pad);
  ScenePt map(double x, double y) {
    final q = toPx(x, y);
    return ScenePt((q.x - minX) * s + pad, (q.y - minY) * s + pad);
  }

  ScenePt mapPt(ScenePt p) => map(p.x, p.y);
  ({double w, double h}) mapLen(double w, double h) =>
      (w: (w / 1000) * imgW * s, h: (h / 1000) * imgH * s);

  List<ScenePt> squareUp(SceneLine l) {
    final a = mapPt(l.points.first), b = mapPt(l.points.last);
    final dx = (b.x - a.x).abs(), dy = (b.y - a.y).abs();
    if (dx > 0 && dy / dx < 0.09) {
      final y = (a.y + b.y) / 2;
      a.y = y;
      b.y = y;
    } else if (dy > 0 && dx / dy < 0.09) {
      final x = (a.x + b.x) / 2;
      a.x = x;
      b.x = x;
    }
    return [a, b];
  }

  final straight =
      lines.where((l) => l.kind == 'pitch_line').map(squareUp).toList();
  final dotted = lines
      .where((l) => l.kind == 'dotted_line' && l.points.length >= 2)
      .map((l) {
    final pts = _simplifyPath(l.points.map(mapPt).toList(), 0.1);
    return pts.length == 2 ? squareUp(l) : pts;
  }).toList();
  final level = straight.where((l) => l[0].y == l[1].y).toList();
  final upright = straight.where((l) => l[0].x == l[1].x).toList();
  ScenePt join(ScenePt p, bool ontoLevel, [double reach = 18]) {
    if (ontoLevel) {
      for (final l in level) {
        final a = l[0], b = l[1];
        if ((p.y - a.y).abs() < reach &&
            p.x >= math.min(a.x, b.x) - reach &&
            p.x <= math.max(a.x, b.x) + reach) {
          p.y = a.y;
          break;
        }
      }
    } else {
      for (final l in upright) {
        final a = l[0], b = l[1];
        if ((p.x - a.x).abs() < reach &&
            p.y >= math.min(a.y, b.y) - reach &&
            p.y <= math.max(a.y, b.y) + reach) {
          p.x = a.x;
          break;
        }
      }
    }
    return p;
  }

  for (final seg in straight) {
    final a = seg[0], b = seg[1], reach = math.min(18.0, _dist(a, b) * 0.4);
    if (upright.contains(seg)) {
      join(a, true, reach);
      join(b, true, reach);
    } else if (level.contains(seg)) {
      join(a, false, reach);
      join(b, false, reach);
    }
  }

  final pos = <SceneItem, ScenePt>{for (final it in items) it: map(it.x, it.y)};
  bool isPerson(SceneItem it) => it.kind == 'player' || it.kind == 'coach';
  final arrows = lines
      .where((l) => l.kind == 'run' || l.kind == 'pass' || l.kind == 'shot')
      .map((l) => _Arrow(
          l.kind,
          _simplifyPath(
              l.points.map(mapPt).toList(), l.kind == 'run' ? 0.04 : 0.1)))
      .toList();
  final arcs = lines.where((l) => l.kind == 'pitch_arc').map((l) {
    final pts = l.points.map(mapPt).toList();
    return pts.length >= 3
        ? [pts.first, pts[pts.length ~/ 2], pts.last]
        : [pts.first, pts.last];
  }).toList();
  final people = items.where(isPerson).map((it) => pos[it]!).toList();
  var gap = double.infinity;
  for (var i = 0; i < people.length; i++) {
    for (var j = i + 1; j < people.length; j++) {
      gap = math.min(gap, _dist(people[i], people[j]));
    }
  }
  final d0 = math.max(28.0, math.min(42.0, gap.isFinite ? gap * 0.95 : 40.0));
  final tol = math.max(14.0, d0 * 0.6), sep = d0 * 0.9;

  // An arrow that starts where another ends stays joined to it.
  final chained = <_Arrow?>[
    for (final a in arrows)
      () {
        for (final b in arrows) {
          if (!identical(b, a) && _dist(b.pts.last, a.pts.first) < 6) return b;
        }
        return null;
      }()
  ];
  void relink() {
    for (var i = 0; i < arrows.length; i++) {
      final b = chained[i];
      if (b != null) arrows[i].pts[0] = b.pts.last;
    }
  }

  relink();

  // 1. Symmetry.
  final attached = <SceneItem, _Attach>{};
  for (final it in items) {
    if (it.kind != 'cone' && it.kind != 'ball') continue;
    final p = pos[it]!;
    ScenePt? best;
    var bd = d0 * 1.6;
    for (final q in people) {
      final d = _dist(p, q);
      if (d < bd) {
        bd = d;
        best = q;
      }
    }
    if (best != null) {
      attached[it] = _Attach(best, p, p.x - best.x, p.y - best.y);
    }
  }
  for (final key in const ['x', 'y']) {
    if (!(key == 'x' ? scene.leftRight : scene.topBottom)) continue;
    final frame = <ScenePt>[
      for (final l in straight) ...l,
      for (final l in arcs) ...l,
      for (final l in dotted) ...l,
      for (final it in items)
        if (const ['cone', 'goalposts', 'wall', 'zone'].contains(it.kind))
          pos[it]!,
    ];
    final ref = frame.length >= 2 ? frame : pos.values.toList();
    if (ref.length < 2) continue;
    final lo = ref.map((p) => _get(p, key)).reduce(math.min);
    final hi = ref.map((p) => _get(p, key)).reduce(math.max);
    final w = hi - lo;
    if (w < 60) continue;
    final loose = w * 0.09, tight = w * 0.07;
    final axis = (lo + hi) / 2;
    final personFeatures = [
      for (final it in items.where(isPerson))
        _Feature('${it.kind}:${it.team}', [pos[it]!], tight)
    ];
    final offCentre = [
      for (final f in personFeatures)
        if ((_get(f.pts[0], key) - axis).abs() > tight * 1.5)
          _Feature(f.kind, [f.pts[0].copy()], f.tol)
    ];
    final peopleMirror = offCentre.isEmpty ||
        _symmetrise(offCentre, key, axis, true) >= offCentre.length * 0.6;
    final features = <_Feature>[
      for (final l in straight) _Feature('line', l, loose),
      for (final l in arcs) _Feature('arc', l, loose),
      for (final l in dotted) _Feature('dotted', l, loose),
      for (final it in items)
        if (!isPerson(it) && (peopleMirror || !attached.containsKey(it)))
          _Feature(it.kind, [pos[it]!], loose),
      if (peopleMirror) ...personFeatures,
      if (peopleMirror)
        for (final a in arrows)
          _Feature(a.kind, [a.pts.first, a.pts.last], loose),
    ];
    _symmetrise(features, key, axis);
  }
  attached.forEach((it, a) {
    final p = pos[it]!, want = ScenePt(a.to.x + a.dx, a.to.y + a.dy);
    if (_dist(p, want) > d0 * 0.5) p.setFrom(want);
  });
  for (final l in arcs) {
    join(l.first, true, 12);
    join(l.last, true, 12);
  }

  // 5a. Arrows land on the player they point at (never on a cone).
  final joints = <ScenePt>{
    for (var i = 0; i < arrows.length; i++)
      if (chained[i] != null) arrows[i].pts.first
  };
  final targets = items.where(isPerson).map((it) => pos[it]!).toList();
  final landed = <ScenePt, ScenePt>{};
  void land(ScenePt end, ScenePt from) {
    if (joints.contains(end)) return;
    final len = _dist(from, end);
    if (len < 1) return;
    final dx = (end.x - from.x) / len, dy = (end.y - from.y) / len;
    ScenePt? best;
    var bd = d0 * 1.6;
    for (final t in targets) {
      final d = _dist(t, end), ft = _dist(from, t);
      if (d >= bd || ft < d0 * 0.8) continue;
      if (((t.x - from.x) * dx + (t.y - from.y) * dy) / ft <
          math.cos(math.pi / 6)) {
        continue;
      }
      best = t;
      bd = d;
    }
    if (best != null) {
      end.setFrom(best);
      landed[end] = best;
    }
  }

  for (final a in arrows) {
    final n = a.pts.length;
    if (a.kind != 'shot') land(a.pts[n - 1], a.pts[n - 2]);
    land(a.pts[0], a.pts[1]);
  }
  // 2b. Players linked by a nearly level or upright arrow are put exactly so.
  for (final a in arrows) {
    if (a.pts.length != 2) continue;
    final t0 = landed[a.pts[0]], t1 = landed[a.pts[1]];
    if (t0 == null || t1 == null || identical(t0, t1)) continue;
    final dx = (t1.x - t0.x).abs(), dy = (t1.y - t0.y).abs();
    final key = dx < dy * 0.1
        ? 'x'
        : dy < dx * 0.1
            ? 'y'
            : null;
    if (key == null) continue;
    final m = (_get(t0, key) + _get(t1, key)) / 2;
    for (final t in [t0, t1]) {
      final d = m - _get(t, key);
      for (final at in attached.values) {
        if (identical(at.to, t)) _set(at.cone, key, _get(at.cone, key) + d);
      }
      _set(t, key, m);
    }
  }
  landed.forEach((end, t) => end.setFrom(t));

  // 2 + 4. Line up rows and columns, then space even rows exactly evenly.
  final solid = <ScenePt>{
    for (final it in items)
      if (const ['player', 'coach', 'cone', 'ball'].contains(it.kind)) pos[it]!
  };
  final arrowEnds = [
    for (var i = 0; i < arrows.length; i++)
      ...(chained[i] != null
          ? [arrows[i].pts.last]
          : [arrows[i].pts.first, arrows[i].pts.last])
  ];
  final pool = <ScenePt>{...solid, ...arrowEnds}.toList();
  _alignAxis(pool, 'x', tol, sep, d0 * 4, solid);
  _alignAxis(pool, 'y', tol, sep, d0 * 4, solid);
  final kinds = [
    for (final it in items)
      if (solid.contains(pos[it]))
        (kind: it.kind == 'coach' ? 'player' : it.kind, p: pos[it]!)
  ];
  _evenOut(kinds, pool, 'x', d0);
  _evenOut(kinds, pool, 'y', d0);
  relink();

  void straighten() {
    for (var k = 0; k < 4; k++) {
      for (final a in arrows) {
        if (a.pts.length != 2) continue;
        final p = a.pts[0], q = a.pts[1];
        final dx = (q.x - p.x).abs(), dy = (q.y - p.y).abs();
        if (dy > 0 && dx / dy < 0.1) {
          final v = (p.x + q.x) / 2;
          p.x = v;
          q.x = v;
        } else if (dx > 0 && dy / dx < 0.1) {
          final v = (p.y + q.y) / 2;
          p.y = v;
          q.y = v;
        }
      }
    }
  }

  straighten();

  // 5b. Arrows side by side at nearly the same angle are made parallel.
  double ang(_Arrow a) =>
      math.atan2(a.pts[1].y - a.pts[0].y, a.pts[1].x - a.pts[0].x);
  final twoPt = arrows.where((a) => a.pts.length == 2).toList();
  final paired = <_Arrow>{};
  for (final a in twoPt) {
    for (final b in twoPt) {
      if (identical(a, b) ||
          paired.contains(a) ||
          paired.contains(b) ||
          a.kind != b.kind) {
        continue;
      }
      var d = ang(b) - ang(a);
      while (d > math.pi / 2) {
        d -= math.pi;
      }
      while (d < -math.pi / 2) {
        d += math.pi;
      }
      if (d.abs() > (8 * math.pi) / 180 || d.abs() < 1e-6) continue;
      for (final (x, turn) in [(a, d / 2), (b, -d / 2)]) {
        final p = x.pts[0], q = x.pts[1];
        final mx = (p.x + q.x) / 2, my = (p.y + q.y) / 2;
        final c = math.cos(turn), sn = math.sin(turn);
        for (final pt in [p, q]) {
          final rx = pt.x - mx, ry = pt.y - my;
          pt.setFrom(ScenePt(mx + rx * c - ry * sn, my + rx * sn + ry * c));
        }
      }
      paired.add(a);
      paired.add(b);
    }
  }

  // Matching arrows get the same length.
  final straightArrows = [
    for (var i = 0; i < arrows.length; i++)
      if (arrows[i].pts.length == 2 && chained[i] == null) arrows[i]
  ];
  final used = <_Arrow>{};
  ({double x, double y}) dir(_Arrow x) => (
        x: _jsRound(x.pts[1].x - x.pts[0].x).sign,
        y: _jsRound(x.pts[1].y - x.pts[0].y).sign
      );
  double len(_Arrow x) => _dist(x.pts[0], x.pts[1]);
  for (final a in straightArrows) {
    if (used.contains(a)) continue;
    final da = dir(a);
    final group = straightArrows.where((b) {
      final db = dir(b);
      return !used.contains(b) &&
          b.kind == a.kind &&
          db.x == da.x &&
          db.y == da.y &&
          (da.x == 0
              ? (b.pts[0].y - a.pts[0].y).abs() < tol
              : da.y == 0
                  ? (b.pts[0].x - a.pts[0].x).abs() < tol
                  : false) &&
          len(b) > len(a) * 0.6 &&
          len(b) < len(a) * 1.65;
    }).toList();
    used.addAll(group);
    if (group.length < 2) continue;
    final lens = group.map(len).toList()..sort();
    final l0 = lens[group.length ~/ 2];
    for (final b in group) {
      final p = b.pts[0], q = b.pts[1];
      var l = len(b);
      if (l == 0 || l.isNaN) l = 1;
      q.setFrom(
          ScenePt(p.x + ((q.x - p.x) / l) * l0, p.y + ((q.y - p.y) / l) * l0));
    }
  }
  straighten();

  // 3. Smooth curved runs and passes.
  for (final a in arrows) {
    if (a.pts.length > 2) a.pts = _smoothPath(a.pts);
  }

  // Balls and cones drawn touching are spread just far enough apart.
  final small = [
    for (final it in items)
      if (it.kind == 'ball' || it.kind == 'cone') pos[it]!
  ];
  final ballGap = d0 * 0.62;
  for (var pass = 0; pass < 3; pass++) {
    for (var i = 0; i < small.length; i++) {
      for (var j = i + 1; j < small.length; j++) {
        final a = small[i], b = small[j], d = _dist(a, b);
        if (d >= ballGap) continue;
        final ux = d > 0.01 ? (b.x - a.x) / d : 1.0;
        final uy = d > 0.01 ? (b.y - a.y) / d : 0.0;
        final k = (ballGap - d) / 2;
        a.x -= ux * k;
        a.y -= uy * k;
        b.x += ux * k;
        b.y += uy * k;
      }
    }
  }

  // Players and coaches: one standard size; crowded ones are pushed apart.
  final circles = [
    for (final it in items.where(isPerson))
      _Circle(pos[it]!.copy(), pos[it]!.copy(), it.kind, it)
  ];
  const dd = kScenePlayerSize;

  // Keep circles clear of each other, then on their own side of every
  // straight line (lines win last).
  final keepOff = <List<ScenePt>>[
    ...straight,
    for (final l in dotted)
      if (l.length == 2) [l.first, l.last]
  ];
  final coneSpots = [
    for (final it in items)
      if (it.kind == 'cone') pos[it]!
  ];
  void settle(double r) {
    for (final c in circles) {
      c.p = c.orig.copy();
    }
    for (var pass = 0; pass < 6; pass++) {
      for (var i = 0; i < circles.length; i++) {
        for (var j = i + 1; j < circles.length; j++) {
          final a = circles[i], b = circles[j], d = _dist(a.p, b.p);
          final need = 2 * r + 8;
          if (d >= need) continue;
          final ux = d > 0.01 ? (b.p.x - a.p.x) / d : 1.0;
          final uy = d > 0.01 ? (b.p.y - a.p.y) / d : 0.0;
          final k = (need - d) / 2;
          a.p = ScenePt(a.p.x - ux * k, a.p.y - uy * k);
          b.p = ScenePt(b.p.x + ux * k, b.p.y + uy * k);
        }
      }
      for (final c in circles) {
        for (final l in keepOff) {
          final o = _lineSide(c.orig, l[0], l[1]);
          final now = _lineSide(c.p, l[0], l[1]);
          if (!now.inside || now.d.abs() >= r + 7) continue;
          final side = o.d >= 0 ? 1 : -1;
          final push = side * (r + 7) - now.d;
          c.p = ScenePt(c.p.x + push * now.nx, c.p.y + push * now.ny);
        }
      }
    }
  }

  settle(dd / 2);
  // A cone too close to a player moves away from it, taking the end of any
  // dotted line that meets it.
  for (var pass = 0; pass < 4; pass++) {
    for (final k in coneSpots) {
      for (final c in circles) {
        final d = _dist(c.p, k), need = dd / 2 + 25;
        if (d >= need) continue;
        final ux = d > 0.01 ? (k.x - c.p.x) / d : 1.0;
        final uy = d > 0.01 ? (k.y - c.p.y) / d : 0.0;
        final nk = ScenePt(c.p.x + ux * need, c.p.y + uy * need);
        final dx = nk.x - k.x, dy = nk.y - k.y;
        for (final l in dotted) {
          for (final q in [l.first, l.last]) {
            if (_dist(q, k) < 24) {
              q.x += dx;
              q.y += dy;
            }
          }
        }
        k.setFrom(nk);
      }
    }
  }

  final cells = <DiagramCell>[];
  void vertex(
          String value, String style, double x, double y, double w, double h) =>
      cells.add(
          DiagramCell.vertex(value, style, _r1(x), _r1(y), _r1(w), _r1(h)));
  void edge(String style, List<ScenePt> pts) => cells.add(DiagramCell.edge(
      style, [for (final p in pts) Offset(_r1(p.x), _r1(p.y))]));

  vertex('', _sBg, 0, 0, cw, ch);

  // Zones and walls first so everything else draws on top.
  for (final it in items) {
    if (it.kind != 'zone' && it.kind != 'wall') continue;
    final wall = it.kind == 'wall';
    final c = map(it.x, it.y);
    final sz = mapLen(_or(it.w, 80), _or(it.h, wall ? 30 : 80));
    vertex(wall ? 'WALL' : it.label, wall ? _sWall : _sZone, c.x - sz.w / 2,
        c.y - sz.h / 2, sz.w, math.max(sz.h, wall ? 28 : 10));
  }

  // Pitch markings.
  for (final l in straight) {
    edge(_sLine, l);
  }
  for (final l in dotted) {
    edge(
        l.length > 2
            ? _sDotted.replaceFirst(
                'edgeStyle=none;', 'edgeStyle=none;curved=1;')
            : _sDotted,
        l);
  }
  for (final l in arcs) {
    edge(l.length == 3 ? _sArc : _sLine, l);
  }

  // Shots: an end near the goalposts goes exactly over (a point) or under
  // (a goal) the bar.
  final posts = [
    for (final it in items)
      if (it.kind == 'goalposts')
        () {
          final c = pos[it]!, sz = mapLen(_or(it.w, 60), _or(it.h, 80));
          final gw = math.max(sz.w, 40.0), gh = math.max(sz.h, 40.0);
          final top = c.y - gh / 2;
          return (x: c.x, top: top, bar: top + gh * 0.55, gw: gw, gh: gh);
        }()
  ];
  for (final a in arrows) {
    if (a.kind != 'shot' || posts.isEmpty) continue;
    final end = a.pts.last;
    var g = posts.first;
    var gd = double.infinity;
    for (final p in posts) {
      final d = _dist(end, ScenePt(p.x, (p.top + p.bar) / 2));
      if (d < gd) {
        gd = d;
        g = p;
      }
    }
    if (gd > math.max(g.gw, g.gh) * 1.5) continue;
    end.x = g.x;
    end.y = end.y < g.bar
        ? g.top + g.gh * 0.28
        : g.bar + (g.gh - g.gh * 0.55) * 0.45;
  }

  // Runs and passes stop short of the circles they start or finish at.
  const gapEnd = 11.0;
  final ends = <({ScenePt p, double r})>[
    for (final c in circles) (p: c.p, r: dd / 2),
    for (final it in items)
      if (it.kind == 'cone' || it.kind == 'ball') (p: pos[it]!, r: 12.0),
  ];
  ScenePt trim(ScenePt end, ScenePt toward) {
    ({ScenePt p, double r})? best;
    var bd = double.infinity;
    for (final e in ends) {
      final d = _dist(e.p, end);
      if (d < bd) {
        bd = d;
        best = e;
      }
    }
    if (best == null || bd > best.r + 14) return end;
    if (_dist(toward, best.p) < best.r + 10) return end;
    var len = _dist(toward, end);
    if (len == 0 || len.isNaN) len = 1;
    final ux = (toward.x - end.x) / len, uy = (toward.y - end.y) / len;
    final wx = best.p.x - end.x, wy = best.p.y - end.y;
    final proj = wx * ux + wy * uy;
    final r = best.r + gapEnd, perp2 = wx * wx + wy * wy - proj * proj;
    if (perp2 >= r * r) return end;
    final s = proj + math.sqrt(r * r - perp2);
    return s > 0 && s < len - 10
        ? ScenePt(end.x + ux * s, end.y + uy * s)
        : end;
  }

  // Walls and zones: an arrow end running into one stops short of its edge.
  final boxes = [
    for (final it in items)
      if (it.kind == 'wall' || it.kind == 'zone')
        () {
          final wall = it.kind == 'wall';
          final c = map(it.x, it.y);
          final sz = mapLen(_or(it.w, 80), _or(it.h, wall ? 30 : 80));
          final hh = math.max(sz.h, wall ? 28.0 : 10.0);
          return _Box(
              c.x - sz.w / 2, c.x + sz.w / 2, c.y - hh / 2, c.y + hh / 2, wall);
        }()
  ];
  bool near(ScenePt p, _Box b, double m) =>
      p.x > b.x0 - m && p.x < b.x1 + m && p.y > b.y0 - m && p.y < b.y1 + m;
  ScenePt offBox(ScenePt end, ScenePt toward) {
    for (final b in boxes) {
      if (!near(end, b, 8) || near(toward, b, 8)) continue;
      if (!b.wall && near(end, b, -8)) continue;
      var len = _dist(toward, end);
      if (len == 0 || len.isNaN) len = 1;
      final ux = (toward.x - end.x) / len, uy = (toward.y - end.y) / len;
      var s = 0.0;
      while (
          s < len - 12 && near(ScenePt(end.x + ux * s, end.y + uy * s), b, 8)) {
        s += 1;
      }
      return ScenePt(end.x + ux * s, end.y + uy * s);
    }
    return end;
  }

  final feeds = <_Arrow>{
    for (final b in chained)
      if (b != null) b
  };
  ScenePt back(ScenePt end, ScenePt toward, double by) {
    final len = _dist(toward, end);
    if (len < by * 3) return end;
    return ScenePt(end.x + ((toward.x - end.x) / len) * by,
        end.y + ((toward.y - end.y) / len) * by);
  }

  // Runs and passes that go past a cone go round it, never through it.
  List<ScenePt> roundCones(List<ScenePt> pts) {
    const clear = 36.0;
    var out = [for (final p in pts) p.copy()];
    for (final c in coneSpots) {
      if (_dist(c, out.first) < clear + 8 || _dist(c, out.last) < clear + 8) {
        continue;
      }
      for (var k = 1; k < out.length - 1; k++) {
        final d = _dist(out[k], c);
        if (d >= clear) continue;
        var nx = out[k].x - c.x, ny = out[k].y - c.y;
        if (d < 0.5) {
          nx = -(out[k + 1].y - out[k - 1].y);
          ny = out[k + 1].x - out[k - 1].x;
        }
        var l = _hypot(nx, ny);
        if (l == 0 || l.isNaN) l = 1;
        out[k] = ScenePt(c.x + (nx / l) * clear, c.y + (ny / l) * clear);
      }
      var bi = -1;
      var bd = double.infinity;
      var bq = c;
      for (var i = 0; i < out.length - 1; i++) {
        final a = out[i], b = out[i + 1];
        var l = _dist(a, b);
        if (l == 0 || l.isNaN) l = 1;
        final t =
            (((c.x - a.x) * (b.x - a.x) + (c.y - a.y) * (b.y - a.y)) / (l * l))
                .clamp(0.0, 1.0);
        final q = ScenePt(a.x + (b.x - a.x) * t, a.y + (b.y - a.y) * t);
        final d = _dist(q, c);
        if (d < bd) {
          bd = d;
          bi = i;
          bq = q;
        }
      }
      if (bi < 0 || bd >= clear * 0.9) continue;
      var nx = bq.x - c.x, ny = bq.y - c.y, nl = _hypot(nx, ny);
      if (nl < 0.5) {
        final a = out[bi], b = out[bi + 1];
        var l = _dist(a, b);
        if (l == 0 || l.isNaN) l = 1;
        nx = -(b.y - a.y) / l;
        ny = (b.x - a.x) / l;
        nl = 1;
      }
      out = [
        ...out.sublist(0, bi + 1),
        ScenePt(c.x + (nx / nl) * clear, c.y + (ny / nl) * clear),
        ...out.sublist(bi + 1)
      ];
    }
    return out;
  }

  for (var i = 0; i < arrows.length; i++) {
    final a = arrows[i];
    final pts = a.kind == 'shot'
        ? [for (final p in a.pts) p.copy()]
        : roundCones(a.pts);
    final n = pts.length;
    final joinStart = chained[i] != null, joinEnd = feeds.contains(a);
    ScenePt fix(ScenePt end, ScenePt toward, bool joint) {
      final t = trim(end, toward);
      return joint && identical(t, end)
          ? back(end, toward, 12)
          : offBox(t, toward);
    }

    pts[0] = fix(pts[0], pts[1], joinStart);
    pts[n - 1] = fix(pts[n - 1], pts[n - 2], joinEnd);
    var touchesNext = false, touchesPrev = false;
    for (var j = 0; j < arrows.length; j++) {
      if (j == i) continue;
      if (_dist(pts[n - 1], arrows[j].pts.first) < 20) touchesNext = true;
    }
    if (touchesNext) pts[n - 1] = back(pts[n - 1], pts[n - 2], 10);
    for (var j = 0; j < arrows.length; j++) {
      if (j == i) continue;
      if (_dist(pts[0], arrows[j].pts.last) < 20) touchesPrev = true;
    }
    if (touchesPrev) pts[0] = back(pts[0], pts[1], 8);
    final curved = pts.length > 2;
    edge(
        a.kind == 'shot'
            ? (curved ? _sShotCurve : _sShot)
            : a.kind == 'pass'
                ? (curved ? _sPassCurve : _sPass)
                : (curved ? _sRunCurve : _sRun),
        pts);
  }

  // Equipment, then people on top.
  for (final it in items) {
    final c = pos[it]!;
    if (it.kind == 'goalposts') {
      final sz = mapLen(_or(it.w, 60), _or(it.h, 80));
      final gw = math.max(sz.w, 40.0), gh = math.max(sz.h, 40.0);
      vertex('', _sGoal, c.x - gw / 2, c.y - gh / 2, gw, gh);
    } else if (it.kind == 'cone') {
      final w = _jsRound(dd * 0.6), h = _jsRound(dd * 0.7);
      vertex('', _sCone, c.x - w / 2, c.y - h / 2, w, h);
    } else if (it.kind == 'ball') {
      final b = _jsRound(dd * 0.55);
      vertex('', _sBall, c.x - b / 2, c.y - b / 2, b, b);
    } else if (it.kind == 'text' && it.label.trim().isNotEmpty) {
      final label = it.label.trim();
      final want = math.max(60.0, label.length * 8.0);
      final tw = math.min(want, cw - 8), wrap = want > tw;
      final tx = math.min(math.max(c.x - 10, 4.0), cw - tw - 4);
      final th = wrap ? 36.0 : 20.0;
      vertex(label, wrap ? '${_sText}whiteSpace=wrap;' : _sText, tx,
          math.min(math.max(c.y - th / 2, 2.0), ch - th - 2), tw, th);
    }
  }
  for (final c in circles) {
    final style = c.kind == 'coach'
        ? _sCoach
        : c.item.team == 'away'
            ? _sAway
            : _sHome;
    var label = c.kind == 'coach' ? 'C' : c.item.label.trim();
    if (label.length > 3) label = label.substring(0, 3);
    vertex(label, style, c.p.x - dd / 2, c.p.y - dd / 2, dd, dd);
  }
  return V3Diagram(cells, v2: true);
}

// ---------------------------------------------------------------- painting

/// Size the page draws every diagram at (then x devicePixelRatio).
const double kDiagramOut = 600;
const Color kDiagramPitch = Color(0xFF2E7D32);

Color? _css(String? s) {
  if (s == null) return null;
  var v = s.trim().toLowerCase();
  switch (v) {
    case 'white':
      return const Color(0xFFFFFFFF);
    case 'black':
      return const Color(0xFF000000);
  }
  if (!v.startsWith('#')) return null;
  v = v.substring(1);
  if (v.length == 3) v = v.split('').map((c) => '$c$c').join();
  if (v.length != 6) return null;
  final n = int.tryParse(v, radix: 16);
  return n == null ? null : Color(0xFF000000 | n);
}

String? _styleVal(String style, String key) =>
    RegExp('(?:^|;)$key=([^;,\\s]+)').firstMatch(style)?[1];

void _text(Canvas c, String text, Offset at,
    {required double size,
    required Color color,
    bool centre = true,
    String? family}) {
  final tp = TextPainter(
      text: TextSpan(
          text: text,
          style: TextStyle(
              color: color,
              fontSize: size,
              fontWeight: FontWeight.bold,
              fontFamily: family)),
      textDirection: TextDirection.ltr,
      maxLines: 1)
    ..layout();
  final dx = centre ? at.dx - tp.width / 2 : at.dx;
  tp.paint(c, Offset(dx, at.dy - tp.height / 2));
}

Path _dashed(Path src, List<double> pattern) {
  final out = Path();
  for (final m in src.computeMetrics()) {
    var d = 0.0, i = 0;
    while (d < m.length) {
      final len = pattern[i % pattern.length];
      if (i.isEven)
        out.addPath(m.extractPath(d, math.min(d + len, m.length)), Offset.zero);
      d += len;
      i++;
    }
  }
  return out;
}

/// Paints [d] the way the page's renderMxGraphToPng does, on a
/// [kDiagramOut] square (scale the canvas for other sizes).
void paintDiagram(Canvas canvas, V3Diagram d) {
  const out = kDiagramOut;
  var cW = 600.0, cH = 600.0;
  for (final c in d.cells) {
    if (!c.edge && c.style.contains('fillColor=#2E7D32')) {
      cW = (c.w.isNaN || c.w == 0) ? 600 : c.w;
      cH = (c.h.isNaN || c.h == 0) ? 600 : c.h;
      break;
    }
  }
  canvas.drawRect(
      const Rect.fromLTWH(0, 0, out, out), Paint()..color = kDiagramPitch);
  canvas.drawPath(
      _dashed(
          Path()
            ..moveTo(0, out / 2)
            ..lineTo(out, out / 2),
          [8, 6]),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = const Color(0x1AFFFFFF));
  final s = math.min(out / cW, out / cH);
  final offX = (out - cW * s) / 2, offY = (out - cH * s) / 2;
  for (final c in d.cells) {
    if (c.edge) _paintEdge(canvas, c, s, offX, offY);
  }
  for (final c in d.cells) {
    if (c.edge || c.style.contains('fillColor=#2E7D32')) continue;
    final x = c.x * s + offX, y = c.y * s + offY, w = c.w * s, h = c.h * s;
    final st = c.style, val = c.value;
    if (st.contains('gaa_goalpost')) {
      _paintGoalpost(canvas, x, y, w, h);
    } else if (st.contains('ellipse')) {
      final cx = x + w / 2, cy = y + h / 2, rx = w / 2, ry = h / 2;
      final fc = (_styleVal(st, 'fillColor') ?? '#C62828').toLowerCase();
      final coach = fc.contains('1a1a1a') || fc == '#000000' || fc == '#000';
      final ball = fc.contains('ffffff') || fc == '#fff';
      final blue = fc.contains('1565c0') ||
          fc.contains('42a5f5') ||
          fc.contains('0d47a1');
      final (Color c0, Color c1, Color edge) = coach
          ? (
              const Color(0xFF3A3A3A),
              const Color(0xFF1A1A1A),
              const Color(0xFF000000)
            )
          : ball
              ? (
                  const Color(0xFFFFFFFF),
                  const Color(0xFFD8D8D8),
                  const Color(0xFF555555)
                )
              : blue
                  ? (
                      const Color(0xFF42A5F5),
                      const Color(0xFF1565C0),
                      const Color(0xFF0D47A1)
                    )
                  : (
                      const Color(0xFFEF5350),
                      const Color(0xFFC62828),
                      const Color(0xFFB71C1C)
                    );
      final oval = Rect.fromCenter(
          center: Offset(cx, cy), width: rx * 2, height: ry * 2);
      canvas.drawOval(
          oval,
          Paint()
            ..color = const Color(0x80000000)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3.5));
      canvas.drawOval(
          oval,
          Paint()
            ..shader = ui.Gradient.radial(
                Offset(cx, cy),
                rx,
                [c0, c1],
                null,
                TileMode.clamp,
                null,
                Offset(cx - rx * 0.25, cy - ry * 0.25),
                rx * 0.05));
      canvas.drawOval(
          oval,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2
            ..color = edge);
      if (val.isNotEmpty) {
        _text(canvas, val, Offset(cx, cy),
            size: math.max(10, _jsRound(w * 0.36)),
            color: ball ? const Color(0xFF333333) : Colors.white);
      }
    } else if (st.contains('triangle')) {
      final path = Path()
        ..moveTo(x + w / 2, y)
        ..lineTo(x + w, y + h)
        ..lineTo(x, y + h)
        ..close();
      canvas.drawPath(
          path,
          Paint()
            ..color = const Color(0x66000000)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.5));
      canvas.drawPath(
          path,
          Paint()
            ..shader = ui.Gradient.linear(Offset(x, y + h), Offset(x, y),
                const [Color(0xFFFF6D00), Color(0xFFFFAB40)]));
      canvas.drawPath(
          path,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5
            ..color = const Color(0xFFE65100));
    } else if (st.contains('text;')) {
      final fs = double.tryParse(_styleVal(st, 'fontSize') ?? '') ?? 12;
      _text(canvas, val, Offset(x, y + h / 2),
          size: fs,
          color: _css(_styleVal(st, 'fontColor')) ?? Colors.white,
          centre: false);
    } else {
      // Plain rectangle: wall, zone, labelled box.
      final op = int.tryParse(_styleVal(st, 'opacity') ?? '');
      final fcS = _styleVal(st, 'fillColor'),
          scS = _styleVal(st, 'strokeColor');
      // A colour the canvas cannot read leaves the last one set (the pitch
      // fill, the faint halfway stroke).
      final fill =
          fcS == null ? const Color(0xFF37474F) : (_css(fcS) ?? kDiagramPitch);
      final stroke = scS == null
          ? const Color(0xFF90A4AE)
          : (_css(scS) ?? const Color(0x1AFFFFFF));
      final r = Rect.fromLTWH(x, y, w, h);
      canvas.drawRect(r,
          Paint()..color = fill.withValues(alpha: op != null ? op / 100 : 1));
      canvas.drawRect(
          r,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth =
                double.tryParse(_styleVal(st, 'strokeWidth') ?? '') ?? 1.5
            ..color = stroke);
      if (val.isNotEmpty) {
        _text(canvas, val, Offset(x + w / 2, y + h / 2),
            size: double.tryParse(_styleVal(st, 'fontSize') ?? '') ?? 13,
            color: _css(_styleVal(st, 'fontColor')) ?? Colors.white);
      }
    }
  }
}

double _normAngle(double a) {
  const tau = 2 * math.pi;
  final r = a % tau;
  return r < 0 ? r + tau : r;
}

void _paintEdge(
    Canvas canvas, DiagramCell cell, double s, double offX, double offY) {
  if (cell.points.length < 2) return;
  Offset m(Offset p) => Offset(p.dx * s + offX, p.dy * s + offY);
  final a = m(cell.points.first), b = m(cell.points.last);
  final way = [
    for (final p in cell.points.sublist(1, cell.points.length - 1)) m(p)
  ];
  final st = cell.style;
  final dashed = st.contains('dashed=1'), curved = st.contains('curved=1');
  final arrow = !st.contains('endArrow=none');
  final shot = arrow && st.contains('csShot=1');
  const yellow = Color(0xFFFFD700);
  final colour = shot
      ? yellow
      : dashed && arrow
          ? yellow
          : dashed
              ? const Color(0x73FFFFFF)
              : Colors.white;
  final width = !arrow
      ? 1.5
      : shot
          ? 3.5
          : 2.5;
  final path = Path()..moveTo(a.dx, a.dy);
  if (!arrow && curved && way.isNotEmpty) {
    // Pitch arc: a true circle through start, middle and end.
    final all = [a, ...way, b];
    final p1 = all.first, pm = all[all.length ~/ 2], p2 = all.last;
    final ax = p2.dx - p1.dx, ay = p2.dy - p1.dy;
    final bx = pm.dx - p1.dx, by = pm.dy - p1.dy;
    final dd = 2 * (ax * by - ay * bx);
    if (dd.abs() > 0.01) {
      final ux = (by * (ax * ax + ay * ay) - ay * (bx * bx + by * by)) / dd;
      final uy = (ax * (bx * bx + by * by) - bx * (ax * ax + ay * ay)) / dd;
      final acx = p1.dx + ux,
          acy = p1.dy + uy,
          r = math.sqrt(ux * ux + uy * uy);
      final a1 = math.atan2(p1.dy - acy, p1.dx - acx);
      final a2 = math.atan2(p2.dy - acy, p2.dx - acx);
      final cross =
          (pm.dx - p1.dx) * (p2.dy - pm.dy) - (pm.dy - p1.dy) * (p2.dx - pm.dx);
      final sweep = cross < 0 ? -_normAngle(a1 - a2) : _normAngle(a2 - a1);
      path.arcTo(Rect.fromCircle(center: Offset(acx, acy), radius: r), a1,
          sweep, false);
    } else {
      path.lineTo(b.dx, b.dy);
    }
  } else if (curved && way.isNotEmpty) {
    // Movement arrow: Chaikin smoothing.
    var pts = [a, ...way, b];
    for (var k = 0; k < 3; k++) {
      final n = [pts.first];
      for (var i = 0; i < pts.length - 1; i++) {
        n.add(pts[i] * 0.75 + pts[i + 1] * 0.25);
        n.add(pts[i] * 0.25 + pts[i + 1] * 0.75);
      }
      n.add(pts.last);
      pts = n;
    }
    for (final p in pts) {
      path.lineTo(p.dx, p.dy);
    }
  } else {
    for (final w in way) {
      path.lineTo(w.dx, w.dy);
    }
    path.lineTo(b.dx, b.dy);
  }
  final paint = Paint()
    ..style = PaintingStyle.stroke
    ..color = colour
    ..strokeWidth = width
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;
  canvas.drawPath(
      dashed ? _dashed(path, arrow ? const [8, 4] : const [6, 6]) : path,
      paint);
  if (!arrow) return;
  final f = way.isNotEmpty ? way.last : a;
  final angle = math.atan2(b.dy - f.dy, b.dx - f.dx), hl = shot ? 17.0 : 13.0;
  final l = Offset(b.dx - hl * math.cos(angle - math.pi / 7),
      b.dy - hl * math.sin(angle - math.pi / 7));
  final r = Offset(b.dx - hl * math.cos(angle + math.pi / 7),
      b.dy - hl * math.sin(angle + math.pi / 7));
  if (!dashed || shot) {
    canvas.drawPath(
        Path()
          ..moveTo(b.dx, b.dy)
          ..lineTo(l.dx, l.dy)
          ..lineTo(r.dx, r.dy)
          ..close(),
        Paint()..color = shot ? colour : Colors.white);
  } else {
    canvas.drawPath(
        Path()
          ..moveTo(l.dx, l.dy)
          ..lineTo(b.dx, b.dy)
          ..lineTo(r.dx, r.dy),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..color = colour);
  }
}

void _paintGoalpost(Canvas c, double x, double y, double w, double h) {
  final post = math.max(3.0, math.min(6.0, w * 0.045));
  final cbY = y + h * 0.55, goalH = y + h - cbY;
  final sInset = w * .10, sRise = goalH * .38, backBarY = cbY - sRise;
  c.drawRect(Rect.fromLTWH(x, cbY, w, goalH),
      Paint()..color = const Color(0x33000000));
  final net = Paint()
    ..color = const Color(0x47FFFFFF)
    ..strokeWidth = 0.8;
  final cols = math.max(4, _jsRound(w / 14).toInt());
  final rows = math.max(3, _jsRound(goalH / 12).toInt());
  for (var i = 1; i < cols; i++) {
    final nx = x + (w / cols) * i;
    c.drawLine(Offset(nx, cbY), Offset(nx, y + h), net);
  }
  for (var i = 1; i < rows; i++) {
    final ny = cbY + (goalH / rows) * i;
    c.drawLine(Offset(x, ny), Offset(x + w, ny), net);
  }
  final side = Paint()
    ..color = const Color(0x8CFFFFFF)
    ..strokeWidth = math.max(1.5, post * .55)
    ..strokeCap = StrokeCap.round;
  c.drawLine(Offset(x, cbY), Offset(x + sInset, backBarY), side);
  c.drawLine(Offset(x + w, cbY), Offset(x + w - sInset, backBarY), side);
  c.drawLine(
      Offset(x + sInset, backBarY), Offset(x + w - sInset, backBarY), side);
  final frame = [
    (Offset(x, y), Offset(x, y + h)),
    (Offset(x + w, y), Offset(x + w, y + h)),
    (Offset(x, cbY), Offset(x + w, cbY)),
  ];
  final shadow = Paint()
    ..color = const Color(0x66000000)
    ..strokeWidth = post
    ..strokeCap = StrokeCap.square
    ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);
  final white = Paint()
    ..color = Colors.white
    ..strokeWidth = post
    ..strokeCap = StrokeCap.square;
  for (final (p, q) in frame) {
    c.drawLine(p, q, shadow);
  }
  for (final (p, q) in frame) {
    c.drawLine(p, q, white);
  }
  c.drawLine(
      Offset(x, y + h), Offset(x + w, y + h), white..strokeWidth = post * .7);
}

/// A CustomPainter of a diagram, scaled to fit a square.
class V3DiagramPainter extends CustomPainter {
  const V3DiagramPainter(this.diagram);
  final V3Diagram diagram;

  @override
  void paint(Canvas canvas, Size size) {
    final side = math.min(size.width, size.height);
    canvas.save();
    canvas.translate((size.width - side) / 2, (size.height - side) / 2);
    canvas.scale(side / kDiagramOut);
    paintDiagram(canvas, diagram);
    canvas.restore();
  }

  @override
  bool shouldRepaint(V3DiagramPainter old) => old.diagram != diagram;
}

/// The PNG the page uploads: 600 x 600 at [pixelRatio] (the page uses the
/// device pixel ratio, or 2).
Future<Uint8List> renderDiagramPng(V3Diagram d, {double pixelRatio = 2}) async {
  final rec = ui.PictureRecorder();
  final canvas = Canvas(rec);
  canvas.scale(pixelRatio);
  paintDiagram(canvas, d);
  final pic = rec.endRecording();
  final px = (kDiagramOut * pixelRatio).round();
  final img = await pic.toImage(px, px);
  final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
  img.dispose();
  pic.dispose();
  return bytes!.buffer.asUint8List();
}

/// The diagram to draw from a diagram-to-drawio answer: its XML (as the
/// page does), else the scene laid out here on an [imgW] x [imgH] picture
/// (1000 x 1000 when drawn from words, as the function does).
V3Diagram? diagramFromAnswer(
    {String? xml, Map? scene, int imgW = 1000, int imgH = 1000}) {
  final parsed = xml == null ? null : parseMxGraphXml(xml);
  if (parsed != null) return fixCircleStyles(parsed);
  if (scene != null && scene['items'] is List) {
    return sceneToDiagram(V3Scene.fromJson(scene), imgW, imgH);
  }
  return null;
}

/// JSON of a scene's items and lines, to tell whether a redraw changed it.
String sceneShape(Map? scene) =>
    jsonEncode({'i': scene?['items'], 'l': scene?['lines']});
