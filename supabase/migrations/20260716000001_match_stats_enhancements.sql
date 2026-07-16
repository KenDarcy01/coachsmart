-- Match stats enhancements: injury time cap, timer state on entries, finalisation

-- Max injury time allowance per match timer session (default 10 mins)
ALTER TABLE match_timer
  ADD COLUMN IF NOT EXISTS injury_seconds INTEGER NOT NULL DEFAULT 600;

-- Track timer state at the moment each stat entry was recorded
-- 'running' = scored during live play; 'paused' = entered while paused; 'stopped' = corrective entry after match
ALTER TABLE match_stats_details
  ADD COLUMN IF NOT EXISTS timer_status TEXT CHECK (timer_status IN ('running', 'paused', 'stopped'));

-- Allow a stats session to be explicitly finalised by the user
ALTER TABLE match_stats
  ADD COLUMN IF NOT EXISTS finalised_at TIMESTAMPTZ;
