-- Return member_id in the 'duplicate' response from create_new_member_by_code.
-- The onboarding webview needs this to call request_member_access() directly
-- without a separate lookup when an existing active member is found on the roster.
-- All other behaviour is unchanged.

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
    v_new_member_id      bigint;
    v_new_member_team_id bigint;
    v_existing_member_id bigint;
    v_team_id            bigint;
    v_club_id            bigint;
    v_user_id            uuid;
    v_team_name          text;
    v_no_team_squad_id   bigint;
    v_clean_first        text := INITCAP(TRIM(COALESCE(p_first_name, '')));
    v_clean_last         text := INITCAP(TRIM(COALESCE(p_last_name, '')));
    v_clean_code         text := UPPER(TRIM(COALESCE(p_joining_code, '')));
    v_default_pic        text := 'https://storage.googleapis.com/flutterflow-io-6f20.appspot.com/projects/hvxmhKxoCA4XCjUFmpM6/assets/50b842h4zvrj/image-removebg-preview_(14).png';
BEGIN
    v_user_id := auth.uid();

    IF v_clean_first = '' OR v_clean_last = '' OR v_clean_code = '' THEN
        RETURN jsonb_build_object(
            'status',  'error',
            'message', 'First name, Last name, and Joining Code are all required.'
        );
    END IF;

    SELECT team_id, club_id, team_name
      INTO v_team_id, v_club_id, v_team_name
      FROM public.teams
     WHERE UPPER(TRIM(team_unique_code)) = v_clean_code;

    IF v_team_id IS NULL THEN
        RETURN jsonb_build_object(
            'status',  'error',
            'message', 'The joining code "' || p_joining_code || '" is not valid.'
        );
    END IF;

    SELECT squad_id INTO v_no_team_squad_id
      FROM public.squads
     WHERE team_id = v_team_id AND squad_name = 'No Team'
     LIMIT 1;

    -- Check for an active member with this name on the team.
    -- Capture their member_id so the webview can call request_member_access().
    SELECT m.member_id INTO v_existing_member_id
      FROM public.member_team_link mtl
      JOIN public.members m ON mtl.member_id = m.member_id
     WHERE mtl.team_id  = v_team_id
       AND mtl.status   = 'active'
       AND m.first_name = v_clean_first
       AND m.last_name  = v_clean_last
     LIMIT 1;

    IF v_existing_member_id IS NOT NULL THEN
        RETURN jsonb_build_object(
            'status',    'duplicate',
            'member_id', v_existing_member_id,
            'team_name', v_team_name,
            'message',   v_clean_first || ' ' || v_clean_last ||
                         ' is already an active member of this team. ' ||
                         'If this is them, confirm below to request access.'
        );
    END IF;

    -- Guard: prevent same user resubmitting the same pending name on this team
    IF EXISTS (
        SELECT 1
          FROM public.member_team_link  mtl
          JOIN public.members           m   ON mtl.member_id  = m.member_id
          JOIN public.user_member_link  uml ON m.member_id    = uml.member_id
         WHERE mtl.team_id  = v_team_id
           AND mtl.status   = 'pending'
           AND uml.user_id  = v_user_id
           AND uml.status   = 'active'
           AND m.first_name = v_clean_first
           AND m.last_name  = v_clean_last
    ) THEN
        RETURN jsonb_build_object(
            'status',  'pending',
            'message', 'A request for ' || v_clean_first || ' ' || v_clean_last ||
                       ' to join ' || v_team_name || ' is already awaiting admin approval.'
        );
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
        push_title, push_body
    )
    SELECT DISTINCT
        uml2.user_id,
        v_team_id,
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
        'message',   'Your request to join ' || v_team_name ||
                     ' has been sent. An admin will confirm your membership shortly.'
    );

EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object('status', 'error', 'message', SQLERRM);
END;
$$;

GRANT EXECUTE ON FUNCTION public.create_new_member_by_code(text, text, text) TO anon;
GRANT EXECUTE ON FUNCTION public.create_new_member_by_code(text, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.create_new_member_by_code(text, text, text) TO service_role;
