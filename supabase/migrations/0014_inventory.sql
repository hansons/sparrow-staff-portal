-- ============================================================
-- 0014_inventory.sql
-- Property Inventory System
-- ============================================================
-- Three workflows:
--   1. Monthly non-consumables  (additions + removals, all year)
--   2. December consumables     (annual snapshot — separate table, phase 2)
--   3. LCP House Flip           (resident-transition inventory — phase 3)
-- This migration covers workflow 1 and the shared asset register.
-- ============================================================


-- ── Enums ────────────────────────────────────────────────────────────────

CREATE TYPE inv_item_status    AS ENUM ('active', 'removed');
CREATE TYPE inv_item_condition AS ENUM ('new', 'used');
CREATE TYPE inv_cost_source    AS ENUM ('known', 'estimated');
CREATE TYPE inv_cost_basis     AS ENUM ('per_item', 'total');
CREATE TYPE inv_sub_status     AS ENUM ('draft', 'submitted', 'approved');
CREATE TYPE inv_exit_method    AS ENUM ('thrown_out', 'hauled_away', 'sold', 'donated_picked_up');
CREATE TYPE inv_change_type    AS ENUM (
  'acquired', 'quantity_updated', 'cost_updated',
  'description_updated', 'location_changed', 'removed'
);


-- ── Locations (seeded, not user-created) ─────────────────────────────────

CREATE TABLE inv_locations (
  id         uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name       text NOT NULL UNIQUE,
  sort_order int  NOT NULL DEFAULT 0
);

CREATE TABLE inv_sub_locations (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  location_id uuid NOT NULL REFERENCES inv_locations(id),
  name        text NOT NULL,
  sort_order  int  NOT NULL DEFAULT 0,
  UNIQUE (location_id, name)
);

-- Which staff may submit for a given location (Shelly + Audrey for Office, etc.)
CREATE TABLE inv_location_assignments (
  location_id uuid NOT NULL REFERENCES inv_locations(id),
  user_id     uuid NOT NULL REFERENCES profiles(id),
  PRIMARY KEY (location_id, user_id)
);


-- ── Asset Register ────────────────────────────────────────────────────────
-- The source of truth for everything Sparrow currently owns.
-- Monthly submissions update this register when approved.
-- Batch items: one record per batch_category per location; quantity/unit_cost
--   are updated cumulatively as new batch additions are approved.
-- Individual items: one record per item (or item set with a shared qty).

CREATE TABLE inv_items (
  id               uuid               PRIMARY KEY DEFAULT gen_random_uuid(),
  location_id      uuid               NOT NULL REFERENCES inv_locations(id),
  sub_location_id  uuid               REFERENCES inv_sub_locations(id),
  description      text               NOT NULL,
  serial_number    text,
  is_batch         boolean            NOT NULL DEFAULT false,
  batch_category   text,
  condition        inv_item_condition NOT NULL,
  is_donated       boolean            NOT NULL DEFAULT false,
  quantity         int                NOT NULL DEFAULT 1 CHECK (quantity >= 0),
  unit_cost        numeric(10,2)      NOT NULL CHECK (unit_cost >= 0),
  cost_source      inv_cost_source    NOT NULL DEFAULT 'known',
  status           inv_item_status    NOT NULL DEFAULT 'active',
  acquired_date    date,
  removed_date     date,
  notes            text,
  created_at       timestamptz        NOT NULL DEFAULT now(),
  updated_at       timestamptz        NOT NULL DEFAULT now(),
  created_by       uuid               REFERENCES profiles(id),
  last_modified_by uuid               REFERENCES profiles(id)
);

CREATE INDEX inv_items_location_idx ON inv_items (location_id);
CREATE INDEX inv_items_status_idx   ON inv_items (status);

CREATE TRIGGER set_inv_items_updated_at
  BEFORE UPDATE ON inv_items
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- Full audit trail for every change to a register item
CREATE TABLE inv_item_history (
  id            uuid            PRIMARY KEY DEFAULT gen_random_uuid(),
  item_id       uuid            NOT NULL REFERENCES inv_items(id),
  change_type   inv_change_type NOT NULL,
  old_values    jsonb,
  new_values    jsonb,
  changed_by    uuid            REFERENCES profiles(id),
  submission_id uuid,           -- FK added below after monthly_submissions exists
  changed_at    timestamptz     NOT NULL DEFAULT now()
);


