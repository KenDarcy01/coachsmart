-- Live match: show throw-in times in local time
--
-- Ken (2026-10-18): throw-in times on the Matches list were an hour late.
-- The app saves events.event_date_time as the local clock time with a UTC
-- label (the app's own RPCs print it with ::timestamp), so 11:00 is stored
-- as 11:00+00. The live pages read it as a real instant and showed 12:00
-- during Irish summer time. lm_event_at turns the stored value into the real
-- moment (11:00 Irish time), which the live pages and countdowns expect.

CREATE OR REPLACE FUNCTION public.lm_event_at(p_at timestamptz)
RETURNS timestamptz
LANGUAGE sql
IMMUTABLE
SET search_path = 'public'
AS $$ SELECT (p_at AT TIME ZONE 'UTC') AT TIME ZONE 'Europe/Dublin' $$;

CREATE OR REPLACE FUNCTION public.lm_state(p_event_id bigint, p_names boolean)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = 'public'
AS $$
DECLARE
  v_sid  bigint := public.lm_session_id(p_event_id);
  v_ms   public.match_stats%ROWTYPE;
  v_team bigint;
BEGIN
  SELECT * INTO v_ms FROM public.match_stats WHERE id = v_sid;
  SELECT team_id INTO v_team FROM public.events WHERE event_id = p_event_id;

  RETURN jsonb_build_object(
    'server_now', now(),
    'phase',      public.lm_phase(v_sid),
    'event', (
      SELECT jsonb_build_object(
        'event_id',         e.event_id,
        'event_date_time',  public.lm_event_at(e.event_date_time),
        'event_title',      e.event_title,
        'opposition',       COALESCE(NULLIF(v_ms.opposition, ''), NULLIF(mt.opposition, ''), e.opposition),
        'home_away',        e.home_away,
        'location_name',    e.location_name,
        'team_id',          e.team_id,
        'team_name',        t.team_name,
        'club_name',        c.club_name,
        'crest',            c.crest,
        'primary_colour',   c.primary_colour,
        'secondary_colour', c.secondary_colour,
        'event_code',       ec.event_code,
        'event_type',       et.event_type
      )
      FROM public.events e
      LEFT JOIN public.teams t        ON t.team_id = e.team_id
      LEFT JOIN public.clubs c        ON c.club_id = t.club_id
      LEFT JOIN public.event_codes ec ON ec.code_id = e.event_code_id
      LEFT JOIN public.event_types et ON et.event_type_id = e.event_type_id
      LEFT JOIN public.match_timer mt ON mt.event_id = e.event_id AND mt.user_id = v_ms.user_id
      WHERE e.event_id = p_event_id
    ),
    'timer', (
      SELECT jsonb_build_object(
        'status',           mt.status,
        'started_at',       mt.started_at + make_interval(secs => COALESCE(mt.clock_offset_ms, 0) / 1000.0),
        'elapsed_seconds',  mt.elapsed_seconds,
        'current_half',     mt.current_half,
        'duration_seconds', mt.duration_seconds,
        'injury_seconds',   mt.injury_seconds
      )
      FROM public.match_timer mt
      WHERE mt.event_id = p_event_id AND mt.user_id = v_ms.user_id
    ),
    'score', public.lm_score(v_sid),
    'score_types', COALESCE((
      SELECT jsonb_agg(jsonb_build_object('id', mst.id, 'name', mst.score_type, 'value', mst.score_value))
        FROM public.match_stat_types mst
       WHERE mst.id IN (SELECT DISTINCT d.score_type FROM public.match_stats_details d WHERE d.match_stats_id = v_sid)
    ), '[]'::jsonb),
    'actions', COALESCE((
      SELECT jsonb_agg(jsonb_build_object(
               'id',     d.id,
               'type',   d.score_type,
               'side',   d.side,
               'kind',   d.kind,
               'count',  COALESCE(d.count, 1),
               'half',   d.half,
               'second', d.event_second,
               'member', CASE WHEN p_names AND d.side = 'us' THEN NULLIF(TRIM(CONCAT(m.first_name, ' ', m.last_name)), '') END
             ) ORDER BY d.half, d.event_second, d.created_at)
        FROM public.match_stats_details d
        LEFT JOIN public.members m ON m.member_id = d.member_id
       WHERE d.match_stats_id = v_sid
    ), '[]'::jsonb),
    'subs', CASE WHEN NOT p_names THEN '[]'::jsonb ELSE COALESCE((
      SELECT jsonb_agg(jsonb_build_object(
               'half',   s.half,
               'second', s.event_second,
               'off',    NULLIF(TRIM(CONCAT(moff.first_name, ' ', moff.last_name)), ''),
               'on',     NULLIF(TRIM(CONCAT(mon.first_name, ' ', mon.last_name)), '')
             ) ORDER BY s.half, s.event_second, s.created_at)
        FROM public.match_subs s
        LEFT JOIN public.members moff ON moff.member_id = s.member_off
        LEFT JOIN public.members mon  ON mon.member_id  = s.member_on
       WHERE s.match_stats_id = v_sid
    ), '[]'::jsonb) END
  );
END;
$$;
REVOKE ALL ON FUNCTION public.lm_state(bigint, boolean) FROM PUBLIC, anon, authenticated;

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
      )
      SELECT jsonb_agg(jsonb_build_object(
               'event_id',        e.event_id,
               'event_date_time', public.lm_event_at(e.event_date_time),
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
