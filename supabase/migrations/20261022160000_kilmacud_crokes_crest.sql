-- Kilmacud Crokes crest and colours (Ken, 2026-10-22): purple is the primary,
-- gold from the crest is the secondary. Crest hosted at coachsmart.app/crests/.
UPDATE public.clubs
SET crest = 'https://coachsmart.app/crests/kilmacud-crokes.png',
    primary_colour = '#5A058C',
    secondary_colour = '#F0B420'
WHERE club_name = 'Kilmacud Crokes';
