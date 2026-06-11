import { useState, useEffect, useCallback } from 'react';
import { fetchAllLocations, fetchAllCurrentPeriodSubmissions } from '@/lib/inventory';
import {
  SUBMISSION_STATUS_META,
  type InvLocation, type InvMonthlySubmission,
} from '@/lib/inventory-types';
import { SubmissionReviewPanel } from './SubmissionReviewPanel';

export function OpsSubmissionsView({ month, year }: { month: number; year: number }) {
  const [locations, setLocations] = useState<InvLocation[]>([]);
  const [submissions, setSubmissions] = useState<InvMonthlySubmission[]>([]);
  const [loading, setLoading] = useState(true);
  const [err, setErr] = useState('');
  const [panelId, setPanelId] = useState<string | null>(null);

  const load = useCallback(async () => {
    setLoading(true);
    try {
      const [locs, subs] = await Promise.all([
        fetchAllLocations(),
        fetchAllCurrentPeriodSubmissions(month, year),
      ]);
      setLocations(locs);
      setSubmissions(subs);
    } catch (e) {
      setErr(e instanceof Error ? e.message : 'Could not load.');
    } finally {
      setLoading(false);
    }
  }, [month, year]);

  useEffect(() => { void load(); }, [load]);

  function getSubmission(locationId: string): InvMonthlySubmission | undefined {
    return submissions.find((s) => s.location_id === locationId);
  }

  const pendingCount = submissions.filter((s) => s.status === 'submitted').length;
  const approvedCount = submissions.filter((s) => s.status === 'approved').length;
  const missingCount = locations.length - submissions.length;

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

  return (
    <>
      {/* Summary bar */}
      <div className="flex flex-wrap gap-4 mb-5">
        {pendingCount > 0 && (
          <div className="flex items-center gap-1.5 text-sm">
            <span className="h-2 w-2 rounded-full bg-priority-p3" />
            <span className="font-medium text-priority-p3">{pendingCount} awaiting review</span>
          </div>
        )}
        {approvedCount > 0 && (
          <div className="flex items-center gap-1.5 text-sm">
            <span className="h-2 w-2 rounded-full bg-sparrow-green" />
            <span className="text-sparrow-gray">{approvedCount} approved</span>
          </div>
        )}
        {missingCount > 0 && (
          <div className="flex items-center gap-1.5 text-sm">
            <span className="h-2 w-2 rounded-full bg-sparrow-rule" />
            <span className="text-sparrow-gray">{missingCount} not yet started</span>
          </div>
        )}
      </div>

      {/* Location rows */}
      <ul className="divide-y divide-sparrow-rule rounded-xl border border-sparrow-rule bg-white overflow-hidden">
        {locations.map((loc) => {
          const sub = getSubmission(loc.id);
          const status = sub?.status;

          return (
            <li key={loc.id}>
              <button
                onClick={() => sub && setPanelId(sub.id)}
                className={`w-full flex items-center gap-4 px-4 py-3.5 text-left transition ${
                  sub ? 'hover:bg-sparrow-mist' : 'cursor-default'
                }`}
              >
                <div className="flex-1 min-w-0">
                  <p className="text-sm font-medium text-sparrow-ink">{loc.name}</p>
                  {sub?.submitter && (
                    <p className="text-xs text-sparrow-gray mt-0.5">
                      {sub.submitter.full_name}
                      {sub.submitted_at &&
                        ` · ${new Date(sub.submitted_at).toLocaleDateString('en-US', { month: 'short', day: 'numeric' })}`}
                    </p>
                  )}
                </div>

                {status ? (
                  <span className={`shrink-0 rounded-full px-2 py-0.5 text-xs font-medium ${SUBMISSION_STATUS_META[status].chip}`}>
                    {SUBMISSION_STATUS_META[status].label}
                  </span>
                ) : (
                  <span className="shrink-0 rounded-full px-2 py-0.5 text-xs font-medium bg-sparrow-mist text-sparrow-gray">
                    Not started
                  </span>
                )}

                {sub && <span className="text-sparrow-gray shrink-0">›</span>}
              </button>
            </li>
          );
        })}
      </ul>

      <SubmissionReviewPanel
        submissionId={panelId}
        open={!!panelId}
        onClose={() => setPanelId(null)}
        onApproved={() => { void load(); setPanelId(null); }}
      />
    </>
  );
}
