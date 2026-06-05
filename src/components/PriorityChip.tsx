import { PRIORITY_META } from '@/lib/tasks';
import type { Priority } from '@/lib/types';

export function PriorityChip({ p }: { p: Priority }) {
  const m = PRIORITY_META[p];
  return (
    <span className={`inline-flex items-center gap-1 text-xs font-semibold ${m.text}`}>
      <span className={`h-2 w-2 rounded-full ${m.dot}`} aria-hidden />
      {m.label}
    </span>
  );
}
