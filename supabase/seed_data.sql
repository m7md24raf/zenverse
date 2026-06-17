-- Zenverse seed/test data
-- Idempotent inserts for local/dev testing.
-- Uses generated UUIDs and includes auth.users bootstrap so profile FKs are valid.

create extension if not exists "pgcrypto";

with seed_users as (
  select gen_random_uuid() as id, 'alex.chen@zenverse.dev'::text as email, 'Alex Chen'::text as display_name, 42::int as level, 14::int as streak_count, 1800::int as xp_session, 950::int as xp_games, 3::int as freeze_credits
  union all
  select gen_random_uuid(), 'mila.chen@zenverse.dev', 'Mila Chen', 35, 9, 1320, 740, 2
  union all
  select gen_random_uuid(), 'jordan.smith@zenverse.dev', 'Jordan Smith', 28, 6, 980, 510, 1
  union all
  select gen_random_uuid(), 'nora.ali@zenverse.dev', 'Nora Ali', 18, 4, 620, 340, 1
  union all
  select gen_random_uuid(), 'liam.rivera@zenverse.dev', 'Liam Rivera', 11, 2, 300, 180, 0
)
insert into auth.users (
  id,
  aud,
  role,
  email,
  encrypted_password,
  email_confirmed_at,
  raw_app_meta_data,
  raw_user_meta_data,
  is_sso_user,
  is_anonymous,
  created_at,
  updated_at
)
select
  su.id,
  'authenticated',
  'authenticated',
  su.email,
  crypt('password123', gen_salt('bf')),
  now(),
  '{"provider":"email","providers":["email"]}'::jsonb,
  jsonb_build_object('seeded', true, 'name', su.display_name),
  false,
  false,
  now(),
  now()
from seed_users su
on conflict (id) do nothing;

with src as (
  select
    u.id,
    u.email,
    case
      when u.email = 'alex.chen@zenverse.dev' then 'Alex Chen'
      when u.email = 'mila.chen@zenverse.dev' then 'Mila Chen'
      when u.email = 'jordan.smith@zenverse.dev' then 'Jordan Smith'
      when u.email = 'nora.ali@zenverse.dev' then 'Nora Ali'
      else 'Liam Rivera'
    end as display_name,
    case
      when u.email = 'alex.chen@zenverse.dev' then 42
      when u.email = 'mila.chen@zenverse.dev' then 35
      when u.email = 'jordan.smith@zenverse.dev' then 28
      when u.email = 'nora.ali@zenverse.dev' then 18
      else 11
    end as level,
    case
      when u.email = 'alex.chen@zenverse.dev' then 14
      when u.email = 'mila.chen@zenverse.dev' then 9
      when u.email = 'jordan.smith@zenverse.dev' then 6
      when u.email = 'nora.ali@zenverse.dev' then 4
      else 2
    end as streak_count,
    case
      when u.email = 'alex.chen@zenverse.dev' then 1800
      when u.email = 'mila.chen@zenverse.dev' then 1320
      when u.email = 'jordan.smith@zenverse.dev' then 980
      when u.email = 'nora.ali@zenverse.dev' then 620
      else 300
    end as xp_session,
    case
      when u.email = 'alex.chen@zenverse.dev' then 950
      when u.email = 'mila.chen@zenverse.dev' then 740
      when u.email = 'jordan.smith@zenverse.dev' then 510
      when u.email = 'nora.ali@zenverse.dev' then 340
      else 180
    end as xp_games,
    case
      when u.email = 'alex.chen@zenverse.dev' then 3
      when u.email = 'mila.chen@zenverse.dev' then 2
      when u.email = 'jordan.smith@zenverse.dev' then 1
      when u.email = 'nora.ali@zenverse.dev' then 1
      else 0
    end as freeze_credits
  from auth.users u
  where u.email in (
    'alex.chen@zenverse.dev',
    'mila.chen@zenverse.dev',
    'jordan.smith@zenverse.dev',
    'nora.ali@zenverse.dev',
    'liam.rivera@zenverse.dev'
  )
)
insert into public.profiles (
  id,
  user_code,
  display_name,
  level,
  xp_session,
  xp_games,
  streak_count,
  freeze_credits,
  timezone,
  daily_goal_sessions
)
select
  s.id,
  'ZEN-' || upper(substr(md5(s.email), 1, 6)),
  s.display_name,
  s.level,
  s.xp_session,
  s.xp_games,
  s.streak_count,
  s.freeze_credits,
  'UTC',
  2
