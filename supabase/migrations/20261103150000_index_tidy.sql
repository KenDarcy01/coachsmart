-- Index tidy-up (Ken, 2026-11-03).
--
-- Add: the every-minute notifications job and the batch send function both look
-- for is_delivered = false, which had no index, so every check read the whole
-- notifications table (600k full scans since March).
CREATE INDEX IF NOT EXISTS idx_notifications_undelivered
  ON public.notifications (id) WHERE is_delivered = false;

-- Drop indexes that duplicate another index or are never used.
-- event_response_type: exact copy of the primary key (event_responses_pkey).
DROP INDEX IF EXISTS public.idx_event_response_type_id;

-- event_attendance: never used / used twice since March.
DROP INDEX IF EXISTS public.idx_event_attendance_declined;
DROP INDEX IF EXISTS public.idx_event_attendance_response_id;

-- match_squad_details: three indexes on the same (match_squad_id, squad_id,
-- role_id, member_id); keep idx_export_match_details, which also carries every
-- included column of the other two.
DROP INDEX IF EXISTS public.idx_match_squad_details_lookup;
DROP INDEX IF EXISTS public.idx_match_squad_details_complete;
-- Covered by the front of idx_export_match_details / idx_msd_team_event_squad_member.
DROP INDEX IF EXISTS public.idx_match_squad_details_match_squad_id;
DROP INDEX IF EXISTS public.idx_match_squad_details_team_id;
-- Never used.
DROP INDEX IF EXISTS public.idx_match_squad_details_role_id;
