-- Team codes and squads, picked by the coach (Ken, 2026-11-06).
--
-- 1. team_code_link: which of the club's codes a team plays.
--      no rows for a team -> every club code (all existing teams, unchanged)
--      rows for a team    -> only those codes
--    Code 1 ("-") is the hidden placeholder code and always counts.
--    public.team_has_code(team, code) is the one rule; it is added to every
--    function that lists a team's codes (same list as 20261016000001), plus the
--    get_updated_event_code fallback so a hurling-only team doesn't fall back
--    to Football.
-- 2. create_team_with_admin gains p_code_ids and p_squads (both optional, so
--    an old copy of create_team.html still works).
-- 3. Team setup page functions (team admins only): get_team_setup,
--    save_team_codes, save_team_squad, remove_team_squad, reorder_team_squads.
--    A removed squad that old events/matches still point to is archived
--    (team_id -> NULL, archived_team_id keeps the team) so history keeps its
--    name; otherwise it is deleted. Its players move to No Team.
-- 5. S&C becomes a Clontarf GAA club code (Ken, 2026-11-06). Each existing
--    Clontarf GAA team first gets its current codes written down, so no team
--    gains S&C unless a coach switches it on.
-- 6. save_team_details: team name, Under 18, Female on the Team setup page;
--    get_my_admin_teams lists the teams the signed-in user can set up.
-- 4. squads.squad_image is the app's coloured badge (Blue/Red/... Team.png).
--    squad_image_for_colour(hex) picks the closest badge for any colour.

CREATE TABLE IF NOT EXISTS public.team_code_link (
  team_id    bigint NOT NULL REFERENCES public.teams(team_id) ON DELETE CASCADE,
  code_id    bigint NOT NULL REFERENCES public.event_codes(code_id),
  created_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (team_id, code_id)
);
ALTER TABLE public.team_code_link ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.squads ADD COLUMN IF NOT EXISTS archived_team_id bigint;

-- ── Helpers ─────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.team_has_code(p_team_id bigint, p_code_id bigint)
RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER
SET search_path = 'public'
AS $$
  SELECT p_code_id = 1
      OR NOT EXISTS (SELECT 1 FROM team_code_link WHERE team_id = p_team_id)
      OR EXISTS (SELECT 1 FROM team_code_link WHERE team_id = p_team_id AND code_id = p_code_id);
$$;

CREATE OR REPLACE FUNCTION public.squad_image_for_colour(p_colour text)
RETURNS text
LANGUAGE plpgsql IMMUTABLE
SET search_path = 'public'
AS $$
DECLARE
  v_base text := 'https://gyfporsbdftvtakdvukt.supabase.co/storage/v1/object/public/coachsmartimages/';
  v_hex  text := lower(ltrim(coalesce(p_colour, ''), '#'));
  r numeric; g numeric; b numeric; mx numeric; mn numeric; l numeric; s numeric; h numeric;
BEGIN
  IF v_hex !~ '^[0-9a-f]{6}$' THEN RETURN v_base || 'Grey%20Team.png'; END IF;
  r := ('x' || substr(v_hex, 1, 2))::bit(8)::int / 255.0;
  g := ('x' || substr(v_hex, 3, 2))::bit(8)::int / 255.0;
  b := ('x' || substr(v_hex, 5, 2))::bit(8)::int / 255.0;
  mx := greatest(r, g, b); mn := least(r, g, b); l := (mx + mn) / 2;
  IF mx = mn THEN s := 0; ELSE s := (mx - mn) / (1 - abs(2 * l - 1)); END IF;
  -- Greys, black and white
  IF s < 0.18 OR l > 0.92 THEN
    RETURN v_base || CASE WHEN l < 0.25 THEN 'Black%20Team.png' ELSE 'Grey%20Team.png' END;
  END IF;
  IF l < 0.1 THEN RETURN v_base || 'Black%20Team.png'; END IF;
  IF mx = r THEN h := 60 * (((g - b) / (mx - mn)));
  ELSIF mx = g THEN h := 60 * (((b - r) / (mx - mn)) + 2);
  ELSE h := 60 * (((r - g) / (mx - mn)) + 4);
  END IF;
  IF h < 0 THEN h := h + 360; END IF;
  RETURN v_base || CASE
    WHEN h < 15 OR h >= 335 THEN 'Red%20team.png'
    WHEN h < 40  THEN 'Orange%20Team.png'
    WHEN h < 70  THEN 'Yellow%20Team.png'
    WHEN h < 170 THEN 'Green%20Team.png'
    WHEN h < 255 THEN 'Blue%20Team.png'
    ELSE 'Purple%20Team.png' END;
