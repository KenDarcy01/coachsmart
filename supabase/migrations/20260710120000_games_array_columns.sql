-- Convert comma-delimited text columns on games table to proper text[] arrays.
-- Replaces btree indexes with GIN indexes for efficient @> (contains) queries.
-- After this migration, FlutterFlow's cs filter works directly:
--   game_age cs {Under 14}
-- No RPC wrapper needed.

-- Drop view that depended on game_age as text (unused workaround for comma-delimited values)
DROP VIEW IF EXISTS "public"."view_game_age_expansion";

-- Drop existing btree indexes on the columns being converted
DROP INDEX IF EXISTS "public"."idx_games_game_age";
DROP INDEX IF EXISTS "public"."idx_games_game_type";

-- Convert game_age, game_type, game_skill to text[]
-- regexp_split_to_array splits on comma with optional surrounding whitespace.
-- Subqueries are not permitted in USING clauses; regexp functions are.
ALTER TABLE "public"."games"
  ALTER COLUMN "game_age" TYPE text[]
    USING (
      CASE
        WHEN game_age IS NULL OR trim(game_age) = '' THEN NULL
        ELSE regexp_split_to_array(trim(game_age), '\s*,\s*')
      END
    ),
  ALTER COLUMN "game_type" TYPE text[]
    USING (
      CASE
        WHEN game_type IS NULL OR trim(game_type) = '' THEN NULL
        ELSE regexp_split_to_array(trim(game_type), '\s*,\s*')
      END
    ),
  ALTER COLUMN "game_skill" TYPE text[]
    USING (
      CASE
        WHEN game_skill IS NULL OR trim(game_skill) = '' THEN NULL
        ELSE regexp_split_to_array(trim(game_skill), '\s*,\s*')
      END
    );

-- GIN indexes support @>, &&, and <@ operators on array columns
CREATE INDEX "idx_games_game_age"  ON "public"."games" USING gin ("game_age");
CREATE INDEX "idx_games_game_type" ON "public"."games" USING gin ("game_type");
CREATE INDEX "idx_games_game_skill" ON "public"."games" USING gin ("game_skill");
