-- Live match list: keep finished matches
--
-- Ken (2026-10-17): a match vanished from the Matches list once it was over.
-- The list only picked up a match if it was dated today or still live, so a
-- game played on another day than scheduled dropped out at full time. Now a
-- match whose clock was started in the last 12 hours stays in the list, and
-- the page shows it under Results.

CREATE OR REPLACE FUNCTION public.get_live_matches()
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = 'public'
AS $$
DECLARE
  v_uid   uuid := auth.uid();
  v_today date := (now() AT TIME ZONE 'Europe/Dublin')::date;
BEGIN
  IF v_uid IS NULL THEN RETURN jsonb_build_object('error', 'not_signed_in'); END IF;

  RETURN jsonb_build_object(
    'server_now', now(),
    'default', COALESCE((SELECT jsonb_build_object('level', level, 'kickoff', kickoff, 'names', names)
                           FROM public.live_follows WHERE user_id = v_uid AND event_id IS NULL),
                        jsonb_build_object('level', 'result', 'kickoff', true, 'names', true)),
    'matches', COALESCE((
      WITH my_clubs AS (
        SELECT DISTINCT t.club_id
          FROM public.user_member_link uml
          JOIN public.member_team_link mtl ON mtl.member_id = uml.member_id AND mtl.status = 'active'
          JOIN public.teams t ON t.team_id = mtl.team_id
         WHERE uml.user_id = v_uid AND t.club_id IS NOT NULL
      ),
      cand AS (
        SELECT e.event_id, public.lm_session_id(e.event_id) AS sid
          FROM public.events e
          JOIN public.teams t ON t.team_id = e.team_id
          LEFT JOIN public.event_types et ON et.event_type_id = e.event_type_id
         WHERE t.club_id IN (SELECT club_id FROM my_clubs)
           AND COALESCE(e.status, 'active') = 'active'
           AND (
             -- today's matches
             ((e.event_date_time AT TIME ZONE 'Europe/Dublin')::date = v_today
               AND (et.event_type IN ('Match', 'Friendly') OR EXISTS (SELECT 1 FROM public.match_stats ms WHERE ms.event_id = e.event_id)))
             -- live now, or finished in the last 12 hours (shown under Results)
             OR EXISTS (SELECT 1 FROM public.match_timer mt
                         WHERE mt.event_id = e.event_id
                           AND mt.kicked_off_at > now() - interval '12 hours')
             -- upcoming matches I follow (next 14 days)
             OR (e.event_id IN (SELECT f.event_id FROM public.live_follows f WHERE f.user_id = v_uid AND f.level <> 'off')
                 AND e.event_date_time BETWEEN now() - interval '1 day' AND now() + interval '14 days')
           )
      )
      SELECT jsonb_agg(jsonb_build_object(
               'event_id',        e.event_id,
               'event_date_time', e.event_date_time,
               'team_name',       t.team_name,
               'club_name',       c.club_name,
               'opposition',      COALESCE(NULLIF(ms.opposition, ''), NULLIF(mt.opposition, ''), e.opposition),
               'home_away',       e.home_away,
               'phase',           public.lm_phase(cand.sid),
               'timer', CASE WHEN mt.id IS NULL THEN NULL ELSE jsonb_build_object(
                   'status', mt.status, 'started_at', mt.started_at + make_interval(secs => COALESCE(mt.clock_offset_ms, 0) / 1000.0), 'elapsed_seconds', mt.elapsed_seconds,
                   'current_half', mt.current_half, 'duration_seconds', mt.duration_seconds) END,
               'score',  CASE WHEN cand.sid IS NULL THEN NULL ELSE public.lm_score(cand.sid) END,
               'follow', public.lm_my_follow(e.event_id)
             ) ORDER BY e.event_date_time)
        FROM cand
        JOIN public.events e ON e.event_id = cand.event_id
        LEFT JOIN public.teams t ON t.team_id = e.team_id
        LEFT JOIN public.clubs c ON c.club_id = t.club_id
        LEFT JOIN public.match_stats ms ON ms.id = cand.sid
        LEFT JOIN public.match_timer mt ON mt.event_id = e.event_id AND mt.user_id = ms.user_id
    ), '[]'::jsonb)
  );
END;
$$;
REVOKE ALL ON FUNCTION public.get_live_matches() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_live_matches() TO authenticated;
