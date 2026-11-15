-- v3 Event Details Teams card said "Red Team · 21 players" when the team had
-- 17 players, 3 coaches and 1 FLO (Ken, 2026-11-15). get_event_teams_v3 now
-- says which members are players (role_level 10, as on the Attendance page)
-- so the app counts only them. Additive: one new key per member. Only the v3
-- app calls this function; v2 is untouched.


-- The published teams for one event, for any active member of the team.
-- Returns:
--   shared, shared_at, is_admin, published (a snapshot exists)
--   families_told   admins only: people told so far
--   mine   [{member_id, first_name, squad_id, squad_name, squad_colour, squad_image}]
--          the caller's linked members in the snapshot; squad_id null = no team
--   squads [{squad_id, squad_name, squad_colour, squad_image,
--            members: [{member_id, name, mine, player}]}]
--          player = the member is on the team as a player (role_level 10), not
--          a coach or FLO; the Teams card counts only players.
-- Non-admins get mine/squads only while shared is on. "No Team" is left out
-- of squads.
CREATE OR REPLACE FUNCTION public.get_event_teams_v3(p_event_id bigint)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
STABLE
SET search_path = 'public'
AS $$
DECLARE
    v_team_id bigint;
    v_member  boolean;
    v_level   int;
    v_shared  boolean := false;
    v_at      timestamptz;
    v_ms      bigint;
    v_told    int := 0;
BEGIN
    IF auth.uid() IS NULL THEN
        RETURN jsonb_build_object('error', 'Not signed in');
    END IF;

    SELECT e.team_id INTO v_team_id FROM public.events e WHERE e.event_id = p_event_id;
    IF v_team_id IS NULL THEN
        RETURN jsonb_build_object('error', 'Event not found.');
    END IF;

    SELECT EXISTS (
        SELECT 1
        FROM public.member_team_link mtl
        JOIN public.user_member_link uml ON uml.member_id = mtl.member_id AND uml.status = 'active'
        WHERE mtl.team_id = v_team_id AND mtl.status = 'active' AND uml.user_id = auth.uid()
    ) INTO v_member;
    IF NOT v_member THEN
        RETURN jsonb_build_object('error', 'You are not a member of this team.');
    END IF;

    SELECT COALESCE(MAX(r.role_level), 0) INTO v_level
    FROM public.member_team_link mtl
    JOIN public.user_member_link uml ON uml.member_id = mtl.member_id AND uml.status = 'active'
    JOIN public.member_team_role_link mtrl ON mtrl.member_team_id = mtl.member_team_id
    JOIN public.roles r ON r.role_id = mtrl.role_id
    WHERE mtl.team_id = v_team_id AND mtl.status = 'active' AND uml.user_id = auth.uid();

    SELECT s.shared, s.shared_at INTO v_shared, v_at
    FROM public.event_team_shares s WHERE s.event_id = p_event_id;
    v_shared := COALESCE(v_shared, false);

    SELECT msq.match_squad_id INTO v_ms
    FROM public.match_squads msq
    WHERE msq.event_id = p_event_id
    ORDER BY msq.created_at DESC, msq.match_squad_id DESC
    LIMIT 1;

    IF v_level >= 100 THEN
        SELECT count(DISTINCT uml.user_id) INTO v_told
        FROM public.event_team_share_sent s
        JOIN public.user_member_link uml ON uml.member_id = s.member_id AND uml.status = 'active'
        WHERE s.event_id = p_event_id AND s.squad_id IS NOT NULL;
    END IF;

    IF v_ms IS NULL OR (NOT v_shared AND v_level < 100) THEN
        RETURN jsonb_build_object(
            'shared', v_shared, 'shared_at', v_at, 'is_admin', v_level >= 100,
            'published', v_ms IS NOT NULL, 'families_told', v_told,
            'mine', '[]'::jsonb, 'squads', '[]'::jsonb);
    END IF;

    RETURN (
    WITH cur AS (
        SELECT DISTINCT ON (d.member_id)
            d.member_id, m.first_name, m.last_name,
            CASE WHEN sq.squad_id IS NULL OR sq.squad_name ILIKE 'no team' THEN NULL
                 ELSE sq.squad_id END AS squad_id,
            sq.squad_name, sq.squad_colour, sq.squad_image, sq.squad_list_seq,
            COALESCE(r.role_level, 10) = 10 AS player
        FROM public.match_squad_details d
        JOIN public.members m ON m.member_id = d.member_id
        LEFT JOIN public.roles r ON r.role_id = d.role_id
        LEFT JOIN public.squads sq ON sq.squad_id = d.squad_id
        WHERE d.match_squad_id = v_ms
        ORDER BY d.member_id, d.id DESC
    ),
    my_members AS (
        SELECT DISTINCT uml.member_id
        FROM public.user_member_link uml
        WHERE uml.user_id = auth.uid() AND uml.status = 'active'
    ),
    sq AS (
        SELECT c.squad_id, max(c.squad_name) AS squad_name,
               max(c.squad_colour) AS squad_colour, max(c.squad_image) AS squad_image,
               min(c.squad_list_seq) AS seq,
               jsonb_agg(jsonb_build_object(
                   'member_id', c.member_id,
                   'name', trim(COALESCE(c.first_name, '') || ' ' || COALESCE(c.last_name, '')),
                   'mine', c.member_id IN (SELECT member_id FROM my_members),
                   'player', c.player)
                   ORDER BY c.first_name, c.last_name) AS members
        FROM cur c
        WHERE c.squad_id IS NOT NULL
        GROUP BY c.squad_id
    )
    SELECT jsonb_build_object(
        'shared', v_shared,
        'shared_at', v_at,
        'is_admin', v_level >= 100,
        'published', true,
        'families_told', v_told,
        'mine', COALESCE((
            SELECT jsonb_agg(jsonb_build_object(
                'member_id', c.member_id, 'first_name', c.first_name,
                'squad_id', c.squad_id,
                'squad_name', CASE WHEN c.squad_id IS NULL THEN NULL ELSE c.squad_name END,
                'squad_colour', c.squad_colour, 'squad_image', c.squad_image)
                ORDER BY c.first_name)
            FROM cur c WHERE c.member_id IN (SELECT member_id FROM my_members)), '[]'::jsonb),
        'squads', COALESCE((
            SELECT jsonb_agg(jsonb_build_object(
                'squad_id', s.squad_id, 'squad_name', s.squad_name,
                'squad_colour', s.squad_colour, 'squad_image', s.squad_image,
                'members', s.members)
                ORDER BY s.seq NULLS LAST, s.squad_name)
            FROM sq s), '[]'::jsonb)
    ));
END;
$$;
REVOKE EXECUTE ON FUNCTION public.get_event_teams_v3(bigint) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_event_teams_v3(bigint) TO authenticated;
