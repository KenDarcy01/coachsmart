// deno-lint-ignore-file no-explicit-any
import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { PDFDocument, rgb, PDFFont, StandardFonts, PDFDict, PDFName, PDFString, PDFArray, PDFNumber } from "npm:pdf-lib@1.17.1";
import fontkit from "npm:@pdf-lib/fontkit@1.1.1";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

// ─── Colour helpers ───────────────────────────────────────────────────────────

function hexToRgb(hex: string) {
  const h = hex.replace("#", "").padEnd(6, "0");
  return rgb(
    parseInt(h.slice(0, 2), 16) / 255,
    parseInt(h.slice(2, 4), 16) / 255,
    parseInt(h.slice(4, 6), 16) / 255,
  );
}

function isNearWhite(hex: string | null | undefined): boolean {
  if (!hex) return false;
  const h = hex.replace("#", "").padEnd(6, "0");
  const r = parseInt(h.slice(0, 2), 16);
  const g = parseInt(h.slice(2, 4), 16);
  const b = parseInt(h.slice(4, 6), 16);
  return (r + g + b) / 3 > 210;
}

// ─── Font fetching ────────────────────────────────────────────────────────────

const FONT_CDN_FALLBACK: Record<string, Record<number, string>> = {
  "Montserrat": {
    700: "https://cdn.jsdelivr.net/gh/google/fonts/ofl/montserrat/static/Montserrat-Bold.ttf",
  },
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
      const css = await cssRes.text();
      const m1 = css.match(/src:\s*url\(['"]?([^'")\s]+)['"]?\)/);
      if (m1) {
        const res = await fetch(m1[1]);
        if (res.ok) return new Uint8Array(await res.arrayBuffer());
      }
    }
  } catch (e) {
    console.warn(`[font] CSS API error for ${family}:${weight}:`, e);
  }

  const fallbackUrl = FONT_CDN_FALLBACK[family]?.[weight];
  if (fallbackUrl) {
    try {
      const res = await fetch(fallbackUrl);
      if (res.ok) return new Uint8Array(await res.arrayBuffer());
    } catch (e) {
      console.warn(`[font] jsDelivr error for ${family}:${weight}:`, e);
    }
  }

  console.warn(`[font] All sources failed for ${family}:${weight}`);
  return null;
}

// ─── Image fetching ───────────────────────────────────────────────────────────

async function fetchImageBytes(url: string): Promise<Uint8Array | null> {
  if (!url) return null;
  try {
    const res = await fetch(url);
    if (!res.ok) return null;
    return new Uint8Array(await res.arrayBuffer());
  } catch {
    return null;
  }
}

function isJpeg(b: Uint8Array) { return b[0] === 0xff && b[1] === 0xd8; }
function isPng(b: Uint8Array)  { return b[0] === 0x89 && b[1] === 0x50; }

// ─── Weather text stripper ────────────────────────────────────────────────────

function stripWeatherFromObjective(text: string): string {
  if (!text) return text;
  return text
    .split('\n')
    .map(line => {
      if (/^Weather:/i.test(line.trim())) return '';
      const idx = line.search(/\.\s+Weather:/i);
      if (idx !== -1) return line.slice(0, idx + 1).trim();
      return line;
    })
    .filter(l => l.trim() !== '')
    .join('\n')
    .trim();
}

// ─── Text helpers ─────────────────────────────────────────────────────────────

function safeName(s: string) {
  return s.replace(/[^a-z0-9]/gi, "_").replace(/_+/g, "_").slice(0, 60);
}

function wrapText(text: string, font: PDFFont, fontSize: number, maxWidth: number): string[] {
  const lines: string[] = [];
  for (const para of text.split(/\n/).map(l => l.trim()).filter(Boolean)) {
    const words = para.split(/\s+/);
    let cur = "";
    for (const w of words) {
      const test = cur ? `${cur} ${w}` : w;
      if (font.widthOfTextAtSize(test, fontSize) <= maxWidth) {
        cur = test;
      } else {
        if (cur) lines.push(cur);
        cur = w;
      }
    }
    if (cur) lines.push(cur);
  }
  return lines;
}

function formatDate(dateStr: string | null | undefined): string {
  if (!dateStr) return "";
  try {
    const d = new Date(dateStr);
    return d.toLocaleDateString("en-IE", { weekday: "short", day: "numeric", month: "short", year: "numeric" });
  } catch {
    return dateStr || "";
  }
}

// ─── Data types ───────────────────────────────────────────────────────────────

interface DrillData {
  game_name: string;
  duration_mins: number;
  description: string;
  coaching_points: string[];
  variation?: string;
  game_image?: string;
  game_video?: string | null;
}

