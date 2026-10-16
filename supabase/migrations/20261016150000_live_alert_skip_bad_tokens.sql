-- Live match alerts: skip push tokens that can't be FCM tokens
--
-- Some users.fcm_token values are too short or contain spaces, and FCM
-- rejects them as "not a valid FCM registration token". Skip them.
-- The person keeping score stays left out of that match's alerts
-- (Ken, 2026-10-16: "Never").

CREATE OR REPLACE FUNCTION public.lm_alert_targets(p_event_id bigint, p_scorer uuid)
RETURNS TABLE (user_id uuid, level text, kickoff boolean, names boolean, fcm_token text)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = 'public'
AS $$
  WITH team_users AS (
    SELECT DISTINCT uml.user_id
      FROM public.events e
      JOIN public.member_team_link mtl ON mtl.team_id = e.team_id AND mtl.status = 'active'
      JOIN public.user_member_link uml ON uml.member_id = mtl.member_id
     WHERE e.event_id = p_event_id
  ),
  everyone AS (
    SELECT user_id FROM team_users
    UNION
    SELECT f.user_id FROM public.live_follows f WHERE f.event_id = p_event_id
  ),
  resolved AS (
    SELECT ev.user_id,
           COALESCE(fe.level,   CASE WHEN tu.user_id IS NOT NULL THEN COALESCE(fd.level, 'result') ELSE 'off' END) AS level,
           COALESCE(fe.kickoff, fd.kickoff, true) AS kickoff,
           COALESCE(fe.names,   fd.names,   true) AS names
      FROM everyone ev
      LEFT JOIN team_users tu ON tu.user_id = ev.user_id
      LEFT JOIN public.live_follows fe ON fe.user_id = ev.user_id AND fe.event_id = p_event_id
      LEFT JOIN public.live_follows fd ON fd.user_id = ev.user_id AND fd.event_id IS NULL
  )
  SELECT r.user_id, r.level, r.kickoff, r.names, u.fcm_token
    FROM resolved r
    JOIN public.users u ON u.user_id = r.user_id
   WHERE r.level <> 'off'
     AND r.user_id IS DISTINCT FROM p_scorer
     AND length(COALESCE(u.fcm_token, '')) >= 100
     AND u.fcm_token !~ '\s';
$$;
REVOKE ALL ON FUNCTION public.lm_alert_targets(bigint, uuid) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.lm_alert_targets(bigint, uuid) TO service_role;
