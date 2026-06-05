-- Sparrow Staff Portal — dev seed (SYNTHETIC task data; REAL staff roster + emails).
-- Run AFTER 0001_init.sql (and before seed_lcp.sql, which needs these profile UUIDs).
--
-- The `email` values are the sign-in allowlist — they must be each person's ACTUAL
-- Google Workspace address or their login is rejected as "not on the Sparrow roster".
--
-- Re-seeding? `profiles` upserts on its fixed UUID (id), so this file is re-runnable.
-- If the DB is in a half-seeded state, run the reset block from the LCP buildout notes
-- first (truncate … cascade), then run the seeds in order.
--
-- Org chart:
--   Andrew (ED) .............. admin   / exec   -> Board (no manager)
--   Susanna (Ops Mgr) ........ admin   / ops    -> Andrew
--   Ryan Hanson (consultant) . admin   / ops    -> Susanna
--   Byron (IT subcontractor) . admin   / ops    -> Andrew
--   Shelly (LCP Director) .... manager / lcp    -> Andrew
--   Bethany (Partnerships) ... staff   / partnerships -> Susanna
--   Audrey (Resident/Family) . staff   / toc    -> Susanna
--   Lindy (TOC Caretaker) .... staff   / toc    -> Susanna
--   Raymond (Groundskeeper) .. staff   / toc    -> Susanna
--   Teresa (Bookkeeper) ...... staff   / ops    -> Andrew

insert into profiles (id, email, full_name, role, department, manager_email) values
  ('00000000-0000-0000-0000-000000000001', 'executivedirector@sparrowinc.org',  'Andrew Wenger',  'admin',   'exec',         null),
  ('00000000-0000-0000-0000-000000000002', 'susannab@sparrowinc.org',           'Susanna Basden', 'admin',   'ops',          'executivedirector@sparrowinc.org'),
  ('00000000-0000-0000-0000-000000000003', 'lifechangedirector@sparrowinc.org', 'Shelly Wenger',  'manager', 'lcp',          'executivedirector@sparrowinc.org'),
  ('00000000-0000-0000-0000-000000000004', 'bethanyw@sparrowinc.org',            'Bethany Wenger', 'staff',   'partnerships', 'susannab@sparrowinc.org'),       -- PLACEHOLDER email — confirm
  ('00000000-0000-0000-0000-000000000005', 'audreyb@sparrowinc.org',             'Audrey',         'staff',   'toc',          'susannab@sparrowinc.org'),       -- PLACEHOLDER email — confirm
  ('00000000-0000-0000-0000-000000000006', 'lindyw@sparrowinc.org',              'Lindy',          'staff',   'toc',          'susannab@sparrowinc.org'),       -- PLACEHOLDER email — confirm
  ('00000000-0000-0000-0000-000000000007', 'raymondd@sparrowinc.org',            'Raymond',        'staff',   'toc',          'susannab@sparrowinc.org'),       -- PLACEHOLDER email — confirm
  ('00000000-0000-0000-0000-000000000008', 'accounting@sparrowinc.org',             'Teresa',         'staff',   'ops',          'executivedirector@sparrowinc.org'), -- PLACEHOLDER email — confirm
  ('00000000-0000-0000-0000-000000000009', 'ryanlhanson@gmail.com',             'Ryan Hanson',    'admin',   'ops',          'susannab@sparrowinc.org'),
  ('00000000-0000-0000-0000-000000000010', 'it@sparrowinc.org',                 'Byron',          'admin',   'ops',          'executivedirector@sparrowinc.org')
on conflict (id) do update set
  email         = excluded.email,
  full_name     = excluded.full_name,
  role          = excluded.role,
  department    = excluded.department,
  manager_email = excluded.manager_email;

-- Synthetic tasks. Due dates are relative to today so grouping always demos well:
--   overdue / today / this week / upcoming.
insert into tasks (title, notes, due_date, department, priority, status, assignee_id, created_by) values
  ('Submit Q2 grant report',          'Final figures from Teresa, then upload to portal.', current_date - 3, 'partnerships', 'p1', 'in_progress', '00000000-0000-0000-0000-000000000004', '00000000-0000-0000-0000-000000000002'),
  ('Call back applicant family',      'Returning their voicemail about the waitlist.',     current_date - 1, 'lcp',          'p2', 'todo',        '00000000-0000-0000-0000-000000000003', '00000000-0000-0000-0000-000000000003'),
  ('Lot 14 — fix porch step',         'Resident reported a loose board.',                  current_date,     'toc',          'p2', 'todo',        '00000000-0000-0000-0000-000000000007', '00000000-0000-0000-0000-000000000006'),
  ('Newsletter first draft',          'June community update + prayer requests.',          current_date,     'partnerships', 'p3', 'todo',        '00000000-0000-0000-0000-000000000004', '00000000-0000-0000-0000-000000000002'),
  ('Staff meeting agenda',            'Collect topics from each department lead.',         current_date + 2, 'ops',          'p3', 'todo',        '00000000-0000-0000-0000-000000000002', '00000000-0000-0000-0000-000000000002'),
  ('Reconcile May donations',         'Match Givebutter payouts to QuickBooks.',           current_date + 4, 'ops',          'p2', 'todo',        '00000000-0000-0000-0000-000000000008', '00000000-0000-0000-0000-000000000001'),
  ('Schedule well-water test',        'Annual arsenic + nitrate panel for the park.',      current_date + 9, 'toc',          'p3', 'todo',        '00000000-0000-0000-0000-000000000006', '00000000-0000-0000-0000-000000000002'),
  ('Plan volunteer appreciation',     'Pick a date and venue for the summer thank-you.',   current_date + 14, 'lcp',         'p4', 'todo',        '00000000-0000-0000-0000-000000000003', '00000000-0000-0000-0000-000000000003'),
  ('Review board onboarding packet',  'New board member starts next month.',               current_date + 12, 'exec',        'p3', 'todo',        '00000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000002');

-- A couple of comment threads to demo collaboration.
insert into task_comments (task_id, author_id, body)
select t.id, '00000000-0000-0000-0000-000000000004', 'Draft ready for your review!'
from tasks t where t.title = 'Newsletter first draft';
insert into task_comments (task_id, author_id, body)
select t.id, '00000000-0000-0000-0000-000000000002', 'Thanks — I''ll read it this afternoon.'
from tasks t where t.title = 'Newsletter first draft';
