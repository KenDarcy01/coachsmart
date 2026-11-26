-- Put back the U21 hurlers photo lost when Issue 3 was re-suggested on
-- 2026-11-26 (the club site's feed no longer listed that post). The copy is
-- still in the newsletter bucket.
UPDATE public.newsletter_stories
SET photo_path = '1/1/034f979b-fa24-4c23-a42a-fc9c637f4424.jpg',
    data = data || '{"image":"https://images.squarespace-cdn.com/content/v1/5fc524b82cf09257bd87237e/1795277829091-NL6G2HE7FDGKE1W8I35Z/image-asset.jpeg"}'::jsonb
WHERE story_id = 8 AND photo_path IS NULL AND data->>'game_id' = '90835';
