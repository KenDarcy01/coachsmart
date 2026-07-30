-- Remove the admin-role guard from all approval RPCs.
-- Access is controlled in FlutterFlow (page only visible to admins).

CREATE OR REPLACE FUNCTION public.get_pending_team_requests(p_team_id bigint)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = 'public'
AS $$
BEGIN
    RETURN jsonb_build_object(
        'success', true,
        'member_requests', COALESCE((
            SELECT jsonb_agg(
                jsonb_build_object(
                    'member_team_id',       mtl.member_team_id,
                    'member_id',            m.member_id,
                    'first_name',           m.first_name,
                    'last_name',            m.last_name,
                    'requested_at',         mtl.created_at,
                    'requested_by_user_id', uml.user_id,
                    'requested_by_name',    u.first_name || ' ' || u.last_name
                )
                ORDER BY mtl.created_at ASC
            )
              FROM public.member_team_link   mtl
              JOIN public.members            m   ON mtl.member_id  = m.member_id
              JOIN public.user_member_link   uml ON m.member_id    = uml.member_id
              JOIN public.users              u   ON uml.user_id    = u.user_id
             WHERE mtl.team_id  = p_team_id
               AND mtl.status   = 'pending'
               AND uml.status   = 'active'
        ), '[]'::jsonb),
        'access_requests', COALESCE((
            SELECT jsonb_agg(
                jsonb_build_object(
                    'user_member_id',         uml.user_member_id,
                    'member_id',              m.member_id,
                    'first_name',             m.first_name,
                    'last_name',              m.last_name,
                    'requesting_user_id',     u.user_id,
                    'requesting_user_name',   u.first_name || ' ' || u.last_name,
                    'requesting_user_email',  u.email_address,
                    'requested_at',           uml.created_at
                )
                ORDER BY uml.created_at ASC
            )
              FROM public.user_member_link uml
              JOIN public.members          m   ON uml.member_id = m.member_id
              JOIN public.users            u   ON uml.user_id   = u.user_id
              JOIN public.member_team_link mtl ON m.member_id   = mtl.member_id
             WHERE mtl.team_id  = p_team_id
               AND mtl.status   = 'active'
               AND uml.status   = 'pending'
        ), '[]'::jsonb),
        'available_roles', COALESCE((
            SELECT jsonb_agg(
                jsonb_build_object(
                    'role_id',    r.role_id,
                    'role_name',  r.role_name,
                    'role_grade', r.role_grade,
                    'role_level', r.role_level
                )
                ORDER BY r.role_grade DESC, r.role_level DESC
            )
              FROM public.team_roles_link trl
              JOIN public.roles           r ON trl.role_id = r.role_id
             WHERE trl.team_id = p_team_id
        ), '[]'::jsonb)
    );

EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object('success', false, 'message', SQLERRM);
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_pending_team_requests(bigint) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_pending_team_requests(bigint) TO service_role;


CREATE OR REPLACE FUNCTION public.confirm_member_join(
    p_member_team_id bigint,
    p_role_id        bigint
)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = 'public'
AS $$
DECLARE
    v_team_id    bigint;
    v_member_id  bigint;
    v_first_name text;
    v_last_name  text;
    v_team_name  text;
BEGIN
    SELECT mtl.team_id, mtl.member_id, m.first_name, m.last_name, t.team_name
      INTO v_team_id, v_member_id, v_first_name, v_last_name, v_team_name
      FROM public.member_team_link mtl
      JOIN public.members          m  ON mtl.member_id = m.member_id
      JOIN public.teams            t  ON mtl.team_id   = t.team_id
     WHERE mtl.member_team_id = p_member_team_id
       AND mtl.status         = 'pending';

    IF v_team_id IS NULL THEN
        RETURN json_build_object('success', false, 'message', 'Pending request not found.');
    END IF;

    UPDATE public.member_team_link
       SET status = 'active'
     WHERE member_team_id = p_member_team_id;

    INSERT INTO public.member_team_role_link (member_team_id, role_id)
    VALUES (p_member_team_id, p_role_id)
    ON CONFLICT DO NOTHING;

    INSERT INTO public.notifications (
        recipient_user_id, team_id,
        app_title, app_body,
        push_title, push_body
    )
    SELECT uml.user_id,
           v_team_id,
           'Request Approved',
           v_first_name || ' ' || v_last_name || ' has been confirmed as a member of ' || v_team_name || '.',
           'Request Approved',
           v_first_name || ' ' || v_last_name || ' has been confirmed as a member of ' || v_team_name || '.'
      FROM public.user_member_link uml
     WHERE uml.member_id = v_member_id
       AND uml.status    = 'active';

    RETURN json_build_object(
        'success', true,
        'message', v_first_name || ' ' || v_last_name || ' confirmed as a member of ' || v_team_name || '.'
    );

EXCEPTION WHEN OTHERS THEN
    RETURN json_build_object('success', false, 'message', SQLERRM);
END;
$$;

GRANT EXECUTE ON FUNCTION public.confirm_member_join(bigint, bigint) TO authenticated;
GRANT EXECUTE ON FUNCTION public.confirm_member_join(bigint, bigint) TO service_role;


CREATE OR REPLACE FUNCTION public.deny_member_join(p_member_team_id bigint)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = 'public'
AS $$
DECLARE
    v_team_id    bigint;
    v_member_id  bigint;
    v_first_name text;
    v_last_name  text;
    v_team_name  text;
