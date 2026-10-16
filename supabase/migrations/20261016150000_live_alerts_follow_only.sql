-- Live match alerts: only for people who follow the match themselves
--
-- Ken (2026-10-16): "turn off alerts for everyone for all events unless they
-- tick it themselves manually per event", and anyone who follows gets every
-- score. So:
--   * team members no longer get alerts by default, and the "my teams"
--     default rows (live_follows.event_id IS NULL) are ignored
--   * a follow on a match (any level other than 'off') means every score,
--     plus throw-in, half time and full time
--   * the person keeping score is still left out (Ken chose "Never")
--   * stored tokens that can't be FCM tokens (too short or with spaces, e.g.
--     status text) are skipped; FCM rejects them anyway

CREATE OR REPLACE FUNCTION public.lm_alert_targets(p_event_id bigint, p_scorer uuid)
RETURNS TABLE (user_id uuid, level text, kickoff boolean, names boolean, fcm_token text)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = 'public'
AS $$
  SELECT f.user_id, 'all'::text, true, COALESCE(f.names, true), u.fcm_token
    FROM public.live_follows f
    JOIN public.users u ON u.user_id = f.user_id
   WHERE f.event_id = p_event_id
     AND f.level <> 'off'
     AND f.user_id IS DISTINCT FROM p_scorer
     AND length(COALESCE(u.fcm_token, '')) >= 100
     AND u.fcm_token !~ '\s';
$$;
REVOKE ALL ON FUNCTION public.lm_alert_targets(bigint, uuid) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.lm_alert_targets(bigint, uuid) TO service_role;

-- What the live screen and Matches list show as "following": only a follow
-- on this match counts
CREATE OR REPLACE FUNCTION public.lm_my_follow(p_event_id bigint)
RETURNS jsonb
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = 'public'
AS $$
  WITH me AS (SELECT auth.uid() AS uid),
  own AS (
    SELECT EXISTS (
      SELECT 1 FROM public.events e
        JOIN public.member_team_link mtl ON mtl.team_id = e.team_id AND mtl.status = 'active'
        JOIN public.user_member_link uml ON uml.member_id = mtl.member_id
       WHERE e.event_id = p_event_id AND uml.user_id = (SELECT uid FROM me)
    ) AS is_own
  ),
  ev AS (SELECT * FROM public.live_follows f
          WHERE f.user_id = (SELECT uid FROM me) AND f.event_id = p_event_id AND f.level <> 'off')
  SELECT CASE
    WHEN EXISTS (SELECT 1 FROM ev) THEN
      (SELECT jsonb_build_object('level', 'all', 'kickoff', true, 'names', names, 'source', 'match', 'own_team', (SELECT is_own FROM own)) FROM ev)
    ELSE jsonb_build_object('level', 'off', 'kickoff', false, 'names', true, 'source', 'none', 'own_team', (SELECT is_own FROM own))
  END;
$$;
REVOKE ALL ON FUNCTION public.lm_my_follow(bigint) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.lm_my_follow(bigint) TO authenticated;
