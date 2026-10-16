// One Sportlomo game as a gaa_games row for gaa_replace_window (pure, easy to test)
import { type ClubGame, compMeta } from "../gaa-fixtures/gaa.ts";

const ORG: Record<string, string> = { Football: "gaa", Hurling: "gaa", Camogie: "camogie", "Ladies Football": "lgfa" };

// "2 - 10" -> { text: "2-10", pts: 16 }
function score(s: string): { text: string; pts: number | null } {
  const m = (s || "").match(/(\d+)\s*-\s*(\d+)/);
  return m ? { text: `${Number(m[1])}-${Number(m[2])}`, pts: Number(m[1]) * 3 + Number(m[2]) } : { text: "", pts: null };
}

function level(age: string): string {
  const n = age.match(/^U(\d+)$/);
  if (!n) return "adult";
  return Number(n[1]) <= 12 ? "ccc1" : Number(n[1]) <= 16 ? "ccc2" : "adult";
}

export function row(g: ClubGame) {
  const code = g.code ?? "";
  const meta = compMeta(g.comp);
  const [h, a] = g.score ? g.score.split(" v ") : ["", ""];
  const hs = score(h), as = score(a);
  return {
    compId: g.compId, comp: g.comp, code, age: meta.age, grade: meta.grade, level: level(meta.age),
    start: g.startUtc.toISOString(), home: g.home, away: g.away,
    homeClub: g.homeClub, awayClub: g.awayClub, homeClubId: g.homeClubId, awayClubId: g.awayClubId, org: ORG[code],
    status: g.kind,
    hs: hs.text, as: as.text, hp: hs.pts, ap: as.pts,
    venue: g.venue, referee: g.referee, note: g.note,
  };
}
