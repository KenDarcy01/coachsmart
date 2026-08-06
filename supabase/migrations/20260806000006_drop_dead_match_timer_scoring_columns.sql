-- Scoring was moved to match_stats_details; these six columns have been
-- completely unused since match_timer_scores migration (20260715000003).
ALTER TABLE public.match_timer
    DROP COLUMN IF EXISTS home_goals,
    DROP COLUMN IF EXISTS home_points,
    DROP COLUMN IF EXISTS home_two_ptrs,
    DROP COLUMN IF EXISTS away_goals,
    DROP COLUMN IF EXISTS away_points,
    DROP COLUMN IF EXISTS away_two_ptrs;
