-- Add half-awareness to the match timer.
-- current_half tracks which half the timer is currently in (1 or 2).
-- half on match_stats_details tags each scoring event to a half for post-match breakdown.

ALTER TABLE public.match_timer
    ADD COLUMN IF NOT EXISTS current_half int NOT NULL DEFAULT 1;

ALTER TABLE public.match_stats_details
    ADD COLUMN IF NOT EXISTS half int NOT NULL DEFAULT 1;
