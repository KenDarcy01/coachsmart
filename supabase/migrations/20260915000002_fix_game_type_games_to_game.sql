-- Normalise game_type array: replace 'Games' with 'Game' on all rows
UPDATE public.games
SET game_type = array_replace(game_type, 'Games', 'Game')
WHERE 'Games' = ANY(game_type);
