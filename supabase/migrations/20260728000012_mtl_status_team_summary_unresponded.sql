-- Migration: 20260728000012_mtl_status_team_summary_unresponded
--
-- Adds mtl.status = 'active' to every JOIN on member_team_link in three
-- functions so that soft-deleted team memberships are invisible.
--
-- get_user_team_summary(p_user_id uuid)
--   Two JOINs on member_team_link (alias mtl):
--     1. The MAX(role_level) subquery that determines the user's
--        overall highest role level.
--     2. The DISTINCT ON query that builds the per-team role list.
--   Both now require mtl.status = 'active' so a user who has been
--   removed from a team no longer sees that team or inherits its
--   role level in the home-screen summary.
--
-- get_unresponded_events(event_id_param bigint)
--   Single JOIN on member_team_link (alias mtl) that expands a team
--   to all its members.  Soft-deleted members (mtl.status != 'active')
--   must NOT receive unresponded-event notification emails.
--
-- get_unresponded_events_v2(event_id_param bigint, ...)
--   Same concern as v1: the all_team_members CTE joins member_team_link
--   to enumerate every member on the event's team.  Adding
--   mtl.status = 'active' prevents removed members from appearing in
--   the notification dispatch list.
--
-- All three functions are written with SECURITY DEFINER
-- SET search_path = 'public' inline (migration 20260727000012 already
-- set search_path via ALTER, and get_user_team_summary already carried
-- SECURITY DEFINER; this makes the intent explicit and keeps the body
-- self-contained for future reads).


-- ─── get_user_team_summary ───────────────────────────────────────────────────
-- Change: both MTL joins now carry AND mtl.status = 'active'.

