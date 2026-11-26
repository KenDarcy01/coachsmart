-- Photos on News too (Ken 2026-11-26: "Is there an option to upload an image
-- as part of a news item?"). The v3 Club news card already shows image_url
-- on its left panel; save_app_message dropped it for news. Same function,
-- only the photo rule changes. Additive; v2 never reads messages.

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
  -- Photos on every kind (news too, 2026-11-26), only from our own storage.
  v_image text := CASE WHEN p_image_url LIKE 'https://gyfporsbdftvtakdvukt.supabase.co/storage/v1/object/public/message-images/%'
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
