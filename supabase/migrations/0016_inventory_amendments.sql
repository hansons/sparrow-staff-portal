-- ============================================================
-- 0015_inventory_amendments.sql
-- Adds Benton County filing columns + consumables snapshot table
-- ============================================================
-- What changed from the spreadsheet analysis:
--   1. Items need a Benton County schedule (2 / 4 / 5A / 5B)
--   2. Items need per-item filing_status (added / updated / carried_over)
--   3. Items need filed_as (county description override) + who_has_it
--   4. Schedule 2 (consumables) are broad annual estimates, not individual
--      items — handled by a separate inv_consumables_snapshots table
-- ============================================================


-- ── New enums ─────────────────────────────────────────────────────────────

CREATE TYPE inv_benton_schedule AS ENUM ('schedule_2', 'schedule_4', 'schedule_5a', 'schedule_5b');
CREATE TYPE inv_filing_status   AS ENUM ('not_filed', 'added', 'updated', 'carried_over');


-- ── Amend inv_items ───────────────────────────────────────────────────────

ALTER TABLE inv_items
  ADD COLUMN benton_schedule inv_benton_schedule NOT NULL DEFAULT 'schedule_5a',
  ADD COLUMN filing_status   inv_filing_status   NOT NULL DEFAULT 'added',
  ADD COLUMN filed_as        text,
  ADD COLUMN who_has_it      text;


