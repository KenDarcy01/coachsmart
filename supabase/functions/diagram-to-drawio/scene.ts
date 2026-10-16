// Sketch → diagram, v2 ("scene") engine.
//
// The model only describes what is drawn and where (a JSON "scene"). This file turns
// that scene into mxGraph XML with fixed sizes and styles, so every diagram looks the
// same however the coach drew it (circles, stick men, X's), and nothing is squashed:
// the drawing keeps its own shape and circles are sized to fit the gaps between lines.
//
// Pure functions only (no Deno APIs) so it can be tested locally with Node.

export const SCENE_PROMPT = `You are reading a coach's hand-drawn GAA (Gaelic football, hurling, camogie) training drill. It is either a photo of a drawing on paper or a sketch made on a phone. Describe every element that is drawn, and exactly where it is. Another program draws the final diagram from your description, so you only need to say what each thing is and where it sits.

COORDINATES
Use a grid over the whole image: x runs from 0 (left edge of the image) to 1000 (right edge), y runs from 0 (top edge) to 1000 (bottom edge). The grid is stretched to the image, so 1000 across and 1000 down are not the same physical length. Place each item at the centre of where it is drawn, and measure carefully: the relative positions of players, lines and zones are what make the diagram right.

ITEMS (the "items" list)
- player: anything that stands for a person who is not the coach. Coaches draw players in many ways: a circle with a number, a stick man, a matchstick figure, an X, a dot or a letter, usually with a number in it or written beside it. label = that number or letters exactly as written ("" if there is none). Never treat a stick man or X as anything other than a player.
- coach: a circle or figure labelled C, or the word Coach. label = "C".
- ball: a small empty circle or "o" with nothing in it. A stack of touching small circles (it can look like an "8" with no number meaning) is several balls: output one ball per circle.
- cone: a triangle.
- goalposts: an H shape or two uprights with a crossbar. x, y = centre of the shape; w = distance between the uprights; h = from the top of the uprights down to where they meet the ground or end line.
- wall: a wide, shallow bar or rectangle used as a training wall (labelled "wall", or arrows point at it from below). x, y = centre; w, h = its size.
- zone: a rectangle or area with a written label inside it (for example "Zone A", "Grid", "Box"), or a shaded area. x, y = centre; w, h = its size; label = the written label ("" if shaded and unlabelled). An unlabelled rectangle drawn with plain lines is not a zone: output its sides as pitch_line entries instead.
- text: a short handwritten word or label that belongs on the diagram (for example "Start", "Finish", "Defenders"). label = the text.
For items with no size, set w and h to 0. For items that are not players, set team to "none".

TEAMS (players only)
- If the drawing shows two teams (different shading or colours, or players drawn in pairs side by side, or numbered pairs that face each other such as 2 and 15, 3 and 14, 6 and 11), set team to "home" for one side and "away" for the other. In a pair, the player with the lower number is "home".
- In GAA, numbers that sum to 17 are usually direct opponents (2 v 15, 3 v 14, 5 v 12), and two players with the same number side by side are drill opponents (one home, one away).
- If all players belong to one group, set every player to "home".

LINES (the "lines" list)
- pitch_line: a solid straight line with no arrowhead that marks the pitch or an area: end lines, side lines, the 13m, 20m, 45m and 65m lines, halfway, box sides, and any short marker line. Give 2 points, one at each end, following the line as drawn (lines that stop before the edge stop there too).
- pitch_arc: a curved pitch marking with no arrowhead (the small D in front of goal, the large arc, a centre circle). Give 3 points: the start, the point of the arc furthest from the straight line between start and end, and the end.
- run: a solid line with an arrowhead, meaning a player moves. Give 2 to 12 points tracing the path from where it starts to the arrowhead. For curved or wavy lines, put a point at every bend so the shape is kept.
- pass: a dashed or dotted line with an arrowhead, meaning a kick, hand pass or strike. Same points rule as run, except that a pass the coach was clearly trying to draw straight (wobbly but heading one way) is straight: give just its 2 ends.
- dotted_line: a dashed or dotted line with no arrowhead (for example a halfway or marker line drawn dotted). Output the whole dotted line as ONE entry, never one entry per dash, even where it runs behind a goal, cone or player. If the coach was trying to draw it straight, give just its 2 ends; only give more points if it is clearly meant to curve.

WHAT TO IGNORE
- Faint marks that are not drawn on this page: dents or impressions from writing on a sheet above, ink showing through from the back of the page (often mirrored), shadows, creases, the paper edge, the table, fingers. Only describe pen, pencil or marker strokes clearly drawn on this page.
- A title: free-standing words above or outside the diagram with no box around it. Put it in game_name instead ("" if there is no title). A rectangle with "WALL" or a label inside is a diagram element, not a title.
- Written instructions or notes beside the diagram (for example "split into groups of 4"). Do not output them, but use them to understand the drawing.

SYMMETRY
Coaches draw by hand, so lines wobble and shapes come out lopsided. Say what the coach meant, not the wobble:
- symmetry.left_right: true when the layout is meant to be the same on the left and right of an upright centre line. Most pitch drawings are (goals, boxes, D and arc centred between the sidelines), as are drills set out as a square, rectangle or mirrored lanes of cones and players. false when the two sides are meant to differ (for example attackers on one side only, or a single channel off to one side).
- symmetry.top_bottom: the same idea for a level centre line (for example a full pitch with a goal at each end, or a square of cones). false for a half pitch with one goal.
When unsure, use false.

SPORT
Set sport to "hurling" if hurleys, sliotars, a wall-ball setup, or the words hurling or camogie appear; "football" if the drawing or its writing clearly says football; otherwise "unknown".

Before answering, scan the whole image from top to bottom twice and check that every player, ball, cone, line and arrow is in your answer.`;

const POINT = {
  type: "object",
  properties: { x: { type: "number" }, y: { type: "number" } },
  required: ["x", "y"],
  additionalProperties: false,
};

