-- Live match alerts: make them self-healing and checkable
--
-- Ken (2026-10-16) only got the full-time alert in two test matches. Locally
-- the whole chain works, so on the server some alert runs are not finishing.
-- When a run doesn't finish, the old 2-minute "already pending" guard also
-- swallowed every wake after it. This:
--   1. shortens that guard to 45 seconds
--   2. adds a once-a-minute sweep that re-wakes any live match with alerts
--      still owed (a new score, kick-off, half time or full time not yet sent)
--   3. records each wake (with its pg_net request id) and each run, so
--      lm_alert_probe can show what happened (no names, tokens or user ids)

CREATE TABLE IF NOT EXISTS public.live_alert_runs (
  id             bigserial PRIMARY KEY,
  match_stats_id bigint NOT NULL,
  at             timestamptz NOT NULL DEFAULT now(),
  note           jsonb NOT NULL DEFAULT '{}'::jsonb
);
CREATE INDEX IF NOT EXISTS live_alert_runs_ms_idx ON public.live_alert_runs (match_stats_id, id DESC);
ALTER TABLE public.live_alert_runs ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.live_alert_runs FROM anon, authenticated;

-- The alert function writes a short note per run
CREATE OR REPLACE FUNCTION public.lm_alert_note(p_match_stats_id bigint, p_note jsonb)
RETURNS void
LANGUAGE sql
SECURITY DEFINER
SET search_path = 'public'
AS $$
  INSERT INTO public.live_alert_runs (match_stats_id, note) VALUES (p_match_stats_id, COALESCE(p_note, '{}'::jsonb));
  DELETE FROM public.live_alert_runs WHERE at < now() - interval '7 days';
$$;
REVOKE ALL ON FUNCTION public.lm_alert_note(bigint, jsonb) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.lm_alert_note(bigint, jsonb) TO service_role;

-- Wake: same as 20261016000100, with a 45-second guard and a note of the request
CREATE OR REPLACE FUNCTION public.lm_alert_wake(p_match_stats_id bigint)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = 'public'
AS $$
DECLARE
  v_secret text;
  v_jwt    text;
  v_go     boolean;
  v_req    bigint;
BEGIN
  INSERT INTO public.live_alert_log (match_stats_id, pending_since)
  VALUES (p_match_stats_id, now())
  ON CONFLICT (match_stats_id) DO UPDATE
     SET pending_since = now()
   WHERE live_alert_log.pending_since IS NULL OR live_alert_log.pending_since < now() - interval '45 seconds'
  RETURNING true INTO v_go;
  IF v_go IS NOT TRUE THEN RETURN; END IF;

  SELECT decrypted_secret INTO v_secret FROM vault.decrypted_secrets WHERE name = 'jwt_signing_secret' LIMIT 1;
  IF v_secret IS NULL THEN
    PERFORM public.lm_alert_note(p_match_stats_id, jsonb_build_object('wake', 'no_secret'));
    RAISE WARNING 'lm_alert_wake: jwt_signing_secret not found in vault';
    RETURN;
  END IF;
  SELECT extensions.sign(json_build_object(
           'role', 'service_role', 'iss', 'supabase', 'ref', 'gyfporsbdftvtakdvukt',
           'iat', extract(epoch from now())::integer, 'exp', (extract(epoch from now()) + 600)::integer
         )::json, v_secret) INTO v_jwt;

  SELECT net.http_post(
    url     := 'https://gyfporsbdftvtakdvukt.supabase.co/functions/v1/live-match-alerts',
    headers := jsonb_build_object('Content-Type', 'application/json', 'Authorization', 'Bearer ' || v_jwt),
    body    := jsonb_build_object('match_stats_id', p_match_stats_id)
  ) INTO v_req;
  PERFORM public.lm_alert_note(p_match_stats_id, jsonb_build_object('wake', v_req));
END;
$$;
REVOKE ALL ON FUNCTION public.lm_alert_wake(bigint) FROM PUBLIC, anon, authenticated;

-- What a session is still owed: scores not yet alerted, or the phase it is in
-- not yet alerted
CREATE OR REPLACE FUNCTION public.lm_alert_owed(p_match_stats_id bigint)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = 'public'
AS $$
  WITH l AS (
    SELECT COALESCE(max(a.last_detail_id), 0) AS last_id, COALESCE(max(a.phases), '{}') AS phases
      FROM public.live_alert_log a WHERE a.match_stats_id = p_match_stats_id
  ), p AS (SELECT public.lm_phase(p_match_stats_id) AS ph)
  SELECT EXISTS (
           SELECT 1 FROM public.match_stats_details d
             JOIN public.match_stat_types mst ON mst.id = d.score_type, l
            WHERE d.match_stats_id = p_match_stats_id AND d.kind = 'score' AND d.id > l.last_id
              AND mst.score_value IS NOT NULL AND mst.score_value > 0
         )
      OR (SELECT (p.ph = 'play' AND NOT 'ko' = ANY (l.phases))
              OR (p.ph = 'ht' AND NOT 'ht' = ANY (l.phases))
              OR (p.ph IN ('ft', 'done') AND NOT 'ft' = ANY (l.phases))
            FROM p, l);
$$;
REVOKE ALL ON FUNCTION public.lm_alert_owed(bigint) FROM PUBLIC, anon, authenticated;

