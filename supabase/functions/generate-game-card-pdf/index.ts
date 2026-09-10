// deno-lint-ignore-file no-explicit-any
import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { PDFDocument, rgb, PDFFont, StandardFonts } from "npm:pdf-lib@1.17.1";
import fontkit from "npm:fontkit@2.0.4";

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

// Direct TTF URLs from the Google Fonts GitHub repo (served via jsDelivr CDN).
// Used as fallback when the Google Fonts CSS API approach fails.
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
  // 1. Try Google Fonts CSS API with legacy User-Agent (forces TTF response)
  try {
    const cssUrl = `https://fonts.googleapis.com/css?family=${encodeURIComponent(family)}:${weight}&subset=latin`;
    const cssRes = await fetch(cssUrl, { headers: { "User-Agent": "Mozilla/4.0 (compatible; MSIE 6.0; Windows NT 5.1)" } });
    if (cssRes.ok) {
      const css = await cssRes.text();
      console.log(`[font] CSS for ${family}:${weight} (first 300 chars): ${css.slice(0, 300)}`);
      // Capture any URL from src: url(...) — Google now returns query-string URLs
      // like fonts.gstatic.com/l/font?kit=... with no extension or format annotation
      let fontUrl: string | null = null;
      const m1 = css.match(/src:\s*url\(['"]?([^'")\s]+)['"]?\)/);
      if (m1) { fontUrl = m1[1]; }
      if (fontUrl) {
        console.log(`[font] Fetching font from CSS API URL: ${fontUrl}`);
        const res = await fetch(fontUrl);
        if (res.ok) return new Uint8Array(await res.arrayBuffer());
        console.warn(`[font] TTF download failed ${res.status}: ${fontUrl}`);
      } else {
        console.warn(`[font] No TTF URL in CSS for ${family}:${weight}`);
      }
    } else {
      console.warn(`[font] CSS API HTTP ${cssRes.status} for ${family}:${weight}`);
    }
  } catch (e) {
    console.warn(`[font] CSS API error for ${family}:${weight}:`, e);
  }

  // 2. Fall back to direct jsDelivr CDN URL
  const fallbackUrl = FONT_CDN_FALLBACK[family]?.[weight];
  if (fallbackUrl) {
    console.log(`[font] Trying jsDelivr fallback: ${fallbackUrl}`);
    try {
      const res = await fetch(fallbackUrl);
      if (res.ok) { console.log(`[font] jsDelivr OK for ${family}:${weight}`); return new Uint8Array(await res.arrayBuffer()); }
      console.warn(`[font] jsDelivr failed ${res.status} for ${family}:${weight}`);
    } catch (e) {
      console.warn(`[font] jsDelivr error for ${family}:${weight}:`, e);
    }
  }

  console.warn(`[font] All sources failed for ${family}:${weight} — will use fallback font`);
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

// ─── Text helpers ─────────────────────────────────────────────────────────────

function safeName(s: string) {
  return s.replace(/[^a-z0-9]/gi, "_").replace(/_+/g, "_").slice(0, 60);
}

// ─── Data types ───────────────────────────────────────────────────────────────

