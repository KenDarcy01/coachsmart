// deno-lint-ignore-file no-explicit-any
// Scouting report PDF in the club's colours with its crest. "a4" for printing, "mobile" is a
// narrow page for sharing to phones. Sections flow down the page and move to a new page when
// they don't fit.
import type { ClubData, RGB } from "../_shared/pdf-kit.ts";
import {
  PDFDocument, Canvas, makeTheme, loadFonts, embedImage, clean, fixed, wrap, fitLine, textW,
  drawCrest, drawStripes, drawFooters, drawContBand, label, sectionHead, irishParts,
} from "../_shared/pdf-kit.ts";
import { rgb } from "npm:pdf-lib@1.17.1";
import type { Report } from "./report.ts";

const LOSS = rgb(0xd6 / 255, 0x2f / 255, 0x3a / 255);
const WIN_TEXT = rgb(0x1d / 255, 0x7a / 255, 0x45 / 255);

const shortDate = (d: string) => {
  const p = irishParts(`${d}T12:00:00Z`);
  return p ? p.date : d;
};
const signed = (m: number) => (m > 0 ? `+${m}` : String(m));

export async function buildScoutingPdf(data: any, club: ClubData, format: "a4" | "mobile", includeNotes: boolean): Promise<Uint8Array> {
  const mobile = format === "mobile";
  const r: Report = data.report;
  const doc = await PDFDocument.create();
  const [f, crest] = await Promise.all([loadFonts(doc), embedImage(doc, club.crest)]);
  const th = makeTheme(club);
  const T = (s: string | null | undefined) => clean(s, f);

  const PW = mobile ? 390 : 595.28, PH = mobile ? 780 : 841.89;
  const M = mobile ? 14 : 28, CW = PW - 2 * M, FOOT = 40, GAP = mobile ? 14 : 16;
  const bottom = PH - FOOT - 6;
  const pages: Canvas[] = [];
  const newPage = () => { const c = new Canvas(doc, doc.addPage([PW, PH]), PW, PH, f); pages.push(c); return c; };

  const title = `${r.opp.team} · ${r.opp.age} ${r.opp.code}`;
  const ev = data.event || {};
  const when = irishParts(ev.date);
  const ha = String(ev.home_away || "").toLowerCase();
  const where = data.fixture?.venue || (ha.startsWith("h") ? "Home" : ha.startsWith("a") ? "Away" : "");
  const sub = [when ? `${when.date} ${when.time}` : null, where || null,
    r.last_result ? `Results to ${shortDate(r.last_result)}` : "No results yet this season"].filter(Boolean).join(" · ");
  const contLeft = `${r.opp.team} · scouting report`;

  // ── Hero ──
  let c = newPage();
  let y = 0;
  {
    const padY = mobile ? 16 : 20, crestW = mobile ? 44 : 58, crestH = mobile ? 50 : 66, h1 = mobile ? 18 : 23;
    const textH = 8.5 + 5 + h1 + 5 + 10.5;
    const h = Math.max(crest ? crestH : 0, textH) + padY * 2;
    c.rect(0, 0, PW, h, th.p);
    const cx = drawCrest(c, crest, M, (h - crestH) / 2, crestW, crestH);
    const tx = M + (cx ? cx + 14 : 0), tw = PW - M - tx, ty = (h - textH) / 2;
    label(c, fitLine(T(`${club.club_name} · Scouting report`).toUpperCase(), f.bold, 8.5, 7, tw)[0], tx, ty, 8.5, th.onP, f);
    const [t1, ts] = fitLine(T(title), f.head, h1, 13, tw);
    c.text(t1, tx, ty + 13.5 + (h1 - ts) / 2, ts, f.head, th.onP);
    const [s1, ss] = fitLine(T(sub), f.reg, 10.5, 8, tw);
    c.text(s1, tx, ty + 13.5 + h1 + 5, ss, f.reg, th.onP);
    y = h + drawStripes(c, h, th, 6) + GAP;
  }

  /** Lays a section out on a dry canvas to measure it, starts a new page if needed, then draws it. */
  const place = (draw: (c: Canvas, top: number) => number) => {
    const h = draw(Canvas.dry(doc, PW, f), 0);
    if (y + h > bottom && y > 80) { c = newPage(); y = drawContBand(c, th, f, T(contLeft), "", M) + GAP; }
    draw(c, y);
    y += h + GAP;
  };
  const head = (c: Canvas, s: string, top: number) => sectionHead(c, s, M, top, CW, f);

  // ── Season so far ──
  const rec = r.record;
  place((c, top) => {
    let yy = top + head(c, "Season so far", top);
    const tiles: [string, string][] = [
      [String(rec.p), "Played"], [`${rec.w}-${rec.d}-${rec.l}`, "W-D-L"],
      [rec.p ? rec.avgFor.toFixed(1) : "-", "Avg for"], [rec.p ? rec.avgAgainst.toFixed(1) : "-", "Avg against"],
      [`${r.home.w}/${r.home.p}`, "Home wins"], [`${r.away.w}/${r.away.p}`, "Away wins"],
    ];
    const per = mobile ? 3 : 6, G = 7, w = (CW - G * (per - 1)) / per, H = 44;
    tiles.forEach(([v, l], i) => {
      const x = M + (i % per) * (w + G), t = yy + Math.floor(i / per) * (H + G);
      c.rrect(x, t, w, H, 8, fixed.white, fixed.line, 1);
      c.textCenter(fitLine(T(v), f.head, 16, 10, w - 6)[0], x + w / 2, t + 8, 16, f.head, fixed.ink);
      c.textCenter(l.toUpperCase(), x + w / 2, t + 29, 6.5, f.reg, fixed.muted, 0.5);
    });
    yy += Math.ceil(tiles.length / per) * (H + G) - G;
    if (r.form.length) {
      yy += 10;
      c.text("LAST 5 (NEWEST FIRST)", M, yy + 3, 7, f.bold, fixed.muted, 0.6);
      let fx = M + textW("LAST 5 (NEWEST FIRST)", f.bold, 7, 0.6) + 10;
      for (const res of r.form) {
        c.rrect(fx, yy, 18, 16, 4, res === "W" ? th.p : res === "L" ? LOSS : fixed.slate);
        c.textCenter(res, fx + 9, yy + 4, 8.5, f.bold, fixed.white);
        fx += 22;
      }
      yy += 16;
    }
    return yy - top;
  });

  // ── The short version (AI) ──
  if (data.summary?.length) {
    place((c, top) => {
      let yy = top + head(c, "The short version", top);
      const size = mobile ? 10 : 9.5, lh = size * 1.45;
      for (const p of data.summary as string[]) {
        const ls = wrap(T(p), f.reg, size, CW - 14);
        c.circle(M + 3, yy + size * 0.55, 2, th.p);
        ls.forEach((l, i) => c.text(l, M + 12, yy + i * lh, size, f.reg, fixed.body));
        yy += ls.length * lh + 4;
      }
      return yy - top;
    });
  }

  // ── Margin game by game ──
  if (r.games.length) {
    place((c, top) => {
      let yy = top + head(c, "Margin game by game", top);
      const H = mobile ? 120 : 130, L = 26, n = r.games.length;
      const mx = Math.max(10, ...r.games.map(g => Math.abs(g.m)));
      const topV = Math.ceil(mx / 10) * 10;
      const y0 = yy + 6, plotH = H - 30;
      const Y = (v: number) => y0 + (topV - v) / (2 * topV) * plotH;
      for (const v of [topV, 0, -topV]) {
        c.line(M + L, Y(v), M + CW, Y(v), v === 0 ? fixed.muted : fixed.line, v === 0 ? 1 : 0.6);
        c.textRight(v ? signed(v) : "0", M + L - 5, Y(v) - 3.5, 7, f.reg, fixed.muted);
      }
      const bw = (CW - L) / n, w = Math.min(28, bw * 0.7);
      r.games.forEach((g, i) => {
        const x = M + L + i * bw + (bw - w) / 2;
        const color = g.res === "W" ? th.p : g.res === "L" ? LOSS : fixed.slate;
        const a = Y(Math.max(g.m, 0)), b = Y(Math.min(g.m, 0));
        c.rect(x, Math.min(a, b) - (g.m === 0 ? 1 : 0), w, Math.max(2, Math.abs(b - a)), color);
        if (n <= 16) {
          const ab = (g.opp.match(/[A-Z0-9]/g) || []).join("").slice(0, 4) || g.opp.slice(0, 3).toUpperCase();
          c.textCenter(T(ab), x + w / 2, y0 + plotH + 6, 6.5, f.reg, fixed.muted);
        }
      });
      return H + (yy - top);
    });
  }

  // ── Every game ──
  type Col = { h: string; w: number; right?: boolean };
  const table = (c: Canvas, top: number, cols: Col[], rows: { cells: string[]; color?: (RGB | null)[]; bold?: boolean }[]) => {
    const size = mobile ? 8.5 : 8.5, rh = size * 2.1;
    let x = M;
    const xs = cols.map(col => { const s = x; x += col.w * CW; return s; });
    cols.forEach((col, i) => c.text(col.h.toUpperCase(), xs[i] + 3, top, 6.5, f.bold, fixed.muted, 0.5));
    c.line(M, top + 11, M + CW, top + 11, th.p, 1.5);
    let yy = top + 15;
    for (const row of rows) {
      row.cells.forEach((cell, i) => {
        const font = row.bold || row.color?.[i] ? f.bold : f.reg;
        const [t, s] = fitLine(T(cell), font, size, 6.5, cols[i].w * CW - 6);
        c.text(t, xs[i] + 3, yy + (rh - s) / 2 - 1, s, font, row.color?.[i] ?? fixed.body);
      });
      yy += rh;
      c.line(M, yy, M + CW, yy, fixed.line, 0.5);
    }
    return yy - top;
  };
  const resColor = (res: string) => (res === "W" ? WIN_TEXT : res === "L" ? LOSS : fixed.muted);

  if (r.games.length) {
    place((c, top) => {
      const yy = top + head(c, "Every game", top);
      const cols: Col[] = mobile
        ? [{ h: "Date", w: 0.19 }, { h: "Opponent", w: 0.38 }, { h: "", w: 0.07 }, { h: "Score", w: 0.24 }, { h: "", w: 0.12 }]
        : [{ h: "Date", w: 0.13 }, { h: "Opponent", w: 0.31 }, { h: "H/A", w: 0.06 }, { h: "Score", w: 0.16 }, { h: "Result", w: 0.1 }, { h: "Competition", w: 0.24 }];
      const rows = r.games.map(g => ({
        cells: [shortDate(g.date), g.opp, g.home ? "H" : "A", `${g.us} v ${g.them}`, `${g.res} ${g.m ? signed(g.m) : "0"}`, g.comp].slice(0, cols.length),
        color: [null, g.vsUs ? th.pText : null, null, null, resColor(g.res), null],
      }));
      return yy - top + table(c, yy, cols, rows);
    });
  }

  // ── Same opponents ──
  if (r.common.length) {
    place((c, top) => {
      const yy = top + head(c, "Teams both sides have played", top);
      const fmt = (xs: { res: string; m: number }[]) => xs.map(x => `${x.res} ${x.m ? signed(x.m) : "0"}`).join(", ");
      const cols: Col[] = [{ h: "Opponent", w: 0.4 }, { h: r.opp.team, w: 0.3 }, { h: T(club.club_name), w: 0.3 }];
      const rows = r.common.map(x => ({
        cells: [x.opp, fmt(x.them), fmt(x.us)],
        color: [null, resColor(x.them[x.them.length - 1].res), resColor(x.us[x.us.length - 1].res)],
      }));
      return yy - top + table(c, yy, cols, rows);
    });
  }

  // ── Scored v conceded ──
  if (r.games.length) {
    place((c, top) => {
      let yy = top + head(c, "Scored v conceded, per game", top);
      const H = mobile ? 120 : 130, L = 26, n = r.games.length;
      const mx = Math.max(10, ...r.games.map(g => Math.max(g.u, g.t)));
      const topV = Math.ceil(mx / 10) * 10, step = topV <= 50 ? 10 : 20;
      const y0 = yy + 6, plotH = H - 30;
      const Y = (v: number) => y0 + (topV - v) / topV * plotH;
      for (let v = 0; v <= topV; v += step) {
        c.line(M + L, Y(v), M + CW, Y(v), v === 0 ? fixed.muted : fixed.line, v === 0 ? 1 : 0.6);
        c.textRight(String(v), M + L - 5, Y(v) - 3.5, 7, f.reg, fixed.muted);
      }
      const bw = (CW - L) / n, w = Math.min(12, bw * 0.36);
      r.games.forEach((g, i) => {
        const x = M + L + i * bw + (bw - 2 * w) / 2;
        c.rect(x, Y(g.u), w - 1, Math.max(1, Y(0) - Y(g.u)), th.p);
        c.rect(x + w, Y(g.t), w - 1, Math.max(1, Y(0) - Y(g.t)), LOSS);
        if (n <= 8 || i % 2 === 0) c.textCenter(T(shortDate(g.date).replace(/ \d{4}$/, "")), x + w, y0 + plotH + 6, 6, f.reg, fixed.muted);
      });
      c.rect(M + L, y0 + plotH + 16, 7, 7, th.p); c.text("Scored", M + L + 10, y0 + plotH + 15, 7, f.reg, fixed.muted);
      c.rect(M + L + 50, y0 + plotH + 16, 7, 7, LOSS); c.text("Conceded", M + L + 60, y0 + plotH + 15, 7, f.reg, fixed.muted);
      return H + 12 + (yy - top);
    });
    const goalsOf = (sc: string) => Number(String(sc).split("-")[0]) || 0, pointsOf = (sc: string) => Number(String(sc).split("-")[1]) || 0;
    const gf = r.games.reduce((a, g) => a + goalsOf(g.us), 0), pf = r.games.reduce((a, g) => a + pointsOf(g.us), 0);
    const ga = r.games.reduce((a, g) => a + goalsOf(g.them), 0), pa = r.games.reduce((a, g) => a + pointsOf(g.them), 0);
    place((c, top) => {
      let yy = top + head(c, "Goals and points", top);
      const line = (lab: string, gl: number, pt: number, col: RGB) => {
        const tot = gl * 3 + pt, barW = CW - 70, w = tot ? barW * gl * 3 / tot : 0;
        c.text(lab, M, yy + 3, 8.5, f.bold, fixed.ink);
        c.rrect(M + 64, yy, barW, 14, 3, fixed.line);
        if (w) c.rrect(M + 64, yy, w, 14, 3, col);
        c.text(`Goals ${gl} (${tot ? Math.round(100 * gl * 3 / tot) : 0}% of total) · Points ${pt}`, M + 64, yy + 18, 7.5, f.reg, fixed.muted);
        yy += 34;
      };
      line("Scored", gf, pf, th.p);
      line("Conceded", ga, pa, LOSS);
      return yy - top;
    });
  }

  // ── Their games v us ──
  if (r.h2h.length) {
    place((c, top) => {
      const yy = top + head(c, T(`Their games v ${club.club_name}`), top);
      const cols: Col[] = mobile
        ? [{ h: "Date", w: 0.2 }, { h: "Us", w: 0.38 }, { h: "Score", w: 0.24, right: true }, { h: "Result", w: 0.18, right: true }]
        : [{ h: "Date", w: 0.14 }, { h: "Us", w: 0.3 }, { h: "H/A", w: 0.08 }, { h: "Score", w: 0.16, right: true }, { h: "Result", w: 0.12, right: true }, { h: "Competition", w: 0.2 }];
      const rows = r.h2h.map(g => ({
        cells: [shortDate(g.date), g.opp, g.home ? "H" : "A", `${g.us} v ${g.them}`, `${g.res} ${g.m ? signed(g.m) : "0"}`, g.comp].filter((_, i) => !mobile || [0, 1, 3, 4].includes(i)),
        color: mobile ? [null, null, null, resColor(g.res)] : [null, null, null, null, resColor(g.res), null],
      }));
      return yy - top + table(c, yy, cols, rows);
    });
  }

  // ── League tables ──
  for (const t of r.tables || (r.table ? [r.table] : [])) {
    place((c, top) => {
      const yy = top + head(c, T(t.comp || "League table"), top);
      const cols: Col[] = [{ h: "#", w: 0.07 }, { h: "Team", w: 0.43 }, { h: "P", w: 0.08 }, { h: "W", w: 0.08 }, { h: "D", w: 0.08 }, { h: "L", w: 0.08 }, { h: "+/-", w: 0.1 }, { h: "Pts", w: 0.08 }];
      const rows = t.rows.slice(0, 14).map((x, i) => {
        const col = x.opp ? LOSS : x.us ? th.pText : null;
        return { cells: [String(i + 1), x.team, String(x.p), String(x.w), String(x.d), String(x.l), signed(x.diff), String(x.pts)], color: Array(8).fill(col), bold: !!col };
      });
      return yy - top + table(c, yy, cols, rows);
    });
  }

  const textBlock = (heading: string, text: string, by: string) => place((c, top) => {
    let yy = top + head(c, heading, top);
    const size = mobile ? 10 : 9.5, lh = size * 1.45;
    const ls = wrap(T(text), f.reg, size, CW - 12);
    c.rect(M, yy, 2.5, ls.length * lh, th.p);
    ls.forEach((l, i) => c.text(l, M + 10, yy + i * lh, size, f.reg, fixed.body));
    yy += ls.length * lh;
    if (by) { c.text(T(by), M + 10, yy + 4, 7.5, f.reg, fixed.muted); yy += 14; }
    return yy - top;
  });

  if (includeNotes && String(data.notes || "").trim()) {
    textBlock("Coach notes", data.notes, data.notes_by || "");
  }

  drawFooters(doc, pages, th, f, T(club.club_name), "Results from the Dublin fixtures", M);
  return doc.save();
}
