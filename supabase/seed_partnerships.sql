-- Sparrow Staff Portal — Partnerships Room seed.
-- Run AFTER 0008_partnerships.sql (and after seed.sql, which creates the staff profiles
-- these partners are owned by).
--
-- Mix of data, deliberately:
--   • ORGANIZATION partners (community orgs + the Hive church network) are REAL — these
--     are Sparrow's actual partners, drawn from tool-current-partnerships-tracker.md and
--     foundation-partnership-system-architecture.md. Their contacts are business contacts.
--   • INDIVIDUAL partners (donors, volunteers, prayer, FST) are SYNTHETIC. The real donor
--     roster is confidential (donor names + giving patterns); never seed it. These stand-ins
--     exist only to exercise the stewardship states.
--
-- Touchpoint dates are relative to current_date so the room always demos the full spread:
-- on cadence (green) · due soon (amber) · overdue (red) · lapsed · prospect.
--
-- Owner UUIDs (from seed.sql): Andrew …001 · Susanna …002 · Shelly …003 · Bethany …004 · Audrey …005

insert into partners (id, name, type, stage, owner_id, organization, contact_name, email, phone, donor_tier, cadence_days, last_touchpoint_at, source, notes) values
  -- ── Church partners — The Hive Communities network (quarterly cadence) ──
  ('00000000-0000-0000-0001-000000000001', 'The Hive Communities', 'church', 'active', '00000000-0000-0000-0000-000000000004', null, 'Tim Wenger', null, null, null, 90, current_date - 28,  'Andrew''s relationship', 'Parent church network. Sub-churches: The Spring, Corpus Christi, Green Tree.'),
  ('00000000-0000-0000-0001-000000000002', 'The Spring', 'church', 'active', '00000000-0000-0000-0000-000000000004', 'The Hive Communities', 'Bond Nichols', null, null, null, 90, current_date - 75,  'Hive network', 'Sub-church of the Hive.'),
  ('00000000-0000-0000-0001-000000000003', 'Corpus Christi (Philomath)', 'church', 'active', '00000000-0000-0000-0000-000000000004', 'The Hive Communities', 'Samuel Stumbo', null, null, null, 90, current_date - 120, 'Hive network', 'Sub-church of the Hive. Philomath.'),
  ('00000000-0000-0000-0001-000000000004', 'Green Tree', 'church', 'active', '00000000-0000-0000-0000-000000000004', 'The Hive Communities', 'Andy Bumstead', null, null, null, 90, current_date - 45,  'Hive network', 'Sub-church of the Hive.'),

  -- ── Community partners (4 active orgs — bi-annual touchpoint) ──
  ('00000000-0000-0000-0001-000000000010', 'C.H.A.N.C.E.', 'community', 'active', '00000000-0000-0000-0000-000000000004', null, null, null, null, null, 180, current_date - 200, 'Existing referral relationship', 'We provide family-program referrals; they provide drug testing + referrals to Sparrow. No MOU on file. Prior contact left — re-engagement needed.'),
  ('00000000-0000-0000-0001-000000000011', 'Southside Youth Outreach', 'community', 'active', '00000000-0000-0000-0000-000000000004', 'SSYO', 'Noah Milbourn', 'noah.m@ssyocorvallis.org', '541-758-8131', null, 180, current_date - 60,  'Director outreach', 'Verbal partnership; MOU flagged. Family priority placement.'),
  ('00000000-0000-0000-0001-000000000012', 'Good News Club / Child Evangelism Fellowship', 'community', 'active', '00000000-0000-0000-0000-000000000004', 'Child Evangelism Fellowship', 'Collette Kuhl', null, null, null, 180, current_date - 175, 'Collette Kuhl', 'No MOU on file.'),
  ('00000000-0000-0000-0001-000000000013', 'Benton County Prayer Team', 'community', 'active', '00000000-0000-0000-0000-000000000004', null, 'Peter Carlson', null, '541-936-2703', null, 30, current_date - 20,  'Prayer team leader', 'Prays for Sparrow ≥ monthly when Bethany sends prayer points (last Tue of each month).'),

  -- ── Donors — SYNTHETIC stand-ins (real donor roster is confidential) ──
  ('00000000-0000-0000-0001-000000000020', 'James & Karen Holloway', 'donor', 'active', '00000000-0000-0000-0000-000000000004', null, null, 'jk.holloway@example.com', null, 'major', 90,  current_date - 100, 'Personal relationship (synthetic)', 'SYNTHETIC. Major-tier ($10k+) → Andrew calls within 72 hrs on new gifts.'),
  ('00000000-0000-0000-0001-000000000021', 'Grace Monroe', 'donor', 'active', '00000000-0000-0000-0000-000000000004', null, null, 'grace.monroe@example.com', null, 'recurring', 180, current_date - 40,  'Givebutter (synthetic)', 'SYNTHETIC. Recurring monthly gift.'),
  ('00000000-0000-0000-0001-000000000022', 'Daniel Reyes', 'donor', 'active', '00000000-0000-0000-0000-000000000004', null, null, 'daniel.reyes@example.com', null, 'first_time', 3, null, 'Givebutter (synthetic)', 'SYNTHETIC. First-time donor — personal thank-you email from Bethany due within 48–72 hrs.'),
  ('00000000-0000-0000-0001-000000000023', 'Margaret Ellison', 'donor', 'lapsed',  '00000000-0000-0000-0000-000000000004', null, null, 'm.ellison@example.com', null, 'lapsed', 180, current_date - 430, 'Givebutter (synthetic)', 'SYNTHETIC. No gift in 14 months — warm check-in (not an ask), per the lapsed flow.'),

  -- ── Volunteers / Prayer / FST — SYNTHETIC stand-ins ──
  ('00000000-0000-0000-0001-000000000030', 'Mike Dolan', 'volunteer', 'active', '00000000-0000-0000-0000-000000000001', null, null, 'mike.dolan@example.com', null, null, 180, current_date - 30, 'Maintenance volunteer (synthetic)', 'SYNTHETIC. Maintenance / building volunteer — owned by Andrew.'),
  ('00000000-0000-0000-0001-000000000031', 'Eleanor Voss', 'prayer', 'active', '00000000-0000-0000-0000-000000000004', null, null, 'eleanor.voss@example.com', null, null, 30, current_date - 40, 'Prayer team (synthetic)', 'SYNTHETIC. Committed intercessor. Quiet > 30 days → personal check-in.'),
  ('00000000-0000-0000-0001-000000000032', 'The Reyes Family (FST)', 'fst', 'active', '00000000-0000-0000-0000-000000000005', null, null, null, null, null, 30, current_date - 10, 'FST pipeline (synthetic)', 'SYNTHETIC. Family Support Team — supports one LifeChange family. Owned by Audrey.'),

  -- ── Foundation — prospect (synthetic) ──
  ('00000000-0000-0000-0001-000000000040', 'Cascade Regional Foundation', 'foundation', 'prospect', '00000000-0000-0000-0000-000000000002', null, null, null, null, null, 120, null, 'Grant research (synthetic)', 'SYNTHETIC. Grant-making foundation prospect — Susanna leads, Andrew oversees.')
