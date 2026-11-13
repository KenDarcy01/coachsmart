-- v3 stats pages (Ken, 2026-11-13): faster Club Analytics and fair session
-- counts. Two new v3-only functions; v2 keeps get_club_comparison_dashboard
-- and get_member_analytics unchanged.
--
-- Who counts for an event ("invited"), on both pages:
--   * an active player-side (grade 10) member of the event's team who had
--     joined the team by the event's start (member_team_link.created_at),
--   * whose role level meets the event's audience (events.audience_id), as
--     the v3 attendance page,
--   * and, for a squad-only event (events.squad_id), who is in that squad;
--   * plus anyone on the roster who replied or was picked, whatever the above.
-- An invited member with no reply counts as "no reply". Before this, the
-- player page only counted events the player had replied to, and the club
-- page counted every current player for every event, even before they joined.

-- ---------------------------------------------------------------------------
-- Club Analytics: one call returns the caller's admin teams and, for one club,
-- compact event rows: names once per team, then per event just the ids of who
-- said yes (y), no (n) or hasn't replied (x), and match picks (p: [member, squad]).
-- Only the caller's admin teams in that club are returned.

CREATE OR REPLACE FUNCTION public.get_club_analytics_v3(
    p_club_id    integer     DEFAULT NULL,
    p_start_date timestamptz DEFAULT NOW() - INTERVAL '1 year',
    p_end_date   timestamptz DEFAULT NOW()
)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = 'public'
AS $$
DECLARE
    v_uid        uuid := auth.uid();
    v_admin      jsonb;
    v_default    bigint;
    v_club_id    bigint;
    v_club_name  text;
    v_team_ids   bigint[];
    v_result     jsonb;
