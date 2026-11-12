-- One-off (Ken, 2026-11-12, "go on the 34"): active team members with no
-- squad for one of their team's codes go into the team's No Team squad
-- (v3 shows it as Unassigned). This is where v2 already expects them.
-- Only adds member_squad_link rows; nothing is changed or removed.
INSERT INTO public.member_squad_link (member_id, team_id, code_id, squad_id)
SELECT DISTINCT mtl.member_id, mtl.team_id, ccl.code_id, nt.squad_id
  FROM public.member_team_link mtl
  JOIN public.teams t ON t.team_id = mtl.team_id
  JOIN public.club_code_link ccl
    ON ccl.club_id = t.club_id
   AND (ccl.team_id IS NULL OR ccl.team_id = t.team_id)
   AND ccl.code_id > 1
  JOIN LATERAL (
        SELECT s.squad_id FROM public.squads s
         WHERE s.team_id = t.team_id AND s.squad_name = 'No Team'
         ORDER BY s.squad_id LIMIT 1) nt ON true
 WHERE mtl.status = 'active'
   AND public.team_has_code(t.team_id, ccl.code_id)
   AND NOT EXISTS (
        SELECT 1 FROM public.member_squad_link msl
         WHERE msl.member_id = mtl.member_id
           AND msl.team_id = mtl.team_id
           AND msl.code_id = ccl.code_id);
