-- Multi-sport step 7: get_live_matches adds each match's club sport
-- ("sport": 1 GAA, 2 Soccer, 3 Rugby) so v3 says "Kick-off" and offers the
-- right alert choices before a soccer or rugby match starts. Add-only: one
-- new key; v2's matches webview ignores it. Everything else as live.
CREATE OR REPLACE FUNCTION public.get_live_matches()
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
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
        SELECT e.event_id
          FROM public.events e
          JOIN public.teams t ON t.team_id = e.team_id
          LEFT JOIN public.event_types et ON et.event_type_id = e.event_type_id
         WHERE t.club_id IN (SELECT club_id FROM my_clubs)
           AND COALESCE(e.status, 'active') = 'active'
           AND (
             -- today's matches
             ((e.event_date_time AT TIME ZONE 'UTC')::date = v_today
               AND (et.event_type IN ('Match', 'Friendly') OR EXISTS (SELECT 1 FROM public.match_stats ms WHERE ms.event_id = e.event_id)))
             -- live now, or finished in the last 12 hours (shown under Results)
             OR EXISTS (SELECT 1 FROM public.match_timer mt
                         WHERE mt.event_id = e.event_id
                           AND mt.kicked_off_at > now() - interval '12 hours')
             -- upcoming matches I follow (next 14 days)
             OR (e.event_id IN (SELECT f.event_id FROM public.live_follows f WHERE f.user_id = v_uid AND f.level <> 'off')
                 AND public.lm_event_at(e.event_date_time) BETWEEN now() - interval '1 day' AND now() + interval '14 days')
           )
      ),
      rows AS (
        SELECT cand.event_id, g.gkey, g.sid, g.summary, g.ord,
               count(g.gkey) OVER (PARTITION BY cand.event_id) AS n_groups
          FROM cand
          LEFT JOIN LATERAL (
            SELECT x.gkey, x.sid, x.summary, row_number() OVER () AS ord FROM public.lm_groups(cand.event_id) x
          ) g ON true
      )
      SELECT jsonb_agg(jsonb_build_object(
               'event_id',        e.event_id,
               'squad_key',       r.gkey,
               'squad_name',      CASE WHEN r.n_groups > 1 OR r.gkey > 0 THEN r.summary->>'name' END,
               'squad_colour',    r.summary->>'colour',
               'squads_in_event', r.n_groups,
               'event_date_time', COALESCE((r.summary->>'throw_in_at')::timestamptz, public.lm_event_at(e.event_date_time)),
               'team_name',       t.team_name,
               'club_name',       c.club_name,
               'sport',           COALESCE(c.sport_id, 1),
               'opposition',      COALESCE(r.summary->>'opposition', e.opposition),
               'venue',           COALESCE(r.summary->>'venue', e.location_name),
               'home_away',       e.home_away,
               'phase',           public.lm_phase(r.sid),
               'timer',           r.summary->'timer',
               'score',           CASE WHEN r.sid IS NULL THEN NULL ELSE r.summary->'score' END,
               'follow',          public.lm_my_follow(e.event_id)
             ) ORDER BY e.event_date_time, e.event_id, r.ord)
        FROM rows r
        JOIN public.events e ON e.event_id = r.event_id
        LEFT JOIN public.teams t ON t.team_id = e.team_id
        LEFT JOIN public.clubs c ON c.club_id = t.club_id
    ), '[]'::jsonb)
  );
END;
$function$;
