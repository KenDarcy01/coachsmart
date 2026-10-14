// deno-lint-ignore-file no-explicit-any
// Shared drawing kit for the CoachSmart PDF exports (session plans, game cards).
// Everything is laid out in "top" coordinates (distance from the top of the page)
// and converted to pdf-lib's bottom-up coordinates at draw time.
import type { PDFFont, PDFImage, PDFPage, RGB } from "npm:pdf-lib@1.17.1";
import {
  PDFDocument, PDFName, PDFString, rgb, StandardFonts,
  pushGraphicsState, popGraphicsState, moveTo, lineTo, appendBezierCurve, closePath, clip, endPath,
  setCharacterSpacing,
} from "npm:pdf-lib@1.17.1";
import fontkit from "npm:@pdf-lib/fontkit@1.1.1";
import QRCode from "npm:qrcode@1.5.4";

export { PDFDocument };
export type { PDFFont, PDFImage, PDFPage, RGB };

// ─── Colours ──────────────────────────────────────────────────────────────────

type C3 = [number, number, number];

function parseHex(hex: string | null | undefined): C3 | null {
  if (!hex) return null;
  const h = hex.trim().replace("#", "");
  if (!/^[0-9a-f]{6}$/i.test(h)) return null;
  return [parseInt(h.slice(0, 2), 16) / 255, parseInt(h.slice(2, 4), 16) / 255, parseInt(h.slice(4, 6), 16) / 255];
}
const toRgb = (c: C3) => rgb(c[0], c[1], c[2]);
const mix = (a: C3, b: C3, t: number): C3 => [a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t, a[2] + (b[2] - a[2]) * t];
function lum(c: C3) {
  const f = (v: number) => (v <= 0.03928 ? v / 12.92 : Math.pow((v + 0.055) / 1.055, 2.4));
  return 0.2126 * f(c[0]) + 0.7152 * f(c[1]) + 0.0722 * f(c[2]);
}
const nearWhite = (c: C3) => (c[0] + c[1] + c[2]) / 3 > 210 / 255;
const dist = (a: C3, b: C3) => Math.hypot(a[0] - b[0], a[1] - b[1], a[2] - b[2]);
const WHITE: C3 = [1, 1, 1];
const BLACK: C3 = [0, 0, 0];
const INK: C3 = [0x1b / 255, 0x1f / 255, 0x24 / 255];

export const fixed = {
  ink: toRgb(INK),
  body: rgb(0.2, 0.2, 0.2),
  muted: rgb(0x6b / 255, 0x72 / 255, 0x80 / 255),
  line: rgb(0xe6 / 255, 0xe8 / 255, 0xec / 255),
  tint: rgb(0xf5 / 255, 0xf6 / 255, 0xf8 / 255),
  head: rgb(0xfa / 255, 0xfb / 255, 0xfc / 255),
  white: rgb(1, 1, 1),
  green: rgb(0x87 / 255, 0xc2 / 255, 0x32 / 255),
  amber: rgb(0xe8 / 255, 0xa2 / 255, 0x0c / 255),
  teal: rgb(0x17 / 255, 0xa5 / 255, 0x89 / 255),
  slate: rgb(0x6b / 255, 0x72 / 255, 0x80 / 255),
};

export interface ClubData {
  club_name: string;
  crest: string | null;
  primary_colour: string;
  secondary_colour: string;
  third_colour: string | null;
}

/** Club colours resolved into a readable palette (handles white / pale club colours). */
export interface Theme {
  p: RGB; onP: RGB; pText: RGB; pTint: RGB;
  s: RGB; onS: RGB; sText: RGB; sTint: RGB;
  third: RGB | null;
  /** text colour to use on any palette colour */
  on: (c: RGB) => RGB;
}

