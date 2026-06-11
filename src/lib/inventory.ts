import { supabase } from './supabase';
import type {
  InvLocation, InvSubLocation, InvItem,
  InvMonthlySubmission, InvAddition, InvRemoval, InvComment,
  InvItemCondition, InvCostBasis, InvCostSource, InvExitMethod,
  InvBentonSchedule, InvConsumablesSnapshot, InvBatchTally,
} from './inventory-types';

// ── Column sets ───────────────────────────────────────────────────────────

const SUB_COLS = `
  *,
  location:inv_locations(id, name, sort_order),
  submitter:profiles!submitted_by(id, full_name)
`;

const SUB_DETAIL_COLS = `
  *,
  location:inv_locations(id, name, sort_order),
  submitter:profiles!submitted_by(id, full_name),
  additions:inv_additions(*, sub_location:inv_sub_locations(*)),
  removals:inv_removals(*, item:inv_items(id, description, quantity, unit_cost, serial_number)),
  comments:inv_comments(*, author:profiles!author_id(id, full_name))
`;

// ── Locations ─────────────────────────────────────────────────────────────

export async function fetchAllLocations(): Promise<InvLocation[]> {
  const { data, error } = await supabase
    .from('inv_locations')
    .select('id, name, sort_order')
    .order('sort_order');
  if (error) throw new Error(error.message);
  return data ?? [];
}

export async function fetchMyLocations(): Promise<InvLocation[]> {
  const { data, error } = await supabase
    .from('inv_location_assignments')
    .select('location:inv_locations(id, name, sort_order)');
  if (error) throw new Error(error.message);
  const locs = (data ?? []).map((d: any) => d.location).filter(Boolean) as InvLocation[];
  return locs.sort((a, b) => a.sort_order - b.sort_order);
}

export async function fetchSubLocations(locationId: string): Promise<InvSubLocation[]> {
  const { data, error } = await supabase
    .from('inv_sub_locations')
    .select('*')
    .eq('location_id', locationId)
    .order('sort_order');
  if (error) throw new Error(error.message);
  return data ?? [];
}

// ── Asset register ────────────────────────────────────────────────────────

export async function fetchActiveItems(locationId: string): Promise<InvItem[]> {
  const { data, error } = await supabase
    .from('inv_items')
    .select('*, sub_location:inv_sub_locations(*)')
    .eq('location_id', locationId)
    .eq('status', 'active')
    .order('description');
  if (error) throw new Error(error.message);
  return data ?? [];
}

export async function fetchAllActiveItems(): Promise<InvItem[]> {
  const { data, error } = await supabase
    .from('inv_items')
    .select('*, sub_location:inv_sub_locations(*), location:inv_locations(id, name)')
    .eq('status', 'active')
    .order('description');
  if (error) throw new Error(error.message);
  return data ?? [];
}

// ── Monthly submissions ───────────────────────────────────────────────────

export async function fetchSubmissions(locationId?: string): Promise<InvMonthlySubmission[]> {
  let q = supabase
    .from('inv_monthly_submissions')
    .select(SUB_COLS)
    .order('period_year', { ascending: false })
    .order('period_month', { ascending: false });
  if (locationId) q = q.eq('location_id', locationId);
  const { data, error } = await q;
  if (error) throw new Error(error.message);
  return (data ?? []) as InvMonthlySubmission[];
}

export async function fetchAllCurrentPeriodSubmissions(
  month: number,
  year: number,
): Promise<InvMonthlySubmission[]> {
  const { data, error } = await supabase
    .from('inv_monthly_submissions')
    .select(SUB_COLS)
    .eq('period_month', month)
    .eq('period_year', year)
    .order('inv_locations(sort_order)');
  if (error) throw new Error(error.message);
  return (data ?? []) as InvMonthlySubmission[];
}

export async function fetchSubmission(id: string): Promise<InvMonthlySubmission> {
  const { data, error } = await supabase
    .from('inv_monthly_submissions')
    .select(SUB_DETAIL_COLS)
    .eq('id', id)
    .single();
  if (error) throw new Error(error.message);
  return data as InvMonthlySubmission;
}

