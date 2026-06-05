import { calculateMaxRent, getRentCap } from '@/lib/compliance/rentCap';
import type { Space, Tenant } from '@/lib/housing-types';
import type { WorkOrderWithAssignee } from '@/lib/housing';

interface Props {
  open: boolean;
  space: Space | null;
  tenant: Tenant | null;
  workOrders: WorkOrderWithAssignee[];
  canManage: boolean;
  onClose: () => void;
  onNewWorkOrder: (spaceId: string) => void;
  onSelectWorkOrder: (wo: WorkOrderWithAssignee) => void;
}

const money = (n: number) => `$${n.toLocaleString(undefined, { minimumFractionDigits: 0 })}`;

export function LotDetailPanel({
  open,
  space,
  tenant,
  workOrders,
  canManage,
  onClose,
  onNewWorkOrder,
  onSelectWorkOrder,
}: Props) {
  const year = new Date().getFullYear();

  return (
    <>
      <div
        onClick={onClose}
        className={`fixed inset-0 z-40 bg-sparrow-ink/30 transition-opacity ${
          open ? 'opacity-100' : 'pointer-events-none opacity-0'
        }`}
        aria-hidden
      />
      <aside
        role="dialog"
        aria-modal="true"
        className={`fixed inset-y-0 right-0 z-50 flex w-full max-w-md flex-col bg-white shadow-xl transition-transform ${
          open ? 'translate-x-0' : 'translate-x-full'
        }`}
      >
        {space && (
          <>
            <div className="flex items-center justify-between border-b border-sparrow-rule px-5 py-4">
              <h2 className="font-serif text-lg font-semibold">Lot {space.label}</h2>
              <button onClick={onClose} className="btn-ghost" aria-label="Close">
                ✕
              </button>
            </div>

            <div className="flex-1 space-y-5 overflow-y-auto px-5 py-4 text-sm">
              <div className="flex flex-wrap gap-2">
                <span className="rounded-full bg-sparrow-mist px-2 py-0.5 text-xs capitalize text-sparrow-gray">
                  {space.status}
                </span>
                <span className="rounded-full bg-sparrow-mist px-2 py-0.5 text-xs text-sparrow-gray">
                  {space.type === 'rv' ? 'RV' : 'Manufactured home'}
                </span>
                {space.rent_status === 'overdue' && (
                  <span className="rounded-full bg-red-100 px-2 py-0.5 text-xs font-medium text-red-700">
                    Rent overdue
                  </span>
                )}
              </div>

              {/* Rent + ORS cap (ported compliance logic) */}
              {space.status !== 'vacant' && (
                <div className="rounded-lg border border-sparrow-rule p-3">
                  <p className="field-label">Rent</p>
                  <p className="mt-1 text-base font-semibold text-sparrow-ink">
                    {money(space.current_rent)}/mo
                  </p>
                  <p className="mt-1 text-xs text-sparrow-gray">
                    ORS max next increase:{' '}
                    <span className="font-medium text-sparrow-ink">
                      {money(calculateMaxRent(space.current_rent, year))}/mo
                    </span>{' '}
                    (cap {(getRentCap(year) * 100).toFixed(1)}%, HB 3054)
                  </p>
                </div>
              )}

              {/* Resident (RLS-gated: tenant is null if not permitted or none on file) */}
              <div>
                <p className="field-label">Resident</p>
                {tenant ? (
                  <div className="mt-1 space-y-0.5">
                    <p className="font-medium text-sparrow-ink">{tenant.name}</p>
                    {tenant.phone && <p className="text-sparrow-gray">{tenant.phone}</p>}
                    <p className="text-sparrow-gray">Household of {tenant.household_size}</p>
                    {tenant.move_in_date && (
                      <p className="text-sparrow-gray">Since {tenant.move_in_date}</p>
                    )}
                    {tenant.notes && (
                      <p className="mt-1 rounded bg-sparrow-cream px-2 py-1 text-xs text-sparrow-ink">
                        {tenant.notes}
                      </p>
                    )}
                  </div>
                ) : (
                  <p className="mt-1 text-sparrow-gray">
                    {space.status === 'vacant' ? 'Vacant lot.' : 'No resident on file (or restricted).'}
                  </p>
                )}
              </div>

              {/* Work orders for this lot */}
              <div>
                <div className="flex items-center justify-between">
                  <p className="field-label">Work orders</p>
                  {canManage && (
                    <button
                      onClick={() => onNewWorkOrder(space.id)}
                      className="text-xs font-medium text-sparrow-green hover:underline"
                    >
                      + New
                    </button>
                  )}
                </div>
                {workOrders.length === 0 ? (
                  <p className="mt-1 text-sparrow-gray">None.</p>
                ) : (
                  <ul className="mt-1 divide-y divide-sparrow-rule rounded-lg border border-sparrow-rule">
                    {workOrders.map((w) => (
                      <li key={w.id}>
                        <button
                          onClick={() => onSelectWorkOrder(w)}
                          className="flex w-full items-center justify-between px-3 py-2 text-left hover:bg-sparrow-mist"
                        >
                          <span className="text-sparrow-ink">{w.description}</span>
                          <span className="ml-2 shrink-0 text-xs capitalize text-sparrow-gray">
                            {w.status.replace('_', ' ')}
                          </span>
                        </button>
                      </li>
                    ))}
                  </ul>
                )}
              </div>
            </div>
          </>
        )}
      </aside>
    </>
  );
}
