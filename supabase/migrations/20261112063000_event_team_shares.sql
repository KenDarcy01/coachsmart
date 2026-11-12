-- Show published teams to parents (Ken, 2026-11-12). v3 only.
--
-- An admin turns on "Show teams to parents" on an event once the teams are
-- published. It starts off on every event, training included, and is set per
-- event. While it is on, everyone in the team can read the latest published
-- teams (get_event_teams_v3), and each family gets one notification naming
-- their child's team. After a republish only families whose child moved are
-- told. Players on no team ("No Team" squad or none) are not notified.
-- Turning it off hides the teams again and sends nothing.
--
-- Additive: two new tables (RLS on, no policies; only these functions touch
-- them), three functions and a deferred trigger on match_squads. The trigger
-- does nothing unless the switch is on for the event, which only v3 can set,
-- and it never blocks a publish.

CREATE TABLE IF NOT EXISTS public.event_team_shares (
    event_id   bigint PRIMARY KEY REFERENCES public.events(event_id) ON DELETE CASCADE,
    shared     boolean NOT NULL DEFAULT false,
    shared_at  timestamptz,
    shared_by  uuid,
    updated_at timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE public.event_team_shares ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.event_team_shares FROM anon, authenticated;

-- What each member's family was last told (squad_id null = not on a team).
CREATE TABLE IF NOT EXISTS public.event_team_share_sent (
    event_id  bigint NOT NULL REFERENCES public.events(event_id) ON DELETE CASCADE,
    member_id bigint NOT NULL,
    squad_id  bigint,
    sent_at   timestamptz NOT NULL DEFAULT now(),
    PRIMARY KEY (event_id, member_id)
);
ALTER TABLE public.event_team_share_sent ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.event_team_share_sent FROM anon, authenticated;


-- Tell families about the latest published teams for an event. Internal:
-- called by set_event_teams_shared and the match_squads trigger.
-- Returns the number of people notified.
CREATE OR REPLACE FUNCTION public.notify_event_teams(p_event_id bigint)
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = 'public'
AS $$
DECLARE
    v_shared  boolean;
    v_ms      bigint;
    v_team_id bigint;
    v_team    text;
    v_title   text;
    v_when    text;
    v_n       int := 0;
BEGIN
    SELECT s.shared INTO v_shared
    FROM public.event_team_shares s WHERE s.event_id = p_event_id;
    IF NOT COALESCE(v_shared, false) THEN
        RETURN 0;
    END IF;

    SELECT msq.match_squad_id INTO v_ms
    FROM public.match_squads msq
    WHERE msq.event_id = p_event_id
    ORDER BY msq.created_at DESC, msq.match_squad_id DESC
    LIMIT 1;
    IF v_ms IS NULL THEN
        RETURN 0;
    END IF;

    SELECT
        e.team_id,
        t.team_name,
        trim(CASE
            WHEN e.event_title IS NOT NULL AND e.event_title <> '' THEN e.event_title
            ELSE (CASE WHEN t.team_female = true AND ec.code_id = 3 THEN 'Camogie'
                       ELSE COALESCE(ec.event_code, '') END)
                 || ' ' || COALESCE(et.event_type, '')
                 || CASE WHEN et.event_type_id = 2 AND COALESCE(e.opposition, '') <> ''
                         THEN ' - ' || e.opposition ELSE '' END
        END),
        to_char(e.event_date_time, 'Dy FMDD Mon')
    INTO v_team_id, v_team, v_title, v_when
    FROM public.events e
    JOIN public.teams t ON t.team_id = e.team_id
    LEFT JOIN public.event_codes ec ON ec.code_id = e.event_code_id
    LEFT JOIN public.event_types et ON et.event_type_id = e.event_type_id
    WHERE e.event_id = p_event_id;

    WITH cur AS (
        SELECT DISTINCT ON (d.member_id)
            d.member_id,
            CASE WHEN sq.squad_id IS NULL OR sq.squad_name ILIKE 'no team' THEN NULL
                 ELSE sq.squad_id END AS squad_id,
            sq.squad_name
        FROM public.match_squad_details d
        LEFT JOIN public.squads sq ON sq.squad_id = d.squad_id
        WHERE d.match_squad_id = v_ms AND d.member_id IS NOT NULL
        ORDER BY d.member_id, d.id DESC
    ),
    chg AS (
        SELECT c.member_id, c.squad_name,
               (s.member_id IS NULL OR s.squad_id IS NULL) AS first_time
        FROM cur c
        LEFT JOIN public.event_team_share_sent s
               ON s.event_id = p_event_id AND s.member_id = c.member_id
        WHERE c.squad_id IS NOT NULL
          AND (s.member_id IS NULL OR s.squad_id IS DISTINCT FROM c.squad_id)
    ),
    lines AS (
        SELECT DISTINCT uml.user_id, ch.member_id, ch.first_time,
            COALESCE(NULLIF(trim(m.first_name), ''), 'Your player')
              || CASE WHEN ch.first_time THEN ' is on ' ELSE ' has moved to ' END
              || ch.squad_name AS line
        FROM chg ch
        JOIN public.members m ON m.member_id = ch.member_id
        JOIN public.user_member_link uml
          ON uml.member_id = ch.member_id AND uml.status = 'active'
    ),
    per_user AS (
        SELECT user_id,
               string_agg(line, ', ' ORDER BY line) AS body,
               bool_or(first_time) AS any_first,
               min(member_id) AS one_member,
               count(DISTINCT member_id) AS n
        FROM lines
        GROUP BY user_id
    )
    INSERT INTO public.notifications (
        recipient_user_id, team_id, event_id, member_id, link_page,
        is_delivered, is_read, delivery_method, created_at,
        push_title, push_body, app_title, app_body)
    SELECT u.user_id, v_team_id, p_event_id,
        CASE WHEN p.n = 1 THEN p.one_member END,
        'Notifications', false, false,
        CASE WHEN COALESCE(u.fcm_token, '') <> '' THEN 'push' ELSE 'email' END,
        NOW(),
        v_team || ': ' || CASE WHEN p.any_first THEN 'Teams are out' ELSE 'Team change' END,
        v_title || ', ' || v_when || ': ' || p.body || '.',
        CASE WHEN p.any_first THEN 'Teams are out' ELSE 'Team change' END,
        v_title || ', ' || v_when || ': ' || p.body || '.'
    FROM per_user p
    JOIN public.users u ON u.user_id = p.user_id AND u.deleted_at IS NULL;
    GET DIAGNOSTICS v_n = ROW_COUNT;

    -- Remember what every family now knows.
    INSERT INTO public.event_team_share_sent (event_id, member_id, squad_id, sent_at)
    SELECT p_event_id, c.member_id, c.squad_id, now()
    FROM (
        SELECT DISTINCT ON (d.member_id)
            d.member_id,
            CASE WHEN sq.squad_id IS NULL OR sq.squad_name ILIKE 'no team' THEN NULL
                 ELSE sq.squad_id END AS squad_id
        FROM public.match_squad_details d
        LEFT JOIN public.squads sq ON sq.squad_id = d.squad_id
        WHERE d.match_squad_id = v_ms AND d.member_id IS NOT NULL
        ORDER BY d.member_id, d.id DESC
    ) c
    ON CONFLICT (event_id, member_id) DO UPDATE
        SET squad_id = EXCLUDED.squad_id, sent_at = now()
        WHERE public.event_team_share_sent.squad_id IS DISTINCT FROM EXCLUDED.squad_id;

    RETURN v_n;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.notify_event_teams(bigint) FROM PUBLIC, anon, authenticated;


-- Admin switch. Returns {shared, shared_at, notified}.
CREATE OR REPLACE FUNCTION public.set_event_teams_shared(p_event_id bigint, p_shared boolean)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = 'public'
AS $$
DECLARE
    v_team_id bigint;
    v_level   int;
    v_n       int := 0;
    v_at      timestamptz;
BEGIN
    IF auth.uid() IS NULL THEN
        RAISE EXCEPTION 'Not signed in';
    END IF;

    SELECT e.team_id INTO v_team_id FROM public.events e WHERE e.event_id = p_event_id;
    IF v_team_id IS NULL THEN
        RAISE EXCEPTION 'Event not found';
    END IF;

    SELECT COALESCE(MAX(r.role_level), 0) INTO v_level
    FROM public.member_team_link mtl
    JOIN public.user_member_link uml ON uml.member_id = mtl.member_id AND uml.status = 'active'
    JOIN public.member_team_role_link mtrl ON mtrl.member_team_id = mtl.member_team_id
    JOIN public.roles r ON r.role_id = mtrl.role_id
    WHERE mtl.team_id = v_team_id AND mtl.status = 'active' AND uml.user_id = auth.uid();
    IF v_level < 100 THEN
        RAISE EXCEPTION 'Only team admins can share the teams';
    END IF;

    IF p_shared AND NOT EXISTS (SELECT 1 FROM public.match_squads WHERE event_id = p_event_id) THEN
        RAISE EXCEPTION 'Publish the teams first';
    END IF;

    INSERT INTO public.event_team_shares (event_id, shared, shared_at, shared_by, updated_at)
    VALUES (p_event_id, p_shared, CASE WHEN p_shared THEN now() END,
            CASE WHEN p_shared THEN auth.uid() END, now())
    ON CONFLICT (event_id) DO UPDATE SET
        shared     = EXCLUDED.shared,
        shared_at  = CASE WHEN EXCLUDED.shared THEN now() ELSE public.event_team_shares.shared_at END,
        shared_by  = CASE WHEN EXCLUDED.shared THEN auth.uid() ELSE public.event_team_shares.shared_by END,
        updated_at = now()
    RETURNING shared_at INTO v_at;

    IF p_shared THEN
        v_n := public.notify_event_teams(p_event_id);
    END IF;

    RETURN jsonb_build_object('shared', p_shared, 'shared_at', v_at, 'notified', v_n);
END;
$$;
REVOKE EXECUTE ON FUNCTION public.set_event_teams_shared(bigint, boolean) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.set_event_teams_shared(bigint, boolean) TO authenticated;


-- The published teams for one event, for any active member of the team.
-- Returns:
--   shared, shared_at, is_admin, published (a snapshot exists)
--   families_told   admins only: people told so far
--   mine   [{member_id, first_name, squad_id, squad_name, squad_colour, squad_image}]
--          the caller's linked members in the snapshot; squad_id null = no team
--   squads [{squad_id, squad_name, squad_colour, squad_image,
--            members: [{member_id, name, mine}]}]
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
            sq.squad_name, sq.squad_colour, sq.squad_image, sq.squad_list_seq
        FROM public.match_squad_details d
        JOIN public.members m ON m.member_id = d.member_id
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
                   'mine', c.member_id IN (SELECT member_id FROM my_members))
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


-- After a (re)publish, from v2 or v3: tell families whose child moved, if the
-- switch is on. Deferred so it runs once the squad rows are written. Never
-- blocks the publish.
CREATE OR REPLACE FUNCTION public.match_squads_notify_teams()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = 'public'
AS $$
BEGIN
    BEGIN
        PERFORM public.notify_event_teams(NEW.event_id);
    EXCEPTION WHEN OTHERS THEN
        RAISE WARNING 'notify_event_teams(%) failed: %', NEW.event_id, SQLERRM;
    END;
    RETURN NULL;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.match_squads_notify_teams() FROM PUBLIC, anon, authenticated;

DROP TRIGGER IF EXISTS match_squads_notify_teams ON public.match_squads;
CREATE CONSTRAINT TRIGGER match_squads_notify_teams
    AFTER INSERT ON public.match_squads
    DEFERRABLE INITIALLY DEFERRED
    FOR EACH ROW EXECUTE FUNCTION public.match_squads_notify_teams();