-- ── Monthly Submissions ───────────────────────────────────────────────────
-- One record per location per calendar month.
-- Staff create a draft, fill in Section A (additions) and/or Section B
-- (removals), then submit. Susanna reviews, edits if needed, and approves —
-- which triggers inv_approve_submission() to commit changes to the register.

CREATE TABLE inv_monthly_submissions (
  id              uuid           PRIMARY KEY DEFAULT gen_random_uuid(),
  location_id     uuid           NOT NULL REFERENCES inv_locations(id),
  period_month    int            NOT NULL CHECK (period_month BETWEEN 1 AND 12),
  period_year     int            NOT NULL CHECK (period_year >= 2020),
  submitted_by    uuid           REFERENCES profiles(id),
  submitted_at    timestamptz,
  status          inv_sub_status NOT NULL DEFAULT 'draft',
  -- Section resolution: staff must resolve both before submitting.
  -- A section is resolved when it has ≥1 entry OR its "nothing" flag is true.
  nothing_came_in boolean        NOT NULL DEFAULT false,
  nothing_left    boolean        NOT NULL DEFAULT false,
  reviewed_by     uuid           REFERENCES profiles(id),
  reviewed_at     timestamptz,
  created_at      timestamptz    NOT NULL DEFAULT now(),
  updated_at      timestamptz    NOT NULL DEFAULT now(),
  UNIQUE (location_id, period_month, period_year)
);

CREATE TRIGGER set_inv_monthly_submissions_updated_at
  BEFORE UPDATE ON inv_monthly_submissions
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- Now that inv_monthly_submissions exists, add the FK from history
ALTER TABLE inv_item_history
  ADD CONSTRAINT fk_inv_item_history_submission
  FOREIGN KEY (submission_id) REFERENCES inv_monthly_submissions(id);


-- Section A — items that arrived this month
CREATE TABLE inv_additions (
  id              uuid               PRIMARY KEY DEFAULT gen_random_uuid(),
  submission_id   uuid               NOT NULL REFERENCES inv_monthly_submissions(id) ON DELETE CASCADE,
  description     text               NOT NULL,
  serial_number   text,
  is_batch        boolean            NOT NULL DEFAULT false,
  batch_category  text,
  condition       inv_item_condition NOT NULL,
  is_donated      boolean            NOT NULL DEFAULT false,
  quantity        int                NOT NULL DEFAULT 1 CHECK (quantity >= 1),
  -- cost + cost_basis: staff enter either per-item or total cost.
  -- inv_approve_submission() normalises to unit_cost before writing to inv_items.
  cost            numeric(10,2)      NOT NULL CHECK (cost >= 0),
  cost_basis      inv_cost_basis     NOT NULL DEFAULT 'per_item',
  cost_source     inv_cost_source    NOT NULL DEFAULT 'known',
  sub_location_id uuid               REFERENCES inv_sub_locations(id),
  notes           text,
  ops_edited      boolean            NOT NULL DEFAULT false,
  inv_item_id     uuid               REFERENCES inv_items(id), -- set on approval
  created_at      timestamptz        NOT NULL DEFAULT now(),
  updated_at      timestamptz        NOT NULL DEFAULT now()
);

CREATE TRIGGER set_inv_additions_updated_at
  BEFORE UPDATE ON inv_additions
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();


-- Section B — items that left this month
CREATE TABLE inv_removals (
  id               uuid            PRIMARY KEY DEFAULT gen_random_uuid(),
  submission_id    uuid            NOT NULL REFERENCES inv_monthly_submissions(id) ON DELETE CASCADE,
  inv_item_id      uuid            REFERENCES inv_items(id), -- null = not yet in seeded register
  description      text            NOT NULL,                  -- free-text (confirmation or fallback)
  serial_number    text,
  quantity_removed int             NOT NULL DEFAULT 1 CHECK (quantity_removed >= 1),
  how_it_left      inv_exit_method NOT NULL,
  notes            text,
  ops_edited       boolean         NOT NULL DEFAULT false,
  created_at       timestamptz     NOT NULL DEFAULT now(),
  updated_at       timestamptz     NOT NULL DEFAULT now()
);

