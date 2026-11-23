-- Monyreach Multiplayer: enforce a maximum of 10 players per room.
-- Run this once in Supabase SQL Editor after the existing game_rooms/game_players tables exist.

create or replace function public.enforce_game_room_player_limit()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  current_count integer;
  room_status text;
begin
  -- Serialize simultaneous joins to the same room so the limit cannot be exceeded.
  perform pg_advisory_xact_lock(hashtextextended(new.room_id::text, 0));

  select status into room_status
  from public.game_rooms
  where id = new.room_id;

  if not found then
    raise exception 'Room does not exist';
  end if;

  if room_status <> 'waiting' then
    raise exception 'Room is not accepting players';
  end if;

  select count(*) into current_count
  from public.game_players
  where room_id = new.room_id;

  if current_count >= 10 then
    raise exception 'Room is full (maximum 10 players)';
  end if;

  return new;
end;
$$;

drop trigger if exists game_players_limit_10 on public.game_players;
create trigger game_players_limit_10
before insert on public.game_players
for each row execute function public.enforce_game_room_player_limit();
