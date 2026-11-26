-- Chairperson dashboard (get_club_dashboard) speed-up, Ken OK 2026-11-26.
-- Its sorts over a season of attendance replies (~100k rows for Clontarf) spilled
-- to disk with the default 3.5 MB work_mem. Give this one function 32 MB.
-- Measured on the main query: 1.30 s -> 0.77 s. Only this function is affected.
-- Undo: ALTER FUNCTION public.get_club_dashboard(bigint, timestamptz, timestamptz) RESET work_mem;
ALTER FUNCTION public.get_club_dashboard(bigint, timestamptz, timestamptz) SET work_mem = '32MB';
