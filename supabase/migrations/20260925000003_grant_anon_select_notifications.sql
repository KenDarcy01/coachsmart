-- Grant anon SELECT on notifications so Supabase Realtime's
-- subscription_check_filters() passes the has_column_privilege check.
-- Without this, subscriptions using .eq('recipient_user_id', ...) fail with
-- "invalid column for filter recipient_user_id" because the column is excluded
-- from col_names when anon lacks SELECT.
-- RLS (recipient_user_id = auth.uid()) ensures anon sees zero rows.
GRANT SELECT ON public.notifications TO anon;
