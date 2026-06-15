-- ============================================================
-- 0016_batch_tallies.sql
-- ============================================================
-- Changes:
--   1. Fix inv_approve_submission — books/children's books
--      now auto-assign to schedule_5a, not schedule_4.
--      (Sparrow's books are cheap general-use items, not a
--      professional library — Schedule 4 doesn't apply.)
--   2. New inv_batch_tallies table — one row per batch category
--      per filing year. Tracks the dollar value filed with
--      Benton County and the January decision (keep/update/assess).
-- ============================================================


-- ── 1. Fix inv_approve_submission ─────────────────────────────────────────

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

    -- Schedule 5B for small hand tools; everything else (including books) → 5A.
    v_sched := CASE v_add.batch_category
      WHEN 'Misc small hand tools' THEN 'schedule_5b'::inv_benton_schedule
      ELSE                              'schedule_5a'::inv_benton_schedule
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


-- ── 2. Batch tally table ──────────────────────────────────────────────────
-- One row per batch category per filing year.
-- filed_value = dollar amount filed with Benton County that year.
-- decision    = January review outcome: keep (don't update filing),
--               update (file a new amount), or assess (still deciding).

CREATE TABLE IF NOT EXISTS inv_batch_tallies (
  id          uuid                PRIMARY KEY DEFAULT gen_random_uuid(),
  category    text                NOT NULL,
  year        smallint            NOT NULL,
  schedule    inv_benton_schedule NOT NULL DEFAULT 'schedule_5a',
  filed_value numeric(10,2),
  decision    text                CHECK (decision IN ('keep', 'update', 'assess')),
  notes       text,
  updated_at  timestamptz         NOT NULL DEFAULT now(),
  updated_by  uuid                REFERENCES profiles(id),
  UNIQUE (category, year)
);

ALTER TABLE inv_batch_tallies ENABLE ROW LEVEL SECURITY;

CREATE POLICY "inv: ops manages batch tallies"
  ON inv_batch_tallies FOR ALL USING (inv_has_ops_access());

-- Seed 2026 rows.
-- filed_value is null — enter the values from your most recent Benton County filing.
INSERT INTO inv_batch_tallies (category, year, schedule) VALUES
  ('Misc office supplies (non-consumable)',     2026, 'schedule_5a'),
  ('Misc small hand tools',                    2026, 'schedule_5b'),
  ('Misc kitchen supplies',                    2026, 'schedule_5a'),
  ('Misc household decor',                     2026, 'schedule_5a'),
  ('Misc holiday / seasonal decor',            2026, 'schedule_5a'),
  ('Misc cleaning equipment (non-consumable)', 2026, 'schedule_5a'),
  ('Misc books',                               2026, 'schedule_5a'),
  ('Misc children''s books',                   2026, 'schedule_5a'),
  ('Misc children''s toys',                    2026, 'schedule_5a'),
  ('Children''s outdoor toys',                 2026, 'schedule_5a');
