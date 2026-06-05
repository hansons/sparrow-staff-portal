# Sparrow Staff Portal (System 2)

The internal team dashboard for Sparrow — Slice 1: personal task management with
role-based visibility. **Static React (Vite) SPA + Supabase** (Postgres + Auth +
Row-Level Security). Hosts as static files on **Cloudflare Pages**; Supabase is the
only backend. Destined for `staff.sparrowinc.org`.

> Topology: the browser app talks **directly** to Supabase. There is no Node server —
> Supabase Row-Level Security enforces every permission. So hosting is just static file
> serving (Cloudflare Pages, free) — no Vercel/Railway needed.

> Status: **Slice 1** — auth + personal task system + "My tasks / My team".
> Board/Calendar views, department Rooms, announcements, notifications, and chat are
> sequenced next.

## What you get so far
**Home (personal tasks)**
- Google sign-in restricted to the Sparrow staff roster.
- Tasks in **List / Board / Calendar** views (drag to change status or reschedule; remembers your last view).
- Create/assign tasks (to anyone), priorities (P1–P4), department tags, due dates, comments.
- **My team** view for managers (see/assign reports' tasks).
- **Notification bell** (assignment + comment alerts) and an admin-managed **announcement bar**.

**Twin Oaks Room**
- **Property grid** of all 61 lots, color-coded (green = current · amber = open work order ·
  red = rent overdue · gray = vacant). Click a lot for resident + rent + work orders.
- **ORS rent cap** shown per lot (HB 3054 logic ported from the concept system).
- **Work-order tracker** — create/assign/triage, with priority + status.
- **Resident records are RLS-gated to TOC staff + admins** (others see the grid, not the PII).

Permissions are enforced in the database via RLS — not in app code.

## One-time setup

### 1. Install dependencies
```bash
npm install
```

### 2. Create a Supabase project
Create it under a **Sparrow-owned account** (per the SOW, deliverables become Sparrow's
property). In the dashboard, open **Settings → API** and copy the Project URL and the
`anon` public key.

```bash
cp .env.example .env.local
# paste the two values into .env.local (VITE_SUPABASE_URL / VITE_SUPABASE_ANON_KEY)
```

### 3. Create the schema + seed data
In the Supabase dashboard **SQL Editor**, run, in order:
1. `supabase/migrations/0001_init.sql`   (profiles + tasks)
2. `supabase/migrations/0002_twin_oaks.sql`   (spaces + tenants + work orders)
3. `supabase/migrations/0003_notifications.sql`   (notifications + announcements + triggers)
4. `supabase/seed.sql`   (staff + sample tasks)
5. `supabase/seed_twin_oaks.sql`   (61 lots + sample residents + work orders)
6. `supabase/seed_social.sql`   (sample announcement + notification)

> ⚠️ Before staff sign in, edit `seed.sql` (or the `profiles` rows) so each `email`
> matches the person's **real Google Workspace address**. The email list is the
> sign-in allowlist — anyone not listed is rejected.

### 4. Configure Google sign-in
1. In **Google Cloud Console**, create an OAuth 2.0 Client (Web). Add the authorized
   redirect URI shown in Supabase **Authentication → Providers → Google**
   (`https://<project-ref>.supabase.co/auth/v1/callback`).
2. Paste the Google Client ID + Secret into Supabase's Google provider and enable it.
3. (Recommended) Restrict the OAuth consent screen to the `sparrowinc.org` Workspace.
4. In Supabase **Authentication → URL Configuration**, add your app origins to the
   redirect allow-list: `http://localhost:5173` (dev) and the Pages URL (prod).

### 5. Run it
```bash
npm run dev          # http://localhost:5173
```
For the first look, sign in with an **admin** account (Andrew or Susanna) — admins see
all seeded tasks, so the dashboard is populated immediately.

## Deploy to Cloudflare Pages
```bash
npm run build        # outputs static site to dist/
```
- Connect the repo in Cloudflare Pages (or `wrangler pages deploy dist`).
- **Build command:** `npm run build` · **Output dir:** `dist`
- Set the env vars `VITE_SUPABASE_URL` and `VITE_SUPABASE_ANON_KEY` in the Pages project
  (they're baked into the static bundle at build time).
- `public/_redirects` already handles SPA routing + the OAuth return.
- Point `staff.sparrowinc.org` at the Pages project when ready.

## Verifying Slice 1
- Sign in → personal tasks appear grouped Overdue/Today/This week/Upcoming.
- "New task" → assign to another staff member → it shows on their list with an
  "Assigned by" badge.
- **RLS check:** a non-manager, non-admin cannot read another person's private tasks.

## Notes / next steps
- **PII gate:** Slice 1 stores only staff names/emails + tasks. Before the Twin Oaks
  **Room** (resident data) and the LCP portal (case notes), settle data governance
  (Supabase ownership/region) against SOW §10.1.
- The Twin Oaks Room ports the concept system's ORS data model + rent-cap logic
  (`../_archive/TwinOaks/`). Still to port from there: rent ledger, notice deadlines,
  AMI eligibility, and the locked Financials tab (Andrew + Teresa only).
