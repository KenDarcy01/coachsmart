-- Important messages stay pinned on the v3 club screen until they end, even
-- after the pop-up is acknowledged (Ken, 2026-11-26). Adds a 'pinned' key to
-- get_my_app_messages: every live important message for the user, dismissed
-- or not. 'important' (the pop-up list) is unchanged. v3 only reads this RPC.
CREATE OR REPLACE FUNCTION public.get_my_app_messages()
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_uid uuid := auth.uid();
  v_out jsonb;
BEGIN
  IF v_uid IS NULL THEN
    RETURN jsonb_build_object('important', '[]'::jsonb, 'pinned', '[]'::jsonb,
                              'news', '[]'::jsonb, 'fundraisers', '[]'::jsonb,
                              'is_super_user', false);
  END IF;

  WITH live AS (
    SELECT m AS msg, r.seen_at, r.dismissed_at
      FROM app_messages m
      LEFT JOIN app_message_reads r ON r.message_id = m.id AND r.user_id = v_uid
     WHERE m.deleted_at IS NULL AND m.ended_at IS NULL
       AND m.starts_at <= now() AND m.ends_at > now()
       AND EXISTS (SELECT 1 FROM app_message_audience(m.club_id, m.team_ids, m.audience, v_uid))
  )
  SELECT jsonb_build_object(
    'is_super_user', is_app_super_user(),
    -- CoachSmart first, then club, then team; newest first within each.
    'important', COALESCE((
       SELECT jsonb_agg(app_message_json(l.msg)
              ORDER BY CASE WHEN cardinality((l.msg).team_ids) > 0 THEN 2
                            WHEN (l.msg).club_id IS NOT NULL THEN 1 ELSE 0 END,
                       (l.msg).starts_at DESC)
         FROM live l WHERE (l.msg).kind = 'important' AND l.dismissed_at IS NULL), '[]'::jsonb),
    -- Pinned on the club screen until the message ends, acknowledged or not.
    'pinned', COALESCE((
       SELECT jsonb_agg(app_message_json(l.msg)
              ORDER BY (l.msg).starts_at DESC)
         FROM live l WHERE (l.msg).kind = 'important'), '[]'::jsonb),
    'news', COALESCE((
       SELECT jsonb_agg(app_message_json(l.msg)
                        || jsonb_build_object('seen', l.seen_at IS NOT NULL)
              ORDER BY (l.msg).starts_at DESC)
         FROM live l WHERE (l.msg).kind = 'news'), '[]'::jsonb),
    -- Ending soonest first: the draw closing this week leads.
    'fundraisers', COALESCE((
       SELECT jsonb_agg(app_message_json(l.msg)
                        || jsonb_build_object('seen', l.seen_at IS NOT NULL)
              ORDER BY (l.msg).ends_at, (l.msg).starts_at DESC)
         FROM live l WHERE (l.msg).kind = 'fundraiser'), '[]'::jsonb))
    INTO v_out;
  RETURN v_out;
END;
$function$;