BEGIN
    IF v_uid IS NULL THEN
        RETURN jsonb_build_object('error', 'Not signed in');
    END IF;

    -- Teams where the caller holds an admin (grade 100) role.
    SELECT COALESCE(jsonb_agg(jsonb_build_object(
               'team_id', a.team_id, 'team_name', a.team_name,
               'club_id', a.club_id, 'club_name', a.club_name)
               ORDER BY a.club_name, a.team_name), '[]'::jsonb)
      INTO v_admin
    FROM (
        SELECT DISTINCT t.team_id, t.team_name, t.club_id, c.club_name
        FROM public.user_member_link uml
        JOIN public.member_team_link mtl       ON mtl.member_id = uml.member_id
                                              AND COALESCE(mtl.status, 'active') = 'active'
        JOIN public.member_team_role_link mtrl ON mtrl.member_team_id = mtl.member_team_id
        JOIN public.roles r                    ON r.role_id = mtrl.role_id AND r.role_grade = 100
        JOIN public.teams t                    ON t.team_id = mtl.team_id
        JOIN public.clubs c                    ON c.club_id = t.club_id
        WHERE uml.user_id = v_uid
    ) a;

    IF jsonb_array_length(v_admin) = 0 THEN
        RETURN jsonb_build_object('admin_teams', v_admin);
    END IF;

    SELECT u.default_club INTO v_default FROM public.users u WHERE u.user_id = v_uid;

    -- The club asked for, else the default club, else the first by name.
    SELECT (x->>'club_id')::bigint INTO v_club_id
    FROM jsonb_array_elements(v_admin) x
    ORDER BY ((x->>'club_id')::bigint = p_club_id) DESC NULLS LAST,
             ((x->>'club_id')::bigint = v_default) DESC NULLS LAST,
             x->>'club_name'
    LIMIT 1;

    SELECT array_agg((x->>'team_id')::bigint), min(x->>'club_name')
      INTO v_team_ids, v_club_name
    FROM jsonb_array_elements(v_admin) x
    WHERE (x->>'club_id')::bigint = v_club_id;

    WITH club_teams AS (
        SELECT t.team_id, t.team_name, t.team_female
        FROM public.teams t
        WHERE t.team_id = ANY (v_team_ids)
    ),
    ev AS (
        SELECT e.event_id, e.team_id, e.event_date_time, e.squad_id,
               e.opposition, e.home_away,
               COALESCE(ec.event_code, '') AS event_code,
               COALESCE(et.event_type, '') AS event_type,
               COALESCE(ar.role_level, 10)  AS audience_level,
               CASE
                   WHEN e.event_title IS NOT NULL AND trim(e.event_title) <> '' THEN e.event_title
                   ELSE trim(
                       CASE WHEN ct.team_female = true AND ec.code_id = 3
                            THEN 'Camogie' ELSE COALESCE(ec.event_code, '') END
                       || ' ' || COALESCE(et.event_type, '')
                       || CASE WHEN et.event_type_id = 2
                                AND e.opposition IS NOT NULL AND e.opposition <> ''
                               THEN ' v ' || e.opposition ELSE '' END)
               END AS title
        FROM public.events e
        JOIN club_teams ct              ON ct.team_id = e.team_id
        LEFT JOIN public.event_codes ec ON ec.code_id = e.event_code_id
        LEFT JOIN public.event_types et ON et.event_type_id = e.event_type_id
        LEFT JOIN public.roles ar       ON ar.role_id = e.audience_id
        WHERE e.event_date_time >= p_start_date
          AND e.event_date_time <  p_end_date
          AND e.status = 'active'
    ),
    roster_roles AS (
        SELECT mtl.team_id, m.member_id, mtl.created_at AS joined,
               trim(m.first_name || ' ' || COALESCE(m.last_name, '')) AS full_name,
               r.role_name, r.role_level, r.role_list_seq
        FROM public.member_team_link mtl
        JOIN club_teams ct                     ON ct.team_id = mtl.team_id
        JOIN public.members m                  ON m.member_id = mtl.member_id
        JOIN public.member_team_role_link mtrl ON mtrl.member_team_id = mtl.member_team_id
        JOIN public.roles r                    ON r.role_id = mtrl.role_id
        WHERE r.role_grade = 10
          AND COALESCE(mtl.status, 'active') = 'active'
          AND COALESCE(m.status, '') <> 'deleted'
    ),
    roster AS (
        -- One row per team member: shown role first by list order, the
        -- highest level for the audience check, the earliest join.
        SELECT DISTINCT ON (rr.team_id, rr.member_id)
               rr.team_id, rr.member_id, rr.full_name, rr.role_name,
               rr.role_level AS shown_level,
               max(rr.role_level) OVER (PARTITION BY rr.team_id, rr.member_id) AS max_level,
               min(rr.joined)     OVER (PARTITION BY rr.team_id, rr.member_id) AS joined
        FROM roster_roles rr
        ORDER BY rr.team_id, rr.member_id, rr.role_list_seq
    ),
    replies AS (
        SELECT DISTINCT ON (ea.event_id, ea.member_id)
               ea.event_id, ea.member_id, ea.response_id
        FROM public.event_attendance ea
        JOIN ev ON ev.event_id = ea.event_id
        ORDER BY ea.event_id, ea.member_id, ea.attendance_id DESC
    ),
    latest_save AS (
        SELECT DISTINCT ON (ms.event_id) ms.event_id, ms.match_squad_id
        FROM public.match_squads ms
        JOIN ev ON ev.event_id = ms.event_id
        ORDER BY ms.event_id, ms.match_squad_id DESC
    ),
    picks AS (
        SELECT DISTINCT ON (msd.event_id, msd.member_id)
               msd.event_id, msd.member_id, msd.squad_id
        FROM public.match_squad_details msd
        JOIN latest_save ls ON ls.match_squad_id = msd.match_squad_id
                           AND ls.event_id       = msd.event_id
        WHERE msd.squad_id IS NOT NULL
        ORDER BY msd.event_id, msd.member_id, msd.squad_id
    ),
    squad_members AS (
        SELECT DISTINCT msl.team_id, msl.squad_id, msl.member_id
        FROM public.member_squad_link msl
        WHERE msl.team_id = ANY (v_team_ids)
    ),
    invited AS (
        SELECT ev.event_id, ro.member_id, rp.response_id, pk.squad_id AS pick
        FROM ev
        JOIN roster ro          ON ro.team_id = ev.team_id
        LEFT JOIN replies rp    ON rp.event_id = ev.event_id AND rp.member_id = ro.member_id
        LEFT JOIN picks pk      ON pk.event_id = ev.event_id AND pk.member_id = ro.member_id
        WHERE rp.member_id IS NOT NULL
           OR pk.member_id IS NOT NULL
           OR (ro.joined <= ev.event_date_time
               AND ro.max_level >= ev.audience_level
               AND (ev.squad_id IS NULL OR EXISTS (
                       SELECT 1 FROM squad_members sm
                       WHERE sm.team_id = ev.team_id AND sm.squad_id = ev.squad_id
                         AND sm.member_id = ro.member_id)))
    ),
    event_rows AS MATERIALIZED (
        SELECT ev.team_id, ev.event_id, ev.event_date_time,
               jsonb_build_object(
                   'event_id',   ev.event_id,
                   'date',       ev.event_date_time,
                   'title',      ev.title,
                   'code',       ev.event_code,
                   'type',       ev.event_type,
                   'opposition', ev.opposition,
                   'home_away',  ev.home_away,
                   'y', COALESCE(jsonb_agg(i.member_id) FILTER (WHERE i.response_id = 3), '[]'::jsonb),
                   'n', COALESCE(jsonb_agg(i.member_id) FILTER (WHERE i.response_id = 4), '[]'::jsonb),
                   'x', COALESCE(jsonb_agg(i.member_id) FILTER (WHERE i.response_id IS NULL OR i.response_id NOT IN (3, 4)), '[]'::jsonb),
                   'p', COALESCE(jsonb_agg(jsonb_build_array(i.member_id, i.pick)) FILTER (WHERE i.pick IS NOT NULL), '[]'::jsonb)
               ) AS j
        FROM ev
        LEFT JOIN invited i ON i.event_id = ev.event_id
        GROUP BY ev.team_id, ev.event_id, ev.event_date_time, ev.title, ev.event_code,
                 ev.event_type, ev.opposition, ev.home_away
    )
    SELECT jsonb_build_object(
        'admin_teams',  v_admin,
        'club_id',      v_club_id,
        'club_name',    v_club_name,
        'start_date',   p_start_date,
        'end_date',     p_end_date,
        'squads', COALESCE((
            SELECT jsonb_agg(jsonb_build_object(
                       'squad_id', s.squad_id, 'squad_name', s.squad_name,
                       'team_id', s.team_id, 'seq', s.squad_list_seq,
                       'colour', s.squad_colour)
                   ORDER BY s.squad_list_seq NULLS LAST, s.squad_name)
            FROM public.squads s
            WHERE s.squad_id IN (SELECT DISTINCT squad_id FROM picks)
        ), '[]'::jsonb),
        'teams', COALESCE((
            SELECT jsonb_agg(jsonb_build_object(
                       'team_id',     ct.team_id,
                       'team_name',   ct.team_name,
                       'team_female', ct.team_female,
                       -- [member_id, name, role, role_level]
                       'people', COALESCE((
                           SELECT jsonb_agg(jsonb_build_array(ro.member_id, ro.full_name,
                                                              ro.role_name, ro.shown_level)
                                            ORDER BY ro.full_name)
                           FROM roster ro WHERE ro.team_id = ct.team_id), '[]'::jsonb),
                       'events', COALESCE((
                           SELECT jsonb_agg(er.j ORDER BY er.event_date_time DESC)
                           FROM event_rows er WHERE er.team_id = ct.team_id), '[]'::jsonb))
                   ORDER BY ct.team_name)
            FROM club_teams ct
        ), '[]'::jsonb)
    ) INTO v_result;

    RETURN v_result;
