-- live-match-probe?recent=1: the alert check for the 5 most recently played
-- matches (last 12 hours), so the event id isn't needed. Same content as
-- lm_alert_probe: counts and statuses only, no names, user ids or tokens.
CREATE OR REPLACE FUNCTION public.lm_alert_probe_recent()
RETURNS jsonb
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = 'public'
AS $$
  SELECT COALESCE(jsonb_agg(jsonb_build_object('event_id', x.event_id) || public.lm_alert_probe(x.event_id) ORDER BY x.last DESC), '[]')
    FROM (SELECT mt.event_id, max(mt.updated_at) AS last
            FROM public.match_timer mt
           WHERE mt.updated_at > now() - interval '12 hours'
           GROUP BY mt.event_id
           ORDER BY max(mt.updated_at) DESC
           LIMIT 5) x;
$$;
REVOKE ALL ON FUNCTION public.lm_alert_probe_recent() FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.lm_alert_probe_recent() TO service_role;