export const SCENE_SCHEMA = {
  type: "object",
  properties: {
    game_name: { type: "string" },
    sport: { type: "string", enum: ["football", "hurling", "unknown"] },
    items: {
      type: "array",
      items: {
        type: "object",
        properties: {
          kind: { type: "string", enum: ["player", "coach", "ball", "cone", "goalposts", "wall", "zone", "text"] },
          label: { type: "string" },
          team: { type: "string", enum: ["home", "away", "none"] },
          x: { type: "number" },
          y: { type: "number" },
          w: { type: "number" },
          h: { type: "number" },
        },
        required: ["kind", "label", "team", "x", "y", "w", "h"],
        additionalProperties: false,
      },
    },
    lines: {
      type: "array",
      items: {
        type: "object",
        properties: {
          kind: { type: "string", enum: ["pitch_line", "pitch_arc", "dotted_line", "run", "pass"] },
          points: { type: "array", items: POINT },
        },
        required: ["kind", "points"],
        additionalProperties: false,
      },
    },
    symmetry: {
      type: "object",
      properties: { left_right: { type: "boolean" }, top_bottom: { type: "boolean" } },
      required: ["left_right", "top_bottom"],
      additionalProperties: false,
    },
  },
  required: ["game_name", "sport", "items", "lines", "symmetry"],
  additionalProperties: false,
};

export type Pt = { x: number; y: number };
export type SceneItem = {
  kind: "player" | "coach" | "ball" | "cone" | "goalposts" | "wall" | "zone" | "text";
  label: string; team: "home" | "away" | "none";
  x: number; y: number; w: number; h: number;
};
export type SceneLine = { kind: "pitch_line" | "pitch_arc" | "dotted_line" | "run" | "pass"; points: Pt[] };
export type Scene = { game_name: string; sport: "football" | "hurling" | "unknown"; items: SceneItem[]; lines: SceneLine[];
  symmetry?: { left_right: boolean; top_bottom: boolean } };

// ── Image size (PNG / JPEG header) ───────────────────────────────────────────
// The model gives positions on a 0–1000 grid stretched over the image, so we need the
// real width and height to keep the drawing's true shape.
export function imageSize(base64: string): { w: number; h: number } | null {
  try {
    const bin = atob(base64.slice(0, 400000));
    const b = (i: number) => bin.charCodeAt(i);
    if (b(0) === 0x89 && b(1) === 0x50) {                       // PNG: IHDR at byte 16
      const w = (b(16) << 24) | (b(17) << 16) | (b(18) << 8) | b(19);
      const h = (b(20) << 24) | (b(21) << 16) | (b(22) << 8) | b(23);
      return w > 0 && h > 0 ? { w, h } : null;
    }
    if (b(0) === 0xff && b(1) === 0xd8) {                       // JPEG: walk to a SOFn marker
      let i = 2;
      while (i + 9 < bin.length) {
        if (b(i) !== 0xff) { i++; continue; }
        const m = b(i + 1);
        if (m >= 0xc0 && m <= 0xcf && m !== 0xc4 && m !== 0xc8 && m !== 0xcc) {
          const h = (b(i + 5) << 8) | b(i + 6), w = (b(i + 7) << 8) | b(i + 8);
          return w > 0 && h > 0 ? { w, h } : null;
        }
        i += 2 + ((b(i + 2) << 8) | b(i + 3));
      }
    }
  } catch (_) { /* fall through */ }
  return null;
}

// ── Styles (the renderer in webviews/game-upload.html reads these) ───────────
const S = {
  bg:       "fillColor=#2E7D32;strokeColor=none;",
  home:     "ellipse;whiteSpace=wrap;html=1;aspect=fixed;fontSize=15;fontStyle=1;fillColor=#C62828;gradientColor=#EF5350;gradientDirection=north;strokeColor=#B71C1C;shadow=1;fontColor=#ffffff;",
  away:     "ellipse;whiteSpace=wrap;html=1;aspect=fixed;fontSize=15;fontStyle=1;fillColor=#1565C0;gradientColor=#42A5F5;gradientDirection=north;strokeColor=#0D47A1;shadow=1;fontColor=#ffffff;",
  coach:    "ellipse;whiteSpace=wrap;html=1;aspect=fixed;fontSize=15;fontStyle=1;fillColor=#1a1a1a;gradientColor=#3a3a3a;gradientDirection=north;strokeColor=#000000;shadow=1;fontColor=#ffffff;",
  ball:     "ellipse;whiteSpace=wrap;html=1;aspect=fixed;fillColor=#ffffff;strokeColor=#555555;shadow=0;",
  cone:     "triangle;direction=north;whiteSpace=wrap;html=1;fillColor=#FF6D00;gradientColor=#FFAB40;gradientDirection=north;strokeColor=#E65100;shadow=1;",
  goal:     "gaa_goalpost;whiteSpace=wrap;html=1;",
  wall:     "rounded=0;whiteSpace=wrap;html=1;fillColor=#455A64;strokeColor=#B0BEC5;strokeWidth=3;fontColor=#ffffff;fontSize=16;fontStyle=1;",
  zone:     "rounded=0;whiteSpace=wrap;html=1;fillColor=#ffffff;opacity=12;strokeColor=#ffffff;strokeWidth=1.5;fontColor=#ffffff;fontSize=13;fontStyle=1;",
  text:     "text;html=1;align=left;verticalAlign=middle;strokeColor=none;fillColor=none;fontColor=#ffffff;fontSize=13;fontStyle=1;",
  line:     "edgeStyle=none;html=1;endArrow=none;endFill=0;strokeColor=#ffffff;strokeWidth=1.5;opacity=50;",
  dotted:   "edgeStyle=none;html=1;endArrow=none;endFill=0;dashed=1;dashPattern=6 6;strokeColor=#ffffff;strokeWidth=1.5;opacity=50;",
  arc:      "edgeStyle=none;curved=1;html=1;endArrow=none;endFill=0;strokeColor=#ffffff;strokeWidth=1.5;opacity=50;",
  run:      "edgeStyle=none;html=1;endArrow=block;endFill=1;strokeColor=#ffffff;strokeWidth=2.5;",
  runCurve: "edgeStyle=none;curved=1;html=1;endArrow=block;endFill=1;strokeColor=#ffffff;strokeWidth=2.5;",
  pass:     "edgeStyle=none;html=1;endArrow=open;endFill=0;dashed=1;dashPattern=8 4;strokeColor=#FFD700;strokeWidth=2.5;",
  passCurve:"edgeStyle=none;curved=1;html=1;endArrow=open;endFill=0;dashed=1;dashPattern=8 4;strokeColor=#FFD700;strokeWidth=2.5;",
};