BEGIN
    SELECT mtl.team_id, mtl.member_id, m.first_name, m.last_name, t.team_name
      INTO v_team_id, v_member_id, v_first_name, v_last_name, v_team_name
      FROM public.member_team_link mtl
      JOIN public.members          m  ON mtl.member_id = m.member_id
      JOIN public.teams            t  ON mtl.team_id   = t.team_id
     WHERE mtl.member_team_id = p_member_team_id
       AND mtl.status         = 'pending';

    IF v_team_id IS NULL THEN
        RETURN json_build_object('success', false, 'message', 'Pending request not found.');
    END IF;

    UPDATE public.member_team_link
       SET status = 'removed'
     WHERE member_team_id = p_member_team_id;

    INSERT INTO public.notifications (
        recipient_user_id, team_id,
        app_title, app_body,
        push_title, push_body
    )
    SELECT uml.user_id,
           v_team_id,
           'Request Not Approved',
           'The request for ' || v_first_name || ' ' || v_last_name ||
               ' to join ' || v_team_name || ' was not approved. Please contact your team admin.',
           'Request Not Approved',
           'The request for ' || v_first_name || ' ' || v_last_name ||
               ' to join ' || v_team_name || ' was not approved.'
      FROM public.user_member_link uml
     WHERE uml.member_id = v_member_id
       AND uml.status    = 'active';

    RETURN json_build_object('success', true, 'message', 'Request denied.');

EXCEPTION WHEN OTHERS THEN
    RETURN json_build_object('success', false, 'message', SQLERRM);
END;
$$;

GRANT EXECUTE ON FUNCTION public.deny_member_join(bigint) TO authenticated;
GRANT EXECUTE ON FUNCTION public.deny_member_join(bigint) TO service_role;


CREATE OR REPLACE FUNCTION public.confirm_user_member_access(p_user_member_id bigint)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = 'public'
AS $$
DECLARE
    v_user_id    uuid;
    v_member_id  bigint;
    v_first_name text;
    v_last_name  text;
    v_team_id    bigint;
    v_team_name  text;
BEGIN
    SELECT uml.user_id, uml.member_id, m.first_name, m.last_name
      INTO v_user_id, v_member_id, v_first_name, v_last_name
      FROM public.user_member_link uml
      JOIN public.members          m ON uml.member_id = m.member_id
     WHERE uml.user_member_id = p_user_member_id
       AND uml.status         = 'pending';

    IF v_user_id IS NULL THEN
        RETURN json_build_object('success', false, 'message', 'Pending request not found.');
    END IF;

    SELECT mtl.team_id, t.team_name INTO v_team_id, v_team_name
      FROM public.member_team_link mtl
      JOIN public.teams            t ON mtl.team_id = t.team_id
     WHERE mtl.member_id = v_member_id
       AND mtl.status    = 'active'
     LIMIT 1;

    UPDATE public.user_member_link
       SET status = 'active'
     WHERE user_member_id = p_user_member_id;

    INSERT INTO public.notifications (
        recipient_user_id, team_id,
        app_title, app_body,
        push_title, push_body
    )
    VALUES (
        v_user_id, v_team_id,
        'Access Approved',
        'You now have access to ' || v_first_name || ' ' || v_last_name ||
            '''s profile on ' || COALESCE(v_team_name, 'your team') || '.',
        'Access Approved',
        'You now have access to ' || v_first_name || ' ' || v_last_name || '''s profile.'
    );

    RETURN json_build_object('success', true, 'message', 'Access granted.');

EXCEPTION WHEN OTHERS THEN
    RETURN json_build_object('success', false, 'message', SQLERRM);
END;
$$;

GRANT EXECUTE ON FUNCTION public.confirm_user_member_access(bigint) TO authenticated;
GRANT EXECUTE ON FUNCTION public.confirm_user_member_access(bigint) TO service_role;


CREATE OR REPLACE FUNCTION public.deny_user_member_access(p_user_member_id bigint)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = 'public'
AS $$
DECLARE
    v_user_id    uuid;
    v_member_id  bigint;
    v_first_name text;
    v_last_name  text;
    v_team_id    bigint;
BEGIN
    SELECT uml.user_id, uml.member_id, m.first_name, m.last_name
      INTO v_user_id, v_member_id, v_first_name, v_last_name
      FROM public.user_member_link uml
      JOIN public.members          m ON uml.member_id = m.member_id
     WHERE uml.user_member_id = p_user_member_id
       AND uml.status         = 'pending';

    IF v_user_id IS NULL THEN
        RETURN json_build_object('success', false, 'message', 'Pending request not found.');
    END IF;

    SELECT mtl.team_id INTO v_team_id
      FROM public.member_team_link mtl
     WHERE mtl.member_id = v_member_id AND mtl.status = 'active'
     LIMIT 1;

    DELETE FROM public.user_member_link WHERE user_member_id = p_user_member_id;

    INSERT INTO public.notifications (
        recipient_user_id, team_id,
        app_title, app_body,
        push_title, push_body
    )
    VALUES (
        v_user_id, v_team_id,
        'Access Request Not Approved',
        'Your request to access ' || v_first_name || ' ' || v_last_name ||
            '''s profile was not approved. Please contact your team admin.',
        'Access Not Approved',
        'Your request to access ' || v_first_name || ' ' || v_last_name || '''s profile was not approved.'
    );

    RETURN json_build_object('success', true, 'message', 'Request denied.');

EXCEPTION WHEN OTHERS THEN
    RETURN json_build_object('success', false, 'message', SQLERRM);
END;
$$;

GRANT EXECUTE ON FUNCTION public.deny_user_member_access(bigint) TO authenticated;
GRANT EXECUTE ON FUNCTION public.deny_user_member_access(bigint) TO service_role;
