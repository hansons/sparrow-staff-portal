import { useState } from 'react';
import { useAuth } from '@/auth/AuthContext';
import { StaffSubmissionView } from './StaffSubmissionView';
import { OpsSubmissionsView } from './OpsSubmissionsView';
import { FilingView } from './FilingView';
import { ConsumablesForm } from './ConsumablesForm';

type OpsTab = 'submissions' | 'filing' | 'consumables' | 'register';

export function InventoryRoom() {
  const { profile } = useAuth();
  const isOps = profile?.ops_access ?? false;

  const now = new Date();
  const month = now.getMonth() + 1;
  const year = now.getFullYear();

  const [opsTab, setOpsTab] = useState<OpsTab>('submissions');

  const tabBase = 'px-4 py-2 text-sm font-medium border-b-2 transition';
  const tabActive = 'border-sparrow-green text-sparrow-green';
  const tabIdle = 'border-transparent text-sparrow-gray hover:text-sparrow-ink';

  return (
    <div className="flex flex-col h-full">
      {/* Room header */}
      <div className="border-b border-sparrow-rule px-6 py-5">
        <div className="flex items-start justify-between gap-4">
          <div>
            <h1 className="font-serif text-2xl font-semibold">Property Inventory</h1>
            <p className="text-sm text-sparrow-gray mt-0.5">
              {isOps
                ? 'Review and approve monthly submissions · Manage the asset register'
                : 'Log additions and removals for your area each month'}
            </p>
          </div>
          <span className="shrink-0 rounded-full border border-sparrow-rule px-3 py-1 text-xs text-sparrow-gray">
            {new Date(year, month - 1).toLocaleString('default', { month: 'long', year: 'numeric' })}
          </span>
        </div>

        {isOps && (
          <div className="flex gap-1 mt-4 -mb-[1px]">
            <button
              onClick={() => setOpsTab('submissions')}
              className={`${tabBase} ${opsTab === 'submissions' ? tabActive : tabIdle}`}
            >
              Submissions
            </button>
            <button
              onClick={() => setOpsTab('filing')}
              className={`${tabBase} ${opsTab === 'filing' ? tabActive : tabIdle}`}
            >
              Benton County Filing
            </button>
            <button
              onClick={() => setOpsTab('consumables')}
              className={`${tabBase} ${opsTab === 'consumables' ? tabActive : tabIdle}`}
            >
              Consumables
            </button>
            <button
              onClick={() => setOpsTab('register')}
              className={`${tabBase} ${opsTab === 'register' ? tabActive : tabIdle}`}
            >
              Asset Register
              <span className="ml-2 rounded-full bg-sparrow-rule/60 px-1.5 py-0.5 text-[10px] font-medium uppercase text-sparrow-gray">
                Soon
              </span>
            </button>
          </div>
        )}
      </div>

      {/* Room content */}
      <div className="flex-1 overflow-y-auto px-6 py-5">
        {isOps ? (
          opsTab === 'submissions' ? (
            <OpsSubmissionsView month={month} year={year} />
          ) : opsTab === 'filing' ? (
            <FilingView />
          ) : opsTab === 'consumables' ? (
            <ConsumablesForm />
          ) : (
            <div className="rounded-xl border border-sparrow-rule bg-sparrow-mist p-8 text-center">
              <p className="text-sm text-sparrow-gray">
                The full asset register view is coming soon.
              </p>
            </div>
          )
        ) : (
          <StaffSubmissionView month={month} year={year} />
        )}
      </div>
    </div>
  );
}
