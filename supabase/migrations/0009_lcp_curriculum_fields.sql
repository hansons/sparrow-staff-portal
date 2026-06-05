-- Sparrow — LifeChange Program: capture the "Building Your House" curriculum content.
-- Run AFTER 0008_partnerships.sql, BEFORE the refreshed seed_lcp.sql.
--
-- 0005 modeled the curriculum SKELETON only (phase → room → 48 sessions, counts).
-- Susanna's concept map (INGEST/"LifeChange Program House Diagram.pdf") carries more per
-- room/session: a descriptive focus line, occasional scripture, a per-room month in the
-- 12-month cadence, a tangible artifact produced in most rooms, and one optional
-- supplemental track. These are additive, nullable columns — no existing query selects
-- them, so the staff/participant builds are unaffected; they hold the content the seed
-- now loads and that Phase-2 Curriculum Admin will edit.

-- Per-session content (the descriptive line + any cited scripture).
alter table lcp_sessions add column focus     text;   -- e.g. "Rest as spiritual discipline"
alter table lcp_sessions add column scripture text;   -- e.g. "Prov 4:23"; null where the map cites none

-- Per-room (unit) attributes from the house diagram.
alter table lcp_units add column month_label text;   -- cadence slot, e.g. "Month 3–4"
alter table lcp_units add column artifact    text;   -- tangible produced in the room; null where none
alter table lcp_units add column supplement  text;   -- optional add-on track; null where none
