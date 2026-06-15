-- Sparrow Staff Portal (System 2) — Operations Room
-- Susanna + Andrew's staff-management space. Access tier ("ops_access") = the three
-- people who manage staff: Andrew, Susanna, Shelly (set in seed_operations.sql).
--   • Staff management — notes + documents per staff member
--   • Issue log        — sensitive HR concerns (same tier; never visible to the subject)
--   • Touchpoint tracker — 1:1 log → "last met X days ago"
--   • Performance reviews — schedule + completion record
--   • Onboarding / Offboarding — per-staff checklists (provision / decommission)
-- Run AFTER 0011_partner_address.sql, then run seed_operations.sql.
--
-- Every FK to profiles uses ON UPDATE CASCADE — the sign-in trigger rewrites profiles.id
-- to the auth user id on first sign-in, and that must propagate (see 0007).

-- ─── Access tier ─────────────────────────────────────────────────────
alter table profiles add column ops_access boolean not null default false;

create or replace function has_ops_access() returns boolean
  language sql security definer set search_path = public stable as $$
  select exists (select 1 from profiles where id = auth.uid() and ops_access);
$$;

-- ─── Enums ───────────────────────────────────────────────────────────
DO $$ BEGIN
  CREATE TYPE ops_doc_type AS ENUM ('job_description', 'review', 'offer_letter', 'onboarding', 'offboarding', 'other');
EXCEPTION WHEN duplicate_object THEN null;
END $$;
DO $$ BEGIN
  CREATE TYPE ops_issue_status AS ENUM ('open', 'resolved');
EXCEPTION WHEN duplicate_object THEN null;
END $$;
DO $$ BEGIN
  CREATE TYPE ops_review_status AS ENUM ('scheduled', 'completed');
EXCEPTION WHEN duplicate_object THEN null;
END $$;
DO $$ BEGIN
  CREATE TYPE ops_checklist_kind AS ENUM ('onboarding', 'offboarding');
EXCEPTION WHEN duplicate_object THEN null;
END $$;
DO $$ BEGIN
  CREATE TYPE ops_checklist_status AS ENUM ('active', 'complete');
EXCEPTION WHEN duplicate_object THEN null;
END $$;

-- ─── Staff management: notes ─────────────────────────────────────────
create table if not exists ops_staff_notes (
  id         uuid primary key default gen_random_uuid(),
  staff_id   uuid not null references profiles(id) on update cascade on delete cascade,   -- who it's about
  author_id  uuid references profiles(id) on update cascade on delete set null,
  body       text not null,
  created_at timestamptz not null default now()
);
create index if not exists ops_staff_notes_staff_idx on ops_staff_notes(staff_id);

-- ─── Staff management: documents (metadata + link; files live in Drive per the brief) ──
create table if not exists ops_staff_documents (
  id         uuid primary key default gen_random_uuid(),
  staff_id   uuid not null references profiles(id) on update cascade on delete cascade,
  label      text not null,
  url        text,
  doc_type   ops_doc_type not null default 'other',
  created_by uuid references profiles(id) on update cascade on delete set null,
  created_at timestamptz not null default now()
);
create index if not exists ops_staff_documents_staff_idx on ops_staff_documents(staff_id);

-- ─── Issue log (sensitive — same tier, never visible to the subject) ──
create table if not exists ops_issues (
  id          uuid primary key default gen_random_uuid(),
  staff_id    uuid not null references profiles(id) on update cascade on delete cascade,
  author_id   uuid references profiles(id) on update cascade on delete set null,
  body        text not null,
  status      ops_issue_status not null default 'open',
  created_at  timestamptz not null default now(),
  resolved_at timestamptz
);
create index if not exists ops_issues_staff_idx on ops_issues(staff_id);

-- ─── Touchpoint tracker (1:1 log; "last met" = max(met_on) per staff) ──
create table if not exists ops_touchpoints (
  id         uuid primary key default gen_random_uuid(),
  staff_id   uuid not null references profiles(id) on update cascade on delete cascade,
  met_by     uuid references profiles(id) on update cascade on delete set null,
  met_on     date not null default current_date,
  note       text,
  created_at timestamptz not null default now()
);
create index if not exists ops_touchpoints_staff_idx on ops_touchpoints(staff_id, met_on desc);

-- ─── Performance reviews (schedule + record) ─────────────────────────
create table if not exists ops_reviews (
  id           uuid primary key default gen_random_uuid(),
  staff_id     uuid not null references profiles(id) on update cascade on delete cascade,
  due_date     date not null,
  status       ops_review_status not null default 'scheduled',
  completed_on date,
  reviewer_id  uuid references profiles(id) on update cascade on delete set null,
  notes        text,
  created_at   timestamptz not null default now()
);
create index if not exists ops_reviews_staff_idx on ops_reviews(staff_id);

-- ─── Onboarding / Offboarding checklists ─────────────────────────────
-- Templates hold the default steps per kind; starting a checklist for a staff member
-- copies the template steps into ops_checklist_steps (done in app code).
create table if not exists ops_checklist_templates (
  id          serial primary key,
  kind        ops_checklist_kind not null,
  step_no     int  not null,
  title       text not null,
  description text
);