on conflict (id) do nothing;

-- A little touchpoint history (latest of each matches last_touchpoint_at above so the
-- trigger keeps the denormalized field consistent). logged_by Bethany unless owner differs.
insert into partner_touchpoints (partner_id, logged_by, method, occurred_on, summary) values
  ('00000000-0000-0000-0001-000000000001', '00000000-0000-0000-0000-000000000004', 'in_person', current_date - 28,  'Quarterly check-in with Tim — shared LifeChange update.'),
  ('00000000-0000-0000-0001-000000000001', '00000000-0000-0000-0000-000000000004', 'email',     current_date - 120, 'Sent year-end giving report + cover note.'),
  ('00000000-0000-0000-0001-000000000002', '00000000-0000-0000-0000-000000000004', 'email',     current_date - 75,  'Touched base with Bond on spring volunteer interest.'),
  ('00000000-0000-0000-0001-000000000003', '00000000-0000-0000-0000-000000000004', 'phone',     current_date - 120, 'Last call with Samuel — overdue for a follow-up.'),
  ('00000000-0000-0000-0001-000000000004', '00000000-0000-0000-0000-000000000004', 'in_person', current_date - 45,  'Visited Green Tree service; brief catch-up with Andy.'),
  ('00000000-0000-0000-0001-000000000010', '00000000-0000-0000-0000-000000000004', 'email',     current_date - 200, 'Last contact before their staff change — needs re-engagement.'),
  ('00000000-0000-0000-0001-000000000011', '00000000-0000-0000-0000-000000000004', 'phone',     current_date - 60,  'Confirmed referral process with Noah.'),
  ('00000000-0000-0000-0001-000000000012', '00000000-0000-0000-0000-000000000004', 'email',     current_date - 175, 'Coordinated club schedule with Collette.'),
  ('00000000-0000-0000-0001-000000000013', '00000000-0000-0000-0000-000000000004', 'email',     current_date - 20,  'Sent monthly prayer points to Peter.'),
  ('00000000-0000-0000-0001-000000000020', '00000000-0000-0000-0000-000000000004', 'in_person', current_date - 100, 'Coffee with the Holloways — overdue for next touch.'),
  ('00000000-0000-0000-0001-000000000021', '00000000-0000-0000-0000-000000000004', 'email',     current_date - 40,  'Thanked Grace for continued monthly giving.'),
  ('00000000-0000-0000-0001-000000000023', '00000000-0000-0000-0000-000000000004', 'email',     current_date - 430, 'Last contact — no gift since.'),
  ('00000000-0000-0000-0001-000000000030', '00000000-0000-0000-0000-000000000001', 'text',      current_date - 30,  'Scheduled Mike for the next work-project Saturday.'),
  ('00000000-0000-0000-0001-000000000031', '00000000-0000-0000-0000-000000000004', 'email',     current_date - 40,  'Last weekly-update reply from Eleanor — has gone quiet.'),
  ('00000000-0000-0000-0001-000000000032', '00000000-0000-0000-0000-000000000005', 'letter',    current_date - 10,  'FST family sent an encouragement letter.');

-- Daniel Reyes (first-time donor) is intentionally created "today" with no touchpoint yet,
-- so he surfaces as a fresh first-time follow-up. Pin his created_at to now so the 48–72 hr
-- window reads correctly regardless of when the seed is run.
update partners set created_at = now() where id = '00000000-0000-0000-0001-000000000022';

-- Audrey owns the FST partner but is department='toc', so she'd otherwise have no way to open
-- the room. Grant the per-person Partnerships Room access flag to demonstrate the distributed-
-- owner case (do the same for Shelly if she should browse her volunteer relationships).
update profiles set partnerships_access = true where id = '00000000-0000-0000-0000-000000000005';
