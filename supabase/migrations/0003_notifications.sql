-- Sparrow Staff Portal — notifications + announcements (System 2)
-- Completes the collaboration loop from Susanna's brief: a task assignment or a
-- comment notifies the right people; a slim announcement bar carries team notices.
-- Run AFTER 0001_init.sql. Notifications are created by SECURITY DEFINER triggers
-- (not by clients), so they can't be spoofed.

-- ─── Announcements ───────────────────────────────────────────────────
create table if not exists announcements (
  id         uuid primary key default gen_random_uuid(),
  body       text not null,
  created_by uuid references profiles(id) on delete set null,
  active     boolean not null default true,
  created_at timestamptz not null default now()
);

alter table announcements enable row level security;
-- Everyone signed in sees announcements; only admins post/edit/dismiss.
create policy announcements_select on announcements
  for select to authenticated using (true);
create policy announcements_admin on announcements
  for all to authenticated using (is_admin()) with check (is_admin());

-- ─── Notifications ───────────────────────────────────────────────────
DO $$ BEGIN
  CREATE TYPE notification_type AS ENUM ('assigned', 'commented');
EXCEPTION WHEN duplicate_object THEN null;
END $$;

create table if not exists notifications (
  id         uuid primary key default gen_random_uuid(),
  user_id    uuid not null references profiles(id) on delete cascade,   -- recipient
  actor_id   uuid references profiles(id) on update cascade on delete set null,
  type       notification_type not null,
  task_id    uuid references tasks(id) on delete cascade,
  body       text,                                                       -- snapshot (task title)
  read       boolean not null default false,
  created_at timestamptz not null default now()
);
create index if not exists notifications_user_idx on notifications(user_id, read);

alter table notifications enable row level security;
-- You only ever see / update / clear your own. No INSERT policy: only the
-- definer triggers below create notifications.
create policy notifications_select on notifications
  for select to authenticated using (user_id = auth.uid());
create policy notifications_update on notifications
  for update to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid());
create policy notifications_delete on notifications
  for delete to authenticated using (user_id = auth.uid());

-- ─── Triggers that create notifications ──────────────────────────────
-- Assignment: on new task (actor = creator) or reassignment (actor = the editor),
-- notify the assignee unless they did it themselves.
create or replace function notify_task_assignment() returns trigger
  language plpgsql security definer set search_path = public as $$
declare actor uuid;
begin
  if TG_OP = 'INSERT' then
    actor := NEW.created_by;
  elsif NEW.assignee_id is distinct from OLD.assignee_id then
    actor := auth.uid();
  else
    return NEW; -- assignee unchanged on update
  end if;

  if NEW.assignee_id is distinct from actor then
    insert into notifications (user_id, actor_id, type, task_id, body)
    values (NEW.assignee_id, actor, 'assigned', NEW.id, NEW.title);
  end if;
  return NEW;
end $$;

create trigger task_assignment_notify
  after insert or update on tasks
  for each row execute function notify_task_assignment();

-- Comment: notify the task's assignee and creator (except the comment's author).
create or replace function notify_comment() returns trigger
  language plpgsql security definer set search_path = public as $$
declare t record;
begin
  select assignee_id, created_by, title into t from tasks where id = NEW.task_id;

  if t.assignee_id is distinct from NEW.author_id then
    insert into notifications (user_id, actor_id, type, task_id, body)
    values (t.assignee_id, NEW.author_id, 'commented', NEW.task_id, t.title);
  end if;

  if t.created_by is distinct from NEW.author_id and t.created_by is distinct from t.assignee_id then
    insert into notifications (user_id, actor_id, type, task_id, body)
    values (t.created_by, NEW.author_id, 'commented', NEW.task_id, t.title);
  end if;

  return NEW;
end $$;

create trigger comment_notify
  after insert on task_comments
  for each row execute function notify_comment();
