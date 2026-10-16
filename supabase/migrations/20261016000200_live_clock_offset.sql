-- Live match clock: the live screen ran behind the score keeper when the
-- scorer's phone clock was ahead of real time (the phone sends its own start
-- time). The score keeper now also sends its clock reading ("client_now"), the
-- server stores the difference, and the live screen gets a start time on the
-- server's clock. The score keeper itself keeps using its own start time.
-- Phones still on the old page send no client_now, so nothing changes for them.

ALTER TABLE public.match_timer ADD COLUMN IF NOT EXISTS clock_offset_ms int;

-- sync_match_actions: same as 20261016000100, plus clock_offset_ms
CREATE OR REPLACE FUNCTION public.sync_match_actions(
  p_match_stats_id bigint,
  p_actions        jsonb,
  p_timer          jsonb DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = 'public'
AS $$
DECLARE
  v_uid     uuid := auth.uid();
  v_event   bigint;
  v_team    bigint;
  a         jsonb;
  v_id      uuid;
  v_target  uuid;
  v_row     bigint;
  v_member  bigint;
  v_done    jsonb := '[]'::jsonb;
BEGIN
  SELECT ms.event_id, e.team_id INTO v_event, v_team
    FROM public.match_stats ms
    JOIN public.events e ON e.event_id = ms.event_id
   WHERE ms.id = p_match_stats_id AND ms.user_id = v_uid;
  IF v_event IS NULL THEN
    RAISE EXCEPTION 'Unauthorized' USING ERRCODE = '42501';
  END IF;

  FOR a IN SELECT * FROM jsonb_array_elements(COALESCE(p_actions, '[]'::jsonb)) LOOP
    v_id := (a->>'id')::uuid;
    v_target := CASE WHEN a->>'target' ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
                     THEN (a->>'target')::uuid END;
    v_row    := CASE WHEN a->>'target' ~ '^srv-[0-9]+$' THEN substring(a->>'target' FROM 5)::bigint END;

    v_member := NULLIF(a->>'member_id', '')::bigint;
    IF v_member IS NOT NULL AND NOT EXISTS (
      SELECT 1 FROM public.member_team_link mtl
       WHERE mtl.member_id = v_member AND mtl.team_id = v_team
    ) THEN
      v_member := NULL;
    END IF;

    CASE a->>'type'
      WHEN 'score', 'correction' THEN
        INSERT INTO public.match_stats_details (
          match_stats_id, score_type, side, count, event_second, timer_status, half,
          client_id, member_id, kind
        ) VALUES (
          p_match_stats_id,
          (a->>'score_type')::bigint,
          a->>'side',
          CASE WHEN a->>'type' = 'correction' THEN COALESCE((a->>'count')::smallint, 0) ELSE 1 END,
          LEAST(GREATEST(COALESCE((a->>'second')::int, 0), 0), 32767)::smallint,
          CASE WHEN a->>'timer_status' IN ('running', 'paused', 'stopped') THEN a->>'timer_status' ELSE 'paused' END,
          COALESCE((a->>'half')::int, 1),
          v_id,
          v_member,
          a->>'type'
        )
        ON CONFLICT (client_id) DO NOTHING;

      WHEN 'edit' THEN
        UPDATE public.match_stats_details d
           SET score_type = COALESCE((a->>'score_type')::bigint, d.score_type),
               side       = COALESCE(a->>'side', d.side),
               member_id  = CASE WHEN a ? 'member_id' THEN v_member ELSE d.member_id END
         WHERE d.match_stats_id = p_match_stats_id AND (d.client_id = v_target OR d.id = v_row);

      WHEN 'remove' THEN
        DELETE FROM public.match_stats_details d
         WHERE d.match_stats_id = p_match_stats_id AND (d.client_id = v_target OR d.id = v_row);

      WHEN 'sub' THEN
        INSERT INTO public.match_subs (match_stats_id, client_id, half, event_second, member_off, member_on)
        VALUES (
          p_match_stats_id, v_id,
          COALESCE((a->>'half')::int, 1),
          GREATEST(COALESCE((a->>'second')::int, 0), 0),
          (SELECT mtl.member_id FROM public.member_team_link mtl
            WHERE mtl.member_id = NULLIF(a->>'member_off', '')::bigint AND mtl.team_id = v_team LIMIT 1),
          (SELECT mtl.member_id FROM public.member_team_link mtl
            WHERE mtl.member_id = NULLIF(a->>'member_on', '')::bigint AND mtl.team_id = v_team LIMIT 1)
        )
        ON CONFLICT (client_id) DO NOTHING;

      WHEN 'remove_sub' THEN
        DELETE FROM public.match_subs s
         WHERE s.match_stats_id = p_match_stats_id AND (s.client_id = v_target OR s.id = v_row);

      ELSE
        NULL;
    END CASE;

    v_done := v_done || to_jsonb(v_id::text);
  END LOOP;

  IF p_timer IS NOT NULL THEN
    UPDATE public.match_timer mt
       SET status           = CASE WHEN p_timer->>'status' IN ('running', 'paused') THEN p_timer->>'status' ELSE mt.status END,
           started_at       = NULLIF(p_timer->>'started_at', '')::timestamptz,
           elapsed_seconds  = COALESCE((p_timer->>'elapsed_seconds')::int, mt.elapsed_seconds),
           current_half     = COALESCE((p_timer->>'current_half')::int, mt.current_half),
           duration_seconds = COALESCE((p_timer->>'duration_seconds')::int, mt.duration_seconds),
           injury_seconds   = COALESCE((p_timer->>'injury_seconds')::int, mt.injury_seconds),
           phase            = CASE WHEN p_timer->>'phase' IN ('setup', 'play', 'ht', 'ft', 'done')
                                   THEN p_timer->>'phase' ELSE mt.phase END,
           clock_offset_ms  = CASE WHEN COALESCE(p_timer->>'client_now', '') <> ''
                                   THEN round(extract(epoch FROM now() - (p_timer->>'client_now')::timestamptz) * 1000)::int
                                   ELSE mt.clock_offset_ms END,
           updated_at       = now()
     WHERE mt.event_id = v_event AND mt.user_id = v_uid;
  END IF;

  RETURN jsonb_build_object('done', v_done);
END;
$$;
REVOKE ALL ON FUNCTION public.sync_match_actions(bigint, jsonb, jsonb) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.sync_match_actions(bigint, jsonb, jsonb) TO authenticated;

-- lm_state / get_live_matches: same as 20261016000100, with the start time on the server's clock
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
        'event_date_time',  e.event_date_time,
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
             ((e.event_date_time AT TIME ZONE 'Europe/Dublin')::date = v_today
               AND (et.event_type IN ('Match', 'Friendly') OR EXISTS (SELECT 1 FROM public.match_stats ms WHERE ms.event_id = e.event_id)))
             -- live now
             OR EXISTS (SELECT 1 FROM public.match_timer mt
                         WHERE mt.event_id = e.event_id AND mt.updated_at > now() - interval '8 hours'
                           AND (mt.status = 'running' OR mt.phase IN ('play', 'ht')))
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
