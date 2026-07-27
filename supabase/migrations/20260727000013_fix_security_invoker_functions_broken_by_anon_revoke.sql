-- Migration 000011 revoked SELECT FROM anon on all public tables.
-- That was correct for tables that should be hidden from anonymous PostgREST
-- queries, but it broke any function that is SECURITY INVOKER (the default).
-- SECURITY INVOKER functions run as the calling role — when the PWA (which
-- sends no JWT) calls them, they execute as anon, which can no longer SELECT
-- the underlying tables. The result is an empty result set, not an error.
--
-- Fix: convert the 12 affected SECURITY INVOKER functions to SECURITY DEFINER
-- so they execute as the postgres owner regardless of the calling role.
-- This restores the behaviour these functions had before migration 000011.
-- SET search_path = 'public' is appended to each to satisfy the linter
-- (migration 000012 would have set this anyway, but explicit is safer here).

ALTER FUNCTION public.get_event_payment_details_v2(bigint)
    SECURITY DEFINER SET search_path = 'public';

ALTER FUNCTION public.get_event_payment_summary(bigint)
    SECURITY DEFINER SET search_path = 'public';

ALTER FUNCTION public.get_accepted_unpaid_members(bigint)
    SECURITY DEFINER SET search_path = 'public';

ALTER FUNCTION public.get_event_attendance_summary(integer, integer)
    SECURITY DEFINER SET search_path = 'public';

ALTER FUNCTION public.get_event_team_members_for_user(bigint, uuid)
    SECURITY DEFINER SET search_path = 'public';

ALTER FUNCTION public.get_event_team_members_with_attendance(bigint, uuid)
    SECURITY DEFINER SET search_path = 'public';

ALTER FUNCTION public.get_member_team_details(bigint, bigint)
    SECURITY DEFINER SET search_path = 'public';

ALTER FUNCTION public.get_members_attendance_latest(bigint, uuid)
    SECURITY DEFINER SET search_path = 'public';

ALTER FUNCTION public.get_user_event_members_with_attendance(bigint, uuid)
    SECURITY DEFINER SET search_path = 'public';

ALTER FUNCTION public.get_user_event_team_members(bigint, uuid, text, text)
    SECURITY DEFINER SET search_path = 'public';

ALTER FUNCTION public.get_user_members_event_attendance(bigint, uuid)
    SECURITY DEFINER SET search_path = 'public';

ALTER FUNCTION public.remove_member_from_team(bigint, bigint)
    SECURITY DEFINER SET search_path = 'public';
