// deno-lint-ignore-file no-explicit-any
// Session plan PDF: overview page (hero, stats, focus, timeline, run sheet, pitch layout)
// followed by one card per block. "a4" packs cards onto A4 pages; "mobile" puts one card
// on each page and sizes every page to its content so phones scroll without blank space.
import type { Fonts, Theme, RGB, PDFImage, ClubData, IconName } from "../_shared/pdf-kit.ts";
import {
  PDFDocument, Canvas,
  makeTheme, loadFonts, embedImage, clean, fixed, wrap, fitLine, wrapRuns, drawRuns, textW,
  drawCrest, drawStripes, drawFooters, drawContBand, drawPill, pillW, label, sectionHead,
  videoRow, iconList, callout, calloutList, splitIdeas, splitSteps, splitWeather, irishParts, clock,
} from "../_shared/pdf-kit.ts";

export type { ClubData };

export interface DrillData {
  game_name: string;
  duration_mins: number;
  description: string;
  coaching_points: string[];
  variation?: string;
  game_image?: string;
  game_video?: string | null;
}
export interface WarmupCooldown {
  duration_mins: number;
  description: string;
  coaching_points?: string[];
  game_name?: string;
  game_image?: string | null;
  game_video?: string | null;
}
export interface OptionalBlock { duration_mins: number; description: string }
export interface PlanJson {
  session_title: string;
  session_objective: string;
  total_duration_mins: number;
  player_count: number;
  coach_count: number;
  weather?: { summary: string };
  session_image?: string;
  pre_session?: OptionalBlock | null;
  warm_up: WarmupCooldown;
  station_setup?: string | null;
  drills: DrillData[];
  cool_down: WarmupCooldown;
  post_session?: OptionalBlock | null;
}
export interface EventData {
  event_title: string | null;
  event_date: string | null;
  squad_name: string | null;
  squad_grade: string | null;
  team_name: string | null;
  event_type: string | null;
  event_code: string | null;
  team_female: boolean;
  club: ClubData;
}

function stripWeatherFromObjective(text: string): string {
  if (!text) return text;
  return text.split("\n").map(line => {
    if (/^Weather:/i.test(line.trim())) return "";
    const idx = line.search(/\.\s+Weather:/i);
    return idx !== -1 ? line.slice(0, idx + 1).trim() : line;
  }).filter(l => l.trim() !== "").join("\n").trim();
}

interface Block {
  kind: "warm" | "drill" | "cool" | "extra";
  badge: string;
  label: string;   // "Station 1", "Warm up"
  short: string;   // label inside the timeline bar
  name: string;
  start: number;   // minutes from session start
  dur: number;
  desc: string;
  points: string[];
  variation: string;
  imageUrl: string | null;
  image: PDFImage | null;
  video: string;
  colour: RGB;
}

/** One measurable/drawable row of a card body. */
interface Item { h: number; draw: (c: Canvas, x: number, top: number) => void }

