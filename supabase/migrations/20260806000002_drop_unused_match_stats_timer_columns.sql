-- timer_start, timer_end, timer_running on match_stats were never written
-- to by any current code path (timer state lives in match_timer instead).
ALTER TABLE public.match_stats
  DROP COLUMN IF EXISTS timer_start,
  DROP COLUMN IF EXISTS timer_end,
  DROP COLUMN IF EXISTS timer_running;
