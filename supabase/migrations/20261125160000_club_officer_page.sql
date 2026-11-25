-- Club officers page (Ken, 2026-11-25): officer admin moves out of the
-- dashboard into coachsmart.app/club/officers.html?club=ID, with one tick
-- per club tool for each officer:
--   can_dashboard   Club dashboard (results, teams, turnout, player names)  existing
--   can_pitches     Pitch planner                                          existing
--   can_newsletter  Newsletter                                             existing
--   can_sponsors    Club partners                                          NEW (was the dashboard tick)
--   can_officers    Club officers: invite, change ticks, remove            NEW
--   can_spend       Spend & gear for this club (money)                     NEW
--   can_lotto       Club lotto admin (money), kept in step with lotto_admins NEW
-- Who can change ticks: SuperUsers, or an officer with can_officers. An
-- officer can't change their own ticks, and only a SuperUser can turn the
-- money ticks (spend, lotto) on or off (Ken's call pending; safest default).
-- Every change is written to club_officer_log and shown on the page.
-- Existing officers keep what they had (partners follow the dashboard tick).
-- Additive; the v2 and v3 apps don't read any of this.

ALTER TABLE public.club_officers
  ADD COLUMN IF NOT EXISTS can_sponsors boolean NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS can_officers boolean NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS can_spend    boolean NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS can_lotto    boolean NOT NULL DEFAULT false;
ALTER TABLE public.club_officer_invites
  ADD COLUMN IF NOT EXISTS can_newsletter boolean NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS can_sponsors   boolean NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS can_officers   boolean NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS can_spend      boolean NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS can_lotto      boolean NOT NULL DEFAULT false;

-- Keep what people have today.
UPDATE public.club_officers SET can_sponsors = true WHERE can_dashboard AND NOT can_sponsors;
UPDATE public.club_officer_invites SET can_sponsors = true, can_newsletter = true
 WHERE can_dashboard AND accepted_at IS NULL;
UPDATE public.club_officers o SET can_spend = true
 WHERE EXISTS (SELECT 1 FROM public.spend_access s WHERE s.user_id = o.user_id);
UPDATE public.club_officers o SET can_lotto = true
 WHERE EXISTS (SELECT 1 FROM public.lotto_clubs lc JOIN public.lotto_admins la ON la.lotto_id = lc.lotto_id
                WHERE lc.club_id = o.club_id AND la.user_id = o.user_id);

CREATE TABLE IF NOT EXISTS public.club_officer_log (
  log_id     bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  club_id    bigint NOT NULL REFERENCES public.clubs(club_id) ON DELETE CASCADE,
  actor_id   uuid,
  who        text   NOT NULL DEFAULT '',   -- the officer the change was about (name or email)
  what       text   NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS club_officer_log_club ON public.club_officer_log (club_id, created_at DESC);
ALTER TABLE public.club_officer_log ENABLE ROW LEVEL SECURITY;

-- ── Checks ──────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.club_officer_admin(p_club bigint)
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path = 'public' AS $$
  SELECT auth.uid() IS NOT NULL AND (
         coalesce(public.is_app_super_user(), false)
      OR EXISTS (SELECT 1 FROM club_officers o
                  WHERE o.club_id = p_club AND o.user_id = auth.uid() AND o.is_active AND o.can_officers));
$$;
REVOKE ALL ON FUNCTION public.club_officer_admin(bigint) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.club_officer_admin(bigint) TO authenticated, service_role;

-- Club partners now has its own tick.
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
    WHERE o.user_id = p_uid AND o.club_id = p_club AND o.is_active AND o.can_sponsors
  );
$$;
REVOKE ALL ON FUNCTION public.sponsor_can_manage(uuid, bigint) FROM PUBLIC, anon, authenticated;

-- Spend & gear for one club: the global spend_access list (Ken) or the club's money tick.
CREATE OR REPLACE FUNCTION public.spend_can_club(p_uid uuid, p_club bigint)
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path = 'public' AS $$
  SELECT EXISTS (SELECT 1 FROM spend_access WHERE user_id = p_uid)
      OR EXISTS (SELECT 1 FROM club_officers o
                  WHERE o.user_id = p_uid AND o.club_id = p_club AND o.is_active AND o.can_spend);
$$;
REVOKE ALL ON FUNCTION public.spend_can_club(uuid, bigint) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.spend_can_club(uuid, bigint) TO service_role;

-- ── The page's data ────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.club_officer_page(p_club bigint)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = 'public' AS $$
BEGIN
  IF NOT public.club_officer_admin(p_club) THEN
    RETURN jsonb_build_object('error', 'not_allowed');
  END IF;
  RETURN jsonb_build_object(
    'club', (SELECT jsonb_build_object('club_id', c.club_id, 'club_name', c.club_name, 'crest', c.crest,
                     'primary_colour', c.primary_colour, 'secondary_colour', c.secondary_colour)
               FROM clubs c WHERE c.club_id = p_club),
    'me', jsonb_build_object('user_id', auth.uid(), 'is_super_user', coalesce(public.is_app_super_user(), false)),
    'has_lotto', EXISTS (SELECT 1 FROM lotto_clubs WHERE club_id = p_club),
    'officers', coalesce((
      SELECT jsonb_agg(jsonb_build_object(
               'user_id', u.user_id,
               'name', trim(coalesce(u.first_name, '') || ' ' || coalesce(u.last_name, '')),
               'email', u.email_address, 'title', o.title, 'since', o.created_at,
               'can_dashboard', o.can_dashboard, 'can_pitches', o.can_pitches,
               'can_newsletter', o.can_newsletter, 'can_sponsors', o.can_sponsors,
               'can_officers', o.can_officers, 'can_spend', o.can_spend, 'can_lotto', o.can_lotto)
             ORDER BY o.created_at)
        FROM club_officers o JOIN users u ON u.user_id = o.user_id
       WHERE o.club_id = p_club AND o.is_active), '[]'::jsonb),
    'invites', coalesce((
      SELECT jsonb_agg(jsonb_build_object(
               'email', i.email, 'title', i.title,
               'name', trim(coalesce(i.first_name, '') || ' ' || coalesce(i.last_name, '')),
               'first_name', i.first_name, 'last_name', i.last_name, 'sent_at', i.sent_at,
               'can_dashboard', i.can_dashboard, 'can_pitches', i.can_pitches,
               'can_newsletter', i.can_newsletter, 'can_sponsors', i.can_sponsors,
               'can_officers', i.can_officers, 'can_spend', i.can_spend, 'can_lotto', i.can_lotto)
             ORDER BY i.created_at)
        FROM club_officer_invites i
       WHERE i.club_id = p_club AND i.accepted_at IS NULL), '[]'::jsonb),
    'log', coalesce((
      SELECT jsonb_agg(x ORDER BY (x->>'at') DESC) FROM (
        SELECT jsonb_build_object('at', l.created_at, 'who', l.who, 'what', l.what,
                 'by', nullif(trim(coalesce(u.first_name, '') || ' ' || coalesce(u.last_name, '')), '')) x
          FROM club_officer_log l LEFT JOIN users u ON u.user_id = l.actor_id
         WHERE l.club_id = p_club ORDER BY l.created_at DESC LIMIT 30) s), '[]'::jsonb));
END $$;
REVOKE ALL ON FUNCTION public.club_officer_page(bigint) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.club_officer_page(bigint) TO authenticated;

-- Labels used in the change log.
CREATE OR REPLACE FUNCTION public.club_tick_label(p_key text)
RETURNS text LANGUAGE sql IMMUTABLE SET search_path = 'public' AS $$
  SELECT CASE p_key
    WHEN 'can_dashboard' THEN 'Club dashboard' WHEN 'can_pitches' THEN 'Pitch planner'
    WHEN 'can_newsletter' THEN 'Newsletter' WHEN 'can_sponsors' THEN 'Club partners'
    WHEN 'can_officers' THEN 'Club officers' WHEN 'can_spend' THEN 'Spend & gear'
    WHEN 'can_lotto' THEN 'Club lotto' ELSE p_key END;
$$;

-- Save an officer's title and ticks. p_ticks: {can_dashboard: true, ...}
CREATE OR REPLACE FUNCTION public.club_officer_save(p_club bigint, p_user uuid, p_title text, p_ticks jsonb)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = 'public' AS $$
DECLARE
  v_super boolean := coalesce(public.is_app_super_user(), false);
  o       club_officers%ROWTYPE;
  v_new   jsonb := '{}'::jsonb;
  v_on    text[] := '{}';
  v_off   text[] := '{}';
  k       text;
  v_old   boolean;
  v_val   boolean;
  v_who   text;
  v_title text := nullif(trim(coalesce(p_title, '')), '');
  v_lotto bigint;
BEGIN
  IF NOT public.club_officer_admin(p_club) THEN
    RETURN jsonb_build_object('error', 'You can’t manage this club’s officers.');
  END IF;
  IF p_user = auth.uid() AND NOT v_super THEN
    RETURN jsonb_build_object('error', 'Ask another officer or CoachSmart to change your own access.');
  END IF;
  SELECT * INTO o FROM club_officers WHERE club_id = p_club AND user_id = p_user AND is_active;
  IF NOT FOUND THEN RETURN jsonb_build_object('error', 'That officer wasn’t found.'); END IF;

  FOREACH k IN ARRAY ARRAY['can_dashboard','can_pitches','can_newsletter','can_sponsors','can_officers','can_spend','can_lotto'] LOOP
    v_old := (to_jsonb(o)->>k)::boolean;
    v_val := CASE WHEN p_ticks ? k THEN (p_ticks->>k)::boolean ELSE v_old END;
    IF k IN ('can_spend','can_lotto') AND v_val IS DISTINCT FROM v_old AND NOT v_super THEN
      RETURN jsonb_build_object('error', 'Only CoachSmart can change access to money tools for now.');
    END IF;
    v_new := v_new || jsonb_build_object(k, v_val);
    IF v_val AND NOT v_old THEN v_on := v_on || public.club_tick_label(k); END IF;
    IF v_old AND NOT v_val THEN v_off := v_off || public.club_tick_label(k); END IF;
  END LOOP;
  IF NOT EXISTS (SELECT 1 FROM jsonb_each_text(v_new) WHERE value = 'true') THEN
    RETURN jsonb_build_object('error', 'Tick at least one tool, or remove the officer.');
  END IF;

  UPDATE club_officers SET
    can_dashboard = (v_new->>'can_dashboard')::boolean, can_pitches = (v_new->>'can_pitches')::boolean,
    can_newsletter = (v_new->>'can_newsletter')::boolean, can_sponsors = (v_new->>'can_sponsors')::boolean,
    can_officers = (v_new->>'can_officers')::boolean, can_spend = (v_new->>'can_spend')::boolean,
    can_lotto = (v_new->>'can_lotto')::boolean, title = coalesce(left(v_title, 60), title)
   WHERE club_officer_id = o.club_officer_id;

  -- The lotto keeps its own admin list.
  SELECT lotto_id INTO v_lotto FROM lotto_clubs WHERE club_id = p_club;
  IF v_lotto IS NOT NULL AND (v_new->>'can_lotto')::boolean IS DISTINCT FROM o.can_lotto THEN
    IF (v_new->>'can_lotto')::boolean THEN
      INSERT INTO lotto_admins (lotto_id, user_id) VALUES (v_lotto, p_user) ON CONFLICT DO NOTHING;
    ELSE
      DELETE FROM lotto_admins WHERE lotto_id = v_lotto AND user_id = p_user;
    END IF;
  END IF;

  SELECT coalesce(nullif(trim(coalesce(first_name, '') || ' ' || coalesce(last_name, '')), ''), email_address)
    INTO v_who FROM users WHERE user_id = p_user;
  IF cardinality(v_on) > 0 THEN
    INSERT INTO club_officer_log (club_id, actor_id, who, what) VALUES (p_club, auth.uid(), v_who, 'given ' || array_to_string(v_on, ', '));
  END IF;
  IF cardinality(v_off) > 0 THEN
    INSERT INTO club_officer_log (club_id, actor_id, who, what) VALUES (p_club, auth.uid(), v_who, 'lost ' || array_to_string(v_off, ', '));
  END IF;
  IF v_title IS NOT NULL AND v_title IS DISTINCT FROM o.title THEN
    INSERT INTO club_officer_log (club_id, actor_id, who, what) VALUES (p_club, auth.uid(), v_who, 'changed title to ' || left(v_title, 60));
  END IF;
  RETURN jsonb_build_object('ok', true);
END $$;
REVOKE ALL ON FUNCTION public.club_officer_save(bigint, uuid, text, jsonb) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.club_officer_save(bigint, uuid, text, jsonb) TO authenticated;

-- Remove an officer (officer admins can't remove themselves or anyone with money access).
CREATE OR REPLACE FUNCTION public.club_officer_remove(p_club_id bigint, p_user_id uuid)
 RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public' AS $$
DECLARE
  v_super boolean := coalesce(public.is_app_super_user(), false);
  o club_officers%ROWTYPE;
  v_who text;
BEGIN
  IF NOT public.club_officer_admin(p_club_id) THEN
    RETURN jsonb_build_object('error', 'You can’t manage this club’s officers.');
  END IF;
  SELECT * INTO o FROM club_officers WHERE club_id = p_club_id AND user_id = p_user_id AND is_active;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok', true); END IF;
  IF NOT v_super AND (p_user_id = auth.uid() OR o.can_spend OR o.can_lotto) THEN
    RETURN jsonb_build_object('error', 'Only CoachSmart can remove this officer.');
  END IF;
  UPDATE club_officers SET is_active = false WHERE club_officer_id = o.club_officer_id;
  IF o.can_lotto THEN
    DELETE FROM lotto_admins la USING lotto_clubs lc
     WHERE la.lotto_id = lc.lotto_id AND lc.club_id = p_club_id AND la.user_id = p_user_id;
  END IF;
  SELECT coalesce(nullif(trim(coalesce(first_name, '') || ' ' || coalesce(last_name, '')), ''), email_address)
    INTO v_who FROM users WHERE user_id = p_user_id;
  INSERT INTO club_officer_log (club_id, actor_id, who, what) VALUES (p_club_id, auth.uid(), v_who, 'removed as ' || coalesce(o.title, 'officer'));
  RETURN jsonb_build_object('ok', true);
END $$;

CREATE OR REPLACE FUNCTION public.club_officer_invite_cancel(p_club_id bigint, p_email text)
 RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public' AS $$
BEGIN
  IF NOT public.club_officer_admin(p_club_id) THEN
    RETURN jsonb_build_object('error', 'You can’t manage this club’s officers.');
  END IF;
  DELETE FROM club_officer_invites
   WHERE club_id = p_club_id AND lower(email) = lower(trim(p_email)) AND accepted_at IS NULL;
  IF FOUND THEN
    INSERT INTO club_officer_log (club_id, actor_id, who, what) VALUES (p_club_id, auth.uid(), lower(trim(p_email)), 'invite cancelled');
  END IF;
  RETURN jsonb_build_object('ok', true);
END $$;

-- The old dashboard sheet's calls stay SuperUser only (now unused).
-- club_officer_list / club_officer_set_access are left as they were.

-- Pending invites carry all their ticks onto the officer row.
CREATE OR REPLACE FUNCTION public.club_officer_claim_invites()
 RETURNS integer LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public' AS $$
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
        PERFORM public.club_officer_apply_invite(r.invite_id, v_uid);
        UPDATE users
           SET first_name = COALESCE(NULLIF(first_name, ''), r.first_name),
               last_name  = COALESCE(NULLIF(last_name, ''),  r.last_name)
         WHERE user_id = v_uid;
        v_n := v_n + 1;
    END LOOP;
    RETURN v_n;
END $$;

-- Turn an invite into an officer row (used above and by the club-invite function).
CREATE OR REPLACE FUNCTION public.club_officer_apply_invite(p_invite bigint, p_user uuid)
 RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public' AS $$
DECLARE r club_officer_invites%ROWTYPE; v_lotto bigint;
BEGIN
  SELECT * INTO r FROM club_officer_invites WHERE invite_id = p_invite;
  IF NOT FOUND THEN RETURN; END IF;
  INSERT INTO club_officers (club_id, user_id, title, created_by, is_active, can_pitches, can_dashboard,
                             can_newsletter, can_sponsors, can_officers, can_spend, can_lotto)
  VALUES (r.club_id, p_user, r.title, r.created_by, true, r.can_pitches, r.can_dashboard,
          r.can_newsletter, r.can_sponsors, r.can_officers, r.can_spend, r.can_lotto)
  ON CONFLICT (club_id, user_id) DO UPDATE
     SET is_active = true, title = EXCLUDED.title,
         can_pitches = EXCLUDED.can_pitches, can_dashboard = EXCLUDED.can_dashboard,
         can_newsletter = EXCLUDED.can_newsletter, can_sponsors = EXCLUDED.can_sponsors,
         can_officers = EXCLUDED.can_officers, can_spend = EXCLUDED.can_spend, can_lotto = EXCLUDED.can_lotto;
  IF r.can_lotto THEN
    SELECT lotto_id INTO v_lotto FROM lotto_clubs WHERE club_id = r.club_id;
    IF v_lotto IS NOT NULL THEN
      INSERT INTO lotto_admins (lotto_id, user_id) VALUES (v_lotto, p_user) ON CONFLICT DO NOTHING;
    END IF;
  END IF;
  UPDATE club_officer_invites SET accepted_at = now(), token = NULL WHERE invite_id = p_invite;
  INSERT INTO club_officer_log (club_id, actor_id, who, what)
  VALUES (r.club_id, p_user, coalesce(nullif(trim(coalesce(r.first_name, '') || ' ' || coalesce(r.last_name, '')), ''), r.email), 'accepted the invite');
END $$;
REVOKE ALL ON FUNCTION public.club_officer_apply_invite(bigint, uuid) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.club_officer_apply_invite(bigint, uuid) TO service_role;

-- Club home: officers tile for officer admins, spend tile per club.
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

  PERFORM public.club_officer_claim_invites();

  v_super := coalesce(public.is_app_super_user(), false);
  v_mon   := v_today - (extract(isodow FROM v_today)::int - 1);
  v_from  := (v_mon::timestamp) AT TIME ZONE 'Europe/Dublin';
  v_to    := ((v_mon + 7)::timestamp) AT TIME ZONE 'Europe/Dublin';

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

  IF public.is_club_pitch_admin(p_club) THEN
    SELECT seen_at INTO v_seen FROM pitch_alert_reads WHERE club_id = p_club AND user_id = v_uid;
    SELECT count(*) INTO v_n FROM pitch_alerts a
     WHERE a.club_id = p_club
       AND a.created_at > greatest(coalesce(v_seen, '-infinity'::timestamptz), now() - interval '14 days');
    v_tiles := v_tiles || jsonb_build_object('pitches', jsonb_build_object('unread', v_n));
  END IF;

  IF public.newsletter_can_manage(v_uid, p_club) THEN
    SELECT i.issue_no, i.status, i.title INTO v_issue
      FROM newsletter_issues i WHERE i.club_id = p_club
     ORDER BY i.week_start DESC LIMIT 1;
    v_tiles := v_tiles || jsonb_build_object('newsletter', jsonb_build_object(
      'title', coalesce(v_issue.title, (SELECT s.title FROM newsletter_settings s WHERE s.club_id = p_club)),
      'issue_no', v_issue.issue_no, 'status', v_issue.status));
  END IF;

  IF public.sponsor_can_manage(v_uid, p_club) THEN
    v_tiles := v_tiles || jsonb_build_object('sponsors', jsonb_build_object(
      'live', (SELECT s.name FROM club_sponsors s WHERE s.club_id = p_club AND s.status = 'live'
                ORDER BY s.sponsor_id DESC LIMIT 1),
      'drafts', (SELECT count(*) FROM club_sponsors s WHERE s.club_id = p_club AND s.status = 'draft')));
  END IF;

  IF public.club_officer_admin(p_club) THEN
    v_tiles := v_tiles || jsonb_build_object('officers', jsonb_build_object(
      'officers', (SELECT count(*) FROM club_officers o WHERE o.club_id = p_club AND o.is_active),
      'invites',  (SELECT count(*) FROM club_officer_invites i WHERE i.club_id = p_club AND i.accepted_at IS NULL)));
  END IF;

  IF public.spend_can_club(v_uid, p_club) THEN
    SELECT count(*) INTO v_n FROM team_expenses x JOIN teams t ON t.team_id = x.team_id
     WHERE t.club_id = p_club AND x.status = 'submitted';
    SELECT count(*) INTO v_n2 FROM gear_requests g JOIN teams t ON t.team_id = g.team_id
     WHERE t.club_id = p_club AND g.status = 'requested';
    v_tiles := v_tiles || jsonb_build_object('spend', jsonb_build_object('claims', v_n, 'gear', v_n2));
  END IF;

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
