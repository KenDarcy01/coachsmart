-- Convert game_code from text to text[], splitting on '/' delimiter.
-- e.g. 'Football/Hurling' -> '{Football,Hurling}'
-- Replaces btree index with GIN for array contains queries.
-- trim() also cleans up any trailing whitespace on existing values.

DROP INDEX IF EXISTS "public"."idx_games_game_code";

ALTER TABLE "public"."games"
  ALTER COLUMN "game_code" TYPE text[]
    USING (
      CASE
        WHEN game_code IS NULL OR trim(game_code) = '' THEN NULL
        ELSE regexp_split_to_array(trim(game_code), '\s*/\s*')
      END
    );

CREATE INDEX "idx_games_game_code" ON "public"."games" USING gin ("game_code");
