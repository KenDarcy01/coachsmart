// deno-lint-ignore-file no-explicit-any
// Score keeper voice (webviews/score-keeper.html).
//
// The phone turns speech into words; this asks Gemini what the coach meant,
// using the squad list and the team's stat names, so misheard words still
// land on the right stat and player ("pointy kieran" → Point, Ciarán Byrne).
// The page falls back to its own on-phone reader (cs-score-voice.js) when
// this fails, is slow, or there is no signal.
//
// POST { event_id, text | audio, us, opp, types:[{id,name,value}],
//        players:[{id,name,number}], aliases:{spoken:member_id} }
//   → { items:[{kind:'score', type_id, side, member_id, unsure, heard, count}
//              |{kind:'sub', on_id, off_id}], unknown:[string], transcript }
// audio: a short WAV clip (base64) from the app's always-on mic. Gemini
// listens to it directly, knowing the player names to expect, instead of
// relying on the phone's dictation.
//
// Needs the caller's JWT, membership of the event's team and users.ai_features.
// Requires GEMINI_API_KEY; GEMINI_MODEL is optional (same secrets as ai-match-report).
import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.43.4";

const GEMINI_MODEL = Deno.env.get("GEMINI_MODEL") ?? "gemini-2.5-flash";
const GEMINI_URL   = `https://generativelanguage.googleapis.com/v1beta/models/${GEMINI_MODEL}:generateContent`;

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};
const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), { status, headers: { ...corsHeaders, "Content-Type": "application/json" } });

const PROMPT = `You read short spoken commands from a GAA (Gaelic games) coach keeping score during a match.
The words came from phone speech recognition, so they are often misheard: Irish names come out as
English words or other names (e.g. "Kieran"/"keera" for Ciarán, "Shawn" for Seán, "Fin" for Fionn,
"Eoin"/"Owen"), and stat words get mangled ("pint"/"pointy"/"appoint" = Point, "gold"/"go" = Goal,
"two pointer"/"to pointer"/"2.0" = 2 Pointer, "white"/"wild" = Wide). Work out what the coach meant.

You get our team name, the opposition name, the stat types (id, name, value) and our players (id, name,
shirt number). One utterance can hold several commands ("point Ciarán and a wide for them").

Rules:
- Each command is a stat (score or other stat) or a substitution ("sub 17 for 11", "Jack on for Liam").
- side: "opp" only if the opposition is named or the coach says them/they/their/opposition. Otherwise "us",
  including when nobody is named at all.
- member_id: only for side "us". Match the spoken name or shirt number to the players list (sound-alikes,
  first name only, surname only, nicknames). Use the known-names list first. If you are not sure, still give
  your best guess and set unsure true. If no player was mentioned, member_id null.
- A name that sounds or is spelt a little differently is still that player ("Connor Wilson" = Conor Wilson,
  "Sean"/"Shaun" = Seán). Always pick the closest player when a name was said; never leave member_id null then.
- heard: the words that named the player, as spoken (empty if none).
- count: how many of that stat (e.g. "two points" = 2), default 1.
- Use only ids from the lists. Never invent a player or stat type.
- Anything you cannot turn into a command goes in unknown as the original words.

When you get an audio clip instead of words, listen to it yourself: expect the stat names and the
player names and numbers in the lists, said quickly by an Irish coach, often with crowd or wind noise.
The coach only ever presses the mic to record a stat, so this is never general chat or commentary.
Hear every clip as: [stat name] [optional player name or shirt number] [optional "them"/opposition],
possibly several in a row. A word that sounds anything like a stat name IS that stat; a word that sounds
like a player's name IS that player. Write transcript using the stat names and player names exactly as
they appear in the lists (e.g. "Point Conor Wilson", "Wide them"), not everyday words.
Only put something in unknown if it really has no stat in it at all.

Return ONLY JSON:
{"transcript":"point ciarán","items":[{"kind":"score","type_id":1,"side":"us","member_id":5,"unsure":false,"heard":"ciaran","count":1},
          {"kind":"sub","on_id":7,"off_id":3}],
 "unknown":[]}`;

