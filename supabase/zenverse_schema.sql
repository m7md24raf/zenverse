-- Zenverse incremental schema changes only
-- This file is intended to run on top of an existing base schema.

-- =========================
-- Profile onboarding preferences (timezone, sessions goal, preset avatar label)
-- =========================
alter table if exists public.profiles
  add column if not exists timezone text;

alter table if exists public.profiles
  add column if not exists daily_goal_sessions integer;

alter table if exists public.profiles
  add column if not exists avatar_url text;

-- =========================
-- Profile XP split additions
-- =========================
alter table if exists public.profiles
  add column if not exists xp_session integer not null default 0;

alter table if exists public.profiles
  add column if not exists xp_games integer not null default 0;

-- =========================
-- Additional indexes added later
-- =========================
create index if not exists profiles_xp_session_idx on public.profiles (xp_session desc);
create index if not exists profiles_xp_games_idx on public.profiles (xp_games desc);

-- =========================
-- Realtime additions
-- =========================
do $$
begin
  begin
    alter publication supabase_realtime add table public.messages;
  exception
    when duplicate_object then null;
    when undefined_table then null;
  end;

  begin
    alter publication supabase_realtime add table public.session_participants;
  exception
    when duplicate_object then null;
    when undefined_table then null;
  end;
end
$$;

-- =========================
-- Friends: profile lookup + RLS (required for friend code search)
-- Run this block in Supabase SQL Editor if friend search returns no results.
-- =========================
create or replace function public.find_profile_by_user_code(p_code text)
returns json
language plpgsql
security definer
set search_path = public
as $$
declare
  result json;
  normalized text;
begin
  normalized := upper(trim(replace(p_code, ' ', '')));
  if normalized = '' then
    return null;
  end if;
  if left(normalized, 4) <> 'ZEN-' then
    normalized := 'ZEN-' || normalized;
  end if;

  select json_build_object(
    'id', id,
    'display_name', display_name,
    'user_code', user_code,
    'avatar_url', avatar_url
  )
  into result
  from public.profiles
  where upper(user_code) = normalized
  limit 1;

  return result;
end;
$$;

grant execute on function public.find_profile_by_user_code(text) to authenticated;

-- Optional: sync purchased music track IDs from the app (run if using Supabase music sync).
alter table if exists public.profiles
  add column if not exists music_unlocks text[] default '{}';

alter table if exists public.profiles enable row level security;

drop policy if exists profiles_select_authenticated on public.profiles;
create policy profiles_select_authenticated
  on public.profiles for select
  to authenticated
  using (true);

drop policy if exists profiles_insert_own on public.profiles;
create policy profiles_insert_own
  on public.profiles for insert
  to authenticated
  with check (auth.uid() = id);

drop policy if exists profiles_update_own on public.profiles;
create policy profiles_update_own
  on public.profiles for update
  to authenticated
  using (auth.uid() = id)
  with check (auth.uid() = id);

alter table if exists public.friendships enable row level security;

drop policy if exists friendships_select_participant on public.friendships;
create policy friendships_select_participant
  on public.friendships for select
  to authenticated
  using (auth.uid() = requester_id or auth.uid() = addressee_id);

drop policy if exists friendships_insert_requester on public.friendships;
create policy friendships_insert_requester
  on public.friendships for insert
  to authenticated
  with check (auth.uid() = requester_id);

drop policy if exists friendships_update_participant on public.friendships;
create policy friendships_update_participant
  on public.friendships for update
  to authenticated
  using (auth.uid() = requester_id or auth.uid() = addressee_id);
