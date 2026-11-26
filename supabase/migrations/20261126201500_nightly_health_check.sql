-- Nightly health check (Ken, 2026-11-26): "a health monitoring system for the
-- app that runs each night ... key KPIs across the code and DB ... things that
-- don't look right, categorised by criticality", emailed at 4am Irish time.
--
-- Pieces:
--   health_reports       one row per night: KPIs, findings and a snapshot used
--                        for "what's new since last night" comparisons.
--   health_http_errors   pg_net keeps call results for ~6 hours only, so an
--                        hourly job copies failed background calls here.
--   health_collect()     runs every check inside the DB, returns jsonb.
--   health_report_wake() woken by cron at 03:00 and 04:00 UTC; it only goes on
--                        when it is 4am in Dublin (handles the clock change),
--                        then calls the health-check edge function, which adds
--                        the GitHub checks and emails the report.
-- Nothing here touches app tables; RLS on, no policies (service role only).

CREATE TABLE IF NOT EXISTS public.health_reports (
  run_date   date PRIMARY KEY,
  created_at timestamptz NOT NULL DEFAULT now(),
  kpis       jsonb NOT NULL DEFAULT '{}'::jsonb,
  findings   jsonb NOT NULL DEFAULT '[]'::jsonb,
  snapshot   jsonb NOT NULL DEFAULT '{}'::jsonb,
  sent_at    timestamptz,
  sent_to    text
);
ALTER TABLE public.health_reports ENABLE ROW LEVEL SECURITY;

CREATE TABLE IF NOT EXISTS public.health_http_errors (
  id          bigint PRIMARY KEY,
  created     timestamptz NOT NULL,
  status_code integer,
  timed_out   boolean,
  error_msg   text,
  snippet     text
);
ALTER TABLE public.health_http_errors ENABLE ROW LEVEL SECURITY;
CREATE INDEX IF NOT EXISTS health_http_errors_created_idx ON public.health_http_errors (created);

-- Copy failed background calls (5xx, timeouts, network errors) before pg_net
-- forgets them. Keeps 30 days.
CREATE OR REPLACE FUNCTION public.health_capture_http_errors()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = 'public'
AS $$
BEGIN
  INSERT INTO public.health_http_errors (id, created, status_code, timed_out, error_msg, snippet)
  SELECT r.id, r.created, r.status_code, r.timed_out, left(r.error_msg, 300),
         left(regexp_replace(coalesce(r.content, ''), '\s+', ' ', 'g'), 200)
  FROM net._http_response r
  WHERE (r.status_code >= 500 OR r.timed_out OR r.error_msg IS NOT NULL)
  ON CONFLICT (id) DO NOTHING;
  DELETE FROM public.health_http_errors WHERE created < now() - interval '30 days';
END;
$$;
REVOKE ALL ON FUNCTION public.health_capture_http_errors() FROM PUBLIC, anon, authenticated;

-- How long a cron job may go without running before it counts as late.
CREATE OR REPLACE FUNCTION public.health_cron_gap(p_schedule text)
RETURNS interval
LANGUAGE plpgsql
IMMUTABLE
SET search_path = 'public'
AS $$
DECLARE
  f text[] := regexp_split_to_array(trim(p_schedule), '\s+');
BEGIN
  IF array_length(f, 1) <> 5 THEN RETURN NULL; END IF;
  IF f[3] <> '*' OR f[4] <> '*' THEN RETURN NULL; END IF;       -- monthly etc: not checked
  IF f[5] <> '*' THEN RETURN interval '8 days'; END IF;          -- weekly
  IF f[2] = '*' THEN
    IF f[1] = '*' THEN RETURN interval '2 minutes'; END IF;
    IF f[1] ~ '^\*/\d+$' THEN RETURN make_interval(mins => 2 * substr(f[1], 3)::int); END IF;
    RETURN interval '2 hours';                                    -- hourly
  END IF;
  IF f[2] ~ '^\*/\d+$' THEN RETURN make_interval(hours => 2 * substr(f[2], 3)::int); END IF;
  RETURN interval '25 hours';                                     -- daily
END;
$$;
REVOKE ALL ON FUNCTION public.health_cron_gap(text) FROM PUBLIC, anon, authenticated;

