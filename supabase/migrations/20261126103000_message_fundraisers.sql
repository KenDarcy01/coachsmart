-- Fundraisers (Ken 2026-11-26, thread "Make the news banner more prominent"):
-- a third message kind next to Important and News. A fundraiser (Christmas
-- Draw, raffle, gear order) shows on v3 Home in its own slim row under Club
-- news, with an optional price line and a button (link_label, e.g. "Buy
-- tickets") that opens link_url, the club's own page. Nothing is paid
-- through CoachSmart.
--   * app_messages.kind allows 'fundraiser'; app_messages.price_label;
--   * app_message_reads.tapped_at: who tapped the button (counted on the
--     club Messages page as "N tapped Buy tickets");
--   * get_my_app_messages returns 'fundraisers' (old v3 builds ignore it and
--     never see fundraisers in the news);
--   * save_app_message gains p_price_label (DEFAULT NULL); a fundraiser
--     needs a link; photos now allowed on fundraisers too;
--   * app_message_tap(p_id) records a tap.
-- Additive; v2 never reads messages.

ALTER TABLE public.app_messages DROP CONSTRAINT IF EXISTS app_messages_kind_check;
ALTER TABLE public.app_messages ADD CONSTRAINT app_messages_kind_check
  CHECK (kind IN ('important', 'news', 'fundraiser'));
ALTER TABLE public.app_messages ADD COLUMN IF NOT EXISTS price_label text;
ALTER TABLE public.app_message_reads ADD COLUMN IF NOT EXISTS tapped_at timestamptz;

CREATE OR REPLACE FUNCTION public.app_message_json(m public.app_messages)
 RETURNS jsonb
 LANGUAGE sql STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $$
  WITH c AS (
    SELECT c.primary_colour, c.secondary_colour FROM clubs c
     WHERE c.club_id = coalesce(m.club_id, (SELECT t.club_id FROM teams t WHERE t.team_id = m.team_ids[1]))
  )
  SELECT jsonb_build_object(
    'id', m.id, 'kind', m.kind, 'title', m.title, 'body', m.body,
    'link_url', m.link_url, 'link_label', m.link_label, 'image_url', m.image_url,
    'price_label', m.price_label,
    'starts_at', m.starts_at, 'ends_at', m.ends_at,
    'scope', CASE WHEN cardinality(m.team_ids) > 0 THEN 'team'
                  WHEN m.club_id IS NOT NULL THEN 'club' ELSE 'all' END,
    'audience', m.audience, 'club_id', m.club_id, 'team_ids', to_jsonb(m.team_ids),
    'from_name', CASE
       WHEN cardinality(m.team_ids) = 1 THEN
         (SELECT c.club_name || ' · ' || t.team_name FROM teams t JOIN clubs c ON c.club_id = t.club_id
           WHERE t.team_id = m.team_ids[1])
       WHEN cardinality(m.team_ids) > 1 THEN
         COALESCE((SELECT c.club_name FROM clubs c WHERE c.club_id = m.club_id), 'Your teams')
       WHEN m.club_id IS NOT NULL THEN (SELECT c.club_name FROM clubs c WHERE c.club_id = m.club_id)
       ELSE 'CoachSmart' END,
    'crest', CASE
       WHEN cardinality(m.team_ids) > 0 THEN
         (SELECT c.crest FROM teams t JOIN clubs c ON c.club_id = t.club_id WHERE t.team_id = m.team_ids[1])
       WHEN m.club_id IS NOT NULL THEN (SELECT c.crest FROM clubs c WHERE c.club_id = m.club_id)
       ELSE NULL END,
    'primary_colour', (SELECT primary_colour FROM c),
    'secondary_colour', (SELECT secondary_colour FROM c));
$$;
REVOKE ALL ON FUNCTION public.app_message_json(public.app_messages) FROM PUBLIC, anon, authenticated;

CREATE OR REPLACE FUNCTION public.get_my_app_messages()
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_uid uuid := auth.uid();
  v_out jsonb;
BEGIN
  IF v_uid IS NULL THEN
    RETURN jsonb_build_object('important', '[]'::jsonb, 'news', '[]'::jsonb,
                              'fundraisers', '[]'::jsonb, 'is_super_user', false);
  END IF;

  WITH live AS (
    SELECT m AS msg, r.seen_at, r.dismissed_at
      FROM app_messages m
      LEFT JOIN app_message_reads r ON r.message_id = m.id AND r.user_id = v_uid
     WHERE m.deleted_at IS NULL AND m.ended_at IS NULL
       AND m.starts_at <= now() AND m.ends_at > now()
       AND EXISTS (SELECT 1 FROM app_message_audience(m.club_id, m.team_ids, m.audience, v_uid))
  )
  SELECT jsonb_build_object(
    'is_super_user', is_app_super_user(),
    -- CoachSmart first, then club, then team; newest first within each.
    'important', COALESCE((
       SELECT jsonb_agg(app_message_json(l.msg)
              ORDER BY CASE WHEN cardinality((l.msg).team_ids) > 0 THEN 2
                            WHEN (l.msg).club_id IS NOT NULL THEN 1 ELSE 0 END,
                       (l.msg).starts_at DESC)
         FROM live l WHERE (l.msg).kind = 'important' AND l.dismissed_at IS NULL), '[]'::jsonb),
    'news', COALESCE((
       SELECT jsonb_agg(app_message_json(l.msg)
                        || jsonb_build_object('seen', l.seen_at IS NOT NULL)
              ORDER BY (l.msg).starts_at DESC)
         FROM live l WHERE (l.msg).kind = 'news'), '[]'::jsonb),
    -- Ending soonest first: the draw closing this week leads.
    'fundraisers', COALESCE((
       SELECT jsonb_agg(app_message_json(l.msg)
                        || jsonb_build_object('seen', l.seen_at IS NOT NULL)
              ORDER BY (l.msg).ends_at, (l.msg).starts_at DESC)
         FROM live l WHERE (l.msg).kind = 'fundraiser'), '[]'::jsonb))
    INTO v_out;
  RETURN v_out;
END;
$function$;

-- A tap on a fundraiser's button (one per person, the latest time kept).
CREATE OR REPLACE FUNCTION public.app_message_tap(p_id bigint)
 RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public' AS $$
BEGIN
  IF auth.uid() IS NULL THEN RETURN; END IF;
  IF NOT EXISTS (SELECT 1 FROM app_messages WHERE id = p_id AND deleted_at IS NULL) THEN RETURN; END IF;
  INSERT INTO app_message_reads (message_id, user_id, seen_at, tapped_at)
  VALUES (p_id, auth.uid(), now(), now())
  ON CONFLICT (message_id, user_id) DO UPDATE
     SET tapped_at = now(), seen_at = COALESCE(app_message_reads.seen_at, now());
END $$;
REVOKE ALL ON FUNCTION public.app_message_tap(bigint) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.app_message_tap(bigint) TO authenticated;

CREATE OR REPLACE FUNCTION public.get_sent_app_messages()
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
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
             'tap_count', (SELECT count(*) FROM app_message_reads r
                            WHERE r.message_id = m.id AND r.tapped_at IS NOT NULL),
             'team_names', COALESCE((SELECT jsonb_agg(t.team_name ORDER BY t.team_name)
                                       FROM teams t WHERE t.team_id = ANY (m.team_ids)), '[]'::jsonb))
           ORDER BY m.starts_at DESC)
      FROM app_messages m
     WHERE m.deleted_at IS NULL
       AND (v_super OR EXISTS (SELECT 1 FROM club_officers o WHERE o.club_id = m.club_id
                                 AND o.user_id = auth.uid() AND o.is_active AND o.can_messages))), '[]'::jsonb);
