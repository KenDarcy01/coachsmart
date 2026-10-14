// deno-lint-ignore-file no-explicit-any
// Game card PDF: one page per game. Hero with the game name and tags, a big diagram,
// numbered set-up / how-to-play steps, teaching points and variations, video QR.
// Phone ("mobile") pages stack everything in one column and are sized to their content.
import type { Fonts, Theme, ClubData } from "../_shared/pdf-kit.ts";
import {
  PDFDocument, Canvas, makeTheme, loadFonts, embedImage, clean, fixed, wrap, fitLine,
  drawCrest, drawStripes, drawFooters, drawContBand, label, sectionHead, videoRow, iconList, toPoints, textW,
} from "../_shared/pdf-kit.ts";

export type { ClubData };

export interface GameData {
  game_name: string;
  game_setup: string | null;
  game_how_to_play: string | null;
  game_variations: string | null;
  game_teaching_points: string | null;
  game_image: string | null;
  game_details_image: string | null;
  game_video: string | null;
  game_code?: string[] | null;
  game_age?: string[] | null;
  game_skill?: string[] | null;
  game_type?: string[] | null;
}

/** Short tag list from the game's own code / age / skill / type. */
function gameTags(g: GameData): string[] {
  const tags: string[] = [];
  (g.game_code || []).slice(0, 2).forEach(c => c && tags.push(c));
  const ages = (g.game_age || []).filter(Boolean);
  const nums = ages.map(a => /^u\s?(\d+)$/i.exec(a.trim())).filter(Boolean).map(m => Number(m![1]));
  if (nums.length && nums.length === ages.length) {
    const lo = Math.min(...nums), hi = Math.max(...nums);
    tags.push(lo === hi ? `U${lo}` : `U${lo} – U${hi}`);
  } else ages.slice(0, 2).forEach(a => tags.push(a));
  (g.game_skill || []).slice(0, 2).forEach(s => s && tags.push(s));
  (g.game_type || []).filter(t => !/^video$/i.test(t)).slice(0, 1).forEach(t => t && tags.push(t));
  return [...new Set(tags.map(t => t.trim()).filter(Boolean))].slice(0, 6);
}