CREATE OR REPLACE FUNCTION public.health_collect(p_run_date date DEFAULT (now() AT TIME ZONE 'Europe/Dublin')::date)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = 'public'
AS $$
DECLARE
  f        jsonb := '[]'::jsonb;   -- findings: {level, area, title, detail}
  k        jsonb := '{}'::jsonb;   -- KPIs
  snap     jsonb := '{}'::jsonb;   -- tonight's snapshot
  prev     jsonb := NULL;          -- last night's snapshot
  r        record;
  v_n      bigint;
  v_n2     bigint;
  v_txt    text;
  v_arr    jsonb;
  v_utc    timestamp := now() AT TIME ZONE 'utc';
BEGIN
  SELECT hr.snapshot INTO prev FROM public.health_reports hr
  WHERE hr.run_date < p_run_date ORDER BY hr.run_date DESC LIMIT 1;

  ------------------------------------------------------------------ cron jobs
  FOR r IN
    SELECT j.jobname, j.schedule,
           public.health_cron_gap(j.schedule) AS gap,
           (SELECT max(d.start_time) FROM cron.job_run_details d WHERE d.jobid = j.jobid) AS last_run,
           (SELECT count(*) FROM cron.job_run_details d WHERE d.jobid = j.jobid AND d.start_time > now() - interval '24 hours') AS runs,
           (SELECT count(*) FROM cron.job_run_details d WHERE d.jobid = j.jobid AND d.start_time > now() - interval '24 hours' AND d.status = 'failed') AS fails,
           (SELECT left(d.return_message, 160) FROM cron.job_run_details d WHERE d.jobid = j.jobid AND d.status = 'failed' ORDER BY d.start_time DESC LIMIT 1) AS last_msg
    FROM cron.job j WHERE j.active
  LOOP
    IF r.gap IS NOT NULL AND r.last_run IS NULL THEN
      f := f || jsonb_build_object('level','warning','area','Cron jobs','title', r.jobname || ' has never run',
             'detail','Schedule ' || r.schedule || '. Fine if it was added in the last day.');
    ELSIF r.gap IS NOT NULL AND r.last_run < now() - r.gap THEN
      f := f || jsonb_build_object('level','critical','area','Cron jobs','title', r.jobname || ' has stopped running',
             'detail','Last ran ' || to_char(r.last_run AT TIME ZONE 'Europe/Dublin', 'Dy DD Mon HH24:MI') || ' (schedule ' || r.schedule || ').');
    END IF;
    IF r.fails > 0 THEN
      f := f || jsonb_build_object(
             'level', CASE WHEN r.fails * 2 >= r.runs THEN 'critical' ELSE 'warning' END,
             'area','Cron jobs','title', r.jobname || ' failed ' || r.fails || ' of ' || r.runs || ' runs',
             'detail', coalesce(r.last_msg, ''));
    END IF;
  END LOOP;
  SELECT count(*) INTO v_n FROM cron.job WHERE active;
  k := k || jsonb_build_object('cron_jobs', v_n);

  --------------------------------------------------- background (pg_net) calls
  PERFORM public.health_capture_http_errors();
  SELECT count(*) INTO v_n FROM public.health_http_errors WHERE created > now() - interval '24 hours';
  k := k || jsonb_build_object('background_call_errors', v_n);
  IF v_n > 0 THEN
    SELECT string_agg(x.line, E'\n') INTO v_txt FROM (
      SELECT count(*) || ' x ' ||
             coalesce('HTTP ' || status_code, CASE WHEN timed_out THEN 'timed out' ELSE 'error' END) ||
             coalesce(': ' || nullif(left(coalesce(error_msg, snippet), 120), ''), '') AS line
      FROM public.health_http_errors WHERE created > now() - interval '24 hours'
      GROUP BY status_code, timed_out, left(coalesce(error_msg, snippet), 120)
      ORDER BY count(*) DESC LIMIT 5) x;
    f := f || jsonb_build_object('level', CASE WHEN v_n >= 3 THEN 'critical' ELSE 'warning' END,
           'area','Background calls','title', v_n || ' failed edge function call' || CASE WHEN v_n = 1 THEN '' ELSE 's' END || ' from cron',
           'detail', v_txt);
  END IF;

  ------------------------------------------------------- push / notifications
  SELECT count(*) INTO v_n FROM public.notifications
  WHERE NOT coalesce(is_delivered, false) AND auto_cleared IS NULL AND created_at < v_utc - interval '1 hour';
  k := k || jsonb_build_object('notifications_stuck', v_n);
  IF v_n > 0 THEN
    f := f || jsonb_build_object('level', CASE WHEN v_n > 100 THEN 'critical' ELSE 'warning' END,
           'area','Push and notifications','title', v_n || ' notification' || CASE WHEN v_n = 1 THEN '' ELSE 's' END || ' unsent for over an hour',
           'detail','The every-minute sender should clear these.');
  END IF;
  SELECT count(*) INTO v_n FROM public.notifications WHERE created_at > v_utc - interval '24 hours';
  SELECT count(*) INTO v_n2 FROM public.notifications WHERE created_at > v_utc - interval '24 hours' AND is_delivered AND auto_cleared IS NULL;
  k := k || jsonb_build_object('notifications_created', v_n, 'notifications_sent', v_n2);
  SELECT jsonb_object_agg(coalesce(delivery_method, 'push'), c) INTO v_arr FROM (
    SELECT delivery_method, count(*) c FROM public.notifications
    WHERE created_at > v_utc - interval '24 hours' AND is_delivered AND auto_cleared IS NULL GROUP BY 1) x;
  k := k || jsonb_build_object('notifications_by_method', coalesce(v_arr, '{}'::jsonb));
  IF v_n > 0 AND v_n2 = 0 THEN
    f := f || jsonb_build_object('level','critical','area','Push and notifications','title','No notifications were sent',
           'detail', v_n || ' were created in the last 24 hours but none went out.');
  ELSE
    SELECT count(*) INTO v_n2 FROM public.events
    WHERE event_date_time BETWEEN now() - interval '24 hours' AND now() + interval '24 hours' AND coalesce(status, '') <> 'cancelled';
    IF v_n = 0 AND v_n2 >= 5 THEN
      f := f || jsonb_build_object('level','critical','area','Push and notifications','title','No notifications at all in 24 hours',
             'detail', v_n2 || ' events are on either side of now, so reminders would normally be going out.');
    END IF;
  END IF;
  SELECT coalesce(sum(push_count), 0) INTO v_n FROM public.app_messages WHERE push_sent_at > now() - interval '24 hours';
  k := k || jsonb_build_object('message_pushes', v_n);

  ------------------------------------------------------------- data freshness
  SELECT extract(epoch FROM now() - max(synced_at))::bigint / 3600 INTO v_n FROM public.gaa_games;
  k := k || jsonb_build_object('gaa_hours_since_sync', v_n);
  IF v_n > 72 THEN
    f := f || jsonb_build_object('level','warning','area','Data freshness','title','GAA results not updated for ' || (v_n / 24) || ' days',
           'detail','Newest gaa_games sync is ' || v_n || ' hours old. Quiet in the off-season, worrying during it.');
  END IF;
  SELECT extract(epoch FROM now() - max(seen_at))::bigint / 3600 INTO v_n FROM public.newsletter_posts;
  IF v_n IS NOT NULL AND v_n > 48 THEN
    f := f || jsonb_build_object('level','warning','area','Data freshness','title','Newsletter crawl found nothing for ' || (v_n / 24) || ' days',
           'detail','Newest newsletter_posts row is ' || v_n || ' hours old.');
  END IF;

  ------------------------------------------------------------------- database
  v_n := pg_database_size(current_database()) / 1048576;
  k := k || jsonb_build_object('db_mb', v_n);
  snap := snap || jsonb_build_object('db_mb', v_n);
  IF v_n > 6000 THEN
    f := f || jsonb_build_object('level','critical','area','Database','title','Database is ' || v_n || ' MB','detail','Disk is 8 GB.');
  ELSIF v_n > 2000 THEN
    f := f || jsonb_build_object('level','warning','area','Database','title','Database is ' || v_n || ' MB','detail','Disk is 8 GB; it was ~250 MB in Nov 2026.');
  END IF;

  SELECT count(*) INTO v_n FROM pg_stat_activity;
  v_n2 := round(100.0 * v_n / current_setting('max_connections')::int);
  k := k || jsonb_build_object('db_connections', v_n, 'db_connections_pct', v_n2);
  IF v_n2 > 70 THEN
    f := f || jsonb_build_object('level', CASE WHEN v_n2 > 90 THEN 'critical' ELSE 'warning' END, 'area','Database',
           'title','Connections at ' || v_n2 || '%', 'detail', v_n || ' of ' || current_setting('max_connections') || ' in use at report time.');
  END IF;

  SELECT round(100.0 * sum(blks_hit) / nullif(sum(blks_hit + blks_read), 0), 1) INTO v_txt FROM pg_stat_database;
  k := k || jsonb_build_object('db_cache_hit_pct', v_txt::numeric);
  IF v_txt::numeric < 95 THEN
    f := f || jsonb_build_object('level','warning','area','Database','title','Cache hit rate ' || v_txt || '%',
           'detail','Below 95% means the database reads from disk a lot; compute may be too small.');
  END IF;

  SELECT string_agg(relname || ' (' || n_dead_tup || ' dead rows)', ', ') INTO v_txt FROM (
    SELECT relname, n_dead_tup FROM pg_stat_user_tables
    WHERE n_dead_tup > 50000 AND n_dead_tup > 0.2 * greatest(n_live_tup, 1)
    ORDER BY n_dead_tup DESC LIMIT 5) x;
  IF v_txt IS NOT NULL THEN
    f := f || jsonb_build_object('level','warning','area','Database','title','Tables need a clean-up (vacuum)','detail', v_txt);
  END IF;

  -- Slow queries: compare with last night's totals so an old slow spell does
  -- not repeat every night.
  SELECT jsonb_object_agg(queryid::text, jsonb_build_array(calls, round(total_exec_time::numeric, 1)))
  INTO v_arr FROM (
    SELECT queryid, calls, total_exec_time FROM extensions.pg_stat_statements
    WHERE queryid IS NOT NULL ORDER BY total_exec_time DESC LIMIT 300) x;
  snap := snap || jsonb_build_object('pss', coalesce(v_arr, '{}'::jsonb));
  SELECT string_agg(line, E'\n') INTO v_txt FROM (
    SELECT round(d_ms / d_calls) || ' ms avg over ' || d_calls || ' calls: ' ||
           coalesce(substring(q FROM '"public"\."([A-Za-z_0-9]+)"\(') || '()',
                    left(regexp_replace(q, '\s+', ' ', 'g'), 90)) AS line
    FROM (
      SELECT s.query AS q,
             s.calls - coalesce((prev->'pss'->(s.queryid::text)->>0)::bigint, 0) AS d_calls,
             s.total_exec_time - coalesce((prev->'pss'->(s.queryid::text)->>1)::numeric, 0) AS d_ms
      FROM extensions.pg_stat_statements s
      WHERE s.queryid IS NOT NULL
    ) z
    WHERE d_calls >= 3 AND d_ms / d_calls > 2000
      AND q !~* '(cron\.|net\.|pg_sleep|health_collect|vacuum|analyze|create |alter |drop |pg_catalog|information_schema)'
    ORDER BY d_ms / d_calls DESC LIMIT 3) x;
  IF v_txt IS NOT NULL THEN
    f := f || jsonb_build_object('level','warning','area','Database','title','Slow database calls (over 2 s average)','detail', v_txt);
  END IF;

  -------------------------------------------------------------------- storage
  SELECT round(coalesce(sum((metadata->>'size')::bigint), 0) / 1048576.0) INTO v_n FROM storage.objects;
  k := k || jsonb_build_object('storage_mb', v_n);
  snap := snap || jsonb_build_object('storage_mb', v_n);
  IF prev ? 'storage_mb' THEN
    k := k || jsonb_build_object('storage_growth_mb', v_n - (prev->>'storage_mb')::bigint);
    IF v_n - (prev->>'storage_mb')::bigint > 1000 THEN
      f := f || jsonb_build_object('level','warning','area','Storage','title','File storage grew ' || (v_n - (prev->>'storage_mb')::bigint) || ' MB in a day','detail','Total ' || v_n || ' MB of 100 GB.');
    END IF;
  END IF;
  IF v_n > 50000 THEN
    f := f || jsonb_build_object('level', CASE WHEN v_n > 90000 THEN 'critical' ELSE 'warning' END, 'area','Storage',
           'title','File storage at ' || v_n || ' MB','detail','Plan includes 100 GB.');
  END IF;

  ------------------------------------------------------------------- security
  SELECT coalesce(jsonb_agg(c.relname ORDER BY c.relname), '[]'::jsonb) INTO v_arr
  FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
  WHERE n.nspname = 'public' AND c.relkind IN ('r','p') AND NOT c.relrowsecurity;
  IF jsonb_array_length(v_arr) > 0 THEN
    f := f || jsonb_build_object('level','critical','area','Security','title', jsonb_array_length(v_arr) || ' table(s) with RLS switched off',
           'detail','Anyone with the app key can read and change these: ' || (SELECT string_agg(x, ', ') FROM jsonb_array_elements_text(v_arr) x));
  END IF;

  SELECT coalesce(jsonb_agg(p.proname ORDER BY p.proname), '[]'::jsonb) INTO v_arr
  FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
  WHERE n.nspname = 'public' AND p.prosecdef AND has_function_privilege('anon', p.oid, 'EXECUTE');
  snap := snap || jsonb_build_object('anon_definer', v_arr);
  k := k || jsonb_build_object('anon_definer_functions', jsonb_array_length(v_arr));
  IF prev ? 'anon_definer' THEN
    SELECT string_agg(x, ', ') INTO v_txt FROM jsonb_array_elements_text(v_arr) x
    WHERE NOT (prev->'anon_definer') ? x;
    IF v_txt IS NOT NULL THEN
      f := f || jsonb_build_object('level','warning','area','Security','title','New function(s) callable without signing in',
             'detail', v_txt || '. Added since last night; worth a REVOKE from anon unless the PWA needs it.');
    END IF;
  END IF;

  SELECT coalesce(jsonb_agg(p.proname ORDER BY p.proname), '[]'::jsonb) INTO v_arr
  FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
  LEFT JOIN pg_depend d ON d.objid = p.oid AND d.deptype = 'e'
  WHERE n.nspname = 'public' AND d.objid IS NULL
    AND NOT EXISTS (SELECT 1 FROM unnest(coalesce(p.proconfig, '{}')) c WHERE c LIKE 'search_path=%');
  snap := snap || jsonb_build_object('search_path_open', v_arr);
  IF prev ? 'search_path_open' THEN
    SELECT string_agg(x, ', ') INTO v_txt FROM jsonb_array_elements_text(v_arr) x
    WHERE NOT (prev->'search_path_open') ? x;
    IF v_txt IS NOT NULL THEN
      f := f || jsonb_build_object('level','warning','area','Security','title','New function(s) without a pinned search_path',
             'detail', v_txt || '. Add SET search_path = ''public''.');
    END IF;
  END IF;

  SELECT count(*) INTO v_n FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
  WHERE n.nspname = 'public' AND c.relkind = 'r' AND c.relrowsecurity
    AND NOT EXISTS (SELECT 1 FROM pg_policy pp WHERE pp.polrelid = c.oid);
  f := f || jsonb_build_object('level','planned','area','Security','title','Backend lock-down (Christmas task)',
         'detail', jsonb_array_length(snap->'anon_definer') || ' functions can be called without signing in, '
                   || v_n || ' tables are server-only (RLS on, no policies, which is fine) and leaked password protection is off. '
                   || 'Known and planned for the v3 flip; this only turns orange if a new gap appears.');

  ------------------------------------------------------------------- payments
  SELECT count(*), coalesce(sum(gross_amount), 0) INTO v_n, v_n2 FROM public.event_user_payment
  WHERE payment_status = 'confirmed' AND created_at > now() - interval '24 hours';
  k := k || jsonb_build_object('event_payments', v_n, 'event_payments_cents', v_n2);
  SELECT count(*) INTO v_n FROM public.event_user_payment
  WHERE payment_status = 'pending' AND created_at BETWEEN now() - interval '7 days' AND now() - interval '25 hours';
  IF v_n > 0 THEN
    f := f || jsonb_build_object('level','warning','area','Payments','title', v_n || ' event payment(s) still pending after a day',
           'detail','Stripe checkouts expire after 24 hours, so these should be confirmed or expired. Check the Stripe webhook.');
  END IF;
  SELECT count(*), coalesce(sum(amount_cents), 0) INTO v_n, v_n2 FROM public.lotto_payments WHERE paid_at > now() - interval '24 hours';
  k := k || jsonb_build_object('lotto_payments', v_n, 'lotto_payments_cents', v_n2);

  ----------------------------------------------------------------------- KPIs
  k := k || jsonb_build_object(
    'users_total',      (SELECT count(*) FROM public.users WHERE deleted_at IS NULL),
    'active_users_24h', (SELECT count(*) FROM public.users WHERE last_active_at > now() - interval '24 hours'),
    'active_users_7d',  (SELECT count(*) FROM public.users WHERE last_active_at > now() - interval '7 days'),
    'new_users_24h',    (SELECT count(*) FROM public.users WHERE created_at > now() - interval '24 hours'),
    'events_created',   (SELECT count(*) FROM public.events WHERE created_at > now() - interval '24 hours'),
    'events_today',     (SELECT count(*) FROM public.events WHERE (event_date_time AT TIME ZONE 'Europe/Dublin')::date = p_run_date AND coalesce(status, '') <> 'cancelled'),
    'attendance_responses', (SELECT count(*) FROM public.event_attendance WHERE created_at > now() - interval '24 hours'),
    'live_matches',     (SELECT count(*) FROM public.live_pulse WHERE updated_at > now() - interval '24 hours'),
    'migrations_applied', (SELECT count(*) FROM supabase_migrations.schema_migrations)
  );
  snap := snap || jsonb_build_object('migrations',
    (SELECT coalesce(jsonb_agg(version ORDER BY version), '[]'::jsonb) FROM supabase_migrations.schema_migrations WHERE version >= '20261001'));

  RETURN jsonb_build_object('run_date', p_run_date, 'kpis', k, 'findings', f, 'snapshot', snap);
