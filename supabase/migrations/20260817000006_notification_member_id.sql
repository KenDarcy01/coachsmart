-- Add member_id to notifications so the recipient can identify the member
-- involved without a separate lookup. NULL for notifications that have no
-- associated member (e.g. event reminders, attendance updates).
--
-- Populated for approve_member (member joining team) and approve_access
-- (user requesting profile access) — the two cases where an admin needs
-- to know which member the action relates to.

ALTER TABLE public.notifications ADD COLUMN IF NOT EXISTS member_id bigint;

-- ─── get_user_notifications ───────────────────────────────────────────────────

DROP FUNCTION IF EXISTS public.get_user_notifications(uuid);

CREATE FUNCTION public.get_user_notifications(p_user_id uuid)
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
            WHEN n.created_at > now() - interval '24 hours'   THEN
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
    ORDER BY n.created_at DESC;
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_user_notifications(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_user_notifications(uuid) TO service_role;

-- ─── create_new_member_by_code ────────────────────────────────────────────────
-- member_id = v_new_member_id (the newly created member record)

CREATE OR REPLACE FUNCTION public.create_new_member_by_code(
    p_first_name   text,
    p_last_name    text,
    p_joining_code text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = 'public'
AS $$
DECLARE
    v_new_member_id       bigint;
    v_new_member_team_id  bigint;
    v_existing_member_id  bigint;
    v_existing_mtl_status text;
    v_team_id             bigint;
    v_club_id             bigint;
    v_user_id             uuid;
    v_team_name           text;
    v_no_team_squad_id    bigint;
    v_clean_first         text := INITCAP(TRIM(COALESCE(p_first_name, '')));
    v_clean_last          text := INITCAP(TRIM(COALESCE(p_last_name, '')));
    v_clean_code          text := UPPER(TRIM(COALESCE(p_joining_code, '')));
    v_default_pic         text := 'https://storage.googleapis.com/flutterflow-io-6f20.appspot.com/projects/hvxmhKxoCA4XCjUFmpM6/assets/50b842h4zvrj/image-removebg-preview_(14).png';
BEGIN
    v_user_id := auth.uid();

    IF v_clean_first = '' OR v_clean_last = '' OR v_clean_code = '' THEN
        RETURN jsonb_build_object('status', 'error',
            'message', 'First name, Last name, and Joining Code are all required.');
    END IF;

    SELECT team_id, club_id, team_name
      INTO v_team_id, v_club_id, v_team_name
      FROM public.teams
     WHERE UPPER(TRIM(team_unique_code)) = v_clean_code;

    IF v_team_id IS NULL THEN
        RETURN jsonb_build_object('status', 'error',
            'message', 'The joining code "' || p_joining_code || '" is not valid.');
    END IF;

    SELECT squad_id INTO v_no_team_squad_id
      FROM public.squads
     WHERE team_id = v_team_id AND squad_name = 'No Team'
     LIMIT 1;

    IF EXISTS (
        SELECT 1
          FROM public.member_team_link  mtl
          JOIN public.members           m   ON mtl.member_id = m.member_id
          JOIN public.user_member_link  uml ON m.member_id   = uml.member_id
         WHERE mtl.team_id  = v_team_id
           AND mtl.status   = 'active'
           AND uml.user_id  = v_user_id
           AND uml.status   = 'active'
           AND m.first_name = v_clean_first
           AND m.last_name  = v_clean_last
    ) THEN
        RETURN jsonb_build_object(
            'status',    'already_member',
            'team_name', v_team_name,
            'message',   v_clean_first || ' ' || v_clean_last ||
                         ' is already linked to your account on ' || v_team_name || '.'
        );
    END IF;

    IF EXISTS (
        SELECT 1
          FROM public.member_team_link  mtl
          JOIN public.members           m   ON mtl.member_id = m.member_id
          JOIN public.user_member_link  uml ON m.member_id   = uml.member_id
         WHERE mtl.team_id  = v_team_id
           AND mtl.status   = 'pending'
           AND uml.user_id  = v_user_id
           AND uml.status   = 'active'
           AND m.first_name = v_clean_first
           AND m.last_name  = v_clean_last
    ) THEN
        RETURN jsonb_build_object(
            'status',    'already_pending',
            'team_name', v_team_name,
            'message',   'You have already submitted a request for ' ||
                         v_clean_first || ' ' || v_clean_last ||
                         ' to join ' || v_team_name || '. It is awaiting admin approval.'
        );
    END IF;

    SELECT m.member_id, mtl.status
      INTO v_existing_member_id, v_existing_mtl_status
      FROM public.member_team_link mtl
      JOIN public.members          m ON mtl.member_id = m.member_id
     WHERE mtl.team_id  = v_team_id
       AND mtl.status   IN ('active', 'pending')
       AND m.first_name = v_clean_first
       AND m.last_name  = v_clean_last
       AND NOT EXISTS (
           SELECT 1 FROM public.user_member_link uml2
            WHERE uml2.member_id = m.member_id
              AND uml2.user_id   = v_user_id
              AND uml2.status    = 'active'
       )
     LIMIT 1;

    IF v_existing_member_id IS NOT NULL THEN
        IF v_existing_mtl_status = 'active' THEN
            RETURN jsonb_build_object(
                'status',    'duplicate',
                'member_id', v_existing_member_id,
                'team_name', v_team_name,
                'message',   v_clean_first || ' ' || v_clean_last ||
                             ' is already an active member of ' || v_team_name || '.'
            );
        ELSE
            RETURN jsonb_build_object(
                'status',    'pending_other',
                'team_name', v_team_name,
                'message',   'A request for ' || v_clean_first || ' ' || v_clean_last ||
                             ' to join ' || v_team_name ||
                             ' is already waiting for admin approval. ' ||
                             'Once it is confirmed, contact your team admin to link your account.'
            );
        END IF;
    END IF;

    INSERT INTO public.members (first_name, last_name, user_id, profile_pic)
    VALUES (v_clean_first, v_clean_last, v_user_id, v_default_pic)
    RETURNING member_id INTO v_new_member_id;

    INSERT INTO public.user_member_link (user_id, member_id, status)
    VALUES (v_user_id, v_new_member_id, 'active');

    INSERT INTO public.member_team_link (member_id, team_id, squad_id, member_team_code, status)
    VALUES (v_new_member_id, v_team_id, v_no_team_squad_id, v_clean_code, 'pending')
    RETURNING member_team_id INTO v_new_member_team_id;

    INSERT INTO public.member_squad_link (member_id, team_id, code_id, squad_id)
    SELECT v_new_member_id, v_team_id, code_id, v_no_team_squad_id
      FROM public.club_code_link
     WHERE club_id = v_club_id AND code_id > 1;

    INSERT INTO public.notifications (
        recipient_user_id, team_id,
        app_title, app_body,
        push_title, push_body,
        delivery_method,
        action, action_ref_id, member_id
    )
    SELECT DISTINCT uml2.user_id, v_team_id,
        'New Join Request',
        v_clean_first || ' ' || v_clean_last || ' has requested to join ' || v_team_name || '.',
        'New Join Request',
        v_clean_first || ' ' || v_clean_last || ' has requested to join ' || v_team_name || '.',
        'push',
        'approve_member',
        v_new_member_team_id,
        v_new_member_id
      FROM public.member_team_link      mtl2
      JOIN public.member_team_role_link mtrl2 ON mtl2.member_team_id = mtrl2.member_team_id
      JOIN public.roles                 r2    ON mtrl2.role_id        = r2.role_id
      JOIN public.user_member_link      uml2  ON mtl2.member_id       = uml2.member_id
     WHERE mtl2.team_id  = v_team_id
       AND mtl2.status   = 'active'
       AND uml2.status   = 'active'
       AND r2.role_grade = 100;

    RETURN jsonb_build_object(
        'status',    'pending',
        'member_id', v_new_member_id,
        'team_name', v_team_name,
        'message',   'Your request for ' || v_clean_first || ' ' || v_clean_last ||
                     ' to join ' || v_team_name ||
                     ' has been sent. An admin will confirm the membership shortly.'
    );

EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object('status', 'error', 'message', SQLERRM);
END;
$$;

GRANT EXECUTE ON FUNCTION public.create_new_member_by_code(text, text, text) TO anon;
GRANT EXECUTE ON FUNCTION public.create_new_member_by_code(text, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.create_new_member_by_code(text, text, text) TO service_role;

-- ─── request_member_access ────────────────────────────────────────────────────
-- member_id = p_member_id (the member whose profile is being requested)

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
    v_caller         uuid := auth.uid();
    v_team_id        bigint;
    v_team_name      text;
    v_first_name     text;
    v_last_name      text;
    v_user_member_id bigint;
    v_clean_code     text := UPPER(TRIM(COALESCE(p_joining_code, '')));
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
    VALUES (v_caller, p_member_id, 'pending')
    RETURNING user_member_id INTO v_user_member_id;

    INSERT INTO public.notifications (
        recipient_user_id, team_id,
        app_title, app_body,
        push_title, push_body,
        delivery_method,
        action, action_ref_id, member_id
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
           'push',
           'approve_access',
           v_user_member_id,
           p_member_id
      FROM public.member_team_link      mtl2
      JOIN public.member_team_role_link mtrl ON mtl2.member_team_id = mtrl.member_team_id
      JOIN public.roles                 r    ON mtrl.role_id    = r.role_id
      JOIN public.user_member_link      uml2 ON mtl2.member_id  = uml2.member_id
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
