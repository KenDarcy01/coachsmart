-- Ken (2026-11-13, confirmed "Delete 156"): remove lineup 156 only
-- (Clontarf Girls 2012, Red Team, Shield Final v Naomh Márnog, saved 06:38).
-- No other lineup is touched.
delete from public.lineup_details where lineup_id = 156;
delete from public.lineup where lineup_id = 156;
