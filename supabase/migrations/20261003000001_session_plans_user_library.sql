-- Allow session plans to exist without an event (favourites library)
-- Add session_title column for efficient listing without loading full plan_json

ALTER TABLE public.session_plans
  ALTER COLUMN event_id DROP NOT NULL;

ALTER TABLE public.session_plans
  ADD COLUMN IF NOT EXISTS session_title text;

-- Index for fetching a user's plan library quickly
CREATE INDEX IF NOT EXISTS session_plans_user_library_idx
  ON public.session_plans (created_by, created_at DESC)
  WHERE event_id IS NULL;

-- Tighten SELECT policy — users can only read their own plans or plans for events
-- they have access to (for now: own plans only; event plans readable by creator)
DROP POLICY IF EXISTS "session_plans_select" ON public.session_plans;

CREATE POLICY "session_plans_select" ON public.session_plans
  FOR SELECT USING (auth.uid() = created_by);
