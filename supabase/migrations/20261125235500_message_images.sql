-- Club colours and photos on messages (Ken 2026-11-25, "Ok go for it").
--   * app_messages.image_url: one optional photo on an Important message,
--     uploaded by the club Messages page to the public bucket message-images
--     (folder = club id; only officers with the Messages tick for that club,
--     or SuperUsers, may upload there);
--   * app_message_json also returns image_url and the club's colours, so the
--     v3 pop-up can use the club colour for its stripe and Got it button.
-- save_app_message gains p_image_url (DEFAULT NULL = leave the photo as it
-- is, '' = remove it). Additive; v2 never reads messages.

ALTER TABLE public.app_messages ADD COLUMN IF NOT EXISTS image_url text;

INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES ('message-images', 'message-images', true, 3145728, ARRAY['image/jpeg','image/png','image/webp'])
ON CONFLICT (id) DO NOTHING;

DROP POLICY IF EXISTS message_images_insert ON storage.objects;
CREATE POLICY message_images_insert ON storage.objects FOR INSERT TO authenticated
WITH CHECK (
  bucket_id = 'message-images'
  AND (coalesce(public.is_app_super_user(), false)
       OR EXISTS (SELECT 1 FROM public.club_officers o
                   WHERE o.user_id = auth.uid() AND o.is_active AND o.can_messages
                     AND o.club_id::text = (storage.foldername(name))[1])));

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

DROP FUNCTION IF EXISTS public.save_app_message(bigint, text, text, text, text, text, bigint, bigint[], text, timestamptz, timestamptz);
CREATE OR REPLACE FUNCTION public.save_app_message(
  p_id bigint, p_kind text, p_title text, p_body text,
  p_link_url text, p_link_label text,
  p_club_id bigint, p_team_ids bigint[], p_audience text,
  p_starts_at timestamptz, p_ends_at timestamptz, p_image_url text DEFAULT NULL)
 RETURNS bigint LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public' AS $$
DECLARE
  v_id bigint;
  v_club bigint := p_club_id;
  v_old app_messages%ROWTYPE;
  -- Photos only on Important messages, and only from our own storage.
  v_image text := CASE WHEN p_kind = 'important' AND p_image_url LIKE 'https://gyfporsbdftvtakdvukt.supabase.co/storage/v1/object/public/message-images/%'
                       THEN p_image_url END;
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
                              club_id, team_ids, audience, starts_at, ends_at, image_url)
    VALUES (p_kind, trim(p_title), COALESCE(p_body, ''), NULLIF(trim(p_link_url), ''),
            NULLIF(trim(p_link_label), ''), auth.uid(), v_club, COALESCE(p_team_ids, '{}'),
            COALESCE(p_audience, 'all'), COALESCE(p_starts_at, now()), p_ends_at, v_image)
    RETURNING id INTO v_id;
  ELSE
    UPDATE app_messages SET
      kind = p_kind, title = trim(p_title), body = COALESCE(p_body, ''),
      link_url = NULLIF(trim(p_link_url), ''), link_label = NULLIF(trim(p_link_label), ''),
      club_id = v_club, team_ids = COALESCE(p_team_ids, '{}'),
      audience = COALESCE(p_audience, 'all'),
      starts_at = COALESCE(p_starts_at, starts_at), ends_at = p_ends_at,
      image_url = CASE WHEN p_image_url IS NULL THEN image_url ELSE v_image END,
      updated_at = now()
     WHERE id = p_id AND deleted_at IS NULL
    RETURNING id INTO v_id;
  END IF;
  RETURN v_id;
END $$;
REVOKE ALL ON FUNCTION public.save_app_message(bigint, text, text, text, text, text, bigint, bigint[], text, timestamptz, timestamptz, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.save_app_message(bigint, text, text, text, text, text, bigint, bigint[], text, timestamptz, timestamptz, text) TO authenticated;
