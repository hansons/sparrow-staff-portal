-- Sparrow — Partnerships Room: add a partner's physical / mailing address.
-- Run AFTER 0010_lcp_resources.sql.
--
-- 0008 modeled reach as email + phone only. But partners also get letters and cards (the
-- 'letter' touchpoint method) — donor thank-yous, church mailings — so they need somewhere
-- to hold a mailing address. One nullable free-text column carries the full multi-line
-- address, matching the room's flat-text style (email, phone, source). Additive and
-- nullable — no existing query selects it, so current reads/writes are unaffected.

alter table partners add column address text;   -- full mailing address (multi-line); null = none on file
