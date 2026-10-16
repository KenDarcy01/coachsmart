// Sportlomo club fixtures source, shared by gaa-fixtures (live page) and
// gaa-sync (season store), so both fetch games exactly the same way.
import { type ClubGame, parseAjaxBody, parseClubGames } from "./gaa.ts";

export const UA = "Mozilla/5.0 (compatible; gaa-fixtures-feed)";

export const AJAX = "https://dublingaa.sportlomo.com/wp-admin/admin-ajax.php";
// How each code is selected on Sportlomo's club fixtures page. code_name alone
// doesn't switch code (code_id does). For football and hurling, user_id is the
// level: 3 = Adult & Minor, 7167 = CCC1 (U8-U12), 7130 = CCC2 (U13-U16); club IDs
// and code_ids are the same at every level. Camogie (7282) and LGFA (7046) are
// separate organisations with their own club IDs and no code_id.
export const GAA_LEVELS = ["3", "7167", "7130"];
export const SOURCES: Record<string, { userIds: string[]; codeId?: string; codeName: string; clubParam?: string }> = {
  Football: { userIds: GAA_LEVELS, codeId: "26", codeName: "Football" },
  Hurling: { userIds: GAA_LEVELS, codeId: "27", codeName: "Hurling" },
  Camogie: { userIds: ["7282"], codeName: "", clubParam: "camogieClub" },
  "Ladies Football": { userIds: ["7046"], codeName: "", clubParam: "lgfaClub" },
};
export const CODES = Object.keys(SOURCES);

/** Same request the club fixtures page (dublingaa.sportlomo.com/fixtures-3/) makes. club "" = every club. */
export async function fetchClub(
  club: string, clubName: string, from: string, to: string, code: string, level: string,
): Promise<ClubGame[]> {
  const games: ClubGame[] = [];
  const seen = new Set<string>();
  const maxPages = club ? 10 : 80;
  for (let page = 1; page <= maxPages; page++) {
    const src = SOURCES[code];
    const form = new URLSearchParams({
      action: "get_fixtures3", fdate: from, tdate: to, user_id: level,
      ...(src.codeId ? { code_id: src.codeId } : {}),
      age_id: "", spage_id: String(page), is_all: "0", sort: "", code_name: src.codeName, debug: "",
      is_fixture: "1", club_search_id: club, club_search_val: club ? clubName : "Select Club", comp_search_id: "",
    });
    const res = await fetch(AJAX, {
      method: "POST",
      headers: {
        "User-Agent": UA,
        "Accept": "application/json, text/javascript, */*; q=0.01",
        "Content-Type": "application/x-www-form-urlencoded; charset=UTF-8",
        "X-Requested-With": "XMLHttpRequest",
        "Referer": "https://dublingaa.sportlomo.com/fixtures-3/",
      },
      body: form,
      signal: AbortSignal.timeout(20_000),
    });
    if (!res.ok) throw new Error(`Source site returned ${res.status} for ${club ? `club ${club}` : "all clubs"}`);
    const body = parseAjaxBody(await res.text());
    for (const g of parseClubGames(body.html)) {
      const id = [g.compId, g.home, g.away, g.startUtc.getTime()].join("|");
      if (!seen.has(id)) { seen.add(id); games.push({ ...g, code }); }
    }
    if (!body.isLoadMore) break;
  }
  return games;
}