export function makeTheme(club: ClubData): Theme {
  const cands = [club.primary_colour, club.secondary_colour, club.third_colour]
    .map(parseHex).filter((c): c is C3 => !!c && !nearWhite(c));
  const p: C3 = cands[0] ?? [0x2d / 255, 0x7a / 255, 0];
  // No usable second colour: use a lighter (or, for pale colours, darker) shade of the first.
  const s: C3 = cands.slice(1).find(c => dist(c, p) > 0.25) ?? (lum(p) > 0.3 ? mix(p, BLACK, 0.4) : mix(p, WHITE, 0.35));
  const t = cands.slice(1).find(c => dist(c, p) > 0.25 && dist(c, s) > 0.25) ?? null;
  const onC = (c: C3) => (lum(c) > 0.45 ? toRgb(INK) : toRgb(WHITE));
  const textC = (c: C3) => (lum(c) > 0.3 ? toRgb(mix(c, BLACK, 0.45)) : toRgb(c));
  return {
    p: toRgb(p), onP: onC(p), pText: textC(p), pTint: toRgb(mix(p, WHITE, 0.9)),
    s: toRgb(s), onS: onC(s), sText: textC(s), sTint: toRgb(mix(s, WHITE, 0.9)),
    third: t ? toRgb(t) : null,
    on: (c: RGB) => onC([c.red, c.green, c.blue]),
  };
}

// ─── Fonts ────────────────────────────────────────────────────────────────────

const FONT_CDN_FALLBACK: Record<string, Record<number, string>> = {
  "Montserrat": { 700: "https://cdn.jsdelivr.net/gh/google/fonts/ofl/montserrat/static/Montserrat-Bold.ttf" },
  "Noto Sans": {
    400: "https://cdn.jsdelivr.net/gh/google/fonts/ofl/notosans/NotoSans-Regular.ttf",
    700: "https://cdn.jsdelivr.net/gh/google/fonts/ofl/notosans/NotoSans-Bold.ttf",
  },
};

async function fetchFontBytes(family: string, weight: number): Promise<Uint8Array | null> {
  try {
    const cssUrl = `https://fonts.googleapis.com/css?family=${encodeURIComponent(family)}:${weight}&subset=latin`;
    const cssRes = await fetch(cssUrl, { headers: { "User-Agent": "curl/7.68.0" } });
    if (cssRes.ok) {
      const m = (await cssRes.text()).match(/src:\s*url\(['"]?([^'")\s]+)['"]?\)/);
      if (m) {
        const res = await fetch(m[1]);
        if (res.ok) return new Uint8Array(await res.arrayBuffer());
      }
    }
  } catch (e) {
    console.warn(`[font] CSS API error for ${family}:${weight}:`, e);
  }
  const url = FONT_CDN_FALLBACK[family]?.[weight];
  if (url) {
    try {
      const res = await fetch(url);
      if (res.ok) return new Uint8Array(await res.arrayBuffer());
    } catch (e) {
      console.warn(`[font] jsDelivr error for ${family}:${weight}:`, e);
    }
  }
  console.warn(`[font] All sources failed for ${family}:${weight}`);
  return null;
}

export interface Fonts { head: PDFFont; reg: PDFFont; bold: PDFFont; standard: boolean }

export async function loadFonts(doc: PDFDocument): Promise<Fonts> {
  doc.registerFontkit(fontkit);
  const [h, r, b] = await Promise.all([
    fetchFontBytes("Montserrat", 700), fetchFontBytes("Noto Sans", 400), fetchFontBytes("Noto Sans", 700),
  ]);
  let standard = false;
  const embed = async (bytes: Uint8Array | null, fb: StandardFonts) => {
    if (bytes) {
      // Ligatures off: with them on, pdf-lib drops pairs like "fi" ("fi nish").
      try { return await doc.embedFont(bytes, { features: { liga: false } } as any); } catch (e) { console.warn("embedFont failed:", e); }
    }
    standard = true;
    return doc.embedFont(fb);
  };
  const head = await embed(h, StandardFonts.HelveticaBold);
  const reg = await embed(r, StandardFonts.Helvetica);
  const bold = await embed(b, StandardFonts.HelveticaBold);
  return { head, reg, bold, standard };
}

/** Normalises text for drawing: tidy whitespace, and keep to Latin-1 if we fell back to standard fonts. */
export function clean(s: string | null | undefined, fonts?: Fonts): string {
  let t = String(s ?? "").replace(/\r/g, "").replace(/\t/g, " ").replace(/[​-‍﻿]/g, "");
  if (fonts?.standard) {
    t = t.replace(/[‘’]/g, "'").replace(/[“”]/g, '"').replace(/[—]/g, "-")
      .replace(/[^\n\x20-\x7E\xA0-\xFF·–]/g, "");
  }
  return t;
}

