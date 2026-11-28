-- Ken, 2026-11-28: make club officer Carmel Jordan a follower of Clontarf GAA
-- (club 1). She is on no team, so v3 opens on the club screen for her.
INSERT INTO public.club_followers (user_id, club_id)
VALUES ('58221f65-fa39-403f-9a3f-1be6b77fcbc8', 1)
ON CONFLICT DO NOTHING;
