-- Add p_limit parameter (default 50) to get_user_notifications.
-- Caps the result set to the N most recent notifications.
-- Passing a higher value from FlutterFlow allows "load more" if needed.
-- Old signature (uuid) is dropped first to allow the signature change.

DROP FUNCTION IF EXISTS public.get_user_notifications(uuid);

CREATE FUNCTION public.get_user_notifications(
    p_user_id uuid,
    p_limit   integer DEFAULT 50
)
RETURNS TABLE (
    id              bigint,
    created_at      text,
    time_label      text,
    app_title       text,
    app_body        text,
    is_read         boolean,
    is_delivered    boolean,
    link_page       text,
    image           text,
    team_id         bigint,
    team_name       text,
    event_id        bigint,
    member_id       bigint,
    action          text,
    action_ref_id   bigint
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = 'public'
AS $$
BEGIN
    RETURN QUERY
    SELECT
        n.id,
        to_char(n.created_at, 'Dy, DD Mon YYYY "at" HH12:MI AM')::text,
        CASE
            WHEN n.created_at > now() - interval '2 minutes'  THEN 'Just now'
            WHEN n.created_at > now() - interval '1 hour'
                THEN floor(extract(epoch from (now() - n.created_at)) / 60)::text || 'm ago'
            WHEN n.created_at > now() - interval '24 hours' THEN
                CASE
                    WHEN floor(extract(epoch from (now() - n.created_at)) / 3600) = 1 THEN '1 hour ago'
                    ELSE floor(extract(epoch from (now() - n.created_at)) / 3600)::text || ' hours ago'
                END
            ELSE
                CASE
                    WHEN floor(extract(epoch from (now() - n.created_at)) / 86400) = 1 THEN '1 day ago'
                    ELSE floor(extract(epoch from (now() - n.created_at)) / 86400)::text || ' days ago'
                END
        END AS time_label,
        COALESCE(n.app_title, n.push_title, 'Notification') AS app_title,
        COALESCE(n.app_body,  n.push_body,  '')              AS app_body,
        n.is_read,
        n.is_delivered,
        n.link_page,
        n.image,
        n.team_id,
        COALESCE(t.team_name, 'General') AS team_name,
        n.event_id,
        n.member_id,
        n.action,
        n.action_ref_id
    FROM  public.notifications n
    LEFT JOIN public.teams t ON n.team_id = t.team_id
    WHERE n.recipient_user_id = p_user_id
    ORDER BY n.created_at DESC
    LIMIT p_limit;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.get_user_notifications(uuid, integer) FROM PUBLIC;
GRANT  EXECUTE ON FUNCTION public.get_user_notifications(uuid, integer) TO authenticated;
GRANT  EXECUTE ON FUNCTION public.get_user_notifications(uuid, integer) TO service_role;
