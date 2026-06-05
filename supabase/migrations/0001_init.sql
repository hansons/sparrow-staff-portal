-- Sparrow Staff Portal (System 2) — Slice 1 schema
-- Personal task system + role-based visibility, enforced by Row-Level Security.
-- Run this in the Supabase SQL editor (or `supabase db push`), then run seed.sql.

-- ─── Enums ───────────────────────────────────────────────────────────
create type app_role    as enum ('admin', 'manager', 'staff');
create type department  as enum ('toc', 'lcp', 'partnerships', 'ops', 'exec');
create type priority    as enum ('p1', 'p2', 'p3', 'p4');
create type task_status as enum ('todo', 'in_progress', 'done');

-- ─── Tables ──────────────────────────────────────────────────────────
-- profiles.id equals the user's auth.users id once they sign in (linked by the
-- handle_new_user trigger below). We intentionally do NOT hard-FK to auth.users
-- so staff can be pre-seeded (as the allowlist) before anyone logs in.
create table profiles (
  id            uuid primary key default gen_random_uuid(),
  email         text unique not null,
  full_name     text not null,
  role          app_role not null default 'staff',
  department    department not null default 'ops',
  manager_email text,                       -- org chart: who this person reports to
  active        boolean not null default true,
  created_at    timestamptz not null default now()
);

create table tasks (
  id          uuid primary key default gen_random_uuid(),
  title       text not null,
  notes       text,
  due_date    date,
  department  department not null default 'ops',
  priority    priority not null default 'p3',
  status      task_status not null default 'todo',
  assignee_id uuid not null references profiles(id) on update cascade on delete cascade,
  created_by  uuid not null references profiles(id) on update cascade on delete cascade,
  position    double precision not null default 0,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);
create index tasks_assignee_idx on tasks(assignee_id);
create index tasks_created_by_idx on tasks(created_by);

create table task_comments (
  id         uuid primary key default gen_random_uuid(),
  task_id    uuid not null references tasks(id) on delete cascade,
  author_id  uuid not null references profiles(id) on update cascade on delete cascade,
  body       text not null,
  created_at timestamptz not null default now()
);
create index task_comments_task_idx on task_comments(task_id);

-- keep tasks.updated_at fresh
create or replace function set_updated_at() returns trigger
  language plpgsql as $$
begin
  new.updated_at = now();
  return new;
end $$;
create trigger tasks_updated_at before update on tasks
  for each row execute function set_updated_at();

-- ─── Permission helpers (security definer so they can read profiles) ──
create or replace function is_admin() returns boolean
  language sql security definer set search_path = public stable as $$
  select exists (select 1 from profiles where id = auth.uid() and role = 'admin');
$$;

-- true when the current user is the manager (by email) of the target profile
create or replace function manages(target uuid) returns boolean
  language sql security definer set search_path = public stable as $$
  select exists (
    select 1
    from profiles me
    join profiles t on t.id = target
    where me.id = auth.uid()
      and t.manager_email is not null
      and lower(t.manager_email) = lower(me.email)
  );
$$;

-- ─── Sign-in linking + roster allowlist ──────────────────────────────
-- On first Google sign-in: if the email matches a pre-seeded staff profile,
-- link that profile to the new auth user (id becomes the auth uid, cascading to
-- tasks). If the email is NOT on the roster, reject the sign-in.
create or replace function handle_new_user() returns trigger
  language plpgsql security definer set search_path = public as $$
begin
  if new.email is null then
    raise exception 'No email on account';
  end if;

  update profiles set id = new.id, active = true
  where lower(email) = lower(new.email);

  if not found then
    raise exception 'Email % is not on the Sparrow staff roster', new.email;
  end if;

  return new;
end $$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function handle_new_user();

-- ─── Row-Level Security ──────────────────────────────────────────────
alter table profiles      enable row level security;
alter table tasks         enable row level security;
alter table task_comments enable row level security;

-- profiles: every signed-in staff member can read the directory; edit self, admin edits anyone
create policy profiles_select on profiles
  for select to authenticated using (true);
create policy profiles_update_self on profiles
  for update to authenticated using (id = auth.uid() or is_admin()) with check (id = auth.uid() or is_admin());

-- tasks: see your own, ones you assigned, your reports' (if manager), or everything (admin)
create policy tasks_select on tasks
  for select to authenticated using (
    assignee_id = auth.uid()
    or created_by = auth.uid()
    or manages(assignee_id)
    or is_admin()
  );
create policy tasks_insert on tasks
  for insert to authenticated with check (created_by = auth.uid());
create policy tasks_update on tasks
  for update to authenticated using (
    created_by = auth.uid() or assignee_id = auth.uid() or manages(assignee_id) or is_admin()
  ) with check (
    created_by = auth.uid() or assignee_id = auth.uid() or manages(assignee_id) or is_admin()
  );
create policy tasks_delete on tasks
  for delete to authenticated using (created_by = auth.uid() or is_admin());

-- comments follow the visibility of their parent task
create policy task_comments_select on task_comments
  for select to authenticated using (
    exists (select 1 from tasks t where t.id = task_id)  -- RLS on tasks already filters visibility
  );
create policy task_comments_insert on task_comments
  for insert to authenticated with check (
    author_id = auth.uid()
    and exists (select 1 from tasks t where t.id = task_id)
  );