CREATE TRIGGER set_inv_removals_updated_at
  BEFORE UPDATE ON inv_removals
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();


-- Comments — Susanna ↔ staff, can target a whole submission or a specific line
CREATE TABLE inv_comments (
  id            uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  submission_id uuid        NOT NULL REFERENCES inv_monthly_submissions(id) ON DELETE CASCADE,
  addition_id   uuid        REFERENCES inv_additions(id),
  removal_id    uuid        REFERENCES inv_removals(id),
  author_id     uuid        NOT NULL REFERENCES profiles(id),
  body          text        NOT NULL,
  created_at    timestamptz NOT NULL DEFAULT now()
);


-- ── Annual Filing Tracker ─────────────────────────────────────────────────
-- Records when Susanna marked a year as filed with Benton County.
-- The Filing View diffs the current register against the last filing date
-- to show additions (green), removals (red), and updates (yellow).

CREATE TABLE inv_filings (
  id       uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  year     int         NOT NULL UNIQUE CHECK (year >= 2020),
  filed_by uuid        REFERENCES profiles(id),
  filed_at timestamptz NOT NULL DEFAULT now(),
  notes    text
);


-- ── Permission Helpers ────────────────────────────────────────────────────

-- Ops-level access (Susanna, Andrew, Shelly via existing ops_access column)
CREATE OR REPLACE FUNCTION inv_has_ops_access()
RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER
AS $$
  SELECT COALESCE(
    (SELECT ops_access FROM profiles WHERE id = auth.uid()),
    false
  );
$$;

-- Returns true if the current user is assigned to submit for this location
CREATE OR REPLACE FUNCTION inv_can_submit(p_location uuid)
RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER
AS $$
  SELECT EXISTS (
    SELECT 1 FROM inv_location_assignments
    WHERE location_id = p_location
      AND user_id = auth.uid()
  );
$$;


-- ── Approval Function ─────────────────────────────────────────────────────
-- Called by Susanna when she approves a submitted monthly submission.
-- Commits all additions and removals to the live asset register (inv_items).
--
-- Additions:
--   Batch items → merge into existing batch record for that category+location
--     (weighted-average unit cost, summed quantity) or create if none exists.
--   Individual items → always create a new inv_items record.
--
-- Removals:
--   Decrement quantity on the referenced item. If quantity reaches 0, mark removed.

CREATE OR REPLACE FUNCTION inv_approve_submission(p_submission_id uuid)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER
AS $$
DECLARE
  v_sub     inv_monthly_submissions%ROWTYPE;
  v_add     inv_additions%ROWTYPE;
  v_rem     inv_removals%ROWTYPE;
  v_item    inv_items%ROWTYPE;
  v_item_id uuid;
  v_unit_cost  numeric(10,2);
  v_new_qty    int;
  v_new_total  numeric(10,2);
