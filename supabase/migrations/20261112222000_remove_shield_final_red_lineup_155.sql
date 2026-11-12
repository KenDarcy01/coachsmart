-- Ken (2026-11-12, confirmed "Delete 155"): remove lineup 155 only
-- (Clontarf Girls 2012, Red Team, Shield Final v Naomh Márnog, saved 22:15).
-- No other lineup is touched.
delete from public.lineup_details where lineup_id = 155;
delete from public.lineup where lineup_id = 155;
