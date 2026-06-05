-- Sparrow Staff Portal — Operations Room seed (SYNTHETIC data).
-- Run AFTER 0012_operations.sql and AFTER seed.sql.
--
-- Staff are referenced by EMAIL, not by the fixed seed UUIDs: the sign-in trigger
-- rewrites profiles.id to the auth user id on first sign-in, so a hardcoded UUID goes
-- stale for anyone who has logged in. Email is the stable key (it's the allowlist).
-- Every insert is `insert … select … from profiles where email = …`, so a row is
-- simply skipped (not an FK error) if an address doesn't match.

-- ─── Ops-management tier: Andrew + Susanna + Shelly ──────────────────
update profiles set ops_access = true
where lower(email) in (
  'executivedirector@sparrowinc.org',   -- Andrew
  'susannab@sparrowinc.org',            -- Susanna
  'lifechangedirector@sparrowinc.org'   -- Shelly
);

-- ─── Demo: a management note (Bethany, by Susanna) ───────────────────
insert into ops_staff_notes (staff_id, author_id, body)
select b.id, s.id, 'Strong on the newsletter cadence — ready for more donor-facing responsibility.'
from profiles b, profiles s
where lower(b.email) = 'bethanyw@sparrowinc.org' and lower(s.email) = 'susannab@sparrowinc.org';

-- ─── Demo: touchpoints (Audrey recent, Lindy overdue) ────────────────
insert into ops_touchpoints (staff_id, met_by, met_on, note)
select a.id, s.id, current_date - 5, 'Resident-services load is manageable; all good.'
from profiles a, profiles s
where lower(a.email) = 'audreyb@sparrowinc.org' and lower(s.email) = 'susannab@sparrowinc.org';

insert into ops_touchpoints (staff_id, met_by, met_on, note)
select l.id, s.id, current_date - 40, 'Last touch-base — overdue for another.'
from profiles l, profiles s
where lower(l.email) = 'lindyw@sparrowinc.org' and lower(s.email) = 'susannab@sparrowinc.org';

-- ─── Demo: reviews (Bethany upcoming, Audrey overdue) ────────────────
insert into ops_reviews (staff_id, due_date, status, reviewer_id)
select b.id, current_date + 10, 'scheduled', s.id
from profiles b, profiles s
where lower(b.email) = 'bethanyw@sparrowinc.org' and lower(s.email) = 'susannab@sparrowinc.org';

insert into ops_reviews (staff_id, due_date, status, reviewer_id)
select a.id, current_date - 3, 'scheduled', s.id
from profiles a, profiles s
where lower(a.email) = 'audreyb@sparrowinc.org' and lower(s.email) = 'susannab@sparrowinc.org';

-- ─── Demo: an open HR issue (Lindy, by Susanna) ──────────────────────
insert into ops_issues (staff_id, author_id, body, status)
select l.id, s.id, 'Two late arrivals this month — keeping an eye on it, no action yet.', 'open'
from profiles l, profiles s
where lower(l.email) = 'lindyw@sparrowinc.org' and lower(s.email) = 'susannab@sparrowinc.org';

-- ─── Demo: an in-progress onboarding checklist (Raymond) ─────────────
with run as (
  insert into ops_checklists (staff_id, kind, created_by)
  select r.id, 'onboarding', s.id
  from profiles r, profiles s
  where lower(r.email) = 'raymondd@sparrowinc.org' and lower(s.email) = 'susannab@sparrowinc.org'
  returning id
)
insert into ops_checklist_steps (checklist_id, step_no, title, description)
select run.id, t.step_no, t.title, t.description
from run, ops_checklist_templates t
where t.kind = 'onboarding';