export async function fetchOrCreateSubmission(
  locationId: string,
  month: number,
  year: number,
): Promise<InvMonthlySubmission> {
  const { data: existing } = await supabase
    .from('inv_monthly_submissions')
    .select(SUB_DETAIL_COLS)
    .eq('location_id', locationId)
    .eq('period_month', month)
    .eq('period_year', year)
    .maybeSingle();
  if (existing) return existing as InvMonthlySubmission;
  const { data, error } = await supabase
    .from('inv_monthly_submissions')
    .insert({ location_id: locationId, period_month: month, period_year: year })
    .select(SUB_DETAIL_COLS)
    .single();
  if (error) throw new Error(error.message);
  return data as InvMonthlySubmission;
}

export async function patchSubmission(
  id: string,
  patch: { nothing_came_in?: boolean; nothing_left?: boolean },
): Promise<void> {
  const { error } = await supabase.from('inv_monthly_submissions').update(patch).eq('id', id);
  if (error) throw new Error(error.message);
}

export async function submitForReview(id: string): Promise<void> {
  const { error } = await supabase
    .from('inv_monthly_submissions')
    .update({ status: 'submitted', submitted_at: new Date().toISOString() })
    .eq('id', id);
  if (error) throw new Error(error.message);
}

export async function approveSubmission(id: string): Promise<void> {
  const { error } = await supabase.rpc('inv_approve_submission', { p_submission_id: id });
  if (error) throw new Error(error.message);
}

// ── Additions ─────────────────────────────────────────────────────────────

export type NewAddition = {
  description: string;
  serial_number?: string | null;
  is_batch: boolean;
  batch_category?: string | null;
  condition: InvItemCondition;
  is_donated: boolean;
  quantity: number;
  cost: number;
  cost_basis: InvCostBasis;
  cost_source: InvCostSource;
  sub_location_id?: string | null;
  notes?: string | null;
};

export async function addAddition(submissionId: string, entry: NewAddition): Promise<InvAddition> {
  const { data, error } = await supabase
    .from('inv_additions')
    .insert({ ...entry, submission_id: submissionId })
    .select('*, sub_location:inv_sub_locations(*)')
    .single();
  if (error) throw new Error(error.message);
  return data as InvAddition;
}

export async function updateAddition(id: string, patch: Partial<NewAddition>): Promise<void> {
  const { error } = await supabase.from('inv_additions').update(patch).eq('id', id);
  if (error) throw new Error(error.message);
}

export async function deleteAddition(id: string): Promise<void> {
  const { error } = await supabase.from('inv_additions').delete().eq('id', id);
  if (error) throw new Error(error.message);
}

// ── Removals ──────────────────────────────────────────────────────────────

export type NewRemoval = {
  inv_item_id?: string | null;
  description: string;
  serial_number?: string | null;
  quantity_removed: number;
  how_it_left: InvExitMethod;
  notes?: string | null;
};

export async function addRemoval(submissionId: string, entry: NewRemoval): Promise<InvRemoval> {
  const { data, error } = await supabase
    .from('inv_removals')
    .insert({ ...entry, submission_id: submissionId })
    .select('*, item:inv_items(id, description, quantity, unit_cost, serial_number)')
    .single();
  if (error) throw new Error(error.message);
  return data as InvRemoval;
}

export async function updateRemoval(id: string, patch: Partial<NewRemoval>): Promise<void> {
  const { error } = await supabase.from('inv_removals').update(patch).eq('id', id);
  if (error) throw new Error(error.message);
}

export async function deleteRemoval(id: string): Promise<void> {
  const { error } = await supabase.from('inv_removals').delete().eq('id', id);
  if (error) throw new Error(error.message);
}

// ── Comments ──────────────────────────────────────────────────────────────

export async function addComment(
  submissionId: string,
  body: string,
  additionId?: string,
  removalId?: string,
): Promise<InvComment> {
  const { data, error } = await supabase
    .from('inv_comments')
    .insert({
      submission_id: submissionId,
      body,
      addition_id: additionId ?? null,
      removal_id: removalId ?? null,
    })
    .select('*, author:profiles!author_id(id, full_name)')
    .single();
  if (error) throw new Error(error.message);
  return data as InvComment;
}

// ── Filings ───────────────────────────────────────────────────────────────

export async function fetchLastFilingYear(): Promise<number | null> {
  const { data } = await supabase
    .from('inv_filings')
    .select('year')
    .order('year', { ascending: false })
    .limit(1)
    .maybeSingle();
  return data?.year ?? null;
}