END $function$;

DROP FUNCTION IF EXISTS public.save_app_message(bigint, text, text, text, text, text, bigint, bigint[], text, timestamptz, timestamptz, text);
CREATE OR REPLACE FUNCTION public.save_app_message(
  p_id bigint, p_kind text, p_title text, p_body text,
  p_link_url text, p_link_label text,
  p_club_id bigint, p_team_ids bigint[], p_audience text,
  p_starts_at timestamptz, p_ends_at timestamptz, p_image_url text DEFAULT NULL,
  p_price_label text DEFAULT NULL)
 RETURNS bigint LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public' AS $$
DECLARE
  v_id bigint;
  v_club bigint := p_club_id;
  v_old app_messages%ROWTYPE;
  -- Photos on Important messages and fundraisers, only from our own storage.
  v_image text := CASE WHEN p_kind IN ('important', 'fundraiser') AND p_image_url LIKE 'https://gyfporsbdftvtakdvukt.supabase.co/storage/v1/object/public/message-images/%'
                       THEN p_image_url END;
  v_price text := CASE WHEN p_kind = 'fundraiser' THEN NULLIF(trim(p_price_label), '') END;
BEGIN
  IF NOT public.app_message_can(p_club_id, p_team_ids) THEN RAISE EXCEPTION 'Not allowed'; END IF;
  IF p_id IS NOT NULL THEN
    SELECT * INTO v_old FROM app_messages WHERE id = p_id AND deleted_at IS NULL;
    IF NOT FOUND OR NOT public.app_message_can(v_old.club_id, v_old.team_ids) THEN RAISE EXCEPTION 'Not allowed'; END IF;
  END IF;
  IF COALESCE(trim(p_title), '') = '' THEN RAISE EXCEPTION 'A title is needed'; END IF;
  IF p_kind = 'fundraiser' AND COALESCE(trim(p_link_url), '') = '' THEN
    RAISE EXCEPTION 'A fundraiser needs a link for its button';
  END IF;
  IF p_ends_at IS NULL OR p_ends_at <= COALESCE(p_starts_at, now()) THEN
    RAISE EXCEPTION 'Stop showing must be after show from';
  END IF;
  IF COALESCE(cardinality(p_team_ids), 0) > 0 AND v_club IS NULL THEN
    SELECT t.club_id INTO v_club FROM teams t WHERE t.team_id = p_team_ids[1];
  END IF;
  IF p_id IS NULL THEN
    INSERT INTO app_messages (kind, title, body, link_url, link_label, sender_user_id,
                              club_id, team_ids, audience, starts_at, ends_at, image_url, price_label)
    VALUES (p_kind, trim(p_title), COALESCE(p_body, ''), NULLIF(trim(p_link_url), ''),
            NULLIF(trim(p_link_label), ''), auth.uid(), v_club, COALESCE(p_team_ids, '{}'),
            COALESCE(p_audience, 'all'), COALESCE(p_starts_at, now()), p_ends_at, v_image, v_price)
    RETURNING id INTO v_id;
  ELSE
    UPDATE app_messages SET
      kind = p_kind, title = trim(p_title), body = COALESCE(p_body, ''),
      link_url = NULLIF(trim(p_link_url), ''), link_label = NULLIF(trim(p_link_label), ''),
      club_id = v_club, team_ids = COALESCE(p_team_ids, '{}'),
      audience = COALESCE(p_audience, 'all'),
      starts_at = COALESCE(p_starts_at, starts_at), ends_at = p_ends_at,
      image_url = CASE WHEN p_image_url IS NULL THEN image_url ELSE v_image END,
      price_label = CASE WHEN p_price_label IS NULL AND p_kind = 'fundraiser' THEN price_label ELSE v_price END,
      updated_at = now()
     WHERE id = p_id AND deleted_at IS NULL
    RETURNING id INTO v_id;
  END IF;
  RETURN v_id;
END $$;
REVOKE ALL ON FUNCTION public.save_app_message(bigint, text, text, text, text, text, bigint, bigint[], text, timestamptz, timestamptz, text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.save_app_message(bigint, text, text, text, text, text, bigint, bigint[], text, timestamptz, timestamptz, text, text) TO authenticated;