const esc = (s: string) => s.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;").replace(/"/g, "&quot;");
const r1 = (n: number) => Math.round(n * 10) / 10;
const dist = (a: Pt, b: Pt) => Math.hypot(a.x - b.x, a.y - b.y);

type Circle = { p: Pt; orig: Pt; kind: "player" | "coach"; item: SceneItem };

// Signed distance from p to the infinite line through a→b, and whether p projects inside the segment.
function lineSide(p: Pt, a: Pt, b: Pt) {
  const dx = b.x - a.x, dy = b.y - a.y, len = Math.hypot(dx, dy) || 1;
  const nx = -dy / len, ny = dx / len;
  const t = ((p.x - a.x) * dx + (p.y - a.y) * dy) / (len * len);
  return { d: (p.x - a.x) * nx + (p.y - a.y) * ny, nx, ny, inside: t > -0.02 && t < 1.02 };
}

// Tidy-up: values within `tol` of each other along one axis (a row or a column drawn by
// hand) are set to their average, so things drawn roughly in line come out exactly in line.
// A row or column only links neighbours (within `span` along the other axis), so things far
// apart on the page are not pulled into line with each other. Two solid things are never put
// in the same group if that would pull them closer than `sep` (on top of each other).
// Only `solid` points (players, cones, balls) can clash; arrow ends never do.
function alignAxis(pts: Pt[], key: "x" | "y", tol: number, sep: number, span: number, solid: Set<Pt>) {
  const other = key === "x" ? "y" : "x";
  const groups: Pt[][] = [];
  const mean = (g: Pt[]) => g.reduce((t, q) => t + q[key], 0) / g.length;
  for (const p of [...pts].sort((a, b) => a[other] - b[other])) {
    const home = groups.find((g) =>
      Math.abs(mean(g) - p[key]) <= tol &&
      g.some((q) => Math.abs(q[other] - p[other]) <= span) &&
      !(solid.has(p) && g.some((q) => {
        if (!solid.has(q)) return false;
        const after = Math.abs(q[other] - p[other]);
        return after < sep && after < dist(q, p) - 2;
      })));
    if (home) home.push(p); else groups.push([p]);
  }
  for (const g of groups) if (g.length >= 2) { const m = mean(g); for (const p of g) p[key] = m; }
}

// A hand-drawn arrow given as several points that is really straight becomes two points.
// `slack` is how far (as a share of its length) a line may wander and still count as straight.
function simplifyPath(pts: Pt[], slack = 0.04): Pt[] {
  if (pts.length <= 2) return pts;
  const a = pts[0], b = pts[pts.length - 1], len = dist(a, b);
  if (len < 1) return pts;
  const straightEnough = pts.every((p) => Math.abs(lineSide(p, a, b).d) < Math.max(4, len * slack));
  return straightEnough ? [a, b] : pts;
}

// ── "Draw what was meant" helpers ───────────────────────────────────────────

type Feature = { kind: string; pts: Pt[]; tol: number };

// Mirror symmetry: each feature is matched with its mirror image across the axis (the
// left-hand 2 with the right-hand 4's spot, the left sideline with the right one) and the
// two are averaged, so they come out as exact mirror images. A feature that is its own
// mirror (an end line, the D, a goal on the centre line) is centred on the axis.
function symmetrise(features: Feature[], key: "x" | "y", axis: number, dry = false): number {
  const refl = (p: Pt): Pt => key === "x" ? { x: 2 * axis - p.x, y: p.y } : { x: p.x, y: 2 * axis - p.y };
  const order = (n: number, rev: boolean) => (i: number) => rev ? n - 1 - i : i;
  const cands: { f: Feature; g: Feature; cost: number; rev: boolean }[] = [];
  for (const f of features) for (const g of features) {
    if (f.kind !== g.kind || f.pts.length !== g.pts.length) continue;
    for (const rev of [false, true]) {
      const o = order(f.pts.length, rev);
      const cost = Math.max(...f.pts.map((p, i) => dist(refl(p), g.pts[o(i)])));
      if (cost < Math.min(f.tol, g.tol)) cands.push({ f, g, cost, rev });
    }
  }
  cands.sort((a, b) => a.cost - b.cost);
  const done = new Set<Feature>();
  for (const { f, g, rev } of cands) {
    if (done.has(f) || done.has(g)) continue;
    if (dry) { done.add(f); done.add(g); continue; }
    const o = order(f.pts.length, rev);
    const next = f.pts.map((p, i) => { const q = refl(g.pts[o(i)]); return { x: (p.x + q.x) / 2, y: (p.y + q.y) / 2 }; });
    if (f === g) next.forEach((n, i) => Object.assign(f.pts[i], n));
    else { next.forEach((n, i) => Object.assign(f.pts[i], n)); next.forEach((n, i) => Object.assign(g.pts[o(i)], refl(n))); }
    done.add(f); done.add(g);
  }
  return done.size;
}

