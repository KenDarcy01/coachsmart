// deno-lint-ignore-file no-explicit-any
import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { PDFDocument, rgb, PDFFont } from "npm:pdf-lib@1.17.1";
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

// ─── Font fetching (Google Fonts → TTF via old UA) ───────────────────────────

async function fetchGoogleFontBytes(family: string): Promise<Uint8Array> {
  const cssUrl = `https://fonts.googleapis.com/css?family=${encodeURIComponent(family)}`;
  const css = await fetch(cssUrl, {
    headers: { "User-Agent": "Mozilla/4.0 (compatible; MSIE 6.0; Windows NT 5.1)" },
  }).then((r) => r.text());
  const match = css.match(/url\((https:\/\/fonts\.gstatic\.com\/[^)]+)\)/);
  if (!match) throw new Error(`TTF not found in Google Fonts CSS for: ${family}`);
  const buf = await fetch(match[1]).then((r) => r.arrayBuffer());
  return new Uint8Array(buf);
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

  // ── Fonts (fetch in parallel) ──
  const [montserratBoldBytes, notoRegBytes, notoBoldBytes] = await Promise.all([
    fetchGoogleFontBytes("Montserrat:700"),
    fetchGoogleFontBytes("Noto+Sans:400"),
    fetchGoogleFontBytes("Noto+Sans:700"),
  ]);

  // ── Images (fetch in parallel) ──
  const [gameImgBytes, crestBytes] = await Promise.all([
    game.game_details_image ? fetchImageBytes(game.game_details_image) : Promise.resolve(null),
    club.crest              ? fetchImageBytes(club.crest)              : Promise.resolve(null),
  ]);

  // ── Create PDF ──
  const doc = await PDFDocument.create();
  doc.registerFontkit(fontkit);

  const montserratBold = await doc.embedFont(montserratBoldBytes);
  const notoReg        = await doc.embedFont(notoRegBytes);
  const notoBold       = await doc.embedFont(notoBoldBytes);

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

  // ── Header layout ──
  const CREST_SIZE  = 60;
  const HEADER_PAD  = 16;
  const CLUB_SIZE   = 22;  // Montserrat Bold
  const GAME_SIZE   = 17;  // NotoSans Bold
  const RULE_H      = 1;

  let headerH = HEADER_PAD;
  if (crestImg) headerH += CREST_SIZE + 8;
  headerH += CLUB_SIZE + 6 + RULE_H + 8 + GAME_SIZE + HEADER_PAD;

  // Accent stripe heights
  const WHITE_STRIPE = 2;
  const SEC_STRIPE   = 4;
  const THIRD_STRIPE = thirdRgb ? 3 : 0;
  const STRIPE_H     = WHITE_STRIPE + SEC_STRIPE + THIRD_STRIPE;

  // Footer height (from bottom)
  const FOOTER_LINE_Y  = 48;       // y of footer rule (from page bottom)
  const FOOTER_TEXT_Y  = 32;       // y of footer text baseline
  const FOOTER_ZONE    = 56;       // total reserved at bottom

  // Section constants
  const SECTION_BAR_H  = 30;       // section label bar height
  const SECTION_FONT_S = 13;
  const BODY_FONT_S    = 11;
  const LINE_H         = 17;       // body line height
  const BODY_INDENT    = 12;       // indent inside content width
  const BODY_W         = CW - BODY_INDENT * 2;

  // ── Draw header on a page ──
  function drawHeader(page: any) {
    const yt = PH; // top of page in pdf-lib coords (y grows up, so top is PH)

    // Primary colour header rect
    page.drawRectangle({
      x: 0, y: yt - headerH,
      width: PW, height: headerH,
      color: primaryRgb,
    });

    let yp = HEADER_PAD; // distance from TOP of page going down
    const centerX = PW / 2;

    if (crestImg) {
      const cx = centerX - CREST_SIZE / 2;
      page.drawImage(crestImg, {
        x: cx, y: yt - yp - CREST_SIZE,
        width: CREST_SIZE, height: CREST_SIZE,
      });
      yp += CREST_SIZE + 8;
    }

    // Club name
    const clubW = montserratBold.widthOfTextAtSize(club.club_name, CLUB_SIZE);
    page.drawText(club.club_name, {
      x: centerX - clubW / 2,
      y: yt - yp - CLUB_SIZE,
      size: CLUB_SIZE,
      font: montserratBold,
      color: white,
    });
    yp += CLUB_SIZE + 6;

    // Rule
    page.drawLine({
      start: { x: ML, y: yt - yp },
      end:   { x: PW - MR, y: yt - yp },
      thickness: RULE_H,
      color: white,
    });
    yp += RULE_H + 8;

    // Game name (truncate if too wide)
    let gameNameText = game.game_name;
    while (notoBold.widthOfTextAtSize(gameNameText, GAME_SIZE) > CW - 8 && gameNameText.length > 0) {
      gameNameText = gameNameText.slice(0, -4) + "...";
    }
    const gnW = notoBold.widthOfTextAtSize(gameNameText, GAME_SIZE);
    page.drawText(gameNameText, {
      x: centerX - gnW / 2,
      y: yt - yp - GAME_SIZE,
      size: GAME_SIZE,
      font: notoBold,
      color: white,
    });

    // Accent stripes
    let sy = yt - headerH;
    page.drawRectangle({ x: 0, y: sy - WHITE_STRIPE, width: PW, height: WHITE_STRIPE, color: white });
    sy -= WHITE_STRIPE;
    page.drawRectangle({ x: 0, y: sy - SEC_STRIPE, width: PW, height: SEC_STRIPE, color: secondaryRgb });
    sy -= SEC_STRIPE;
    if (thirdRgb) {
      page.drawRectangle({ x: 0, y: sy - THIRD_STRIPE, width: PW, height: THIRD_STRIPE, color: thirdRgb });
    }
  }

  // ── Draw footer on a page ──
  function drawFooter(page: any) {
    page.drawLine({
      start: { x: ML, y: FOOTER_LINE_Y },
      end:   { x: PW - MR, y: FOOTER_LINE_Y },
      thickness: 1.5,
      color: footerLineRgb,
    });
    page.drawText(club.club_name, {
      x: ML,
      y: FOOTER_TEXT_Y,
      size: 10,
      font: notoBold,
      color: primaryRgb,
    });
    const csW = notoReg.widthOfTextAtSize("CoachSmart", 10);
    page.drawText("CoachSmart", {
      x: PW - MR - csW,
      y: FOOTER_TEXT_Y,
      size: 10,
      font: notoReg,
      color: grey,
    });
  }

  // ── Page manager ──
  let currentPage: any = null;
  let curY = 0; // current Y from page top (increases as we go down)

  function newPage(isFirst: boolean) {
    const page = doc.addPage([PW, PH]);
    drawFooter(page);
    if (isFirst) {
      drawHeader(page);
      curY = headerH + STRIPE_H;
    } else {
      // continuation spacer
      curY = 24;
    }
    currentPage = page;
  }

  function ensureSpace(needed: number) {
    const available = PH - curY - FOOTER_ZONE;
    if (available < needed) {
      newPage(false);
    }
  }

  // Draw a coloured section bar
  function drawSectionBar(label: string) {
    ensureSpace(SECTION_BAR_H + LINE_H + 8);
    const yTop = PH - curY;
    currentPage.drawRectangle({
      x: 0, y: yTop - SECTION_BAR_H,
      width: PW, height: SECTION_BAR_H,
      color: secondaryRgb,
    });
    currentPage.drawText(label, {
      x: ML + BODY_INDENT,
      y: yTop - SECTION_BAR_H + (SECTION_BAR_H - SECTION_FONT_S) / 2,
      size: SECTION_FONT_S,
      font: notoBold,
      color: white,
    });
    curY += SECTION_BAR_H + 6;
  }

  // Draw wrapped body text
  function drawBodyText(text: string) {
    if (!text.trim()) return;
    const lines = wrapText(text, notoReg, BODY_FONT_S, BODY_W);
    for (const line of lines) {
      ensureSpace(LINE_H);
      const prefix = "• ";
      const displayText = line ? `${prefix}${line}` : "";
      if (displayText) {
        currentPage.drawText(displayText, {
          x: ML + BODY_INDENT,
          y: PH - curY - BODY_FONT_S,
          size: BODY_FONT_S,
          font: notoReg,
          color: rgb(0.1, 0.1, 0.1),
        });
      }
      curY += LINE_H;
    }
    curY += 6; // gap after section content
  }

  // Draw the game image
  async function drawGameImage() {
    if (!gameImg) return;
    const ratio = gameImg.width / gameImg.height;
    const imgW = CW;
    const imgH = Math.min(imgW / ratio, 200); // cap at 200pt
    ensureSpace(imgH + 8);
    currentPage.drawImage(gameImg, {
      x: ML,
      y: PH - curY - imgH,
      width: imgW,
      height: imgH,
    });
    curY += imgH + 8;
  }

  // ── Build content ──
  newPage(true);

  // Section order matches Flutter: Setup → Image → How To Play → Variations → Teaching Points → Video
  if (game.game_setup?.trim()) {
    drawSectionBar("SETUP");
    drawBodyText(game.game_setup);
    curY += 4;
  }

  await drawGameImage();

  if (game.game_how_to_play?.trim()) {
    drawSectionBar("HOW TO PLAY");
    drawBodyText(game.game_how_to_play);
    curY += 4;
  }

  if (game.game_variations?.trim()) {
    drawSectionBar("VARIATIONS");
    drawBodyText(game.game_variations);
    curY += 4;
  }

  if (game.game_teaching_points?.trim()) {
    drawSectionBar("TEACHING POINTS");
    drawBodyText(game.game_teaching_points);
    curY += 4;
  }

  if (game.game_video?.trim()) {
    drawSectionBar("VIDEO EXPLAINER");
    ensureSpace(LINE_H);
    currentPage.drawText(game.game_video, {
      x: ML + BODY_INDENT,
      y: PH - curY - BODY_FONT_S,
      size: BODY_FONT_S,
      font: notoReg,
      color: rgb(0.0, 0.3, 0.8),
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
    const base64 = btoa(String.fromCharCode(...pdfBytes));
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
