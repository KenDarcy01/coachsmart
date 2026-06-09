-- ============================================================
-- Edge Function Last Execution Report
-- ============================================================
-- Covers two call paths that are queryable from SQL:
--   1. Database webhooks  → supabase_functions.hooks + net._http_response
--   2. pg_cron schedules  → cron.job + cron.job_run_details
--
-- NOT covered here (only visible in Dashboard → Logs → Edge Functions):
--   - Direct calls from the Flutter app
--   - Calls from the Supabase client in edge functions themselves
-- ============================================================


-- ── 1. Database Webhooks ─────────────────────────────────────────────────────
-- Records every database webhook fire (e.g. trigger-push-notification on
-- notifications INSERT). Joined to net._http_response for HTTP status.

SELECT
    h.hook_name                                                 AS name,
    'database_webhook'                                          AS source,
    MAX(h.created_at)                                           AS last_fired,
    COUNT(*)                                                    AS total_fires,
    COUNT(r.id)  FILTER (WHERE r.status_code BETWEEN 200 AND 299)           AS http_2xx,
    COUNT(r.id)  FILTER (WHERE r.status_code NOT BETWEEN 200 AND 299
                            OR  r.timed_out = true)             AS http_errors,
    MAX(r.status_code)                                          AS last_status
FROM supabase_functions.hooks h
LEFT JOIN net._http_response r ON h.request_id = r.id
GROUP BY h.hook_name
ORDER BY last_fired DESC NULLS LAST;


-- ── 2. pg_cron Scheduled Jobs ────────────────────────────────────────────────
-- Covers any edge functions invoked on a schedule (e.g.
-- cron_batch_notification_send, event_email_reminder).

SELECT
    j.jobname                                                   AS name,
    'pg_cron'                                                   AS source,
    j.schedule                                                  AS cron_schedule,
    j.active                                                    AS is_active,
    MAX(d.start_time)                                           AS last_fired,
    MAX(d.end_time)                                             AS last_completed,
    COUNT(d.runid)                                              AS total_runs,
    COUNT(d.runid) FILTER (WHERE d.status = 'succeeded')        AS succeeded,
    COUNT(d.runid) FILTER (WHERE d.status <> 'succeeded')       AS failed,
    (SELECT d2.status
     FROM cron.job_run_details d2
     WHERE d2.jobid = j.jobid
     ORDER BY d2.start_time DESC
     LIMIT 1)                                                   AS last_run_status
FROM cron.job j
LEFT JOIN cron.job_run_details d ON j.jobid = d.jobid
GROUP BY j.jobid, j.jobname, j.schedule, j.active
ORDER BY last_fired DESC NULLS LAST;


-- ── 3. Combined Summary (single result set) ───────────────────────────────────

SELECT
    name,
    source,
    last_fired,
    total_fires,
    http_2xx     AS successes,
    http_errors  AS errors,
    NULL::text   AS cron_schedule,
    NULL::text   AS last_status
FROM (
    SELECT
        h.hook_name                                                         AS name,
        'database_webhook'                                                  AS source,
        MAX(h.created_at)                                                   AS last_fired,
        COUNT(*)                                                            AS total_fires,
        COUNT(r.id) FILTER (WHERE r.status_code BETWEEN 200 AND 299)       AS http_2xx,
        COUNT(r.id) FILTER (WHERE r.status_code NOT BETWEEN 200 AND 299
                               OR  r.timed_out = true)                     AS http_errors
    FROM supabase_functions.hooks h
    LEFT JOIN net._http_response r ON h.request_id = r.id
    GROUP BY h.hook_name
) webhooks

UNION ALL

SELECT
    name,
    source,
    last_fired,
    total_fires,
    succeeded    AS successes,
    failed       AS errors,
    cron_schedule,
    last_status
FROM (
    SELECT
        j.jobname                                                           AS name,
        'pg_cron'                                                           AS source,
        j.schedule                                                          AS cron_schedule,
        MAX(d.start_time)                                                   AS last_fired,
        COUNT(d.runid)                                                      AS total_fires,
        COUNT(d.runid) FILTER (WHERE d.status = 'succeeded')               AS succeeded,
        COUNT(d.runid) FILTER (WHERE d.status <> 'succeeded')              AS failed,
        (SELECT d2.status
         FROM cron.job_run_details d2
         WHERE d2.jobid = j.jobid
         ORDER BY d2.start_time DESC
         LIMIT 1)                                                           AS last_status
    FROM cron.job j
    LEFT JOIN cron.job_run_details d ON j.jobid = d.jobid
    GROUP BY j.jobid, j.jobname, j.schedule
) crons

ORDER BY last_fired DESC NULLS LAST;


-- ── 4. Known functions with no DB-side call record ───────────────────────────
-- Cross-reference against the full function list. NULL last_fired means
-- the function has never been called from a webhook or cron — it is either
-- called only from the app, or it has never been called at all.

WITH known_functions (function_name) AS (
    VALUES
        ('create-checkout-session'),
        ('create-checkout-session-V2'),
        ('create_google_sheet_squads'),
        ('create_stripe_payment_intent'),
        ('cron_batch_notification_send'),
        ('cron_push_batch_notifications'),
        ('event_email_reminder'),
        ('event_match_report_email'),
        ('export_team_list_xls'),
        ('export_to_csv'),
        ('export_to_xls'),
        ('get-checkout-session-details'),
        ('get-google-token'),
        ('get_unresponded_details_wrapper'),
        ('send-change-of-attendance'),
        ('send-email'),
        ('send-push-notification'),
        ('stripe-webhook-listener'),
        ('stripe-webhook-listener-V2'),
        ('translate-names'),
        ('trigger-push-notification')
),
db_calls AS (
    SELECT hook_name AS name, MAX(created_at) AS last_fired
    FROM supabase_functions.hooks
    GROUP BY hook_name

    UNION ALL

    SELECT jobname AS name, MAX(start_time) AS last_fired
    FROM cron.job j
    LEFT JOIN cron.job_run_details d ON j.jobid = d.jobid
    GROUP BY jobname
)
SELECT
    kf.function_name,
    MAX(dc.last_fired)  AS last_db_call,
    CASE
        WHEN MAX(dc.last_fired) IS NULL THEN 'app-only or never called'
        ELSE 'has DB-side call record'
    END                 AS note
FROM known_functions kf
LEFT JOIN db_calls dc ON dc.name ILIKE '%' || kf.function_name || '%'
GROUP BY kf.function_name
ORDER BY last_db_call DESC NULLS LAST;