END;
$$;

CREATE OR REPLACE FUNCTION public.is_team_admin(p_team_id bigint)
RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER
SET search_path = 'public'
AS $$
  SELECT auth.uid() IS NOT NULL AND EXISTS (
    SELECT 1
      FROM user_member_link uml
      JOIN member_team_link mtl       ON mtl.member_id = uml.member_id
      JOIN member_team_role_link mtrl ON mtrl.member_team_id = mtl.member_team_id
      JOIN roles r                    ON r.role_id = mtrl.role_id
     WHERE uml.user_id = auth.uid()
       AND COALESCE(uml.status, 'active') = 'active'
       AND mtl.team_id = p_team_id
       AND mtl.status = 'active'
       AND r.role_grade = 100);
$$;

-- ── Code lists, re-created from 20261016000001 with team_has_code added ──
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
                       AND (ccl.team_id IS NULL OR ccl.team_id = t.team_id)
                       AND public.team_has_code(t.team_id, ccl.code_id)) AS event_codes,
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
                       AND (ccl.team_id IS NULL OR ccl.team_id = t.team_id)
                       AND public.team_has_code(t.team_id, ccl.code_id)) AS event_codes,
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
      AND (ccl.team_id IS NULL OR ccl.team_id = p_team_id)
      AND public.team_has_code(p_team_id, ccl.code_id);

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
                          AND (ccl_sub.team_id IS NULL OR ccl_sub.team_id = p_team_id)
                          AND public.team_has_code(p_team_id, ccl_sub.code_id)
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
       AND (ccl.team_id IS NULL OR ccl.team_id = v_team_id)
       AND public.team_has_code(v_team_id, ccl.code_id);

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

CREATE OR REPLACE FUNCTION public.get_updated_event_code(p_event_id bigint)
RETURNS bigint
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = 'public'
AS $$
DECLARE
    v_event_code_id int8;
    v_team_id int8;
    v_club_id int8;
    v_fallback_code_id int8;
BEGIN
    SELECT event_code_id, team_id
    INTO v_event_code_id, v_team_id
    FROM public.events
    WHERE event_id = p_event_id;

    IF v_event_code_id > 1 THEN
        RETURN v_event_code_id;
    END IF;

    SELECT club_id INTO v_club_id
    FROM public.teams
    WHERE team_id = v_team_id;

    SELECT ccl.code_id INTO v_fallback_code_id
    FROM public.club_code_link ccl
    WHERE ccl.club_id = v_club_id
      AND ccl.code_id > 1
      AND (ccl.team_id IS NULL OR ccl.team_id = v_team_id)
      AND public.team_has_code(v_team_id, ccl.code_id)
    ORDER BY ccl.code_id ASC
    LIMIT 1;

    RETURN COALESCE(v_fallback_code_id, v_event_code_id);
END;
$$;

-- ── Create team ─────────────────────────────────────────────────────────
-- Codes the create-team page offers for a club (club-wide, not the placeholder).
CREATE OR REPLACE FUNCTION public.get_club_codes(p_club_id bigint)
RETURNS jsonb
LANGUAGE sql STABLE SECURITY DEFINER
SET search_path = 'public'
AS $$
  SELECT COALESCE(jsonb_agg(jsonb_build_object('code_id', ec.code_id, 'name', ec.event_code) ORDER BY ec.code_id), '[]'::jsonb)
    FROM club_code_link ccl
    JOIN event_codes ec ON ec.code_id = ccl.code_id
   WHERE ccl.club_id = p_club_id AND ccl.team_id IS NULL AND ccl.code_id > 1;
