-- Auto-clear event reminder ("attend") notifications so the bell and the app
-- badge only count reminders that still need an answer.
--
-- Until now an attend reminder stayed unread until the user tapped Event
-- Details inside the notifications list. Answering from Home or the event
-- screen never cleared it, nor did the event passing, and every extra
-- "Send Event Reminder" tap stacked another unread row.
--
-- Now a reminder is cleared (is_read = true) when:
--   1. 'answered'   every child on it has an answer (any screen, any device)
--   2. 'replaced'   a newer reminder for the same event reaches the same user
--   3. 'event_over' the event started more than 2 hours ago, or was deleted
--   4. 'cleanup_20261014' one-off pass over existing rows (cases 1 and 3)
--
-- auto_cleared records which rule cleared the row, so any pass can be undone:
--   UPDATE notifications SET is_read = false, when_read = NULL, auto_cleared = NULL
--   WHERE auto_cleared = '<reason>';
-- Rows cleared before delivery are also marked delivered so the cron job
-- doesn't push or email a reminder that is no longer needed.
--
-- Rollback: DROP TRIGGER trg_clear_attend_on_answer ON public.event_attendance;
--           DROP TRIGGER trg_replace_older_attend ON public.notifications;
--           SELECT cron.unschedule('clear-past-event-reminders');

ALTER TABLE public.notifications
    ADD COLUMN IF NOT EXISTS auto_cleared text;

-- Unread reminders, looked up by event (answer trigger) and recipient (resend).
CREATE INDEX IF NOT EXISTS idx_notifications_unread_attend_event
    ON public.notifications (event_id, recipient_user_id)
    WHERE is_read = false AND action = 'attend';

-- ─── Does this user still have a child who needs to answer this event? ──────
-- Same rules as populate_event_notifications called from Admin Options
-- (role_grade 10, role_level >= 10, squad filter, active links only), so a
-- reminder for "Sean and Aoife" stays until both have answered.

CREATE OR REPLACE FUNCTION public.user_has_unanswered_for_event(
    p_user_id  uuid,
    p_event_id bigint
)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = 'public'
AS $$
    SELECT EXISTS (
        SELECT 1
        FROM public.events e
        JOIN public.member_team_link mtl      ON mtl.team_id = e.team_id AND mtl.status = 'active'
        JOIN public.user_member_link uml      ON uml.member_id = mtl.member_id AND uml.status = 'active'
        JOIN public.member_team_role_link mtrl ON mtrl.member_team_id = mtl.member_team_id
        JOIN public.roles r                   ON r.role_id = mtrl.role_id
        WHERE e.event_id   = p_event_id
          AND uml.user_id  = p_user_id
          AND r.role_grade = 10
          AND r.role_level >= 10
          AND NOT EXISTS (
              SELECT 1
              FROM public.event_attendance ea
              WHERE ea.event_id  = p_event_id
                AND ea.member_id = mtl.member_id
                AND ea.response_id IS NOT NULL
                AND ea.response_id > 0
          )
          AND (
              e.squad_id IS NULL
              OR EXISTS (
                  SELECT 1 FROM public.member_squad_link msl
                  WHERE msl.member_id = mtl.member_id
                    AND msl.squad_id  = e.squad_id
                    AND msl.code_id   = public.get_updated_event_code(p_event_id::integer)
              )
          )
    );
$$;

REVOKE EXECUTE ON FUNCTION public.user_has_unanswered_for_event(uuid, bigint) FROM PUBLIC, anon, authenticated;
GRANT  EXECUTE ON FUNCTION public.user_has_unanswered_for_event(uuid, bigint) TO service_role;

-- ─── 1. Clear on answer ─────────────────────────────────────────────────────
-- Never blocks the answer being saved: any error is logged and swallowed.

CREATE OR REPLACE FUNCTION public.clear_attend_reminders_on_answer()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = 'public'
AS $$
BEGIN
    IF NEW.event_id IS NULL OR NEW.member_id IS NULL
       OR NEW.response_id IS NULL OR NEW.response_id <= 0 THEN
        RETURN NULL;
    END IF;

    BEGIN
        UPDATE public.notifications n
        SET is_read      = true,
            when_read    = now(),
            is_delivered = true,
            auto_cleared = 'answered'
        WHERE n.event_id = NEW.event_id
          AND n.action   = 'attend'
          AND n.is_read  = false
          AND n.recipient_user_id IN (
              SELECT uml.user_id
              FROM public.user_member_link uml
              WHERE uml.member_id = NEW.member_id
          )
          AND NOT public.user_has_unanswered_for_event(n.recipient_user_id, NEW.event_id);
    EXCEPTION WHEN OTHERS THEN
        RAISE WARNING 'clear_attend_reminders_on_answer failed (event %, member %): %',
            NEW.event_id, NEW.member_id, SQLERRM;
    END;

    RETURN NULL;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.clear_attend_reminders_on_answer() FROM PUBLIC, anon, authenticated;