// Rows (or columns) of three or more of the same thing spaced roughly evenly are spaced
// exactly evenly. Everything else sharing a moved row/column position moves with it, so
// cones, arrows and the players behind them stay in their lanes.
function evenOut(groups: { kind: string; p: Pt }[], everything: Pt[], key: "x" | "y", minGap: number) {
  const other = key === "x" ? "y" : "x";
  const rows = new Map<string, Pt[]>();
  for (const { kind, p } of groups) {
    const k = kind + "|" + Math.round(p[other] * 100);
    if (!rows.has(k)) rows.set(k, []);
    rows.get(k)!.push(p);
  }
  const moves: [number, number][] = [];
  for (const row of rows.values()) {
    if (row.length < 3) continue;
    row.sort((a, b) => a[key] - b[key]);
    const first = row[0][key], last = row[row.length - 1][key], step = (last - first) / (row.length - 1);
    if (step < minGap) continue;
    const gaps = row.slice(1).map((p, i) => p[key] - row[i][key]);
    if (gaps.some((g) => g < step * 0.7 || g > step * 1.3)) continue;
    row.forEach((p, i) => moves.push([p[key], first + i * step]));
  }
  if (!moves.length) return;
  for (const p of everything) {
    const m = moves.find(([from]) => Math.abs(p[key] - from) < 0.01);
    if (m) p[key] = m[1];
  }
}

// Curves: a run that bends one way becomes one clean arc; a wave or S keeps its turns but
// with even swings. Small wobbles on the way are dropped.
function smoothPath(pts: Pt[]): Pt[] {
  if (pts.length <= 2) return pts;
  const a = pts[0], b = pts[pts.length - 1], L = dist(a, b);
  if (L < 1) return pts;
  const ux = (b.x - a.x) / L, uy = (b.y - a.y) / L;
  const at = (t: number, d: number): Pt => ({ x: a.x + ux * t - uy * d, y: a.y + uy * t + ux * d });
  const td = pts.map((p) => ({ t: (p.x - a.x) * ux + (p.y - a.y) * uy, d: -(p.x - a.x) * uy + (p.y - a.y) * ux }));
  const ext = td.slice(1, -1).filter((q, i) => {
    // A neighbour on the other side of the line never stops a point being a swing (zig-zags).
    const peak = (n: { d: number }) => Math.sign(n.d) !== Math.sign(q.d) || Math.abs(q.d) >= Math.abs(n.d) - 0.5;
    return Math.abs(q.d) > L * 0.04 && peak(td[i]) && peak(td[i + 2]);
  });
  // Merge neighbouring extremes on the same side (one swing drawn as two bumps).
  const swings: { t: number; d: number }[] = [];
  for (const q of ext) {
    const last = swings[swings.length - 1];
    if (last && Math.sign(last.d) === Math.sign(q.d)) { if (Math.abs(q.d) > Math.abs(last.d)) swings[swings.length - 1] = q; }
    else swings.push(q);
  }
  if (!swings.length) return [a, b];
  if (swings.length === 1) {
    // One bend: a single control point that makes the smoothed curve pass through the apex.
    const apex = at(swings[0].t, swings[0].d), mid = { x: (a.x + b.x) / 2, y: (a.y + b.y) / 2 };
    return [a, { x: 2 * apex.x - mid.x, y: 2 * apex.y - mid.y }, b];
  }
  const amp = swings.reduce((t, q) => t + Math.abs(q.d), 0) / swings.length;
  const t0 = swings[0].t, t1 = swings[swings.length - 1].t, n = swings.length;
  return [a, ...swings.map((q, i) => at(n > 1 ? t0 + ((t1 - t0) * i) / (n - 1) : q.t, Math.sign(q.d) * amp * 1.35)), b];
}

