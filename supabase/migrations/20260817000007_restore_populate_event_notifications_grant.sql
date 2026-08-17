-- populate_event_notifications was incorrectly treated as unused and had its
-- PUBLIC grant revoked without a replacement grant.  It is actively called
-- from the app.  Restore access.

GRANT EXECUTE ON FUNCTION public.populate_event_notifications(integer, integer, integer) TO authenticated;
GRANT EXECUTE ON FUNCTION public.populate_event_notifications(integer, integer, integer) TO service_role;
