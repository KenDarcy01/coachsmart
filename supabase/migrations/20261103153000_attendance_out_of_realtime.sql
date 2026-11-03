-- Nothing subscribes to live changes on event_attendance (app, PWA webviews or
-- website), so stop streaming it through Realtime (Ken, 2026-11-03). Every
-- attendance reply was being decoded for live updates nobody received.
-- Undo: ALTER PUBLICATION supabase_realtime ADD TABLE public.event_attendance;
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_publication_tables
             WHERE pubname = 'supabase_realtime' AND schemaname = 'public' AND tablename = 'event_attendance') THEN
    ALTER PUBLICATION supabase_realtime DROP TABLE public.event_attendance;
  END IF;
END;
$$;
