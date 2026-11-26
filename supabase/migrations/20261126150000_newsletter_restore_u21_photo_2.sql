-- Retry of 20261126140000: the results re-sync gave the game a new id, so
-- match the U21 hurlers story by its teams and day instead.
UPDATE public.newsletter_stories
SET photo_path = '1/1/034f979b-fa24-4c23-a42a-fc9c637f4424.jpg',
    data = data || '{"image":"https://images.squarespace-cdn.com/content/v1/5fc524b82cf09257bd87237e/1795277829091-NL6G2HE7FDGKE1W8I35Z/image-asset.jpeg"}'::jsonb
WHERE photo_path IS NULL AND kind = 'win'
  AND data->>'home' = 'Naomh Barrog' AND data->>'away' = 'Clontarf' AND data->>'day' = '2026-11-21'
  AND issue_id IN (SELECT issue_id FROM public.newsletter_issues WHERE club_id = 1 AND week_start = '2026-11-16');