CREATE OR REPLACE FUNCTION public.get_user_team_summary(p_user_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = 'public'
AS $$
DECLARE
    v_overall_highest smallint;
    v_teams_json jsonb;
BEGIN
    -- 1. Get the absolute MAX role level across all members LINKED to this user
    SELECT MAX(r.role_level) INTO v_overall_highest
    FROM public.user_member_link uml
    JOIN public.member_team_link mtl ON uml.member_id = mtl.member_id AND mtl.status = 'active'
    JOIN public.member_team_role_link mtrl ON mtl.member_team_id = mtrl.member_team_id
    JOIN public.roles r ON mtrl.role_id = r.role_id
    WHERE uml.user_id = p_user_id;

    -- 2. Build the flat team list for members explicitly linked to this user
    SELECT jsonb_agg(t_final) INTO v_teams_json
    FROM (
        SELECT DISTINCT ON (t.team_id)
            t.team_id,
            t.team_name,
            t.team_unique_code,
            r.role_level as team_highest_role_level,
            r.role_name as team_role_name
        FROM public.user_member_link uml
        INNER JOIN public.member_team_link mtl ON uml.member_id = mtl.member_id AND mtl.status = 'active'
        INNER JOIN public.teams t ON mtl.team_id = t.team_id
        INNER JOIN public.member_team_role_link mtrl ON mtl.member_team_id = mtrl.member_team_id
        INNER JOIN public.roles r ON mtrl.role_id = r.role_id
        WHERE uml.user_id = p_user_id
        ORDER BY t.team_id, r.role_level DESC
    ) t_final;

    RETURN jsonb_build_object(
        'overall_highest_role_level', COALESCE(v_overall_highest, 0),
        'teams', COALESCE(v_teams_json, '[]'::jsonb)
    );
END;
$$;


-- ─── get_unresponded_events ───────────────────────────────────────────────────
-- Change: MTL join now carries AND mtl.status = 'active' so removed members
-- are excluded from the unresponded-event notification list.

CREATE OR REPLACE FUNCTION public.get_unresponded_events(event_id_param bigint)
RETURNS SETOF jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = 'public'
AS $$
BEGIN
  RETURN QUERY
  WITH latest_attendance AS (
    SELECT
      ea.event_id,
      ea.member_id,
      ea.response_id,
      row_number() OVER (
        PARTITION BY ea.event_id, ea.member_id
        ORDER BY ea.created_at DESC
      ) AS rn
    FROM public.event_attendance ea
  )
  SELECT DISTINCT
    jsonb_build_object(
      'email',             u.email_address,
      'team_name',         t.team_name,
      'event_title',       e.event_title,
      'event_date_time',   e.event_date_time,
      'full_name',         u.first_name || ' ' || u.last_name,
      'first_name',        u.first_name,
      'last_name',         u.last_name,
      'member_first_name', m.first_name,
      'member_last_name',  m.last_name
    )
  FROM public.events e
  JOIN public.teams t    ON t.team_id    = e.team_id
  JOIN public.member_team_link mtl ON mtl.team_id = t.team_id AND mtl.status = 'active'
  JOIN public.members m  ON m.member_id  = mtl.member_id
  JOIN public.user_member_link uml ON uml.member_id = m.member_id
  JOIN public.users u    ON u.user_id    = uml.user_id
  LEFT JOIN latest_attendance la
         ON la.event_id  = e.event_id
        AND la.member_id = m.member_id
        AND la.rn = 1
  WHERE e.event_id = event_id_param
    AND (la.response_id IS NULL OR la.response_id = 0);
END;
$$;


-- ─── get_unresponded_events_v2 ────────────────────────────────────────────────
-- Change: the all_team_members CTE INNER JOIN on member_team_link now carries
-- AND mtl.status = 'active' so removed members are excluded from the
-- notification dispatch list before role-grade / role-level filtering.

CREATE OR REPLACE FUNCTION public.get_unresponded_events_v2(
    event_id_param bigint,
    p_role_grade   smallint DEFAULT NULL::smallint,
    p_role_level   smallint DEFAULT NULL::smallint
)
RETURNS SETOF jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = 'public'
AS $$
BEGIN
    RETURN QUERY
    WITH
    -- 1. CTE: Find ALL members linked to the event's team (The foundation set).
    all_team_members AS (
        SELECT DISTINCT ON (e.event_id, m.member_id, u.user_id)
            e.event_id,
            e.event_title,
            e.event_date_time,
            t.team_name,
            u.email_address,
            u.first_name AS user_first_name,
            u.last_name AS user_last_name,
            u.first_name || ' ' || u.last_name AS full_user_name,
            m.member_id,
            m.first_name AS member_first_name,
            m.last_name AS member_last_name,
            r.role_grade, -- Needed for filtering
            r.role_level  -- Needed for filtering
        FROM
            public.events e
        INNER JOIN
            public.teams t ON e.team_id = t.team_id
        INNER JOIN
            public.member_team_link mtl ON t.team_id = mtl.team_id AND mtl.status = 'active'
        INNER JOIN
            public.members m ON mtl.member_id = m.member_id
        INNER JOIN
            public.user_member_link uml ON m.member_id = uml.member_id
        INNER JOIN
            public.users u ON uml.user_id = u.user_id
        LEFT JOIN
            public.member_team_role_link mtrl ON mtl.member_team_id = mtrl.member_team_id
        LEFT JOIN
            public.roles r ON mtrl.role_id = r.role_id
        WHERE
            e.event_id = event_id_param
    ),
    -- 2. CTE: Find the latest attendance response for each distinct event-member combination.
    -- This identifies the member's CURRENT status.
    latest_member_event_attendance AS (
        SELECT
            ea.event_id,
            ea.member_id,
            ea.response_id,
            ROW_NUMBER() OVER (
                PARTITION BY ea.event_id, ea.member_id
                ORDER BY ea.created_at DESC
            ) AS rn
        FROM
            public.event_attendance ea
        WHERE
            ea.event_id = event_id_param
    )
    SELECT
        jsonb_build_object(
            'email', atm.email_address,
            'team_name', atm.team_name,
            'event_title', atm.event_title,
            'event_date_time', atm.event_date_time,
            'full_name', atm.full_user_name,
            'first_name', atm.user_first_name,
            'last_name', atm.user_last_name,
            'member_first_name', atm.member_first_name,
            'member_last_name', atm.member_last_name
        )
    FROM
        all_team_members atm -- Step 1: Start with ALL members
    LEFT JOIN
        latest_member_event_attendance lmea
        ON atm.event_id = lmea.event_id
        AND atm.member_id = lmea.member_id
        AND lmea.rn = 1 -- Only join the latest response status (Step 2 Prep)
    WHERE
        -- Filter 1: Check for members who are UNRESPONDED (latest status is NULL or 0)
        (lmea.response_id IS NULL OR lmea.response_id = 0)
        -- Filter 2: Conditional Role Grade filter (exact match if provided)
        AND (p_role_grade IS NULL OR atm.role_grade = p_role_grade)
        -- Filter 3: Conditional Role Level filter (minimum level if provided)
        AND (p_role_level IS NULL OR atm.role_level >= p_role_level);
END;
$$;
