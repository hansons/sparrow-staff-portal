import { useCallback, useEffect, useMemo, useState } from 'react';
import { useAuth } from '@/auth/AuthContext';
import { fetchProfiles } from '@/lib/data';
import type { Profile } from '@/lib/types';
import { fetchPartners, syncDueTouchpointTasks } from '@/lib/partnerships';
import {
  PARTNER_STAGE,
  PARTNER_TYPE,
  STEWARDSHIP,
  dueLabel,
  stewardshipStatus,
  type Partner,
  type PartnerType,
} from '@/lib/partnerships-types';
import { PartnerDetailPanel } from './PartnerDetailPanel';
import { AddPartnerPanel } from './AddPartnerPanel';

type Filter = 'all' | PartnerType;
const FILTERS: { key: Filter; label: string }[] = [
  { key: 'all', label: 'All' },
  { key: 'donor', label: 'Donors' },
  { key: 'church', label: 'Churches' },
  { key: 'community', label: 'Community' },
  { key: 'volunteer', label: 'Volunteers' },
  { key: 'prayer', label: 'Prayer' },
  { key: 'fst', label: 'FST' },
  { key: 'foundation', label: 'Foundations' },
];

// Order the directory by how badly each relationship needs attention.
const STATUS_RANK = { overdue: 0, lapsed: 1, due_soon: 2, no_cadence: 3, on_cadence: 4, inactive: 5 } as const;