// ─── Images ───────────────────────────────────────────────────────────────────

export async function fetchImageBytes(url: string | null | undefined): Promise<Uint8Array | null> {
  if (!url) return null;
  try {
    const headers: Record<string, string> = {};
    const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
    const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
    if (supabaseUrl && url.startsWith(supabaseUrl)) {
      headers["Authorization"] = `Bearer ${serviceKey}`;
      headers["apikey"] = serviceKey;
    }
    const res = await fetch(url, { headers });
    if (!res.ok) { console.warn(`[image] fetch failed ${res.status} for ${url}`); return null; }
    return new Uint8Array(await res.arrayBuffer());
  } catch (e) {
    console.warn(`[image] fetch error for ${url}:`, e);
    return null;
  }
}

export async function embedImage(doc: PDFDocument, url: string | null | undefined): Promise<PDFImage | null> {
  const b = await fetchImageBytes(url);
  if (!b) return null;
  try {
    if (b[0] === 0xff && b[1] === 0xd8) return await doc.embedJpg(b);
    if (b[0] === 0x89 && b[1] === 0x50) return await doc.embedPng(b);
  } catch (e) { console.warn("[image] embed failed:", e); }
  return null;
}

// ─── Canvas: a page plus top-down drawing helpers ─────────────────────────────

export class Canvas {
  constructor(public doc: PDFDocument, public page: PDFPage, public W: number, public H: number, public f: Fonts) {}

  y(top: number) { return this.H - top; }

  rect(x: number, top: number, w: number, h: number, color: RGB, opacity = 1) {
    this.page.drawRectangle({ x, y: this.H - top - h, width: w, height: h, color, opacity });
  }

  private rrOps(x: number, top: number, w: number, h: number, r: number) {
    const k = 0.5523 * r, y0 = this.H - top - h, y1 = this.H - top;
    return [
      moveTo(x + r, y0), lineTo(x + w - r, y0),
      appendBezierCurve(x + w - r + k, y0, x + w, y0 + r - k, x + w, y0 + r),
      lineTo(x + w, y1 - r),
      appendBezierCurve(x + w, y1 - r + k, x + w - r + k, y1, x + w - r, y1),
      lineTo(x + r, y1),
      appendBezierCurve(x + r - k, y1, x, y1 - r + k, x, y1 - r),
      lineTo(x, y0 + r),
      appendBezierCurve(x, y0 + r - k, x + r - k, y0, x + r, y0),
      closePath(),
    ];
  }

  private rrPath(x: number, top: number, w: number, h: number, r: number) {
    r = Math.max(0, Math.min(r, w / 2, h / 2));
    return `M${x + r},${top} H${x + w - r} A${r},${r} 0 0 1 ${x + w},${top + r} V${top + h - r} A${r},${r} 0 0 1 ${x + w - r},${top + h} H${x + r} A${r},${r} 0 0 1 ${x},${top + h - r} V${top + r} A${r},${r} 0 0 1 ${x + r},${top} Z`;
  }

  /** Filled and/or outlined rounded rectangle. */
  rrect(x: number, top: number, w: number, h: number, r: number, fill: RGB | null, stroke?: RGB, strokeW = 1) {
    this.page.drawSvgPath(this.rrPath(0, 0, w, h, r), {
      x, y: this.H - top,
      color: fill ?? undefined,
      borderColor: stroke, borderWidth: stroke ? strokeW : 0,
    });
  }

  /** Runs fn with drawing clipped to a rounded rectangle. */
  clipped(x: number, top: number, w: number, h: number, r: number, fn: () => void) {
    r = Math.max(0, Math.min(r, w / 2, h / 2));
    this.page.pushOperators(pushGraphicsState(), ...this.rrOps(x, top, w, h, r), clip(), endPath());
    fn();
    this.page.pushOperators(popGraphicsState());
  }

  circle(cx: number, ctop: number, r: number, color: RGB) {
    this.page.drawCircle({ x: cx, y: this.H - ctop, size: r, color });
  }

  line(x1: number, t1: number, x2: number, t2: number, color: RGB, w = 1) {
    this.page.drawLine({ start: { x: x1, y: this.H - t1 }, end: { x: x2, y: this.H - t2 }, thickness: w, color });
  }

