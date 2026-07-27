-- Published PWA queries the teams table directly via PostgREST (no JWT,
-- runs as anon). Migration 000011 revoked SELECT from anon on all tables,
-- breaking this query. Re-grant SELECT to anon on teams so the Create Event
-- dropdown loads. Remove once the PWA is updated to use the RPC instead.

GRANT SELECT ON public.teams TO anon;
