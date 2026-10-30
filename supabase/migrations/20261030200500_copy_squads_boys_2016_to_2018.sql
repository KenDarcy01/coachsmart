-- Copy the squad set from Clontarf Boys 2016 (team 82) to Clontarf Boys 2018 (team 109).
-- Squads only, no players. Boys 2018 already has its own "No Team" squad, so that one is skipped.
-- Idempotent: a squad is only added if the new team doesn't already have one with that name.
INSERT INTO squads (team_id, squad_name, grade, squad_colour, squad_image, squad_list_seq)
SELECT 109, s.squad_name, s.grade, s.squad_colour, s.squad_image, s.squad_list_seq
FROM squads s
WHERE s.team_id = 82
  AND s.squad_name <> 'No Team'
  AND NOT EXISTS (
    SELECT 1 FROM squads x WHERE x.team_id = 109 AND x.squad_name = s.squad_name
  )
ORDER BY s.squad_list_seq;
