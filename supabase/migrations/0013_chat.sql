-- Sparrow Staff Portal (System 2) — Internal Chat ("replace Signal use", brief §System 2)
-- Direct (1:1) and group messaging between staff, membership-gated by Row-Level Security.
-- Kept deliberately small for an ~8-person team: channels, members, messages — no threads,
-- reactions, or attachments in v1. Chat unread is tracked per-member (last_read_at) and is
-- intentionally SEPARATE from the task notification bell (0003), matching how Signal keeps
-- message unreads distinct from app notifications.
-- Run after the operations migration (number 0012).

-- ─── Enums ───────────────────────────────────────────────────────────
create type chat_channel_kind as enum ('direct', 'group');

-- ─── Tables ──────────────────────────────────────────────────────────
create table chat_channels (
  id              uuid primary key default gen_random_uuid(),
  kind            chat_channel_kind not null default 'direct',
  title           text,                          -- group name; null for direct (UI shows the other member)
  created_by      uuid references profiles(id) on delete set null,
  created_at      timestamptz not null default now(),
  last_message_at timestamptz not null default now()   -- conversation-list sort key; bumped by trigger
);

create table chat_members (
  channel_id   uuid not null references chat_channels(id) on delete cascade,
  user_id      uuid not null references profiles(id) on update cascade on delete cascade,
  last_read_at timestamptz not null default now(),     -- everything after this is "unread" for this member
  added_at     timestamptz not null default now(),
  primary key (channel_id, user_id)
);
create index chat_members_user_idx on chat_members(user_id);

create table chat_messages (
  id         uuid primary key default gen_random_uuid(),
  channel_id uuid not null references chat_channels(id) on delete cascade,
  author_id  uuid not null references profiles(id) on update cascade on delete cascade,
  body       text not null,
  created_at timestamptz not null default now()
);
create index chat_messages_channel_idx on chat_messages(channel_id, created_at);

-- ─── Membership helper (security definer → reads chat_members without RLS,
--     so the membership policies below don't recurse; same pattern as is_admin()) ──
create or replace function is_chat_member(p_channel uuid) returns boolean
  language sql security definer set search_path = public stable as $$
  select exists (
    select 1 from chat_members
    where channel_id = p_channel and user_id = auth.uid()
  );
$$;

-- ─── Bump last_message_at on each new message (definer → bypasses channel RLS) ──
create or replace function chat_bump_channel() returns trigger
  language plpgsql security definer set search_path = public as $$
begin
  update chat_channels set last_message_at = NEW.created_at where id = NEW.channel_id;
  return NEW;
end $$;

create trigger chat_message_bump after insert on chat_messages
  for each row execute function chat_bump_channel();

-- ─── Row-Level Security ──────────────────────────────────────────────
alter table chat_channels enable row level security;
alter table chat_members  enable row level security;
alter table chat_messages enable row level security;

-- Channels: you see only channels you belong to. Creation happens through the
-- SECURITY DEFINER RPCs below (so there is no client INSERT/UPDATE/DELETE policy —
-- a member cannot rename or delete a channel in v1; that is a future nicety).
create policy chat_channels_select on chat_channels
  for select to authenticated using (is_chat_member(id));

-- Members: visible to fellow members. The only client write is updating YOUR OWN
-- last_read_at (mark-as-read). Adding people is done by the definer RPCs.
create policy chat_members_select on chat_members
  for select to authenticated using (is_chat_member(channel_id));
create policy chat_members_update_own on chat_members
  for update to authenticated
  using (user_id = auth.uid()) with check (user_id = auth.uid());

-- Messages: read if you're in the channel; post as yourself into a channel you're in.
-- No update/delete in v1.
create policy chat_messages_select on chat_messages
  for select to authenticated using (is_chat_member(channel_id));
create policy chat_messages_insert on chat_messages
  for insert to authenticated
  with check (author_id = auth.uid() and is_chat_member(channel_id));

-- ─── Channel creation RPCs (definer: create channel + memberships atomically,
--     which a plain client INSERT can't do without opening a membership hole) ──

-- Open (or reuse) a 1:1 conversation with another staff member. Dedups so two
-- people never end up with parallel DM threads.
create or replace function chat_start_direct(p_other uuid) returns uuid
  language plpgsql security definer set search_path = public as $$
declare existing uuid; new_id uuid;
begin
  if p_other = auth.uid() then
    raise exception 'Cannot start a direct message with yourself';
  end if;
  if not exists (select 1 from profiles where id = p_other and active) then
    raise exception 'No such active staff member';
  end if;

  select c.id into existing
  from chat_channels c
  where c.kind = 'direct'
    and exists (select 1 from chat_members m where m.channel_id = c.id and m.user_id = auth.uid())
    and exists (select 1 from chat_members m where m.channel_id = c.id and m.user_id = p_other)
    and (select count(*) from chat_members m where m.channel_id = c.id) = 2
  limit 1;
  if existing is not null then
    return existing;
  end if;

  insert into chat_channels (kind, created_by) values ('direct', auth.uid())
  returning id into new_id;
  insert into chat_members (channel_id, user_id) values (new_id, auth.uid()), (new_id, p_other);
  return new_id;
end $$;

-- Create a named group with the given members (creator is always included).
create or replace function chat_create_group(p_title text, p_members uuid[]) returns uuid
  language plpgsql security definer set search_path = public as $$
declare new_id uuid; m uuid;
begin
  insert into chat_channels (kind, title, created_by)
  values ('group', nullif(trim(p_title), ''), auth.uid())
  returning id into new_id;

  insert into chat_members (channel_id, user_id) values (new_id, auth.uid());
  foreach m in array coalesce(p_members, '{}'::uuid[]) loop
    if m is distinct from auth.uid() and exists (select 1 from profiles where id = m and active) then
      insert into chat_members (channel_id, user_id) values (new_id, m)
      on conflict do nothing;
    end if;
  end loop;
  return new_id;
end $$;

-- One-shot conversation list for the signed-in user: each channel with its last
-- message preview, unread count (messages after my last_read_at, excluding my own),
-- and — for direct channels — the other member's identity for display.
create or replace function chat_list_conversations()
returns table (
  channel_id      uuid,
  kind            chat_channel_kind,
  title           text,
  last_message_at timestamptz,
  last_body       text,
  last_author_id  uuid,
  unread          int,
  other_id        uuid,
  other_name      text
)
  language sql security definer set search_path = public stable as $$
  select
    c.id,
    c.kind,
    c.title,
    c.last_message_at,
    lm.body,
    lm.author_id,
    coalesce((
      select count(*) from chat_messages msg
      where msg.channel_id = c.id
        and msg.created_at > me.last_read_at
        and msg.author_id <> auth.uid()
    ), 0)::int as unread,
    other.user_id,
    op.full_name
  from chat_members me
  join chat_channels c on c.id = me.channel_id
  left join lateral (
    select body, author_id from chat_messages msg
    where msg.channel_id = c.id
    order by msg.created_at desc
    limit 1
  ) lm on true
  left join lateral (
    select m2.user_id from chat_members m2
    where m2.channel_id = c.id and m2.user_id <> auth.uid()
    limit 1
  ) other on c.kind = 'direct'
  left join profiles op on op.id = other.user_id
  where me.user_id = auth.uid()
  order by c.last_message_at desc;
$$;

-- ─── Realtime ────────────────────────────────────────────────────────
-- Deliver new messages live (RLS still applies — a client only receives rows it
-- may SELECT). The client also polls as a fallback, so chat works even if this
-- publication line is skipped on a given Supabase project.
alter publication supabase_realtime add table chat_messages;
