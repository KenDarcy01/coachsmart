-- Push confirm sheet (Ken 2026-11-28): before an Important message's push is
-- sent, the sender sees how many phones get it (iPhone / Android split) and
-- how many people it reaches. Read-only; same rules and token test as
-- count_app_message_push and app_message_push_targets (one push per token).
CREATE OR REPLACE FUNCTION public.count_app_message_push_detail(
  p_club_id bigint, p_team_ids bigint[], p_audience text)
 RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path TO 'public' AS $$
DECLARE v jsonb;
BEGIN
  IF NOT public.app_message_can(p_club_id, p_team_ids) THEN RAISE EXCEPTION 'Not allowed'; END IF;
  WITH a AS (
    SELECT DISTINCT a.user_id FROM app_message_audience(p_club_id, p_team_ids, p_audience) a),
  t AS (
    SELECT DISTINCT ON (u.fcm_token) u.fcm_token, lower(coalesce(u.last_platform, '')) AS plat
      FROM a JOIN users u ON u.user_id = a.user_id
     WHERE length(coalesce(u.fcm_token, '')) > 100
     ORDER BY u.fcm_token, u.last_active_at DESC NULLS LAST)
  SELECT jsonb_build_object(
           'people', (SELECT count(*) FROM a),
           'phones', (SELECT count(*) FROM t),
           'ios', (SELECT count(*) FROM t WHERE plat LIKE '%ios%'),
           'android', (SELECT count(*) FROM t WHERE plat LIKE '%android%'))
    INTO v;
  RETURN v;
END $$;
REVOKE ALL ON FUNCTION public.count_app_message_push_detail(bigint, bigint[], text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.count_app_message_push_detail(bigint, bigint[], text) TO authenticated;
