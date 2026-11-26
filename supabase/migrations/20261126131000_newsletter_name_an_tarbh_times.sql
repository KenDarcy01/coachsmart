-- Newsletter renamed "An Tarbh Times" (Ken, 2026-11-26). Settings title and
-- the open Issue 3 draft (issues copy the title when they are made).
UPDATE public.newsletter_settings SET title = 'An Tarbh Times', updated_at = now()
WHERE club_id = 1 AND title = 'The Tarbh Times';
UPDATE public.newsletter_issues SET title = 'An Tarbh Times', updated_at = now()
WHERE club_id = 1 AND title = 'The Tarbh Times' AND status <> 'approved';
