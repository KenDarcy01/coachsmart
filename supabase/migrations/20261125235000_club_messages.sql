-- Club messages (Ken, 2026-11-25): Messages becomes a club officer tool.
--   * new tick can_messages on the club officers page;
--   * the v3 menu shows Messages and Pitches only to club officers with that
--     tick (get_my_club_tools; being a SuperUser alone no longer shows them,
--     Ken: "Shouldn't be visible on the menu at all for anyone else");
--   * officers send messages to their own club only (all of it or some
--     teams); only SuperUsers may still send to everyone on CoachSmart;
--   * Ken keeps his access: his main account (the spend_access holder) is
--     made a Clontarf officer with every tick.
-- Messages still show only in the v3 app. Additive; v2 untouched.

ALTER TABLE public.club_officers        ADD COLUMN IF NOT EXISTS can_messages boolean NOT NULL DEFAULT false;
ALTER TABLE public.club_officer_invites ADD COLUMN IF NOT EXISTS can_messages boolean NOT NULL DEFAULT false;

INSERT INTO public.club_officers (club_id, user_id, title, created_by, is_active, can_pitches, can_dashboard,
                                  can_newsletter, can_sponsors, can_officers, can_spend, can_lotto, can_messages)
SELECT 1, s.user_id, 'CoachSmart', s.user_id, true, true, true, true, true, true, true, true, true
  FROM public.spend_access s
 WHERE EXISTS (SELECT 1 FROM public.clubs WHERE club_id = 1)
ON CONFLICT (club_id, user_id) DO UPDATE
   SET is_active = true, can_pitches = true, can_dashboard = true, can_newsletter = true, can_sponsors = true,
       can_officers = true, can_spend = true, can_messages = true;
UPDATE public.club_officers o SET can_lotto = true
 WHERE o.user_id IN (SELECT user_id FROM public.spend_access)
   AND EXISTS (SELECT 1 FROM public.lotto_clubs lc JOIN public.lotto_admins la ON la.lotto_id = lc.lotto_id
                WHERE lc.club_id = o.club_id AND la.user_id = o.user_id);

-- ── Officer ticks for the v3 menu ───────────────────────────────────
CREATE OR REPLACE FUNCTION public.get_my_club_tools()
RETURNS jsonb LANGUAGE sql STABLE SECURITY DEFINER SET search_path = 'public' AS $$
  SELECT jsonb_build_object(
    'pitch_clubs', coalesce((SELECT jsonb_agg(o.club_id ORDER BY o.club_id) FROM club_officers o
                              WHERE o.user_id = auth.uid() AND o.is_active AND o.can_pitches), '[]'::jsonb),
    'message_clubs', coalesce((SELECT jsonb_agg(o.club_id ORDER BY o.club_id) FROM club_officers o
                              WHERE o.user_id = auth.uid() AND o.is_active AND o.can_messages), '[]'::jsonb),
    'send_everyone', coalesce(public.is_app_super_user(), false));
$$;
REVOKE ALL ON FUNCTION public.get_my_club_tools() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_my_club_tools() TO authenticated;

-- May the caller send to this club / these teams? SuperUsers: anything.
-- Officers with the Messages tick: their club, whole or some of its teams.
CREATE OR REPLACE FUNCTION public.app_message_can(p_club bigint, p_team_ids bigint[])
RETURNS boolean LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = 'public' AS $$
DECLARE v_club bigint := p_club;
BEGIN
  IF auth.uid() IS NULL THEN RETURN false; END IF;
  IF coalesce(public.is_app_super_user(), false) THEN RETURN true; END IF;
  IF v_club IS NULL AND coalesce(cardinality(p_team_ids), 0) > 0 THEN
    SELECT t.club_id INTO v_club FROM teams t WHERE t.team_id = p_team_ids[1];
  END IF;
  IF v_club IS NULL THEN RETURN false; END IF;
  IF EXISTS (SELECT 1 FROM unnest(coalesce(p_team_ids, '{}')) x(id)
              WHERE NOT EXISTS (SELECT 1 FROM teams t WHERE t.team_id = x.id AND t.club_id = v_club)) THEN
    RETURN false;
  END IF;
  RETURN EXISTS (SELECT 1 FROM club_officers o
                  WHERE o.club_id = v_club AND o.user_id = auth.uid() AND o.is_active AND o.can_messages);
END $$;
REVOKE ALL ON FUNCTION public.app_message_can(bigint, bigint[]) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.app_message_can(bigint, bigint[]) TO authenticated;

-- ── Sending, now for officers too ──────────────────────────────────
CREATE OR REPLACE FUNCTION public.get_app_message_targets()
 RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path TO 'public' AS $$
