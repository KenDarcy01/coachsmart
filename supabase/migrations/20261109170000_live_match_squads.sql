-- Live match: one event, several squads (Ken, 2026-11-09)
--
-- Until now the live page, share link, Matches list and alerts worked per
-- event: when two squads of a team played under one event (a blitz, or A and
-- B games at different times and places), followers only saw whichever scorer
-- started the clock first and the other squad's game was invisible.
--
-- Now every scorer session belongs to a group: its squad (picked in the score
-- keeper's setup). A session with no squad joins the only squad being scored,
-- or the squad playing the same opposition, else the "whole team" group (0).
-- Each group has its own shown scorer, alerts, score and clock. The live page
-- gets a summary of every group for its Both / squad tabs.
--
-- Also: half time no longer counts as "inactive", so a half-time break longer
-- than 10 minutes can't hand the match to a backup scorer and back again. And
-- when nobody is actively scoring, a saved (finalised) match beats a backup
-- scorer's idle record.
--
-- Optional per-squad throw-in time and venue, set in the score keeper's setup
-- (match_timer.throw_in_at / venue); otherwise the event's own time and place.

ALTER TABLE public.match_timer ADD COLUMN IF NOT EXISTS throw_in_at timestamptz;
ALTER TABLE public.match_timer ADD COLUMN IF NOT EXISTS venue text;

-- ── Every scorer session for an event, with its group ──────────────────────────
CREATE OR REPLACE FUNCTION public.lm_sessions(p_event_id bigint)
RETURNS TABLE(sid bigint, gkey bigint, status text, kicked_off_at timestamptz, created_at timestamptz,
              last_at timestamptz, on_now boolean, used boolean)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = 'public'
AS $$
  WITH s AS (
    SELECT ms.id, ms.status, ms.created_at, mt.kicked_off_at, mt.phase, mt.status AS tstatus,
           mt.current_half, mt.elapsed_seconds,
           COALESCE(ms.squad_id, mt.squad_id) AS squad,
           lower(btrim(COALESCE(NULLIF(ms.opposition, ''), mt.opposition, ''))) AS opp,
           GREATEST(mt.updated_at,
                    (SELECT max(d.created_at) FROM public.match_stats_details d WHERE d.match_stats_id = ms.id),
                    ms.created_at) AS last_at,
           EXISTS (SELECT 1 FROM public.match_stats_details d WHERE d.match_stats_id = ms.id) AS has_actions
      FROM public.match_stats ms
      LEFT JOIN public.match_timer mt ON mt.event_id = ms.event_id AND mt.user_id = ms.user_id
     WHERE ms.event_id = p_event_id AND ms.status IN ('active', 'finalised')
  ),
  sq AS (SELECT DISTINCT squad, opp FROM s WHERE squad IS NOT NULL)
  SELECT s.id,
         COALESCE(s.squad,
                  CASE WHEN (SELECT count(DISTINCT squad) FROM sq) = 1 THEN (SELECT min(squad) FROM sq) END,
                  (SELECT min(sq.squad) FROM sq WHERE sq.opp = s.opp AND s.opp <> ''),
                  0),
         s.status, s.kicked_off_at, s.created_at, s.last_at,
         -- still scoring: did something in the last 10 minutes, or is at half
         -- time (or paused in the first half) and did something in the last 25
         s.status = 'active' AND (
           s.last_at > now() - interval '10 minutes'
           OR ((s.phase = 'ht' OR (COALESCE(s.current_half, 1) = 1 AND s.tstatus IS DISTINCT FROM 'running' AND COALESCE(s.elapsed_seconds, 0) > 0))
               AND s.last_at > now() - interval '25 minutes')
         ),
         s.kicked_off_at IS NOT NULL OR s.has_actions OR s.status = 'finalised'
    FROM s;
$$;
REVOKE ALL ON FUNCTION public.lm_sessions(bigint) FROM PUBLIC, anon, authenticated;

-- The session followers see for one group of an event
CREATE OR REPLACE FUNCTION public.lm_session_id(p_event_id bigint, p_key bigint)
RETURNS bigint
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = 'public'
AS $$
  SELECT sid FROM public.lm_sessions(p_event_id)
   WHERE gkey = p_key
   ORDER BY on_now DESC,
            -- among scorers still going: first to start the clock, then first to open
            CASE WHEN on_now THEN kicked_off_at END ASC NULLS LAST,
            CASE WHEN on_now THEN created_at END ASC NULLS LAST,
            -- nobody scoring: a saved match, then whoever did most recently
            (status = 'finalised') DESC,
            used DESC,
            last_at DESC NULLS LAST,
            sid DESC
   LIMIT 1;
$$;
REVOKE ALL ON FUNCTION public.lm_session_id(bigint, bigint) FROM PUBLIC, anon, authenticated;

CREATE OR REPLACE FUNCTION public.lm_group_of(p_match_stats_id bigint)
RETURNS bigint
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = 'public'
AS $$
  SELECT x.gkey FROM public.match_stats ms
   CROSS JOIN LATERAL public.lm_sessions(ms.event_id) x
   WHERE ms.id = p_match_stats_id AND x.sid = ms.id;
$$;
REVOKE ALL ON FUNCTION public.lm_group_of(bigint) FROM PUBLIC, anon, authenticated;

-- ── The groups worth showing, with a summary of each ───────────────────────────
-- A group shows once its scorer has opened the match (so a squad that hasn't
-- started yet appears with its throw-in time). A "whole team" group that never
-- started is hidden when squads are being scored, and an unstarted group is
-- dropped 12 hours after it was opened. Sorted in the squads' own order.
CREATE OR REPLACE FUNCTION public.lm_groups(p_event_id bigint)
RETURNS TABLE(gkey bigint, sid bigint, summary jsonb)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = 'public'
AS $$
  WITH g AS (
    SELECT x.gkey, bool_or(x.used) AS used, max(x.created_at) AS opened
      FROM public.lm_sessions(p_event_id) x
     GROUP BY x.gkey
  ),
  vis AS (
    SELECT g.gkey, public.lm_session_id(p_event_id, g.gkey) AS sid
      FROM g
     WHERE g.used
        OR (g.opened > now() - interval '12 hours'
            AND NOT (g.gkey = 0 AND EXISTS (SELECT 1 FROM g g2 WHERE g2.gkey <> 0)))
  )
  SELECT vis.gkey, vis.sid,
         jsonb_build_object(
           'key',           vis.gkey,
           'squad_id',      NULLIF(vis.gkey, 0),
           'name',          COALESCE(sq.squad_name, 'Team'),
           'colour',        NULLIF(btrim(sq.squad_colour), ''),
           'phase',         public.lm_phase(vis.sid),
           'score',         public.lm_score(vis.sid),
           'opposition',    COALESCE(NULLIF(ms.opposition, ''), NULLIF(mt.opposition, ''), e.opposition),
           'venue',         COALESCE(NULLIF(btrim(mt.venue), ''), e.location_name),
           'throw_in_at',   COALESCE(mt.throw_in_at, public.lm_event_at(e.event_date_time)),
           'own_time',      mt.throw_in_at IS NOT NULL,
           'kicked_off_at', mt.kicked_off_at,
           'timer', CASE WHEN mt.id IS NULL THEN NULL ELSE jsonb_build_object(
               'status', mt.status,
               'started_at', mt.started_at + make_interval(secs => COALESCE(mt.clock_offset_ms, 0) / 1000.0),
               'elapsed_seconds', mt.elapsed_seconds, 'current_half', mt.current_half,
               'duration_seconds', mt.duration_seconds, 'injury_seconds', mt.injury_seconds) END,
           'last', (
             SELECT jsonb_build_object('type', mst.score_type, 'value', mst.score_value, 'side', d.side,
                                       'half', d.half, 'second', d.event_second)
               FROM public.match_stats_details d
               JOIN public.match_stat_types mst ON mst.id = d.score_type
              WHERE d.match_stats_id = vis.sid AND d.kind = 'score' AND mst.score_value > 0
              ORDER BY d.half DESC, d.event_second DESC, d.created_at DESC
              LIMIT 1)
         )
    FROM vis
    JOIN public.events e ON e.event_id = p_event_id
    LEFT JOIN public.squads sq ON sq.squad_id = NULLIF(vis.gkey, 0)
    LEFT JOIN public.match_stats ms ON ms.id = vis.sid
    LEFT JOIN public.match_timer mt ON mt.event_id = ms.event_id AND mt.user_id = ms.user_id
   ORDER BY (vis.gkey = 0), sq.squad_list_seq NULLS LAST, sq.squad_name, vis.gkey;
$$;
REVOKE ALL ON FUNCTION public.lm_groups(bigint) FROM PUBLIC, anon, authenticated;

-- The group to open when none is picked: live first, then the next to start,
-- then the most recent result
CREATE OR REPLACE FUNCTION public.lm_default_group(p_event_id bigint)
RETURNS bigint
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = 'public'
AS $$
  SELECT gkey FROM public.lm_groups(p_event_id)
   ORDER BY CASE summary->>'phase' WHEN 'play' THEN 0 WHEN 'ht' THEN 0 WHEN 'pre' THEN 1 ELSE 2 END,
            CASE WHEN summary->>'phase' IN ('play', 'ht') THEN (summary->>'kicked_off_at')::timestamptz END ASC,
            CASE WHEN summary->>'phase' = 'pre' THEN (summary->>'throw_in_at')::timestamptz END ASC,
            CASE WHEN summary->>'phase' NOT IN ('play', 'ht', 'pre') THEN (summary->>'kicked_off_at')::timestamptz END DESC NULLS LAST
   LIMIT 1;
$$;
REVOKE ALL ON FUNCTION public.lm_default_group(bigint) FROM PUBLIC, anon, authenticated;

-- Old one-argument form (used by lm_alert_probe): the default group's session
CREATE OR REPLACE FUNCTION public.lm_session_id(p_event_id bigint)
RETURNS bigint
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = 'public'
AS $$
  SELECT public.lm_session_id(p_event_id, COALESCE(public.lm_default_group(p_event_id), 0));
$$;
REVOKE ALL ON FUNCTION public.lm_session_id(bigint) FROM PUBLIC, anon, authenticated;

-- ── State of one group (plus every group's summary) ───────────────────────────
CREATE OR REPLACE FUNCTION public.lm_state(p_event_id bigint, p_names boolean, p_key bigint)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = 'public'
AS $$
DECLARE
  v_groups jsonb;
  v_key    bigint;
  v_sid    bigint;
  v_sum    jsonb;
  v_ms     public.match_stats%ROWTYPE;
BEGIN
  SELECT COALESCE(jsonb_agg(summary), '[]'::jsonb) INTO v_groups FROM public.lm_groups(p_event_id);
  v_key := p_key;
  IF v_key IS NULL OR NOT EXISTS (SELECT 1 FROM jsonb_array_elements(v_groups) x WHERE (x->>'key')::bigint = v_key) THEN
    v_key := public.lm_default_group(p_event_id);
  END IF;
  IF v_key IS NOT NULL THEN
    v_sid := public.lm_session_id(p_event_id, v_key);
    SELECT x INTO v_sum FROM jsonb_array_elements(v_groups) x WHERE (x->>'key')::bigint = v_key LIMIT 1;
  END IF;
  SELECT * INTO v_ms FROM public.match_stats WHERE id = v_sid;

  RETURN jsonb_build_object(
    'server_now', now(),
    'phase',      public.lm_phase(v_sid),
    'squad',      v_sum,
    'squads',     v_groups,
    'event', (
      SELECT jsonb_build_object(
        'event_id',         e.event_id,
        -- this squad's own throw-in time and venue when the scorer set them
        'event_date_time',  COALESCE(mt.throw_in_at, public.lm_event_at(e.event_date_time)),
        'event_start',      public.lm_event_at(e.event_date_time),
        'event_title',      e.event_title,
        'opposition',       COALESCE(NULLIF(v_ms.opposition, ''), NULLIF(mt.opposition, ''), e.opposition),
        'home_away',        e.home_away,
        'location_name',    COALESCE(NULLIF(btrim(mt.venue), ''), e.location_name),
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
REVOKE ALL ON FUNCTION public.lm_state(bigint, boolean, bigint) FROM PUBLIC, anon, authenticated;

-- Old two-argument form: the default group
CREATE OR REPLACE FUNCTION public.lm_state(p_event_id bigint, p_names boolean)
RETURNS jsonb
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = 'public'
AS $$ SELECT public.lm_state(p_event_id, p_names, NULL::bigint); $$;
REVOKE ALL ON FUNCTION public.lm_state(bigint, boolean) FROM PUBLIC, anon, authenticated;

-- ── Page calls with a squad ────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.get_live_match_v2(p_event_id bigint, p_squad bigint DEFAULT NULL)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = 'public'
AS $$
BEGIN
  IF auth.uid() IS NULL THEN RETURN jsonb_build_object('error', 'not_signed_in'); END IF;
  IF NOT public.lm_can_view(p_event_id) THEN RETURN jsonb_build_object('error', 'not_allowed'); END IF;
  RETURN public.lm_state(p_event_id, true, p_squad)
    || jsonb_build_object('follow', public.lm_my_follow(p_event_id),
                          'pulse', (SELECT ver FROM public.live_pulse WHERE event_id = p_event_id));
END;
$$;
REVOKE ALL ON FUNCTION public.get_live_match_v2(bigint, bigint) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_live_match_v2(bigint, bigint) TO authenticated;

CREATE OR REPLACE FUNCTION public.get_live_match_public_v2(p_token uuid, p_squad bigint DEFAULT NULL)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = 'public'
AS $$
DECLARE
  v_event bigint;
BEGIN
  SELECT l.event_id INTO v_event FROM public.live_links l WHERE l.token = p_token;
  IF v_event IS NULL THEN RETURN jsonb_build_object('error', 'link_not_found'); END IF;
  RETURN public.lm_state(v_event, false, p_squad)
    || jsonb_build_object('public', true, 'pulse', (SELECT ver FROM public.live_pulse WHERE event_id = v_event));
END;
$$;
REVOKE ALL ON FUNCTION public.get_live_match_public_v2(uuid, bigint) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_live_match_public_v2(uuid, bigint) TO anon, authenticated;

-- ── Matches list: one row per squad playing ────────────────────────────────────
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
$$;

-- ── Alerts: one shown scorer per squad ─────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.lm_alert_claim(p_match_stats_id bigint, p_settle integer DEFAULT 8)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = 'public'
AS $$
DECLARE
  v_log    public.live_alert_log%ROWTYPE;
  v_ms     public.match_stats%ROWTYPE;
  v_phase  text;
  v_new    jsonb;
  v_max    bigint;
  v_more   boolean;
  v_phases text[] := '{}';
  v_mt     public.match_timer%ROWTYPE;
  v_key    bigint;
BEGIN
  SELECT * INTO v_ms FROM public.match_stats WHERE id = p_match_stats_id;
  IF v_ms.id IS NULL THEN RETURN jsonb_build_object('items', '[]'::jsonb, 'phases', '[]'::jsonb, 'more', false); END IF;
  v_key := COALESCE(public.lm_group_of(p_match_stats_id), 0);

  INSERT INTO public.live_alert_log (match_stats_id) VALUES (p_match_stats_id) ON CONFLICT DO NOTHING;
  SELECT * INTO v_log FROM public.live_alert_log WHERE match_stats_id = p_match_stats_id FOR UPDATE;

  -- Only the session followers see for this squad sends alerts. Another
  -- scorer's session is marked as sent up to now, so it never alerts its
  -- backlog if it later becomes the one followers see.
  IF public.lm_session_id(v_ms.event_id, v_key) IS DISTINCT FROM p_match_stats_id THEN
    v_phase := public.lm_phase(p_match_stats_id);
    SELECT * INTO v_mt FROM public.match_timer mt WHERE mt.event_id = v_ms.event_id AND mt.user_id = v_ms.user_id;
    UPDATE public.live_alert_log
       SET last_detail_id = GREATEST(last_detail_id, COALESCE((SELECT max(d.id) FROM public.match_stats_details d WHERE d.match_stats_id = p_match_stats_id), 0)),
           phases = phases
             || CASE WHEN v_phase IN ('play', 'ht', 'ft', 'done') THEN ARRAY['ko-x'] ELSE '{}'::text[] END
             || CASE WHEN v_phase IN ('ht', 'ft', 'done') OR COALESCE(v_mt.current_half, 1) >= 2 THEN ARRAY['ht-x'] ELSE '{}'::text[] END
             || CASE WHEN v_phase IN ('ft', 'done') OR (v_phase = 'play' AND COALESCE(v_mt.current_half, 1) >= 2) THEN ARRAY['h2-x'] ELSE '{}'::text[] END
             || CASE WHEN v_phase IN ('ft', 'done') THEN ARRAY['ft-x'] ELSE '{}'::text[] END,
           pending_since = NULL,
           updated_at = now()
     WHERE match_stats_id = p_match_stats_id;
    RETURN jsonb_build_object('items', '[]'::jsonb, 'phases', '[]'::jsonb, 'more', false, 'not_shown', true);
  END IF;

  -- What counts as done: this session's own record ('ko-x' etc. mark phases
  -- passed while another scorer was the one shown), plus throw-in, half time
  -- or full time another scorer's session of the SAME squad really sent, so a
  -- hand-over never repeats them. Only other people's sessions count: this
  -- scorer's own earlier records (reset, or a new record started) are a
  -- different match.
  v_log.phases := ARRAY(
    SELECT DISTINCT replace(x, '-x', '') FROM unnest(v_log.phases) x
    UNION
    SELECT x FROM public.live_alert_log a
      JOIN public.match_stats ms2 ON ms2.id = a.match_stats_id AND ms2.event_id = v_ms.event_id
      CROSS JOIN LATERAL unnest(a.phases) x
     WHERE a.match_stats_id <> p_match_stats_id AND x NOT LIKE '%-x'
       AND ms2.user_id IS DISTINCT FROM v_ms.user_id AND ms2.status <> 'reset'
       AND COALESCE(public.lm_group_of(ms2.id), 0) = v_key);

  SELECT COALESCE(jsonb_agg(jsonb_build_object(
           'id', d.id, 'type', mst.score_type, 'value', mst.score_value, 'side', d.side,
           'half', d.half, 'second', d.event_second,
           'member', NULLIF(TRIM(CONCAT(m.first_name, ' ', m.last_name)), '')
         ) ORDER BY d.id), '[]'::jsonb),
         max(d.id)
    INTO v_new, v_max
    FROM public.match_stats_details d
    JOIN public.match_stat_types mst ON mst.id = d.score_type
    LEFT JOIN public.members m ON m.member_id = d.member_id
   WHERE d.match_stats_id = p_match_stats_id
     AND d.id > v_log.last_detail_id
     AND d.kind = 'score'
     AND mst.score_value IS NOT NULL AND mst.score_value > 0
     AND d.created_at <= now() - make_interval(secs => p_settle);

  v_more := EXISTS (
    SELECT 1 FROM public.match_stats_details d
     WHERE d.match_stats_id = p_match_stats_id AND d.id > GREATEST(v_log.last_detail_id, COALESCE(v_max, 0))
       AND d.kind = 'score' AND d.created_at > now() - make_interval(secs => p_settle)
  );

  -- Phases: kick-off once the first half is under way, then HT and FT
  v_phase := public.lm_phase(p_match_stats_id);
  SELECT * INTO v_mt FROM public.match_timer mt WHERE mt.event_id = v_ms.event_id AND mt.user_id = v_ms.user_id;
  IF NOT ('ko' = ANY (v_log.phases)) AND (v_phase IN ('play', 'ht', 'ft', 'done')) THEN v_phases := v_phases || 'ko'::text; END IF;
  IF NOT ('ht' = ANY (v_log.phases)) AND (v_phase = 'ht' OR (v_phase IN ('play', 'ft', 'done') AND COALESCE(v_mt.current_half, 1) >= 2)) THEN
    -- Only alert half time while it is half time; a missed one is just marked done
    v_phases := v_phases || CASE WHEN v_phase = 'ht' THEN 'ht' ELSE 'ht-skip' END;
  END IF;
  -- Second half under way (marked done without an alert once it's over)
  IF NOT ('h2' = ANY (v_log.phases)) AND (v_phase IN ('ft', 'done') OR (v_phase = 'play' AND COALESCE(v_mt.current_half, 1) >= 2)) THEN
    v_phases := v_phases || CASE WHEN v_phase = 'play' THEN 'h2' ELSE 'h2-skip' END;
  END IF;
  IF NOT ('ft' = ANY (v_log.phases)) AND v_phase IN ('ft', 'done') THEN v_phases := v_phases || 'ft'::text; END IF;
  -- Half time / full time wait until the last scores have settled, so the
  -- result alert carries the final score and comes after them
  IF v_more THEN
    v_phases := array_remove(array_remove(v_phases, 'ht'), 'ft');
  END IF;
  -- A kick-off alert after the match is well under way is no use
  IF 'ko' = ANY (v_phases) AND (v_phase <> 'play' OR COALESCE(v_mt.current_half, 1) > 1) THEN
    v_phases := array_replace(v_phases, 'ko', 'ko-skip');
  END IF;

  UPDATE public.live_alert_log
     SET last_detail_id = GREATEST(last_detail_id, COALESCE(v_max, 0)),
         phases         = v_log.phases || array_replace(array_replace(array_replace(v_phases, 'ht-skip', 'ht'), 'ko-skip', 'ko'), 'h2-skip', 'h2'),
         pending_since  = CASE WHEN v_more THEN pending_since ELSE NULL END,
         updated_at     = now()
   WHERE match_stats_id = p_match_stats_id;

  RETURN jsonb_build_object(
    'event_id', v_ms.event_id,
    'scorer',   v_ms.user_id,
    'phase',    v_phase,
    'items',    v_new,
    'phases',   to_jsonb(array_remove(array_remove(array_remove(v_phases, 'ht-skip'), 'ko-skip'), 'h2-skip')),
    'more',     v_more,
    'state',    public.lm_state(v_ms.event_id, true, v_key)
  );
END;
$$;
