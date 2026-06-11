-- 0015_onboarding.sql
-- Extend onboarding/offboarding checklists with:
--   • url + estimated_minutes on template items and live steps
--   • Two-level hierarchy (top-level items + subtasks) via parent_id / parent_step_id
--   • Staff can complete their own onboarding checklist (mark status = 'complete')

ALTER TABLE ops_checklist_templates
  ADD COLUMN url               text,
  ADD COLUMN estimated_minutes int,
  ADD COLUMN parent_id         int REFERENCES ops_checklist_templates(id) ON DELETE CASCADE;

ALTER TABLE ops_checklist_steps
  ADD COLUMN url               text,
  ADD COLUMN estimated_minutes int,
  ADD COLUMN parent_step_id    uuid REFERENCES ops_checklist_steps(id) ON DELETE CASCADE;

-- Allow a new hire to mark their own onboarding checklist complete
-- (ops tier already has full access via ops_chk_ops)
CREATE POLICY ops_chk_subject_complete ON ops_checklists FOR UPDATE TO authenticated
  USING     (kind = 'onboarding' AND staff_id = auth.uid())
  WITH CHECK (kind = 'onboarding' AND staff_id = auth.uid());