  /** Draws one line of text; `top` is the top of the line box, baseline sits at top + size*0.8. */
  text(s: string, x: number, top: number, size: number, font: PDFFont, color: RGB, spacing = 0) {
    if (!s) return;
    const y = this.H - top - size * 0.8;
    if (spacing) this.page.pushOperators(setCharacterSpacing(spacing));
    this.page.drawText(s, { x, y, size, font, color });
    if (spacing) this.page.pushOperators(setCharacterSpacing(0));
  }

  textRight(s: string, right: number, top: number, size: number, font: PDFFont, color: RGB, spacing = 0) {
    this.text(s, right - textW(s, font, size, spacing), top, size, font, color, spacing);
  }

  textCenter(s: string, cx: number, top: number, size: number, font: PDFFont, color: RGB, spacing = 0) {
    this.text(s, cx - textW(s, font, size, spacing) / 2, top, size, font, color, spacing);
  }

  image(img: PDFImage, x: number, top: number, w: number, h: number) {
    this.page.drawImage(img, { x, y: this.H - top - h, width: w, height: h });
  }

  /** Stroked 24x24 line icon scaled to `size`. */
  icon(name: keyof typeof ICONS, x: number, top: number, size: number, color: RGB, strokeW = 2) {
    const s = size / 24;
    for (const d of ICONS[name]) {
      this.page.drawSvgPath(d, { x, y: this.H - top, scale: s, borderColor: color, borderWidth: strokeW, borderLineCap: 1 as any });
    }
  }

  /** Filled triangle "play" mark. */
  play(x: number, top: number, size: number, color: RGB) {
    this.page.drawSvgPath(`M0,0 L${size * 0.85},${size / 2} L0,${size} Z`, { x, y: this.H - top, color });
  }

  /** Clickable link area. */
  link(url: string, x: number, top: number, w: number, h: number) {
    try {
      const ctx = this.doc.context;
      const annot = ctx.obj({
        Type: PDFName.of("Annot"), Subtype: PDFName.of("Link"),
        Rect: ctx.obj([x, this.H - top - h, x + w, this.H - top]),
        Border: ctx.obj([0, 0, 0]),
        A: ctx.obj({ Type: PDFName.of("Action"), S: PDFName.of("URI"), URI: PDFString.of(url.trim()) }),
      });
      this.page.node.addAnnot(ctx.register(annot));
    } catch { /* links are a nice-to-have */ }
  }

  /** QR code drawn as vector squares. */
  qr(data: string, x: number, top: number, size: number, color: RGB) {
    let m: any;
    try { m = QRCode.create(data, { errorCorrectionLevel: "M" }).modules; } catch { return; }
    const n = m.size, u = size / n;
    for (let r = 0; r < n; r++) {
      let c = 0;
      while (c < n) {
        if (!m.get(r, c)) { c++; continue; }
        let e = c;
        while (e + 1 < n && m.get(r, e + 1)) e++;
        // tiny overlap avoids hairline gaps between modules in some viewers
        this.rect(x + c * u, top + r * u, (e - c + 1) * u + 0.05, u + 0.05, color);
        c = e + 1;
      }
    }
  }
}

// SVG path data for 24x24 icons (stroked)
const ICONS = {
  clock: ["M12,3 A9,9 0 1 1 11.99,3 Z", "M12,7 V12 L15,14"],
  players: ["M9,4.5 A3.5,3.5 0 1 1 8.99,4.5 Z", "M2.5,20 C3.1,16.4 5.7,14.5 9,14.5 C12.3,14.5 14.9,16.4 15.5,20", "M17,6.4 A2.6,2.6 0 1 1 16.99,6.4 Z", "M16.5,14.6 C19.1,14.8 20.9,16.5 21.5,20"],
  whistle: ["M3,9 H15 L17,6 H21 V9 L17,11 A6,6 0 1 1 3,9 Z", "M9,14 A1.5,1.5 0 1 1 8.99,14 Z"],
  sun: ["M12,8 A4,4 0 1 1 11.99,8 Z", "M12,2 V4", "M12,20 V22", "M4.9,4.9 L6.3,6.3", "M17.7,17.7 L19.1,19.1", "M2,12 H4", "M20,12 H22", "M4.9,19.1 L6.3,17.7", "M17.7,6.3 L19.1,4.9"],
  check: ["M5,12.5 L9.5,17 L19,7.5"],
  up: ["M12,19 V5", "M6,11 L12,5 L18,11"],
  calendar: ["M4,6 H20 V20 H4 Z", "M4,10 H20", "M8,3 V7", "M16,3 V7"],
};
export type IconName = keyof typeof ICONS;

