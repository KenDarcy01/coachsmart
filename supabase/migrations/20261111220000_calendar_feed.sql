-- Calendar feed (v3, Ken 2026-11-11): each user can subscribe their phone
-- calendar to a private link that lists their CoachSmart events.
--
--   calendar_feeds            one secret token per user (RLS on, no policies)
--   get_my_calendar_token     signed-in user: their token, made on first call;
--                             p_reset = true swaps it for a new one
--   get_calendar_feed         service role only (calendar-feed edge function):
--                             the events behind a token
--
-- Purely additive: nothing the live app uses is changed.

CREATE TABLE IF NOT EXISTS public.calendar_feeds (
    user_id    uuid PRIMARY KEY REFERENCES public.users(user_id) ON DELETE CASCADE,
    token      text NOT NULL UNIQUE,
    created_at timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE public.calendar_feeds ENABLE ROW LEVEL SECURITY;

CREATE OR REPLACE FUNCTION public.get_my_calendar_token(p_reset boolean DEFAULT false)
 RETURNS text
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
    v_uid uuid := auth.uid();
    v_new text := replace(gen_random_uuid()::text || gen_random_uuid()::text, '-', '');
    v_token text;
BEGIN
    IF v_uid IS NULL THEN
        RAISE EXCEPTION 'Not signed in';
    END IF;
    IF p_reset THEN
        INSERT INTO public.calendar_feeds (user_id, token) VALUES (v_uid, v_new)
        ON CONFLICT (user_id) DO UPDATE SET token = EXCLUDED.token, created_at = now();
        RETURN v_new;
    END IF;
    SELECT token INTO v_token FROM public.calendar_feeds WHERE user_id = v_uid;
    IF v_token IS NULL THEN
        INSERT INTO public.calendar_feeds (user_id, token) VALUES (v_uid, v_new)
        ON CONFLICT (user_id) DO NOTHING;
        SELECT token INTO v_token FROM public.calendar_feeds WHERE user_id = v_uid;
    END IF;
    RETURN v_token;
END;
$function$;

REVOKE ALL ON FUNCTION public.get_my_calendar_token(boolean) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_my_calendar_token(boolean) TO authenticated;

-- Events for the feed: the last 30 days and everything ahead, not deleted,
-- on teams where one of the user's members can see the event (the same
-- rule as get_user_home_events: an admin role, or a role at or above the
-- event's audience and in the event's squad when it has one).
CREATE OR REPLACE FUNCTION public.get_calendar_feed(p_token text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 STABLE
 SET search_path TO 'public'
AS $function$
DECLARE
    v_uid uuid;
BEGIN
    SELECT user_id INTO v_uid FROM public.calendar_feeds WHERE token = p_token;
    IF v_uid IS NULL THEN
        RETURN NULL;
    END IF;

    RETURN jsonb_build_object('events', COALESCE((
        SELECT jsonb_agg(x ORDER BY x.local_time)
        FROM (
            SELECT
                e.event_id,
                CASE WHEN t.team_female THEN
                    replace(COALESCE(NULLIF(trim(e.event_title), ''),
                        trim(concat(COALESCE(ec.event_code, ''), ' ', et.event_type))), 'Hurling', 'Camogie')
                ELSE
                    COALESCE(NULLIF(trim(e.event_title), ''),
                        trim(concat(COALESCE(ec.event_code, ''), ' ', et.event_type)))
                END AS title,
                t.team_name,
                et.event_type,
                to_char(e.event_date_time::timestamp, 'YYYY-MM-DD"T"HH24:MI:SS') AS local_time,
                e.meet_time,
                e.location_name,
                e.location_pin,
                e.opposition,
                e.home_away,
                e.event_details,
                e.status,
                sq.squad_name,
                e.created_at
            FROM public.events e
            JOIN public.teams t ON t.team_id = e.team_id
            JOIN public.event_types et ON et.event_type_id = e.event_type_id
            LEFT JOIN public.event_codes ec ON ec.code_id = e.event_code_id
            LEFT JOIN public.roles ar ON ar.role_id = e.audience_id
            LEFT JOIN public.squads sq ON sq.squad_id = e.squad_id
            WHERE e.status IS DISTINCT FROM 'deleted'
              AND e.event_date_time >= CURRENT_DATE - 30
              AND EXISTS (
                  SELECT 1
                  FROM public.user_member_link uml
                  JOIN public.member_team_link mtl
                    ON mtl.member_id = uml.member_id AND mtl.team_id = e.team_id AND mtl.status = 'active'
                  JOIN public.member_team_role_link mtrl ON mtrl.member_team_id = mtl.member_team_id
                  JOIN public.roles r ON r.role_id = mtrl.role_id
                  WHERE uml.user_id = v_uid
                    AND uml.status = 'active'
                    AND (
                        r.role_grade = 100
                        OR (
                            r.role_level >= COALESCE(ar.role_level, 0)
                            AND (
                                e.squad_id IS NULL
                                OR EXISTS (
                                    SELECT 1 FROM public.member_squad_link msl
                                    WHERE msl.member_id = uml.member_id
                                      AND msl.squad_id = e.squad_id
                                      AND msl.code_id = public.get_updated_event_code(e.event_id)
                                )
                            )
                        )
                    )
              )
        ) x
    ), '[]'::jsonb));
END;
$function$;

REVOKE ALL ON FUNCTION public.get_calendar_feed(text) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.get_calendar_feed(text) TO service_role;
