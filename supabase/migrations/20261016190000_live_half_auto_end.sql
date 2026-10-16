-- Live match: a half ends itself when injury time is up
--
-- Ken (2026-10-16): if the scorer forgets to end a half, it stops once half
-- length + the maximum injury time is up. The score keeper now does this on
-- the phone; this does the same on the server, so followers see half time /
-- full time (and get the alert) even if the scorer's phone is closed.

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
    WHEN mt.kicked_off_at < now() - interval '6 hours' THEN 'done'
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
