-- Club officer access ticks (Ken, 2026-11-18): each officer gets
-- "Pitch planner" and/or "Club dashboard". A club's pitch admin (not on
-- CoachSmart, no team) is invited with only the planner, so she never sees
-- the dashboard's player names and attendance. Existing officers keep both.
-- SuperUsers still get everything for every club.
--   is_club_officer(club)      = dashboard access (all get_club_* functions)
--   is_club_pitch_admin(club)  = planner access (all pitch_* writes)
-- Additive; v2 untouched.

ALTER TABLE public.club_officers
  ADD COLUMN IF NOT EXISTS can_pitches   boolean NOT NULL DEFAULT true,
  ADD COLUMN IF NOT EXISTS can_dashboard boolean NOT NULL DEFAULT true;
ALTER TABLE public.club_officer_invites
  ADD COLUMN IF NOT EXISTS can_pitches   boolean NOT NULL DEFAULT true,
  ADD COLUMN IF NOT EXISTS can_dashboard boolean NOT NULL DEFAULT true;

CREATE OR REPLACE FUNCTION public.is_club_officer(p_club_id bigint)
 RETURNS boolean
 LANGUAGE sql STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $$
  SELECT auth.uid() IS NOT NULL AND (
         public.is_app_super_user()
      OR EXISTS (SELECT 1 FROM club_officers co
                  WHERE co.club_id = p_club_id
                    AND co.user_id = auth.uid()
                    AND co.is_active AND co.can_dashboard));
$$;

CREATE OR REPLACE FUNCTION public.is_club_pitch_admin(p_club bigint)
RETURNS boolean LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = 'public' AS $$
BEGIN
  RETURN auth.uid() IS NOT NULL AND (
         coalesce(public.is_app_super_user(), false)
      OR EXISTS (SELECT 1 FROM club_officers co
                  WHERE co.club_id = p_club AND co.user_id = auth.uid()
                    AND co.is_active AND co.can_pitches));
END $$;

-- Dashboard page: clubs whose dashboard the caller can open.
CREATE OR REPLACE FUNCTION public.get_my_officer_clubs()
 RETURNS jsonb
 LANGUAGE sql STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $$
  SELECT jsonb_build_object(
    'is_super_user', public.is_app_super_user(),
    'pitch_clubs', (SELECT coalesce(jsonb_agg(co2.club_id), '[]'::jsonb) FROM club_officers co2
                     WHERE co2.user_id = auth.uid() AND co2.is_active AND co2.can_pitches),
    'clubs', COALESCE(jsonb_agg(jsonb_build_object(
        'club_id', c.club_id, 'club_name', c.club_name, 'crest', c.crest,
        'primary_colour', c.primary_colour, 'secondary_colour', c.secondary_colour,
        'title', co.title) ORDER BY c.club_name), '[]'::jsonb))
    FROM clubs c
    LEFT JOIN club_officers co ON co.club_id = c.club_id AND co.user_id = auth.uid()
                              AND co.is_active AND co.can_dashboard
   WHERE auth.uid() IS NOT NULL
     AND (co.club_officer_id IS NOT NULL OR public.is_app_super_user());
$$;

-- Pitch planner: clubs whose planner the caller can open.
CREATE OR REPLACE FUNCTION public.pitch_officer_clubs()
 RETURNS jsonb
 LANGUAGE sql STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $$
  SELECT coalesce(jsonb_agg(jsonb_build_object(
        'club_id', c.club_id, 'club_name', c.club_name, 'crest', c.crest,
        'primary_colour', c.primary_colour, 'secondary_colour', c.secondary_colour,
        'third_colour', c.third_colour, 'title', co.title) ORDER BY c.club_name), '[]'::jsonb)
    FROM clubs c
    LEFT JOIN club_officers co ON co.club_id = c.club_id AND co.user_id = auth.uid()
                              AND co.is_active AND co.can_pitches
   WHERE auth.uid() IS NOT NULL
     AND (co.club_officer_id IS NOT NULL OR public.is_app_super_user());
$$;

-- Public club branding for a club's sign-in screen (name, crest, colours).
CREATE OR REPLACE FUNCTION public.club_brand(p_club bigint)
 RETURNS jsonb
 LANGUAGE sql STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $$
  SELECT jsonb_build_object('club_id', c.club_id, 'club_name', c.club_name, 'crest', c.crest,
           'primary_colour', c.primary_colour, 'secondary_colour', c.secondary_colour,
           'third_colour', c.third_colour)
    FROM clubs c WHERE c.club_id = p_club;
