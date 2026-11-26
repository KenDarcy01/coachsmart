-- Newsletter: keep every club website / Instagram post we see (2026-11-26).
-- The club site's Instagram strip only shows the latest few posts, so a
-- week's posts (and their photos) were lost when suggestions were made again
-- later in the week. The newsletter edge function stores each post here when
-- the newsletter is opened or suggestions run, and reads the week from here.
-- RLS on, no policies: only the edge function (service role) uses it.
CREATE TABLE IF NOT EXISTS public.newsletter_posts (
  club_id  bigint NOT NULL REFERENCES public.clubs(club_id) ON DELETE CASCADE,
  key      text   NOT NULL,          -- image URL, or the text when there is no image
  source   text   NOT NULL,          -- website / instagram
  title    text,
  text     text   NOT NULL DEFAULT '',
  url      text,
  image    text,
  at       bigint NOT NULL,          -- post time, ms since epoch
  seen_at  timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (club_id, key)
);
CREATE INDEX IF NOT EXISTS newsletter_posts_at ON public.newsletter_posts (club_id, at);
ALTER TABLE public.newsletter_posts ENABLE ROW LEVEL SECURITY;

-- Put the U21 hurlers photo back on the current Issue 3 draft (made again at
-- 15:41 after the first draft was deleted; the post had left the site's strip).
UPDATE public.newsletter_stories
SET photo_path = '1/1/034f979b-fa24-4c23-a42a-fc9c637f4424.jpg',
    data = data || '{"image":"https://images.squarespace-cdn.com/content/v1/5fc524b82cf09257bd87237e/1795277829091-NL6G2HE7FDGKE1W8I35Z/image-asset.jpeg"}'::jsonb
WHERE photo_path IS NULL AND kind = 'win'
  AND data->>'home' = 'Naomh Barrog' AND data->>'away' = 'Clontarf' AND data->>'day' = '2026-11-21'
  AND issue_id IN (SELECT issue_id FROM public.newsletter_issues WHERE club_id = 1 AND week_start = '2026-11-16');