interface GameData {
  game_name: string;
  game_setup: string | null;
  game_how_to_play: string | null;
  game_variations: string | null;
  game_teaching_points: string | null;
  game_image: string | null;
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

// ─── PDF builder — accepts one or many games, one PDF per call ────────────────

async function buildPdf(games: GameData[], club: ClubData, isMobile = false): Promise<Uint8Array> {

  // ── Colours (shared across all games) ──
  const primaryRgb   = hexToRgb(club.primary_colour   || "#2d7a00");
  const secondaryRgb = hexToRgb(club.secondary_colour || "#ffd700");
  const thirdRgb     = club.third_colour ? hexToRgb(club.third_colour) : null;
  const footerLineRgb = thirdRgb ?? secondaryRgb;
  const white        = rgb(1, 1, 1);
  const grey         = rgb(0.70, 0.70, 0.70);

  type ColourEntry = { hex: string | null; col: ReturnType<typeof hexToRgb> };
  const colourRank: ColourEntry[] = [
    { hex: club.secondary_colour, col: secondaryRgb },
    { hex: club.third_colour,     col: thirdRgb as ReturnType<typeof hexToRgb> },
    { hex: club.primary_colour,   col: primaryRgb },
  ].filter((c): c is ColourEntry => c.col !== null && !isNearWhite(c.hex));

  const sectionBarRgb  = colourRank[0]?.col ?? primaryRgb;
  const sectionTextRgb = colourRank.find(c => c.col !== sectionBarRgb)?.col ?? secondaryRgb;

  // ── Fonts — fetched ONCE, shared across all games ──
  const [montserratBoldBytes, notoRegBytes, notoBoldBytes] = await Promise.all([
    fetchFontBytes("Montserrat", 700),
    fetchFontBytes("Noto Sans", 400),
    fetchFontBytes("Noto Sans", 700),
  ]);

  // ── Create PDF document ──
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

  // ── Page dimensions — same for every page in this document ──
  const PW = isMobile ? 430 : 595.28;
  const PH = isMobile ? 900 : 841.89;
  const ML = isMobile ? 20 : 28;
  const MR = isMobile ? 20 : 28;
  const CW = PW - ML - MR;

  // ── Club crest — fetched and embedded ONCE ──
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
  const CREST_SIZE  = 80;
  const HEADER_PAD  = 14;
  const CLUB_SIZE   = 24;
  const GAME_SIZE   = 20;
  const RULE_H      = 1;
  const TEXT_BLOCK_H = CLUB_SIZE + 8 + RULE_H + 8 + GAME_SIZE;
  const headerContentH = Math.max(CREST_SIZE, TEXT_BLOCK_H);
  const headerH = headerContentH + 2 * HEADER_PAD;
  const WHITE_STRIPE = 2;
  const SEC_STRIPE   = 4;
  const THIRD_STRIPE = thirdRgb ? 3 : 0;
  const STRIPE_H     = WHITE_STRIPE + SEC_STRIPE + THIRD_STRIPE;
  const FOOTER_LINE_Y = 44;
  const FOOTER_TEXT_Y = 30;
  const FOOTER_ZONE   = 54;
  const SECTION_LABEL_ROW_H = 28;
  const SECTION_BAR_W  = 6;
  const SECTION_BAR_H  = 19;
  const SECTION_FONT_S = 12;
  const BODY_FONT_S = 15;
  const LINE_H      = 24;
  const BODY_LEFT   = ML + 10;
  const BODY_RIGHT  = PW - MR - 10;
  const BODY_W      = BODY_RIGHT - BODY_LEFT;

  // ── Shared mutable page state ──
  let currentPage: any = null;
  let curY = 0;

  // ── Shared drawing helpers ──

  function drawFooter(page: any) {
    page.drawLine({
      start: { x: ML, y: FOOTER_LINE_Y }, end: { x: PW - MR, y: FOOTER_LINE_Y },
      thickness: 1.5, color: footerLineRgb,
    });
    page.drawText(club.club_name, { x: ML, y: FOOTER_TEXT_Y, size: 10, font: notoBold, color: primaryRgb });
    const csW = notoReg.widthOfTextAtSize("CoachSmart", 10);
    page.drawText("CoachSmart", { x: PW - MR - csW, y: FOOTER_TEXT_Y, size: 10, font: notoReg, color: grey });
  }

  function drawHeader(page: any, game: GameData) {
    const headerBottom = PH - headerH;
    page.drawRectangle({ x: 0, y: headerBottom, width: PW, height: headerH, color: primaryRgb });

    if (crestImg) {
      const crestY = headerBottom + (headerH - CREST_SIZE) / 2;
      page.drawImage(crestImg, { x: ML, y: crestY, width: CREST_SIZE, height: CREST_SIZE });
    }

    const textLeft = ML + (crestImg ? CREST_SIZE + 12 : 0);
    const textRight = PW - MR;
    const blockMidY = headerBottom + headerH / 2;
    const clubNameY  = blockMidY + TEXT_BLOCK_H / 2 - CLUB_SIZE;
    const ruleY      = clubNameY - 6;
    const gameNameY  = ruleY - 6 - GAME_SIZE;

    page.drawText(club.club_name, { x: textLeft, y: clubNameY, size: CLUB_SIZE, font: montserratBold, color: white });
    page.drawLine({ start: { x: textLeft, y: ruleY }, end: { x: textRight, y: ruleY }, thickness: RULE_H, color: white });
    page.drawText(game.game_name, { x: textLeft, y: gameNameY, size: GAME_SIZE, font: notoBold, color: white });

    let sy = headerBottom;
    page.drawRectangle({ x: 0, y: sy - WHITE_STRIPE, width: PW, height: WHITE_STRIPE, color: white });
    sy -= WHITE_STRIPE;
    page.drawRectangle({ x: 0, y: sy - SEC_STRIPE, width: PW, height: SEC_STRIPE, color: secondaryRgb });
    sy -= SEC_STRIPE;
    if (thirdRgb) {
      page.drawRectangle({ x: 0, y: sy - THIRD_STRIPE, width: PW, height: THIRD_STRIPE, color: thirdRgb });
    }
  }

  // newPage: isFirst=true draws the game header; continuation pages are plain
  function newPage(isFirst: boolean, game?: GameData) {
    const page = doc.addPage([PW, PH]);
    drawFooter(page);
    if (isFirst && game) {
      drawHeader(page, game);
      curY = headerH + STRIPE_H + 8;
    } else {
      curY = 24;
    }
    currentPage = page;
  }

  function ensureSpace(needed: number) {
    if (PH - curY - FOOTER_ZONE < needed) newPage(false);
  }

  function drawSectionLabel(label: string) {
    ensureSpace(SECTION_LABEL_ROW_H + LINE_H + 4);
    const rowCenterY = PH - curY - SECTION_LABEL_ROW_H / 2;
    currentPage.drawRectangle({
      x: ML, y: rowCenterY - SECTION_BAR_H / 2,
      width: SECTION_BAR_W, height: SECTION_BAR_H,
      color: sectionBarRgb,
    });
    currentPage.drawText(label, {
      x: ML + SECTION_BAR_W + 6,
      y: rowCenterY - SECTION_FONT_S / 2,
      size: SECTION_FONT_S, font: notoBold, color: sectionTextRgb,
    });
    curY += SECTION_LABEL_ROW_H + 10;
  }

  function drawBodyText(text: string) {
    if (!text.trim()) return;
    const darkText  = rgb(0.25, 0.25, 0.25);
    const bulletCol = sectionBarRgb;
    const bulletStr = "• ";
    const bulletW   = notoReg.widthOfTextAtSize(bulletStr, BODY_FONT_S);
    const paraMaxW  = BODY_W - bulletW;
    const contX     = BODY_LEFT + bulletW;

    const paragraphs = text.split(/\n/)
      .map(l => l.replace(/^[•\-\*]\s*/, "").trim())
      .filter(Boolean);

    for (const para of paragraphs) {
      const words = para.split(/\s+/);
      const wrappedLines: string[] = [];
      let cur = "";
      for (const w of words) {
        const test = cur ? `${cur} ${w}` : w;
        if (notoReg.widthOfTextAtSize(test, BODY_FONT_S) <= paraMaxW) { cur = test; }
        else { if (cur) wrappedLines.push(cur); cur = w; }
      }
      if (cur) wrappedLines.push(cur);

      for (let i = 0; i < wrappedLines.length; i++) {
        ensureSpace(LINE_H);
        const lineY = PH - curY - BODY_FONT_S;
        if (i === 0) {
          currentPage.drawText(bulletStr, { x: BODY_LEFT, y: lineY, size: BODY_FONT_S, font: notoReg, color: bulletCol });
        }
        currentPage.drawText(wrappedLines[i], { x: contX, y: lineY, size: BODY_FONT_S, font: notoReg, color: darkText });
        curY += LINE_H;
      }
      curY += 5;
    }
    curY += 12;
  }

  // ── Per-game render loop ──────────────────────────────────────────────────────

  for (const game of games) {
    // Fetch this game's image
    const gameImageUrl = game.game_image || game.game_details_image || null;
    const gameImgBytes = gameImageUrl ? await fetchImageBytes(gameImageUrl) : null;
    let gameImg: any = null;
    if (gameImgBytes) {
      try {
        gameImg = isJpeg(gameImgBytes)
          ? await doc.embedJpg(gameImgBytes)
          : isPng(gameImgBytes) ? await doc.embedPng(gameImgBytes) : null;
      } catch { /* skip */ }
    }

    // Start this game on a fresh page with its own header
    newPage(true, game);

    // Sections — same order as Flutter exportGameCardPdf
    if (game.game_setup?.trim()) {
      drawSectionLabel("HOW TO SET UP");
      drawBodyText(game.game_setup);
    }

    // Game image (between setup and how to play)
    if (gameImg) {
      const ratio = gameImg.width / gameImg.height;
      let imgW = CW;
      let imgH = imgW / ratio;
      if (imgH > 380) { imgH = 220; imgW = imgH * ratio; }
      const imgX = ML + (CW - imgW) / 2;
      curY += 10;
      ensureSpace(imgH + 28);
      currentPage.drawImage(gameImg, { x: imgX, y: PH - curY - imgH, width: imgW, height: imgH });
      curY += imgH + 24;
    }

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
    const { game_id, game_ids, platform } = body;
    const isMobile = platform === 'mobile';

    // Accept either a single game_id or an array of game_ids
    let gameIds: string[] = [];
    if (Array.isArray(game_ids) && game_ids.length > 0) {
      gameIds = game_ids;
    } else if (game_id) {
      gameIds = [game_id];
    } else {
      return new Response(JSON.stringify({ error: "Missing game_id or game_ids" }), {
        status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const supabase = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    );

    // Fetch all games + user's club in parallel
    const [gamesRes, userRes] = await Promise.all([
      supabase.from("games")
        .select("game_name,game_setup,game_how_to_play,game_variations,game_teaching_points,game_image,game_details_image,game_video")
        .in("game_id", gameIds),
      supabase.from("users")
        .select("default_club")
        .eq("user_id", userId)
        .maybeSingle(),
    ]);

    if (gamesRes.error || !gamesRes.data?.length) {
      return new Response(JSON.stringify({ error: "Games not found" }), {
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
          club_name:        clubRes.data.club_name        || "CoachSmart",
          crest:            clubRes.data.crest            || null,
          primary_colour:   clubRes.data.primary_colour   || "#2d7a00",
          secondary_colour: clubRes.data.secondary_colour || "#ffd700",
          third_colour:     clubRes.data.third_colour     || null,
        };
      }
    }

    const pdfBytes = await buildPdf(gamesRes.data as GameData[], clubData, isMobile);

    // Chunked base64 — avoids spread-arg stack overflow on large PDFs
    let b64 = '';
    for (let i = 0; i < pdfBytes.length; i += 8192) {
      b64 += String.fromCharCode(...pdfBytes.subarray(i, i + 8192));
    }
    const base64 = btoa(b64);

    const filename = gameIds.length === 1
      ? `${safeName(gamesRes.data[0].game_name || "game_card")}.pdf`
      : `CoachSmart_Games_${gameIds.length}.pdf`;

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