DROP TRIGGER IF EXISTS trg_clear_attend_on_answer ON public.event_attendance;
CREATE TRIGGER trg_clear_attend_on_answer
    AFTER INSERT OR UPDATE OF response_id ON public.event_attendance
    FOR EACH ROW
    EXECUTE FUNCTION public.clear_attend_reminders_on_answer();

-- ─── 2. A new reminder replaces the older unread one ────────────────────────

CREATE OR REPLACE FUNCTION public.replace_older_attend_reminders()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = 'public'
AS $$
BEGIN
    IF NEW.action IS DISTINCT FROM 'attend' OR NEW.event_id IS NULL THEN
        RETURN NULL;
    END IF;

    BEGIN
        UPDATE public.notifications n
        SET is_read      = true,
            when_read    = now(),
            is_delivered = true,
            auto_cleared = 'replaced'
        WHERE n.event_id          = NEW.event_id
          AND n.recipient_user_id = NEW.recipient_user_id
          AND n.action            = 'attend'
          AND n.is_read           = false
          AND n.id               <> NEW.id;
    EXCEPTION WHEN OTHERS THEN
        RAISE WARNING 'replace_older_attend_reminders failed (notification %): %',
            NEW.id, SQLERRM;
    END;

    RETURN NULL;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.replace_older_attend_reminders() FROM PUBLIC, anon, authenticated;

DROP TRIGGER IF EXISTS trg_replace_older_attend ON public.notifications;
CREATE TRIGGER trg_replace_older_attend
    AFTER INSERT ON public.notifications
    FOR EACH ROW
    EXECUTE FUNCTION public.replace_older_attend_reminders();

-- ─── 3. Clear reminders for events that are over ────────────────────────────

CREATE OR REPLACE FUNCTION public.clear_past_event_reminders(p_reason text DEFAULT 'event_over')
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = 'public'
AS $$
DECLARE
    v_count integer;
BEGIN
    UPDATE public.notifications n
    SET is_read      = true,
        when_read    = now(),
        is_delivered = true,
        auto_cleared = p_reason
    WHERE n.action  = 'attend'
      AND n.is_read = false
      AND NOT EXISTS (
          SELECT 1 FROM public.events e
          WHERE e.event_id = n.event_id
            AND (e.event_date_time IS NULL
                 OR e.event_date_time > now() - interval '2 hours')
      );

    GET DIAGNOSTICS v_count = ROW_COUNT;
    RETURN v_count;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.clear_past_event_reminders(text) FROM PUBLIC, anon, authenticated;
GRANT  EXECUTE ON FUNCTION public.clear_past_event_reminders(text) TO service_role;

-- Nightly at 03:15 UTC. Guarded so the migration never fails on scheduling.
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM pg_namespace WHERE nspname = 'cron') THEN
        PERFORM cron.unschedule(jobid) FROM cron.job WHERE jobname = 'clear-past-event-reminders';
        PERFORM cron.schedule(
            'clear-past-event-reminders',
            '15 3 * * *',
            'SELECT public.clear_past_event_reminders()'
        );
    ELSE
        RAISE WARNING 'pg_cron not installed: clear-past-event-reminders not scheduled';
    END IF;
EXCEPTION WHEN OTHERS THEN
    RAISE WARNING 'Could not schedule clear-past-event-reminders: %', SQLERRM;
END;
$$;

-- ─── 4. One-off cleanup of existing rows ────────────────────────────────────

-- Past or deleted events.
SELECT public.clear_past_event_reminders('cleanup_20261014');

-- Older duplicates: keep only the newest unread reminder per user per event.
UPDATE public.notifications n
SET is_read      = true,
    when_read    = now(),
    is_delivered = true,
    auto_cleared = 'cleanup_20261014'
WHERE n.action  = 'attend'
  AND n.is_read = false
  AND EXISTS (
      SELECT 1 FROM public.notifications newer
      WHERE newer.action            = 'attend'
        AND newer.is_read           = false
        AND newer.event_id          = n.event_id
        AND newer.recipient_user_id = n.recipient_user_id
        AND newer.id                > n.id
  );

-- Upcoming events where every child on the reminder has already answered.
UPDATE public.notifications n
SET is_read      = true,
    when_read    = now(),
    is_delivered = true,
    auto_cleared = 'cleanup_20261014'
WHERE n.action  = 'attend'
  AND n.is_read = false
  AND n.event_id IS NOT NULL
  AND NOT public.user_has_unanswered_for_event(n.recipient_user_id, n.event_id);