// ── Scene → mxGraph XML ──────────────────────────────────────────────────────
export function sceneToXml(scene: Scene, imgW: number, imgH: number): string {
  const CANVAS = 700, PAD = 34;
  const toPx = (p: Pt): Pt => ({ x: (p.x / 1000) * imgW, y: (p.y / 1000) * imgH });

  const items = (scene.items || []).filter((it) => Number.isFinite(it.x) && Number.isFinite(it.y));
  const lines = (scene.lines || [])
    .map((l) => ({ ...l, points: (l.points || []).filter((p) => Number.isFinite(p.x) && Number.isFinite(p.y)) }))
    .filter((l) => l.points.length >= 2);

  // Bounding box of everything drawn, in image pixels (keeps the sketch's true shape).
  let minX = Infinity, minY = Infinity, maxX = -Infinity, maxY = -Infinity;
  const grow = (p: Pt, hw = 0, hh = 0) => {
    minX = Math.min(minX, p.x - hw); maxX = Math.max(maxX, p.x + hw);
    minY = Math.min(minY, p.y - hh); maxY = Math.max(maxY, p.y + hh);
  };
  for (const it of items) {
    const c = toPx(it);
    grow(c, ((it.w || 0) / 2000) * imgW, ((it.h || 0) / 2000) * imgH);
  }
  for (const l of lines) for (const p of l.points) grow(toPx(p));
  if (!Number.isFinite(minX)) { minX = 0; minY = 0; maxX = imgW; maxY = imgH; }
  const bw = Math.max(maxX - minX, 1), bh = Math.max(maxY - minY, 1);
  const s = (CANVAS - 2 * PAD) / Math.max(bw, bh);
  const cw = Math.round(bw * s + 2 * PAD), ch = Math.round(bh * s + 2 * PAD);
  const map = (p: Pt): Pt => { const q = toPx(p); return { x: (q.x - minX) * s + PAD, y: (q.y - minY) * s + PAD }; };
  const mapLen = (w: number, h: number) => ({ w: (w / 1000) * imgW * s, h: (h / 1000) * imgH * s });

  // Straight pitch lines in canvas space. Hand-drawn lines that are nearly level or
  // nearly upright are straightened, and ends that nearly meet another line are joined to it.
  const squareUp = (l: SceneLine) => {
    const a = map(l.points[0]), b = map(l.points[l.points.length - 1]);
    const dx = Math.abs(b.x - a.x), dy = Math.abs(b.y - a.y);
    if (dx > 0 && dy / dx < 0.09) { const y = (a.y + b.y) / 2; a.y = y; b.y = y; }
    else if (dy > 0 && dx / dy < 0.09) { const x = (a.x + b.x) / 2; a.x = x; b.x = x; }
    return [a, b] as [Pt, Pt];
  };
  const straight = lines.filter((l) => l.kind === "pitch_line").map(squareUp);
  // Dotted marker lines: straight from end to end unless clearly drawn as a curve.
  const dotted = lines.filter((l) => l.kind === "dotted_line" && l.points.length >= 2).map((l) => {
    const pts = simplifyPath(l.points.map(map), 0.1);
    return pts.length === 2 ? squareUp(l) : pts;
  });
  const level = straight.filter(([a, b]) => a.y === b.y), upright = straight.filter(([a, b]) => a.x === b.x);
  // Join an end of a level line across to an upright line (or an upright's end up/down to a
  // level line) when it nearly meets it. Reach is capped by the line's own length so small
  // shapes such as the goal box keep their size.
  const join = (p: Pt, onto: "level" | "upright", reach = 18) => {
    if (onto === "level") {
      for (const [a, b] of level) {
        if (Math.abs(p.y - a.y) < reach && p.x >= Math.min(a.x, b.x) - reach && p.x <= Math.max(a.x, b.x) + reach) { p.y = a.y; break; }
      }
    } else {
      for (const [a, b] of upright) {
        if (Math.abs(p.x - a.x) < reach && p.y >= Math.min(a.y, b.y) - reach && p.y <= Math.max(a.y, b.y) + reach) { p.x = a.x; break; }
      }
    }
    return p;
  };
  for (const seg of straight) {
    const [a, b] = seg, reach = Math.min(18, dist(a, b) * 0.4);
    if (upright.includes(seg)) { join(a, "level", reach); join(b, "level", reach); }
    else if (level.includes(seg)) { join(a, "upright", reach); join(b, "upright", reach); }
  }

  // Positions in canvas space.
  const pos = new Map<SceneItem, Pt>(items.map((it) => [it, map(it)]));
  const arrows = lines
    .filter((l) => l.kind === "run" || l.kind === "pass")
    // A dotted pass that only wobbles was meant to be straight.
    .map((l) => ({ kind: l.kind, pts: simplifyPath(l.points.map(map), l.kind === "pass" ? 0.1 : 0.04) }));
  const arcs = lines.filter((l) => l.kind === "pitch_arc").map((l) => {
    const pts = l.points.map(map);
    return pts.length >= 3 ? [pts[0], pts[Math.floor(pts.length / 2)], pts[pts.length - 1]] : [pts[0], pts[pts.length - 1]];
  });
  const people = items.filter((it) => it.kind === "player" || it.kind === "coach").map((it) => pos.get(it)!);
  let gap = Infinity;
  for (let i = 0; i < people.length; i++) for (let j = i + 1; j < people.length; j++) gap = Math.min(gap, dist(people[i], people[j]));
  const D0 = Math.max(28, Math.min(42, Number.isFinite(gap) ? gap * 0.95 : 40));
  const tol = Math.max(14, D0 * 0.6), sep = D0 * 0.9;

  // An arrow that starts where another ends (a run that turns into a strike) stays joined to it.
  const chained = arrows.map((a) => arrows.find((b) => b !== a && dist(b.pts[b.pts.length - 1], a.pts[0]) < 6) ?? null);
  const relink = () => arrows.forEach((a, i) => { const b = chained[i]; if (b) a.pts[0] = b.pts[b.pts.length - 1]; });
  relink();

  // 1. Symmetry: pitches and symmetric layouts come out as exact mirror images. A cone or
  // ball set beside a player stays beside that player if mirroring would pull them apart.
  const peoplePts = items.filter((it) => it.kind === "player" || it.kind === "coach").map((it) => pos.get(it)!);
  const attached = new Map<SceneItem, { to: Pt; cone: Pt; dx: number; dy: number }>();
  for (const it of items) {
    if (it.kind !== "cone" && it.kind !== "ball") continue;
    const p = pos.get(it)!;
    let best: Pt | null = null, bd = D0 * 1.6;
    for (const q of peoplePts) { const d = dist(p, q); if (d < bd) { bd = d; best = q; } }
    if (best) attached.set(it, { to: best, cone: p, dx: p.x - best.x, dy: p.y - best.y });
  }
  for (const key of ["x", "y"] as const) {
    if (!(key === "x" ? scene.symmetry?.left_right : scene.symmetry?.top_bottom)) continue;
    const frame: Pt[] = [
      ...straight.flat(), ...arcs.flat(), ...dotted.flat(),
      ...items.filter((it) => ["cone", "goalposts", "wall", "zone"].includes(it.kind)).map((it) => pos.get(it)!),
    ];
    const ref = frame.length >= 2 ? frame : [...pos.values()];
    if (ref.length < 2) continue;
    const lo = Math.min(...ref.map((p) => p[key])), hi = Math.max(...ref.map((p) => p[key])), W = hi - lo;
    if (W < 60) continue;
    const loose = W * 0.09, tight = W * 0.07;
    const axis = (lo + hi) / 2;
    const isPerson = (it: SceneItem) => it.kind === "player" || it.kind === "coach";
    const personFeatures: Feature[] = items.filter(isPerson).map((it) => ({ kind: `${it.kind}:${it.team}`, pts: [pos.get(it)!], tol: tight }));
    // Players only follow the mirror when most of them have a partner across it. A drill
    // that goes round a square (one player at each corner) is not a mirror image, so its
    // players, their cones and the arrows between them are left to the other tidy-ups.
    // (Players near the centre line are left out of that count.)
    const offCentre = personFeatures.filter((f) => Math.abs(f.pts[0][key] - axis) > tight * 1.5)
      .map((f) => ({ ...f, pts: [{ ...f.pts[0] }] }));
    const peopleMirror = offCentre.length === 0 || symmetrise(offCentre, key, axis, true) >= offCentre.length * 0.6;
    const features: Feature[] = [
      ...straight.map((l) => ({ kind: "line", pts: l as Pt[], tol: loose })),
      ...arcs.map((l) => ({ kind: "arc", pts: l, tol: loose })),
      ...dotted.map((l) => ({ kind: "dotted", pts: l as Pt[], tol: loose })),
      ...items.filter((it) => !isPerson(it) && (peopleMirror || !attached.has(it)))
        .map((it) => ({ kind: it.kind, pts: [pos.get(it)!], tol: loose })),
      ...(peopleMirror ? personFeatures : []),
      ...(peopleMirror ? arrows.map((a) => ({ kind: a.kind, pts: [a.pts[0], a.pts[a.pts.length - 1]], tol: loose })) : []),
    ];
    symmetrise(features, key, axis);
  }
  for (const [it, a] of attached) {
    const p = pos.get(it)!, want = { x: a.to.x + a.dx, y: a.to.y + a.dy };
    if (dist(p, want) > D0 * 0.5) Object.assign(p, want);
  }
  for (const l of arcs) { join(l[0], "level", 12); join(l[l.length - 1], "level", 12); }

  // 5a. Arrows land on what they point at: an end that stops short of (or runs past) a
  // player or cone it is aimed at is moved onto it, and the start onto the player it leaves.
  const joints = new Set<Pt>(arrows.flatMap((a, i) => chained[i] ? [a.pts[0]] : []));
  const targets = items.filter((it) => ["player", "coach", "cone"].includes(it.kind)).map((it) => pos.get(it)!);
  const land = (end: Pt, from: Pt) => {
    if (joints.has(end)) return;
    const len = dist(from, end);
    if (len < 1) return;
    const dx = (end.x - from.x) / len, dy = (end.y - from.y) / len;
    let best: Pt | null = null, bd = D0 * 1.6;
    for (const t of targets) {
      const d = dist(t, end), ft = dist(from, t);
      if (d >= bd || ft < D0 * 0.8) continue;
      if (((t.x - from.x) * dx + (t.y - from.y) * dy) / ft < Math.cos(Math.PI / 6)) continue;
      best = t; bd = d;
    }
    if (best) { Object.assign(end, best); landed.set(end, best); }
  };
  const landed = new Map<Pt, Pt>();
  for (const a of arrows) {
    const n = a.pts.length;
    land(a.pts[n - 1], a.pts[n - 2]);
    land(a.pts[0], a.pts[1]);
  }
  // 2b. Two players linked by a nearly level or upright straight arrow are put exactly level
  // or upright, so the sides of a square come out square however far apart the corners are.
  for (const a of arrows) {
    if (a.pts.length !== 2) continue;
    const t0 = landed.get(a.pts[0]), t1 = landed.get(a.pts[1]);
    if (!t0 || !t1 || t0 === t1) continue;
    const dx = Math.abs(t1.x - t0.x), dy = Math.abs(t1.y - t0.y);
    const key = dx < dy * 0.1 ? "x" : dy < dx * 0.1 ? "y" : null;
    if (!key) continue;
    const m = (t0[key] + t1[key]) / 2;
    for (const t of [t0, t1]) {
      const d = m - t[key];
      for (const at of attached.values()) if (at.to === t) at.cone[key] += d;
      t[key] = m;
    }
  }
  for (const [end, t] of landed) Object.assign(end, t);

  // 2 + 4. Line up rows and columns, then space evenly spaced rows exactly evenly.
  const solid = new Set(items.filter((it) => ["player", "coach", "cone", "ball"].includes(it.kind)).map((it) => pos.get(it)!));
  const arrowEnds = arrows.flatMap((a, i) => chained[i] ? [a.pts[a.pts.length - 1]] : [a.pts[0], a.pts[a.pts.length - 1]]);
  const pool: Pt[] = [...new Set([...solid, ...arrowEnds])];
  alignAxis(pool, "x", tol, sep, D0 * 4, solid);
  alignAxis(pool, "y", tol, sep, D0 * 4, solid);
  const kinds = items.filter((it) => solid.has(pos.get(it)!)).map((it) => ({ kind: it.kind === "coach" ? "player" : it.kind, p: pos.get(it)! }));
  evenOut(kinds, pool, "x", D0);
  evenOut(kinds, pool, "y", D0);
  relink();

  // Repeated so a run and the strike chained onto it both end up straight.
  const straighten = () => {
    for (let k = 0; k < 4; k++) for (const a of arrows) {
      if (a.pts.length !== 2) continue;
      const [p, q] = a.pts, dx = Math.abs(q.x - p.x), dy = Math.abs(q.y - p.y);
      if (dy > 0 && dx / dy < 0.1) { p.x = q.x = (p.x + q.x) / 2; }
      else if (dx > 0 && dy / dx < 0.1) { p.y = q.y = (p.y + q.y) / 2; }
    }
  };
  straighten();

  // 5b. Arrows drawn side by side at nearly the same angle are made parallel.
  const ang = (a: typeof arrows[number]) => { const [p, q] = a.pts; return Math.atan2(q.y - p.y, q.x - p.x); };
  const twoPt = arrows.filter((a) => a.pts.length === 2);
  const paired = new Set<typeof arrows[number]>();
  for (const a of twoPt) for (const b of twoPt) {
    if (a === b || paired.has(a) || paired.has(b) || a.kind !== b.kind) continue;
    let d = ang(b) - ang(a);
    while (d > Math.PI / 2) d -= Math.PI;
    while (d < -Math.PI / 2) d += Math.PI;
    if (Math.abs(d) > (8 * Math.PI) / 180 || Math.abs(d) < 1e-6) continue;
    for (const [x, turn] of [[a, d / 2], [b, -d / 2]] as const) {
      const [p, q] = x.pts, m = { x: (p.x + q.x) / 2, y: (p.y + q.y) / 2 }, c = Math.cos(turn), sn = Math.sin(turn);
      for (const pt of [p, q]) {
        const rx = pt.x - m.x, ry = pt.y - m.y;
        Object.assign(pt, { x: m.x + rx * c - ry * sn, y: m.y + rx * sn + ry * c });
      }
    }
    paired.add(a); paired.add(b);
  }

  // Matching arrows (same kind, same direction, starting in the same row or column, roughly
  // the same length) get the same length.
  const straightArrows = arrows.filter((a, i) => a.pts.length === 2 && !chained[i]);
  const used = new Set<typeof arrows[number]>();
  for (const a of straightArrows) {
    if (used.has(a)) continue;
    const dir = (x: typeof a) => { const [p, q] = x.pts; return { x: Math.sign(Math.round(q.x - p.x)), y: Math.sign(Math.round(q.y - p.y)) }; };
    const len = (x: typeof a) => dist(x.pts[0], x.pts[1]);
    const da = dir(a);
    const group = straightArrows.filter((b) => {
      const db = dir(b);
      return !used.has(b) && b.kind === a.kind && db.x === da.x && db.y === da.y &&
        (da.x === 0 ? Math.abs(b.pts[0].y - a.pts[0].y) < tol : da.y === 0 ? Math.abs(b.pts[0].x - a.pts[0].x) < tol : false) &&
        len(b) > len(a) * 0.6 && len(b) < len(a) * 1.65;
    });
    group.forEach((b) => used.add(b));
    if (group.length < 2) continue;
    const L = group.map(len).sort((x, y) => x - y)[Math.floor(group.length / 2)];
    for (const b of group) {
      const [p, q] = b.pts, l = len(b) || 1;
      Object.assign(q, { x: p.x + ((q.x - p.x) / l) * L, y: p.y + ((q.y - p.y) / l) * L });
    }
  }
  straighten();

  // 3. Smooth curved runs and passes.
  for (const a of arrows) if (a.pts.length > 2) a.pts = smoothPath(a.pts);

  // Balls and cones drawn touching (a stack of balls) are spread just far enough apart to read.
  const small = items.filter((it) => it.kind === "ball" || it.kind === "cone").map((it) => pos.get(it)!);
  const ballGap = D0 * 0.62;
  for (let pass = 0; pass < 3; pass++) for (let i = 0; i < small.length; i++) for (let j = i + 1; j < small.length; j++) {
    const a = small[i], b = small[j], d = dist(a, b);
    if (d >= ballGap) continue;
    const ux = d > 0.01 ? (b.x - a.x) / d : 1, uy = d > 0.01 ? (b.y - a.y) / d : 0, k = (ballGap - d) / 2;
    a.x -= ux * k; a.y -= uy * k; b.x += ux * k; b.y += uy * k;
  }

  // Players and coaches: size from how close together they were drawn.
  const circles: Circle[] = items
    .filter((it) => it.kind === "player" || it.kind === "coach")
    .map((it) => { const p = pos.get(it)!; return { p: { ...p }, orig: { ...p }, kind: it.kind as "player" | "coach", item: it }; });
  let nn = Infinity;
  for (let i = 0; i < circles.length; i++) for (let j = i + 1; j < circles.length; j++) nn = Math.min(nn, dist(circles[i].orig, circles[j].orig));
  let D = Math.max(28, Math.min(42, Number.isFinite(nn) ? nn * 0.95 : 40));

  // Keep circles on their own side of every straight line, then off each other.
  // If a gap between two lines is too tight, shrink every circle a little and retry.
  const settle = (r: number) => {
    for (const c of circles) c.p = { ...c.orig };
    for (let pass = 0; pass < 4; pass++) {
      for (const c of circles) {
        for (const [a, b] of straight) {
          const o = lineSide(c.orig, a, b), now = lineSide(c.p, a, b);
          if (!now.inside || Math.abs(now.d) >= r + 3) continue;
          const side = o.d >= 0 ? 1 : -1;
          const push = side * (r + 3) - now.d;
          c.p = { x: c.p.x + push * now.nx, y: c.p.y + push * now.ny };
        }
      }
      for (let i = 0; i < circles.length; i++) for (let j = i + 1; j < circles.length; j++) {
        const a = circles[i], b = circles[j], d = dist(a.p, b.p), need = 2 * r + 3;
        if (d >= need) continue;
        const ux = d > 0.01 ? (b.p.x - a.p.x) / d : 1, uy = d > 0.01 ? (b.p.y - a.p.y) / d : 0, k = (need - d) / 2;
        a.p = { x: a.p.x - ux * k, y: a.p.y - uy * k };
        b.p = { x: b.p.x + ux * k, y: b.p.y + uy * k };
      }
    }
    // Clash left over = a circle still sitting on a line it did not start on.
    return circles.some((c) => straight.some(([a, b]) => {
      const o = lineSide(c.orig, a, b), now = lineSide(c.p, a, b);
      return now.inside && Math.abs(now.d) < r && Math.sign(o.d || 1) === Math.sign(now.d || 1) && Math.abs(o.d) > 1;
    }));
  };
  for (let tries = 0; tries < 5 && settle(D / 2); tries++) D = Math.max(24, D * 0.9);

  const cells: string[] = [];
  let id = 2;
  const vertex = (value: string, style: string, x: number, y: number, w: number, h: number) =>
    cells.push(`<mxCell id="${id++}" value="${esc(value)}" style="${style}" vertex="1" parent="1"><mxGeometry x="${r1(x)}" y="${r1(y)}" width="${r1(w)}" height="${r1(h)}" as="geometry"/></mxCell>`);
  const edge = (style: string, pts: Pt[]) => {
    const [a, ...rest] = pts, b = rest.pop()!;
    const mid = rest.length ? `<Array as="points">${rest.map((p) => `<mxPoint x="${r1(p.x)}" y="${r1(p.y)}"/>`).join("")}</Array>` : "";
    cells.push(`<mxCell id="${id++}" value="" style="${style}" edge="1" parent="1"><mxGeometry relative="1" as="geometry"><mxPoint x="${r1(a.x)}" y="${r1(a.y)}" as="sourcePoint"/><mxPoint x="${r1(b.x)}" y="${r1(b.y)}" as="targetPoint"/>${mid}</mxGeometry></mxCell>`);
  };

  vertex("", S.bg, 0, 0, cw, ch);

  // Zones and walls first so everything else draws on top.
  for (const it of items) {
    if (it.kind !== "zone" && it.kind !== "wall") continue;
    const c = map(it), { w, h } = mapLen(it.w || 80, it.h || (it.kind === "wall" ? 30 : 80));
    vertex(it.kind === "wall" ? "WALL" : it.label, it.kind === "wall" ? S.wall : S.zone, c.x - w / 2, c.y - h / 2, w, Math.max(h, it.kind === "wall" ? 28 : 10));
  }

  // Pitch markings.
  for (const [a, b] of straight) edge(S.line, [a, b]);
  for (const l of dotted) edge(l.length > 2 ? S.dotted.replace("edgeStyle=none;", "edgeStyle=none;curved=1;") : S.dotted, l);
  for (const l of arcs) edge(l.length === 3 ? S.arc : S.line, l);

  // Runs and passes: pull the ends back off the circles they start or finish at, leaving a
  // clear gap (coaches prefer arrows that stop short rather than touch).
  const GAP = 11;
  const ends: { p: Pt; r: number }[] = [
    ...circles.map((c) => ({ p: c.p, r: D / 2 })),
    ...items.filter((it) => it.kind === "cone" || it.kind === "ball").map((it) => ({ p: pos.get(it)!, r: 12 })),
  ];
  const trim = (end: Pt, toward: Pt) => {
    let best: { p: Pt; r: number } | null = null, bd = Infinity;
    for (const e of ends) { const d = dist(e.p, end); if (d < bd) { bd = d; best = e; } }
    if (!best || bd > best.r + 14) return end;
    if (dist(toward, best.p) < best.r + 10) return end;
    // Slide the end back along the arrow's own line until it clears the circle, so the
    // arrow keeps its direction even if the circle was nudged sideways.
    const len = dist(toward, end) || 1, ux = (toward.x - end.x) / len, uy = (toward.y - end.y) / len;
    const wx = best.p.x - end.x, wy = best.p.y - end.y, proj = wx * ux + wy * uy;
    const R = best.r + GAP, perp2 = wx * wx + wy * wy - proj * proj;
    if (perp2 >= R * R) return end;
    const s = proj + Math.sqrt(R * R - perp2);
    return s > 0 && s < len - 10 ? { x: end.x + ux * s, y: end.y + uy * s } : end;
  };
  // Walls and zones: an arrow end that runs into or up to one stops short of its edge.
  const boxes = items.filter((it) => it.kind === "wall" || it.kind === "zone").map((it) => {
    const c = map(it), { w, h } = mapLen(it.w || 80, it.h || (it.kind === "wall" ? 30 : 80));
    const hh = Math.max(h, it.kind === "wall" ? 28 : 10);
    return { x0: c.x - w / 2, x1: c.x + w / 2, y0: c.y - hh / 2, y1: c.y + hh / 2, wall: it.kind === "wall" };
  });
  const near = (p: Pt, b: typeof boxes[number], m: number) => p.x > b.x0 - m && p.x < b.x1 + m && p.y > b.y0 - m && p.y < b.y1 + m;
  const offBox = (end: Pt, toward: Pt) => {
    for (const b of boxes) {
      // A zone is somewhere to run into, so only its edge is kept clear; a wall is kept clear always.
      if (!near(end, b, 8) || near(toward, b, 8)) continue;
      if (!b.wall && near(end, b, -8)) continue;
      const len = dist(toward, end) || 1, ux = (toward.x - end.x) / len, uy = (toward.y - end.y) / len;
      let s = 0;
      while (s < len - 12 && near({ x: end.x + ux * s, y: end.y + uy * s }, b, 8)) s += 1;
      return { x: end.x + ux * s, y: end.y + uy * s };
    }
    return end;
  };
  // Where one arrow carries straight on from another (a run then a strike), each stops a
  // little short of the joint so the two read as separate moves.
  const feeds = new Set(chained.filter((b) => b)); // arrows that another arrow carries on from
  const back = (end: Pt, toward: Pt, by: number) => {
    const len = dist(toward, end);
    if (len < by * 3) return end;
    return { x: end.x + ((toward.x - end.x) / len) * by, y: end.y + ((toward.y - end.y) / len) * by };
  };
  arrows.forEach((a, i) => {
    const pts = a.pts.map((p) => ({ ...p }));
    const n = pts.length;
    const joinStart = !!chained[i], joinEnd = feeds.has(a);
    // A joint on a player (pass to 7, then 7 runs) is trimmed off the player like any end.
    const fix = (end: Pt, toward: Pt, joint: boolean) => {
      const t = trim(end, toward);
      return joint && t === end ? back(end, toward, 6) : offBox(t, toward);
    };
    pts[0] = fix(pts[0], pts[1], joinStart);
    pts[n - 1] = fix(pts[n - 1], pts[n - 2], joinEnd);
    const curved = pts.length > 2;
    edge(a.kind === "pass" ? (curved ? S.passCurve : S.pass) : (curved ? S.runCurve : S.run), pts);
  });

  // Equipment, then people on top.
  for (const it of items) {
    const c = pos.get(it)!;
    if (it.kind === "goalposts") {
      const { w, h } = mapLen(it.w || 60, it.h || 80);
      const gw = Math.max(w, 40), gh = Math.max(h, 40);
      vertex("", S.goal, c.x - gw / 2, c.y - gh / 2, gw, gh);
    } else if (it.kind === "cone") {
      const w = Math.round(D * 0.6), h = Math.round(D * 0.7);
      vertex("", S.cone, c.x - w / 2, c.y - h / 2, w, h);
    } else if (it.kind === "ball") {
      const b = Math.round(D * 0.55);
      vertex("", S.ball, c.x - b / 2, c.y - b / 2, b, b);
    } else if (it.kind === "text" && it.label.trim()) {
      vertex(it.label.trim(), S.text, c.x - 10, c.y - 10, Math.max(60, it.label.length * 9), 20);
    }
  }
  for (const c of circles) {
    const style = c.kind === "coach" ? S.coach : c.item.team === "away" ? S.away : S.home;
    const label = c.kind === "coach" ? "C" : (c.item.label || "").trim().slice(0, 3);
    vertex(label, style, c.p.x - D / 2, c.p.y - D / 2, D, D);
  }

  // csEngine="v2" tells the page not to re-colour circles (an unnumbered player is still a player).
  return `<mxGraphModel background="#2E7D32" csEngine="v2"><root><mxCell id="0"/><mxCell id="1" parent="0"/>${cells.join("")}</root></mxGraphModel>`;
}
