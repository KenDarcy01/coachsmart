// Multi-sport (Ken, 2026-11-13): GAA, soccer and rugby. A team's sport is its
// club's (clubs.sport_id: 1 GAA, 2 soccer, 3 rugby; unknown = GAA). AI
// prompts are written for GAA; for soccer and rugby sportPrompt swaps the
// GAA wording and adds a note to use that sport's terms only. GAA prompts
// come back unchanged, so GAA output (and the old app) is the same.
export type SportId = 1 | 2 | 3;

export const sportId = (v: unknown): SportId => {
  const n = Number(v);
  return n === 2 ? 2 : n === 3 ? 3 : 1;
};

export async function teamSport(sb: any, teamId: unknown): Promise<SportId> {
  if (!teamId) return 1;
  try {
    const { data } = await sb.from("teams").select("clubs(sport_id)").eq("team_id", teamId).maybeSingle();
    return sportId((data as any)?.clubs?.sport_id);
  } catch {
    return 1;
  }
}

const NAME: Record<2 | 3, string> = { 2: "soccer", 3: "rugby union" };
const TERMS: Record<2 | 3, string> = {
  2: "goals, shots, saves, corners, free kicks, penalties, offside, throw-ins, goal kicks, yellow and red cards",
  3: "tries, conversions, penalty goals, drop goals, lineouts, scrums, rucks, mauls, knock-ons, the sin bin, yellow and red cards",
};

export const sportName = (s: SportId) => (s === 1 ? "GAA" : NAME[s]);

export function sportPrompt(prompt: string, s: SportId): string {
  if (s === 1) return prompt;
  const name = NAME[s];
  return prompt
    .replace(/\(e\.g\. points, goals, wides, frees, 45s, sideline, puck-out, kick-out, hurley, sliotar\)/g, `(e.g. ${TERMS[s]})`)
    .replace(/- Use the sport code supplied in the context throughout[^\n]*/g, `- This is ${name}: use ${name} terminology throughout`)
    .replace(/GAA \(Gaelic Athletic Association\)/g, name)
    .replace(/\bGAA\b/g, name)
    + `\n\nThis is ${name}. Use ${name} terms only (${TERMS[s]}). Never use GAA words: no points over the bar, hand pass, solo, puck-out, kick-out, sliotar, hurley, 45 or 65.`;
}