$$;

-- Officer list with the ticks.
CREATE OR REPLACE FUNCTION public.club_officer_list(p_club_id bigint)
 RETURNS jsonb
 LANGUAGE plpgsql STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $$
BEGIN
  IF NOT public.is_app_super_user() THEN
    RETURN jsonb_build_object('error', 'Only a SuperUser can manage club officers');
  END IF;
  RETURN jsonb_build_object(
    'officers', COALESCE((
      SELECT jsonb_agg(jsonb_build_object(
               'user_id', u.user_id,
               'name', trim(COALESCE(u.first_name, '') || ' ' || COALESCE(u.last_name, '')),
               'email', u.email_address, 'title', co.title, 'created_at', co.created_at,
               'can_pitches', co.can_pitches, 'can_dashboard', co.can_dashboard)
             ORDER BY co.created_at)
        FROM club_officers co JOIN users u ON u.user_id = co.user_id
       WHERE co.club_id = p_club_id AND co.is_active), '[]'::jsonb),
    'invites', COALESCE((
      SELECT jsonb_agg(jsonb_build_object(
               'email', i.email, 'title', i.title,
               'name', trim(COALESCE(i.first_name, '') || ' ' || COALESCE(i.last_name, '')),
               'sent_at', i.sent_at, 'can_pitches', i.can_pitches,
               'can_dashboard', i.can_dashboard) ORDER BY i.created_at)
        FROM club_officer_invites i
       WHERE i.club_id = p_club_id AND i.accepted_at IS NULL), '[]'::jsonb));
END;
$$;

-- Change an officer's ticks (SuperUser only). At least one must stay on.
CREATE OR REPLACE FUNCTION public.club_officer_set_access(p_club_id bigint, p_user_id uuid,
  p_pitches boolean, p_dashboard boolean)
 RETURNS jsonb
 LANGUAGE plpgsql SECURITY DEFINER
 SET search_path TO 'public'
AS $$
BEGIN
  IF NOT public.is_app_super_user() THEN
    RETURN jsonb_build_object('error', 'Only a SuperUser can manage club officers');
  END IF;
  IF NOT (p_pitches OR p_dashboard) THEN
    RETURN jsonb_build_object('error', 'Tick at least one, or remove the officer');
  END IF;
  UPDATE club_officers SET can_pitches = p_pitches, can_dashboard = p_dashboard
   WHERE club_id = p_club_id AND user_id = p_user_id;
  RETURN jsonb_build_object('ok', true);
END;
$$;

-- Pending invites carry their ticks onto the officer row.
CREATE OR REPLACE FUNCTION public.club_officer_claim_invites()
 RETURNS integer
 LANGUAGE plpgsql SECURITY DEFINER
 SET search_path TO 'public'
AS $$
DECLARE
    v_uid   uuid := auth.uid();
    v_email text;
    v_n     integer := 0;
    r       record;
BEGIN
    IF v_uid IS NULL THEN RETURN 0; END IF;
    SELECT au.email INTO v_email FROM auth.users au WHERE au.id = v_uid;
    IF v_email IS NULL OR NOT EXISTS (SELECT 1 FROM users WHERE user_id = v_uid) THEN
        RETURN 0;
    END IF;
    FOR r IN SELECT * FROM club_officer_invites
              WHERE lower(email) = lower(v_email) AND accepted_at IS NULL
    LOOP
        INSERT INTO club_officers (club_id, user_id, title, created_by, can_pitches, can_dashboard)
        VALUES (r.club_id, v_uid, r.title, r.created_by, r.can_pitches, r.can_dashboard)
        ON CONFLICT (club_id, user_id) DO UPDATE
           SET is_active = true, title = EXCLUDED.title,
               can_pitches = EXCLUDED.can_pitches, can_dashboard = EXCLUDED.can_dashboard;
        UPDATE users
           SET first_name = COALESCE(NULLIF(first_name, ''), r.first_name),
               last_name  = COALESCE(NULLIF(last_name, ''),  r.last_name)
         WHERE user_id = v_uid;
        UPDATE club_officer_invites SET accepted_at = now() WHERE invite_id = r.invite_id;
        v_n := v_n + 1;
    END LOOP;
    RETURN v_n;
END;
$$;

