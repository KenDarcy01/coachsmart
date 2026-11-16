-- Ken (2026-11-16) signs in to the club dashboard with his work account, which
-- holds no SuperUser team role. Make that account an officer of Clontarf GAA.
INSERT INTO public.club_officers (club_id, user_id, title)
SELECT 1, '4b28dd07-08f4-4555-a57b-98dd5d9e22ef'::uuid, 'Officer'
WHERE EXISTS (SELECT 1 FROM public.users WHERE user_id = '4b28dd07-08f4-4555-a57b-98dd5d9e22ef')
ON CONFLICT (club_id, user_id) DO UPDATE SET is_active = true;
