-- Add delivery_method = 'push' to the notification INSERT in
-- request_member_access. Without it the cron job silently skips the row
-- and team admins never receive the access-request alert.

CREATE OR REPLACE FUNCTION public.request_member_access(
    p_member_id    bigint,
    p_joining_code text
)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = 'public'
AS $$
DECLARE
    v_caller     uuid := auth.uid();
    v_team_id    bigint;
    v_team_name  text;
    v_first_name text;
    v_last_name  text;
    v_clean_code text := UPPER(TRIM(COALESCE(p_joining_code, '')));
BEGIN
    SELECT team_id, team_name INTO v_team_id, v_team_name
      FROM public.teams
     WHERE UPPER(TRIM(team_unique_code)) = v_clean_code;

    IF v_team_id IS NULL THEN
        RETURN json_build_object('success', false, 'message', 'Invalid joining code.');
    END IF;

    SELECT m.first_name, m.last_name
      INTO v_first_name, v_last_name
      FROM public.members          m
      JOIN public.member_team_link mtl ON m.member_id = mtl.member_id
     WHERE m.member_id  = p_member_id
       AND mtl.team_id  = v_team_id
       AND mtl.status   = 'active';

    IF v_first_name IS NULL THEN
        RETURN json_build_object('success', false, 'message', 'Member not found on this team.');
    END IF;

    IF EXISTS (
        SELECT 1 FROM public.user_member_link
         WHERE user_id   = v_caller
           AND member_id = p_member_id
           AND status    IN ('active', 'pending')
    ) THEN
        RETURN json_build_object(
            'success', false,
            'message', 'You already have an active or pending link to this member.'
        );
    END IF;

    INSERT INTO public.user_member_link (user_id, member_id, status)
    VALUES (v_caller, p_member_id, 'pending');

    INSERT INTO public.notifications (
        recipient_user_id, team_id,
        app_title, app_body,
        push_title, push_body,
        delivery_method
    )
    SELECT DISTINCT uml2.user_id,
           v_team_id,
           'Access Request',
           (SELECT first_name || ' ' || last_name FROM public.users WHERE user_id = v_caller) ||
               ' has requested access to ' || v_first_name || ' ' || v_last_name ||
               ' on ' || v_team_name || '.',
           'Access Request',
           (SELECT first_name || ' ' || last_name FROM public.users WHERE user_id = v_caller) ||
               ' has requested access to ' || v_first_name || ' ' || v_last_name || '.',
           'push'
      FROM public.member_team_link     mtl2
      JOIN public.member_team_role_link mtrl ON mtl2.member_team_id = mtrl.member_team_id
      JOIN public.roles                r    ON mtrl.role_id    = r.role_id
      JOIN public.user_member_link     uml2 ON mtl2.member_id  = uml2.member_id
     WHERE mtl2.team_id  = v_team_id
       AND mtl2.status   = 'active'
       AND uml2.status   = 'active'
       AND r.role_grade  = 100;

    RETURN json_build_object(
        'success', true,
        'message', 'Your request to access ' || v_first_name || ' ' || v_last_name ||
                   '''s profile has been sent to the ' || v_team_name || ' admin.'
    );

EXCEPTION WHEN OTHERS THEN
    RETURN json_build_object('success', false, 'message', SQLERRM);
END;
$$;

GRANT EXECUTE ON FUNCTION public.request_member_access(bigint, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.request_member_access(bigint, text) TO service_role;
