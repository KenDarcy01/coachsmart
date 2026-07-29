-- Add status column to user_member_link.
-- Default 'active' leaves all existing rows unaffected — no PWA impact.
-- 'pending' is set when a second user (e.g. other parent) requests access
-- to an existing member, and awaits explicit admin approval before granting
-- any visibility into that member's team data.

ALTER TABLE public.user_member_link
    ADD COLUMN IF NOT EXISTS status text NOT NULL DEFAULT 'active';

CREATE INDEX IF NOT EXISTS idx_uml_status
    ON public.user_member_link USING btree (status);
