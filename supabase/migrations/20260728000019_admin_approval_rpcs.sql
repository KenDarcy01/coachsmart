-- New RPCs for the admin member-approval queue.
--
-- get_pending_team_requests   — list all pending join/access requests for a team
-- confirm_member_join         — approve a new member, assign their role
-- deny_member_join            — reject a new member request
-- request_member_access       — second user (e.g. other parent) requests access to an existing member
-- confirm_user_member_access  — admin approves second-user access
-- deny_user_member_access     — admin rejects second-user access


-- ─────────────────────────────────────────────────────────────────────────────
-- get_pending_team_requests
-- Returns two arrays:
--   member_requests  — pending member_team_link rows (new member waiting to join)
--   access_requests  — pending user_member_link rows (second user wants access to existing member)
-- Also returns available roles for the team so the admin UI can build the role picker.
-- Only callable by authenticated users who are active admins (role_grade = 100) on the team.
-- ─────────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.get_pending_team_requests(p_team_id bigint)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = 'public'
AS $$
DECLARE
    v_caller uuid := auth.uid();
BEGIN
    -- Verify caller is an active admin on this team
    IF NOT EXISTS (
        SELECT 1
          FROM public.user_member_link   uml
          JOIN public.member_team_link   mtl  ON uml.member_id  = mtl.member_id
          JOIN public.member_team_role_link mtrl ON mtl.member_team_id = mtrl.member_team_id
          JOIN public.roles              r    ON mtrl.role_id    = r.role_id
         WHERE uml.user_id   = v_caller
           AND uml.status    = 'active'
           AND mtl.team_id   = p_team_id
           AND mtl.status    = 'active'
           AND r.role_grade  = 100
    ) THEN
        RETURN jsonb_build_object(
            'success', false,
            'message', 'Access denied.'
        );
    END IF;

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


-- ─────────────────────────────────────────────────────────────────────────────
-- confirm_member_join
-- Admin approves a pending new-member request and assigns their role.
-- ─────────────────────────────────────────────────────────────────────────────
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
    v_caller     uuid := auth.uid();
    v_team_id    bigint;
    v_member_id  bigint;
    v_first_name text;
    v_last_name  text;
    v_team_name  text;
BEGIN
    -- Resolve team and member from the link
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

    -- Verify caller is an active admin on this team
    IF NOT EXISTS (
        SELECT 1
          FROM public.user_member_link   uml
          JOIN public.member_team_link   mtl2 ON uml.member_id    = mtl2.member_id
          JOIN public.member_team_role_link mtrl ON mtl2.member_team_id = mtrl.member_team_id
          JOIN public.roles              r    ON mtrl.role_id      = r.role_id
         WHERE uml.user_id  = v_caller
           AND uml.status   = 'active'
           AND mtl2.team_id = v_team_id
           AND mtl2.status  = 'active'
           AND r.role_grade = 100
    ) THEN
        RETURN json_build_object('success', false, 'message', 'Access denied.');
    END IF;

    -- Confirm the membership
    UPDATE public.member_team_link
       SET status = 'active'
     WHERE member_team_id = p_member_team_id;

    -- Assign the chosen role
    INSERT INTO public.member_team_role_link (member_team_id, role_id)
    VALUES (p_member_team_id, p_role_id)
    ON CONFLICT DO NOTHING;

    -- Notify the member's linked users (the parent/guardian who submitted)
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
        'success',   true,
        'message',   v_first_name || ' ' || v_last_name || ' confirmed as a member of ' || v_team_name || '.'
    );

EXCEPTION WHEN OTHERS THEN
    RETURN json_build_object('success', false, 'message', SQLERRM);
END;
$$;

GRANT EXECUTE ON FUNCTION public.confirm_member_join(bigint, bigint) TO authenticated;
GRANT EXECUTE ON FUNCTION public.confirm_member_join(bigint, bigint) TO service_role;


-- ─────────────────────────────────────────────────────────────────────────────
-- deny_member_join
-- Admin rejects a pending new-member request.
-- Sets member_team_link.status = 'removed' (preserves the record for audit).
-- ─────────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.deny_member_join(p_member_team_id bigint)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = 'public'
AS $$
DECLARE
    v_caller     uuid := auth.uid();
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

    IF NOT EXISTS (
        SELECT 1
          FROM public.user_member_link   uml
          JOIN public.member_team_link   mtl2 ON uml.member_id    = mtl2.member_id
          JOIN public.member_team_role_link mtrl ON mtl2.member_team_id = mtrl.member_team_id
          JOIN public.roles              r    ON mtrl.role_id      = r.role_id
         WHERE uml.user_id  = v_caller
           AND uml.status   = 'active'
           AND mtl2.team_id = v_team_id
           AND mtl2.status  = 'active'
           AND r.role_grade = 100
    ) THEN
        RETURN json_build_object('success', false, 'message', 'Access denied.');
    END IF;

    UPDATE public.member_team_link
       SET status = 'removed'
     WHERE member_team_id = p_member_team_id;

    -- Notify the submitting user
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


