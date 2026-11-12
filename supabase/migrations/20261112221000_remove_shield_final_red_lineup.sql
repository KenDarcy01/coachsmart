-- Ken (2026-11-12): remove lineup 154 only (Clontarf Girls 2012, Red Team,
-- Shield Final v Naomh Márnog, saved 21:56) so that event has no saved
-- lineup for the Red squad. No other lineup is touched.
delete from public.lineup_details where lineup_id = 154;
delete from public.lineup where lineup_id = 154;