interface WarmupCooldown {
  duration_mins: number;
  description: string;
  coaching_points?: string[];
  game_name?: string;
  game_image?: string | null;
  game_video?: string | null;
}

interface OptionalBlock {
  duration_mins: number;
  description: string;
}

interface PlanJson {
  session_title: string;
  session_objective: string;
  total_duration_mins: number;
  player_count: number;
  coach_count: number;
  weather?: { summary: string };
  pre_session?: OptionalBlock | null;
  warm_up: WarmupCooldown;
  station_setup?: string | null;
  drills: DrillData[];
  cool_down: WarmupCooldown;
  post_session?: OptionalBlock | null;
}

interface ClubData {
  club_name: string;
  crest: string | null;
  primary_colour: string;
  secondary_colour: string;
  third_colour: string | null;
}

interface EventData {
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

function applyCamogie(s: string | null, teamFemale: boolean): string | null {
  if (!s || !teamFemale) return s;
  return s.replace(/\bHurling\b/g, 'Camogie').replace(/\bhurling\b/g, 'camogie');
}

function buildPdfTitle(event: EventData): string {
  const parts: string[] = [];
  if (event.team_name) parts.push(event.team_name);
  const typeCode = [
    applyCamogie(event.event_code, event.team_female),
    applyCamogie(event.event_type, event.team_female),
  ].filter(Boolean).join(" ");
  if (typeCode) parts.push(typeCode);
  return parts.join(" - ") || "Session Plan";
}

// ─── PDF builder ──────────────────────────────────────────────────────────────

async function buildSessionPlanPdf(
  plan: PlanJson,
  event: EventData,
  format: "a4" | "mobile" = "a4",
): Promise<Uint8Array> {

  const club = event.club;

  // ── Colours ──
  const primaryRgb   = hexToRgb(club.primary_colour   || "#2d7a00");
  const secondaryRgb = hexToRgb(club.secondary_colour || "#ffd700");
  const thirdRgb     = club.third_colour ? hexToRgb(club.third_colour) : null;
  const white        = rgb(1, 1, 1);
  const darkText     = rgb(0.18, 0.18, 0.18);
  const mutedText    = rgb(0.45, 0.45, 0.45);
  const grey         = rgb(0.70, 0.70, 0.70);
  const lightBg      = rgb(0.97, 0.97, 0.97);
  const amberText    = rgb(0.80, 0.50, 0.00);

  type ColourEntry = { hex: string | null; col: ReturnType<typeof hexToRgb> };
  const colourRank: ColourEntry[] = [
    { hex: club.secondary_colour, col: secondaryRgb },
    { hex: club.third_colour,     col: thirdRgb as ReturnType<typeof hexToRgb> },
    { hex: club.primary_colour,   col: primaryRgb },
  ].filter((c): c is ColourEntry => c.col !== null && !isNearWhite(c.hex));

  const accentRgb = colourRank[0]?.col ?? primaryRgb;

  // ── Fonts ──
  const [montserratBoldBytes, notoRegBytes, notoBoldBytes] = await Promise.all([
    fetchFontBytes("Montserrat", 700),
    fetchFontBytes("Noto Sans", 400),
    fetchFontBytes("Noto Sans", 700),
  ]);

  const doc = await PDFDocument.create();
  doc.registerFontkit(fontkit);

  async function embedOrFallback(bytes: Uint8Array | null, fallback: StandardFonts): Promise<PDFFont> {
    if (bytes) {
      try { return await doc.embedFont(bytes); } catch (e) { console.warn("embedFont failed:", e); }
    }
    return doc.embedFont(fallback);
  }

  const montserratBold = await embedOrFallback(montserratBoldBytes, StandardFonts.HelveticaBold);
  const notoReg        = await embedOrFallback(notoRegBytes,        StandardFonts.Helvetica);
  const notoBold       = await embedOrFallback(notoBoldBytes,       StandardFonts.HelveticaBold);

  // ── Page dimensions ──
  const isMobile   = format === "mobile";
  const PW         = isMobile ? 390 : 595;
  const PH         = isMobile ? 780 : 842;
  const ML         = isMobile ?  14 :  28;
  const MR         = isMobile ?  14 :  28;
  const MT         = isMobile ?  16 :  20;
  const MB         = isMobile ?  16 :  20;
  const CW         = PW - ML - MR;

  // ── Club crest ──
  const crestBytes = club.crest ? await fetchImageBytes(club.crest) : null;
  let crestImg: any = null;
  if (crestBytes) {
    try {
      crestImg = isJpeg(crestBytes)
        ? await doc.embedJpg(crestBytes)
        : isPng(crestBytes) ? await doc.embedPng(crestBytes) : null;
    } catch { /* skip */ }
  }

  // ── Layout constants ──
  const CREST_SIZE      = isMobile ?  44 :  64;
  const HEADER_PAD      = isMobile ?  10 :  12;
  const CLUB_FONT_S     = isMobile ?  16 :  20;
  const TITLE_FONT_S    = isMobile ?  12 :  14;
  const RULE_H          = 1;
  const TEXT_BLOCK_H    = CLUB_FONT_S + 8 + RULE_H + 8 + TITLE_FONT_S;
  const headerContentH  = Math.max(CREST_SIZE, TEXT_BLOCK_H);
  const HEADER_H        = headerContentH + 2 * HEADER_PAD;

  const WHITE_STRIPE  = 2;
  const SEC_STRIPE    = 4;
  const THIRD_STRIPE  = thirdRgb ? 3 : 0;
  const STRIPE_H      = WHITE_STRIPE + SEC_STRIPE + THIRD_STRIPE;

  const META_ROW_H    = plan.weather?.summary ? (isMobile ? 58 : 62) : (isMobile ? 34 : 38);
  const FOOTER_RULE_Y = MB + 14;
  const FOOTER_TEXT_Y = MB;
  const FOOTER_ZONE   = MB + (isMobile ? 24 : 30);

  const SECTION_ROW_H   = isMobile ? 26 : 28;
  const SECTION_DOT_R   = 4;
  const SECTION_FONT_S  = isMobile ? 12 : 11;
  const DRILL_NAME_S    = 12;
  const BODY_FONT_S     = isMobile ? 12 : 11;
  const SMALL_FONT_S    = 10;
  const LINE_H          = isMobile ? 18 : 17;
  const BODY_LEFT       = ML + (isMobile ? 10 : 12);
  const BODY_W          = CW - (isMobile ? 10 : 12);
  const IDEAL_IMG_H     = isMobile ? 210 : 270;
  const MIN_IMG_H       = isMobile ? 100 : 160;

  // ── Mutable page state ──
  let currentPage: any = null;
  let curY = 0; // distance from top of page

  // ── Draw helpers ──

  function drawFooter(page: any) {
    page.drawLine({
      start: { x: ML, y: FOOTER_RULE_Y }, end: { x: PW - MR, y: FOOTER_RULE_Y },
      thickness: 1, color: accentRgb,
    });
    page.drawText(club.club_name, {
      x: ML, y: FOOTER_TEXT_Y + 2,
      size: SMALL_FONT_S, font: notoBold, color: primaryRgb,
    });
    const csLabel = "COACHSMART";
    const csW = notoReg.widthOfTextAtSize(csLabel, SMALL_FONT_S);
    page.drawText(csLabel, {
      x: PW - MR - csW, y: FOOTER_TEXT_Y + 2,
      size: SMALL_FONT_S, font: notoReg, color: grey,
    });
  }

  function drawPageHeader(page: any, sessionTitle: string) {
    const headerBottom = PH - HEADER_H;
    page.drawRectangle({ x: 0, y: headerBottom, width: PW, height: HEADER_H, color: primaryRgb });

    if (crestImg) {
      const crestY = headerBottom + (HEADER_H - CREST_SIZE) / 2;
      page.drawImage(crestImg, { x: ML, y: crestY, width: CREST_SIZE, height: CREST_SIZE });
    }

    const textLeft  = ML + (crestImg ? CREST_SIZE + 12 : 0);
    const textRight = PW - MR;
    const blockMidY = headerBottom + HEADER_H / 2;
    const clubNameY = blockMidY + TEXT_BLOCK_H / 2 - CLUB_FONT_S;
    const ruleY     = clubNameY - 8;
    const titleY    = ruleY - 8 - TITLE_FONT_S;

    page.drawText(club.club_name, {
      x: textLeft, y: clubNameY,
      size: CLUB_FONT_S, font: montserratBold, color: white,
    });
    page.drawLine({
      start: { x: textLeft, y: ruleY }, end: { x: textRight, y: ruleY },
      thickness: RULE_H, color: white,
    });

    // Truncate session title if too wide
    let displayTitle = sessionTitle || "Session Plan";
    const maxTitleW = textRight - textLeft;
    while (
      displayTitle.length > 4 &&
      montserratBold.widthOfTextAtSize(displayTitle, TITLE_FONT_S) > maxTitleW
    ) {
      displayTitle = displayTitle.slice(0, -4) + "...";
    }
    page.drawText(displayTitle, {
      x: textLeft, y: titleY,
      size: TITLE_FONT_S, font: montserratBold, color: white,
    });

    // Colour stripes below header
    let sy = headerBottom;
    page.drawRectangle({ x: 0, y: sy - WHITE_STRIPE, width: PW, height: WHITE_STRIPE, color: white });
    sy -= WHITE_STRIPE;
    page.drawRectangle({ x: 0, y: sy - SEC_STRIPE, width: PW, height: SEC_STRIPE, color: secondaryRgb });
    sy -= SEC_STRIPE;
    if (thirdRgb) {
      page.drawRectangle({ x: 0, y: sy - THIRD_STRIPE, width: PW, height: THIRD_STRIPE, color: thirdRgb });
    }
  }

  function drawContinuationHeader(page: any) {
    // Thin coloured rule at top of continuation pages
    page.drawRectangle({ x: 0, y: PH - 6, width: PW, height: 6, color: primaryRgb });
    page.drawRectangle({ x: 0, y: PH - 6 - SEC_STRIPE, width: PW, height: SEC_STRIPE, color: secondaryRgb });
    if (thirdRgb) {
      page.drawRectangle({
        x: 0, y: PH - 6 - SEC_STRIPE - THIRD_STRIPE,
        width: PW, height: THIRD_STRIPE, color: thirdRgb,
      });
    }
  }

  function drawMetaRow(page: any, topY: number) {
    page.drawRectangle({ x: 0, y: PH - topY - META_ROW_H, width: PW, height: META_ROW_H, color: lightBg });

    const VPAD = 10;
    const parts: string[] = [];
    if (event.squad_name) parts.push(event.squad_name + (event.squad_grade ? ` · ${event.squad_grade}` : ""));
    if (plan.total_duration_mins) parts.push(`${plan.total_duration_mins} mins`);
    if (plan.player_count) parts.push(`${plan.player_count} players`);
    if (plan.coach_count)  parts.push(`${plan.coach_count} coaches`);

    const line1Y = PH - topY - VPAD - SMALL_FONT_S;
    page.drawText(parts.join("   |   "), { x: ML, y: line1Y, size: SMALL_FONT_S, font: notoReg, color: mutedText });

    // Session date/time right-aligned on line 1
    if (event.event_date) {
      try {
        const d = new Date(event.event_date);
        const days = ["Sun","Mon","Tue","Wed","Thu","Fri","Sat"];
        const months = ["Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"];
        const hh = String(d.getHours()).padStart(2,"0");
        const mm = String(d.getMinutes()).padStart(2,"0");
        const dateStr = `${days[d.getDay()]} ${d.getDate()} ${months[d.getMonth()]}, ${hh}:${mm}`;
        const dateW = notoReg.widthOfTextAtSize(dateStr, SMALL_FONT_S);
        page.drawText(dateStr, { x: PW - MR - dateW, y: line1Y, size: SMALL_FONT_S, font: notoReg, color: mutedText });
      } catch { /* skip */ }
    }

    if (plan.weather?.summary) {
      const line2Y = line1Y - VPAD - SMALL_FONT_S;
      page.drawText(plan.weather.summary, { x: ML, y: line2Y, size: SMALL_FONT_S, font: notoReg, color: mutedText });
    }
  }

  function newPage(isFirst: boolean) {
    const page = doc.addPage([PW, PH]);
    drawFooter(page);

    if (isFirst) {
      drawPageHeader(page, buildPdfTitle(event));
      const headerTotal = HEADER_H + STRIPE_H;
      drawMetaRow(page, headerTotal);
      curY = headerTotal + META_ROW_H + 8;
    } else {
      drawContinuationHeader(page);
      curY = 6 + SEC_STRIPE + THIRD_STRIPE + MT;
    }
    currentPage = page;
  }

  function ensureSpace(needed: number) {
    if (PH - curY - FOOTER_ZONE < needed) {
      newPage(false);
    }
  }

  // Draw wrapped body text (no bullets)
  function drawText(
    text: string,
    font: PDFFont,
    fontSize: number,
    color: ReturnType<typeof rgb>,
    indent = 0,
    extraBottom = 4,
  ) {
    if (!text.trim()) return;
    const maxW = BODY_W - indent;
    const lines = wrapText(text, font, fontSize, maxW);
    const lineH  = fontSize + 6;
    for (const line of lines) {
      ensureSpace(lineH);
      currentPage.drawText(line, {
        x: BODY_LEFT + indent, y: PH - curY - fontSize,
        size: fontSize, font, color,
      });
      curY += lineH;
    }
    curY += extraBottom;
  }

  // Draw bullet list from string array
  function drawBulletList(points: string[], accentColor: ReturnType<typeof rgb>) {
    if (!points?.length) return;
    const bullet    = "• ";
    const bulletW   = notoReg.widthOfTextAtSize(bullet, BODY_FONT_S);
    const contX     = BODY_LEFT + bulletW;
    const paraMaxW  = BODY_W - bulletW;
    const lineH     = BODY_FONT_S + 6;

    for (const point of points) {
      const lines = wrapText(point, notoReg, BODY_FONT_S, paraMaxW);
      for (let i = 0; i < lines.length; i++) {
        ensureSpace(lineH);
        const lineY = PH - curY - BODY_FONT_S;
        if (i === 0) {
          currentPage.drawText(bullet, { x: BODY_LEFT, y: lineY, size: BODY_FONT_S, font: notoReg, color: accentColor });
        }
        currentPage.drawText(lines[i], { x: contX, y: lineY, size: BODY_FONT_S, font: notoReg, color: darkText });
        curY += lineH;
      }
    }
    curY += 4;
  }

  // Draw a video URL as blue underlined text with a clickable PDF link annotation
  function drawVideoLink(url: string) {
    if (!url?.trim()) return;
    const label = "▶ Watch video";
    const fs    = BODY_FONT_S;
    const lh    = fs + 8;
    ensureSpace(lh + 4);

    const textY = PH - curY - fs;
    const textW = notoReg.widthOfTextAtSize(label, fs);
    const blue  = rgb(0.10, 0.40, 0.85);

    currentPage.drawText(label, { x: BODY_LEFT, y: textY, size: fs, font: notoReg, color: blue });
    currentPage.drawLine({
      start: { x: BODY_LEFT,         y: textY - 1 },
      end:   { x: BODY_LEFT + textW,  y: textY - 1 },
      thickness: 0.6, color: blue,
    });

    try {
      const ctx   = doc.context;
      const annot = ctx.obj({
        Type:    PDFName.of("Annot"),
        Subtype: PDFName.of("Link"),
        Rect:    ctx.obj([BODY_LEFT, textY - 2, BODY_LEFT + textW, textY + fs]),
        Border:  ctx.obj([0, 0, 0]),
        A: ctx.obj({
          Type: PDFName.of("Action"),
          S:    PDFName.of("URI"),
          URI:  PDFString.of(url.trim()),
        }),
      });
      currentPage.node.addAnnot(annot);
    } catch { /* skip if annotation api unavailable */ }

    curY += lh + 2;
  }

  // Section header: coloured dot + label + duration right-aligned
  function drawSectionHeader(label: string, durationMins: number | null, color: ReturnType<typeof rgb>) {
    ensureSpace(SECTION_ROW_H + LINE_H + 4);

    const rowCenterY = PH - curY - SECTION_ROW_H / 2;

    // Coloured dot
    currentPage.drawCircle({ x: ML + SECTION_DOT_R, y: rowCenterY, size: SECTION_DOT_R, color });

    // Label
    currentPage.drawText(label, {
      x: ML + SECTION_DOT_R * 2 + 6,
      y: rowCenterY - SECTION_FONT_S / 2,
      size: SECTION_FONT_S, font: notoBold, color: darkText,
    });

    // Duration right-aligned
    if (durationMins !== null && durationMins !== undefined) {
      const durStr = `${durationMins} min`;
      const durW   = notoBold.widthOfTextAtSize(durStr, SECTION_FONT_S);
      currentPage.drawText(durStr, {
        x: PW - MR - durW, y: rowCenterY - SECTION_FONT_S / 2,
        size: SECTION_FONT_S, font: notoBold, color,
      });
    }

    curY += SECTION_ROW_H;

    // Thin rule below section header
    currentPage.drawLine({
      start: { x: ML, y: PH - curY }, end: { x: PW - MR, y: PH - curY },
      thickness: 0.5, color: rgb(0.88, 0.88, 0.88),
    });
    curY += 6;
  }

  // Numbered circle + drill name
  function drawDrillName(index: number, name: string) {
    const circleR = 9;
    const circleX = ML + circleR;
    const rowY    = PH - curY - circleR * 2;
    const circleCY = rowY + circleR;

    ensureSpace(circleR * 2 + 6);

    currentPage.drawCircle({ x: circleX, y: circleCY, size: circleR, color: accentRgb });
    const numStr = String(index);
    const numW   = notoBold.widthOfTextAtSize(numStr, 9);
    currentPage.drawText(numStr, {
      x: circleX - numW / 2, y: circleCY - 5,
      size: 9, font: notoBold, color: white,
    });

    const nameX = ML + circleR * 2 + 8;
    const nameY = circleCY - DRILL_NAME_S / 2;
    currentPage.drawText(name || "Drill", {
      x: nameX, y: nameY,
      size: DRILL_NAME_S, font: notoBold, color: darkText,
    });

    curY += circleR * 2 + 8;
  }

  // ── Build PDF ─────────────────────────────────────────────────────────────────

  newPage(true);

  // FOCUS section (was session_title)
  if (plan.session_title?.trim()) {
    drawSectionHeader("FOCUS", null, accentRgb);
    drawText(plan.session_title, notoBold, BODY_FONT_S + 1, darkText, 0, 6);
  }

  // Objective (italic-style via regular font + muted colour, slightly indented)
  const cleanObjective = stripWeatherFromObjective(plan.session_objective ?? '');
  if (cleanObjective.trim()) {
    const objLines = wrapText(cleanObjective, notoReg, BODY_FONT_S + 1, CW - 16);
    for (const line of objLines) {
      ensureSpace(BODY_FONT_S + 8);
      currentPage.drawText(line, {
        x: ML + 8, y: PH - curY - (BODY_FONT_S + 1),
        size: BODY_FONT_S + 1, font: notoReg, color: mutedText,
      });
      curY += BODY_FONT_S + 8;
    }
    curY += 8;
  }

  curY += 4; // breathing room before sections

  // ── PRE-SESSION (optional) ────────────────────────────────────────────────────

  if (plan.pre_session?.description?.trim()) {
    drawSectionHeader("PRE-SESSION", plan.pre_session.duration_mins ?? null, accentRgb);
    drawText(plan.pre_session.description, notoReg, BODY_FONT_S, darkText, 0, 4);
    curY += 6;
  }

  // ── WARM UP ──────────────────────────────────────────────────────────────────

  if (plan.warm_up) {
    drawSectionHeader("WARM UP", plan.warm_up.duration_mins ?? null, accentRgb);

    // Warmup game image
    if (plan.warm_up.game_image) {
      const imgBytes = await fetchImageBytes(plan.warm_up.game_image);
      if (imgBytes) {
        let wuImg: any = null;
        try {
          wuImg = isJpeg(imgBytes)
            ? await doc.embedJpg(imgBytes)
            : isPng(imgBytes) ? await doc.embedPng(imgBytes) : null;
        } catch { /* skip */ }

        if (wuImg) {
          const ratio = wuImg.width / wuImg.height;
          let imgW = CW;
          let imgH = Math.min(imgW / ratio, IDEAL_IMG_H);
          imgW = imgH * ratio;
          if (imgW > CW) { imgW = CW; imgH = imgW / ratio; }

          curY += 8;
          const spaceAvail = PH - curY - FOOTER_ZONE - 20;
          if (spaceAvail < imgH) {
            if (spaceAvail >= MIN_IMG_H) {
              imgH = spaceAvail; imgW = imgH * ratio;
              if (imgW > CW) { imgW = CW; imgH = imgW / ratio; }
            } else {
              newPage(false);
              imgH = IDEAL_IMG_H; imgW = imgH * ratio;
              if (imgW > CW) { imgW = CW; imgH = imgW / ratio; }
            }
          }

          const imgX = ML + (CW - imgW) / 2;
          currentPage.drawImage(wuImg, { x: imgX, y: PH - curY - imgH, width: imgW, height: imgH });
          curY += imgH + 10;
        }
      }
    }

    if (plan.warm_up.description?.trim()) {
      drawText(plan.warm_up.description, notoReg, BODY_FONT_S, darkText, 0, 4);
    }
    if (plan.warm_up.coaching_points?.length) {
      drawBulletList(plan.warm_up.coaching_points, accentRgb);
    }
    if (plan.warm_up.game_video?.trim()) {
      drawVideoLink(plan.warm_up.game_video);
    }
    curY += 6;
  }

  // ── STATION SETUP (rotation mode only) ───────────────────────────────────────

  if (plan.station_setup?.trim()) {
    drawSectionHeader("STATION SETUP", null, accentRgb);
    drawText(plan.station_setup, notoReg, BODY_FONT_S, darkText, 0, 4);
    curY += 6;
  }

  // ── DRILLS ────────────────────────────────────────────────────────────────────

  for (let i = 0; i < (plan.drills ?? []).length; i++) {
    const drill = plan.drills[i];

    drawSectionHeader(`DRILL ${i + 1}`, drill.duration_mins ?? null, accentRgb);
    drawDrillName(i + 1, drill.game_name);

    // Game image
    if (drill.game_image) {
      const imgBytes = await fetchImageBytes(drill.game_image);
      if (imgBytes) {
        let drillImg: any = null;
        try {
          drillImg = isJpeg(imgBytes)
            ? await doc.embedJpg(imgBytes)
            : isPng(imgBytes) ? await doc.embedPng(imgBytes) : null;
        } catch { /* skip */ }

        if (drillImg) {
          const ratio = drillImg.width / drillImg.height;
          let imgW = CW;
          let imgH = Math.min(imgW / ratio, IDEAL_IMG_H);
          imgW = imgH * ratio;
          if (imgW > CW) { imgW = CW; imgH = imgW / ratio; }

          curY += 8;
          const spaceAvail = PH - curY - FOOTER_ZONE - 20;
          if (spaceAvail < imgH) {
            if (spaceAvail >= MIN_IMG_H) {
              imgH = spaceAvail; imgW = imgH * ratio;
              if (imgW > CW) { imgW = CW; imgH = imgW / ratio; }
            } else {
              newPage(false);
              imgH = IDEAL_IMG_H; imgW = imgH * ratio;
              if (imgW > CW) { imgW = CW; imgH = imgW / ratio; }
            }
          }

          const imgX = ML + (CW - imgW) / 2;
          currentPage.drawImage(drillImg, { x: imgX, y: PH - curY - imgH, width: imgW, height: imgH });
          curY += imgH + 10;
        }
      }
    }

    // Description
    if (drill.description?.trim()) {
      drawText(drill.description, notoReg, BODY_FONT_S, darkText, 0, 4);
    }

    // Coaching points
    if (drill.coaching_points?.length) {
      ensureSpace(SMALL_FONT_S + 4);
      currentPage.drawText("Coaching Points:", {
        x: BODY_LEFT, y: PH - curY - SMALL_FONT_S,
        size: SMALL_FONT_S, font: notoBold, color: darkText,
      });
      curY += SMALL_FONT_S + 4;
      drawBulletList(drill.coaching_points, accentRgb);
    }

    // Variation
    if (drill.variation?.trim()) {
      ensureSpace(SMALL_FONT_S + 4);
      currentPage.drawText("Variation:", {
        x: BODY_LEFT, y: PH - curY - SMALL_FONT_S,
        size: SMALL_FONT_S, font: notoBold, color: mutedText,
      });
      curY += SMALL_FONT_S + 4;
      drawText(drill.variation, notoReg, SMALL_FONT_S, mutedText, 8, 4);
    }

    // Video link
    if (drill.game_video?.trim()) {
      drawVideoLink(drill.game_video);
    }

    curY += 6;
  }

  // ── COOL DOWN ─────────────────────────────────────────────────────────────────

  if (plan.cool_down) {
    drawSectionHeader("COOL DOWN", plan.cool_down.duration_mins ?? null, accentRgb);

    if (plan.cool_down.description?.trim()) {
      drawText(plan.cool_down.description, notoReg, BODY_FONT_S, darkText, 0, 4);
    }
    if ((plan.cool_down as any).coaching_points?.length) {
      drawBulletList((plan.cool_down as any).coaching_points, accentRgb);
    }
    if (plan.cool_down.game_video?.trim()) {
      drawVideoLink(plan.cool_down.game_video);
    }
    curY += 6;
  }

  // ── POST-SESSION (optional) ───────────────────────────────────────────────────

  if (plan.post_session?.description?.trim()) {
    drawSectionHeader("POST-SESSION", plan.post_session.duration_mins ?? null, accentRgb);
    drawText(plan.post_session.description, notoReg, BODY_FONT_S, darkText, 0, 4);
  }

  return doc.save();
}

// ─── Edge function handler ────────────────────────────────────────────────────

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const authHeader = req.headers.get("Authorization");
    if (!authHeader?.startsWith("Bearer ")) {
      return new Response(JSON.stringify({ error: "Missing auth" }), {
        status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }
    const jwt = authHeader.slice(7);
    let userId: string;
    try {
      const payload = jwt.split(".")[1].replace(/-/g, "+").replace(/_/g, "/");
      const decoded = JSON.parse(atob(payload));
      userId = decoded.sub;
      if (!userId) throw new Error("No sub");
    } catch {
      return new Response(JSON.stringify({ error: "Invalid JWT" }), {
        status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const body = await req.json();
    const { plan_id, plan_json: bodyPlanJson, user_id, format = "a4" } = body;
    if (!plan_id && !bodyPlanJson) {
      return new Response(JSON.stringify({ error: "Missing plan_id or plan_json" }), {
        status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const supabase = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    );

    let planJsonResolved: any;
    let planEventId: number | null = null;
    let planCreatedBy: string | null = null;

    if (plan_id) {
      // ── Fetch session plan from DB ──
      const { data: planRow, error: planErr } = await supabase
        .from("session_plans")
        .select("plan_json, event_id, created_by")
        .eq("plan_id", plan_id)
        .maybeSingle();

      if (planErr || !planRow) {
        return new Response(JSON.stringify({ error: "Session plan not found" }), {
          status: 404, headers: { ...corsHeaders, "Content-Type": "application/json" },
        });
      }
      planJsonResolved = planRow.plan_json;
      planEventId      = planRow.event_id;
      planCreatedBy    = planRow.created_by;
    } else {
      // plan_json passed directly (e.g. from favourites screen — no event)
      planJsonResolved = bodyPlanJson;
    }

    // ── Fetch event data (only when a plan_id linked to an event is present) ──
    let eventRow: any = null;
    if (planEventId) {
      const { data: er, error: eventErr } = await supabase
        .from("events")
        .select(`
          event_title,
          event_date_time,
          teams!inner (
            team_name,
            team_female,
            clubs!inner (
              club_name,
              crest,
              primary_colour,
              secondary_colour,
              third_colour
            )
          ),
          squads (
            squad_name,
            grade
          ),
          event_types!events_event_type_id_fkey(event_type),
          event_codes!events_event_code_id_fkey(event_code)
        `)
        .eq("event_id", planEventId)
        .maybeSingle();
      if (eventErr) console.warn("Event fetch error (continuing with defaults):", eventErr);
      eventRow = er;
    }

    // Build EventData — gracefully handle missing relations
    const clubRaw   = eventRow?.teams?.clubs;
    const squadRaw  = eventRow?.squads;

    // Prefer user's default_club branding over the event's club chain
    const resolvedUserId = user_id || planCreatedBy;
    let userClubRaw: Record<string, any> | null = null;
    if (resolvedUserId) {
      const { data: userRow } = await supabase
        .from("users")
        .select("default_club")
        .eq("user_id", resolvedUserId)
        .maybeSingle();
      if (userRow?.default_club) {
        const { data: uc } = await supabase
          .from("clubs")
          .select("club_name, crest, primary_colour, secondary_colour, third_colour")
          .eq("club_id", userRow.default_club)
          .maybeSingle();
        userClubRaw = uc;
      }
    }

    const src = userClubRaw || clubRaw;
    const club: ClubData = {
      club_name:        src?.club_name        || "CoachSmart",
      crest:            src?.crest            || null,
      primary_colour:   src?.primary_colour   || "#2d7a00",
      secondary_colour: src?.secondary_colour || "#ffd700",
      third_colour:     src?.third_colour     || null,
    };

    const teamFemale = eventRow?.teams?.team_female === true;
    const eventData: EventData = {
      event_title: eventRow?.event_title                || null,
      event_date:  eventRow?.event_date_time            || null,
      squad_name:  squadRaw?.squad_name                 || null,
      squad_grade: squadRaw?.grade                      || null,
      team_name:   eventRow?.teams?.team_name           || null,
      event_type:  applyCamogie(eventRow?.event_types?.event_type || null, teamFemale),
      event_code:  applyCamogie(eventRow?.event_codes?.event_code || null, teamFemale),
      team_female: teamFemale,
      club,
    };

    const plan = planJsonResolved as PlanJson;
    if (!plan) {
      return new Response(JSON.stringify({ error: "plan_json is empty" }), {
        status: 422, headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // ── Build PDF ──
    const pdfBytes = await buildSessionPlanPdf(plan, eventData, format === "mobile" ? "mobile" : "a4");

    // Chunked base64 — avoids stack overflow on large PDFs
    let b64 = "";
    for (let i = 0; i < pdfBytes.length; i += 8192) {
      b64 += String.fromCharCode(...pdfBytes.subarray(i, i + 8192));
    }
    const base64 = btoa(b64);

    // Filename: use event date if available, else today
    const datePart = eventData.event_date
      ? eventData.event_date.slice(0, 10)
      : new Date().toISOString().slice(0, 10);
    const filename = `session-plan-${format === "mobile" ? "share" : "print"}-${datePart}.pdf`;

    return new Response(JSON.stringify({ pdf: base64, filename }), {
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });

  } catch (err) {
    console.error("generate-session-plan-pdf error:", err);
    return new Response(JSON.stringify({ error: String(err) }), {
      status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});