BEGIN
  SELECT * INTO v_sub
    FROM inv_monthly_submissions
    WHERE id = p_submission_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Submission % not found', p_submission_id;
  END IF;
  IF v_sub.status != 'submitted' THEN
    RAISE EXCEPTION 'Submission must be in submitted state to approve (currently: %)', v_sub.status;
  END IF;

  -- ── Process additions ─────────────────────────────────────────────────
  FOR v_add IN SELECT * FROM inv_additions WHERE submission_id = p_submission_id LOOP

    -- Normalise to unit cost regardless of how staff entered it
    v_unit_cost := CASE v_add.cost_basis
      WHEN 'per_item' THEN v_add.cost
      WHEN 'total'    THEN ROUND(v_add.cost / GREATEST(v_add.quantity, 1), 2)
    END;

    IF v_add.is_batch THEN
      -- Look for an existing active batch record at this location for this category
      SELECT * INTO v_item
        FROM inv_items
        WHERE location_id     = v_sub.location_id
          AND is_batch         = true
          AND batch_category   = v_add.batch_category
          AND status           = 'active'
        LIMIT 1;

      IF FOUND THEN
        -- Weighted-average unit cost; summed quantity
        v_new_total := v_item.unit_cost * v_item.quantity + v_unit_cost * v_add.quantity;
        v_new_qty   := v_item.quantity + v_add.quantity;

        UPDATE inv_items SET
          quantity         = v_new_qty,
          unit_cost        = ROUND(v_new_total / v_new_qty, 2),
          updated_at       = now(),
          last_modified_by = auth.uid()
        WHERE id = v_item.id;

        INSERT INTO inv_item_history (item_id, change_type, old_values, new_values, changed_by, submission_id)
        VALUES (
          v_item.id, 'quantity_updated',
          jsonb_build_object('quantity', v_item.quantity, 'unit_cost', v_item.unit_cost),
          jsonb_build_object('quantity', v_new_qty,       'unit_cost', ROUND(v_new_total / v_new_qty, 2)),
          auth.uid(), p_submission_id
        );

        UPDATE inv_additions SET inv_item_id = v_item.id WHERE id = v_add.id;

      ELSE
        -- First addition of this batch category at this location
        INSERT INTO inv_items (
          location_id, sub_location_id, description, is_batch, batch_category,
          condition, is_donated, quantity, unit_cost, cost_source,
          acquired_date, created_by, last_modified_by
        ) VALUES (
          v_sub.location_id, v_add.sub_location_id, v_add.description, true, v_add.batch_category,
          v_add.condition, v_add.is_donated, v_add.quantity, v_unit_cost, v_add.cost_source,
          make_date(v_sub.period_year, v_sub.period_month, 1),
          auth.uid(), auth.uid()
        ) RETURNING id INTO v_item_id;

        INSERT INTO inv_item_history (item_id, change_type, new_values, changed_by, submission_id)
        VALUES (v_item_id, 'acquired', to_jsonb(v_add), auth.uid(), p_submission_id);

        UPDATE inv_additions SET inv_item_id = v_item_id WHERE id = v_add.id;
      END IF;

    ELSE
      -- Individual item — always a new register record
      INSERT INTO inv_items (
        location_id, sub_location_id, description, serial_number, is_batch,
        condition, is_donated, quantity, unit_cost, cost_source,
        acquired_date, created_by, last_modified_by
      ) VALUES (
        v_sub.location_id, v_add.sub_location_id, v_add.description, v_add.serial_number, false,
        v_add.condition, v_add.is_donated, v_add.quantity, v_unit_cost, v_add.cost_source,
        make_date(v_sub.period_year, v_sub.period_month, 1),
        auth.uid(), auth.uid()
      ) RETURNING id INTO v_item_id;

      INSERT INTO inv_item_history (item_id, change_type, new_values, changed_by, submission_id)
      VALUES (v_item_id, 'acquired', to_jsonb(v_add), auth.uid(), p_submission_id);

      UPDATE inv_additions SET inv_item_id = v_item_id WHERE id = v_add.id;
    END IF;

  END LOOP;

  -- ── Process removals ──────────────────────────────────────────────────
  FOR v_rem IN SELECT * FROM inv_removals WHERE submission_id = p_submission_id LOOP
    CONTINUE WHEN v_rem.inv_item_id IS NULL; -- free-text removal, no register record to update

    SELECT * INTO v_item FROM inv_items WHERE id = v_rem.inv_item_id;
    v_new_qty := GREATEST(v_item.quantity - v_rem.quantity_removed, 0);

    UPDATE inv_items SET
      quantity         = v_new_qty,
      status           = CASE WHEN v_new_qty = 0 THEN 'removed'::inv_item_status ELSE 'active' END,
      removed_date     = CASE WHEN v_new_qty = 0 THEN CURRENT_DATE ELSE NULL END,
      updated_at       = now(),
      last_modified_by = auth.uid()
    WHERE id = v_rem.inv_item_id;

    INSERT INTO inv_item_history (item_id, change_type, old_values, new_values, changed_by, submission_id)
    VALUES (
      v_rem.inv_item_id,
      CASE WHEN v_new_qty = 0 THEN 'removed'::inv_change_type ELSE 'quantity_updated' END,
      jsonb_build_object('quantity', v_item.quantity),
      jsonb_build_object('quantity', v_new_qty, 'how_it_left', v_rem.how_it_left),
      auth.uid(), p_submission_id
    );
  END LOOP;

  -- ── Mark approved ─────────────────────────────────────────────────────
  UPDATE inv_monthly_submissions SET
    status      = 'approved',
    reviewed_by = auth.uid(),
    reviewed_at = now()
  WHERE id = p_submission_id;

