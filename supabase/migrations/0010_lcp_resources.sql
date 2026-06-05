-- Sparrow — LifeChange Program: curriculum/resource files (Google Drive links).
-- Run AFTER 0009_lcp_curriculum_fields.sql.
--
-- Decision (2026-06-05): all LCP materials — student handouts, teacher guides, weekly
-- devotionals, PowerPoints, art-therapy exercises, and the House Diagram itself — are
-- hosted on Google Drive. The apps store LINKS ONLY (no uploads, no Supabase Storage).
-- This supersedes the brief's §251 "upload PDF" Curriculum Admin flow: adding material
-- becomes "paste a Drive link."
--
-- Two audience tiers, because LCP families sign in with email+password and are NOT in the
-- sparrowinc.org Google Workspace:
--   • participant — handouts, devotionals, the House Diagram. Shared on Drive as
--     "anyone with the link" (a non-Workspace family can open it). Never put a family
--     name/photo/case detail in one of these — anyone-with-link is permanent + unauditable.
--   • staff       — teacher guides, leader notes. Kept Workspace-restricted on Drive and
--     surfaced only on full-LCP-staff screens (Session Brief / Curriculum Admin).
-- Drive enforces the actual file access; the RLS below just keeps the wrong links off the
-- wrong screen (a family never even sees a teacher-guide row).

create type lcp_resource_kind     as enum ('handout', 'teacher_guide', 'devotional', 'ppt', 'art', 'other');
create type lcp_resource_audience as enum ('participant', 'staff');

create table lcp_resources (
  id         uuid primary key default gen_random_uuid(),
  session_id int references lcp_sessions(id) on delete cascade,  -- null = program-wide (e.g. the House Diagram)
  kind       lcp_resource_kind not null default 'other',
  audience   lcp_resource_audience not null default 'staff',
  title      text not null,
  drive_url  text not null,                                      -- the Google Drive share link / file URL
  created_by uuid references profiles(id) on update cascade on delete set null,
  created_at timestamptz not null default now()
);
create index lcp_resources_session_idx on lcp_resources(session_id);

alter table lcp_resources enable row level security;

-- Read: full LCP staff see every resource; everyone else (participants + extended staff)
-- see only participant-audience materials. Staff-tier rows (teacher guides) never reach a
-- family or extended staff.
create policy lcp_resources_read on lcp_resources for select to authenticated
  using (
    lcp_is_full()
    or (audience = 'participant' and (current_family() is not null or lcp_has_access()))
  );

-- Write: full LCP staff only (Curriculum Admin is Shelly — Phase 2).
create policy lcp_resources_write on lcp_resources for all to authenticated
  using (lcp_is_full()) with check (lcp_is_full());
