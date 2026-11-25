-- Club home (Ken, 2026-11-25): a fast landing page for club officers at
-- coachsmart.app/club/?club=ID. It shows a tile for each club tool the
-- signed-in user can open, with a small count of what is waiting. The club
-- dashboard (slow, heavy) moves to /club/dashboard.html and only loads when
-- its tile is tapped.
--
-- club_home(club) answers in one small query. Each tile uses the same check
-- the tool itself uses, so a tile never shows for a tool that would refuse:
--   dashboard, this week   is_club_officer(club)        (can_dashboard or SuperUser)
--   pitch planner          is_club_pitch_admin(club)    (can_pitches or SuperUser)
--   newsletter             newsletter_can_manage(uid, club)
--   club partners          sponsor_can_manage(uid, club)
--   officers               is_app_super_user()          (club_officer_list is SuperUser only)
--   spend & gear           spend_has_access()
--   club lotto             a lotto_admins row for this club's lotto
-- Read only, additive; v2 and v3 apps untouched.

CREATE OR REPLACE FUNCTION public.club_home(p_club bigint)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path = 'public' AS $$
DECLARE
  v_uid    uuid := auth.uid();
  v_club   jsonb;
  v_gaa    bigint;
  v_super  boolean;
  v_today  date := (now() AT TIME ZONE 'Europe/Dublin')::date;
  v_mon    date;
  v_from   timestamptz;
  v_to     timestamptz;
  v_tiles  jsonb := '{}'::jsonb;
  v_seen   timestamptz;
  v_n      int;
  v_n2     int;
  v_issue  record;
  v_lotto  bigint;
  v_title  text;
  v_name   text;
