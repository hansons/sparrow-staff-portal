import { useState, useEffect, useCallback } from 'react';
import { fetchMyLocations, fetchSubmissions } from '@/lib/inventory';
import {
  SUBMISSION_STATUS_META, monthName,
  type InvLocation, type InvMonthlySubmission,
} from '@/lib/inventory-types';
import { MonthlySubmissionForm } from './MonthlySubmissionForm';

interface ActiveForm {
  locationId: string;
  locationName: string;
  month: number;
  year: number;
}

export function StaffSubmissionView({ month, year }: { month: number; year: number }) {
  const [locations, setLocations] = useState<InvLocation[]>([]);
  const [submissions, setSubmissions] = useState<InvMonthlySubmission[]>([]);
  const [loading, setLoading] = useState(true);
  const [err, setErr] = useState('');
  const [active, setActive] = useState<ActiveForm | null>(null);

  const load = useCallback(async () => {
    setLoading(true);
    try {
      const locs = await fetchMyLocations();
      if (locs.length === 0) {
        setLocations([]);
        setLoading(false);
        return;
      }
      const allSubs = await Promise.all(
        locs.map((l) => fetchSubmissions(l.id)),
      );
      setLocations(locs);
      setSubmissions(allSubs.flat());
    } catch (e) {
      setErr(e instanceof Error ? e.message : 'Could not load.');
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => { void load(); }, [load]);

  function getCurrentSub(locationId: string): InvMonthlySubmission | undefined {
    return submissions.find(
      (s) => s.location_id === locationId && s.period_month === month && s.period_year === year,
    );
  }

  function getRecentSubs(locationId: string): InvMonthlySubmission[] {
    return submissions
      .filter((s) => s.location_id === locationId && !(s.period_month === month && s.period_year === year))
      .slice(0, 3);
  }

  if (active) {
    return (
      <MonthlySubmissionForm
        locationId={active.locationId}
        locationName={active.locationName}
        month={active.month}
        year={active.year}
        onSubmitted={() => { void load(); setActive(null); }}
        onBack={() => setActive(null)}
      />
    );
  }

  if (loading) {
    return (
      <div className="flex items-center justify-center h-40 text-sparrow-gray text-sm">
        Loading…
      </div>
    );
  }

  if (err) {
    return <p className="p-4 text-sm text-priority-p1">{err}</p>;
  }

  if (locations.length === 0) {
    return (
      <div className="rounded-xl border border-sparrow-rule bg-sparrow-mist p-6 text-center">
        <p className="text-sm text-sparrow-gray">
          You don't have any inventory locations assigned yet. Contact operations.
        </p>
      </div>
    );
  }

  return (
    <div className="space-y-6">
      {locations.map((loc) => {
        const currentSub = getCurrentSub(loc.id);
        const recentSubs = getRecentSubs(loc.id);

        return (
          <div key={loc.id} className="rounded-xl border border-sparrow-rule bg-white overflow-hidden">
            {/* Location header */}
            <div className="border-b border-sparrow-rule px-4 py-3">
              <h2 className="font-medium text-sparrow-ink text-sm">{loc.name}</h2>
            </div>

            {/* Current month */}
            <div className="px-4 py-3">
              <p className="text-xs font-semibold uppercase tracking-wide text-sparrow-gray mb-2">
                {monthName(month)} {year}
              </p>
              {currentSub ? (
                <button
                  onClick={() => setActive({ locationId: loc.id, locationName: loc.name, month, year })}
                  className="w-full flex items-center justify-between rounded-lg border border-sparrow-rule px-3 py-2.5 text-left hover:bg-sparrow-mist transition"
                >
                  <div className="space-y-0.5">
                    <div className="flex items-center gap-2">
                      <span className={`rounded-full px-2 py-0.5 text-xs font-medium ${SUBMISSION_STATUS_META[currentSub.status].chip}`}>
                        {SUBMISSION_STATUS_META[currentSub.status].label}
                      </span>
                    </div>
                    <p className="text-xs text-sparrow-gray">
                      {currentSub.status === 'draft' && 'Continue filling out your sheet'}
                      {currentSub.status === 'submitted' && 'Awaiting review by Susanna'}
                      {currentSub.status === 'approved' && 'Approved — no action needed'}
                    </p>
                  </div>
                  <span className="text-sparrow-gray">›</span>
                </button>
              ) : (
                <button
                  onClick={() => setActive({ locationId: loc.id, locationName: loc.name, month, year })}
                  className="w-full rounded-lg border border-dashed border-sparrow-rule px-3 py-2.5 text-sm text-sparrow-gray hover:border-sparrow-green/50 hover:text-sparrow-green transition text-left"
                >
                  Start {monthName(month)} submission →
                </button>
              )}
            </div>

            {/* Recent history */}
            {recentSubs.length > 0 && (
              <div className="border-t border-sparrow-rule px-4 py-2.5">
                <p className="text-xs text-sparrow-gray mb-1.5">Recent</p>
                <div className="space-y-1">
                  {recentSubs.map((s) => (
                    <button
                      key={s.id}
                      onClick={() => setActive({
                        locationId: loc.id,
                        locationName: loc.name,
                        month: s.period_month,
                        year: s.period_year,
                      })}
                      className="w-full flex items-center justify-between text-xs text-sparrow-gray hover:text-sparrow-ink transition py-0.5"
                    >
                      <span>{monthName(s.period_month)} {s.period_year}</span>
                      <span className={`rounded-full px-1.5 py-0.5 ${SUBMISSION_STATUS_META[s.status].chip}`}>
                        {SUBMISSION_STATUS_META[s.status].label}
                      </span>
                    </button>
                  ))}
                </div>
              </div>
            )}
          </div>
        );
      })}
    </div>
  );
}
