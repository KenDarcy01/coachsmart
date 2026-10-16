-- Live match: throw-in, half time, second half and full time alerts
--
-- Ken (2026-10-16): in a test only the scores came through; throw-in, half
-- time and full time never did. Two causes, both after a scorer resets the
-- match or starts a new record (which makes a new scoring session):
--  * the new session treated the old session's throw-in / half time / full
--    time as already sent (that rule was meant for a second scorer taking
--    over), so they never went again. Now only other people's sessions count.
--  * the clock's kick-off time was kept from the first time the clock ever
--    ran, so a reset match could look like it had finished hours ago. It now
--    clears when the clock goes back to the start.
-- Also adds a "second half under way" alert (with the throw-in setting).

CREATE OR REPLACE FUNCTION public.lm_timer_kickoff()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = 'public'
AS $$
BEGIN
  -- Back at the start (reset or a new record): forget the old kick-off
  IF NEW.phase = 'setup'
     OR (NEW.status IS DISTINCT FROM 'running' AND NEW.started_at IS NULL
         AND COALESCE(NEW.elapsed_seconds, 0) = 0 AND COALESCE(NEW.current_half, 1) = 1) THEN
    NEW.kicked_off_at := NULL;
  END IF;
  IF NEW.kicked_off_at IS NULL AND (NEW.started_at IS NOT NULL OR NEW.status = 'running') THEN
    NEW.kicked_off_at := now();
  END IF;
  RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION public.lm_phase(p_session bigint)
RETURNS text
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = 'public'
AS $$
  SELECT CASE
    WHEN ms.id IS NULL THEN 'pre'
    WHEN ms.status = 'finalised' THEN 'done'
    WHEN mt.id IS NULL THEN 'pre'
    WHEN mt.phase = 'setup' THEN 'pre'
    -- left running long after the match (never saved): treat as over
    WHEN GREATEST(mt.kicked_off_at, ms.created_at) < now() - interval '6 hours' THEN 'done'
    -- a running half stops itself once half length + injury time is up
    WHEN mt.status = 'running' AND mt.started_at IS NOT NULL AND COALESCE(mt.duration_seconds, 0) > 0
         AND COALESCE(mt.phase, 'play') = 'play'
         AND mt.elapsed_seconds + extract(epoch FROM now() - (mt.started_at + make_interval(secs => COALESCE(mt.clock_offset_ms, 0) / 1000.0)))
             >= mt.duration_seconds + COALESCE(mt.injury_seconds, 0)
      THEN CASE WHEN mt.current_half >= 2 THEN 'ft' ELSE 'ht' END
    WHEN mt.phase IN ('play', 'ht', 'ft', 'done') THEN mt.phase
    WHEN mt.status = 'running' THEN 'play'
    WHEN mt.elapsed_seconds >= mt.duration_seconds + mt.injury_seconds AND mt.duration_seconds > 0
      THEN CASE WHEN mt.current_half >= 2 THEN 'ft' ELSE 'ht' END
    WHEN mt.elapsed_seconds = 0 AND mt.current_half = 1
         AND NOT EXISTS (SELECT 1 FROM public.match_stats_details d WHERE d.match_stats_id = ms.id) THEN 'pre'
    ELSE 'play'
  END
    FROM (SELECT p_session AS sid) x
    LEFT JOIN public.match_stats ms ON ms.id = x.sid
    LEFT JOIN public.match_timer mt ON mt.event_id = ms.event_id AND mt.user_id = ms.user_id;
$$;
REVOKE ALL ON FUNCTION public.lm_phase(bigint) FROM PUBLIC, anon, authenticated;

CREATE OR REPLACE FUNCTION public.lm_alert_claim(p_match_stats_id bigint, p_settle int DEFAULT 8)
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
BEGIN
  SELECT * INTO v_ms FROM public.match_stats WHERE id = p_match_stats_id;
  IF v_ms.id IS NULL THEN RETURN jsonb_build_object('items', '[]'::jsonb, 'phases', '[]'::jsonb, 'more', false); END IF;

  INSERT INTO public.live_alert_log (match_stats_id) VALUES (p_match_stats_id) ON CONFLICT DO NOTHING;
  SELECT * INTO v_log FROM public.live_alert_log WHERE match_stats_id = p_match_stats_id FOR UPDATE;

  -- Only the session followers see sends alerts. Another scorer's session is
  -- marked as sent up to now, so it never alerts its backlog if it later
  -- becomes the one followers see.
  IF public.lm_session_id(v_ms.event_id) IS DISTINCT FROM p_match_stats_id THEN
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
  -- or full time another scorer's session really sent, so a hand-over never
  -- repeats them. Only other people's sessions count: this scorer's own
  -- earlier records (reset, or a new record started) are a different match.
  v_log.phases := ARRAY(
    SELECT DISTINCT replace(x, '-x', '') FROM unnest(v_log.phases) x
    UNION
    SELECT x FROM public.live_alert_log a
      JOIN public.match_stats ms2 ON ms2.id = a.match_stats_id AND ms2.event_id = v_ms.event_id
      CROSS JOIN LATERAL unnest(a.phases) x
     WHERE a.match_stats_id <> p_match_stats_id AND x NOT LIKE '%-x'
       AND ms2.user_id IS DISTINCT FROM v_ms.user_id AND ms2.status <> 'reset');

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
    'state',    public.lm_state(v_ms.event_id, true)
  );
END;
$$;
REVOKE ALL ON FUNCTION public.lm_alert_claim(bigint, int) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.lm_alert_claim(bigint, int) TO service_role;

CREATE OR REPLACE FUNCTION public.lm_alert_owed(p_match_stats_id bigint)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = 'public'
AS $$
  WITH l AS (
    SELECT COALESCE(max(a.last_detail_id), 0) AS last_id,
           COALESCE((SELECT array_agg(replace(x, '-x', '')) FROM unnest(max(a.phases)) x), '{}') AS phases
      FROM public.live_alert_log a WHERE a.match_stats_id = p_match_stats_id
  ), p AS (SELECT public.lm_phase(p_match_stats_id) AS ph)
  SELECT EXISTS (
           SELECT 1 FROM public.match_stats_details d
             JOIN public.match_stat_types mst ON mst.id = d.score_type, l
            WHERE d.match_stats_id = p_match_stats_id AND d.kind = 'score' AND d.id > l.last_id
              AND mst.score_value IS NOT NULL AND mst.score_value > 0
         )
      OR (SELECT (p.ph = 'play' AND NOT 'ko' = ANY (l.phases))
              OR (p.ph = 'play' AND (SELECT COALESCE(mt.current_half, 1) >= 2 FROM public.match_stats ms
                     JOIN public.match_timer mt ON mt.event_id = ms.event_id AND mt.user_id = ms.user_id
                    WHERE ms.id = p_match_stats_id) AND NOT 'h2' = ANY (l.phases))
              OR (p.ph = 'ht' AND NOT 'ht' = ANY (l.phases))
              OR (p.ph IN ('ft', 'done') AND NOT 'ft' = ANY (l.phases))
            FROM p, l);
$$;
REVOKE ALL ON FUNCTION public.lm_alert_owed(bigint) FROM PUBLIC, anon, authenticated;