-- Planner-only officers can see the published plan too.
CREATE OR REPLACE FUNCTION public.pitch_member_clubs()
RETURNS jsonb LANGUAGE sql STABLE SECURITY DEFINER SET search_path = 'public' AS $$
  SELECT coalesce(jsonb_agg(jsonb_build_object(
           'club_id', c.club_id, 'club_name', c.club_name, 'crest', c.crest,
           'primary_colour', c.primary_colour, 'secondary_colour', c.secondary_colour,
           'third_colour', c.third_colour,
           'officer', coalesce(public.is_club_pitch_admin(c.club_id), false)) ORDER BY c.club_name), '[]'::jsonb)
    FROM clubs c
   WHERE auth.uid() IS NOT NULL
     AND (c.club_id IN (SELECT t.club_id FROM teams t
                          JOIN member_team_link mtl ON mtl.team_id = t.team_id AND mtl.status = 'active'
                          JOIN members m ON m.member_id = mtl.member_id
                         WHERE m.user_id = auth.uid())
          OR coalesce(public.is_club_officer(c.club_id), false)
          OR coalesce(public.is_club_pitch_admin(c.club_id), false))
     AND EXISTS (SELECT 1 FROM pitch_weeks w WHERE w.club_id = c.club_id AND w.published_at IS NOT NULL);
$$;

CREATE OR REPLACE FUNCTION public.pitch_published_week(p_club bigint, p_monday date)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = 'public' AS $$
DECLARE
  w pitch_weeks%ROWTYPE;
  v_week date := date_trunc('week', p_monday::timestamp)::date;
  v_mine jsonb;
BEGIN
  IF auth.uid() IS NULL OR NOT (
       coalesce(public.is_club_officer(p_club), false)
       OR coalesce(public.is_club_pitch_admin(p_club), false)
       OR EXISTS (SELECT 1 FROM teams t
                    JOIN member_team_link mtl ON mtl.team_id = t.team_id AND mtl.status = 'active'
                    JOIN members m ON m.member_id = mtl.member_id
                   WHERE m.user_id = auth.uid() AND t.club_id = p_club)) THEN
    RAISE EXCEPTION 'Only club members can see the pitch plan' USING ERRCODE = '42501';
  END IF;
  SELECT coalesce(jsonb_agg(DISTINCT t.team_id), '[]'::jsonb) INTO v_mine
    FROM teams t
    JOIN member_team_link mtl ON mtl.team_id = t.team_id AND mtl.status = 'active'
    JOIN members m ON m.member_id = mtl.member_id
   WHERE t.club_id = p_club
     AND (m.user_id = auth.uid()
          OR m.member_id IN (SELECT uml.member_id FROM user_member_link uml WHERE uml.user_id = auth.uid()));
  SELECT * INTO w FROM pitch_weeks WHERE club_id = p_club AND week_start = v_week AND published_at IS NOT NULL;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('week_start', v_week, 'published_at', NULL, 'my_teams', v_mine);
  END IF;
  RETURN w.snapshot || jsonb_build_object(
    'published_at', w.published_at,
    'my_teams', v_mine,
    'hours', coalesce((
      SELECT jsonb_agg(jsonb_build_object('pitch_id', h.pitch_id, 'weekday', h.weekday,
               'opens', to_char(h.opens, 'HH24:MI'), 'closes', to_char(h.closes, 'HH24:MI')))
        FROM pitch_hours h JOIN pitches p ON p.pitch_id = h.pitch_id
       WHERE p.club_id = p_club AND p.is_active), '[]'::jsonb),
    'blocks', coalesce((
      SELECT jsonb_agg(jsonb_build_object('pitch_id', b.pitch_id, 'weekday', b.weekday,
               'opens', to_char(b.opens, 'HH24:MI'), 'closes', to_char(b.closes, 'HH24:MI')))
        FROM pitch_blocks b JOIN pitches p ON p.pitch_id = b.pitch_id
       WHERE p.club_id = p_club AND p.is_active), '[]'::jsonb));
END $$;


REVOKE ALL ON FUNCTION public.pitch_officer_clubs() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.pitch_officer_clubs() TO authenticated;
REVOKE ALL ON FUNCTION public.club_officer_set_access(bigint, uuid, boolean, boolean) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.club_officer_set_access(bigint, uuid, boolean, boolean) TO authenticated;
GRANT EXECUTE ON FUNCTION public.club_brand(bigint) TO anon, authenticated;
