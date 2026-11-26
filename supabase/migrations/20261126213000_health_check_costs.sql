-- Health check: costs and growth section (Ken 2026-11-26: flag anything using
-- too many resources, growing too fast or out of the norm, i.e. anything that
-- could add to the bill). Also counts background calls per hour, because
-- pg_net only keeps its call history for about 6 hours.

CREATE TABLE IF NOT EXISTS public.health_http_counts (
  hour  timestamptz PRIMARY KEY,
  calls integer NOT NULL
);
ALTER TABLE public.health_http_counts ENABLE ROW LEVEL SECURITY;

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

  INSERT INTO public.health_http_counts (hour, calls)
  SELECT date_trunc('hour', r.created), count(*) FROM net._http_response r GROUP BY 1
  ON CONFLICT (hour) DO UPDATE SET calls = greatest(health_http_counts.calls, excluded.calls);
  DELETE FROM public.health_http_counts WHERE hour < now() - interval '60 days';
END;
$$;
REVOKE ALL ON FUNCTION public.health_capture_http_errors() FROM PUBLIC, anon, authenticated;

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
  hist     jsonb;
  v_avg    numeric;
  v_days   bigint;
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
      f := f || jsonb_build_object('level','info','area','Cron jobs','title', r.jobname || ' has not run yet',
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

  ------------------------------------------------------- costs and growth
  -- Ken 2026-11-26: "know when something is taking too many resources or
  -- building too quickly or just out of the norm ... anything that impacts my
  -- costs". Compares with last night's snapshot and the 7-night average.
  SELECT coalesce(jsonb_agg(hr.kpis ORDER BY hr.run_date DESC), '[]'::jsonb) INTO hist
  FROM (SELECT run_date, kpis FROM public.health_reports WHERE run_date < p_run_date ORDER BY run_date DESC LIMIT 7) hr;

  -- Database and file storage growth, and days until the plan's included size.
  IF prev ? 'db_mb' THEN
    v_n := (k->>'db_mb')::bigint - (prev->>'db_mb')::bigint;
    k := k || jsonb_build_object('db_growth_mb', v_n);
  END IF;
  FOR r IN SELECT * FROM (VALUES
      ('db_growth_mb', 'db_mb', 'Database', 8192, 50),
      ('storage_growth_mb', 'storage_mb', 'File storage', 102400, 1000)) v(gkey, skey, label, cap_mb, big_mb)
  LOOP
    IF NOT k ? r.gkey THEN CONTINUE; END IF;
    v_n := (k->>r.gkey)::bigint;
    SELECT avg((h->>r.gkey)::numeric) INTO v_avg FROM jsonb_array_elements(hist) h WHERE h ? r.gkey;
    IF v_n > r.big_mb OR (v_avg IS NOT NULL AND v_n > 20 AND v_n > 3 * greatest(v_avg, 1)) THEN
      f := f || jsonb_build_object('level','warning','area','Costs and growth',
             'title', r.label || ' grew ' || v_n || ' MB overnight',
             'detail', 'Usual is ' || coalesce(round(v_avg)::text || ' MB a night', 'not known yet') || '. Now ' || (k->>r.skey) || ' MB of ' || (r.cap_mb / 1024) || ' GB included.');
    END IF;
    IF v_avg IS NOT NULL AND v_avg > 0 THEN
      v_days := ((r.cap_mb - (k->>r.skey)::numeric) / v_avg)::bigint;
      k := k || jsonb_build_object(r.skey || '_days_to_cap', v_days);
      IF v_days < 60 THEN
        f := f || jsonb_build_object('level', CASE WHEN v_days < 14 THEN 'critical' ELSE 'warning' END, 'area','Costs and growth',
               'title', r.label || ' will pass the included ' || (r.cap_mb / 1024) || ' GB in about ' || v_days || ' days',
               'detail', 'At the recent ' || round(v_avg) || ' MB a night. After that Supabase charges extra.');
      END IF;
    END IF;
  END LOOP;

  -- Tables growing fast (includes system tables such as job and call history,
  -- which have quietly grown to hundreds of MB before).
  SELECT jsonb_object_agg(t, mb) INTO v_arr FROM (
    SELECT n.nspname || '.' || c.relname AS t, round(pg_total_relation_size(c.oid) / 1048576.0, 1) AS mb
    FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
    WHERE c.relkind IN ('r','m') AND n.nspname NOT IN ('pg_catalog','information_schema','pg_toast')
    ORDER BY pg_total_relation_size(c.oid) DESC LIMIT 40) x;
  snap := snap || jsonb_build_object('tables_mb', coalesce(v_arr, '{}'::jsonb));
  IF prev ? 'tables_mb' THEN
    SELECT string_agg(t || ' +' || round(d) || ' MB (now ' || round(mb) || ' MB)', E'\n' ORDER BY d DESC) INTO v_txt FROM (
      SELECT * FROM (
        SELECT e.key AS t, e.value::numeric AS mb, e.value::numeric - coalesce((prev->'tables_mb'->>e.key)::numeric, 0) AS d
        FROM jsonb_each_text(v_arr) e) y
      WHERE d > 50 OR (d > 20 AND d > mb * 0.25)
      ORDER BY d DESC LIMIT 5) x;
    IF v_txt IS NOT NULL THEN
      f := f || jsonb_build_object('level','warning','area','Costs and growth','title','Tables growing fast overnight','detail', v_txt);
    END IF;
  END IF;

  -- How busy the database was: query time over the day as % of one CPU.
  SELECT round(sum(total_exec_time)::numeric) INTO v_avg FROM extensions.pg_stat_statements;
  snap := snap || jsonb_build_object('pss_total_ms', v_avg, 'at', extract(epoch FROM now())::bigint);
  IF prev ? 'pss_total_ms' AND v_avg >= (prev->>'pss_total_ms')::numeric THEN
    v_days := round(100 * (v_avg - (prev->>'pss_total_ms')::numeric)
                    / greatest(1000 * (extract(epoch FROM now())::bigint - (prev->>'at')::bigint), 1));
    k := k || jsonb_build_object('db_busy_pct', v_days);
    IF v_days > 25 THEN
      f := f || jsonb_build_object('level', CASE WHEN v_days > 60 THEN 'critical' ELSE 'warning' END, 'area','Costs and growth',
             'title','Database was ' || v_days || '% busy',
             'detail','Usually about 1%. Sustained high use means a bigger (paid) compute size, so find the cause first.');
    END IF;
  END IF;

  -- Background call volume (runaway cron loops cost function invocations).
  SELECT coalesce(sum(calls), 0) INTO v_n FROM public.health_http_counts WHERE hour > now() - interval '24 hours';
  k := k || jsonb_build_object('background_calls', v_n);

  -- Unusual volumes: tonight more than 3x the 7-night average.
  FOR r IN SELECT * FROM (VALUES
      ('notifications_created', 'Notifications created', 300),
      ('background_calls', 'Background function calls', 2000),
      ('message_pushes', 'Message pushes', 500),
      ('events_created', 'Events created', 100),
      ('new_users_24h', 'New sign-ups', 30)) v(key, label, floor_n)
  LOOP
    IF NOT k ? r.key THEN CONTINUE; END IF;
    SELECT avg((h->>r.key)::numeric) INTO v_avg FROM jsonb_array_elements(hist) h WHERE h ? r.key;
    IF jsonb_array_length(hist) >= 3 AND (k->>r.key)::numeric > r.floor_n
       AND (k->>r.key)::numeric > 3 * greatest(coalesce(v_avg, 0), 1) THEN
      f := f || jsonb_build_object('level','warning','area','Costs and growth',
             'title', r.label || ' unusually high: ' || (k->>r.key),
             'detail', 'The 7-night average is ' || round(v_avg) || '. Could be a busy day, or something looping.');
    END IF;
  END LOOP;

  RETURN jsonb_build_object('run_date', p_run_date, 'kpis', k, 'findings', f, 'snapshot', snap);
END;
$$;
REVOKE ALL ON FUNCTION public.health_collect(date) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.health_collect(date) TO service_role;

