-- The club's 21 Nov Instagram post about the U21 hurlers (photo) left the
-- site's strip before newsletter_posts existed, so each new Issue 3 draft
-- lost it. Keep it in the post cache (its original caption was not saved:
-- this line only carries the score so it matches the result) and put the
-- photo back on the current draft's story.
INSERT INTO public.newsletter_posts (club_id, key, source, title, text, url, image, at)
VALUES (1,
  'https://images.squarespace-cdn.com/content/v1/5fc524b82cf09257bd87237e/1795277829091-NL6G2HE7FDGKE1W8I35Z/image-asset.jpeg',
  'instagram', '', 'U21 hurlers: Naomh Barrog 1-18 Clontarf 2-16, Saturday 21 November.', 'https://clontarfgaa.com',
  'https://images.squarespace-cdn.com/content/v1/5fc524b82cf09257bd87237e/1795277829091-NL6G2HE7FDGKE1W8I35Z/image-asset.jpeg',
  1795277829091)
ON CONFLICT (club_id, key) DO NOTHING;

UPDATE public.newsletter_stories
SET photo_path = '1/1/034f979b-fa24-4c23-a42a-fc9c637f4424.jpg',
    data = data || '{"image":"https://images.squarespace-cdn.com/content/v1/5fc524b82cf09257bd87237e/1795277829091-NL6G2HE7FDGKE1W8I35Z/image-asset.jpeg"}'::jsonb
WHERE photo_path IS NULL AND kind = 'win'
  AND data->>'home' = 'Naomh Barrog' AND data->>'away' = 'Clontarf' AND data->>'day' = '2026-11-21'
  AND issue_id IN (SELECT issue_id FROM public.newsletter_issues WHERE club_id = 1 AND week_start = '2026-11-16');
