-- One-off (Ken, 2026-10-22): reload this week's games now instead of waiting for
-- tonight. Sportlomo moved Clontarf v Ballymun Kickhams (Minor football) from Mon
-- 26 Oct to Fri 23 Oct after this morning's nightly load. Nightly part 2 covers
-- today to six days ahead, every code. Runs once, when this migration is applied.
SELECT public.gaa_sync_wake('nightly', 2);
