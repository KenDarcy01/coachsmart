-- When any admin acts on a join/access request, mark ALL other admins'
-- notifications for the same request as read. This disables the action
-- buttons in real-time via the existing Supabase realtime subscription,
-- preventing a second admin from approving or denying an already-resolved request.

-- ─── confirm_member_join ──────────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION public.confirm_member_join(
    p_member_team_id bigint,
    p_role_ids       bigint[]
)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = 'public'
AS $$
DECLARE
    v_team_id    bigint;
    v_club_id    bigint;
    v_member_id  bigint;
    v_first_name text;
    v_last_name  text;
    v_team_name  text;
BEGIN
    IF p_role_ids IS NULL OR array_length(p_role_ids, 1) IS NULL THEN
        RETURN json_build_object('success', false, 'message', 'At least one role must be provided.');
    END IF;

    SELECT mtl.team_id, t.club_id, mtl.member_id, m.first_name, m.last_name, t.team_name
      INTO v_team_id, v_club_id, v_member_id, v_first_name, v_last_name, v_team_name
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
    SELECT p_member_team_id, unnest(p_role_ids)
    ON CONFLICT DO NOTHING;

    UPDATE public.users
       SET onboarding_status = 'active',
           default_club      = COALESCE(default_club, v_club_id)
      FROM public.user_member_link uml
     WHERE uml.member_id = v_member_id
       AND uml.status    = 'active'
       AND public.users.user_id = uml.user_id;

    -- Mark all admin notifications for this request as read so peer admins
    -- see the buttons disabled in real-time.
    UPDATE public.notifications
       SET is_read   = true,
           when_read = now()
     WHERE action        = 'approve_member'
       AND action_ref_id = p_member_team_id
       AND is_read       = false;

    INSERT INTO public.notifications (
        recipient_user_id, team_id,
        app_title, app_body,
        push_title, push_body,
        delivery_method
    )
    SELECT uml.user_id,
           v_team_id,
           'Request Approved',
           v_first_name || ' ' || v_last_name || ' has been confirmed as a member of ' || v_team_name || '.',
           'Request Approved',
           v_first_name || ' ' || v_last_name || ' has been confirmed as a member of ' || v_team_name || '.',
           'push'
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

GRANT EXECUTE ON FUNCTION public.confirm_member_join(bigint, bigint[]) TO authenticated;
GRANT EXECUTE ON FUNCTION public.confirm_member_join(bigint, bigint[]) TO service_role;

-- ─── deny_member_join ─────────────────────────────────────────────────────────

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

    -- Mark all admin notifications for this request as read so peer admins
    -- see the buttons disabled in real-time.
    UPDATE public.notifications
       SET is_read   = true,
           when_read = now()
     WHERE action        = 'approve_member'
       AND action_ref_id = p_member_team_id
       AND is_read       = false;

    INSERT INTO public.notifications (
        recipient_user_id, team_id,
        app_title, app_body,
        push_title, push_body,
        delivery_method
    )
    SELECT uml.user_id,
           v_team_id,
           'Request Not Approved',
           'The request for ' || v_first_name || ' ' || v_last_name ||
               ' to join ' || v_team_name || ' was not approved. Please contact your team admin.',
           'Request Not Approved',
           'The request for ' || v_first_name || ' ' || v_last_name ||
               ' to join ' || v_team_name || ' was not approved.',
           'push'
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

-- ─── confirm_user_member_access ───────────────────────────────────────────────

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

    -- Mark all admin notifications for this request as read so peer admins
    -- see the buttons disabled in real-time.
    UPDATE public.notifications
       SET is_read   = true,
           when_read = now()
     WHERE action        = 'approve_access'
       AND action_ref_id = p_user_member_id
       AND is_read       = false;

    INSERT INTO public.notifications (
        recipient_user_id, team_id,
        app_title, app_body,
        push_title, push_body,
        delivery_method
    )
    VALUES (
        v_user_id, v_team_id,
        'Access Approved',
        'You now have access to ' || v_first_name || ' ' || v_last_name ||
            '''s profile on ' || COALESCE(v_team_name, 'your team') || '.',
        'Access Approved',
        'You now have access to ' || v_first_name || ' ' || v_last_name || '''s profile.',
        'push'
    );

    RETURN json_build_object('success', true, 'message', 'Access granted.');

EXCEPTION WHEN OTHERS THEN
    RETURN json_build_object('success', false, 'message', SQLERRM);
END;
$$;

GRANT EXECUTE ON FUNCTION public.confirm_user_member_access(bigint) TO authenticated;
GRANT EXECUTE ON FUNCTION public.confirm_user_member_access(bigint) TO service_role;

-- ─── deny_user_member_access ──────────────────────────────────────────────────

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

    -- Mark all admin notifications for this request as read so peer admins
    -- see the buttons disabled in real-time.
    UPDATE public.notifications
       SET is_read   = true,
           when_read = now()
     WHERE action        = 'approve_access'
       AND action_ref_id = p_user_member_id
       AND is_read       = false;

    INSERT INTO public.notifications (
        recipient_user_id, team_id,
        app_title, app_body,
        push_title, push_body,
        delivery_method
    )
    VALUES (
        v_user_id, v_team_id,
        'Access Request Not Approved',
        'Your request to access ' || v_first_name || ' ' || v_last_name ||
            '''s profile was not approved. Please contact your team admin.',
        'Access Not Approved',
        'Your request to access ' || v_first_name || ' ' || v_last_name || '''s profile was not approved.',
        'push'
    );

    RETURN json_build_object('success', true, 'message', 'Request denied.');

EXCEPTION WHEN OTHERS THEN
    RETURN json_build_object('success', false, 'message', SQLERRM);
END;
$$;

GRANT EXECUTE ON FUNCTION public.deny_user_member_access(bigint) TO authenticated;
GRANT EXECUTE ON FUNCTION public.deny_user_member_access(bigint) TO service_role;
