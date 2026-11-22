-- Development groups (Clontarf Girls 2012, Féile 2027).
--
-- After the superpower check-in the coaches put each girl in one or more
-- development groups for each code: Ball skills, Speed & power, Scoring,
-- Winning the ball. They are part of her card (one group per line, same as
-- Superpower), so they go through review and Publish like the rest of it.
-- The public diary never knows who is in which group: the girl reads her
-- groups on her card and taps the same ones in the diary herself.
alter table public.pc_assessments add column if not exists dev_groups text;
