-- Team-only codes.
--
-- club_code_link rows link a code to a whole club. A new optional team_id
-- limits a row to one team at that club (e.g. an "S&C" code used by one team
-- to split players into S&C-specific squads).
--   team_id IS NULL  -> code applies to every team at the club (all existing rows)
--   team_id = <team> -> code applies to that team only
--
-- The functions that list a team's codes are re-created from their latest
-- definitions with one extra condition each:
--   get_user_event_create_detail  (20260825000002) - Create Event code picker
--   get_user_event_edit_detail    (20260825000001) - Edit Event code picker
--   get_team_members_by_role      (20260728000014) - Team Members code buttons
--   create_new_member_by_code     (20260817000006) - "No Team" placement per code
--   create_team_with_admin        (20261008000001) - club-wide codes only (a new
--                                                    team can't have team-only codes yet)
-- Fallback code logic (get_updated_event_code and its inline copies) picks the
-- club's lowest code, which is always a club-wide code, so it is unchanged.

ALTER TABLE public.club_code_link
  ADD COLUMN IF NOT EXISTS team_id bigint REFERENCES public.teams(team_id) ON DELETE CASCADE;

CREATE INDEX IF NOT EXISTS club_code_link_club_team_idx
  ON public.club_code_link (club_id, team_id);

CREATE OR REPLACE FUNCTION public.get_user_event_create_detail(p_user_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = 'public'
AS $$
DECLARE
    v_result jsonb;
    v_default_team_id bigint;
BEGIN
    SELECT
        CASE WHEN COUNT(DISTINCT mtl.team_id) = 1 THEN MAX(mtl.team_id) ELSE NULL END
    INTO v_default_team_id
    FROM public.members m
    JOIN public.user_member_link uml ON m.member_id = uml.member_id
    JOIN public.member_team_link mtl ON m.member_id = mtl.member_id AND mtl.status = 'active'
    WHERE uml.user_id = p_user_id;

    SELECT jsonb_build_object(
        'user_id',         p_user_id,
        'default_team_id', v_default_team_id,
        'create_teams', (
            SELECT jsonb_agg(team_data)
            FROM (
                SELECT DISTINCT ON (t.team_id)
                    t.team_id, t.team_name, t.club_id, c.club_name,
                    m.member_id,
                    (m.first_name || ' ' || m.last_name) AS authorized_member_name,
                    r.role_id,
                    r.role_name  AS admin_role,
                    r.role_level AS admin_level,
                    (SELECT jsonb_agg(jsonb_build_object('id', et.event_type_id, 'name', et.event_type))
                     FROM public.event_types et) AS event_types,
                    (SELECT jsonb_agg(jsonb_build_object('id', ec.code_id, 'name', ec.event_code))
                     FROM public.club_code_link ccl
                     JOIN public.event_codes ec ON ccl.code_id = ec.code_id
                     WHERE ccl.club_id = t.club_id
                       AND (ccl.team_id IS NULL OR ccl.team_id = t.team_id)) AS event_codes,
                    (SELECT jsonb_agg(jsonb_build_object(
                         'id', r_inner.role_id, 'name', r_inner.role_name,
                         'name_plural', r_inner.role_name_plural))
                     FROM public.team_roles_link trl
                     JOIN public.roles r_inner ON trl.role_id = r_inner.role_id
                     WHERE trl.team_id = t.team_id
                       AND r_inner.role_grade = 10 AND r_inner.show_audience = true) AS team_roles,
                    (SELECT jsonb_agg(jsonb_build_object(
                         'id', s.squad_id, 'name', s.squad_name, 'image', s.squad_image))
                     FROM public.squads s
                     WHERE s.team_id = t.team_id) AS squads
                FROM public.members m
                JOIN public.user_member_link uml ON m.member_id = uml.member_id
                JOIN public.member_team_link mtl ON m.member_id = mtl.member_id AND mtl.status = 'active'
                JOIN public.teams t ON mtl.team_id = t.team_id
                LEFT JOIN public.clubs c ON t.club_id = c.club_id
                JOIN public.member_team_role_link mtrl ON mtl.member_team_id = mtrl.member_team_id
                JOIN public.roles r ON mtrl.role_id = r.role_id
                WHERE uml.user_id = p_user_id AND r.role_grade = 100
                ORDER BY t.team_id, r.role_level DESC
            ) team_data
        )
    ) INTO v_result;

    RETURN v_result;
END;
$$;

CREATE OR REPLACE FUNCTION public.get_user_event_edit_detail(
    p_user_id  uuid,
    p_event_id bigint DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = 'public'
AS $$
DECLARE
    v_result          jsonb;
    v_default_team_id bigint;
    v_current_event   jsonb;
BEGIN
    SELECT
        CASE WHEN COUNT(DISTINCT mtl.team_id) = 1 THEN MAX(mtl.team_id) ELSE NULL END
    INTO v_default_team_id
    FROM public.members m
    JOIN public.user_member_link uml ON m.member_id = uml.member_id
    JOIN public.member_team_link mtl ON m.member_id = mtl.member_id AND mtl.status = 'active'
    WHERE uml.user_id = p_user_id;

    IF p_event_id IS NOT NULL THEN
        SELECT jsonb_build_object(
            'event_id',          e.event_id,
            'event_title',       e.event_title,
            'event_type_id',     e.event_type_id,
            'event_date_time',   e.event_date_time_2,
            'meet_time',         e.meet_time,
            'event_code_id',     e.event_code_id,
            'opposition',        e.opposition,
            'home_away',         e.home_away,
            'location_name',     e.location_name,
            'location_pin',      e.location_pin,
            'event_link',        e.event_link,
            'audience_id',       e.audience_id,
            'request_attendance',e.request_attendance,
            'event_details',     e.event_details,
            'team_id',           e.team_id,
            'event_image',       e.event_image,
            'payment_required',  e.payment_required,
            'payment_amount',    e.payment_amount,
            'squad_id',          e.squad_id,
            'status',            e.status
        ) INTO v_current_event
        FROM public.events e
        WHERE e.event_id = p_event_id;
    END IF;

    SELECT jsonb_build_object(
        'user_id',         p_user_id,
        'default_team_id', v_default_team_id::text,
        'current_event',   v_current_event,
        'create_teams', (
            SELECT jsonb_agg(team_data)
            FROM (
                SELECT DISTINCT ON (t.team_id)
                    t.team_id, t.team_name, t.club_id, c.club_name,
                    m.member_id,
                    (m.first_name || ' ' || m.last_name) AS authorized_member_name,
                    r.role_id,
                    r.role_name  AS admin_role,
                    r.role_level AS admin_level,
                    (SELECT jsonb_agg(jsonb_build_object('id', et.event_type_id, 'name', et.event_type))
                     FROM public.event_types et) AS event_types,
                    (SELECT jsonb_agg(jsonb_build_object('id', ec.code_id, 'name', ec.event_code))
                     FROM public.club_code_link ccl
                     JOIN public.event_codes ec ON ccl.code_id = ec.code_id
                     WHERE ccl.club_id = t.club_id
                       AND (ccl.team_id IS NULL OR ccl.team_id = t.team_id)) AS event_codes,
                    (SELECT jsonb_agg(jsonb_build_object(
                         'id', r_inner.role_id, 'name', r_inner.role_name,
                         'name_plural', r_inner.role_name_plural))
                     FROM public.team_roles_link trl
                     JOIN public.roles r_inner ON trl.role_id = r_inner.role_id
                     WHERE trl.team_id = t.team_id
                       AND r_inner.role_grade = 10 AND r_inner.show_audience = true) AS team_roles,
                    (SELECT jsonb_agg(jsonb_build_object(
                         'id', s.squad_id, 'name', s.squad_name, 'image', s.squad_image))
                     FROM public.squads s
                     WHERE s.team_id = t.team_id) AS squads
                FROM public.members m
                JOIN public.user_member_link uml ON m.member_id = uml.member_id
                JOIN public.member_team_link mtl ON m.member_id = mtl.member_id AND mtl.status = 'active'
                JOIN public.teams t ON mtl.team_id = t.team_id
                LEFT JOIN public.clubs c ON t.club_id = c.club_id
                JOIN public.member_team_role_link mtrl ON mtl.member_team_id = mtrl.member_team_id
                JOIN public.roles r ON mtrl.role_id = r.role_id
                WHERE uml.user_id = p_user_id AND r.role_grade = 100
                ORDER BY t.team_id, r.role_level DESC
            ) team_data
        )
    ) INTO v_result;

    RETURN v_result;
END;
$$;

CREATE OR REPLACE FUNCTION public.get_team_members_by_role(p_user_id uuid, p_team_id bigint)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = 'public'
AS $$
DECLARE
    v_user_highest_role smallint;
    v_team_info RECORD;
    v_roles_json jsonb;
    v_club_codes_json jsonb;
BEGIN
    SELECT MAX(r.role_level) INTO v_user_highest_role
    FROM public.roles r
    JOIN public.member_team_role_link mtrl ON r.role_id = mtrl.role_id
    JOIN public.member_team_link mtl ON mtrl.member_team_id = mtl.member_team_id
    JOIN public.members m ON mtl.member_id = m.member_id
    WHERE m.user_id = p_user_id
      AND mtl.status = 'active';  -- exclude soft-deleted team members

    SELECT team_id, team_name, team_unique_code, club_id, team_female
    INTO v_team_info
    FROM public.teams
    WHERE team_id = p_team_id;

    SELECT jsonb_agg(
        jsonb_build_object(
            'code_id', ec.code_id::bigint,
            'event_code', CASE
                WHEN v_team_info.team_female = TRUE AND ec.event_code = 'Hurling' THEN 'Camogie'
                ELSE ec.event_code
            END::text
        )
    ) INTO v_club_codes_json
    FROM public.club_code_link ccl
    JOIN public.event_codes ec ON ccl.code_id = ec.code_id
    WHERE ccl.club_id = v_team_info.club_id
      AND (ccl.team_id IS NULL OR ccl.team_id = p_team_id);

    SELECT jsonb_agg(role_group) INTO v_roles_json
    FROM (
        SELECT
            r.role_name, r.role_level,
            CASE
                WHEN r.role_name ILIKE '%y' THEN LEFT(r.role_name, -1) || 'ies'
                WHEN r.role_name ILIKE '%ch' OR r.role_name ILIKE '%sh' OR r.role_name ILIKE '%x' OR r.role_name ILIKE '%s' THEN r.role_name || 'es'
                ELSE r.role_name || 's'
            END as role_name_plural,
            COUNT(DISTINCT m.member_id) as member_count,
            jsonb_agg(
                jsonb_build_object(
                    'member_id',   m.member_id::bigint,
                    'first_name',  m.first_name::text,
                    'last_name',   m.last_name::text,
                    'full_name',   (m.first_name || ' ' || m.last_name)::text,
                    'squad_image', s.squad_image,
                    'squad_id',    mtl.squad_id::bigint,
                    'squad_name',  s.squad_name::text,
                    'squad_codes', (
                        SELECT jsonb_agg(
                            jsonb_build_object(
                                'code_id',    ec_sub.code_id::bigint,
                                'code_name',  CASE
                                    WHEN v_team_info.team_female = TRUE AND ec_sub.event_code = 'Hurling' THEN 'Camogie'
                                    ELSE ec_sub.event_code
                                END::text,
                                'squad_id',   COALESCE(s_sub.squad_id, 0)::bigint,
                                'squad_name', COALESCE(s_sub.squad_name, '')::text,
                                'squad_image',COALESCE(s_sub.squad_image, '')::text
                            )
                        )
                        FROM public.club_code_link ccl_sub
                        JOIN public.event_codes ec_sub ON ccl_sub.code_id = ec_sub.code_id
                        LEFT JOIN public.member_squad_link msl_sub
                            ON msl_sub.code_id = ec_sub.code_id AND msl_sub.member_id = m.member_id AND msl_sub.team_id = p_team_id
                        LEFT JOIN public.squads s_sub ON msl_sub.squad_id = s_sub.squad_id
                        WHERE ccl_sub.club_id = v_team_info.club_id
                    )
                )
            ) as members
        FROM public.roles r
        JOIN public.member_team_role_link mtrl ON r.role_id = mtrl.role_id
        JOIN public.member_team_link mtl ON mtrl.member_team_id = mtl.member_team_id
        JOIN public.members m ON mtl.member_id = m.member_id
        LEFT JOIN public.squads s ON mtl.squad_id = s.squad_id
        WHERE mtl.team_id = p_team_id
          AND mtl.status = 'active'       -- exclude soft-deleted team members
          AND m.status = 'active'         -- hide deleted + inactive members from roster
        GROUP BY r.role_name, r.role_level
        ORDER BY r.role_level DESC
    ) role_group;

    RETURN jsonb_build_object(
        'team_id',                v_team_info.team_id::bigint,
        'team_name',              v_team_info.team_name::text,
        'team_unique_code',       v_team_info.team_unique_code::text,
        'club_id',                v_team_info.club_id::bigint,
        'user_highest_role_level',COALESCE(v_user_highest_role, 0)::int,
        'role_groups',            COALESCE(v_roles_json, '[]'::jsonb),
        'club_codes',             COALESCE(v_club_codes_json, '[]'::jsonb)
    );
END;
$$;

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
      FROM public.club_code_link ccl
     WHERE ccl.club_id = v_club_id AND ccl.code_id > 1
       AND (ccl.team_id IS NULL OR ccl.team_id = v_team_id);

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

CREATE OR REPLACE FUNCTION public.create_team_with_admin(
  p_club_id             bigint,
  p_team_name           text,
  p_team_juvenile       boolean,
  p_team_female         boolean,
  p_car_pooling_allowed boolean,
  p_first_name          text,
  p_last_name           text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = 'public'
AS $$
DECLARE
  v_user_id          uuid;
  v_team_id          bigint;
  v_team_code        text;
  v_member_id        bigint;
  v_member_team_id   bigint;
  v_first_squad_id   bigint;
  v_code_rec         record;
  v_has_codes        boolean := false;
  v_chars            text := 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  v_attempt          int  := 0;
  v_candidate        text;
  v_exists           boolean;
  v_no_team_image    text := 'https://gyfporsbdftvtakdvukt.supabase.co/storage/v1/object/sign/coachsmartimages/Grey%20Team.png?token=eyJraWQiOiJzdG9yYWdlLXVybC1zaWduaW5nLWtleV82OTA4NmRkYy01MWQ3LTQ1NzUtYWYwMC1mZjQxYmMyNDU2YWMiLCJhbGciOiJIUzI1NiJ9.eyJ1cmwiOiJjb2FjaHNtYXJ0aW1hZ2VzL0dyZXkgVGVhbS5wbmciLCJpYXQiOjE3NTY0NDg1OTgsImV4cCI6MjYyMDQ0ODU5OH0.LRFMMpY8ifKkQDGxwMhKArQeyz-__9SIWn-1bQG0rA4';
BEGIN
  v_user_id := auth.uid();
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Unauthorized';
  END IF;

  -- Generate a unique team code (format: TM + 5 chars)
  LOOP
    v_candidate := 'TM';
    FOR j IN 1..5 LOOP
      v_candidate := v_candidate || substr(v_chars, floor(random() * length(v_chars) + 1)::int, 1);
    END LOOP;
    SELECT EXISTS(SELECT 1 FROM teams WHERE team_unique_code = v_candidate) INTO v_exists;
    EXIT WHEN NOT v_exists;
    v_attempt := v_attempt + 1;
    IF v_attempt >= 10 THEN
      RAISE EXCEPTION 'Failed to generate a unique team code — please try again';
    END IF;
  END LOOP;
  v_team_code := v_candidate;

  -- 1. Team
  INSERT INTO teams (team_name, club_id, team_juvenile, team_female, car_pooling_allowed, allow_lineup, team_unique_code)
  VALUES (p_team_name, p_club_id, p_team_juvenile, p_team_female, p_car_pooling_allowed, false, v_team_code)
  RETURNING team_id INTO v_team_id;

  -- 2. Team roles — Admin, Coach, FLO, Player (no SuperUser)
  INSERT INTO team_roles_link (team_id, role_id)
  VALUES (v_team_id, 7), (v_team_id, 8), (v_team_id, 9), (v_team_id, 6);

  -- 3. Member record for the creator
  INSERT INTO members (first_name, last_name, user_id)
  VALUES (p_first_name, p_last_name, v_user_id)
  RETURNING member_id INTO v_member_id;

  -- 4. Link member to user account
  INSERT INTO user_member_link (user_id, member_id)
  VALUES (v_user_id, v_member_id);

  -- 5. Create exactly ONE "No Team" squad for this team
  INSERT INTO squads (team_id, squad_name, grade, squad_colour, squad_list_seq, squad_image)
  VALUES (v_team_id, 'No Team', '', '#ffffff', 100, v_no_team_image)
  RETURNING squad_id INTO v_first_squad_id;

  -- 6. Link the admin member to that squad once per club code
  FOR v_code_rec IN
    SELECT ccl.code_id FROM club_code_link ccl
     WHERE ccl.club_id = p_club_id AND ccl.team_id IS NULL
     ORDER BY ccl.code_id
  LOOP
    INSERT INTO member_squad_link (member_id, squad_id, team_id, code_id)
    VALUES (v_member_id, v_first_squad_id, v_team_id, v_code_rec.code_id);
    v_has_codes := true;
  END LOOP;

  -- Fallback: club has no codes — one link without code_id
  IF NOT v_has_codes THEN
    INSERT INTO member_squad_link (member_id, squad_id, team_id)
    VALUES (v_member_id, v_first_squad_id, v_team_id);
  END IF;

  -- 7. Link member to team (squad_id = the single "No Team" squad)
  INSERT INTO member_team_link (member_id, team_id, squad_id, member_team_code, status)
  VALUES (v_member_id, v_team_id, v_first_squad_id, v_team_code, 'active')
  RETURNING member_team_id INTO v_member_team_id;

  -- 8. Assign Admin role to creator
  INSERT INTO member_team_role_link (member_team_id, role_id)
  VALUES (v_member_team_id, 7);

  RETURN jsonb_build_object('team_id', v_team_id, 'team_unique_code', v_team_code);
END;
$$;
