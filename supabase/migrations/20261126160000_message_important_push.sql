-- Push on Important messages (Ken 2026-11-26, design points 1-5 agreed):
--   * a "Send a push too" switch on Important messages only, off by default;
--   * goes to the message's audience (one push per person, however many
--     children), only people with a push token; push only, no notifications
--     row, no email;
--   * sent when the message starts showing (scheduled ones at their start),
--     once per message, never again on edit.
-- A cron job each minute claims due messages and wakes the app-message-push
-- edge function, which sends through FCM. Additive; v2 apps simply receive
-- the push (no link, so a tap just opens the app).

ALTER TABLE public.app_messages
  ADD COLUMN IF NOT EXISTS push boolean NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS push_sent_at timestamptz,
  ADD COLUMN IF NOT EXISTS push_count integer;

-- A real FCM token (the column also holds '' and "Notification permissions denied.").
CREATE OR REPLACE FUNCTION public.app_message_push_targets(p_id bigint)
 RETURNS TABLE(user_id uuid, fcm_token text)
 LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public' AS $$
  SELECT DISTINCT ON (u.fcm_token) u.user_id, u.fcm_token
    FROM app_messages m
    CROSS JOIN LATERAL app_message_audience(m.club_id, m.team_ids, m.audience) a
    JOIN users u ON u.user_id = a.user_id
   WHERE m.id = p_id AND length(coalesce(u.fcm_token, '')) > 100
   ORDER BY u.fcm_token, u.user_id;
$$;
REVOKE ALL ON FUNCTION public.app_message_push_targets(bigint) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.app_message_push_targets(bigint) TO service_role;

-- How many phones a push would reach (shown next to the switch).
CREATE OR REPLACE FUNCTION public.count_app_message_push(
  p_club_id bigint, p_team_ids bigint[], p_audience text)
 RETURNS integer LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path TO 'public' AS $$
BEGIN
  IF NOT public.app_message_can(p_club_id, p_team_ids) THEN RAISE EXCEPTION 'Not allowed'; END IF;
  RETURN (SELECT count(DISTINCT u.fcm_token)
            FROM app_message_audience(p_club_id, p_team_ids, p_audience) a
            JOIN users u ON u.user_id = a.user_id
           WHERE length(coalesce(u.fcm_token, '')) > 100);
