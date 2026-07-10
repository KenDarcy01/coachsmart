-- Convert comma-delimited text columns on games table to proper text[] arrays.
-- Replaces btree indexes with GIN indexes for efficient @> (contains) queries.
-- After this migration, FlutterFlow's cs filter works directly:
--   game_age cs {Under 14}
-- No RPC wrapper needed.

-- Drop existing btree indexes on the columns being converted
DROP INDEX IF EXISTS "public"."idx_games_game_age";
DROP INDEX IF EXISTS "public"."idx_games_game_type";

-- Convert game_age, game_type, game_skill to text[]
-- Trims whitespace around each value; preserves NULL for null/empty input.
ALTER TABLE "public"."games"
  ALTER COLUMN "game_age" TYPE text[]
    USING (
      CASE
        WHEN game_age IS NULL OR trim(game_age) = '' THEN NULL
        ELSE ARRAY(
          SELECT trim(item)
          FROM unnest(string_to_array(game_age, ',')) AS item
          WHERE trim(item) != ''
        )
      END
    ),
  ALTER COLUMN "game_type" TYPE text[]
    USING (
      CASE
        WHEN game_type IS NULL OR trim(game_type) = '' THEN NULL
        ELSE ARRAY(
          SELECT trim(item)
          FROM unnest(string_to_array(game_type, ',')) AS item
          WHERE trim(item) != ''
        )
      END
    ),
  ALTER COLUMN "game_skill" TYPE text[]
    USING (
      CASE
        WHEN game_skill IS NULL OR trim(game_skill) = '' THEN NULL
        ELSE ARRAY(
          SELECT trim(item)
          FROM unnest(string_to_array(game_skill, ',')) AS item
          WHERE trim(item) != ''
        )
      END
    );

-- GIN indexes support @>, &&, and <@ operators on array columns
CREATE INDEX "idx_games_game_age"  ON "public"."games" USING gin ("game_age");
CREATE INDEX "idx_games_game_type" ON "public"."games" USING gin ("game_type");
CREATE INDEX "idx_games_game_skill" ON "public"."games" USING gin ("game_skill");