END;
$$;
REVOKE ALL ON FUNCTION public.health_collect(date) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.health_collect(date) TO service_role;

-- Woken at 03:00 and 04:00 UTC; goes on only at 4am Dublin time (or when
-- forced for a test) and only once per Dublin date.
CREATE OR REPLACE FUNCTION public.health_report_wake(p_force boolean DEFAULT false)
RETURNS text
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = 'public'
AS $$
DECLARE
  v_local  timestamp := now() AT TIME ZONE 'Europe/Dublin';
  v_secret text;
  v_jwt    text;
BEGIN
  IF NOT p_force THEN
    IF extract(hour FROM v_local) <> 4 THEN RETURN 'not 4am in Dublin'; END IF;
    IF EXISTS (SELECT 1 FROM public.health_reports WHERE run_date = v_local::date AND sent_at IS NOT NULL) THEN
      RETURN 'already sent';
    END IF;
  END IF;
  SELECT decrypted_secret INTO v_secret FROM vault.decrypted_secrets WHERE name = 'jwt_signing_secret' LIMIT 1;
  IF v_secret IS NULL THEN
    RAISE WARNING 'health_report_wake: jwt_signing_secret not found in vault';
    RETURN 'no secret';
  END IF;
  SELECT extensions.sign(json_build_object(
           'role', 'service_role', 'iss', 'supabase', 'ref', 'gyfporsbdftvtakdvukt',
           'iat', extract(epoch FROM now())::integer, 'exp', (extract(epoch FROM now()) + 900)::integer
         )::json, v_secret) INTO v_jwt;
  PERFORM net.http_post(
    url     := 'https://gyfporsbdftvtakdvukt.supabase.co/functions/v1/health-check',
    headers := jsonb_build_object('Content-Type', 'application/json', 'Authorization', 'Bearer ' || v_jwt),
    body    := jsonb_build_object('run_date', v_local::date, 'test', p_force),
    timeout_milliseconds := 120000
  );
  RETURN 'woken';
END;
$$;
REVOKE ALL ON FUNCTION public.health_report_wake(boolean) FROM PUBLIC, anon, authenticated;

DO $$
BEGIN
  PERFORM cron.unschedule(jobid) FROM cron.job WHERE jobname IN ('health-report', 'health-http-errors');
  PERFORM cron.schedule('health-report', '0 3,4 * * *', 'SELECT public.health_report_wake()');
  PERFORM cron.schedule('health-http-errors', '50 * * * *', 'SELECT public.health_capture_http_errors()');
END $$;
