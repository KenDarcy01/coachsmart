-- Club sponsors with reach counting (2026-11-25, thread "Explore advertising
-- in CoachSmart"). v3 only: the old app never reads these.
--
-- A club adds its own sponsor (club officers on coachsmart.app/club/
-- sponsors.html). v3 shows a sponsor card on Home, event screens and live
-- scores, and counts it once it has been on screen for a second.
--
-- Privacy (Ken's rules): totals only. A view adds 1 to a daily total per
-- sponsor, team and screen. "People reached" uses a hashed id per sponsor and
-- month; at month end the count is kept and the hashes are deleted. Sponsors
-- are never shown to, or counted for, a child's own login (a user whose own
-- name matches a player they are linked to on an underage team).
-- Drafts are shown only to super users and the club's officers, never counted.

CREATE TABLE IF NOT EXISTS public.club_sponsors (
  sponsor_id   bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  club_id      bigint NOT NULL REFERENCES public.clubs(club_id) ON DELETE CASCADE,
  name         text   NOT NULL,
  tagline      text,
  link_url     text,
  logo_path    text,
  card_colour  text,
  status       text   NOT NULL DEFAULT 'draft' CHECK (status IN ('draft', 'live', 'ended')),
  on_home      boolean NOT NULL DEFAULT true,
  on_events    boolean NOT NULL DEFAULT true,
  on_live      boolean NOT NULL DEFAULT true,
  starts_on    date,
  ends_on      date,
  created_by   uuid,
  created_at   timestamptz NOT NULL DEFAULT now(),
  updated_at   timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS club_sponsors_club ON public.club_sponsors (club_id);
ALTER TABLE public.club_sponsors ENABLE ROW LEVEL SECURITY;

-- Daily totals. team_id 0 = no team (Home with every team showing).
CREATE TABLE IF NOT EXISTS public.sponsor_counts (
  sponsor_id bigint NOT NULL REFERENCES public.club_sponsors(sponsor_id) ON DELETE CASCADE,
  day        date   NOT NULL,
  team_id    bigint NOT NULL DEFAULT 0,
  placement  text   NOT NULL CHECK (placement IN ('home', 'event', 'live')),
  views      integer NOT NULL DEFAULT 0,
  taps       integer NOT NULL DEFAULT 0,
  PRIMARY KEY (sponsor_id, day, team_id, placement)
);
ALTER TABLE public.sponsor_counts ENABLE ROW LEVEL SECURITY;

-- This month's viewers, as hashes only, plus a per-day counter that caps one
-- person at 100 counted views a day. Emptied for each month once it closes.
CREATE TABLE IF NOT EXISTS public.sponsor_viewers (
  sponsor_id bigint NOT NULL REFERENCES public.club_sponsors(sponsor_id) ON DELETE CASCADE,
  month      date   NOT NULL,
  viewer     text   NOT NULL,
  day        date   NOT NULL,
  day_views  integer NOT NULL DEFAULT 0,
  PRIMARY KEY (sponsor_id, month, viewer)
);
ALTER TABLE public.sponsor_viewers ENABLE ROW LEVEL SECURITY;

-- People reached per closed month.
CREATE TABLE IF NOT EXISTS public.sponsor_reach_month (
  sponsor_id bigint NOT NULL REFERENCES public.club_sponsors(sponsor_id) ON DELETE CASCADE,
  month      date   NOT NULL,
  people     integer NOT NULL,
  PRIMARY KEY (sponsor_id, month)
);
ALTER TABLE public.sponsor_reach_month ENABLE ROW LEVEL SECURITY;

-- Public bucket for sponsor logos (uploads go through the sponsors edge
-- function with the service role).
INSERT INTO storage.buckets (id, name, public)
VALUES ('sponsors', 'sponsors', true)
ON CONFLICT (id) DO NOTHING;

-- ── helpers ──────────────────────────────────────────────────────────────

-- The user's active teams (through their member links) with each team's club.
CREATE OR REPLACE FUNCTION public.sponsor_user_teams(p_uid uuid)
RETURNS TABLE (team_id bigint, club_id bigint)
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT DISTINCT t.team_id, t.club_id
  FROM user_member_link uml
  JOIN member_team_link mtl ON mtl.member_id = uml.member_id AND mtl.status = 'active'
  JOIN teams t ON t.team_id = mtl.team_id
  WHERE uml.user_id = p_uid AND coalesce(uml.status, 'active') = 'active' AND t.club_id IS NOT NULL;
$$;

-- True when the user looks like a child's own login: linked to a player on an
-- underage team whose name is the user's own name.
CREATE OR REPLACE FUNCTION public.sponsor_is_child_login(p_uid uuid)
RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT EXISTS (
    SELECT 1
    FROM users u
    JOIN user_member_link uml ON uml.user_id = u.user_id AND coalesce(uml.status, 'active') = 'active'
    JOIN members m ON m.member_id = uml.member_id
    JOIN member_team_link mtl ON mtl.member_id = m.member_id AND mtl.status = 'active'
    JOIN teams t ON t.team_id = mtl.team_id AND t.team_juvenile IS TRUE
    JOIN member_team_role_link mr ON mr.member_team_id = mtl.member_team_id
    JOIN roles r ON r.role_id = mr.role_id AND r.role_level = 10
    WHERE u.user_id = p_uid
      AND lower(trim(u.first_name)) = lower(trim(m.first_name))
      AND lower(trim(u.last_name)) = lower(trim(m.last_name))
  );
$$;

-- Super user anywhere, or an active officer (dashboard) of the club.
CREATE OR REPLACE FUNCTION public.sponsor_can_manage(p_uid uuid, p_club bigint)
RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT EXISTS (
    SELECT 1
    FROM user_member_link uml
    JOIN member_team_link mtl ON mtl.member_id = uml.member_id AND mtl.status = 'active'
    JOIN member_team_role_link mr ON mr.member_team_id = mtl.member_team_id
    JOIN roles r ON r.role_id = mr.role_id
    WHERE uml.user_id = p_uid AND coalesce(uml.status, 'active') = 'active' AND r.role_level >= 110
  ) OR EXISTS (
    SELECT 1 FROM club_officers o
    WHERE o.user_id = p_uid AND o.club_id = p_club AND o.is_active AND o.can_dashboard
  );
$$;

REVOKE ALL ON FUNCTION public.sponsor_user_teams(uuid) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.sponsor_is_child_login(uuid) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.sponsor_can_manage(uuid, bigint) FROM PUBLIC, anon, authenticated;

-- ── v3: sponsors for the signed-in user ─────────────────────────────────
-- { teams: [{team_id, club_id}], sponsors: [{sponsor_id, club_id, name, ...}] }
-- One sponsor per club (the newest live one; drafts only for managers).
CREATE OR REPLACE FUNCTION public.get_my_sponsors()
RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_uid uuid := auth.uid();
  v_today date := (now() AT TIME ZONE 'Europe/Dublin')::date;
  v_teams jsonb;
  v_sponsors jsonb;
BEGIN
  IF v_uid IS NULL THEN
    RETURN jsonb_build_object('teams', '[]'::jsonb, 'sponsors', '[]'::jsonb);
  END IF;

  SELECT coalesce(jsonb_agg(jsonb_build_object('team_id', team_id, 'club_id', club_id)), '[]'::jsonb)
  INTO v_teams FROM sponsor_user_teams(v_uid);

  IF sponsor_is_child_login(v_uid) THEN
    RETURN jsonb_build_object('teams', v_teams, 'sponsors', '[]'::jsonb);
  END IF;

  SELECT coalesce(jsonb_agg(x ORDER BY x->>'club_id'), '[]'::jsonb) INTO v_sponsors
  FROM (
    SELECT DISTINCT ON (s.club_id) jsonb_build_object(
      'sponsor_id', s.sponsor_id, 'club_id', s.club_id, 'name', s.name,
      'tagline', coalesce(s.tagline, ''), 'link_url', coalesce(s.link_url, ''),
      'logo_url', CASE WHEN s.logo_path IS NULL THEN ''
                       ELSE 'https://gyfporsbdftvtakdvukt.supabase.co/storage/v1/object/public/sponsors/' || s.logo_path END,
      'card_colour', coalesce(s.card_colour, ''), 'status', s.status,
      'on_home', s.on_home, 'on_events', s.on_events, 'on_live', s.on_live) AS x
    FROM club_sponsors s
    WHERE s.club_id IN (SELECT club_id FROM sponsor_user_teams(v_uid))
      AND (s.starts_on IS NULL OR s.starts_on <= v_today)
      AND (s.ends_on IS NULL OR s.ends_on >= v_today)
      AND (s.status = 'live' OR (s.status = 'draft' AND sponsor_can_manage(v_uid, s.club_id)))
    ORDER BY s.club_id, (s.status = 'live') DESC, s.sponsor_id DESC
  ) q;

  RETURN jsonb_build_object('teams', v_teams, 'sponsors', v_sponsors);
END $$;

REVOKE ALL ON FUNCTION public.get_my_sponsors() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_my_sponsors() TO authenticated;

-- ── v3: count a view or a tap ───────────────────────────────────────────
-- p_kind 'view' | 'tap'. Team comes from the event when one is given, else
-- p_team_id; either must be a team of the sponsor's club, otherwise 0.
-- Returns true when it was counted.
CREATE OR REPLACE FUNCTION public.sponsor_seen(
  p_sponsor_id bigint, p_placement text, p_kind text DEFAULT 'view',
  p_event_id bigint DEFAULT NULL, p_team_id bigint DEFAULT NULL)
RETURNS boolean
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_uid uuid := auth.uid();
  v_s club_sponsors;
  v_team bigint := 0;
  v_day date := (now() AT TIME ZONE 'Europe/Dublin')::date;
  v_month date := date_trunc('month', (now() AT TIME ZONE 'Europe/Dublin'))::date;
  v_n integer;
BEGIN
  IF v_uid IS NULL OR p_placement NOT IN ('home', 'event', 'live') OR p_kind NOT IN ('view', 'tap') THEN
    RETURN false;
  END IF;
  SELECT * INTO v_s FROM club_sponsors WHERE sponsor_id = p_sponsor_id;
  IF NOT FOUND OR v_s.status <> 'live' THEN RETURN false; END IF;
  IF NOT EXISTS (SELECT 1 FROM sponsor_user_teams(v_uid) WHERE club_id = v_s.club_id) THEN RETURN false; END IF;
  IF sponsor_is_child_login(v_uid) THEN RETURN false; END IF;

  IF p_event_id IS NOT NULL THEN
    SELECT e.team_id INTO v_team FROM events e JOIN teams t ON t.team_id = e.team_id
    WHERE e.event_id = p_event_id AND t.club_id = v_s.club_id;
  ELSIF p_team_id IS NOT NULL AND p_team_id > 0 THEN
    SELECT t.team_id INTO v_team FROM teams t WHERE t.team_id = p_team_id AND t.club_id = v_s.club_id;
  END IF;
  v_team := coalesce(v_team, 0);

  IF p_kind = 'view' THEN
    INSERT INTO sponsor_viewers AS v (sponsor_id, month, viewer, day, day_views)
    VALUES (v_s.sponsor_id, v_month, md5(v_uid::text || ':' || v_s.sponsor_id || ':' || v_month), v_day, 1)
    ON CONFLICT (sponsor_id, month, viewer) DO UPDATE
      SET day_views = CASE WHEN v.day = EXCLUDED.day THEN v.day_views + 1 ELSE 1 END,
          day = EXCLUDED.day
    RETURNING day_views INTO v_n;
    IF v_n > 100 THEN RETURN false; END IF;
  END IF;

  INSERT INTO sponsor_counts AS c (sponsor_id, day, team_id, placement, views, taps)
  VALUES (v_s.sponsor_id, v_day, v_team, p_placement,
          CASE WHEN p_kind = 'view' THEN 1 ELSE 0 END, CASE WHEN p_kind = 'tap' THEN 1 ELSE 0 END)
  ON CONFLICT (sponsor_id, day, team_id, placement) DO UPDATE
    SET views = c.views + EXCLUDED.views, taps = c.taps + EXCLUDED.taps;
  RETURN true;
END $$;

REVOKE ALL ON FUNCTION public.sponsor_seen(bigint, text, text, bigint, bigint) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.sponsor_seen(bigint, text, text, bigint, bigint) TO authenticated;

-- ── month end: keep the people count, delete the hashes ─────────────────
CREATE OR REPLACE FUNCTION public.sponsor_close_months()
RETURNS integer
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_month date := date_trunc('month', (now() AT TIME ZONE 'Europe/Dublin'))::date;
  v_n integer;
BEGIN
  INSERT INTO sponsor_reach_month (sponsor_id, month, people)
  SELECT sponsor_id, month, count(*) FROM sponsor_viewers WHERE month < v_month GROUP BY 1, 2
  ON CONFLICT (sponsor_id, month) DO UPDATE SET people = sponsor_reach_month.people + EXCLUDED.people;
  DELETE FROM sponsor_viewers WHERE month < v_month;
  GET DIAGNOSTICS v_n = ROW_COUNT;
  RETURN v_n;
END $$;
REVOKE ALL ON FUNCTION public.sponsor_close_months() FROM PUBLIC, anon, authenticated;

DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'pg_cron') THEN
    PERFORM cron.unschedule(jobname) FROM cron.job WHERE jobname = 'sponsor-close-months';
    PERFORM cron.schedule('sponsor-close-months', '20 2 1 * *', $c$SELECT public.sponsor_close_months()$c$);
  END IF;
END;
$$;

-- The sponsors edge function (service role) checks access with this.
GRANT EXECUTE ON FUNCTION public.sponsor_can_manage(uuid, bigint) TO service_role;
