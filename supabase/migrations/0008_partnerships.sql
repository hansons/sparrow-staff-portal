-- Sparrow Staff Portal (System 2) — Partnerships Room ("CRM")
-- The relationship-stewardship room. Implements the Partnership System Architecture
-- (reference/sparrow-inc/strategy/foundation-partnership-system-architecture.md) and the
-- Partnerships primer. Run AFTER 0007_lcp_fk_cascade.sql, then run seed_partnerships.sql.
--
-- The load-bearing rule from the architecture: "Every relationship needs a RHYTHM, not
-- just a record." So this room is not a contact dump — it tracks, per partner, a named
-- OWNER and a CADENCE, derives who is due / overdue for a touchpoint, and (via the spine)
-- pushes overdue relationships onto the owner's Triage Inbox. source_system = 'crm'.
--
-- Access (mirrors Twin Oaks' resident-PII gate): partnerships staff (Bethany) + admins
-- (Andrew, Susanna) manage everything. Two extensions:
--   • A per-person `partnerships_access` flag (toggled in the Staff admin panel, like LCP's
--     lcp_role) grants the full room to someone whose department isn't 'partnerships'.
--   • A partner's named OWNER always sees/stewards their own partners — so Audrey (FST),
--     Shelly (SM volunteers), and Andrew (maintenance) reach the relationships they hold
--     even without full-room access.

-- ─── Enums ───────────────────────────────────────────────────────────
DO $$ BEGIN
  CREATE TYPE partner_type AS ENUM ('donor', 'church', 'community', 'volunteer', 'prayer', 'fst', 'business', 'foundation');
EXCEPTION WHEN duplicate_object THEN null;
END $$;
DO $$ BEGIN
  CREATE TYPE partner_stage AS ENUM ('prospect', 'active', 'lapsed', 'inactive');
EXCEPTION WHEN duplicate_object THEN null;
END $$;
DO $$ BEGIN
  CREATE TYPE donor_tier AS ENUM ('first_time', 'recurring', 'major', 'lapsed');
EXCEPTION WHEN duplicate_object THEN null;
END $$;
DO $$ BEGIN
  CREATE TYPE touchpoint_method AS ENUM ('email', 'phone', 'in_person', 'text', 'letter', 'event', 'other');
EXCEPTION WHEN duplicate_object THEN null;
END $$;

-- Full Partnerships Room access for someone outside the 'partnerships' department (toggled
-- in the Staff admin panel, like LCP's lcp_role). Admin + department='partnerships' already
-- have it implicitly; this opens the room to e.g. Audrey (FST) or Shelly (volunteers).
alter table profiles add column partnerships_access boolean not null default false;

-- ─── Partners (the relationship record + its stewardship rhythm) ──────
create table if not exists partners (
  id                uuid primary key default gen_random_uuid(),
  name              text not null,                          -- partner / org / person display name
  type              partner_type not null,
  stage             partner_stage not null default 'prospect',
  owner_id          uuid references profiles(id) on update cascade on delete set null, -- named owner (precondition for stewardship)
  organization      text,                                   -- org name when the partner is a person, or vice versa
  contact_name      text,                                   -- primary contact person
  email             text,
  phone             text,
  donor_tier        donor_tier,                             -- first_time / recurring / major / lapsed (donors)
  cadence_days      int,                                    -- the stewardship rhythm; null = no defined cadence (a defect)
  last_touchpoint_at date,                                  -- denormalized from touchpoints for fast "due" math
  source            text,                                   -- how the connection was made
  notes             text,
  active            boolean not null default true,
  created_at        timestamptz not null default now(),
  updated_at        timestamptz not null default now()
);
create index if not exists partners_owner_idx on partners(owner_id);
create index if not exists partners_type_idx on partners(type);

-- ─── Touchpoints (every logged contact — the evidence the rhythm is being kept) ──
create table if not exists partner_touchpoints (
  id          uuid primary key default gen_random_uuid(),
  partner_id  uuid not null references partners(id) on delete cascade,
  logged_by   uuid references profiles(id) on update cascade on delete set null,
  method      touchpoint_method not null default 'email',
  occurred_on date not null default current_date,
  summary     text,
  created_at  timestamptz not null default now()
);
create index if not exists partner_touchpoints_partner_idx on partner_touchpoints(partner_id, occurred_on desc);

create trigger partners_updated_at before update on partners
  for each row execute function set_updated_at();

-- Logging a touchpoint advances last_touchpoint_at and clears any open "touchpoint due"
-- task the spine raised for this partner — the rhythm has been kept, so the nudge resolves.
create or replace function on_touchpoint_logged() returns trigger
  language plpgsql security definer set search_path = public as $$
begin
  update partners
     set last_touchpoint_at = greatest(coalesce(last_touchpoint_at, NEW.occurred_on), NEW.occurred_on),
         updated_at = now()
   where id = NEW.partner_id;
  perform resolve_system_task('crm', 'touchpoint:' || NEW.partner_id);
  return NEW;
end $$;

create trigger partner_touchpoint_logged after insert on partner_touchpoints
  for each row execute function on_touchpoint_logged();

-- ─── Permission helper: who may manage the CRM ───────────────────────
-- Partnerships staff (Bethany) + admins (Andrew, Susanna). Named owners get scoped
-- access to their own partners via the policies below (not through this helper).
create or replace function partnerships_has_access() returns boolean
  language sql security definer set search_path = public stable as $$
  select exists (
    select 1 from profiles
    where id = auth.uid()
      and (role = 'admin' or department = 'partnerships' or partnerships_access)
  );
$$;

-- ─── Spine integration: surface overdue touchpoints as triaged tasks ──
-- A partner is "due" when coalesce(last_touchpoint_at, created_at) + cadence_days has
-- passed. For each active/prospect partner with an owner and a cadence whose touchpoint
-- is overdue, emit (dedup-safe) a task to the owner. Touchpoint logging resolves it.
-- SECURITY DEFINER so any partnerships viewer's load can fan work to the right owners.
create or replace function emit_due_touchpoint_tasks() returns int
  language plpgsql security definer set search_path = public as $$
declare r record; n int := 0; due date;
begin
  if not partnerships_has_access() then
    return 0;                                   -- only the CRM-facing roles trigger the sweep
  end if;
  for r in
    select id, name, owner_id,
           (coalesce(last_touchpoint_at, created_at::date) + cadence_days) as due_date
    from partners
    where active
      and stage in ('active', 'prospect')
      and owner_id is not null
      and cadence_days is not null
      and (coalesce(last_touchpoint_at, created_at::date) + cadence_days) < current_date
  loop
    due := r.due_date;
    perform emit_system_task(
      'crm', 'touchpoint:' || r.id, r.owner_id,
      'Touchpoint due — ' || r.name,
      'partnerships'::department, 'p2'::priority, due
    );
    n := n + 1;
  end loop;
  return n;
end $$;

-- ─── Row-Level Security ──────────────────────────────────────────────
alter table partners            enable row level security;
alter table partner_touchpoints enable row level security;

-- Partners: CRM staff + admins manage all; a named owner sees/stewards their own.
create policy partners_select on partners for select to authenticated
  using (partnerships_has_access() or owner_id = auth.uid());
create policy partners_write on partners for all to authenticated
  using (partnerships_has_access() or owner_id = auth.uid())
  with check (partnerships_has_access() or owner_id = auth.uid());

-- Touchpoints: same reach as the partner they belong to.
create policy touchpoints_select on partner_touchpoints for select to authenticated
  using (
    partnerships_has_access()
    or exists (select 1 from partners p where p.id = partner_id and p.owner_id = auth.uid())
  );
create policy touchpoints_write on partner_touchpoints for all to authenticated
  using (
    partnerships_has_access()
    or exists (select 1 from partners p where p.id = partner_id and p.owner_id = auth.uid())
  )
  with check (
    partnerships_has_access()
    or exists (select 1 from partners p where p.id = partner_id and p.owner_id = auth.uid())
  );