DECLARE v_super boolean := coalesce(is_app_super_user(), false);
BEGIN
  IF NOT v_super AND NOT EXISTS (SELECT 1 FROM club_officers o WHERE o.user_id = auth.uid() AND o.is_active AND o.can_messages) THEN
    RAISE EXCEPTION 'Not allowed';
  END IF;
  RETURN COALESCE((
    SELECT jsonb_agg(jsonb_build_object(
             'club_id', c.club_id, 'club_name', c.club_name, 'crest', c.crest,
             'teams', COALESCE((SELECT jsonb_agg(jsonb_build_object('team_id', t.team_id, 'team_name', t.team_name)
                                   ORDER BY t.team_name)
                                  FROM teams t WHERE t.club_id = c.club_id), '[]'::jsonb))
           ORDER BY c.club_name)
      FROM clubs c
     WHERE EXISTS (SELECT 1 FROM teams t WHERE t.club_id = c.club_id)
       AND (v_super OR EXISTS (SELECT 1 FROM club_officers o WHERE o.club_id = c.club_id
                                 AND o.user_id = auth.uid() AND o.is_active AND o.can_messages))), '[]'::jsonb);
END $$;

CREATE OR REPLACE FUNCTION public.count_app_message_audience(
  p_club_id bigint, p_team_ids bigint[], p_audience text)
 RETURNS integer LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path TO 'public' AS $$
BEGIN
  IF NOT public.app_message_can(p_club_id, p_team_ids) THEN RAISE EXCEPTION 'Not allowed'; END IF;
  RETURN (SELECT count(*) FROM app_message_audience(p_club_id, p_team_ids, p_audience));
END $$;

CREATE OR REPLACE FUNCTION public.save_app_message(
  p_id bigint, p_kind text, p_title text, p_body text,
  p_link_url text, p_link_label text,
  p_club_id bigint, p_team_ids bigint[], p_audience text,
  p_starts_at timestamptz, p_ends_at timestamptz)
 RETURNS bigint LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public' AS $$
DECLARE
  v_id bigint;
  v_club bigint := p_club_id;
  v_old app_messages%ROWTYPE;
BEGIN
  IF NOT public.app_message_can(p_club_id, p_team_ids) THEN RAISE EXCEPTION 'Not allowed'; END IF;
  IF p_id IS NOT NULL THEN
    SELECT * INTO v_old FROM app_messages WHERE id = p_id AND deleted_at IS NULL;
    IF NOT FOUND OR NOT public.app_message_can(v_old.club_id, v_old.team_ids) THEN RAISE EXCEPTION 'Not allowed'; END IF;
  END IF;
  IF COALESCE(trim(p_title), '') = '' THEN RAISE EXCEPTION 'A title is needed'; END IF;
  IF p_ends_at IS NULL OR p_ends_at <= COALESCE(p_starts_at, now()) THEN
    RAISE EXCEPTION 'Stop showing must be after show from';
  END IF;
  IF COALESCE(cardinality(p_team_ids), 0) > 0 AND v_club IS NULL THEN
    SELECT t.club_id INTO v_club FROM teams t WHERE t.team_id = p_team_ids[1];
  END IF;
  IF p_id IS NULL THEN
    INSERT INTO app_messages (kind, title, body, link_url, link_label, sender_user_id,
                              club_id, team_ids, audience, starts_at, ends_at)
    VALUES (p_kind, trim(p_title), COALESCE(p_body, ''), NULLIF(trim(p_link_url), ''),
            NULLIF(trim(p_link_label), ''), auth.uid(), v_club, COALESCE(p_team_ids, '{}'),
            COALESCE(p_audience, 'all'), COALESCE(p_starts_at, now()), p_ends_at)
    RETURNING id INTO v_id;
  ELSE
    UPDATE app_messages SET
      kind = p_kind, title = trim(p_title), body = COALESCE(p_body, ''),
      link_url = NULLIF(trim(p_link_url), ''), link_label = NULLIF(trim(p_link_label), ''),
      club_id = v_club, team_ids = COALESCE(p_team_ids, '{}'),
      audience = COALESCE(p_audience, 'all'),
      starts_at = COALESCE(p_starts_at, starts_at), ends_at = p_ends_at,
      updated_at = now()
     WHERE id = p_id AND deleted_at IS NULL
    RETURNING id INTO v_id;
  END IF;
  RETURN v_id;
END $$;

CREATE OR REPLACE FUNCTION public.end_app_message(p_id bigint, p_delete boolean DEFAULT false)
 RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public' AS $$
DECLARE v_old app_messages%ROWTYPE;
BEGIN
  SELECT * INTO v_old FROM app_messages WHERE id = p_id;
  IF NOT FOUND OR NOT public.app_message_can(v_old.club_id, v_old.team_ids) THEN RAISE EXCEPTION 'Not allowed'; END IF;
  UPDATE app_messages
     SET ended_at   = COALESCE(ended_at, now()),
         deleted_at = CASE WHEN p_delete THEN now() ELSE deleted_at END,
         updated_at = now()
   WHERE id = p_id;
END $$;

-- Sent list: SuperUsers see all; officers see their own clubs' messages.
CREATE OR REPLACE FUNCTION public.get_sent_app_messages()
 RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path TO 'public' AS $$
