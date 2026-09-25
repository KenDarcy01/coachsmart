-- Reset the notifications table in the supabase_realtime publication so it
-- replicates all columns. If the publication was added with a column-level
-- filter (attnames IS NOT NULL), Supabase Realtime rejects .eq() filters on
-- non-PK columns such as recipient_user_id with "invalid column for filter".
-- Dropping and re-adding the table clears any column restriction.
ALTER PUBLICATION supabase_realtime DROP TABLE public.notifications;
ALTER PUBLICATION supabase_realtime ADD TABLE public.notifications;