BEGIN
  IF v_uid IS NULL THEN
    RETURN jsonb_build_object('error', 'not_signed_in');
  END IF;

  SELECT jsonb_build_object('club_id', c.club_id, 'club_name', c.club_name, 'crest', c.crest,
           'primary_colour', c.primary_colour, 'secondary_colour', c.secondary_colour),
         c.gaa_club_id
    INTO v_club, v_gaa
    FROM clubs c WHERE c.club_id = p_club;
  IF v_club IS NULL THEN
    RETURN jsonb_build_object('error', 'no_club');
  END IF;

  -- Pending officer invites for this email become officer rows first.
  PERFORM public.club_officer_claim_invites();

  v_super := coalesce(public.is_app_super_user(), false);
  v_mon   := v_today - (extract(isodow FROM v_today)::int - 1);
  v_from  := (v_mon::timestamp) AT TIME ZONE 'Europe/Dublin';
  v_to    := ((v_mon + 7)::timestamp) AT TIME ZONE 'Europe/Dublin';

  -- Club dashboard + this week
  IF public.is_club_officer(p_club) THEN
    v_tiles := v_tiles || jsonb_build_object('dashboard', '{}'::jsonb);
    SELECT count(*) INTO v_n FROM gaa_games g
     WHERE v_gaa IS NOT NULL
       AND (g.home_club_id = v_gaa OR g.away_club_id = v_gaa)
       AND g.home_club_id IS DISTINCT FROM g.away_club_id
       AND g.start_at >= v_from AND g.start_at < v_to;
    SELECT count(*) INTO v_n2 FROM events e JOIN teams t ON t.team_id = e.team_id
     WHERE t.club_id = p_club AND e.status = 'active'
       AND e.event_date_time >= v_mon::timestamp AND e.event_date_time < (v_mon + 7)::timestamp;
    v_tiles := v_tiles || jsonb_build_object('week', jsonb_build_object('games', v_n, 'events', v_n2));
  END IF;

  -- Pitch planner: league fixture changes since this user last looked (last 14 days)
  IF public.is_club_pitch_admin(p_club) THEN
    SELECT seen_at INTO v_seen FROM pitch_alert_reads WHERE club_id = p_club AND user_id = v_uid;
    SELECT count(*) INTO v_n FROM pitch_alerts a
     WHERE a.club_id = p_club
       AND a.created_at > greatest(coalesce(v_seen, '-infinity'::timestamptz), now() - interval '14 days');
    v_tiles := v_tiles || jsonb_build_object('pitches', jsonb_build_object('unread', v_n));
  END IF;

  -- Newsletter: the latest issue and where it is up to
  IF public.newsletter_can_manage(v_uid, p_club) THEN
    SELECT i.issue_no, i.status, i.title INTO v_issue
      FROM newsletter_issues i WHERE i.club_id = p_club
     ORDER BY i.week_start DESC LIMIT 1;
    v_tiles := v_tiles || jsonb_build_object('newsletter', jsonb_build_object(
      'title', coalesce(v_issue.title, (SELECT s.title FROM newsletter_settings s WHERE s.club_id = p_club)),
      'issue_no', v_issue.issue_no, 'status', v_issue.status));
  END IF;

  -- Club partners: the live sponsor, if any
  IF public.sponsor_can_manage(v_uid, p_club) THEN
    v_tiles := v_tiles || jsonb_build_object('sponsors', jsonb_build_object(
      'live', (SELECT s.name FROM club_sponsors s WHERE s.club_id = p_club AND s.status = 'live'
                ORDER BY s.sponsor_id DESC LIMIT 1),
      'drafts', (SELECT count(*) FROM club_sponsors s WHERE s.club_id = p_club AND s.status = 'draft')));
  END IF;

  -- Club officers (SuperUsers manage them today)
  IF v_super THEN
    v_tiles := v_tiles || jsonb_build_object('officers', jsonb_build_object(
      'officers', (SELECT count(*) FROM club_officers o WHERE o.club_id = p_club AND o.is_active),
      'invites',  (SELECT count(*) FROM club_officer_invites i WHERE i.club_id = p_club AND i.accepted_at IS NULL)));
  END IF;

  -- Spend & gear: claims and gear requests waiting for a decision
  IF public.spend_has_access() THEN
    SELECT count(*) INTO v_n FROM team_expenses x JOIN teams t ON t.team_id = x.team_id
     WHERE t.club_id = p_club AND x.status = 'submitted';
    SELECT count(*) INTO v_n2 FROM gear_requests g JOIN teams t ON t.team_id = g.team_id
     WHERE t.club_id = p_club AND g.status = 'requested';
    v_tiles := v_tiles || jsonb_build_object('spend', jsonb_build_object('claims', v_n, 'gear', v_n2));
  END IF;

  -- Club lotto: admins of this club's lotto
  SELECT lc.lotto_id INTO v_lotto FROM lotto_clubs lc
    JOIN lotto_admins la ON la.lotto_id = lc.lotto_id AND la.user_id = v_uid
   WHERE lc.club_id = p_club;
  IF v_lotto IS NOT NULL THEN
    v_tiles := v_tiles || jsonb_build_object('lotto', jsonb_build_object('lotto_id', v_lotto,
      'next_draw', (SELECT min(d.draw_at) FROM lotto_draws d WHERE d.lotto_id = v_lotto AND d.status = 'open')));
  END IF;

  SELECT o.title INTO v_title FROM club_officers o
   WHERE o.club_id = p_club AND o.user_id = v_uid AND o.is_active LIMIT 1;
  SELECT nullif(trim(coalesce(u.first_name, '')), '') INTO v_name FROM users u WHERE u.user_id = v_uid;

  RETURN jsonb_build_object(
    'club', v_club,
    'me', jsonb_build_object('first_name', v_name, 'title', coalesce(v_title, CASE WHEN v_super THEN 'SuperUser' END),
                             'is_super_user', v_super),
    'tiles', v_tiles);
END $$;

REVOKE ALL ON FUNCTION public.club_home(bigint) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.club_home(bigint) TO authenticated;
