-- Twin Oaks Room — dev seed (SYNTHETIC, no real PII). Run AFTER 0002_twin_oaks.sql.
-- 61 lots: 1–58 occupied, 59–61 vacant. A few lots overdue (red) or with open work
-- orders (amber) so the property grid demonstrates every status color.

-- 61 spaces
insert into spaces (label, status, type, current_rent, rent_status)
select
  g::text,
  case when g <= 58 then 'occupied'::space_status else 'vacant'::space_status end,
  case when g % 11 = 0 then 'rv'::space_type else 'manufactured_home'::space_type end,
  case when g <= 58 then 625 + (g % 6) * 25 else 0 end,
  case
    when g > 58 then 'na'::rent_status
    when g in (7, 19, 33, 52) then 'overdue'::rent_status
    else 'current'::rent_status
  end
from generate_series(1, 61) as g;

-- A sample of residents (only some occupied lots, to keep the seed small)
insert into tenants (space_id, name, phone, household_size, annual_income, status, move_in_date, notes)
select s.id, v.name, v.phone, v.hh, v.income, 'active'::tenant_status, v.movein::date, nullif(v.notes, '')
from (values
  ('2',  'Maria Gonzalez',     '541-555-0102', 3, 38000, '2022-05-01', 'Prefers text contact.'),
  ('7',  'James Carter',       '541-555-0107', 1, 21000, '2019-09-15', 'Rent past due — see ledger.'),
  ('12', 'The Nguyen Family',  '541-555-0112', 4, 46000, '2023-01-10', ''),
  ('19', 'Robert Hill',        '541-555-0119', 2, 29000, '2020-03-22', 'Balance outstanding.'),
  ('23', 'Patricia Lewis',     '541-555-0123', 1, 18500, '2018-07-05', 'Assistance animal on file.'),
  ('31', 'The Okafor Family',  '541-555-0131', 5, 52000, '2024-02-28', ''),
  ('33', 'Linda Brooks',       '541-555-0133', 2, 27000, '2021-11-12', 'Payment plan discussed.'),
  ('40', 'Daniel Reyes',       '541-555-0140', 3, 41000, '2022-08-19', ''),
  ('48', 'Susan Park',         '541-555-0148', 1, 23000, '2017-04-30', ''),
  ('52', 'The Johnson Family', '541-555-0152', 4, 35000, '2023-06-01', 'Rent past due.')
) as v(lbl, name, phone, hh, income, movein, notes)
join spaces s on s.label = v.lbl;

-- Work orders (assigned to Raymond = ...007, Lindy = ...006)
insert into work_orders (space_id, location, category, description, priority, status, assigned_to, request_date, completed_date)
select
  s.id, v.loc, v.cat::wo_category, v.descr, v.pri::wo_priority, v.st::wo_status,
  v.assignee::uuid, current_date - v.days_ago,
  case when v.st = 'completed' then current_date - (v.days_ago - 3) else null end
from (values
  ('14',   'Lot 14',        'tenant_request', 'Loose porch step board.',          'high',   'open',        '00000000-0000-0000-0000-000000000007', 2),
  ('3',    'Lot 3',         'tenant_request', 'Kitchen faucet leak.',             'medium', 'assigned',    '00000000-0000-0000-0000-000000000007', 5),
  ('27',   'Common area',   'common_area',    'Playground gate hinge broken.',    'medium', 'in_progress', '00000000-0000-0000-0000-000000000006', 8),
  (null,   'Park entrance', 'infrastructure', 'Entrance light out.',              'low',    'open',        '00000000-0000-0000-0000-000000000006', 12),
  ('40',   'Lot 40',        'safety',         'Smoke detector replacement.',      'high',   'open',        '00000000-0000-0000-0000-000000000007', 1),
  ('12',   'Lot 12',        'tenant_request', 'Skirting panel detached.',         'low',    'completed',   '00000000-0000-0000-0000-000000000007', 20)
) as v(lbl, loc, cat, descr, pri, st, assignee, days_ago)
left join spaces s on s.label = v.lbl;