export async function recordFiling(year: number, notes?: string): Promise<void> {
  const { error } = await supabase
    .from('inv_filings')
    .upsert({ year, notes: notes ?? null, filed_at: new Date().toISOString() });
  if (error) throw new Error(error.message);
}

// ── Filing view data ──────────────────────────────────────────────────────

export interface FilingItem extends Omit<InvItem, 'sub_location'> {
  location: InvLocation;
  sub_location: InvSubLocation | null;
}

export async function fetchFilingData(): Promise<{
  activeItems: FilingItem[];
  removedSinceLastFiling: FilingItem[];
  lastFiling: { year: number; filed_at: string } | null;
}> {
  const [itemsRes, filingRes] = await Promise.all([
    supabase
      .from('inv_items')
      .select('*, location:inv_locations(id, name, sort_order), sub_location:inv_sub_locations(id, name)')
      .order('benton_schedule')
      .order('description'),
    supabase
      .from('inv_filings')
      .select('year, filed_at')
      .order('year', { ascending: false })
      .limit(1)
      .maybeSingle(),
  ]);
  if (itemsRes.error) throw new Error(itemsRes.error.message);

  const lastFiling = filingRes.data ?? null;
  const cutoffDate = lastFiling?.filed_at.slice(0, 10) ?? '2020-01-01';
  const all = (itemsRes.data ?? []) as FilingItem[];

  return {
    activeItems:            all.filter(i => i.status === 'active'),
    removedSinceLastFiling: all.filter(
      i => i.status === 'removed' && !!i.removed_date && i.removed_date > cutoffDate,
    ),
    lastFiling,
  };
}

export async function markFiled(year: number): Promise<number> {
  const { data, error } = await supabase.rpc('inv_mark_filed', { p_year: year });
  if (error) throw new Error(error.message);
  return (data as number) ?? 0;
}

export async function patchItemFiling(
  id: string,
  patch: { benton_schedule?: InvBentonSchedule; filed_as?: string | null; who_has_it?: string | null },
): Promise<void> {
  const { error } = await supabase.from('inv_items').update(patch).eq('id', id);
  if (error) throw new Error(error.message);
}

// ── Consumables (Schedule 2 annual estimates) ─────────────────────────────

export async function fetchConsumablesSnapshot(year: number): Promise<InvConsumablesSnapshot[]> {
  const { data, error } = await supabase
    .from('inv_consumables_snapshots')
    .select('*')
    .eq('year', year)
    .order('category');
  if (error) throw new Error(error.message);
  return (data ?? []) as InvConsumablesSnapshot[];
}

export async function upsertConsumablesSnapshot(
  year: number,
  category: string,
  amount: number,
  notes: string | null,
): Promise<void> {
  const { error } = await supabase
    .from('inv_consumables_snapshots')
    .upsert(
      { year, category, amount, notes, updated_at: new Date().toISOString() },
      { onConflict: 'year,category' },
    );
  if (error) throw new Error(error.message);
}

// ── Batch tallies ─────────────────────────────────────────────────────────

export async function fetchBatchTallies(year: number): Promise<InvBatchTally[]> {
  const { data, error } = await supabase
    .from('inv_batch_tallies')
    .select('*')
    .eq('year', year)
    .order('category');
  if (error) throw new Error(error.message);
  return (data ?? []) as InvBatchTally[];
}

export async function upsertBatchTally(
  year: number,
  category: string,
  patch: { filed_value?: number | null; decision?: 'keep' | 'update' | 'assess' | null; notes?: string | null },
): Promise<void> {
  const { error } = await supabase
    .from('inv_batch_tallies')
    .upsert(
      { year, category, ...patch, updated_at: new Date().toISOString() },
      { onConflict: 'category,year' },
    );
  if (error) throw new Error(error.message);
}

export async function ensureBatchTalliesExist(year: number, categories: readonly string[]): Promise<void> {
  const existing = await fetchBatchTallies(year);
  const existingCats = new Set(existing.map((t) => t.category));
  const missing = categories.filter((c) => !existingCats.has(c));
  if (missing.length === 0) return;
  const { error } = await supabase.from('inv_batch_tallies').insert(
    missing.map((category) => ({ category, year })),
  );
  if (error) throw new Error(error.message);
}
