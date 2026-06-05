-- Sparrow Staff Portal — Twin Oaks Room (System 2)
-- Spaces (61 lots), tenants (resident records), and work orders.
-- Data model ported from the concept system (_archive/TwinOaks/src/db/schema.ts).
-- Run AFTER 0001_init.sql. Resident PII is gated to TOC staff + admins via RLS.

-- ─── Enums ───────────────────────────────────────────────────────────
create type space_status  as enum ('occupied', 'vacant', 'reserved', 'maintenance');
create type space_type    as enum ('manufactured_home', 'rv');
create type rent_status   as enum ('current', 'overdue', 'na');
create type tenant_status as enum ('active', 'applicant', 'moved_out', 'evicted');
create type wo_category   as enum ('tenant_request', 'common_area', 'infrastructure', 'hazard_tree', 'safety');
create type wo_priority   as enum ('low', 'medium', 'high', 'urgent');
create type wo_status     as enum ('open', 'assigned', 'in_progress', 'completed', 'cancelled');

-- ─── Tables ──────────────────────────────────────────────────────────
create table spaces (
  id           uuid primary key default gen_random_uuid(),
  label        text not null unique,          -- lot number/label, e.g. "14"
  status       space_status not null default 'vacant',
  type         space_type not null default 'manufactured_home',
  current_rent numeric(8,2) not null default 0,
  rent_status  rent_status not null default 'na',
  size         text,
  notes        text,
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now()
);

create table tenants (
  id              uuid primary key default gen_random_uuid(),
  space_id        uuid references spaces(id) on delete set null,
  name            text not null,
  phone           text,
  email           text,
  household_size  integer not null default 1,
  annual_income   numeric(10,2),               -- for AMI eligibility
  status          tenant_status not null default 'active',
  move_in_date    date,
  notes           text,                        -- resident notes (sensitive)
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now()
);
create index tenants_space_idx on tenants(space_id);

create table work_orders (
  id             uuid primary key default gen_random_uuid(),
  space_id       uuid references spaces(id) on delete set null,  -- null = common area / infra
  location       text not null,
  category       wo_category not null default 'tenant_request',
  description    text not null,
  priority       wo_priority not null default 'medium',
  status         wo_status not null default 'open',
  assigned_to    uuid references profiles(id) on update cascade on delete set null,
  request_date   date not null default current_date,
  completed_date date,
  created_at     timestamptz not null default now(),
  updated_at     timestamptz not null default now()
);
create index work_orders_space_idx on work_orders(space_id);
create index work_orders_status_idx on work_orders(status);

-- keep updated_at fresh (reuses set_updated_at() from 0001)
create trigger spaces_updated_at before update on spaces
  for each row execute function set_updated_at();
create trigger tenants_updated_at before update on tenants
  for each row execute function set_updated_at();
create trigger work_orders_updated_at before update on work_orders
  for each row execute function set_updated_at();

-- ─── Permission helper: who may see resident records ─────────────────
-- TOC staff (Audrey, Lindy, Raymond) + admins (Andrew, Susanna). Others can see
-- the operational lot grid but not resident PII or work-order detail.
create or replace function can_see_residents() returns boolean
  language sql security definer set search_path = public stable as $$
  select exists (
    select 1 from profiles
    where id = auth.uid() and (role = 'admin' or department = 'toc')
  );
$$;

-- ─── Row-Level Security ──────────────────────────────────────────────
alter table spaces      enable row level security;
alter table tenants     enable row level security;
alter table work_orders enable row level security;

-- spaces: the lot grid is operational — any signed-in staff may view it.
create policy spaces_select on spaces
  for select to authenticated using (true);
create policy spaces_write on spaces
  for all to authenticated using (can_see_residents()) with check (can_see_residents());

-- tenants: resident PII — TOC staff + admins only.
create policy tenants_select on tenants
  for select to authenticated using (can_see_residents());
create policy tenants_write on tenants
  for all to authenticated using (can_see_residents()) with check (can_see_residents());

-- work orders: TOC staff + admins, plus whoever a work order is assigned to.
create policy work_orders_select on work_orders
  for select to authenticated using (can_see_residents() or assigned_to = auth.uid());
create policy work_orders_write on work_orders
  for all to authenticated using (can_see_residents()) with check (can_see_residents());