export async function buildSessionPlanPdf(plan: PlanJson, event: EventData, format: "a4" | "mobile" = "a4"): Promise<Uint8Array> {
  const mobile = format === "mobile";
  const club = event.club;
  const th: Theme = makeTheme(club);
  const doc = await PDFDocument.create();
  const f: Fonts = await loadFonts(doc);
  const T = (s: any) => clean(s, f);

  // ── Data ──
  const start = irishParts(event.event_date);
  const typeCode = [event.event_code, event.event_type].filter(Boolean).join(" ");
  const isStations = !!plan.station_setup?.trim();

  const blocks: Block[] = [];
  const add = (b: Omit<Block, "start" | "image">) => blocks.push({ ...b, start: 0, image: null });
  if (plan.pre_session?.description?.trim()) {
    add({ kind: "extra", badge: "P", label: "Pre-session", short: "Pre", name: "Pre-session", dur: plan.pre_session.duration_mins || 0,
      desc: T(plan.pre_session.description), points: [], variation: "", imageUrl: null, video: "", colour: fixed.slate });
  }
  const wu = plan.warm_up;
  if (wu && (wu.description?.trim() || wu.game_name || wu.coaching_points?.length)) {
    add({ kind: "warm", badge: "W", label: "Warm up", short: "Warm up", name: T(wu.game_name || "Warm up"), dur: wu.duration_mins || 0,
      desc: T(wu.description), points: (wu.coaching_points || []).map(T), variation: "", imageUrl: wu.game_image || null,
      video: wu.game_video?.trim() || "", colour: fixed.amber });
  }
  (plan.drills || []).forEach((d, i) => {
    const lab = `${isStations ? "Station" : "Drill"} ${i + 1}`;
    add({ kind: "drill", badge: String(i + 1), label: lab, short: lab, name: T(d.game_name || lab), dur: d.duration_mins || 0,
      desc: T(d.description), points: (d.coaching_points || []).map(T), variation: T(d.variation || ""), imageUrl: d.game_image || null,
      video: d.game_video?.trim() || "", colour: i % 2 ? th.s : th.p });
  });
  const cd = plan.cool_down;
  if (cd && (cd.description?.trim() || cd.coaching_points?.length)) {
    add({ kind: "cool", badge: "C", label: "Cool down", short: "Cool down", name: T(cd.game_name || "Cool down"), dur: cd.duration_mins || 0,
      desc: T(cd.description), points: (cd.coaching_points || []).map(T), variation: "", imageUrl: cd.game_image || null,
      video: cd.game_video?.trim() || "", colour: fixed.teal });
  }
  if (plan.post_session?.description?.trim()) {
    add({ kind: "extra", badge: "P", label: "Post-session", short: "Post", name: "Post-session", dur: plan.post_session.duration_mins || 0,
      desc: T(plan.post_session.description), points: [], variation: "", imageUrl: null, video: "", colour: fixed.slate });
  }
  let acc = 0;
  for (const b of blocks) { b.start = acc; acc += b.dur; }
  const totalMins = plan.total_duration_mins || acc;
  const at = (m: number) => (start ? clock(start.minutes + m) : `${m}'`);
  const range = (b: Block) => (start ? `${clock(start.minutes + b.start)} – ${clock(start.minutes + b.start + b.dur)}` : "");

  // Images in parallel
  const [crest, sessionImg, ...blockImgs] = await Promise.all([
    embedImage(doc, club.crest), embedImage(doc, plan.session_image), ...blocks.map(b => embedImage(doc, b.imageUrl)),
  ]);
  blocks.forEach((b, i) => (b.image = blockImgs[i]));

  const teamLine = T(event.team_name || club.club_name);
  const contLeft = [event.team_name, typeCode].filter(Boolean).join(" · ") || T(plan.session_title) || "Session plan";
  const contRight = start ? `${start.date} · ${start.time}` : "";
  const footSub = T([event.team_name, typeCode].filter(Boolean).join(" · ") || plan.session_title || "Session plan");
  const whenParts = [
    start?.date,
    start ? `${start.time} – ${clock(start.minutes + totalMins)}` : null,
    event.squad_name ? event.squad_name + (event.squad_grade ? ` (${event.squad_grade})` : "") : null,
    teamLine !== club.club_name ? club.club_name : (totalMins ? `${totalMins} minute session` : null),
  ].filter(Boolean) as string[];

  // ── Page geometry ──
  const PW = mobile ? 390 : 595.28;
  const PH = mobile ? 780 : 841.89;
  const M = mobile ? 14 : 28;
  const CW = PW - 2 * M;
  const FOOT = 40;            // space kept for the footer
  const pages: Canvas[] = [];

  const newPage = (h = PH) => {
    const c = new Canvas(doc, doc.addPage([PW, h]), PW, h, f);
    pages.push(c);
    return c;
  };
  /** Phone pages: lay out once on a dry canvas to measure, then draw on a page of exactly that height. */
  const fitted = (draw: (c: Canvas) => number) => {
    const used = draw(Canvas.dry(doc, PW, f));
    const c = newPage(Math.ceil(used + FOOT + 6));
    draw(c);
  };

  // ── Overview pieces ──
  function hero(c: Canvas): number {
    const padY = mobile ? 18 : 20, crestW = mobile ? 44 : 58, crestH = mobile ? 50 : 66;
    const h1Size = mobile ? 20 : 23;
    const textH = 8.5 + 5 + h1Size + 5 + 10.5;
    const h = Math.max(crest ? crestH : 0, textH) + padY * 2;
    c.rect(0, 0, PW, h, th.p);
    const cx = drawCrest(c, crest, M, (h - crestH) / 2, crestW, crestH);
    const tx = M + (cx ? cx + 14 : 0);
    const badgeW = mobile ? 0 : 56;
    const tw = PW - M - tx - (badgeW ? badgeW + 14 : 0);
    const ty = (h - textH) / 2;
    const kick = ["Session plan", typeCode].filter(Boolean).join(" · ");
    label(c, fitLine(T(kick).toUpperCase(), f.bold, 8.5, 7, tw)[0], tx, ty, 8.5, th.onP, f);
    const [h1, hs] = fitLine(teamLine, f.head, h1Size, 15, tw);
    c.text(h1, tx, ty + 13.5 + (h1Size - hs) / 2, hs, f.head, th.onP);
    const [when, ws] = fitLine(T(whenParts.join(" · ")), f.reg, 10.5, 8.5, tw);
    c.text(when, tx, ty + 13.5 + h1Size + 5, ws, f.reg, th.onP);
    if (badgeW && totalMins) {
      const bh = 50, bt = (h - bh) / 2, bx = PW - M - badgeW;
      c.rrect(bx, bt, badgeW, bh, 11, fixed.white);
      c.textCenter(String(totalMins), bx + badgeW / 2, bt + 8, 22, f.head, th.pText);
      c.textCenter("MINS", bx + badgeW / 2, bt + 35, 7, f.bold, th.pText, 1);
    }
    return h + drawStripes(c, h, th, 6);
  }

  function chips(c: Canvas, top: number): number {
    type Chip = { icon: IconName; value: string; label: string; wide?: boolean };
    const list: Chip[] = [];
    if (totalMins) list.push({ icon: "clock", value: String(totalMins), label: "Minutes" });
    if (plan.player_count) list.push({ icon: "players", value: String(plan.player_count), label: "Players" });
    if (plan.coach_count) list.push({ icon: "whistle", value: String(plan.coach_count), label: "Coaches" });
    const wx = splitWeather(plan.weather?.summary);
    if (wx) list.push({ icon: "sun", value: T(wx[0]), label: T(wx[1]), wide: true });
    if (!list.length) return 0;
    const H = 42, G = mobile ? 7 : 8;
    const rows: Chip[][] = mobile
      ? [list.filter(x => !x.wide), list.filter(x => x.wide)].filter(r => r.length)
      : [list];
    let y = top;
    for (const row of rows) {
      const weights = row.map(x => (x.wide && !mobile ? 1.6 : 1));
      const per = (CW - G * (row.length - 1)) / weights.reduce((a, b) => a + b, 0);
      let x = M;
      row.forEach((ch, i) => {
        const w = per * weights[i];
        c.rrect(x, y, w, H, 9, fixed.white, fixed.line, 1);
        c.rrect(x + 9, y + 9, 24, 24, 7, th.sTint);
        c.icon(ch.icon, x + 13, y + 13, 16, th.sText, 2);
        const vx = x + 41, vw = w - 41 - 8;
        if (ch.value) {
          c.text(fitLine(ch.value, f.head, 14, 10, vw)[0], vx, y + 8, 14, f.head, fixed.ink);
          c.text(fitLine(ch.label.toUpperCase(), f.reg, 7, 6, vw)[0], vx, y + 26, 7, f.reg, fixed.muted, 0.6);
        } else {
          const ls = wrap(ch.label, f.reg, 8.5, vw).slice(0, 2);
          ls.forEach((l, k) => c.text(l, vx, y + (H - ls.length * 11) / 2 + k * 11, 8.5, f.reg, fixed.body));
        }
        x += w + G;
      });
      y += H + G;
    }
    return y - top - G;
  }

  function focus(c: Canvas, top: number): number {
    const title = T(plan.session_title || "");
    const obj = T(stripWeatherFromObjective(plan.session_objective ?? ""));
    if (!title.trim() && !obj.trim()) return 0;
    const pl = 16, pr = 14, pt = 12, w = CW - pl - pr;
    const ts = mobile ? 16 : 15, tl = ts * 1.27, os = mobile ? 10.5 : 9.5, ol = os * 1.5;
    const tLines = wrap(title, f.head, ts, w), oLines = wrap(obj, f.reg, os, w);
    const h = pt + 7.5 + 6 + tLines.length * tl + (oLines.length ? 3 + oLines.length * ol : 0) + pt - 2;
    c.clipped(M, top, CW, h, 11, () => {
      c.rect(M, top, CW, h, fixed.tint);
      c.rect(M, top, 5, h, th.p);
    });
    let y = top + pt;
    label(c, "Today's focus", M + pl, y, 7.5, th.pText, f);
    y += 7.5 + 6;
    tLines.forEach(l => { c.text(l, M + pl, y + (tl - ts) / 2, ts, f.head, fixed.ink); y += tl; });
    y += 3;
    oLines.forEach(l => { c.text(l, M + pl, y + (ol - os) / 2, os, f.reg, fixed.body); y += ol; });
    return h;
  }

  function timeline(c: Canvas, top: number): number {
    const tot = blocks.reduce((a, b) => a + b.dur, 0);
    if (!tot || blocks.length < 2) return 0;
    let y = top + sectionHead(c, "Session at a glance", M, top, CW, f);
    const H = 30;
    const xs: number[] = [];
    c.clipped(M, y, CW, H, 8, () => {
      let x = M;
      blocks.forEach((b, i) => {
        const w = (CW * b.dur) / tot;
        xs.push(x);
        c.rect(x, y, w, H, b.colour);
        if (i > 0) c.rect(x - 1, y, 2, H, fixed.white);
        const lab = b.short;
        if (textW(lab, f.bold, 8) + 8 < w) c.textCenter(lab, x + w / 2, y + (H - 8) / 2, 8, f.bold, th.on(b.colour));
        else if (textW(b.badge, f.bold, 8) + 4 < w) c.textCenter(b.badge, x + w / 2, y + (H - 8) / 2, 8, f.bold, th.on(b.colour));
        x += w;
      });
    });
    y += H + 5;
    // time ticks under the bar; the end time wins over a crowded last tick
    const endLab = at(tot), endW = textW(endLab, f.reg, 7.5);
    let lastRight = -1;
    blocks.forEach((b, i) => {
      const lab = at(b.start), w = textW(lab, f.reg, 7.5);
      if (xs[i] < lastRight + 6 || xs[i] + w > M + CW - endW - 6) return;
      c.text(lab, xs[i], y, 7.5, f.reg, fixed.muted);
      lastRight = xs[i] + w;
    });
    c.textRight(endLab, M + CW, y, 7.5, f.reg, fixed.muted);
    return y + 7.5 - top;
  }

  function runRowH(b: Block) { return b.points[0] || b.kind === "drill" ? 31 : 21; }

  function runSheet(c: Canvas, x: number, top: number, w: number, rows: Block[], withHead: boolean): number {
    let y = top;
    if (withHead) y += sectionHead(c, "Run sheet", x, y, w, f);
    const ns = mobile ? 10 : 8.8, ss = mobile ? 9 : 8;
    for (const b of rows) {
      const h = runRowH(b);
      c.text(at(b.start), x + 4, y + 7, 8.5, f.bold, fixed.muted);
      const minS = `${b.dur} min`;
      c.textRight(minS, x + w - 4, y + 7, 8.5, f.bold, fixed.ink);
      const nx = x + (start ? 50 : 34);
      c.rrect(nx, y + 8, 8, 8, 2.5, b.colour);
      const nw = x + w - textW(minS, f.bold, 8.5) - 12 - (nx + 14);
      const nm = b.kind === "drill" && isStations ? `${b.name}` : b.name;
      c.text(fitLine(nm, f.bold, ns, ns - 1.5, nw)[0], nx + 14, y + 6.5, ns, f.bold, fixed.ink);
      const sub = b.points[0] || (b.kind === "drill" ? b.label : "");
      if (h > 21 && sub) c.text(fitLine(sub, f.reg, ss, ss - 1, nw)[0], nx + 14, y + 6.5 + ns + 3.5, ss, f.reg, fixed.muted);
      y += h;
      c.line(x, y, x + w, y, fixed.line, 0.75);
    }
    return y - top;
  }

  function stationNote(c: Canvas | null, x: number, top: number, w: number): number {
    if (!isStations) return 0;
    const size = mobile ? 9.5 : 8.5, lh = size * 1.5, pad = 9;
    const lines = wrapRuns([{ text: "Stations:", font: f.bold, color: th.sText }, { text: T(plan.station_setup), font: f.reg, color: fixed.body }], size, w - pad * 2);
    const h = lines.length * lh + pad * 2 - (lh - size);
    if (c) {
      c.rrect(x, top, w, h, 8, th.sTint);
      lines.forEach((l, i) => drawRuns(c, l, x + pad, top + pad + i * lh, size));
    }
    return h;
  }

  function pitchLayout(c: Canvas, x: number, top: number, w: number, maxH: number, withHead = true): number {
    if (!sessionImg) return 0;
    let y = top;
    if (withHead) y += sectionHead(c, "Pitch layout", x, y, w, f);
    const sc = Math.min(w / sessionImg.width, (maxH - (y - top)) / sessionImg.height);
    const iw = sessionImg.width * sc, ih = sessionImg.height * sc, ix = x + (w - iw) / 2;
    c.clipped(ix, y, iw, ih, 10, () => c.image(sessionImg, ix, y, iw, ih));
    c.rrect(ix, y, iw, ih, 10, null, fixed.line, 1);
    return y + ih - top;
  }

  // ── Card body items (shared by A4 and phone) ──
  function bodyItems(b: Block, w: number, s: { body: number; lh: number; lab: number; pt: number; plh: number; call: number; clh: number }, videoInText: boolean): Item[] {
    const items: Item[] = [];
    const { intro, steps } = splitSteps(b.desc);
    const descLines = intro.flatMap(p => wrap(p, f.reg, s.body, w));
    descLines.forEach(l => items.push({ h: s.lh, draw: (c, x, t) => c.text(l, x, t + (s.lh - s.body) / 2, s.body, f.reg, fixed.body) }));
    // numbered steps: small circle with the number, text hanging beside it
    const d = s.body * 1.6;
    steps.forEach((st, i) => {
      const lines = wrap(st, f.reg, s.body, w - d - 7);
      const top0 = i === 0 && descLines.length ? 4 : 0;
      items.push({
        h: top0 + lines.length * s.lh + 3,
        draw: (c, x, t) => {
          const y = t + top0;
          c.circle(x + d / 2, y + s.lh / 2, d / 2, th.s);
          c.textCenter(String(i + 1), x + d / 2, y + s.lh / 2 - s.body * 0.4, s.body * 0.82, f.head, th.onS);
          lines.forEach((l, k) => c.text(l, x + d + 7, y + k * s.lh + (s.lh - s.body) / 2, s.body, f.reg, fixed.body));
        },
      });
    });
    const gap = descLines.length || steps.length ? 5 : 0;
    if (b.points.length) {
      items.push({ h: s.lab + 8 + gap, draw: (c, x, t) => label(c, "Coaching points", x, t + gap + 2, s.lab, th.pText, f) });
      for (const p of b.points) {
        const h = iconList(null, [p], 0, 0, w, f, s.pt, s.plh, th.p, "check", 2);
        items.push({ h, draw: (c, x, t) => iconList(c, [p], x, t, w, f, s.pt, s.plh, th.p, "check", 2, th.onP) });
      }
    }
    if (b.variation) {
      const ideas = splitIdeas(b.variation);
      if (ideas.length > 1) {
        const h = calloutList(null, "Make it harder", ideas, 0, 0, w, f, th, s.call, s.clh);
        items.push({ h: h + 7, draw: (c, x, t) => calloutList(c, "Make it harder", ideas, x, t + 7, w, f, th, s.call, s.clh) });
      } else {
        const one = ideas[0] ?? b.variation;
        const h = callout(null, "Make it harder:", one, 0, 0, w, f, th, s.call, s.clh);
        items.push({ h: h + 7, draw: (c, x, t) => callout(c, "Make it harder:", one, x, t + 7, w, f, th, s.call, s.clh) });
      }
    }
    if (b.video && videoInText) {
      const o = mobile
        ? { qr: 46, title: 11.5, sub: 9, boxed: true, subText: "Tap here, or scan from another phone" }
        : { qr: 40, title: 9, sub: 7.5, boxed: true, subText: "Scan with your phone camera, or tap here" };
      items.push({ h: o.qr + 16 + 10, draw: (c, x, t) => videoRow(c, b.video, x, t + 10, w, f, th, o) });
    }
    return items;
  }

  // ── A4 card: header row, diagram left, text right ──
  const A4S = { body: 9, lh: 13.5, lab: 7.5, pt: 9, plh: 13.5, call: 8.5, clh: 12.5 };
  const HEAD = 40;

  function a4Layout(b: Block, w: number) {
    const inner = w - 24;
    const picW = b.image ? inner * 0.46 : 0;
    const imgH = b.image ? Math.min(picW * b.image.height / b.image.width, 190) : 0;
    const imgW = b.image ? imgH * b.image.width / b.image.height : 0;
    const txtW = b.image ? inner - picW - 12 : inner;
    const items = bodyItems(b, txtW, A4S, !b.image);
    const vidH = b.image && b.video ? 8 + 40 : 0;
    const leftH = imgH + vidH;
    const rightH = items.reduce((a, it) => a + it.h, 0);
    return { picW, imgW, imgH, txtW, items, h: HEAD + 10 + Math.max(leftH, rightH) + 12 };
  }

  function cardHeader(c: Canvas, b: Block, x: number, top: number, w: number) {
    c.rect(x, top, w, HEAD, fixed.head);
    c.line(x, top + HEAD, x + w, top + HEAD, fixed.line, 1);
    c.circle(x + 24, top + HEAD / 2, 12, b.colour);
    c.textCenter(b.badge, x + 24, top + HEAD / 2 - 5.5, 11, f.head, th.on(b.colour));
    const dur = b.dur ? `${b.dur} min` : "";
    const pw = dur ? pillW(dur, f, 8.5) : 0;
    const rng = range(b), rw = rng ? textW(rng, f.reg, 8.5) + 8 : 0;
    if (dur) drawPill(c, dur, x + w - 12 - pw, top + (HEAD - 17) / 2, 8.5, th.s, th.onS, f);
    if (rng) c.text(rng, x + w - 12 - pw - rw, top + (HEAD - 8.5) / 2, 8.5, f.reg, fixed.muted);
    const nw = w - 44 - 12 - pw - rw - 8;
    label(c, fitLine(b.label.toUpperCase(), f.bold, 7, 6, nw)[0], x + 44, top + 9, 7, fixed.muted, f);
    c.text(fitLine(b.name, f.head, 12.5, 10, nw)[0], x + 44, top + 19, 12.5, f.head, fixed.ink);
  }

  function drawA4Card(c: Canvas, b: Block, x: number, top: number, w: number, L: ReturnType<typeof a4Layout>) {
    c.clipped(x, top, w, L.h, 10, () => {
      c.rect(x, top, w, L.h, fixed.white);
      cardHeader(c, b, x, top, w);
    });
    c.rrect(x, top, w, L.h, 10, null, fixed.line, 1);
    const bt = top + HEAD + 10;
    if (b.image) {
      c.clipped(x + 12, bt, L.imgW, L.imgH, 7, () => c.image(b.image!, x + 12, bt, L.imgW, L.imgH));
      if (b.video) {
        videoRow(c, b.video, x + 12, bt + L.imgH + 8, L.picW, f, th,
          { qr: 40, title: 8.5, sub: 7.5, boxed: false, subText: "Scan, or tap here in the PDF" });
      }
    }
    let y = bt;
    const tx = x + 12 + (b.image ? L.picW + 12 : 0);
    for (const it of L.items) { it.draw(c, tx, y); y += it.h; }
  }

  // ── Phone card: coloured header band, full-width diagram, text below ──
  const PHS = { body: 11, lh: 16.5, lab: 8, pt: 11, plh: 16, call: 10.5, clh: 15 };

  function drawPhoneCard(c: Canvas, b: Block, x: number, top: number, w: number): number {
    const onC = th.on(b.colour);
    const nameLines = wrap(b.name, f.head, 18, w - 28 - 37).slice(0, 2);
    const bandH = 11 + 8.5 + 7 + Math.max(28, nameLines.length * 21) + 12;
    const imgH = b.image ? Math.min(w * b.image.height / b.image.width, 320) : 0;
    const imgW = b.image ? imgH * b.image.width / b.image.height : 0;
    const items = bodyItems(b, w - 28, PHS, true);
    const bodyH = items.reduce((a, it) => a + it.h, 0);
    const h = bandH + imgH + 12 + bodyH + 14;
    c.clipped(x, top, w, h, 14, () => {
      c.rect(x, top, w, h, fixed.white);
      c.rect(x, top, w, bandH, b.colour);
      if (b.image) c.image(b.image, x + (w - imgW) / 2, top + bandH, imgW, imgH);
    });
    c.rrect(x, top, w, h, 14, null, fixed.line, 1);
    // band: label · times + pill, then badge + name
    const dur = b.dur ? `${b.dur} min` : "";
    const pw = dur ? pillW(dur, f, 9) : 0;
    if (dur) drawPill(c, dur, x + w - 14 - pw, top + 9, 9, fixed.white, onC === fixed.white ? b.colour : fixed.ink, f);
    const r1 = [b.label, range(b)].filter(Boolean).join(" · ").toUpperCase();
    label(c, fitLine(r1, f.bold, 8.5, 7, w - 28 - pw - 8)[0], x + 14, top + 13, 8.5, onC, f);
    const r2 = top + 11 + 8.5 + 7;
    const nameBlock = Math.max(28, nameLines.length * 21);
    c.circle(x + 14 + 14, r2 + nameBlock / 2, 14, onC);
    c.textCenter(b.badge, x + 28, r2 + nameBlock / 2 - 6.5, 13, f.head, b.colour);
    nameLines.forEach((l, i) => c.text(l, x + 14 + 37, r2 + (nameBlock - nameLines.length * 21) / 2 + i * 21 + 1.5, 18, f.head, onC));
    let y = top + bandH + imgH + 12;
    for (const it of items) { it.draw(c, x + 14, y); y += it.h; }
    return h;
  }

  // ── Compose ──
  if (!mobile) {
    // Page 1: overview
    let c = newPage();
    let y = hero(c) + 16;
    const ch = chips(c, y); if (ch) y += ch + 14;
    const fo = focus(c, y); if (fo) y += fo + 16;
    const tl = timeline(c, y); if (tl) y += tl + 16;
    const bottom = PH - FOOT - 6;
    const leftW = sessionImg ? (CW - 16) * 0.56 : CW;
    const rightX = M + leftW + 16, rightW = CW - leftW - 16;
    const colTop = y;
    // run sheet, spilling onto a continuation page if a plan is very long
    let ly = y + sectionHead(c, "Run sheet", M, y, leftW, f);
    for (const b of blocks) {
      if (ly + runRowH(b) > bottom) { c = newPage(); ly = drawContBand(c, th, f, T(contLeft), contRight, M) + 18; }
      ly += runSheet(c, M, ly, leftW, [b], false);
    }
    const nh = stationNote(null, M, 0, leftW);
    if (nh) {
      if (ly + 10 + nh > bottom) { c = newPage(); ly = drawContBand(c, th, f, T(contLeft), contRight, M) + 8; }
      stationNote(c, M, ly + 10, leftW); ly += 10 + nh;
    }
    if (sessionImg) pitchLayout(pages[0], rightX, colTop, rightW, bottom - colTop);

    // Cards, packed onto A4 pages
    c = newPage();
    const contTop = drawContBand(c, th, f, T(contLeft), contRight, M) + 18;
    y = contTop;
    const fullH = bottom - contTop;
    for (const b of blocks) {
      const L = a4Layout(b, CW);
      if (y + L.h > bottom && y > contTop) {
        c = newPage(); y = drawContBand(c, th, f, T(contLeft), contRight, M) + 18;
      }
      if (L.h > fullH) {
        // Flow layout for an unusually long card: header, then items with page breaks.
        c.rrect(M, y, CW, HEAD, 10, fixed.head, fixed.line, 1);
        cardHeader(c, b, M, y, CW);
        y += HEAD + 10;
        if (b.image) {
          const iw = Math.min(CW, 320), ih = iw * b.image.height / b.image.width;
          if (y + ih > bottom) { c = newPage(); y = drawContBand(c, th, f, T(contLeft), contRight, M) + 18; }
          c.clipped(M, y, iw, ih, 7, () => c.image(b.image!, M, y, iw, ih));
          y += ih + 10;
        }
        for (const it of bodyItems(b, CW, A4S, true)) {
          if (y + it.h > bottom) { c = newPage(); y = drawContBand(c, th, f, T(contLeft), contRight, M) + 18; }
          it.draw(c, M, y); y += it.h;
        }
        y += 14;
        continue;
      }
      drawA4Card(c, b, M, y, CW, L);
      y += L.h + 12;
    }
  } else {
    // Page 1: overview, sized to content
    fitted(c => {
      let y = hero(c) + 14;
      const ch = chips(c, y); if (ch) y += ch + 14;
      const fo = focus(c, y); if (fo) y += fo + 16;
      const tl = timeline(c, y); if (tl) y += tl + 16;
      y += runSheet(c, M, y, CW, blocks, true);
      return y + 6;
    });
    // Page 2: pitch layout + station note
    if (sessionImg || isStations) {
      fitted(c => {
        let y = drawContBand(c, th, f, T(contLeft), contRight, M) + 14;
        if (sessionImg) y += pitchLayout(c, M, y, CW, 640) + 10;
        if (isStations) y += stationNote(c, M, y, CW);
        return y + 8;
      });
    }
    // One card per page
    for (const b of blocks) {
      fitted(c => {
        const y = drawContBand(c, th, f, T(contLeft), contRight, M) + 14;
        return y + drawPhoneCard(c, b, M, y, CW) + 8;
      });
    }
  }

  drawFooters(doc, pages, th, f, T(club.club_name), footSub, M);
  return doc.save();
}
