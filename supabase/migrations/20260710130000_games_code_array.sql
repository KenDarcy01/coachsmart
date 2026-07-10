-- Convert game_code from text to text[], splitting on '/' delimiter.
-- e.g. 'Football/Hurling' -> '{Football,Hurling}'
-- Replaces btree index with GIN for array contains queries.
-- trim() also cleans up any trailing whitespace on existing values.
--
-- Idempotent: skips ALTER TABLE if game_code is already text[].

DROP INDEX IF EXISTS "public"."idx_games_game_code";

DO $$
DECLARE
  col_type text;
BEGIN
  SELECT data_type INTO col_type
  FROM information_schema.columns
  WHERE table_schema = 'public' AND table_name = 'games' AND column_name = 'game_code';

  IF col_type <> 'ARRAY' THEN
    EXECUTE $ddl$
      ALTER TABLE public.games
        ALTER COLUMN game_code TYPE text[]
          USING (
            CASE
              WHEN game_code IS NULL OR trim(game_code) = '' THEN NULL
              ELSE regexp_split_to_array(trim(game_code), '\s*/\s*')
            END
          )
    $ddl$;
    RAISE NOTICE 'game_code converted to text[]';
  ELSE
    RAISE NOTICE 'game_code already text[], skipping conversion';
  END IF;
END $$;

CREATE INDEX IF NOT EXISTS "idx_games_game_code" ON "public"."games" USING gin ("game_code");
