-- Team sponsors (Ken, 2026-11-25, thread "Explore advertising in CoachSmart").
-- A club sponsor can be assigned to one team. It then shows only on that
-- team's event screens and live scores (never Home), in place of the
-- club-wide sponsor. Set up by club officers on coachsmart.app/club/
-- sponsors.html. v3 only; the old app never reads these.

ALTER TABLE public.club_sponsors
  ADD COLUMN IF NOT EXISTS team_id bigint REFERENCES public.teams(team_id) ON DELETE CASCADE;
CREATE INDEX IF NOT EXISTS club_sponsors_team ON public.club_sponsors (team_id) WHERE team_id IS NOT NULL;

-- A team sponsor never shows on Home.
UPDATE public.club_sponsors SET on_home = false WHERE team_id IS NOT NULL AND on_home;

-- { teams, sponsors }: one club-wide sponsor per club (team_id null) and one
-- per team of those clubs (for club-wide live matches too).
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

  SELECT coalesce(jsonb_agg(x ORDER BY x->>'club_id', x->>'team_id'), '[]'::jsonb) INTO v_sponsors
  FROM (
    SELECT DISTINCT ON (s.club_id, coalesce(s.team_id, 0)) jsonb_build_object(
      'sponsor_id', s.sponsor_id, 'club_id', s.club_id, 'team_id', s.team_id, 'name', s.name,
      'tagline', coalesce(s.tagline, ''), 'link_url', coalesce(s.link_url, ''),
      'logo_url', CASE WHEN s.logo_path IS NULL THEN ''
                       ELSE 'https://gyfporsbdftvtakdvukt.supabase.co/storage/v1/object/public/sponsors/' || s.logo_path END,
      'card_colour', coalesce(s.card_colour, ''), 'status', s.status,
      'on_home', s.on_home AND s.team_id IS NULL, 'on_events', s.on_events, 'on_live', s.on_live) AS x
    FROM club_sponsors s
    WHERE s.club_id IN (SELECT club_id FROM sponsor_user_teams(v_uid))
      AND (s.starts_on IS NULL OR s.starts_on <= v_today)
      AND (s.ends_on IS NULL OR s.ends_on >= v_today)
      AND (s.status = 'live' OR (s.status = 'draft' AND sponsor_can_manage(v_uid, s.club_id)))
    ORDER BY s.club_id, coalesce(s.team_id, 0), (s.status = 'live') DESC, s.sponsor_id DESC
  ) q;

  RETURN jsonb_build_object('teams', v_teams, 'sponsors', v_sponsors);
END $$;

REVOKE ALL ON FUNCTION public.get_my_sponsors() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_my_sponsors() TO authenticated;

-- Same as before, but a team sponsor counts only on its own team (never on
-- Home) and always against that team.
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

  IF v_s.team_id IS NOT NULL THEN
    IF p_placement = 'home' OR (p_event_id IS NOT NULL AND v_team <> v_s.team_id) THEN
      RETURN false;
    END IF;
    v_team := v_s.team_id;
  END IF;

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
