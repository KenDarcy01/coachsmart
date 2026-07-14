-- Add position column to user_game_link for drag-to-reorder ordering.
-- Defaults to 0 for existing rows; app sets correct values on reorder.
alter table public.user_game_link
  add column if not exists position integer not null default 0;

-- Returns the current user's favourited games joined with game details.
-- Called on MyPlan page load. Uses auth.uid() so users can only ever
-- see their own favourites.
create or replace function public.get_user_favourites()
returns table (
  link_id   bigint,
  game_id   bigint,
  game_name text,
  game_image text,
  game_skill text,
  position  integer
)
language plpgsql
security definer
set search_path = 'public'
as $$
begin
  return query
  select
    ugl.id                                    as link_id,
    g.game_id,
    g.game_name,
    g.game_image,
    array_to_string(g.game_skill, ', ')       as game_skill,
    ugl.position
  from public.user_game_link ugl
  join public.games g on g.game_id = ugl.game_id
  where ugl.user_id = auth.uid()
  order by ugl.position asc, ugl.created_at asc;
end;
$$;
