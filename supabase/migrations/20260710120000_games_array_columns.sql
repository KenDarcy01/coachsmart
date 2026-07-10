-- Convert comma-delimited text columns on games table to proper text[] arrays.
-- Replaces btree indexes with GIN indexes for efficient @> (contains) queries.
-- After this migration, FlutterFlow's cs filter works directly:
--   game_age cs {Under 14}
-- No RPC wrapper needed.
--
-- Idempotent: skips ALTER TABLE if game_age is already text[].

-- Drop view that depended on game_age as text (unused workaround for comma-delimited values)
DROP VIEW IF EXISTS "public"."view_game_age_expansion";

-- Drop existing btree indexes on the columns being converted
DROP INDEX IF EXISTS "public"."idx_games_game_age";
DROP INDEX IF EXISTS "public"."idx_games_game_type";

-- Convert game_age, game_type, game_skill to text[] only if still text.
-- regexp_split_to_array splits on comma with optional surrounding whitespace.
-- Wrapped in DO block so re-running after a manual apply does not error.
DO $$
DECLARE
  col_type text;
BEGIN
  SELECT data_type INTO col_type
  FROM information_schema.columns
  WHERE table_schema = 'public' AND table_name = 'games' AND column_name = 'game_age';

  IF col_type <> 'ARRAY' THEN
    EXECUTE $ddl$
      ALTER TABLE public.games
        ALTER COLUMN game_age TYPE text[]
          USING (
            CASE
              WHEN game_age IS NULL OR trim(game_age) = '' THEN NULL
              ELSE regexp_split_to_array(trim(game_age), '\s*,\s*')
            END
          ),
        ALTER COLUMN game_type TYPE text[]
          USING (
            CASE
              WHEN game_type IS NULL OR trim(game_type) = '' THEN NULL
              ELSE regexp_split_to_array(trim(game_type), '\s*,\s*')
            END
          ),
        ALTER COLUMN game_skill TYPE text[]
          USING (
            CASE
              WHEN game_skill IS NULL OR trim(game_skill) = '' THEN NULL
              ELSE regexp_split_to_array(trim(game_skill), '\s*,\s*')
            END
          )
    $ddl$;
    RAISE NOTICE 'game_age/game_type/game_skill converted to text[]';
  ELSE
    RAISE NOTICE 'game_age already text[], skipping conversion';
  END IF;
END $$;

-- GIN indexes support @>, &&, and <@ operators on array columns
CREATE INDEX IF NOT EXISTS "idx_games_game_age"  ON "public"."games" USING gin ("game_age");
CREATE INDEX IF NOT EXISTS "idx_games_game_type" ON "public"."games" USING gin ("game_type");
CREATE INDEX IF NOT EXISTS "idx_games_game_skill" ON "public"."games" USING gin ("game_skill");
