-- GAA season store: every Dublin game (all clubs, all codes) kept in our own
-- tables, so a whole-season comparison page can load in one go instead of
-- scraping Sportlomo live. Filled by the gaa-sync edge function:
--   * gaa-season-backfill (every 10 min): loads the next two-week window of the
--     season that has never loaded, and does nothing once the season is complete
--   * gaa-season-nightly-0/1/2 (04:15, 04:20, 04:25): reload the last two weeks
--     and the next four weeks so new results, fixtures and changes come in
-- Public fixture data only: nothing here links to users or members.

-- ── Tables ───────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.gaa_clubs (
  club_id     serial PRIMARY KEY,
  name        text NOT NULL,                       -- the name we show (GAA spelling)
  name_key    text NOT NULL UNIQUE,                -- lower-case letters and digits only
  alias_keys  text[] NOT NULL DEFAULT '{}',        -- other names it goes by (camogie list, spellings)
  gaa_id      text,                                -- Sportlomo club IDs per organisation
  camogie_id  text,
  lgfa_id     text,
  created_at  timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS gaa_clubs_alias_keys ON public.gaa_clubs USING gin (alias_keys);

CREATE TABLE IF NOT EXISTS public.gaa_competitions (
  comp_id     text PRIMARY KEY,                    -- Sportlomo competition ID
  name        text NOT NULL,
  code        text NOT NULL,                       -- Football, Hurling, Camogie, Ladies Football
  age         text NOT NULL,                       -- U8 … U16, Minor, Junior, Senior, Adult, Other
  grade       text NOT NULL DEFAULT '',            -- e.g. League Div.3
  level       text NOT NULL,                       -- ccc1 (U12 and under), ccc2 (U13-U16), adult
  season      int  NOT NULL,
  updated_at  timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.gaa_games (
  game_id       bigserial PRIMARY KEY,
  comp_id       text NOT NULL REFERENCES public.gaa_competitions (comp_id),
  code          text NOT NULL,
  start_at      timestamptz NOT NULL,
  home_team     text NOT NULL,                     -- as listed, e.g. "Clontarf C"
  away_team     text NOT NULL,
  home_club_id  int REFERENCES public.gaa_clubs (club_id),
  away_club_id  int REFERENCES public.gaa_clubs (club_id),
  status        text NOT NULL CHECK (status IN ('fixture', 'result')),
  home_score    text NOT NULL DEFAULT '',          -- "2-10"
  away_score    text NOT NULL DEFAULT '',
  home_pts      int,                               -- total, goals count 3
  away_pts      int,
  venue         text NOT NULL DEFAULT '',
  referee       text NOT NULL DEFAULT '',
  note          text NOT NULL DEFAULT '',
  synced_at     timestamptz NOT NULL DEFAULT now(),
  UNIQUE (comp_id, home_team, away_team, start_at)
);
CREATE INDEX IF NOT EXISTS gaa_games_start ON public.gaa_games (start_at);
CREATE INDEX IF NOT EXISTS gaa_games_home_club ON public.gaa_games (home_club_id);
CREATE INDEX IF NOT EXISTS gaa_games_away_club ON public.gaa_games (away_club_id);

-- One row per window load, so a failed night is easy to spot
CREATE TABLE IF NOT EXISTS public.gaa_sync_log (
  sync_id     bigserial PRIMARY KEY,
  mode        text NOT NULL,                       -- backfill | nightly | manual
  from_day    date NOT NULL,
  to_day      date NOT NULL,
  ok          boolean NOT NULL,
  games       int NOT NULL DEFAULT 0,
  seconds     numeric(7, 1),
  error       text,
  ran_at      timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS gaa_sync_log_window ON public.gaa_sync_log (from_day, ok);

-- Anyone may read (public fixture data); only the service role writes
ALTER TABLE public.gaa_clubs        ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.gaa_competitions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.gaa_games        ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.gaa_sync_log     ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS gaa_clubs_read ON public.gaa_clubs;
CREATE POLICY gaa_clubs_read ON public.gaa_clubs FOR SELECT TO anon, authenticated USING (true);
DROP POLICY IF EXISTS gaa_competitions_read ON public.gaa_competitions;
CREATE POLICY gaa_competitions_read ON public.gaa_competitions FOR SELECT TO anon, authenticated USING (true);
DROP POLICY IF EXISTS gaa_games_read ON public.gaa_games;
CREATE POLICY gaa_games_read ON public.gaa_games FOR SELECT TO anon, authenticated USING (true);

-- ── Clubs: the same aliases the fixtures page uses ───────────────────────────
CREATE OR REPLACE FUNCTION public.gaa_key(p text)
RETURNS text LANGUAGE sql IMMUTABLE AS $$
  SELECT regexp_replace(lower(coalesce(p, '')), '[^a-z0-9]', '', 'g');
$$;

INSERT INTO public.gaa_clubs (name, name_key, alias_keys, gaa_id, camogie_id, lgfa_id) VALUES
  ('Clontarf', 'clontarf', '{}', '3561', '40597', '5346'),
  ('St Brigids', 'stbrigids', ARRAY['naomhbrid'], NULL, NULL, NULL),
  ('St Judes', 'stjudes', ARRAY['naomhjude'], NULL, NULL, NULL),
  ('St Finbarrs', 'stfinbarrs', ARRAY['naomhfionnbarra'], NULL, NULL, NULL),
  ('St Catherines', 'stcatherines', ARRAY['naomhcaitriona'], NULL, NULL, NULL),
  ('Round Towers (L)', 'roundtowersl', ARRAY['roundtowerslusk'], NULL, NULL, NULL),
  ('Round Towers (C)', 'roundtowersc', ARRAY['roundtower', 'roundtowersclondalkin'], NULL, NULL, NULL),
  ('St Patricks Donabate', 'stpatricksdonabate', ARRAY['stpatsdonabate'], NULL, NULL, NULL),
  ('St Kevins', 'stkevins', ARRAY['kevins'], NULL, NULL, NULL)
ON CONFLICT (name_key) DO NOTHING;

-- Club for a listed name, created on first sight; remembers the organisation's club ID
CREATE OR REPLACE FUNCTION public.gaa_club_for(p_name text, p_org text, p_source_id text)
RETURNS int
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = 'public'
AS $$
DECLARE
  v_key text := public.gaa_key(p_name);
  v_id  int;
BEGIN
  IF v_key = '' THEN RETURN NULL; END IF;
  SELECT club_id INTO v_id FROM public.gaa_clubs WHERE name_key = v_key OR v_key = ANY (alias_keys) LIMIT 1;
  IF v_id IS NULL THEN
    INSERT INTO public.gaa_clubs (name, name_key) VALUES (trim(p_name), v_key)
    ON CONFLICT (name_key) DO UPDATE SET name = public.gaa_clubs.name
    RETURNING club_id INTO v_id;
  END IF;
  IF coalesce(p_source_id, '') <> '' THEN
    UPDATE public.gaa_clubs SET
      gaa_id     = CASE WHEN p_org = 'gaa'     AND gaa_id     IS NULL THEN p_source_id ELSE gaa_id END,
      camogie_id = CASE WHEN p_org = 'camogie' AND camogie_id IS NULL THEN p_source_id ELSE camogie_id END,
      lgfa_id    = CASE WHEN p_org = 'lgfa'    AND lgfa_id    IS NULL THEN p_source_id ELSE lgfa_id END
    WHERE club_id = v_id;
  END IF;
  RETURN v_id;
END;
$$;
REVOKE ALL ON FUNCTION public.gaa_club_for(text, text, text) FROM PUBLIC, anon, authenticated;

-- ── Load one window ──────────────────────────────────────────────────────────
-- Replaces every game of the given codes between two Dublin days with the
-- games given, so moved or cancelled fixtures don't linger. Called by gaa-sync
-- only after every source for the window loaded without error.
-- p_games: [{compId, comp, code, age, grade, level, start, home, away, homeClub,
--            awayClub, homeClubId, awayClubId, org, status, hs, as, hp, ap,
--            venue, referee, note}]
CREATE OR REPLACE FUNCTION public.gaa_replace_window(p_from date, p_to date, p_codes text[], p_games jsonb)
RETURNS int
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = 'public'
AS $$
DECLARE
  v_n int;
BEGIN
  INSERT INTO public.gaa_competitions (comp_id, name, code, age, grade, level, season, updated_at)
  SELECT DISTINCT ON (g->>'compId') g->>'compId', g->>'comp', g->>'code', g->>'age', coalesce(g->>'grade', ''),
         g->>'level', extract(year FROM (g->>'start')::timestamptz AT TIME ZONE 'Europe/Dublin')::int, now()
  FROM jsonb_array_elements(p_games) g
  ORDER BY g->>'compId'
  ON CONFLICT (comp_id) DO UPDATE
    SET name = EXCLUDED.name, code = EXCLUDED.code, age = EXCLUDED.age,
        grade = EXCLUDED.grade, level = EXCLUDED.level, updated_at = now();

  DELETE FROM public.gaa_games
   WHERE code = ANY (p_codes)
     AND (start_at AT TIME ZONE 'Europe/Dublin')::date BETWEEN p_from AND p_to;

  INSERT INTO public.gaa_games (comp_id, code, start_at, home_team, away_team, home_club_id, away_club_id,
                                status, home_score, away_score, home_pts, away_pts, venue, referee, note)
  SELECT g->>'compId', g->>'code', (g->>'start')::timestamptz, g->>'home', g->>'away',
         public.gaa_club_for(g->>'homeClub', g->>'org', g->>'homeClubId'),
         public.gaa_club_for(g->>'awayClub', g->>'org', g->>'awayClubId'),
         g->>'status', coalesce(g->>'hs', ''), coalesce(g->>'as', ''),
         (g->>'hp')::int, (g->>'ap')::int,
         coalesce(g->>'venue', ''), coalesce(g->>'referee', ''), coalesce(g->>'note', '')
  FROM jsonb_array_elements(p_games) g
  ON CONFLICT (comp_id, home_team, away_team, start_at) DO UPDATE
    SET status = EXCLUDED.status, home_score = EXCLUDED.home_score, away_score = EXCLUDED.away_score,
        home_pts = EXCLUDED.home_pts, away_pts = EXCLUDED.away_pts, venue = EXCLUDED.venue,
        referee = EXCLUDED.referee, note = EXCLUDED.note, synced_at = now();
  GET DIAGNOSTICS v_n = ROW_COUNT;
  RETURN v_n;
END;
$$;
REVOKE ALL ON FUNCTION public.gaa_replace_window(date, date, text[], jsonb) FROM PUBLIC, anon, authenticated;

-- ── Schedule ─────────────────────────────────────────────────────────────────
-- Wakes gaa-sync with a short-lived service-role token signed from the vault
-- secret (same pattern as the live match alerts).
CREATE OR REPLACE FUNCTION public.gaa_sync_wake(p_mode text, p_part int DEFAULT 0)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = 'public'
AS $$
DECLARE
  v_secret text;
  v_jwt    text;
BEGIN
  SELECT decrypted_secret INTO v_secret FROM vault.decrypted_secrets WHERE name = 'jwt_signing_secret' LIMIT 1;
  IF v_secret IS NULL THEN
    RAISE WARNING 'gaa_sync_wake: jwt_signing_secret not found in vault';
    RETURN;
  END IF;
  SELECT extensions.sign(json_build_object(
           'role', 'service_role', 'iss', 'supabase', 'ref', 'gyfporsbdftvtakdvukt',
           'iat', extract(epoch from now())::integer, 'exp', (extract(epoch from now()) + 900)::integer
         )::json, v_secret) INTO v_jwt;
  PERFORM net.http_post(
    url     := 'https://gyfporsbdftvtakdvukt.supabase.co/functions/v1/gaa-sync',
    headers := jsonb_build_object('Content-Type', 'application/json', 'Authorization', 'Bearer ' || v_jwt),
    body    := jsonb_build_object('mode', p_mode, 'part', p_part),
    timeout_milliseconds := 300000
  );
END;
$$;
REVOKE ALL ON FUNCTION public.gaa_sync_wake(text, int) FROM PUBLIC, anon, authenticated;

DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'pg_cron') THEN
    PERFORM cron.unschedule(jobname) FROM cron.job WHERE jobname LIKE 'gaa-season-%';
    PERFORM cron.schedule('gaa-season-backfill', '*/10 * * * *', $c$SELECT public.gaa_sync_wake('backfill')$c$);
    -- Last two weeks, next two weeks, the two weeks after: one window each, five minutes apart
    PERFORM cron.schedule('gaa-season-nightly-0', '15 4 * * *', $c$SELECT public.gaa_sync_wake('nightly', 0)$c$);
    PERFORM cron.schedule('gaa-season-nightly-1', '20 4 * * *', $c$SELECT public.gaa_sync_wake('nightly', 1)$c$);
    PERFORM cron.schedule('gaa-season-nightly-2', '25 4 * * *', $c$SELECT public.gaa_sync_wake('nightly', 2)$c$);
  END IF;
END;
$$;
