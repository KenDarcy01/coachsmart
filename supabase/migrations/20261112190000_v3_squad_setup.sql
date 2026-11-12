-- v3 squad setup on the Team page (Ken approved 2026-11-12).
-- Super users only for now (role_level >= 110 on the team).
--   get_team_squads_v3   active squads + turned-off squads, player counts that
--                        ignore the "-" code (code 1)
--   disable_team_squad   "Turn off": never deletes. Players move to No Team,
--                        squad is archived (team_id NULL, archived_team_id kept)
--                        so history keeps its name. Blocked while an upcoming
--                        event uses it.
--   enable_team_squad    "Turn on": back on the team, empty, at the end.
-- Add / edit / reorder reuse save_team_squad and reorder_team_squads
-- (20261106060000). Nothing used by v2 or team-setup.html changes.

ALTER TABLE public.squads ADD COLUMN IF NOT EXISTS disabled_at timestamptz;

CREATE OR REPLACE FUNCTION public.is_team_super_user(p_team_id bigint)
RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER
SET search_path = 'public'
AS $$
  SELECT auth.uid() IS NOT NULL AND EXISTS (
    SELECT 1
      FROM user_member_link uml
      JOIN member_team_link mtl       ON mtl.member_id = uml.member_id
      JOIN member_team_role_link mtrl ON mtrl.member_team_id = mtl.member_team_id
      JOIN roles r                    ON r.role_id = mtrl.role_id
     WHERE uml.user_id = auth.uid()
       AND COALESCE(uml.status, 'active') = 'active'
       AND mtl.team_id = p_team_id
       AND mtl.status = 'active'
       AND r.role_level >= 110);
$$;

CREATE OR REPLACE FUNCTION public.get_team_squads_v3(p_team_id bigint)
RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path = 'public'
AS $$
DECLARE
  v_team record;
