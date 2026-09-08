// deno-lint-ignore-file no-explicit-any
import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { PDFDocument, rgb, PDFFont, StandardFonts } from "npm:pdf-lib@1.17.1";
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

// ─── Font fetching (direct TTF from Google Fonts GitHub) ─────────────────────

const FONT_TTF: Record<string, string> = {
  "montserrat-bold":  "https://raw.githubusercontent.com/google/fonts/main/ofl/montserrat/static/Montserrat-Bold.ttf",
  "notosans-regular": "https://raw.githubusercontent.com/google/fonts/main/ofl/notosans/NotoSans-Regular.ttf",
  "notosans-bold":    "https://raw.githubusercontent.com/google/fonts/main/ofl/notosans/NotoSans-Bold.ttf",
};

async function fetchFontBytes(key: string): Promise<Uint8Array | null> {
  try {
    const url = FONT_TTF[key];
    if (!url) return null;
    const res = await fetch(url);
    if (!res.ok) { console.warn(`Font fetch ${key}: ${res.status}`); return null; }
    return new Uint8Array(await res.arrayBuffer());
  } catch (e) {
    console.warn(`fetchFontBytes ${key}:`, e);
    return null;
  }
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

// ─── Text helpers ─────────────────────────────────────────────────────────────

function wrapText(text: string, font: PDFFont, size: number, maxW: number): string[] {
  const paragraphs = text.split(/\n+/);
  const lines: string[] = [];
  for (const para of paragraphs) {
    if (!para.trim()) { lines.push(""); continue; }
    const words = para.trim().split(/\s+/);
    let cur = "";
    for (const w of words) {
      const test = cur ? `${cur} ${w}` : w;
      if (font.widthOfTextAtSize(test, size) <= maxW) { cur = test; }
      else { if (cur) lines.push(cur); cur = w; }
    }
    if (cur) lines.push(cur);
  }
  return lines;
}

function safeName(s: string) {
  return s.replace(/[^a-z0-9]/gi, "_").replace(/_+/g, "_").slice(0, 60);
}

// ─── PDF builder ──────────────────────────────────────────────────────────────

interface GameData {
  game_name: string;
  game_setup: string | null;
  game_how_to_play: string | null;
  game_variations: string | null;
  game_teaching_points: string | null;
  game_details_image: string | null;
  game_video: string | null;
}

interface ClubData {
  club_name: string;
  crest: string | null;
  primary_colour: string;
  secondary_colour: string;
  third_colour: string | null;
}

async function buildPdf(game: GameData, club: ClubData): Promise<Uint8Array> {
  // ── Colours ──
  const primaryRgb   = hexToRgb(club.primary_colour   || "#2d7a00");
  const secondaryRgb = hexToRgb(club.secondary_colour || "#ffd700");
  const thirdRgb     = club.third_colour ? hexToRgb(club.third_colour) : null;
  const footerLineRgb = thirdRgb ?? secondaryRgb;
  const white        = rgb(1, 1, 1);
  const grey         = rgb(0.70, 0.70, 0.70);

  // ── Fonts (fetch in parallel, fall back to Helvetica if unavailable) ──
  const [montserratBoldBytes, notoRegBytes, notoBoldBytes] = await Promise.all([
    fetchFontBytes("montserrat-bold"),
    fetchFontBytes("notosans-regular"),
    fetchFontBytes("notosans-bold"),
  ]);

  // ── Images (fetch in parallel) ──
  const [gameImgBytes, crestBytes] = await Promise.all([
    game.game_details_image ? fetchImageBytes(game.game_details_image) : Promise.resolve(null),
    club.crest              ? fetchImageBytes(club.crest)              : Promise.resolve(null),
  ]);

  // ── Create PDF ──
  const doc = await PDFDocument.create();
  doc.registerFontkit(fontkit);

  async function embedOrFallback(bytes: Uint8Array | null, fallback: StandardFonts): Promise<PDFFont> {
    if (bytes) {
      try { return await doc.embedFont(bytes); } catch (e) { console.warn("embedFont failed, using fallback:", e); }
    }
    return doc.embedFont(fallback);
  }

  const montserratBold = await embedOrFallback(montserratBoldBytes, StandardFonts.HelveticaBold);
  const notoReg        = await embedOrFallback(notoRegBytes,        StandardFonts.Helvetica);
  const notoBold       = await embedOrFallback(notoBoldBytes,       StandardFonts.HelveticaBold);

  // Page dimensions (A4)
  const PW = 595.28;
  const PH = 841.89;
  const ML = 24; // left margin
  const MR = 24; // right margin
  const CW = PW - ML - MR; // content width: 547.28

  // ── Embed images ──
  let gameImg: any = null;
  let crestImg: any = null;
  if (gameImgBytes) {
    try {
      gameImg = isJpeg(gameImgBytes)
        ? await doc.embedJpg(gameImgBytes)
        : isPng(gameImgBytes) ? await doc.embedPng(gameImgBytes) : null;
    } catch { /* skip */ }
  }
  if (crestBytes) {
    try {
      crestImg = isJpeg(crestBytes)
        ? await doc.embedJpg(crestBytes)
        : isPng(crestBytes) ? await doc.embedPng(crestBytes) : null;
    } catch { /* skip */ }
  }

  // ── Layout constants ──
  const CREST_SIZE  = 52;   // crest image size
  const HEADER_PAD  = 12;   // header top/bottom padding
  const CLUB_SIZE   = 18;   // Montserrat Bold — club name
  const GAME_SIZE   = 13;   // NotoSans Bold — game name
  const RULE_H      = 1;

  // Header: horizontal layout (crest left, text right)
  // Text block = club name + gap + rule + gap + game name
  const TEXT_BLOCK_H = CLUB_SIZE + 6 + RULE_H + 6 + GAME_SIZE;
  const headerContentH = Math.max(CREST_SIZE, TEXT_BLOCK_H);
  const headerH = headerContentH + 2 * HEADER_PAD;

  // Accent stripe heights
  const WHITE_STRIPE = 2;
  const SEC_STRIPE   = 4;
  const THIRD_STRIPE = thirdRgb ? 3 : 0;
  const STRIPE_H     = WHITE_STRIPE + SEC_STRIPE + THIRD_STRIPE;

  // Footer
  const FOOTER_LINE_Y = 44;
  const FOOTER_TEXT_Y = 30;
  const FOOTER_ZONE   = 54;

  // Section label (left-bar accent style, matching Flutter)
  const SECTION_LABEL_ROW_H = 22;  // total row height incl. padding
  const SECTION_BAR_W  = 3;        // left accent bar width
  const SECTION_BAR_H  = 16;       // left accent bar height
  const SECTION_FONT_S = 10;       // label text size

  // Body text
  const BODY_FONT_S = 11;
  const LINE_H      = 16;   // line height
  const BODY_LEFT   = ML + 10;  // left edge for bullets
  const BODY_RIGHT  = PW - MR - 10;
  const BODY_W      = BODY_RIGHT - BODY_LEFT;

  // ── Draw header (horizontal: crest left, text right) ──
  function drawHeader(page: any) {
    const headerBottom = PH - headerH;

    // Red background
    page.drawRectangle({ x: 0, y: headerBottom, width: PW, height: headerH, color: primaryRgb });

    // Crest (left, vertically centered)
    if (crestImg) {
      const crestY = headerBottom + (headerH - CREST_SIZE) / 2;
      page.drawImage(crestImg, { x: ML, y: crestY, width: CREST_SIZE, height: CREST_SIZE });
    }

    // Text column (right of crest)
    const textLeft = ML + (crestImg ? CREST_SIZE + 12 : 0);
    const textRight = PW - MR;

    // Vertical centre of header → anchor the text block from there
    const blockMidY = headerBottom + headerH / 2;
    const clubNameY  = blockMidY + TEXT_BLOCK_H / 2 - CLUB_SIZE;
    const ruleY      = clubNameY - 6;
    const gameNameY  = ruleY - 6 - GAME_SIZE;

    page.drawText(club.club_name, {
      x: textLeft, y: clubNameY,
      size: CLUB_SIZE, font: montserratBold, color: white,
    });
    page.drawLine({
      start: { x: textLeft, y: ruleY }, end: { x: textRight, y: ruleY },
      thickness: RULE_H, color: white,
    });
    page.drawText(game.game_name, {
      x: textLeft, y: gameNameY,
      size: GAME_SIZE, font: notoBold, color: white,
    });

    // Accent stripes immediately below header
    let sy = headerBottom;
    page.drawRectangle({ x: 0, y: sy - WHITE_STRIPE, width: PW, height: WHITE_STRIPE, color: white });
    sy -= WHITE_STRIPE;
    page.drawRectangle({ x: 0, y: sy - SEC_STRIPE, width: PW, height: SEC_STRIPE, color: secondaryRgb });
    sy -= SEC_STRIPE;
    if (thirdRgb) {
      page.drawRectangle({ x: 0, y: sy - THIRD_STRIPE, width: PW, height: THIRD_STRIPE, color: thirdRgb });
    }
  }

  // ── Draw footer ──
  function drawFooter(page: any) {
    page.drawLine({
      start: { x: ML, y: FOOTER_LINE_Y }, end: { x: PW - MR, y: FOOTER_LINE_Y },
      thickness: 1.5, color: footerLineRgb,
    });
    page.drawText(club.club_name, {
      x: ML, y: FOOTER_TEXT_Y, size: 10, font: notoBold, color: primaryRgb,
    });
    const csW = notoReg.widthOfTextAtSize("CoachSmart", 10);
    page.drawText("CoachSmart", {
      x: PW - MR - csW, y: FOOTER_TEXT_Y, size: 10, font: notoReg, color: grey,
    });
  }

  // ── Page manager ──
  let currentPage: any = null;
  let curY = 0;

  function newPage(isFirst: boolean) {
    const page = doc.addPage([PW, PH]);
    drawFooter(page);
    if (isFirst) {
      drawHeader(page);
      curY = headerH + STRIPE_H + 8;
    } else {
      curY = 24;
    }
    currentPage = page;
  }

  function ensureSpace(needed: number) {
    if (PH - curY - FOOTER_ZONE < needed) newPage(false);
  }

  // ── Section label: left accent bar + bold coloured text (matches Flutter) ──
  function drawSectionLabel(label: string) {
    ensureSpace(SECTION_LABEL_ROW_H + LINE_H + 4);
    const rowCenterY = PH - curY - SECTION_LABEL_ROW_H / 2;

    // Left accent bar
    currentPage.drawRectangle({
      x: ML, y: rowCenterY - SECTION_BAR_H / 2,
      width: SECTION_BAR_W, height: SECTION_BAR_H,
      color: secondaryRgb,
    });
    // Label text (vertically centred in row)
    currentPage.drawText(label, {
      x: ML + SECTION_BAR_W + 6,
      y: rowCenterY - SECTION_FONT_S / 2,
      size: SECTION_FONT_S, font: notoBold, color: secondaryRgb,
    });
    curY += SECTION_LABEL_ROW_H + 4;
  }

  // ── Body text: per-paragraph bullets, proper continuation indent ──
  function drawBodyText(text: string) {
    if (!text.trim()) return;
    const darkText = rgb(0.08, 0.08, 0.08);
    const bulletStr = "• ";  // "• "
    const bulletW = notoReg.widthOfTextAtSize(bulletStr, BODY_FONT_S);
    const paraMaxW = BODY_W - bulletW;
    const contX = BODY_LEFT + bulletW;  // continuation line x

    // Each DB line = one bullet paragraph; strip any existing bullet/dash prefix
    const paragraphs = text.split(/\n/)
      .map(l => l.replace(/^[•\-\*]\s*/, "").trim())
      .filter(Boolean);

    for (const para of paragraphs) {
      // Word-wrap this paragraph
      const words = para.split(/\s+/);
      const wrappedLines: string[] = [];
      let cur = "";
      for (const w of words) {
        const test = cur ? `${cur} ${w}` : w;
        if (notoReg.widthOfTextAtSize(test, BODY_FONT_S) <= paraMaxW) {
          cur = test;
        } else {
          if (cur) wrappedLines.push(cur);
          cur = w;
        }
      }
      if (cur) wrappedLines.push(cur);

      for (let i = 0; i < wrappedLines.length; i++) {
        ensureSpace(LINE_H);
        const lineY = PH - curY - BODY_FONT_S;
        if (i === 0) {
          currentPage.drawText(bulletStr, { x: BODY_LEFT, y: lineY, size: BODY_FONT_S, font: notoReg, color: darkText });
        }
        currentPage.drawText(wrappedLines[i], { x: contX, y: lineY, size: BODY_FONT_S, font: notoReg, color: darkText });
        curY += LINE_H;
      }
      curY += 3;  // gap between bullet points
    }
    curY += 6;  // gap after section
  }

  // ── Game image ──
  async function drawGameImage() {
    if (!gameImg) return;
    const ratio = gameImg.width / gameImg.height;
    const imgW = BODY_W;
    const imgH = Math.min(imgW / ratio, 220);
    ensureSpace(imgH + 12);
    currentPage.drawImage(gameImg, {
      x: BODY_LEFT, y: PH - curY - imgH,
      width: imgW, height: imgH,
    });
    curY += imgH + 12;
  }

  // ── Build content (section order matches Flutter exportGameCardPdf) ──
  newPage(true);

  if (game.game_setup?.trim()) {
    drawSectionLabel("HOW TO SET UP");
    drawBodyText(game.game_setup);
  }

  await drawGameImage();

  if (game.game_how_to_play?.trim()) {
    drawSectionLabel("HOW TO PLAY");
    drawBodyText(game.game_how_to_play);
  }

  if (game.game_variations?.trim()) {
    drawSectionLabel("VARIATIONS");
    drawBodyText(game.game_variations);
  }

  if (game.game_teaching_points?.trim()) {
    drawSectionLabel("TEACHING POINTS");
    drawBodyText(game.game_teaching_points);
  }

  if (game.game_video?.trim()) {
    drawSectionLabel("VIDEO EXPLAINER");
    ensureSpace(LINE_H);
    currentPage.drawText(game.game_video, {
      x: BODY_LEFT,
      y: PH - curY - BODY_FONT_S,
      size: BODY_FONT_S, font: notoReg, color: rgb(0.0, 0.3, 0.8),
    });
    curY += LINE_H + 6;
  }

  const pdfBytes = await doc.save();
  return pdfBytes;
}

// ─── Edge function handler ────────────────────────────────────────────────────

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    // Validate JWT and get user ID
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

    const { game_id } = await req.json();
    if (!game_id) {
      return new Response(JSON.stringify({ error: "Missing game_id" }), {
        status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // Supabase service role client for data fetching
    const supabase = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    );

    // Fetch game data + user's club in parallel
    const [gameRes, userRes] = await Promise.all([
      supabase.from("games")
        .select("game_name,game_setup,game_how_to_play,game_variations,game_teaching_points,game_details_image,game_video")
        .eq("game_id", game_id)
        .maybeSingle(),
      supabase.from("users")
        .select("default_club")
        .eq("user_id", userId)
        .maybeSingle(),
    ]);

    if (gameRes.error || !gameRes.data) {
      return new Response(JSON.stringify({ error: "Game not found" }), {
        status: 404, headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    let clubData: ClubData = {
      club_name: "CoachSmart",
      crest: null,
      primary_colour: "#2d7a00",
      secondary_colour: "#ffd700",
      third_colour: null,
    };

    if (userRes.data?.default_club) {
      const clubRes = await supabase.from("clubs")
        .select("club_name,crest,primary_colour,secondary_colour,third_colour")
        .eq("club_id", userRes.data.default_club)
        .maybeSingle();
      if (clubRes.data) {
        clubData = {
          club_name:       clubRes.data.club_name       || "CoachSmart",
          crest:           clubRes.data.crest           || null,
          primary_colour:  clubRes.data.primary_colour  || "#2d7a00",
          secondary_colour:clubRes.data.secondary_colour|| "#ffd700",
          third_colour:    clubRes.data.third_colour    || null,
        };
      }
    }

    const pdfBytes = await buildPdf(gameRes.data as GameData, clubData);
    // Chunked base64 — avoids spread-arg stack overflow on large PDFs
    let b64 = '';
    for (let i = 0; i < pdfBytes.length; i += 8192) {
      b64 += String.fromCharCode(...pdfBytes.subarray(i, i + 8192));
    }
    const base64 = btoa(b64);
    const filename = `${safeName(gameRes.data.game_name || "game_card")}.pdf`;

    return new Response(JSON.stringify({ pdf: base64, filename }), {
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });

  } catch (err) {
    console.error("generate-game-card-pdf error:", err);
    return new Response(JSON.stringify({ error: String(err) }), {
      status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});
