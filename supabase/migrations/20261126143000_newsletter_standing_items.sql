-- Newsletter "In every issue" items (Ken, 2026-11-26): standing pieces such as
-- Lotto, Membership or Club shop, set up once in the newsletter settings and
-- added (ticked) to each new issue, where that week's copy can be edited.
-- Array of { id, kicker, headline, body, placement ('story'|'short'),
-- photo_path, active }. Read and written only by the newsletter edge function.
ALTER TABLE public.newsletter_settings ADD COLUMN IF NOT EXISTS standing jsonb NOT NULL DEFAULT '[]'::jsonb;