BEGIN
  IF NOT public.is_team_super_user(p_team_id) THEN
    RAISE EXCEPTION 'Only super users can set up squads';
  END IF;
  SELECT t.team_id, t.team_name, c.club_name
    INTO v_team
    FROM teams t LEFT JOIN clubs c ON c.club_id = t.club_id
   WHERE t.team_id = p_team_id;

  RETURN jsonb_build_object(
    'team_id',   v_team.team_id,
    'team_name', v_team.team_name,
    'club_name', v_team.club_name,
    'squads', (
      SELECT COALESCE(jsonb_agg(jsonb_build_object(
               'squad_id', s.squad_id,
               'name', s.squad_name,
               'colour', s.squad_colour,
               'image', s.squad_image,
               'grade', s.grade,
               'no_team', s.squad_name = 'No Team',
               'players', (
                 SELECT count(DISTINCT msl.member_id)
                   FROM member_squad_link msl
                   JOIN member_team_link mtl ON mtl.member_id = msl.member_id
                    AND mtl.team_id = p_team_id AND mtl.status = 'active'
                  WHERE msl.squad_id = s.squad_id AND msl.team_id = p_team_id
                    AND COALESCE(msl.code_id, 0) <> 1))
             ORDER BY (s.squad_name = 'No Team'), s.squad_list_seq NULLS LAST, s.squad_id), '[]'::jsonb)
        FROM squads s
       WHERE s.team_id = p_team_id),
    'disabled', (
      SELECT COALESCE(jsonb_agg(jsonb_build_object(
               'squad_id', s.squad_id,
               'name', s.squad_name,
               'colour', s.squad_colour,
               'image', s.squad_image,
               'disabled_at', s.disabled_at,
               'past_events', (SELECT count(*) FROM events e WHERE e.squad_id = s.squad_id))
             ORDER BY s.disabled_at DESC NULLS LAST, s.squad_name), '[]'::jsonb)
        FROM squads s
       WHERE s.archived_team_id = p_team_id AND s.team_id IS NULL)
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.disable_team_squad(p_team_id bigint, p_squad_id bigint)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = 'public'
AS $$
DECLARE
  v_sq       record;
  v_no_team  bigint;
  v_upcoming int;
BEGIN
  IF NOT public.is_team_super_user(p_team_id) THEN
    RAISE EXCEPTION 'Only super users can set up squads';
  END IF;
  SELECT * INTO v_sq FROM squads WHERE squad_id = p_squad_id AND team_id = p_team_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'Squad not found'; END IF;
  IF v_sq.squad_name = 'No Team' THEN RAISE EXCEPTION 'No Team can''t be turned off'; END IF;

  SELECT count(*) INTO v_upcoming FROM events
   WHERE squad_id = p_squad_id AND event_date_time_2 >= (now() AT TIME ZONE 'Europe/Dublin')
     AND COALESCE(status, 'active') <> 'cancelled';
  IF v_upcoming > 0 THEN
    RAISE EXCEPTION '% upcoming event(s) are for this squad. Change or cancel them first.', v_upcoming;
  END IF;

  SELECT squad_id INTO v_no_team FROM squads
   WHERE team_id = p_team_id AND squad_name = 'No Team'
   ORDER BY squad_id LIMIT 1;
  IF v_no_team IS NULL THEN RAISE EXCEPTION 'This team has no No Team squad'; END IF;

  -- Move players to No Team; skip a row that would duplicate a No Team placement
  DELETE FROM member_squad_link a
   WHERE a.squad_id = p_squad_id AND a.team_id = p_team_id
     AND EXISTS (SELECT 1 FROM member_squad_link b
                  WHERE b.squad_id = v_no_team AND b.member_id = a.member_id
                    AND b.team_id = a.team_id AND b.code_id IS NOT DISTINCT FROM a.code_id);
  UPDATE member_squad_link SET squad_id = v_no_team WHERE squad_id = p_squad_id;
  UPDATE member_team_link  SET squad_id = v_no_team WHERE squad_id = p_squad_id;

  -- Never delete: keep it for history, off the team's lists
  UPDATE squads
     SET archived_team_id = team_id, team_id = NULL, disabled_at = now()
   WHERE squad_id = p_squad_id;

  RETURN public.get_team_squads_v3(p_team_id);
END;
$$;

CREATE OR REPLACE FUNCTION public.enable_team_squad(p_team_id bigint, p_squad_id bigint)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = 'public'
AS $$
DECLARE
  v_sq  record;
  v_seq int;
BEGIN
  IF NOT public.is_team_super_user(p_team_id) THEN
    RAISE EXCEPTION 'Only super users can set up squads';
  END IF;
  SELECT * INTO v_sq FROM squads
   WHERE squad_id = p_squad_id AND archived_team_id = p_team_id AND team_id IS NULL;
  IF NOT FOUND THEN RAISE EXCEPTION 'Squad not found'; END IF;
  IF EXISTS (SELECT 1 FROM squads WHERE team_id = p_team_id
                AND lower(squad_name) = lower(v_sq.squad_name)) THEN
    RAISE EXCEPTION 'There is already a squad called %. Rename it first.', v_sq.squad_name;
  END IF;
  SELECT COALESCE(max(squad_list_seq), 0) + 1 INTO v_seq
    FROM squads WHERE team_id = p_team_id AND squad_name <> 'No Team';
  UPDATE squads
     SET team_id = p_team_id, archived_team_id = NULL, disabled_at = NULL,
         squad_list_seq = LEAST(v_seq, 99)
   WHERE squad_id = p_squad_id;

  RETURN public.get_team_squads_v3(p_team_id);
END;
$$;

REVOKE ALL ON FUNCTION public.is_team_super_user(bigint) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.get_team_squads_v3(bigint) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.disable_team_squad(bigint, bigint) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.enable_team_squad(bigint, bigint) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_team_squads_v3(bigint) TO authenticated;
GRANT EXECUTE ON FUNCTION public.disable_team_squad(bigint, bigint) TO authenticated;
GRANT EXECUTE ON FUNCTION public.enable_team_squad(bigint, bigint) TO authenticated;