END;
$$;


-- ── Row Level Security ────────────────────────────────────────────────────

ALTER TABLE inv_locations            ENABLE ROW LEVEL SECURITY;
ALTER TABLE inv_sub_locations        ENABLE ROW LEVEL SECURITY;
ALTER TABLE inv_location_assignments ENABLE ROW LEVEL SECURITY;
ALTER TABLE inv_items                ENABLE ROW LEVEL SECURITY;
ALTER TABLE inv_item_history         ENABLE ROW LEVEL SECURITY;
ALTER TABLE inv_monthly_submissions  ENABLE ROW LEVEL SECURITY;
ALTER TABLE inv_additions            ENABLE ROW LEVEL SECURITY;
ALTER TABLE inv_removals             ENABLE ROW LEVEL SECURITY;
ALTER TABLE inv_comments             ENABLE ROW LEVEL SECURITY;
ALTER TABLE inv_filings              ENABLE ROW LEVEL SECURITY;

-- Locations + sub-locations: all staff can read (needed to render forms)
CREATE POLICY "inv: all staff read locations"
  ON inv_locations FOR SELECT TO authenticated USING (true);
CREATE POLICY "inv: all staff read sub_locations"
  ON inv_sub_locations FOR SELECT TO authenticated USING (true);
CREATE POLICY "inv: all staff read assignments"
  ON inv_location_assignments FOR SELECT TO authenticated USING (true);

-- Asset register
CREATE POLICY "inv: ops reads all items"
  ON inv_items FOR SELECT USING (inv_has_ops_access());
CREATE POLICY "inv: staff reads own location items"
  ON inv_items FOR SELECT USING (inv_can_submit(location_id));
CREATE POLICY "inv: ops manages items"
  ON inv_items FOR ALL USING (inv_has_ops_access());

-- Item history: same visibility as the item itself
CREATE POLICY "inv: ops reads all history"
  ON inv_item_history FOR SELECT USING (inv_has_ops_access());
CREATE POLICY "inv: staff reads own location history"
  ON inv_item_history FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM inv_items i
      WHERE i.id = item_id AND inv_can_submit(i.location_id)
    )
  );

-- Monthly submissions
CREATE POLICY "inv: ops reads all submissions"
  ON inv_monthly_submissions FOR SELECT USING (inv_has_ops_access());
CREATE POLICY "inv: staff reads own submissions"
  ON inv_monthly_submissions FOR SELECT USING (inv_can_submit(location_id));
CREATE POLICY "inv: staff creates own submissions"
  ON inv_monthly_submissions FOR INSERT WITH CHECK (inv_can_submit(location_id));
CREATE POLICY "inv: staff updates own draft submissions"
  ON inv_monthly_submissions FOR UPDATE
  USING (inv_can_submit(location_id) AND status = 'draft');
CREATE POLICY "inv: ops updates any submission"
  ON inv_monthly_submissions FOR UPDATE USING (inv_has_ops_access());

-- Additions
CREATE POLICY "inv: ops manages additions"
  ON inv_additions FOR ALL USING (inv_has_ops_access());
CREATE POLICY "inv: staff manages own draft additions"
  ON inv_additions FOR ALL USING (
    EXISTS (
      SELECT 1 FROM inv_monthly_submissions s
      WHERE s.id = submission_id
        AND inv_can_submit(s.location_id)
        AND s.status = 'draft'
    )
  );
CREATE POLICY "inv: staff reads submitted additions"
  ON inv_additions FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM inv_monthly_submissions s
      WHERE s.id = submission_id AND inv_can_submit(s.location_id)
    )
  );

-- Removals
CREATE POLICY "inv: ops manages removals"
  ON inv_removals FOR ALL USING (inv_has_ops_access());