// ─── Text measuring and wrapping ──────────────────────────────────────────────

export function textW(s: string, font: PDFFont, size: number, spacing = 0) {
  return font.widthOfTextAtSize(s, size) + (spacing ? spacing * Math.max(0, s.length - 1) : 0);
}

export function wrap(text: string, font: PDFFont, size: number, maxW: number): string[] {
  const out: string[] = [];
  for (const para of String(text ?? "").split("\n").map(l => l.trim()).filter(Boolean)) {
    let cur = "";
    for (const word of para.split(/\s+/)) {
      const test = cur ? `${cur} ${word}` : word;
      if (textW(test, font, size) <= maxW) { cur = test; continue; }
      if (cur) out.push(cur);
      // hard-break words longer than the line (long URLs)
      let w = word;
      while (textW(w, font, size) > maxW && w.length > 1) {
        let i = w.length - 1;
        while (i > 1 && textW(w.slice(0, i), font, size) > maxW) i--;
        out.push(w.slice(0, i)); w = w.slice(i);
      }
      cur = w;
    }
    if (cur) out.push(cur);
  }
  return out;
}

/** Shrinks then truncates a single line to fit. Returns [text, size]. */
export function fitLine(s: string, font: PDFFont, size: number, minSize: number, maxW: number): [string, number] {
  let sz = size;
  while (sz > minSize && textW(s, font, sz) > maxW) sz -= 0.5;
  let t = s;
  while (t.length > 2 && textW(t, font, sz) > maxW) t = t.slice(0, -2).trimEnd() + "…";
  return [t, sz];
}

export interface Run { text: string; font: PDFFont; color: RGB }

/** Wraps mixed-font runs (e.g. a bold lead-in followed by normal text). */
export function wrapRuns(runs: Run[], size: number, maxW: number): Run[][] {
  const words: Run[] = [];
  for (const r of runs) for (const w of r.text.split(/\s+/).filter(Boolean)) words.push({ ...r, text: w });
  const lines: Run[][] = [];
  let cur: Run[] = [], curW = 0;
  for (const w of words) {
    const ww = textW(w.text, w.font, size), sp = cur.length ? textW(" ", w.font, size) : 0;
    if (cur.length && curW + sp + ww > maxW) { lines.push(cur); cur = []; curW = 0; }
    curW += (cur.length ? textW(" ", w.font, size) : 0) + ww;
    cur.push(w);
  }
  if (cur.length) lines.push(cur);
  return lines;
}

export function drawRuns(c: Canvas, line: Run[], x: number, top: number, size: number) {
  let cx = x;
  for (const r of line) {
    c.text(r.text, cx, top, size, r.font, r.color);
    cx += textW(r.text + " ", r.font, size);
  }
}

// ─── Small helpers ────────────────────────────────────────────────────────────

/** Splits stored multi-line text into clean points ("• a\n- b" → ["a","b"]). */
export function toPoints(text: string | null | undefined): string[] {
  return String(text ?? "").split(/\n/).map(l => l.replace(/^\s*(?:[•\-\*]|\d+[.)])\s*/, "").trim()).filter(Boolean);
}

export function safeName(s: string) {
  return s.replace(/[^a-z0-9]/gi, "_").replace(/_+/g, "_").slice(0, 60);
}

/** Draws the club crest inside a box, keeping its shape. */
export function drawCrest(c: Canvas, crest: PDFImage | null, x: number, top: number, boxW: number, boxH: number) {
  if (!crest) return 0;
  const sc = Math.min(boxW / crest.width, boxH / crest.height);
  const w = crest.width * sc, h = crest.height * sc;
  c.image(crest, x + (boxW - w) / 2, top + (boxH - h) / 2, w, h);
  return boxW;
}