export async function buildPdf(games: GameData[], club: ClubData, isMobile = false): Promise<Uint8Array> {
  const th: Theme = makeTheme(club);
  const doc = await PDFDocument.create();
  const f: Fonts = await loadFonts(doc);
  const T = (s: any) => clean(s, f);
  const crest = await embedImage(doc, club.crest);

  const PW = isMobile ? 390 : 595.28;
  const PH = isMobile ? 780 : 841.89;
  const M = isMobile ? 14 : 28;
  const CW = PW - 2 * M;
  const FOOT = 40;
  const pages: Canvas[] = [];
  const newPage = (h = PH) => { const c = new Canvas(doc, doc.addPage([PW, h]), PW, h, f); pages.push(c); return c; };

  // Text sizes
  const S = isMobile
    ? { step: 11, slh: 16, pt: 11, plh: 16, lab: 8, h1: 21 }
    : { step: 9.5, slh: 14.25, pt: 9.5, plh: 13.8, lab: 7.5, h1: 23 };

  function hero(c: Canvas, g: GameData): number {
    const padY = isMobile ? 18 : 20, crestW = isMobile ? 44 : 58, crestH = isMobile ? 50 : 66;
    const tags = gameTags(g).map(T);
    const tx0 = M + (crest ? crestW + 14 : 0), tw = PW - M - tx0;
    const nameLines = wrap(T(g.game_name || "Game"), f.head, S.h1, tw).slice(0, 2);
    const nameLH = S.h1 * 1.12;
    // lay tags out in rows
    const tagRows: string[][] = [];
    let row: string[] = [], rw = 0;
    for (const t of tags) {
      const w = textW(t, f.bold, 8.5) + 18 + 6;
      if (row.length && rw + w > tw) { tagRows.push(row); row = []; rw = 0; }
      row.push(t); rw += w;
    }
    if (row.length) tagRows.push(row);
    const textH = 8.5 + 6 + nameLines.length * nameLH + (tagRows.length ? 6 + tagRows.length * 21 - 4 : 0);
    const h = Math.max(crest ? crestH : 0, textH) + padY * 2;
    c.rect(0, 0, PW, h, th.p);
    drawCrest(c, crest, M, (h - crestH) / 2, crestW, crestH);
    let y = (h - textH) / 2;
    label(c, fitLine(`GAME CARD · ${T(club.club_name).toUpperCase()}`, f.bold, 8.5, 7, tw)[0], tx0, y, 8.5, th.onP, f);
    y += 8.5 + 6;
    nameLines.forEach(l => { c.text(l, tx0, y + (nameLH - S.h1) / 2, S.h1, f.head, th.onP); y += nameLH; });
    y += 6;
    for (const r of tagRows) {
      let x = tx0;
      for (const t of r) {
        const w = textW(t, f.bold, 8.5) + 18;
        c.page.drawSvgPath(`M8.5,0 H${w - 8.5} A8.5,8.5 0 0 1 ${w - 8.5},17 H8.5 A8.5,8.5 0 0 1 8.5,0 Z`,
          { x, y: c.H - y, color: th.onP, opacity: 0.18 });
        c.text(t, x + 9, y + 4.3, 8.5, f.bold, th.onP);
        x += w + 6;
      }
      y += 21;
    }
    return h + drawStripes(c, h, th, 6);
  }

  // Measurable column pieces. Each returns height; draws only when c is given.
  const steps = (c: Canvas | null, items: string[], x: number, top: number, w: number) => {
    let y = top;
    const d = S.step * 1.8;
    items.forEach((it, i) => {
      const lines = wrap(it, f.reg, S.step, w - d - 8);
      if (c) {
        c.circle(x + d / 2, y + S.slh / 2, d / 2, th.s);
        c.textCenter(String(i + 1), x + d / 2, y + S.slh / 2 - S.step * 0.42, S.step * 0.88, f.head, th.onS);
        lines.forEach((l, k) => c.text(l, x + d + 8, y + k * S.slh + (S.slh - S.step) / 2, S.step, f.reg, fixed.body));
      }
      y += lines.length * S.slh + 5;
    });
    return y - top;
  };
  const section = (c: Canvas | null, title: string, items: string[], x: number, top: number, w: number) => {
    if (!items.length) return 0;
    const head = (isMobile ? 11 : 10) + 9 + 2;
    if (c) sectionHead(c, title, x, top, w, f, isMobile ? 11 : 10);
    return head + steps(c, items, x, top + head, w);
  };
  const box = (c: Canvas | null, title: string, items: string[], x: number, top: number, w: number, bg: any, fg: any, dot: any, icon: "check" | "up", onDot: any) => {
    if (!items.length) return 0;
    const pad = 12;
    const listH = iconList(null, items, 0, 0, w - pad * 2, f, S.pt, S.plh, dot, icon, 3);
    const h = pad + S.lab + 8 + listH + pad - 3;
    if (c) {
      c.rrect(x, top, w, h, 11, bg);
      label(c, title, x + pad, top + pad, S.lab, fg, f);
      iconList(c, items, x + pad, top + pad + S.lab + 8, w - pad * 2, f, S.pt, S.plh, dot, icon, 3, onDot);
    }
    return h;
  };
  const video = (c: Canvas | null, url: string, x: number, top: number, w: number) => {
    if (!url) return 0;
    const o = isMobile
      ? { qr: 50, title: 12, sub: 9, boxed: true, subText: "Tap here, or scan from another phone" }
      : { qr: 54, title: 10.5, sub: 8.5, boxed: true, subText: "Scan with your phone camera, or tap here" };
    if (c) videoRow(c, url, x, top, w, f, th, o);
    return o.qr + 16;
  };

  for (const g of games) {
    const img = await embedImage(doc, g.game_image || g.game_details_image);
    const setup = toPoints(T(g.game_setup)), play = toPoints(T(g.game_how_to_play));
    const tps = toPoints(T(g.game_teaching_points)), vars = toPoints(T(g.game_variations));
    const vid = (g.game_video || "").trim();
    const contLeft = T(g.game_name || "Game card");

    if (isMobile) {
      // One tall page per game, sized to content.
      const draw = (c: Canvas) => {
        let y = hero(c, g) + 14;
        if (img) {
          const iw = CW, ih = Math.min(iw * img.height / img.width, 420), w2 = ih * img.width / img.height;
          c.clipped(M + (CW - w2) / 2, y, w2, ih, 12, () => c.image(img, M + (CW - w2) / 2, y, w2, ih));
          y += ih + 16;
        }
        const parts: [number, (cc: Canvas | null, t: number) => number][] = [
          [0, (cc, t) => section(cc, "How to set up", setup, M, t, CW)],
          [0, (cc, t) => section(cc, "How to play", play, M, t, CW)],
          [0, (cc, t) => box(cc, "Teaching points", tps, M, t, CW, th.pTint, th.pText, th.p, "check", th.onP)],
          [0, (cc, t) => box(cc, "Variations", vars, M, t, CW, th.sTint, th.sText, th.s, "up", th.onS)],
          [0, (cc, t) => video(cc, vid, M, t, CW)],
        ];
        for (const [, fn] of parts) { const h = fn(c, y); if (h) y += h + 12; }
        return y;
      };
      const used = draw(Canvas.dry(doc, PW, f));
      draw(newPage(Math.ceil(used + FOOT)));
      continue;
    }

    // ── A4 ──
    let c = newPage();
    let y = hero(c, g) + 18;
    const bottom = PH - FOOT - 6;
    const lw = (CW - 16) * 0.545, rw = CW - lw - 16, rx = M + lw + 16;
    const leftH = () => { const a = section(null, "How to set up", setup, 0, 0, lw), b = section(null, "How to play", play, 0, 0, lw); return a + (a && b ? 12 : 0) + b; };
    const rightParts = [
      (cc: Canvas | null, t: number) => box(cc, "Teaching points", tps, rx, t, rw, th.pTint, th.pText, th.p, "check", th.onP),
      (cc: Canvas | null, t: number) => box(cc, "Variations", vars, rx, t, rw, th.sTint, th.sText, th.s, "up", th.onS),
      (cc: Canvas | null, t: number) => video(cc, vid, rx, t, rw),
    ];
    const rightH = () => rightParts.map(p => p(null, 0)).filter(Boolean).reduce((a, h, i) => a + h + (i ? 10 : 0), 0);
    const colsH = Math.max(leftH(), rightH());

    if (img) {
      // Diagram as large as possible while leaving room for the columns (minimum 190pt tall).
      const room = bottom - y - colsH - 18;
      const maxH = Math.max(190, Math.min(img.width >= img.height ? 330 : 400, room));
      const sc = Math.min(CW / img.width, maxH / img.height);
      const iw = img.width * sc, ih = img.height * sc, ix = M + (CW - iw) / 2;
      c.clipped(ix, y, iw, ih, 12, () => c.image(img, ix, y, iw, ih));
      c.rrect(ix, y, iw, ih, 12, null, fixed.line, 1);
      y += ih + 18;
    }

    if (y + colsH <= bottom) {
      // Two columns side by side
      let ly = y;
      const a = section(c, "How to set up", setup, M, ly, lw); if (a) ly += a + 12;
      section(c, "How to play", play, M, ly, lw);
      let ry = y;
      for (const p of rightParts) { const h = p(c, ry); if (h) ry += h + 10; }
    } else {
      // Long game: single column flowing over pages
      const flow: ((cc: Canvas | null, t: number) => number)[] = [
        (cc, t) => section(cc, "How to set up", setup, M, t, CW),
        (cc, t) => section(cc, "How to play", play, M, t, CW),
        (cc, t) => box(cc, "Teaching points", tps, M, t, CW, th.pTint, th.pText, th.p, "check", th.onP),
        (cc, t) => box(cc, "Variations", vars, M, t, CW, th.sTint, th.sText, th.s, "up", th.onS),
        (cc, t) => video(cc, vid, M, t, CW),
      ];
      for (const fn of flow) {
        const h = fn(null, 0);
        if (!h) continue;
        if (y + h > bottom) { c = newPage(); y = drawContBand(c, th, f, contLeft, "", M) + 18; }
        fn(c, y); y += h + 12;
      }
    }
  }

  drawFooters(doc, pages, th, f, T(club.club_name), games.length === 1 ? "Game card" : `${games.length} game cards`, M);
  return doc.save();
}