export function PartnershipsRoom() {
  const { profile } = useAuth();
  const [partners, setPartners] = useState<Partner[]>([]);
  const [profiles, setProfiles] = useState<Profile[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  const [filter, setFilter] = useState<Filter>('all');
  const [partnerId, setPartnerId] = useState<string | null>(null);
  const [detailOpen, setDetailOpen] = useState(false);
  const [addOpen, setAddOpen] = useState(false);

  const load = useCallback(async () => {
    try {
      const [pp, pr] = await Promise.all([fetchPartners(), fetchProfiles()]);
      setPartners(pp);
      setProfiles(pr);
      // Best-effort: fan overdue touchpoints to their owners' triage inboxes.
      void syncDueTouchpointTasks().catch(() => undefined);
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Could not load partnerships.');
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    void load();
  }, [load]);

  const ownerName = useCallback(
    (id: string | null) => (id ? profiles.find((p) => p.id === id)?.full_name ?? 'Unassigned' : 'Unassigned'),
    [profiles],
  );

  const stats = useMemo(() => {
    let overdue = 0;
    let dueSoon = 0;
    let noCadence = 0;
    let lapsed = 0;
    for (const p of partners) {
      const s = stewardshipStatus(p);
      if (s === 'overdue') overdue++;
      else if (s === 'due_soon') dueSoon++;
      else if (s === 'no_cadence') noCadence++;
      else if (s === 'lapsed') lapsed++;
    }
    return { total: partners.length, overdue, dueSoon, noCadence, lapsed };
  }, [partners]);

  const visible = useMemo(() => {
    const list = filter === 'all' ? partners : partners.filter((p) => p.type === filter);
    return [...list].sort((a, b) => {
      const ra = STATUS_RANK[stewardshipStatus(a)];
      const rb = STATUS_RANK[stewardshipStatus(b)];
      if (ra !== rb) return ra - rb;
      return a.name.localeCompare(b.name);
    });
  }, [partners, filter]);

  function openPartner(id: string) {
    setPartnerId(id);
    setDetailOpen(true);
  }

  const firstOverdue = useMemo(
    () => visible.find((p) => stewardshipStatus(p) === 'overdue'),
    [visible],
  );

  if (loading) return <p className="p-8 text-sm text-sparrow-gray">Loading partnerships…</p>;
  if (error) return <p className="p-8 text-sm text-priority-p1">{error}</p>;

  const selected = partnerId ? partners.find((p) => p.id === partnerId) ?? null : null;

  return (
    <div className="mx-auto max-w-4xl px-4 py-8 sm:px-6">
      <div className="flex items-start justify-between gap-4">
        <div>
          <h1 className="font-serif text-2xl font-semibold">Partnerships</h1>
          <p className="mt-1 text-sm text-sparrow-gray">
            {stats.total} relationships · {stats.overdue} overdue · {stats.dueSoon} due soon
            {stats.noCadence > 0 && ` · ${stats.noCadence} without a cadence`}
          </p>
        </div>
        <button onClick={() => setAddOpen(true)} className="btn-primary shrink-0">
          + Add partner
        </button>
      </div>

      {stats.overdue > 0 && firstOverdue && (
        <div className="mt-4 flex items-center justify-between rounded-xl border border-priority-p1/30 bg-priority-p1/5 px-4 py-3 text-sm">
          <span>
            🔴 {stats.overdue} relationship{stats.overdue > 1 ? 's are' : ' is'} overdue for a touchpoint.
            They've been pushed to each owner's triage inbox.
          </span>
          <button onClick={() => openPartner(firstOverdue.id)} className="shrink-0 font-medium text-sparrow-green">
            Open {firstOverdue.name} →
          </button>
        </div>
      )}

      {stats.noCadence > 0 && (
        <p className="mt-2 rounded-xl border border-slate-300/60 bg-slate-50 px-4 py-2 text-xs text-slate-600">
          {stats.noCadence} relationship{stats.noCadence > 1 ? 's have' : ' has'} no stewardship cadence set — a
          record without a rhythm isn't stewarded. Open it to set one.
        </p>
      )}

      {/* Type filters */}
      <div className="mt-6 flex flex-wrap gap-1.5 text-sm">
        {FILTERS.map((f) => {
          const count = f.key === 'all' ? partners.length : partners.filter((p) => p.type === f.key).length;
          if (count === 0 && f.key !== 'all') return null;
          return (
            <button
              key={f.key}
              onClick={() => setFilter(f.key)}
              className={`rounded-lg border px-3 py-1.5 font-medium transition ${
                filter === f.key
                  ? 'border-sparrow-green bg-sparrow-green text-white'
                  : 'border-sparrow-rule bg-white text-sparrow-gray hover:text-sparrow-ink'
              }`}
            >
              {f.label} <span className="opacity-70">{count}</span>
            </button>
          );
        })}
      </div>

      {/* Partner directory */}
      <div className="mt-5 space-y-2.5">
        {visible.length === 0 && <p className="text-sm text-sparrow-gray">No partners in this view yet.</p>}
        {visible.map((p) => {
          const status = stewardshipStatus(p);
          const st = STEWARDSHIP[status];
          const type = PARTNER_TYPE[p.type];
          return (
            <button
              key={p.id}
              onClick={() => openPartner(p.id)}
              className="flex w-full items-center gap-3 rounded-2xl border border-sparrow-rule bg-white p-4 text-left shadow-card transition hover:border-sparrow-green/40"
            >
              <span className={`h-2.5 w-2.5 shrink-0 rounded-full ${st.dot}`} title={st.label} />
              <div className="min-w-0 flex-1">
                <div className="flex flex-wrap items-center gap-2">
                  <span className="truncate font-medium text-sparrow-ink">{p.name}</span>
                  <span className="text-xs text-sparrow-gray">
                    {type.icon} {type.label}
                  </span>
                  {p.donor_tier === 'major' && (
                    <span className="rounded-full bg-sparrow-gold/20 px-2 py-0.5 text-[10px] font-medium text-sparrow-ink">
                      Major donor
                    </span>
                  )}
                  {(p.stage === 'prospect' || p.stage === 'lapsed') && (
                    <span className={`rounded-full px-2 py-0.5 text-[10px] font-medium ${PARTNER_STAGE[p.stage].chip}`}>
                      {PARTNER_STAGE[p.stage].label}
                    </span>
                  )}
                </div>
                <p className="mt-0.5 text-xs text-sparrow-gray">
                  {ownerName(p.owner_id)} · {dueLabel(p)}
                </p>
              </div>
              <span className={`shrink-0 rounded-full px-2 py-0.5 text-[10px] font-medium ${st.chip}`}>
                {st.label}
              </span>
            </button>
          );
        })}
      </div>

      <PartnerDetailPanel
        open={detailOpen}
        partner={selected}
        profiles={profiles}
        currentUserId={profile?.id ?? ''}
        onClose={() => setDetailOpen(false)}
        onChanged={load}
      />
      <AddPartnerPanel
        open={addOpen}
        profiles={profiles}
        defaultOwnerId={profile?.id ?? null}
        onClose={() => setAddOpen(false)}
        onCreated={load}
      />
    </div>
  );
}
