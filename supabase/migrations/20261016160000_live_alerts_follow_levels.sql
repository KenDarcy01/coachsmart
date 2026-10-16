-- Live match alerts: followers can choose what they get
--
-- Ken (2026-10-16): only people who follow a match get alerts (unchanged
-- from 20261016150000), and following starts on every score, but each
-- follower can switch that match to goals only or half/full time only. So
-- the follower's own level and kick-off choice are used again instead of
-- always 'all'. Team defaults stay ignored; the scorer stays left out.

CREATE OR REPLACE FUNCTION public.lm_alert_targets(p_event_id bigint, p_scorer uuid)
RETURNS TABLE (user_id uuid, level text, kickoff boolean, names boolean, fcm_token text)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = 'public'
AS $$
  SELECT f.user_id, f.level, COALESCE(f.kickoff, true), COALESCE(f.names, true), u.fcm_token
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
      (SELECT jsonb_build_object('level', level, 'kickoff', kickoff, 'names', names, 'source', 'match', 'own_team', (SELECT is_own FROM own)) FROM ev)
    ELSE jsonb_build_object('level', 'off', 'kickoff', false, 'names', true, 'source', 'none', 'own_team', (SELECT is_own FROM own))
  END;
$$;
REVOKE ALL ON FUNCTION public.lm_my_follow(bigint) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.lm_my_follow(bigint) TO authenticated;