-- ── Schedule 2 — Annual Consumables Snapshot ─────────────────────────────
-- Five fixed categories (Andrew's annual estimates) reported to Benton
-- County as noninventory supplies. These are NOT tracked item-by-item;
-- only the estimated dollar total per category is recorded.

CREATE TABLE inv_consumables_snapshots (
  id         uuid          PRIMARY KEY DEFAULT gen_random_uuid(),
  year       smallint      NOT NULL,
  category   text          NOT NULL,
  amount     numeric(10,2) NOT NULL DEFAULT 0 CHECK (amount >= 0),
  notes      text,
  updated_at timestamptz   NOT NULL DEFAULT now(),
  updated_by uuid          REFERENCES profiles(id),
  UNIQUE (year, category)
);

ALTER TABLE inv_consumables_snapshots ENABLE ROW LEVEL SECURITY;

CREATE POLICY "inv: ops manages consumables snapshots"
  ON inv_consumables_snapshots FOR ALL USING (inv_has_ops_access());

-- Seed 2025 values (from the existing spreadsheet)
INSERT INTO inv_consumables_snapshots (year, category, amount, notes) VALUES
  (2025, 'General Office Supplies',    400.00, 'Paper, pens, ink, envelopes, etc. — Andrew''s estimate'),
  (2025, 'Maintenance Supplies',       200.00, 'Gas, pipes, consumable maintenance items'),
  (2025, 'Operating Supplies',        1000.00, null),
  (2025, 'Spare Parts',                  0.00, 'None on hand'),
  (2025, 'Other Noninventory Supplies',  0.00, null);


-- ── Updated approval function ─────────────────────────────────────────────
-- Now also infers benton_schedule from batch_category and sets filing_status.

CREATE OR REPLACE FUNCTION inv_approve_submission(p_submission_id uuid)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER
AS $$
DECLARE
  v_sub        inv_monthly_submissions%ROWTYPE;
  v_add        inv_additions%ROWTYPE;
  v_rem        inv_removals%ROWTYPE;
  v_item       inv_items%ROWTYPE;
  v_item_id    uuid;
  v_unit_cost  numeric(10,2);
  v_new_qty    int;
  v_new_total  numeric(10,2);
  v_sched      inv_benton_schedule;
BEGIN
  SELECT * INTO v_sub FROM inv_monthly_submissions WHERE id = p_submission_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Submission % not found', p_submission_id;
  END IF;
  IF v_sub.status != 'submitted' THEN
    RAISE EXCEPTION 'Submission must be in submitted state (currently: %)', v_sub.status;
  END IF;

  -- ── Process additions ─────────────────────────────────────────────────
  FOR v_add IN SELECT * FROM inv_additions WHERE submission_id = p_submission_id LOOP

    v_unit_cost := CASE v_add.cost_basis
      WHEN 'per_item' THEN v_add.cost
      WHEN 'total'    THEN ROUND(v_add.cost / GREATEST(v_add.quantity, 1), 2)
    END;

    -- Infer Benton County schedule from batch category; default 5A for everything else
    v_sched := CASE v_add.batch_category
      WHEN 'Misc small hand tools'    THEN 'schedule_5b'::inv_benton_schedule
      WHEN 'Misc books'               THEN 'schedule_4'::inv_benton_schedule
      WHEN 'Misc children''s books'   THEN 'schedule_4'::inv_benton_schedule
      ELSE                                 'schedule_5a'::inv_benton_schedule
    END;

    IF v_add.is_batch THEN
      SELECT * INTO v_item
        FROM inv_items
        WHERE location_id   = v_sub.location_id
          AND is_batch       = true
          AND batch_category = v_add.batch_category
          AND status         = 'active'
        LIMIT 1;

      IF FOUND THEN
        -- Merge into existing batch: weighted-avg cost, summed qty
        -- If the batch was 'carried_over' (previously filed), it's now 'updated'
        v_new_total := v_item.unit_cost * v_item.quantity + v_unit_cost * v_add.quantity;
        v_new_qty   := v_item.quantity + v_add.quantity;

        UPDATE inv_items SET
          quantity         = v_new_qty,
          unit_cost        = ROUND(v_new_total / v_new_qty, 2),
          filing_status    = CASE
                               WHEN filing_status = 'carried_over' THEN 'updated'::inv_filing_status
                               ELSE filing_status
                             END,
          updated_at       = now(),
          last_modified_by = auth.uid()
        WHERE id = v_item.id;

        INSERT INTO inv_item_history
          (item_id, change_type, old_values, new_values, changed_by, submission_id)
        VALUES (
          v_item.id, 'quantity_updated',
          jsonb_build_object('quantity', v_item.quantity, 'unit_cost', v_item.unit_cost),
          jsonb_build_object('quantity', v_new_qty, 'unit_cost', ROUND(v_new_total / v_new_qty, 2)),
          auth.uid(), p_submission_id
        );

        UPDATE inv_additions SET inv_item_id = v_item.id WHERE id = v_add.id;

      ELSE
        -- First time this batch category appears at this location
        INSERT INTO inv_items (
          location_id, sub_location_id, description, is_batch, batch_category,
          condition, is_donated, quantity, unit_cost, cost_source,
          acquired_date, benton_schedule, filing_status,
          created_by, last_modified_by
        ) VALUES (
          v_sub.location_id, v_add.sub_location_id, v_add.description, true, v_add.batch_category,
          v_add.condition, v_add.is_donated, v_add.quantity, v_unit_cost, v_add.cost_source,
          make_date(v_sub.period_year, v_sub.period_month, 1), v_sched, 'added',
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
        acquired_date, benton_schedule, filing_status,
        created_by, last_modified_by
      ) VALUES (
        v_sub.location_id, v_add.sub_location_id, v_add.description, v_add.serial_number, false,
        v_add.condition, v_add.is_donated, v_add.quantity, v_unit_cost, v_add.cost_source,
        make_date(v_sub.period_year, v_sub.period_month, 1), v_sched, 'added',
        auth.uid(), auth.uid()
      ) RETURNING id INTO v_item_id;

      INSERT INTO inv_item_history (item_id, change_type, new_values, changed_by, submission_id)
      VALUES (v_item_id, 'acquired', to_jsonb(v_add), auth.uid(), p_submission_id);

      UPDATE inv_additions SET inv_item_id = v_item_id WHERE id = v_add.id;
    END IF;

  END LOOP;

  -- ── Process removals ──────────────────────────────────────────────────
  FOR v_rem IN SELECT * FROM inv_removals WHERE submission_id = p_submission_id LOOP
    CONTINUE WHEN v_rem.inv_item_id IS NULL;

    SELECT * INTO v_item FROM inv_items WHERE id = v_rem.inv_item_id;
    v_new_qty := GREATEST(v_item.quantity - v_rem.quantity_removed, 0);

    UPDATE inv_items SET
      quantity         = v_new_qty,
      status           = CASE WHEN v_new_qty = 0 THEN 'removed'::inv_item_status ELSE 'active' END,
      removed_date     = CASE WHEN v_new_qty = 0 THEN CURRENT_DATE ELSE NULL END,
      updated_at       = now(),
      last_modified_by = auth.uid()
    WHERE id = v_rem.inv_item_id;

    INSERT INTO inv_item_history
      (item_id, change_type, old_values, new_values, changed_by, submission_id)
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


-- ── Mark a year as officially filed ──────────────────────────────────────
-- Flips all active items with filing_status IN ('added', 'updated') to
-- 'carried_over'. Returns the count of items marked.

CREATE OR REPLACE FUNCTION inv_mark_filed(p_year smallint)
RETURNS int
LANGUAGE plpgsql SECURITY DEFINER
AS $$
DECLARE
  v_count int;
BEGIN
  IF NOT inv_has_ops_access() THEN
    RAISE EXCEPTION 'Insufficient permissions — ops access required';
  END IF;

  UPDATE inv_items
    SET filing_status = 'carried_over', updated_at = now()
    WHERE status = 'active'
      AND filing_status IN ('added', 'updated');

  GET DIAGNOSTICS v_count = ROW_COUNT;

  INSERT INTO inv_filings (year, filed_by, filed_at)
    VALUES (p_year, auth.uid(), now())
    ON CONFLICT (year)
    DO UPDATE SET filed_by = EXCLUDED.filed_by, filed_at = EXCLUDED.filed_at;

  RETURN v_count;
END;
$$;
