// ── Enums & constants ─────────────────────────────────────────────────────

export const BATCH_CATEGORIES = [
  'Misc office supplies (non-consumable)',
  'Misc small hand tools',
  'Misc kitchen supplies',
  'Misc household decor',
  'Misc holiday / seasonal decor',
  'Misc cleaning equipment (non-consumable)',
  'Misc window treatments',
  'Misc books',
  "Misc children's books",
  "Misc children's toys",
  "Children's outdoor toys",
] as const;

export type BatchCategory = (typeof BATCH_CATEGORIES)[number];

export type InvItemStatus    = 'active' | 'removed';
export type InvItemCondition = 'new' | 'used';
export type InvCostSource    = 'known' | 'estimated';
export type InvCostBasis     = 'per_item' | 'total';
export type InvSubStatus     = 'draft' | 'submitted' | 'approved';
export type InvExitMethod    = 'thrown_out' | 'hauled_away' | 'sold' | 'donated_picked_up';

export const EXIT_METHOD_LABELS: Record<InvExitMethod, string> = {
  thrown_out:        'Thrown out / disposed',
  hauled_away:       'Hauled away',
  sold:              'Sold',
  donated_picked_up: 'Donated & picked up',
};

export const SUBMISSION_STATUS_META: Record<InvSubStatus, { label: string; chip: string }> = {
  draft:     { label: 'Draft',     chip: 'bg-sparrow-mist text-sparrow-gray' },
  submitted: { label: 'Submitted', chip: 'bg-priority-p3/15 text-priority-p3' },
  approved:  { label: 'Approved',  chip: 'bg-sparrow-green/10 text-sparrow-green' },
};

// ── Entity types ──────────────────────────────────────────────────────────

export interface InvLocation {
  id: string;
  name: string;
  sort_order: number;
}

export interface InvSubLocation {
  id: string;
  location_id: string;
  name: string;
  sort_order: number;
}

export interface InvItem {
  id: string;
  location_id: string;
  sub_location_id: string | null;
  description: string;
  serial_number: string | null;
  is_batch: boolean;
  batch_category: string | null;
  condition: InvItemCondition;
  is_donated: boolean;
  quantity: number;
  unit_cost: number;
  cost_source: InvCostSource;
  status: InvItemStatus;
  acquired_date: string | null;
  removed_date: string | null;
  notes: string | null;
  created_at: string;
  updated_at: string;
  sub_location?: InvSubLocation;
}

export interface InvMonthlySubmission {
  id: string;
  location_id: string;
  period_month: number;
  period_year: number;
  submitted_by: string | null;
  submitted_at: string | null;
  status: InvSubStatus;
  nothing_came_in: boolean;
  nothing_left: boolean;
  reviewed_by: string | null;
  reviewed_at: string | null;
  created_at: string;
  updated_at: string;
  location?: InvLocation;
  submitter?: { id: string; full_name: string };
  additions?: InvAddition[];
  removals?: InvRemoval[];
  comments?: InvComment[];
}

export interface InvAddition {
  id: string;
  submission_id: string;
  description: string;
  serial_number: string | null;
  is_batch: boolean;
  batch_category: string | null;
  condition: InvItemCondition;
  is_donated: boolean;
  quantity: number;
  cost: number;
  cost_basis: InvCostBasis;
  cost_source: InvCostSource;
  sub_location_id: string | null;
  notes: string | null;
  ops_edited: boolean;
  inv_item_id: string | null;
  created_at: string;
  updated_at: string;
  sub_location?: InvSubLocation;
}

export interface InvRemoval {
  id: string;
  submission_id: string;
  inv_item_id: string | null;
  description: string;
  serial_number: string | null;
  quantity_removed: number;
  how_it_left: InvExitMethod;
  notes: string | null;
  ops_edited: boolean;
  created_at: string;
  updated_at: string;
  item?: Pick<InvItem, 'id' | 'description' | 'quantity' | 'unit_cost' | 'serial_number'>;
}

export interface InvComment {
  id: string;
  submission_id: string;
  addition_id: string | null;
  removal_id: string | null;
  author_id: string;
  body: string;
  created_at: string;
  author?: { id: string; full_name: string };
}

// ── Display helpers ───────────────────────────────────────────────────────

export function monthName(month: number): string {
  return new Date(2000, month - 1, 1).toLocaleString('default', { month: 'long' });
}

export function formatCost(amount: number): string {
  return `$${amount.toLocaleString('en-US', { minimumFractionDigits: 0, maximumFractionDigits: 0 })}`;
}

export function displayAdditionCost(entry: Pick<InvAddition, 'cost' | 'cost_basis' | 'quantity'>): string {
  if (entry.cost_basis === 'per_item' && entry.quantity > 1)
    return `${formatCost(entry.cost)} × ${entry.quantity} = ${formatCost(entry.cost * entry.quantity)}`;
  if (entry.cost_basis === 'total' && entry.quantity > 1)
    return `${formatCost(entry.cost)} total (${entry.quantity} items)`;
  return formatCost(entry.cost);
}

// ── Validation helpers ────────────────────────────────────────────────────

export function isSectionAResolved(
  sub: Pick<InvMonthlySubmission, 'nothing_came_in' | 'additions'>,
): boolean {
  return sub.nothing_came_in || (sub.additions ?? []).length > 0;
}

export function isSectionBResolved(
  sub: Pick<InvMonthlySubmission, 'nothing_left' | 'removals'>,
): boolean {
  return sub.nothing_left || (sub.removals ?? []).length > 0;
}

export function canSubmitForReview(
  sub: Pick<InvMonthlySubmission, 'nothing_came_in' | 'nothing_left' | 'additions' | 'removals'>,
): boolean {
  return isSectionAResolved(sub) && isSectionBResolved(sub);
}