DECLARE v_super boolean := coalesce(is_app_super_user(), false);
BEGIN
  IF NOT v_super AND NOT EXISTS (SELECT 1 FROM club_officers o WHERE o.user_id = auth.uid() AND o.is_active AND o.can_messages) THEN
    RAISE EXCEPTION 'Not allowed';
  END IF;
  RETURN COALESCE((
    SELECT jsonb_agg(app_message_json(m) || jsonb_build_object(
             'ended_at', m.ended_at,
             'reach', (SELECT count(*) FROM app_message_audience(m.club_id, m.team_ids, m.audience)),
             'seen_count', (SELECT count(*) FROM app_message_reads r WHERE r.message_id = m.id),
             'dismissed_count', (SELECT count(*) FROM app_message_reads r
                            WHERE r.message_id = m.id AND r.dismissed_at IS NOT NULL),
             'team_names', COALESCE((SELECT jsonb_agg(t.team_name ORDER BY t.team_name)
                                       FROM teams t WHERE t.team_id = ANY (m.team_ids)), '[]'::jsonb))
           ORDER BY m.starts_at DESC)
      FROM app_messages m
     WHERE m.deleted_at IS NULL
       AND (v_super OR EXISTS (SELECT 1 FROM club_officers o WHERE o.club_id = m.club_id
                                 AND o.user_id = auth.uid() AND o.is_active AND o.can_messages))), '[]'::jsonb);
END $$;

-- ── Club officer functions with the Messages tick ──────────────────
CREATE OR REPLACE FUNCTION public.club_tick_label(p_key text)
RETURNS text LANGUAGE sql IMMUTABLE SET search_path = 'public' AS $$
  SELECT CASE p_key
    WHEN 'can_dashboard' THEN 'Club dashboard' WHEN 'can_pitches' THEN 'Pitch planner'
    WHEN 'can_newsletter' THEN 'Newsletter' WHEN 'can_sponsors' THEN 'Club partners'
    WHEN 'can_officers' THEN 'Club officers' WHEN 'can_spend' THEN 'Spend & gear'
    WHEN 'can_lotto' THEN 'Club lotto' WHEN 'can_messages' THEN 'Messages' ELSE p_key END;
$$;

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
               'can_officers', o.can_officers, 'can_spend', o.can_spend, 'can_lotto', o.can_lotto,
               'can_messages', o.can_messages)
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
               'can_officers', i.can_officers, 'can_spend', i.can_spend, 'can_lotto', i.can_lotto,
               'can_messages', i.can_messages)
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

  FOREACH k IN ARRAY ARRAY['can_dashboard','can_pitches','can_newsletter','can_sponsors','can_officers','can_spend','can_lotto','can_messages'] LOOP
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
    can_lotto = (v_new->>'can_lotto')::boolean, can_messages = (v_new->>'can_messages')::boolean, title = coalesce(left(v_title, 60), title)
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

CREATE OR REPLACE FUNCTION public.club_officer_apply_invite(p_invite bigint, p_user uuid)
 RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public' AS $$
DECLARE r club_officer_invites%ROWTYPE; v_lotto bigint;
BEGIN
  SELECT * INTO r FROM club_officer_invites WHERE invite_id = p_invite;
  IF NOT FOUND THEN RETURN; END IF;
  INSERT INTO club_officers (club_id, user_id, title, created_by, is_active, can_pitches, can_dashboard,
                             can_newsletter, can_sponsors, can_officers, can_spend, can_lotto, can_messages)
  VALUES (r.club_id, p_user, r.title, r.created_by, true, r.can_pitches, r.can_dashboard,
          r.can_newsletter, r.can_sponsors, r.can_officers, r.can_spend, r.can_lotto, r.can_messages)
  ON CONFLICT (club_id, user_id) DO UPDATE
     SET is_active = true, title = EXCLUDED.title,
         can_pitches = EXCLUDED.can_pitches, can_dashboard = EXCLUDED.can_dashboard,
         can_newsletter = EXCLUDED.can_newsletter, can_sponsors = EXCLUDED.can_sponsors,
         can_officers = EXCLUDED.can_officers, can_spend = EXCLUDED.can_spend, can_lotto = EXCLUDED.can_lotto,
         can_messages = EXCLUDED.can_messages;
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

  -- Messages: officers with the Messages tick only (Ken 2026-11-25).
  IF EXISTS (SELECT 1 FROM club_officers o WHERE o.club_id = p_club AND o.user_id = v_uid AND o.is_active AND o.can_messages) THEN
    v_tiles := v_tiles || jsonb_build_object('messages', jsonb_build_object(
      'live', (SELECT count(*) FROM app_messages m WHERE m.club_id = p_club AND m.deleted_at IS NULL AND m.ended_at IS NULL
                AND m.starts_at <= now() AND m.ends_at > now()),
      'sent', (SELECT count(*) FROM app_messages m WHERE m.club_id = p_club AND m.deleted_at IS NULL
                AND m.created_at > now() - interval '30 days')));
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