-- Once a minute: wake any match played in the last 4 hours that is still owed alerts
CREATE OR REPLACE FUNCTION public.lm_alert_sweep()
RETURNS int
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = 'public'
AS $$
DECLARE
  r record;
  n int := 0;
BEGIN
  FOR r IN
    SELECT ms.id
      FROM public.match_stats ms
      JOIN public.match_timer mt ON mt.event_id = ms.event_id AND mt.user_id = ms.user_id
     WHERE ms.status IN ('active', 'finalised')
       AND GREATEST(mt.updated_at, ms.finalised_at) > now() - interval '4 hours'
  LOOP
    BEGIN
      IF public.lm_alert_owed(r.id) THEN
        PERFORM public.lm_alert_wake(r.id);
        n := n + 1;
      END IF;
    EXCEPTION WHEN OTHERS THEN
      RAISE WARNING 'lm_alert_sweep %: %', r.id, SQLERRM;
    END;
  END LOOP;
  RETURN n;
END;
$$;
REVOKE ALL ON FUNCTION public.lm_alert_sweep() FROM PUBLIC, anon, authenticated;

DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_namespace WHERE nspname = 'cron') THEN
    PERFORM cron.unschedule(jobid) FROM cron.job WHERE jobname = 'live-match-alert-sweep';
    PERFORM cron.schedule('live-match-alert-sweep', '* * * * *', 'SELECT public.lm_alert_sweep()');
  ELSE
    RAISE WARNING 'pg_cron not installed: live-match-alert-sweep not scheduled';
  END IF;
EXCEPTION WHEN OTHERS THEN
  RAISE WARNING 'Could not schedule live-match-alert-sweep: %', SQLERRM;
END;
$$;

-- What happened with alerts for a match: sessions, timer, what was alerted,
-- recent wakes and runs, and the server's answers to those wakes.
-- Counts only for who gets alerts; no names, user ids or tokens.
CREATE OR REPLACE FUNCTION public.lm_alert_probe(p_event_id bigint)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = 'public'
AS $$
DECLARE
  v_out   jsonb;
  v_sid   bigint := public.lm_session_id(p_event_id);
  v_resp  jsonb;
BEGIN
  SELECT jsonb_build_object(
    'now', now(),
    'session', v_sid,
    'phase', public.lm_phase(v_sid),
    'sessions', (SELECT COALESCE(jsonb_agg(jsonb_build_object('id', ms.id, 'status', ms.status, 'created', ms.created_at, 'finalised', ms.finalised_at,
                   'scores', (SELECT count(*) FROM public.match_stats_details d WHERE d.match_stats_id = ms.id AND d.kind = 'score'),
                   'scorer_is_follower', EXISTS (SELECT 1 FROM public.live_follows f WHERE f.user_id = ms.user_id AND (f.event_id = p_event_id OR f.event_id IS NULL)))
                   ORDER BY ms.id), '[]') FROM public.match_stats ms WHERE ms.event_id = p_event_id),
    'timers', (SELECT COALESCE(jsonb_agg(jsonb_build_object('status', mt.status, 'phase', mt.phase, 'half', mt.current_half,
                   'elapsed', mt.elapsed_seconds, 'updated', mt.updated_at, 'offset_ms', mt.clock_offset_ms)), '[]')
                 FROM public.match_timer mt WHERE mt.event_id = p_event_id),
    'log', (SELECT COALESCE(jsonb_agg(to_jsonb(a)), '[]') FROM public.live_alert_log a
             WHERE a.match_stats_id IN (SELECT id FROM public.match_stats WHERE event_id = p_event_id)),
    'targets', (SELECT jsonb_build_object(
                  'total', count(*),
                  'by_level', COALESCE((SELECT jsonb_object_agg(level, c) FROM (SELECT level, count(*) c FROM public.lm_alert_targets(p_event_id, NULL) GROUP BY level) x), '{}'))
                FROM public.lm_alert_targets(p_event_id, NULL)),
    'runs', (SELECT COALESCE(jsonb_agg(jsonb_build_object('at', r.at, 'ms', r.match_stats_id, 'note', r.note) ORDER BY r.id DESC), '[]')
               FROM (SELECT * FROM public.live_alert_runs
                      WHERE match_stats_id IN (SELECT id FROM public.match_stats WHERE event_id = p_event_id)
                      ORDER BY id DESC LIMIT 60) r)
  ) INTO v_out;

  -- pg_net keeps the server's answers for a few hours
  BEGIN
    EXECUTE $q$
      SELECT COALESCE(jsonb_agg(jsonb_build_object('id', h.id, 'status', h.status_code, 'timed_out', h.timed_out,
               'error', h.error_msg, 'body', left(h.content, 120), 'at', h.created) ORDER BY h.id DESC), '[]')
        FROM net._http_response h
       WHERE h.id IN (SELECT (r.note->>'wake')::bigint FROM public.live_alert_runs r
                       WHERE r.note ? 'wake' AND r.note->>'wake' ~ '^[0-9]+$'
                         AND r.match_stats_id IN (SELECT id FROM public.match_stats WHERE event_id = $1))
    $q$ INTO v_resp USING p_event_id;
  EXCEPTION WHEN OTHERS THEN
    v_resp := to_jsonb(SQLERRM);
  END;
  RETURN v_out || jsonb_build_object('wake_answers', v_resp);
END;
$$;
REVOKE ALL ON FUNCTION public.lm_alert_probe(bigint) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.lm_alert_probe(bigint) TO service_role;
