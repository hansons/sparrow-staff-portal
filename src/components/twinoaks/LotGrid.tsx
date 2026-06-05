import { LOT_COLOR_CLASSES, lotColor, type Space } from '@/lib/housing-types';

interface Props {
  spaces: Space[];
  openWoSpaceIds: Set<string>;
  onSelect: (space: Space) => void;
}

export function LotGrid({ spaces, openWoSpaceIds, onSelect }: Props) {
  return (
    <div className="grid grid-cols-6 gap-2 sm:grid-cols-8 lg:grid-cols-10">
      {spaces.map((s) => {
        const color = lotColor(s, openWoSpaceIds.has(s.id));
        return (
          <button
            key={s.id}
            onClick={() => onSelect(s)}
            title={`Lot ${s.label}`}
            className={`flex aspect-square items-center justify-center rounded-lg border text-sm font-semibold transition hover:ring-2 hover:ring-sparrow-gold ${LOT_COLOR_CLASSES[color]}`}
          >
            {s.label}
          </button>
        );
      })}
    </div>
  );
}