/** Club stripes under a band: secondary, then third colour if the club has one. */
export function drawStripes(c: Canvas, top: number, th: Theme, main: number) {
  c.rect(0, top, c.W, main, th.s);
  if (th.third) { c.rect(0, top + main, c.W, 3, th.third); return main + 3; }
  return main;
}

/** Footer on every page: club, subtitle, CoachSmart wordmark, page x of y. */
export function drawFooters(doc: PDFDocument, pages: Canvas[], th: Theme, f: Fonts, clubName: string, subtitle: string, margin: number) {
  const n = pages.length;
  pages.forEach((c, i) => {
    const top = c.H - 26;
    c.line(margin, top, c.W - margin, top, fixed.line, 0.75);
    const ty = top + 7;
    const pg = `Page ${i + 1} of ${n}`;
    c.textRight(pg, c.W - margin, ty, 7.5, f.reg, fixed.muted);
    const pgW = textW(pg, f.reg, 7.5) + 10;
    const smartW = textW("SMART", f.head, 7.5, 0.4), coachW = textW("COACH", f.head, 7.5, 0.4);
    const brandX = c.W - margin - pgW - smartW - coachW;
    c.text("COACH", brandX, ty, 7.5, f.head, fixed.ink, 0.4);
    c.text("SMART", brandX + coachW, ty, 7.5, f.head, fixed.green, 0.4);
    const clubW = textW(clubName, f.bold, 7.5);
    c.text(clubName, margin, ty, 7.5, f.bold, th.pText);
    const room = brandX - 12 - (margin + clubW + 6);
    if (subtitle && room > 30) {
      const [sub, sz] = fitLine(subtitle, f.reg, 7.5, 7.5, room);
      c.text(sub, margin + clubW + 6, ty, sz, f.reg, fixed.muted);
    }
  });
}

/** Thin band at the top of continuation pages. Returns its height. */
export function drawContBand(c: Canvas, th: Theme, f: Fonts, left: string, right: string, margin: number) {
  const h = 28;
  c.rect(0, 0, c.W, h, th.p);
  const rW = right ? textW(right, f.reg, 8.5) : 0;
  const [l, sz] = fitLine(left, f.head, 9, 7.5, c.W - 2 * margin - rW - 12);
  c.text(l, margin, (h - sz) / 2 + 1, sz, f.head, th.onP);
  if (right) c.textRight(right, c.W - margin, (h - 8.5) / 2 + 1, 8.5, f.reg, th.onP);
  return h + drawStripes(c, h, th, 4);
}

/** Pill with centred text; returns its width. Draw with right edge at `right`. */
export function pillW(s: string, f: Fonts, size: number) { return textW(s, f.bold, size) + size * 2; }
export function drawPill(c: Canvas, s: string, x: number, top: number, size: number, bg: RGB, fg: RGB, f: Fonts) {
  const w = pillW(s, f, size), h = size * 2;
  c.rrect(x, top, w, h, h / 2, bg);
  c.textCenter(s, x + w / 2, top + (h - size) / 2 + 0.5, size, f.bold, fg);
  return w;
}

/** Spaced uppercase label. */
export function label(c: Canvas, s: string, x: number, top: number, size: number, color: RGB, f: Fonts) {
  c.text(s.toUpperCase(), x, top, size, f.bold, color, size * 0.14);
}

/** Section heading with a rule running to the right edge. Returns height used. */
export function sectionHead(c: Canvas, s: string, x: number, top: number, w: number, f: Fonts, size = 10) {
  const t = s.toUpperCase();
  c.text(t, x, top, size, f.head, fixed.ink, size * 0.06);
  const tw = textW(t, f.head, size, size * 0.06);
  c.line(x + tw + 8, top + size * 0.45, x + w, top + size * 0.45, fixed.line, 1);
  return size + 9;
}

