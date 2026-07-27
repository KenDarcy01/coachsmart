-- Add soft-delete / status support to events and members.
-- Both columns default to 'active' so all existing rows are unaffected.
-- No RPC or FlutterFlow changes are required at this step — the columns
-- simply exist until the RPC rewrites (next migration) start using them.
--
-- events.status values:
--   'active'    — normal, visible to eligible users
--   'cancelled' — shown with cancelled treatment until event_date passes
--   'deleted'   — hidden immediately from all views
--
-- members.status values:
--   'active'   — normal, appears in all member lists
--   'inactive' — hidden from active pickers; preserved in historical data
--   'deleted'  — hidden everywhere

ALTER TABLE public.events
    ADD COLUMN IF NOT EXISTS status text NOT NULL DEFAULT 'active'
    CHECK (status IN ('active', 'cancelled', 'deleted'));

ALTER TABLE public.members
    ADD COLUMN IF NOT EXISTS status text NOT NULL DEFAULT 'active'
    CHECK (status IN ('active', 'inactive', 'deleted'));

-- Index for the common filter (status = 'active' or != 'deleted')
CREATE INDEX IF NOT EXISTS idx_events_status  ON public.events  (status);
CREATE INDEX IF NOT EXISTS idx_members_status ON public.members (status);