create table if not exists ops_checklists (
  id           uuid primary key default gen_random_uuid(),
  staff_id     uuid not null references profiles(id) on update cascade on delete cascade,
  kind         ops_checklist_kind not null,
  status       ops_checklist_status not null default 'active',
  created_by   uuid references profiles(id) on update cascade on delete set null,
  created_at   timestamptz not null default now(),
  completed_at timestamptz
);
create index if not exists ops_checklists_staff_idx on ops_checklists(staff_id);

create table if not exists ops_checklist_steps (
  id           uuid primary key default gen_random_uuid(),
  checklist_id uuid not null references ops_checklists(id) on delete cascade,
  step_no      int  not null,
  title        text not null,
  description  text,
  done         boolean not null default false,
  done_by      uuid references profiles(id) on update cascade on delete set null,
  done_at      timestamptz
);
create index if not exists ops_checklist_steps_list_idx on ops_checklist_steps(checklist_id, step_no);

-- ─── Default checklist templates (reference data; Susanna can edit later) ──
insert into ops_checklist_templates (kind, step_no, title, description) values
  ('onboarding', 1, 'Welcome + confirm start date', 'Send the warm welcome message and confirm first day.'),
  ('onboarding', 2, 'Provision accounts',           'Create email, Staff Portal login, and any tool access needed for the role.'),
  ('onboarding', 3, 'Employee handbook',            'Share the handbook to read and acknowledge.'),
  ('onboarding', 4, 'Job description & expectations','Review the role, responsibilities, and first-90-days expectations.'),
  ('onboarding', 5, 'Payroll & tax forms',          'W-4, I-9, and direct deposit.'),
  ('onboarding', 6, 'Benefits enrollment',          'Walk through the benefits menu and enroll.'),
  ('onboarding', 7, 'Building access & safety',     'Keys/badge, building orientation, and safety basics.'),
  ('onboarding', 8, 'First-week schedule + buddy',  'Assign an onboarding buddy and lay out the first week.'),
  ('onboarding', 9, 'First 1:1 with manager',       'Schedule the first one-on-one.'),
  ('offboarding', 1, 'Confirm last day + reason',   'Record the final working day and departure reason.'),
  ('offboarding', 2, 'Exit interview',              'Schedule and hold the exit conversation.'),
  ('offboarding', 3, 'Revoke system access',        'Remove Staff Portal, email, and tool access.'),
  ('offboarding', 4, 'Collect property',            'Equipment, keys, badge, and any cards.'),
  ('offboarding', 5, 'Final pay',                   'Final timesheet, final paycheck, and PTO payout.'),
  ('offboarding', 6, 'Benefits / COBRA notice',     'Send the benefits-end and continuation notice.'),
  ('offboarding', 7, 'Reassign work',               'Hand off open tasks, files, and responsibilities.'),
  ('offboarding', 8, 'Remove from lists',           'Directories, distribution lists, and email signatures.'),
  ('offboarding', 9, 'Deactivate accounts + archive','Deactivate Supabase/Google accounts and archive their records.');

-- ─── Row-Level Security ──────────────────────────────────────────────
alter table ops_staff_notes        enable row level security;
alter table ops_staff_documents    enable row level security;
alter table ops_issues             enable row level security;
alter table ops_touchpoints        enable row level security;
alter table ops_reviews            enable row level security;
alter table ops_checklist_templates enable row level security;
alter table ops_checklists         enable row level security;
alter table ops_checklist_steps    enable row level security;

-- Staff management + issue log + touchpoints + reviews: ops tier only (A+S+Shelly).
-- Never visible to the staff member they're about.
create policy ops_notes_all     on ops_staff_notes     for all to authenticated using (has_ops_access()) with check (has_ops_access());
create policy ops_docs_all      on ops_staff_documents for all to authenticated using (has_ops_access()) with check (has_ops_access());
create policy ops_issues_all    on ops_issues          for all to authenticated using (has_ops_access()) with check (has_ops_access());
create policy ops_touch_all     on ops_touchpoints     for all to authenticated using (has_ops_access()) with check (has_ops_access());
create policy ops_reviews_all   on ops_reviews         for all to authenticated using (has_ops_access()) with check (has_ops_access());

-- Templates: any signed-in staff may read (so an onboardee sees step titles); ops tier edits.
create policy ops_tmpl_read  on ops_checklist_templates for select to authenticated using (true);
create policy ops_tmpl_write on ops_checklist_templates for all to authenticated using (has_ops_access()) with check (has_ops_access());

-- Checklists: ops tier manages all. A new hire may see + tick their OWN onboarding checklist
-- (offboarding is admin-only — the departing person never sees it).
create policy ops_chk_ops on ops_checklists for all to authenticated
  using (has_ops_access()) with check (has_ops_access());
create policy ops_chk_subject_read on ops_checklists for select to authenticated
  using (kind = 'onboarding' and staff_id = auth.uid());

create policy ops_step_ops on ops_checklist_steps for all to authenticated
  using (has_ops_access()) with check (has_ops_access());
create policy ops_step_subject_read on ops_checklist_steps for select to authenticated
  using (exists (
    select 1 from ops_checklists c
    where c.id = checklist_id and c.kind = 'onboarding' and c.staff_id = auth.uid()
  ));
create policy ops_step_subject_update on ops_checklist_steps for update to authenticated
  using (exists (
    select 1 from ops_checklists c
    where c.id = checklist_id and c.kind = 'onboarding' and c.staff_id = auth.uid()
  ))
  with check (exists (
    select 1 from ops_checklists c
    where c.id = checklist_id and c.kind = 'onboarding' and c.staff_id = auth.uid()
  ));