END $$;
REVOKE ALL ON FUNCTION public.count_app_message_push(bigint, bigint[], text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.count_app_message_push(bigint, bigint[], text) TO authenticated;

-- Claims due pushes and wakes the edge function (service-role token signed
-- from the vault secret, as gaa_sync_wake does).
CREATE OR REPLACE FUNCTION public.app_message_push_run()
 RETURNS integer LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public' AS $$
DECLARE
  v_ids bigint[];
  v_secret text;
  v_jwt text;
BEGIN
  WITH due AS (
    UPDATE app_messages SET push_sent_at = now()
     WHERE push AND push_sent_at IS NULL AND kind = 'important'
       AND deleted_at IS NULL AND ended_at IS NULL
       AND starts_at <= now() AND ends_at > now()
    RETURNING id)
  SELECT array_agg(id) INTO v_ids FROM due;
  IF v_ids IS NULL THEN RETURN 0; END IF;

  SELECT decrypted_secret INTO v_secret FROM vault.decrypted_secrets WHERE name = 'jwt_signing_secret' LIMIT 1;
  IF v_secret IS NULL THEN
    RAISE WARNING 'app_message_push_run: jwt_signing_secret not found in vault';
    UPDATE app_messages SET push_sent_at = NULL WHERE id = ANY (v_ids);
    RETURN 0;
  END IF;
  SELECT extensions.sign(json_build_object(
           'role', 'service_role', 'iss', 'supabase', 'ref', 'gyfporsbdftvtakdvukt',
           'iat', extract(epoch from now())::integer, 'exp', (extract(epoch from now()) + 900)::integer
         )::json, v_secret) INTO v_jwt;
  PERFORM net.http_post(
    url     := 'https://gyfporsbdftvtakdvukt.supabase.co/functions/v1/app-message-push',
    headers := jsonb_build_object('Content-Type', 'application/json', 'Authorization', 'Bearer ' || v_jwt),
    body    := jsonb_build_object('ids', to_jsonb(v_ids)),
    timeout_milliseconds := 60000);
  RETURN cardinality(v_ids);
END $$;
REVOKE ALL ON FUNCTION public.app_message_push_run() FROM PUBLIC, anon, authenticated;

-- Turn the push on or off for a saved message (called right after
-- save_app_message). Important only; once sent it can't be sent again.
CREATE OR REPLACE FUNCTION public.set_app_message_push(p_id bigint, p_push boolean)
 RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public' AS $$
DECLARE v_old app_messages%ROWTYPE;
BEGIN
  SELECT * INTO v_old FROM app_messages WHERE id = p_id AND deleted_at IS NULL;
  IF NOT FOUND OR NOT public.app_message_can(v_old.club_id, v_old.team_ids) THEN RAISE EXCEPTION 'Not allowed'; END IF;
  IF v_old.push_sent_at IS NULL THEN
    UPDATE app_messages SET push = coalesce(p_push, false) AND kind = 'important' WHERE id = p_id;
    PERFORM public.app_message_push_run();
  END IF;
  SELECT * INTO v_old FROM app_messages WHERE id = p_id;
  RETURN jsonb_build_object('push', v_old.push, 'push_sent_at', v_old.push_sent_at);
END $$;
REVOKE ALL ON FUNCTION public.set_app_message_push(bigint, boolean) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.set_app_message_push(bigint, boolean) TO authenticated;

-- Edge function records how many phones it reached.
CREATE OR REPLACE FUNCTION public.app_message_push_done(p_id bigint, p_count integer)
 RETURNS void LANGUAGE sql SECURITY DEFINER SET search_path TO 'public' AS $$
  UPDATE app_messages SET push_count = p_count WHERE id = p_id;
$$;
REVOKE ALL ON FUNCTION public.app_message_push_done(bigint, integer) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.app_message_push_done(bigint, integer) TO service_role;

-- Sent list shows the push state.
CREATE OR REPLACE FUNCTION public.get_sent_app_messages()
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE v_super boolean := coalesce(is_app_super_user(), false);
BEGIN
  IF NOT v_super AND NOT EXISTS (SELECT 1 FROM club_officers o WHERE o.user_id = auth.uid() AND o.is_active AND o.can_messages) THEN
    RAISE EXCEPTION 'Not allowed';
  END IF;
  RETURN COALESCE((
    SELECT jsonb_agg(app_message_json(m) || jsonb_build_object(
             'ended_at', m.ended_at,
             'push', m.push, 'push_sent_at', m.push_sent_at, 'push_count', m.push_count,
             'reach', (SELECT count(*) FROM app_message_audience(m.club_id, m.team_ids, m.audience)),
             'seen_count', (SELECT count(*) FROM app_message_reads r WHERE r.message_id = m.id),
             'dismissed_count', (SELECT count(*) FROM app_message_reads r
                            WHERE r.message_id = m.id AND r.dismissed_at IS NOT NULL),
             'tap_count', (SELECT count(*) FROM app_message_reads r
                            WHERE r.message_id = m.id AND r.tapped_at IS NOT NULL),
             'team_names', COALESCE((SELECT jsonb_agg(t.team_name ORDER BY t.team_name)
                                       FROM teams t WHERE t.team_id = ANY (m.team_ids)), '[]'::jsonb))
           ORDER BY m.starts_at DESC)
      FROM app_messages m
     WHERE m.deleted_at IS NULL
       AND (v_super OR EXISTS (SELECT 1 FROM club_officers o WHERE o.club_id = m.club_id
                                 AND o.user_id = auth.uid() AND o.is_active AND o.can_messages))), '[]'::jsonb);
END $function$;

DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'pg_cron') THEN
    PERFORM cron.unschedule(jobname) FROM cron.job WHERE jobname = 'app-message-push';
    PERFORM cron.schedule('app-message-push', '* * * * *', $c$SELECT public.app_message_push_run()$c$);
  END IF;
END $$;