// Closest player to the spoken words, by spelling: each spoken word is
// compared with each player's first and last name (accents and case ignored).
// sure = both names matched closely, or one name matched exactly and no other
// player shares it.
const fold = (t: string) => t.normalize("NFD").replace(/[\u0300-\u036f]/g, "").toLowerCase().replace(/[^a-z' ]/g, " ");
function editDistance(a: string, b: string) {
  const d = Array.from({ length: a.length + 1 }, (_, i) => [i, ...Array(b.length).fill(0)]);
  for (let j = 1; j <= b.length; j++) d[0][j] = j;
  for (let i = 1; i <= a.length; i++) for (let j = 1; j <= b.length; j++) {
    d[i][j] = Math.min(d[i - 1][j] + 1, d[i][j - 1] + 1, d[i - 1][j - 1] + (a[i - 1] === b[j - 1] ? 0 : 1));
  }
  return d[a.length][b.length];
}
function nameScore(word: string, name: string) {
  if (!word || !name || word.length < 2) return 0;
  if (word === name) return 1;
  const allow = name.length <= 4 ? 1 : 2;
  const e = editDistance(word, name);
  return e <= allow ? 1 - e / (name.length + 1) : 0;
}
function matchPlayer(words: string, players: { id: number; name: string }[]) {
  const said = fold(words).split(/\s+/).filter((w) => w.length > 1);
  if (!said.length) return null;
  const scored = players.map((p) => {
    const parts = fold(p.name).split(/\s+/).filter(Boolean);
    const first = parts[0] || "", last = parts.slice(1).join(" ").replace(/ /g, "");
    const f = Math.max(0, ...said.map((w) => nameScore(w, first)));
    const l = Math.max(0, ...said.map((w) => nameScore(w, last)), last ? nameScore(said.join(""), last) : 0);
    return { id: p.id, f, l, s: f + l, both: f > 0 && l > 0 };
  }).filter((x) => x.s > 0).sort((a, b) => b.s - a.s);
  if (!scored.length) return null;
  const best = scored[0], next = scored[1];
  if (next && next.s >= best.s - 0.05) return { id: best.id, sure: false };
  return { id: best.id, sure: best.both || best.s >= 1 };
}

// Stat type named in the words, by spelling: whole names first ("two pointer"),
// then single words close to a one-word name ("pint" ~ point)
const SOUNDS_LIKE: Record<string, string> = { gold: "goal", gol: "goal", goul: "goal", white: "wide", wild: "wide", wise: "wide",
  pint: "point", pointy: "point", appoint: "point", poynt: "point", to: "two", too: "two" };
function matchType(words: string, types: { id: number; name: string }[]) {
  const said = fold(words).split(/\s+/).filter(Boolean).map((w) => SOUNDS_LIKE[w] || w);
  const joined = " " + said.join(" ") + " ";
  let best: { id: number; s: number; words: string[] } | null = null;
  for (const t of types) {
    const tw = fold(t.name).split(/\s+/).filter(Boolean);
    if (!tw.length) continue;
    let s = 0;
    if (joined.includes(" " + tw.join(" ") + " ")) s = 2 + tw.length;
    else if (tw.length === 1) s = Math.max(0, ...said.map((w) => w.length >= 3 ? nameScore(w, tw[0]) : 0));
    if (s > 0 && (!best || s > best.s)) best = { id: t.id, s, words: tw };
  }
  return best;
}

serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method !== "POST") return json({ error: "Method not allowed" }, 405);
  try {
    const body = await req.json();
    const eventId = Number(body.event_id);
    const text = typeof body.text === "string" ? body.text.trim().slice(0, 400) : "";
    const audio = typeof body.audio === "string" && body.audio.length < 1_500_000 ? body.audio : "";
    if (!eventId || (!text && !audio)) return json({ error: "event_id and text or audio required" }, 400);

    const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
    const sb = createClient(SUPABASE_URL, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!, { auth: { persistSession: false } });

    const jwt = (req.headers.get("Authorization") || "").replace(/^Bearer\s+/i, "");
    const { data: { user }, error: userErr } = await sb.auth.getUser(jwt);
    if (userErr || !user) return json({ error: "Please sign in again" }, 401);

    const { data: ev } = await sb.from("events").select("team_id").eq("event_id", eventId).maybeSingle();
    if (!ev) return json({ error: "Match not found" }, 404);
    const asUser = createClient(SUPABASE_URL, Deno.env.get("SUPABASE_ANON_KEY")!, {
      auth: { persistSession: false }, global: { headers: { Authorization: `Bearer ${jwt}` } },
    });
    const [{ data: member }, { data: me }] = await Promise.all([
      asUser.rpc("sk_is_team_member", { p_team_id: ev.team_id }),
      sb.from("users").select("ai_features").eq("user_id", user.id).maybeSingle(),
    ]);
    if (member !== true) return json({ error: "You're not on this team" }, 403);
    if (me?.ai_features !== true) return json({ error: "AI features are not switched on for your account" }, 403);

    const apiKey = Deno.env.get("GEMINI_API_KEY");
    if (!apiKey) return json({ error: "GEMINI_API_KEY not configured" }, 500);

    const types = (Array.isArray(body.types) ? body.types : []).slice(0, 40)
      .map((t: any) => ({ id: Number(t.id), name: String(t.name || "").slice(0, 40), value: t.value == null ? null : Number(t.value) }))
      .filter((t: any) => t.id && t.name);
    const players = (Array.isArray(body.players) ? body.players : []).slice(0, 150)
      .map((p: any) => ({ id: Number(p.id), name: String(p.name || "").slice(0, 60), number: p.number == null ? null : Number(p.number) }))
      .filter((p: any) => p.id && p.name);
    const aliases = Object.entries(body.aliases && typeof body.aliases === "object" ? body.aliases : {}).slice(0, 80)
      .map(([k, v]) => ({ spoken: String(k).slice(0, 40), member_id: Number(v) }))
      .filter(a => players.some((p: any) => p.id === a.member_id));

    const userText = [
      `Our team: ${String(body.us || "Us").slice(0, 60)}`,
      `Opposition: ${String(body.opp || "Opposition").slice(0, 60)}`,
      `Stat types: ${JSON.stringify(types)}`,
      `Our players: ${JSON.stringify(players)}`,
      aliases.length ? `Known names (spoken words this coach used before for a player): ${JSON.stringify(aliases)}` : "",
      audio ? "Spoken: (the audio clip)" : `Spoken: "${text}"`,
    ].filter(Boolean).join("\n");

    // Thinking off for speed; models that can't turn it off get asked without it.
    const ask = (fast: boolean) => fetch(`${GEMINI_URL}?key=${apiKey}`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        system_instruction: { parts: [{ text: PROMPT }] },
        contents: [{ parts: audio
          ? [{ inline_data: { mime_type: "audio/wav", data: audio } }, { text: userText }]
          : [{ text: userText }] }],
        generationConfig: Object.assign(
          { maxOutputTokens: 2048, temperature: 0, responseMimeType: "application/json" },
          fast ? { thinkingConfig: { thinkingBudget: 0 } } : {},
        ),
      }),
    });
    let res = await ask(true);
    if (res.status === 400) res = await ask(false);
    if (!res.ok) { console.warn("Gemini", res.status, (await res.text()).slice(0, 200)); return json({ error: "AI unavailable" }, 502); }
    const data = await res.json();
    const raw = (data.candidates?.[0]?.content?.parts?.[0]?.text || "").trim()
      .replace(/^```json\s*/i, "").replace(/^```\s*/i, "").replace(/\s*```$/i, "");
    let out: any;
    try { out = JSON.parse(raw); } catch { return json({ error: "AI gave an unexpected answer" }, 502); }

    // Keep only ids we sent. A name the AI heard but didn't link to a player
    // is matched here by spelling (Connor ~ Conor, Wolson ~ Wilson).
    const byName = (words: string) => matchPlayer(words, players);
    const typeIds = new Set(types.map((t: any) => t.id));
    const playerIds = new Set(players.map((p: any) => p.id));
    const items = (Array.isArray(out.items) ? out.items : []).flatMap((it: any) => {
      if (it?.kind === "sub") {
        const on = Number(it.on_id), off = Number(it.off_id);
        return playerIds.has(on) || playerIds.has(off)
          ? [{ kind: "sub", on_id: playerIds.has(on) ? on : null, off_id: playerIds.has(off) ? off : null }] : [];
      }
      const typeId = Number(it?.type_id);
      if (!typeIds.has(typeId)) return [];
      const side = it.side === "opp" ? "opp" : "us";
      let mem = side === "us" && playerIds.has(Number(it.member_id)) ? Number(it.member_id) : null;
      let unsure = !!it.unsure && !!mem;
      if (side === "us" && !mem) {
        const words = typeof it.heard === "string" && it.heard.trim() ? it.heard
          : (out.items.length === 1 && typeof out.transcript === "string" ? out.transcript : "");
        const m = words ? byName(words) : null;
        if (m) { mem = m.id; unsure = !m.sure; }
      }
      return [{
        kind: "score", type_id: typeId, side, member_id: mem, unsure,
        heard: typeof it.heard === "string" ? it.heard.slice(0, 40) : "",
        count: Math.min(Math.max(Math.round(Number(it.count) || 1), 1), 5),
      }];
    });
    // Nothing understood: lean towards a stat anyway, matching the words to
    // the stat names by spelling ("pint" ~ Point) and any name to the squad
    if (!items.length) {
      const words = [typeof out.transcript === "string" ? out.transcript : "", text,
        ...(Array.isArray(out.unknown) ? out.unknown.map(String) : [])].join(" ");
      const t = matchType(words, types);
      if (t) {
        const side = /\b(them|they|their|opp|opposition)\b/i.test(words) || (body.opp && fold(words).includes(fold(String(body.opp)).trim())) ? "opp" : "us";
        const m = side === "us" ? byName(fold(words).split(/\s+/).filter((w) => !t.words.includes(w)).join(" ")) : null;
        items.push({ kind: "score", type_id: t.id, side, member_id: m ? m.id : null, unsure: !!m && !m.sure, heard: "", count: 1 });
        out.unknown = [];
      }
    }
    const unknown = (Array.isArray(out.unknown) ? out.unknown : []).map((u: any) => String(u).slice(0, 80)).slice(0, 5);
    const transcript = typeof out.transcript === "string" ? out.transcript.slice(0, 200) : text;
    return json({ items, unknown, transcript });
  } catch (e) {
    console.error("score-voice", e);
    return json({ error: "Something went wrong" }, 500);
  }
});