$$;

DROP FUNCTION IF EXISTS public.create_team_with_admin(bigint, text, boolean, boolean, boolean, text, text);

CREATE OR REPLACE FUNCTION public.create_team_with_admin(
  p_club_id             bigint,
  p_team_name           text,
  p_team_juvenile       boolean,
  p_team_female         boolean,
  p_car_pooling_allowed boolean,
  p_first_name          text,
  p_last_name           text,
  p_code_ids            bigint[] DEFAULT NULL,
  p_squads              jsonb    DEFAULT NULL
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
  v_sq               jsonb;
  v_seq              int := 0;
  v_name             text;
  v_colour           text;
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

  -- Picked codes must be the club's own club-wide codes
  IF p_code_ids IS NOT NULL AND cardinality(p_code_ids) > 0 AND EXISTS (
       SELECT 1 FROM unnest(p_code_ids) c(id)
        WHERE c.id > 1 AND NOT EXISTS (
          SELECT 1 FROM club_code_link ccl
           WHERE ccl.club_id = p_club_id AND ccl.team_id IS NULL AND ccl.code_id = c.id)) THEN
    RAISE EXCEPTION 'That code is not used by this club';
  END IF;

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

  -- 1b. The codes this team plays (none picked = every club code, as before)
  IF p_code_ids IS NOT NULL AND cardinality(p_code_ids) > 0 THEN
    INSERT INTO team_code_link (team_id, code_id)
    SELECT DISTINCT v_team_id, c.id FROM unnest(p_code_ids) c(id) WHERE c.id > 1
    ON CONFLICT DO NOTHING;
  END IF;

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

  -- 5. The "No Team" squad, always last
  INSERT INTO squads (team_id, squad_name, grade, squad_colour, squad_list_seq, squad_image)
  VALUES (v_team_id, 'No Team', '', '#ffffff', 100, v_no_team_image)
  RETURNING squad_id INTO v_first_squad_id;

  -- 5b. The coach's own squads, in the order entered
  IF p_squads IS NOT NULL AND jsonb_typeof(p_squads) = 'array' THEN
    FOR v_sq IN SELECT * FROM jsonb_array_elements(p_squads) LOOP
      v_name   := left(btrim(COALESCE(v_sq->>'name', '')), 40);
      v_colour := COALESCE(NULLIF(btrim(v_sq->>'colour'), ''), '#9AA0A6');
      CONTINUE WHEN v_name = '' OR lower(v_name) = 'no team';
      v_seq := v_seq + 1;
      INSERT INTO squads (team_id, squad_name, grade, squad_colour, squad_list_seq, squad_image)
      VALUES (v_team_id, v_name, '', v_colour, v_seq, public.squad_image_for_colour(v_colour));
      EXIT WHEN v_seq >= 20;
    END LOOP;
  END IF;

  -- 6. Admin placed in No Team once per code the team plays
  FOR v_code_rec IN
    SELECT ccl.code_id FROM club_code_link ccl
     WHERE ccl.club_id = p_club_id AND ccl.team_id IS NULL
       AND public.team_has_code(v_team_id, ccl.code_id)
     ORDER BY ccl.code_id
  LOOP
    INSERT INTO member_squad_link (member_id, squad_id, team_id, code_id)
    VALUES (v_member_id, v_first_squad_id, v_team_id, v_code_rec.code_id);
    v_has_codes := true;
  END LOOP;

  IF NOT v_has_codes THEN
    INSERT INTO member_squad_link (member_id, squad_id, team_id)
    VALUES (v_member_id, v_first_squad_id, v_team_id);
  END IF;

  -- 7. Link member to team
  INSERT INTO member_team_link (member_id, team_id, squad_id, member_team_code, status)
  VALUES (v_member_id, v_team_id, v_first_squad_id, v_team_code, 'active')
  RETURNING member_team_id INTO v_member_team_id;

  -- 8. Admin role
  INSERT INTO member_team_role_link (member_team_id, role_id)
  VALUES (v_member_team_id, 7);

  RETURN jsonb_build_object('team_id', v_team_id, 'team_unique_code', v_team_code);
END;
$$;

-- ── Team setup page ─────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.get_team_setup(p_team_id bigint)
RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path = 'public'
AS $$
DECLARE
  v_team record;
BEGIN
  IF NOT public.is_team_admin(p_team_id) THEN
    RAISE EXCEPTION 'Only team admins can change team setup';
  END IF;

  SELECT t.team_id, t.team_name, t.team_female, t.team_juvenile, t.club_id, c.club_name
    INTO v_team
    FROM teams t LEFT JOIN clubs c ON c.club_id = t.club_id
   WHERE t.team_id = p_team_id;

  RETURN jsonb_build_object(
    'team_id',   v_team.team_id,
    'team_name', v_team.team_name,
    'club_name', v_team.club_name,
    'female',    COALESCE(v_team.team_female, false),
    'juvenile',  COALESCE(v_team.team_juvenile, false),
    'codes', (
      SELECT COALESCE(jsonb_agg(jsonb_build_object(
               'code_id', x.code_id,
               'name', CASE WHEN v_team.team_female AND x.event_code = 'Hurling' THEN 'Camogie' ELSE x.event_code END,
               'on', public.team_has_code(p_team_id, x.code_id)) ORDER BY x.code_id), '[]'::jsonb)
        FROM (SELECT DISTINCT ec.code_id, ec.event_code
                FROM club_code_link ccl
                JOIN event_codes ec ON ec.code_id = ccl.code_id
               WHERE ccl.club_id = v_team.club_id AND ccl.code_id > 1
                 AND (ccl.team_id IS NULL OR ccl.team_id = p_team_id)) x),
    'squads', (
      SELECT COALESCE(jsonb_agg(jsonb_build_object(
               'squad_id', s.squad_id,
               'name', s.squad_name,
               'colour', s.squad_colour,
               'image', s.squad_image,
               'grade', s.grade,
               'seq', s.squad_list_seq,
               'no_team', s.squad_name = 'No Team',
               'players', (
                 SELECT count(DISTINCT msl.member_id)
                   FROM member_squad_link msl
                   JOIN member_team_link mtl ON mtl.member_id = msl.member_id AND mtl.team_id = p_team_id AND mtl.status = 'active'
                  WHERE msl.squad_id = s.squad_id AND msl.team_id = p_team_id))
             ORDER BY (s.squad_name = 'No Team'), s.squad_list_seq NULLS LAST, s.squad_id), '[]'::jsonb)
        FROM squads s
       WHERE s.team_id = p_team_id)
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.save_team_codes(p_team_id bigint, p_code_ids bigint[])
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = 'public'
AS $$
DECLARE
  v_club_id   bigint;
  v_no_team   bigint;
BEGIN
  IF NOT public.is_team_admin(p_team_id) THEN
    RAISE EXCEPTION 'Only team admins can change team setup';
  END IF;
  SELECT club_id INTO v_club_id FROM teams WHERE team_id = p_team_id;

  IF p_code_ids IS NULL OR NOT EXISTS (SELECT 1 FROM unnest(p_code_ids) c(id) WHERE c.id > 1) THEN
    RAISE EXCEPTION 'Pick at least one code';
  END IF;
  IF EXISTS (
       SELECT 1 FROM unnest(p_code_ids) c(id)
        WHERE c.id > 1 AND NOT EXISTS (
          SELECT 1 FROM club_code_link ccl
           WHERE ccl.club_id = v_club_id AND ccl.code_id = c.id
             AND (ccl.team_id IS NULL OR ccl.team_id = p_team_id))) THEN
    RAISE EXCEPTION 'That code is not used by this club';
  END IF;

  DELETE FROM team_code_link WHERE team_id = p_team_id;
  INSERT INTO team_code_link (team_id, code_id)
  SELECT DISTINCT p_team_id, c.id FROM unnest(p_code_ids) c(id) WHERE c.id > 1;

  -- Everyone on the team gets a No Team placement for any newly added code.
  -- Nothing is removed when a code is switched off.
  SELECT squad_id INTO v_no_team FROM squads
   WHERE team_id = p_team_id AND squad_name = 'No Team'
   ORDER BY squad_id LIMIT 1;
  IF v_no_team IS NOT NULL THEN
    INSERT INTO member_squad_link (member_id, team_id, code_id, squad_id)
    SELECT DISTINCT mtl.member_id, p_team_id, tcl.code_id, v_no_team
      FROM member_team_link mtl
      JOIN team_code_link tcl ON tcl.team_id = p_team_id
     WHERE mtl.team_id = p_team_id AND mtl.status IN ('active', 'pending')
       AND NOT EXISTS (
         SELECT 1 FROM member_squad_link msl
          WHERE msl.member_id = mtl.member_id AND msl.team_id = p_team_id AND msl.code_id = tcl.code_id);
  END IF;

  RETURN public.get_team_setup(p_team_id);
END;
$$;

-- Add (p_squad_id NULL) or change a squad. No Team can't be renamed.
CREATE OR REPLACE FUNCTION public.save_team_squad(
  p_team_id  bigint,
  p_squad_id bigint,
  p_name     text,
  p_colour   text,
  p_grade    text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = 'public'
AS $$
DECLARE
  v_name   text := left(btrim(COALESCE(p_name, '')), 40);
  v_colour text := COALESCE(NULLIF(btrim(p_colour), ''), '#9AA0A6');
  v_grade  text := left(btrim(COALESCE(p_grade, '')), 20);
  v_old    record;
  v_seq    int;
BEGIN
  IF NOT public.is_team_admin(p_team_id) THEN
    RAISE EXCEPTION 'Only team admins can change team setup';
  END IF;
  IF v_colour !~ '^#[0-9A-Fa-f]{6}$' THEN
    RAISE EXCEPTION 'Colour must look like #2F6FD6';
  END IF;

  IF p_squad_id IS NULL THEN
    IF v_name = '' THEN RAISE EXCEPTION 'Give the squad a name'; END IF;
    IF lower(v_name) = 'no team' THEN RAISE EXCEPTION 'No Team is already there'; END IF;
    IF EXISTS (SELECT 1 FROM squads WHERE team_id = p_team_id AND lower(squad_name) = lower(v_name)) THEN
      RAISE EXCEPTION 'There is already a squad called %', v_name;
    END IF;
    SELECT COALESCE(max(squad_list_seq), 0) + 1 INTO v_seq
      FROM squads WHERE team_id = p_team_id AND squad_name <> 'No Team';
    INSERT INTO squads (team_id, squad_name, grade, squad_colour, squad_list_seq, squad_image)
    VALUES (p_team_id, v_name, v_grade, v_colour, LEAST(v_seq, 99), public.squad_image_for_colour(v_colour));
  ELSE
    SELECT * INTO v_old FROM squads WHERE squad_id = p_squad_id AND team_id = p_team_id;
    IF NOT FOUND THEN RAISE EXCEPTION 'Squad not found'; END IF;
    IF v_old.squad_name = 'No Team' THEN
      RAISE EXCEPTION 'No Team can''t be changed';
    END IF;
    IF v_name = '' THEN RAISE EXCEPTION 'Give the squad a name'; END IF;
    IF lower(v_name) = 'no team' THEN RAISE EXCEPTION 'That name is kept for No Team'; END IF;
    IF EXISTS (SELECT 1 FROM squads WHERE team_id = p_team_id AND squad_id <> p_squad_id AND lower(squad_name) = lower(v_name)) THEN
      RAISE EXCEPTION 'There is already a squad called %', v_name;
    END IF;
    UPDATE squads
       SET squad_name   = v_name,
           grade        = v_grade,
           squad_colour = v_colour,
           squad_image  = CASE WHEN lower(COALESCE(v_old.squad_colour, '')) = lower(v_colour) AND v_old.squad_image IS NOT NULL
                               THEN v_old.squad_image ELSE public.squad_image_for_colour(v_colour) END
     WHERE squad_id = p_squad_id;
  END IF;

  RETURN public.get_team_setup(p_team_id);
END;
$$;

-- Remove a squad: players go to No Team. Blocked while an upcoming event uses it.
CREATE OR REPLACE FUNCTION public.remove_team_squad(p_team_id bigint, p_squad_id bigint)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = 'public'
AS $$
DECLARE
  v_sq       record;
  v_no_team  bigint;
  v_upcoming int;
BEGIN
  IF NOT public.is_team_admin(p_team_id) THEN
    RAISE EXCEPTION 'Only team admins can change team setup';
  END IF;
  SELECT * INTO v_sq FROM squads WHERE squad_id = p_squad_id AND team_id = p_team_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'Squad not found'; END IF;
  IF v_sq.squad_name = 'No Team' THEN RAISE EXCEPTION 'No Team can''t be removed'; END IF;

  SELECT count(*) INTO v_upcoming FROM events
   WHERE squad_id = p_squad_id AND event_date_time_2 >= (now() AT TIME ZONE 'Europe/Dublin')
     AND COALESCE(status, 'active') <> 'cancelled';
  IF v_upcoming > 0 THEN
    RAISE EXCEPTION '% upcoming event(s) are for this squad. Change or cancel them first.', v_upcoming;
  END IF;

  SELECT squad_id INTO v_no_team FROM squads
   WHERE team_id = p_team_id AND squad_name = 'No Team'
   ORDER BY squad_id LIMIT 1;
  IF v_no_team IS NULL THEN RAISE EXCEPTION 'This team has no No Team squad'; END IF;

  -- Move players; skip a row that would duplicate an existing No Team placement
  DELETE FROM member_squad_link a
   WHERE a.squad_id = p_squad_id AND a.team_id = p_team_id
     AND EXISTS (SELECT 1 FROM member_squad_link b
                  WHERE b.squad_id = v_no_team AND b.member_id = a.member_id
                    AND b.team_id = a.team_id AND b.code_id IS NOT DISTINCT FROM a.code_id);
  UPDATE member_squad_link SET squad_id = v_no_team WHERE squad_id = p_squad_id;
  UPDATE member_team_link  SET squad_id = v_no_team WHERE squad_id = p_squad_id;

  IF EXISTS (SELECT 1 FROM events WHERE squad_id = p_squad_id)
     OR EXISTS (SELECT 1 FROM match_stats WHERE squad_id = p_squad_id)
     OR EXISTS (SELECT 1 FROM match_squad_details WHERE squad_id = p_squad_id)
     OR EXISTS (SELECT 1 FROM match_timer WHERE squad_id = p_squad_id) THEN
    -- Keep it for history, off the team's lists
    UPDATE squads SET archived_team_id = team_id, team_id = NULL WHERE squad_id = p_squad_id;
  ELSE
    DELETE FROM squads WHERE squad_id = p_squad_id;
  END IF;

  RETURN public.get_team_setup(p_team_id);
END;
$$;

CREATE OR REPLACE FUNCTION public.reorder_team_squads(p_team_id bigint, p_squad_ids bigint[])
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = 'public'
AS $$
BEGIN
  IF NOT public.is_team_admin(p_team_id) THEN
    RAISE EXCEPTION 'Only team admins can change team setup';
  END IF;
  UPDATE squads s
     SET squad_list_seq = LEAST(o.pos, 99)
    FROM unnest(p_squad_ids) WITH ORDINALITY AS o(id, pos)
   WHERE s.squad_id = o.id AND s.team_id = p_team_id AND s.squad_name <> 'No Team';
  RETURN public.get_team_setup(p_team_id);
END;
$$;

CREATE OR REPLACE FUNCTION public.save_team_details(
  p_team_id  bigint,
  p_name     text,
  p_juvenile boolean,
  p_female   boolean
)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = 'public'
AS $$
DECLARE
  v_name text := left(btrim(COALESCE(p_name, '')), 60);
BEGIN
  IF NOT public.is_team_admin(p_team_id) THEN
    RAISE EXCEPTION 'Only team admins can change team setup';
  END IF;
  IF v_name = '' THEN RAISE EXCEPTION 'Give the team a name'; END IF;
  UPDATE teams
     SET team_name     = v_name,
         team_juvenile = COALESCE(p_juvenile, team_juvenile),
         team_female   = COALESCE(p_female, team_female)
   WHERE team_id = p_team_id;
  RETURN public.get_team_setup(p_team_id);
END;
$$;

-- Teams the signed-in user is an admin on (Team setup page team list)
CREATE OR REPLACE FUNCTION public.get_my_admin_teams()
RETURNS jsonb
LANGUAGE sql STABLE SECURITY DEFINER
SET search_path = 'public'
AS $$
  SELECT COALESCE(jsonb_agg(jsonb_build_object(
           'team_id', x.team_id, 'team_name', x.team_name, 'club_name', x.club_name)
           ORDER BY x.club_name, x.team_name), '[]'::jsonb)
    FROM (SELECT DISTINCT t.team_id, t.team_name, c.club_name
            FROM teams t
            LEFT JOIN clubs c ON c.club_id = t.club_id
           WHERE public.is_team_admin(t.team_id)
             AND t.team_id IN (
               SELECT mtl.team_id
                 FROM user_member_link uml
                 JOIN member_team_link mtl ON mtl.member_id = uml.member_id
                WHERE uml.user_id = auth.uid())) x;
$$;

-- ── S&C as a Clontarf GAA club code ─────────────────────────────────────
DO $$
DECLARE
  v_club bigint;
  v_snc  bigint;
BEGIN
  SELECT club_id INTO v_club FROM clubs WHERE club_name = 'Clontarf GAA' ORDER BY club_id LIMIT 1;
  SELECT code_id INTO v_snc FROM event_codes WHERE event_code = 'S&C' ORDER BY code_id LIMIT 1;
  IF v_club IS NULL OR v_snc IS NULL THEN
    RAISE NOTICE 'Clontarf GAA or S&C not found; skipped';
    RETURN;
  END IF;
  IF EXISTS (SELECT 1 FROM club_code_link WHERE club_id = v_club AND code_id = v_snc AND team_id IS NULL) THEN
    RETURN;
  END IF;

  -- Write down each team's codes as they are today (before S&C goes club-wide)
  INSERT INTO team_code_link (team_id, code_id)
  SELECT DISTINCT t.team_id, ccl.code_id
    FROM teams t
    JOIN club_code_link ccl ON ccl.club_id = t.club_id
                           AND (ccl.team_id IS NULL OR ccl.team_id = t.team_id)
   WHERE t.club_id = v_club AND ccl.code_id > 1
     AND NOT EXISTS (SELECT 1 FROM team_code_link x WHERE x.team_id = t.team_id)
  ON CONFLICT DO NOTHING;

  INSERT INTO club_code_link (club_id, code_id) VALUES (v_club, v_snc);
END;
$$;

-- ── Grants ──────────────────────────────────────────────────────────────
REVOKE ALL ON FUNCTION public.team_has_code(bigint, bigint) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.is_team_admin(bigint) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.get_club_codes(bigint) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.create_team_with_admin(bigint, text, boolean, boolean, boolean, text, text, bigint[], jsonb) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.get_team_setup(bigint) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.save_team_codes(bigint, bigint[]) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.save_team_squad(bigint, bigint, text, text, text) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.remove_team_squad(bigint, bigint) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.reorder_team_squads(bigint, bigint[]) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_club_codes(bigint) TO authenticated;
GRANT EXECUTE ON FUNCTION public.create_team_with_admin(bigint, text, boolean, boolean, boolean, text, text, bigint[], jsonb) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_team_setup(bigint) TO authenticated;
GRANT EXECUTE ON FUNCTION public.save_team_codes(bigint, bigint[]) TO authenticated;
GRANT EXECUTE ON FUNCTION public.save_team_squad(bigint, bigint, text, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.remove_team_squad(bigint, bigint) TO authenticated;
GRANT EXECUTE ON FUNCTION public.reorder_team_squads(bigint, bigint[]) TO authenticated;
REVOKE ALL ON FUNCTION public.get_my_admin_teams() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_my_admin_teams() TO authenticated;
REVOKE ALL ON FUNCTION public.save_team_details(bigint, text, boolean, boolean) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.save_team_details(bigint, text, boolean, boolean) TO authenticated;
