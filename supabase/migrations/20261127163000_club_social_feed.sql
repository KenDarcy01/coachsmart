-- Club news from the club's own social posts (Ken 2026-11-27, thread
-- "Feed Clontarf socials into Club news"). We mirror whatever the club's
-- website shows in its social feed (Clontarf: the Squarespace Instagram
-- block on clontarfgaa.com), so no Instagram login and no link to Instagram.
-- The club-social-feed edge function reads clubs.social_feed_url every 30
-- minutes, copies each post's photo into the public club-social bucket and
-- upserts club_social_posts. v3 reads get_club_social_posts; v2 never does.
-- Admin-written news (app_messages) is untouched; v3 now calls it
-- "Club notices".

ALTER TABLE public.clubs
  ADD COLUMN IF NOT EXISTS social_feed_url text,
  -- Posts whose caption contains one of these words are left out
  -- (Ken: lotto posts are left out, as in the newsletter).
  ADD COLUMN IF NOT EXISTS social_hide_words text[] NOT NULL DEFAULT ARRAY['lotto'];

CREATE TABLE IF NOT EXISTS public.club_social_posts (
  id          bigserial PRIMARY KEY,
  club_id     bigint NOT NULL REFERENCES public.clubs(club_id),
  source      text NOT NULL DEFAULT 'instagram',
  ext_key     text NOT NULL,           -- stable id from the feed (image asset id)
  source_url  text,                    -- the image on the club's website
  image_url   text,                    -- our copy (club-social bucket)
  caption     text NOT NULL DEFAULT '',
  posted_at   timestamptz,
  hidden      boolean NOT NULL DEFAULT false,
  first_seen  timestamptz NOT NULL DEFAULT now(),
  last_seen   timestamptz NOT NULL DEFAULT now(),
  UNIQUE (club_id, ext_key)
);
CREATE INDEX IF NOT EXISTS club_social_posts_club_idx
  ON public.club_social_posts (club_id, posted_at DESC);
ALTER TABLE public.club_social_posts ENABLE ROW LEVEL SECURITY;  -- no policies

INSERT INTO storage.buckets (id, name, public)
VALUES ('club-social', 'club-social', true)
ON CONFLICT (id) DO NOTHING;

-- Clontarf GAA (club 1): the website's Instagram block.
UPDATE public.clubs SET social_feed_url = 'https://clontarfgaa.com/'
 WHERE club_id = 1 AND social_feed_url IS NULL;

-- Posts for the given clubs, newest first, at most p_limit per club.
-- Public club content (the club posted it on its own website).
CREATE OR REPLACE FUNCTION public.get_club_social_posts(p_club_ids bigint[], p_limit integer DEFAULT 20)
 RETURNS jsonb LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public' AS $$
  WITH p AS (
    SELECT s.*, c.club_name, c.crest,
           row_number() OVER (PARTITION BY s.club_id ORDER BY s.posted_at DESC NULLS LAST, s.id DESC) AS rn
      FROM club_social_posts s
      JOIN clubs c ON c.club_id = s.club_id
     WHERE s.club_id = ANY (p_club_ids)
       AND NOT s.hidden
       AND s.image_url IS NOT NULL
       AND NOT EXISTS (SELECT 1 FROM unnest(c.social_hide_words) w
                        WHERE length(trim(w)) > 0 AND s.caption ILIKE '%' || trim(w) || '%')
  )
  SELECT coalesce(jsonb_agg(jsonb_build_object(
           'id', p.id, 'club_id', p.club_id, 'club_name', p.club_name, 'crest', p.crest,
           'source', p.source, 'image_url', p.image_url, 'caption', p.caption,
           'posted_at', p.posted_at)
         ORDER BY p.posted_at DESC NULLS LAST, p.id DESC), '[]'::jsonb)
    FROM p WHERE p.rn <= greatest(1, least(coalesce(p_limit, 20), 50));
$$;
REVOKE ALL ON FUNCTION public.get_club_social_posts(bigint[], integer) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_club_social_posts(bigint[], integer) TO authenticated;

-- Wakes the edge function (service-role token signed from the vault
-- secret, as app_message_push_run does).
CREATE OR REPLACE FUNCTION public.club_social_sync_run()
 RETURNS integer LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public' AS $$
DECLARE
  v_secret text;
  v_jwt text;
BEGIN
  IF NOT EXISTS (SELECT 1 FROM clubs WHERE coalesce(social_feed_url, '') <> '') THEN
    RETURN 0;
  END IF;
  SELECT decrypted_secret INTO v_secret FROM vault.decrypted_secrets WHERE name = 'jwt_signing_secret' LIMIT 1;
  IF v_secret IS NULL THEN
    RAISE WARNING 'club_social_sync_run: jwt_signing_secret not found in vault';
    RETURN 0;
  END IF;
  SELECT extensions.sign(json_build_object(
           'role', 'service_role', 'iss', 'supabase', 'ref', 'gyfporsbdftvtakdvukt',
           'iat', extract(epoch from now())::integer, 'exp', (extract(epoch from now()) + 900)::integer
         )::json, v_secret) INTO v_jwt;
  PERFORM net.http_post(
    url     := 'https://gyfporsbdftvtakdvukt.supabase.co/functions/v1/club-social-feed',
    headers := jsonb_build_object('Content-Type', 'application/json', 'Authorization', 'Bearer ' || v_jwt),
    body    := '{}'::jsonb,
    timeout_milliseconds := 60000);
  RETURN 1;
END $$;
REVOKE ALL ON FUNCTION public.club_social_sync_run() FROM PUBLIC, anon, authenticated;

DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'pg_cron') THEN
    PERFORM cron.unschedule(jobname) FROM cron.job WHERE jobname = 'club-social-feed';
    PERFORM cron.schedule('club-social-feed', '7,37 * * * *', $c$SELECT public.club_social_sync_run()$c$);
  END IF;
END $$;