END;
$$;

REVOKE ALL ON FUNCTION public.get_club_analytics_v3(integer, timestamptz, timestamptz) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_club_analytics_v3(integer, timestamptz, timestamptz)
    TO authenticated, service_role;

-- ---------------------------------------------------------------------------
-- Player stats: same shape as get_member_analytics, but "events" lists every
-- event the player was invited to (see the rule at the top), with
-- response_id null when they haven't replied. The caller must be an active
-- member of one of the player's teams (or linked to the player).

CREATE OR REPLACE FUNCTION public.get_member_analytics_v3(p_member_id bigint)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = 'public'
AS $$
DECLARE
    v_uid uuid := auth.uid();
BEGIN
    IF v_uid IS NULL OR NOT EXISTS (
        SELECT 1
        FROM public.user_member_link uml
        WHERE uml.user_id = v_uid
          AND (uml.member_id = p_member_id OR EXISTS (
                SELECT 1
                FROM public.member_team_link mine
                JOIN public.member_team_link theirs ON theirs.team_id = mine.team_id
                WHERE mine.member_id = uml.member_id
                  AND COALESCE(mine.status, 'active') = 'active'
                  AND theirs.member_id = p_member_id))
    ) THEN
        RETURN jsonb_build_object('error', 'You can''t see this player''s stats.');
    END IF;

    RETURN (
    WITH links AS (
        -- The player's active teams: earliest join and highest player-side level.
        SELECT mtl.team_id, min(mtl.created_at) AS joined, max(r.role_level) AS max_level
        FROM public.member_team_link mtl
        JOIN public.member_team_role_link mtrl ON mtrl.member_team_id = mtl.member_team_id
        JOIN public.roles r                    ON r.role_id = mtrl.role_id AND r.role_grade = 10
        WHERE mtl.member_id = p_member_id
          AND COALESCE(mtl.status, 'active') = 'active'
        GROUP BY mtl.team_id
    ),
    replies AS (
        SELECT DISTINCT ON (ea.event_id) ea.event_id, ea.response_id
        FROM public.event_attendance ea
        WHERE ea.member_id = p_member_id
        ORDER BY ea.event_id, ea.attendance_id DESC
    ),
    invited AS (
        SELECT e.event_id
        FROM public.events e
        JOIN links l          ON l.team_id = e.team_id
        LEFT JOIN public.roles ar ON ar.role_id = e.audience_id
        WHERE e.event_date_time >= l.joined
          AND l.max_level >= COALESCE(ar.role_level, 10)
          AND (e.squad_id IS NULL OR EXISTS (
                SELECT 1 FROM public.member_squad_link msl
                WHERE msl.member_id = p_member_id AND msl.team_id = e.team_id
                  AND msl.squad_id = e.squad_id))
        UNION
        SELECT event_id FROM replies
    ),
    ev AS (
        SELECT e.event_id, e.event_title, e.event_date_time, et.event_type,
               ec.event_code, e.team_id, t.team_name, e.opposition, e.home_away,
               rp.response_id, ert.response_value, ert.display_value
        FROM invited i
        JOIN public.events e        ON e.event_id = i.event_id
        JOIN public.event_types et  ON et.event_type_id = e.event_type_id
        JOIN public.teams t         ON t.team_id = e.team_id
        LEFT JOIN public.event_codes ec ON ec.code_id = e.event_code_id
        LEFT JOIN replies rp        ON rp.event_id = e.event_id
        LEFT JOIN public.event_response_type ert ON ert.response_id = rp.response_id
        WHERE (e.status IS NULL OR e.status = 'active')
    ),
    sel AS (
        SELECT DISTINCT ON (e.event_id)
               e.event_id, e.event_title, e.event_date_time, et.event_type,
               ec.event_code, e.opposition, e.home_away, e.team_id, t.team_name,
               s.squad_id, s.squad_name, r.role_id, r.role_name
        FROM public.match_squad_details msd
        JOIN public.match_squads msq ON msq.match_squad_id = msd.match_squad_id
        JOIN public.events e         ON e.event_id = msq.event_id
        JOIN public.event_types et   ON et.event_type_id = e.event_type_id
        JOIN public.teams t          ON t.team_id = e.team_id
        LEFT JOIN public.event_codes ec ON ec.code_id = e.event_code_id
        LEFT JOIN public.squads s    ON s.squad_id = msd.squad_id
        LEFT JOIN public.roles r     ON r.role_id = msd.role_id
        WHERE msd.member_id = p_member_id
          AND (e.status IS NULL OR e.status = 'active')
        ORDER BY e.event_id, msq.match_squad_id DESC, msd.id DESC
    )
    SELECT jsonb_build_object(
        'member', (
            SELECT jsonb_build_object('member_id', m.member_id,
                       'first_name', m.first_name, 'last_name', m.last_name)
            FROM public.members m WHERE m.member_id = p_member_id),
        'teams', (
            SELECT COALESCE(jsonb_agg(jsonb_build_object(
                       'team_id', t.team_id, 'team_name', t.team_name,
                       'team_female', t.team_female,
                       'club_id', c.club_id, 'club_name', c.club_name)
                   ORDER BY c.club_name, t.team_name), '[]'::jsonb)
            FROM public.member_team_link mtl
            JOIN public.teams t ON t.team_id = mtl.team_id
            JOIN public.clubs c ON c.club_id = t.club_id
            WHERE mtl.member_id = p_member_id AND mtl.status = 'active'),
        'events', (
            SELECT COALESCE(jsonb_agg(jsonb_build_object(
                       'event_id', ev.event_id, 'event_title', ev.event_title,
                       'event_date_time', ev.event_date_time,
                       'event_type', ev.event_type, 'event_code', ev.event_code,
                       'team_id', ev.team_id, 'team_name', ev.team_name,
                       'opposition', ev.opposition, 'home_away', ev.home_away,
                       'response_id', ev.response_id,
                       'response', ev.response_value,
                       'response_label', ev.display_value)
                   ORDER BY ev.event_date_time DESC), '[]'::jsonb)
            FROM ev),
        'matchSelections', (
            SELECT COALESCE(jsonb_agg(jsonb_build_object(
                       'event_id', sel.event_id, 'event_title', sel.event_title,
                       'event_date_time', sel.event_date_time,
                       'event_type', sel.event_type, 'event_code', sel.event_code,
                       'opposition', sel.opposition, 'home_away', sel.home_away,
                       'team_id', sel.team_id, 'team_name', sel.team_name,
                       'squad_id', sel.squad_id, 'squad_name', sel.squad_name,
                       'squad_colour', (SELECT s2.squad_colour FROM public.squads s2
                                        WHERE s2.squad_id = sel.squad_id),
                       'role_id', sel.role_id, 'role_name', sel.role_name)
                   ORDER BY sel.event_date_time DESC), '[]'::jsonb)
            FROM sel)
    ));
END;
$$;

REVOKE ALL ON FUNCTION public.get_member_analytics_v3(bigint) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_member_analytics_v3(bigint) TO authenticated, service_role;
