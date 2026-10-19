-- Scouting reports no longer pick the two sides automatically (Ken, 2026-10-19): the coach
-- chooses code, age, division and team for both sides. Clear the pairs and team links the
-- old automatic guess saved, so every match shows the picker on its next open.
DELETE FROM public.scouting_reports WHERE created_at < '2026-10-19 02:20:00+00';
DELETE FROM public.scouting_links   WHERE updated_at < '2026-10-19 02:20:00+00';