CREATE POLICY "inv: staff manages own draft removals"
  ON inv_removals FOR ALL USING (
    EXISTS (
      SELECT 1 FROM inv_monthly_submissions s
      WHERE s.id = submission_id
        AND inv_can_submit(s.location_id)
        AND s.status = 'draft'
    )
  );
CREATE POLICY "inv: staff reads submitted removals"
  ON inv_removals FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM inv_monthly_submissions s
      WHERE s.id = submission_id AND inv_can_submit(s.location_id)
    )
  );

-- Comments
CREATE POLICY "inv: ops manages comments"
  ON inv_comments FOR ALL USING (inv_has_ops_access());
CREATE POLICY "inv: staff reads own submission comments"
  ON inv_comments FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM inv_monthly_submissions s
      WHERE s.id = submission_id AND inv_can_submit(s.location_id)
    )
  );
CREATE POLICY "inv: staff posts on own submissions"
  ON inv_comments FOR INSERT WITH CHECK (
    auth.uid() = author_id
    AND EXISTS (
      SELECT 1 FROM inv_monthly_submissions s
      WHERE s.id = submission_id AND inv_can_submit(s.location_id)
    )
  );

-- Filings: ops only
CREATE POLICY "inv: ops manages filings"
  ON inv_filings FOR ALL USING (inv_has_ops_access());


-- ── Seed Data ─────────────────────────────────────────────────────────────

INSERT INTO inv_locations (name, sort_order) VALUES
  ('Office Building',           1),
  ('Outdoor Areas',             2),
  ('Laundry Room',              3),
  ('Shiloh House',              4),
  ('Goshen House',              5),
  ('LCP Home (RV)',             6),
  ('Service Volunteer Trailer', 7);

INSERT INTO inv_sub_locations (location_id, name, sort_order)
SELECT l.id, v.name, v.ord
FROM inv_locations l
JOIN (VALUES
  -- Office Building
  ('Office Building', 'Entry',                      1),
  ('Office Building', 'Main Room',                  2),
  ('Office Building', 'Kitchen',                    3),
  ('Office Building', 'Prayer Room',                4),
  ('Office Building', 'Kids Play Room',             5),
  ('Office Building', 'Bathroom',                   6),
  ('Office Building', 'Blue Office Shed',           7),
  ('Office Building', 'Various',                    8),
  -- Outdoor Areas
  ('Outdoor Areas',   'Steel Shed (office)',         1),
  ('Outdoor Areas',   'Steel Shed (laundry room)',   2),
  ('Outdoor Areas',   'Timber Shed',                 3),
  ('Outdoor Areas',   'Visitor Parking Shed',        4),
  -- LCP Houses share the same room layout
  ('Shiloh House',    'LR',                          1),
  ('Shiloh House',    'Kitchen',                     2),
  ('Shiloh House',    'Master Bedroom',              3),
  ('Shiloh House',    'Kids'' Room',                 4),
  ('Shiloh House',    'Bathroom',                    5),
  ('Shiloh House',    'Porch',                       6),
  ('Shiloh House',    'Various',                     7),
  ('Goshen House',    'LR',                          1),
  ('Goshen House',    'Kitchen',                     2),
  ('Goshen House',    'Master Bedroom',              3),
  ('Goshen House',    'Kids'' Room',                 4),
  ('Goshen House',    'Bathroom',                    5),
  ('Goshen House',    'Porch',                       6),
  ('Goshen House',    'Various',                     7),
  ('LCP Home (RV)',   'LR',                          1),
  ('LCP Home (RV)',   'Kitchen',                     2),
  ('LCP Home (RV)',   'Master Bedroom',              3),
  ('LCP Home (RV)',   'Kids'' Room',                 4),
  ('LCP Home (RV)',   'Bathroom',                    5),
  ('LCP Home (RV)',   'Porch',                       6),
  ('LCP Home (RV)',   'Various',                     7)
) AS v(loc, name, ord) ON l.name = v.loc;

-- Note: Laundry Room and Service Volunteer Trailer have no sub-locations
-- (the whole space is the unit). No rows needed for those.