from src s
on conflict (id) do nothing;

insert into public.friendships (id, requester_id, addressee_id, status, requested_at, responded_at)
select gen_random_uuid(), p1.id, p2.id, 'accepted'::public.friendship_status, now() - interval '14 days', now() - interval '13 days'
from public.profiles p1
join public.profiles p2 on p1.display_name = 'Alex Chen' and p2.display_name = 'Mila Chen'
on conflict do nothing;

insert into public.friendships (id, requester_id, addressee_id, status, requested_at, responded_at)
select gen_random_uuid(), p1.id, p2.id, 'accepted'::public.friendship_status, now() - interval '10 days', now() - interval '9 days'
from public.profiles p1
join public.profiles p2 on p1.display_name = 'Alex Chen' and p2.display_name = 'Jordan Smith'
on conflict do nothing;

insert into public.friendships (id, requester_id, addressee_id, status, requested_at, responded_at)
select gen_random_uuid(), p1.id, p2.id, 'pending'::public.friendship_status, now() - interval '1 day', null
from public.profiles p1
join public.profiles p2 on p1.display_name = 'Nora Ali' and p2.display_name = 'Liam Rivera'
on conflict do nothing;

insert into public.sessions (
  id,
  user_id,
  planet_id,
  mode,
  status,
  start_time,
  end_time,
  target_duration_seconds,
  points_earned,
  gave_up_at,
  freeze_hours
)
select
  gen_random_uuid(),
  p.id,
  pl.id,
  'hard'::public.focus_mode,
  'complete'::public.session_status,
  now() - interval '3 days' + interval '8 hours',
  now() - interval '3 days' + interval '8 hours 45 minutes',
  2700,
  90,
  null,
  null
from public.profiles p
left join public.planets pl on pl.slug = 'earth'
where p.display_name = 'Alex Chen'
on conflict (id) do nothing;

insert into public.sessions (
  id,
  user_id,
  planet_id,
  mode,
  status,
  start_time,
  end_time,
  target_duration_seconds,
  points_earned,
  gave_up_at,
  freeze_hours
)
select
  gen_random_uuid(),
  p.id,
  pl.id,
  'medium'::public.focus_mode,
  'given_up'::public.session_status,
  now() - interval '2 days' + interval '15 hours',
  now() - interval '2 days' + interval '15 hours 20 minutes',
  3600,
  0,
  now() - interval '2 days' + interval '15 hours 20 minutes',
  2
from public.profiles p
left join public.planets pl on pl.slug = 'mars'
where p.display_name = 'Mila Chen'
on conflict (id) do nothing;

insert into public.sessions (
  id,
  user_id,
  planet_id,
  mode,
  status,
  start_time,
  end_time,
  target_duration_seconds,
  points_earned,
  gave_up_at,
  freeze_hours
)
select
  gen_random_uuid(),
  p.id,
  pl.id,
  'easy'::public.focus_mode,
  'complete'::public.session_status,
  now() - interval '1 day' + interval '9 hours',
  now() - interval '1 day' + interval '9 hours 30 minutes',
  1800,
  55,
  null,
  null
from public.profiles p
left join public.planets pl on pl.slug = 'earth'
where p.display_name in ('Jordan Smith', 'Nora Ali', 'Liam Rivera')
on conflict (id) do nothing;

insert into public.session_participants (session_id, user_id)
select s.id, p.id
from public.sessions s
join public.profiles owner on owner.id = s.user_id and owner.display_name = 'Alex Chen'
join public.profiles p on p.display_name in ('Mila Chen', 'Jordan Smith')
where s.start_time > now() - interval '7 days'
on conflict (session_id, user_id) do nothing;

insert into public.messages (id, sender_id, receiver_id, session_id, content, sent_at)
select
  gen_random_uuid(),
  sender.id,
  receiver.id,
  null,
  msg.content,
  now() - msg.offset
