// "No Team" is the squad every team gets for players nobody has placed yet.
// v2 shows it by that name; v3 shows it as "Unassigned" and treats it the
// same as having no squad at all (Ken, 2026-11-12). The database keeps the
// No Team squad while v2 is live, so picking Unassigned in v3 puts the player
// in the team's No Team squad (what v2 expects) rather than removing the link.

const kUnassigned = 'Unassigned';

/// True for the team's "No Team" squad.
bool isNoTeamSquad(String? name) =>
    (name ?? '').trim().toLowerCase() == 'no team';

/// A squad name as v3 shows it.
String v3SquadName(String? name) =>
    isNoTeamSquad(name) ? kUnassigned : (name ?? '');
