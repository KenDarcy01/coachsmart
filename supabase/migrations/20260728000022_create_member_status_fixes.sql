-- Fix create_new_member_by_code to handle all duplicate/pending scenarios correctly.
--
-- Previous gaps:
--   1. A second user submitting the same name while a pending request from a
--      DIFFERENT user existed would create a duplicate member record.
--   2. The 'already_pending' (same user re-submitting) returned 'pending' with
--      no team_name, making webview messaging vague.
--
-- New return statuses:
--   'pending'       — fresh request created successfully
--   'already_pending' — this user already has a pending request for this name/team
--   'duplicate'     — active member with this name found; webview offers request_member_access
--   'pending_other' — a DIFFERENT user has a pending request for this name; block and advise
--   'error'         — validation failure or unexpected error

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

    -- Check 1: this user already has a pending request for this name on this team.
    -- Handled first so the user gets the most specific message.
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

    -- Check 2: any other member (active OR pending from a DIFFERENT user) with this
    -- name on the team.  Excludes members this user already owns (covered by check 1).
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
            -- Member is confirmed and active — offer to link via request_member_access
            RETURN jsonb_build_object(
                'status',    'duplicate',
                'member_id', v_existing_member_id,
                'team_name', v_team_name,
                'message',   v_clean_first || ' ' || v_clean_last ||
                             ' is already an active member of ' || v_team_name || '.'
            );
        ELSE
            -- Member is pending from a different user — block to prevent duplicates
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

    -- All clear — create the pending member
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
        recipient_user_id, team_id, app_title, app_body, push_title, push_body
    )
    SELECT DISTINCT uml2.user_id, v_team_id,
        'New Join Request',
        v_clean_first || ' ' || v_clean_last || ' has requested to join ' || v_team_name || '.',
        'New Join Request',
        v_clean_first || ' ' || v_clean_last || ' has requested to join ' || v_team_name || '.'
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
