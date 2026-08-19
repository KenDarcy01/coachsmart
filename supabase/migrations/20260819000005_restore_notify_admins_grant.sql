-- notify_admins_attendance_change is called directly from the app when a user
-- changes their attendance response. Migration 20260727000011 accidentally
-- revoked the authenticated grant during a lockdown sweep.
GRANT EXECUTE ON FUNCTION public.notify_admins_attendance_change(integer, integer, integer, bigint) TO authenticated;