-- ─────────────────────────────────────────────────────────────────────────────
-- request_member_access
-- A second user (e.g. other parent) requests access to an existing active member
-- on a team they identify via the team joining code.
-- Creates user_member_link with status = 'pending'; notifies team admins.
-- ─────────────────────────────────────────────────────────────────────────────
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
    -- Resolve team from joining code
    SELECT team_id, team_name INTO v_team_id, v_team_name
      FROM public.teams
     WHERE UPPER(TRIM(team_unique_code)) = v_clean_code;

    IF v_team_id IS NULL THEN
        RETURN json_build_object('success', false, 'message', 'Invalid joining code.');
    END IF;

    -- Verify the member is active on this team
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

    -- Block if this user already has an active or pending link to this member
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

    -- Create the pending access link
    INSERT INTO public.user_member_link (user_id, member_id, status)
    VALUES (v_caller, p_member_id, 'pending');

    -- Notify active admins on the team
    INSERT INTO public.notifications (
        recipient_user_id, team_id,
        app_title, app_body,
        push_title, push_body
    )
    SELECT DISTINCT uml2.user_id,
           v_team_id,
           'Access Request',
           (SELECT first_name || ' ' || last_name FROM public.users WHERE user_id = v_caller) ||
               ' has requested access to ' || v_first_name || ' ' || v_last_name ||
               ' on ' || v_team_name || '.',
           'Access Request',
           (SELECT first_name || ' ' || last_name FROM public.users WHERE user_id = v_caller) ||
               ' has requested access to ' || v_first_name || ' ' || v_last_name || '.'
      FROM public.member_team_link   mtl2
      JOIN public.member_team_role_link mtrl ON mtl2.member_team_id = mtrl.member_team_id
      JOIN public.roles              r    ON mtrl.role_id    = r.role_id
      JOIN public.user_member_link   uml2 ON mtl2.member_id  = uml2.member_id
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


-- ─────────────────────────────────────────────────────────────────────────────
-- confirm_user_member_access
-- Admin approves a pending second-user access request.
-- ─────────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.confirm_user_member_access(p_user_member_id bigint)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = 'public'
AS $$
DECLARE
    v_caller     uuid := auth.uid();
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

    -- Find a team this member is active on (to verify caller is an admin there)
    SELECT mtl.team_id, t.team_name INTO v_team_id, v_team_name
      FROM public.member_team_link mtl
      JOIN public.teams            t ON mtl.team_id = t.team_id
     WHERE mtl.member_id = v_member_id
       AND mtl.status    = 'active'
     LIMIT 1;

    IF NOT EXISTS (
        SELECT 1
          FROM public.user_member_link   uml2
          JOIN public.member_team_link   mtl2 ON uml2.member_id    = mtl2.member_id
          JOIN public.member_team_role_link mtrl ON mtl2.member_team_id = mtrl.member_team_id
          JOIN public.roles              r    ON mtrl.role_id      = r.role_id
         WHERE uml2.user_id  = v_caller
           AND uml2.status   = 'active'
           AND mtl2.team_id  = v_team_id
           AND mtl2.status   = 'active'
           AND r.role_grade  = 100
    ) THEN
        RETURN json_build_object('success', false, 'message', 'Access denied.');
    END IF;

    UPDATE public.user_member_link
       SET status = 'active'
     WHERE user_member_id = p_user_member_id;

    -- Notify the approved user
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


-- ─────────────────────────────────────────────────────────────────────────────
-- deny_user_member_access
-- Admin rejects a pending second-user access request.
-- The user_member_link row is deleted (no historical value for a denied request).
-- ─────────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.deny_user_member_access(p_user_member_id bigint)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = 'public'
AS $$
DECLARE
    v_caller     uuid := auth.uid();
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

    IF NOT EXISTS (
        SELECT 1
          FROM public.user_member_link   uml2
          JOIN public.member_team_link   mtl2 ON uml2.member_id    = mtl2.member_id
          JOIN public.member_team_role_link mtrl ON mtl2.member_team_id = mtrl.member_team_id
          JOIN public.roles              r    ON mtrl.role_id      = r.role_id
         WHERE uml2.user_id  = v_caller
           AND uml2.status   = 'active'
           AND mtl2.team_id  = v_team_id
           AND mtl2.status   = 'active'
           AND r.role_grade  = 100
    ) THEN
        RETURN json_build_object('success', false, 'message', 'Access denied.');
    END IF;

    DELETE FROM public.user_member_link WHERE user_member_id = p_user_member_id;

    -- Notify the denied user
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