/** "Watch the video" row: QR + label, whole row is a link. Returns height. */
export function videoRow(c: Canvas, url: string, x: number, top: number, w: number, f: Fonts, th: Theme, opts: { qr: number; title: number; sub: number; boxed: boolean; subText: string }) {
  const pad = opts.boxed ? 8 : 0;
  const h = opts.qr + pad * 2;
  if (opts.boxed) c.rrect(x, top, w, h, 9, fixed.white, fixed.line, 1);
  c.qr(url, x + pad, top + pad, opts.qr, fixed.ink);
  const tx = x + pad + opts.qr + 9;
  const block = opts.title + 4 + opts.sub;
  const tt = top + (h - block) / 2;
  c.play(tx, tt + 1, opts.title * 0.75, th.sText);
  c.text("Watch the video", tx + opts.title * 0.9, tt, opts.title, f.head, th.sText);
  c.text(opts.subText, tx, tt + opts.title + 4, opts.sub, f.reg, fixed.muted);
  c.link(url, x, top, w, h);
  return h;
}

/** Bulleted list with a small filled icon circle per item. Measure with draw=false. */
export function iconList(c: Canvas | null, items: string[], x: number, top: number, w: number, f: Fonts, size: number, lh: number, dot: RGB, iconName: IconName, gap = 3, iconColor: RGB = fixed.white) {
  const d = size * 1.35;
  let y = top;
  for (const it of items) {
    const lines = wrap(it, f.reg, size, w - d - 6);
    if (c) {
      c.circle(x + d / 2, y + (lh - d) / 2 + d / 2, d / 2, dot);
      c.icon(iconName, x + d * 0.18, y + (lh - d) / 2 + d * 0.18, d * 0.64, iconColor, 3);
      lines.forEach((l, i) => c.text(l, x + d + 6, y + i * lh + (lh - size) / 2, size, f.reg, fixed.body));
    }
    y += lines.length * lh + gap;
  }
  return y - top;
}

/** Tinted callout box with icon and rich text ("Make it harder: ..."). Returns height. */
export function callout(c: Canvas | null, lead: string, text: string, x: number, top: number, w: number, f: Fonts, th: Theme, size: number, lh: number, iconName: IconName | null = "up") {
  const pad = 8, isz = iconName ? size * 1.3 : -6;
  const lines = wrapRuns([{ text: lead, font: f.bold, color: th.sText }, { text, font: f.reg, color: fixed.body }], size, w - pad * 2 - isz - 6);
  const h = lines.length * lh + pad * 2 - (lh - size) + 2;
  if (c) {
    c.rrect(x, top, w, h, 8, th.sTint);
    if (iconName) c.icon(iconName, x + pad, top + pad - 1, isz, th.sText, 2.4);
    lines.forEach((l, i) => drawRuns(c, l, x + pad + isz + 6, top + pad + i * lh - (lh - size) / 2 + 1, size));
  }
  return h;
}

/** Parses a weather summary like "17°C · 1% rain · 22km/h wind — good conditions" into [main, rest]. */
export function splitWeather(summary: string | null | undefined): [string, string] | null {
  const s = String(summary ?? "").replace(/[\s—\-]+$/, "").trim();
  if (!s) return null;
  const core = s.split(/\s+—\s+|\s+-\s+/)[0];
  const parts = core.split(/\s*[·|,]\s*/).filter(Boolean);
  if (parts.length > 1 && parts[0].length <= 8) return [parts[0], parts.slice(1).join(" · ")];
  return ["", core];
}

/** Formats a timestamp in Irish time. */
export function irishParts(iso: string | null | undefined): { date: string; time: string; minutes: number } | null {
  if (!iso) return null;
  const d = new Date(iso);
  if (isNaN(d.getTime())) return null;
  const date = new Intl.DateTimeFormat("en-IE", { timeZone: "Europe/Dublin", weekday: "short", day: "numeric", month: "short" }).format(d).replace(",", "");
  const time = new Intl.DateTimeFormat("en-IE", { timeZone: "Europe/Dublin", hour: "2-digit", minute: "2-digit", hour12: false }).format(d);
  const [hh, mm] = time.split(":").map(Number);
  return { date, time, minutes: hh * 60 + mm };
}

export function clock(mins: number) {
  const m = ((mins % 1440) + 1440) % 1440;
  return `${Math.floor(m / 60)}:${String(m % 60).padStart(2, "0")}`;
}

export function toBase64(bytes: Uint8Array) {
  let b = "";
  for (let i = 0; i < bytes.length; i += 8192) b += String.fromCharCode(...bytes.subarray(i, i + 8192));
  return btoa(b);
}
