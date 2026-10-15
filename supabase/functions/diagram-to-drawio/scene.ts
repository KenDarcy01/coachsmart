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
- pitch_line: a straight line with no arrowhead that marks the pitch or an area: end lines, side lines, the 13m, 20m, 45m and 65m lines, halfway, box sides, and any short marker line. Give 2 points, one at each end, following the line as drawn (lines that stop before the edge stop there too).
- pitch_arc: a curved pitch marking with no arrowhead (the small D in front of goal, the large arc, a centre circle). Give 3 points: the start, the point of the arc furthest from the straight line between start and end, and the end.
- run: a solid line with an arrowhead, meaning a player moves. Give 2 to 12 points tracing the path from where it starts to the arrowhead. For curved or wavy lines, put a point at every bend so the shape is kept.
- pass: a dashed or dotted line with an arrowhead, meaning a kick, hand pass or strike. Same points rule as run.

WHAT TO IGNORE
- Faint marks that are not drawn on this page: dents or impressions from writing on a sheet above, ink showing through from the back of the page (often mirrored), shadows, creases, the paper edge, the table, fingers. Only describe pen, pencil or marker strokes clearly drawn on this page.
- A title: free-standing words above or outside the diagram with no box around it. Put it in game_name instead ("" if there is no title). A rectangle with "WALL" or a label inside is a diagram element, not a title.
- Written instructions or notes beside the diagram (for example "split into groups of 4"). Do not output them, but use them to understand the drawing.

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
          kind: { type: "string", enum: ["pitch_line", "pitch_arc", "run", "pass"] },
          points: { type: "array", items: POINT },
        },
        required: ["kind", "points"],
        additionalProperties: false,
      },
    },
  },
  required: ["game_name", "sport", "items", "lines"],
  additionalProperties: false,
};

export type Pt = { x: number; y: number };
export type SceneItem = {
  kind: "player" | "coach" | "ball" | "cone" | "goalposts" | "wall" | "zone" | "text";
  label: string; team: "home" | "away" | "none";
  x: number; y: number; w: number; h: number;
};
export type SceneLine = { kind: "pitch_line" | "pitch_arc" | "run" | "pass"; points: Pt[] };
export type Scene = { game_name: string; sport: "football" | "hurling" | "unknown"; items: SceneItem[]; lines: SceneLine[] };

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
function simplifyPath(pts: Pt[]): Pt[] {
  if (pts.length <= 2) return pts;
  const a = pts[0], b = pts[pts.length - 1], len = dist(a, b);
  if (len < 1) return pts;
  const straightEnough = pts.every((p) => Math.abs(lineSide(p, a, b).d) < Math.max(4, len * 0.04));
  return straightEnough ? [a, b] : pts;
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
  const straight = lines.filter((l) => l.kind === "pitch_line").map((l) => {
    const a = map(l.points[0]), b = map(l.points[l.points.length - 1]);
    const dx = Math.abs(b.x - a.x), dy = Math.abs(b.y - a.y);
    if (dx > 0 && dy / dx < 0.09) { const y = (a.y + b.y) / 2; a.y = y; b.y = y; }
    else if (dy > 0 && dx / dy < 0.09) { const x = (a.x + b.x) / 2; a.x = x; b.x = x; }
    return [a, b] as [Pt, Pt];
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

  // Tidy-up: line up players, coaches, cones, balls and arrow ends that were drawn roughly
  // in the same row or column, and straighten arrows that are nearly upright or level.
  // Matching arrows end up the same length because their starts and ends line up.
  const pos = new Map<SceneItem, Pt>(items.map((it) => [it, map(it)]));
  const arrows = lines
    .filter((l) => l.kind === "run" || l.kind === "pass")
    .map((l) => ({ kind: l.kind, pts: simplifyPath(l.points.map(map)) }));
  const people = items.filter((it) => it.kind === "player" || it.kind === "coach").map((it) => pos.get(it)!);
  let gap = Infinity;
  for (let i = 0; i < people.length; i++) for (let j = i + 1; j < people.length; j++) gap = Math.min(gap, dist(people[i], people[j]));
  const D0 = Math.max(28, Math.min(42, Number.isFinite(gap) ? gap * 0.95 : 40));
  const tol = Math.max(14, D0 * 0.6), sep = D0 * 0.9;

  // An arrow that starts where another ends (a run that turns into a strike) stays joined to it.
  const chained = arrows.map((a) => arrows.find((b) => b !== a && dist(b.pts[b.pts.length - 1], a.pts[0]) < 6) ?? null);
  const solid = new Set(items.filter((it) => ["player", "coach", "cone", "ball"].includes(it.kind)).map((it) => pos.get(it)!));
  const pool: Pt[] = [
    ...solid,
    ...arrows.flatMap((a, i) => chained[i] ? [a.pts[a.pts.length - 1]] : [a.pts[0], a.pts[a.pts.length - 1]]),
  ];
  alignAxis(pool, "x", tol, sep, D0 * 4, solid);
  alignAxis(pool, "y", tol, sep, D0 * 4, solid);
  const relink = () => arrows.forEach((a, i) => { const b = chained[i]; if (b) a.pts[0] = { ...b.pts[b.pts.length - 1] }; });
  const straighten = () => {
    for (const a of arrows) {
      if (a.pts.length !== 2) continue;
      const [p, q] = a.pts, dx = Math.abs(q.x - p.x), dy = Math.abs(q.y - p.y);
      if (dy > 0 && dx / dy < 0.1) { p.x = q.x = (p.x + q.x) / 2; }
      else if (dx > 0 && dy / dx < 0.1) { p.y = q.y = (p.y + q.y) / 2; }
    }
  };
  relink(); straighten();

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
      b.pts[1] = { x: p.x + ((q.x - p.x) / l) * L, y: p.y + ((q.y - p.y) / l) * L };
    }
  }
  relink(); straighten();

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
  for (const l of lines) {
    if (l.kind !== "pitch_arc") continue;
    const pts = l.points.map(map);
    const first = join(pts[0], "level", 12), last = join(pts[pts.length - 1], "level", 12);
    const far = pts.length >= 3 ? pts[Math.floor(pts.length / 2)] : null;
    edge(far ? S.arc : S.line, far ? [first, far, last] : [first, last]);
  }

  // Runs and passes: pull the ends back off the circles they start or finish at.
  const ends: { p: Pt; r: number }[] = [
    ...circles.map((c) => ({ p: c.p, r: D / 2 })),
    ...items.filter((it) => it.kind === "cone" || it.kind === "ball").map((it) => ({ p: pos.get(it)!, r: 12 })),
  ];
  const trim = (end: Pt, toward: Pt) => {
    let best: { p: Pt; r: number } | null = null, bd = Infinity;
    for (const e of ends) { const d = dist(e.p, end); if (d < bd) { bd = d; best = e; } }
    if (!best || bd > best.r + 14) return end;
    const dx = toward.x - best.p.x, dy = toward.y - best.p.y, len = Math.hypot(dx, dy);
    if (len < best.r + 10) return end;
    return { x: best.p.x + (dx / len) * (best.r + 7), y: best.p.y + (dy / len) * (best.r + 7) };
  };
  for (const a of arrows) {
    const pts = a.pts.map((p) => ({ ...p }));
    pts[0] = trim(pts[0], pts[1]);
    pts[pts.length - 1] = trim(pts[pts.length - 1], pts[pts.length - 2]);
    const curved = pts.length > 2;
    edge(a.kind === "pass" ? (curved ? S.passCurve : S.pass) : (curved ? S.runCurve : S.run), pts);
  }

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