from (
  values
    ('Alex Chen', 'Mila Chen', 'Ready for a deep-work sprint at 2PM?', interval '6 hours'),
    ('Mila Chen', 'Alex Chen', 'Yes, invite me when you start.', interval '5 hours 55 minutes'),
    ('Alex Chen', 'Jordan Smith', 'How did your Mars session go?', interval '4 hours'),
    ('Jordan Smith', 'Alex Chen', 'Given up once, but back on track now.', interval '3 hours 50 minutes')
) as msg(sender_name, receiver_name, content, offset)
join public.profiles sender on sender.display_name = msg.sender_name
join public.profiles receiver on receiver.display_name = msg.receiver_name
on conflict (id) do nothing;

insert into public.message_receipts (id, message_id, user_id, read_at)
select gen_random_uuid(), m.id, m.receiver_id, m.sent_at + interval '10 minutes'
from public.messages m
where m.sent_at > now() - interval '2 days'
on conflict (message_id, user_id) do nothing;

insert into public.streak_daily (
  id,
  user_id,
  day,
  completed_sessions,
  goal_sessions,
  streak_after_day,
  was_protected_by_freeze
)
select
  gen_random_uuid(),
  p.id,
  d::date,
  case when p.display_name in ('Alex Chen', 'Mila Chen') then 2 else 1 end,
  1,
  greatest(1, p.streak_count - (current_date - d::date)),
  false
from public.profiles p
cross join generate_series(current_date - interval '4 days', current_date, interval '1 day') d
on conflict (user_id, day) do nothing;

insert into public.streak_freeze_logs (
  id,
  user_id,
  day,
  reason,
  credits_before,
  credits_after
)
select
  gen_random_uuid(),
  p.id,
  current_date - 2,
  'Protected streak after a given-up session',
  2,
  1
from public.profiles p
where p.display_name = 'Mila Chen'
on conflict (id) do nothing;

insert into public.notifications_schedule (
  id,
  user_id,
  label,
  reminder_time,
  duration_minutes,
  repeat_days,
  is_enabled,
  next_trigger_at
)
select gen_random_uuid(), p.id, 'Morning Focus', '08:30'::time, 30, array[1,2,3,4,5], true, now() + interval '1 day'
from public.profiles p
on conflict (id) do nothing;

insert into public.notifications_schedule (
  id,
  user_id,
  label,
  reminder_time,
  duration_minutes,
  repeat_days,
  is_enabled,
  next_trigger_at
)
select gen_random_uuid(), p.id, 'Deep Work 2PM', '14:00'::time, 45, array[1,2,3,4,5], true, now() + interval '4 hours'
from public.profiles p
where p.display_name in ('Alex Chen', 'Mila Chen')
on conflict (id) do nothing;

insert into public.user_purchases (id, user_id, item_id, purchased_at, price_paid_xp, source_wallet)
select
  gen_random_uuid(),
  p.id,
  si.id,
  now() - interval '7 days',
  si.price_xp,
  'xp_games'
from public.profiles p
join public.store_items si on si.slug in ('planet-mars', 'sound-lofi-orbit')
where p.display_name in ('Alex Chen', 'Mila Chen')
on conflict (user_id, item_id) do nothing;

insert into public.user_planets (id, user_id, planet_id, level, is_frozen, frozen_until, purchased_at)
select
  gen_random_uuid(),
  p.id,
  pl.id,
  case when pl.slug = 'earth' then 3 else 1 end,
  false,
  null,
  now() - interval '10 days'
from public.profiles p
join public.planets pl on pl.slug in ('earth', 'mars')
on conflict (user_id, planet_id) do nothing;

insert into public.sync_queue (
  id,
  user_id,
  client_action_id,
  action_type,
  entity_table,
  entity_id,
  payload,
  client_created_at,
  conflict_status,
  retries
)
select
  gen_random_uuid(),
  p.id,
  'seed-action-' || substr(md5(p.id::text), 1, 12),
  'create_session'::public.sync_action_type,
  'sessions',
  null,
  jsonb_build_object('note', 'seeded offline action', 'mode', 'medium'),
  now() - interval '2 hours',
  'pending'::public.sync_conflict_status,
  0
from public.profiles p
on conflict (user_id, client_action_id) do nothing;
