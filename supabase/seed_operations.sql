-- Sparrow Staff Portal — Operations Room seed (SYNTHETIC data).
-- Run AFTER 0012_operations.sql and AFTER seed.sql (needs the staff profile UUIDs).

-- ─── Ops-management tier: Andrew + Susanna + Shelly ──────────────────
update profiles set ops_access = true where id in (
  '00000000-0000-0000-0000-000000000001',  -- Andrew
  '00000000-0000-0000-0000-000000000002',  -- Susanna
  '00000000-0000-0000-0000-000000000003'   -- Shelly
);

-- ─── Demo staff-management data ──────────────────────────────────────
insert into ops_staff_notes (staff_id, author_id, body) values
  ('00000000-0000-0000-0000-000000000004', '00000000-0000-0000-0000-000000000002',
   'Strong on the newsletter cadence — ready for more donor-facing responsibility.');

insert into ops_touchpoints (staff_id, met_by, met_on, note) values
  ('00000000-0000-0000-0000-000000000005', '00000000-0000-0000-0000-000000000002', current_date - 5,  'Resident-services load is manageable; all good.'),
  ('00000000-0000-0000-0000-000000000006', '00000000-0000-0000-0000-000000000002', current_date - 40, 'Last touch-base — overdue for another.');

insert into ops_reviews (staff_id, due_date, status, reviewer_id) values
  ('00000000-0000-0000-0000-000000000004', current_date + 10, 'scheduled', '00000000-0000-0000-0000-000000000002'),
  ('00000000-0000-0000-0000-000000000005', current_date - 3,  'scheduled', '00000000-0000-0000-0000-000000000002');  -- overdue

insert into ops_issues (staff_id, author_id, body, status) values
  ('00000000-0000-0000-0000-000000000006', '00000000-0000-0000-0000-000000000002',
   'Two late arrivals this month — keeping an eye on it, no action yet.', 'open');

-- One in-progress onboarding checklist (Raymond), steps copied from the template.
with run as (
  insert into ops_checklists (staff_id, kind, created_by)
  values ('00000000-0000-0000-0000-000000000007', 'onboarding', '00000000-0000-0000-0000-000000000002')
  returning id
)
insert into ops_checklist_steps (checklist_id, step_no, title, description)
select run.id, t.step_no, t.title, t.description
from run, ops_checklist_templates t
where t.kind = 'onboarding';
