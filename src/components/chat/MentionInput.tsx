import { useRef, useState } from 'react';
import { initials, type ChatPerson } from '@/lib/chat';

interface Props {
  value: string;
  onChange: (value: string) => void;
  onKeyDown?: (e: React.KeyboardEvent<HTMLTextAreaElement>) => void;
  staff: ChatPerson[];
  disabled?: boolean;
  placeholder?: string;
  className?: string;
}

interface MentionState {
  query: string;
  atPos: number;
}

export function MentionInput({ value, onChange, onKeyDown, staff, disabled, placeholder, className }: Props) {
  const [mention, setMention] = useState<MentionState | null>(null);
  const [selected, setSelected] = useState(0);
  const textareaRef = useRef<HTMLTextAreaElement>(null);

  const filtered = mention
    ? staff
        .filter((p) => {
          const q = mention.query.toLowerCase();
          if (!q) return true;
          const name = p.full_name.toLowerCase();
          return name.startsWith(q) || name.split(' ').some((part) => part.startsWith(q));
        })
        .slice(0, 6)
    : [];

  function handleChange(e: React.ChangeEvent<HTMLTextAreaElement>) {
    const val = e.target.value;
    const cursor = e.target.selectionStart ?? val.length;
    const before = val.slice(0, cursor);
    const atIdx = before.lastIndexOf('@');

    if (atIdx !== -1) {
      const segment = before.slice(atIdx + 1);
      if (!segment.includes(' ') && !segment.includes('\n')) {
        setMention({ query: segment, atPos: atIdx });
        setSelected(0);
        onChange(val);
        return;
      }
    }

    setMention(null);
    onChange(val);
  }

  function insertMention(person: ChatPerson) {
    if (!mention) return;
    const before = value.slice(0, mention.atPos);
    const after = value.slice(mention.atPos + 1 + mention.query.length);
    const newVal = `${before}@${person.full_name} ${after}`;
    onChange(newVal);
    setMention(null);

    const ta = textareaRef.current;
    if (ta) {
      ta.focus();
      const pos = before.length + 1 + person.full_name.length + 1;
      setTimeout(() => ta.setSelectionRange(pos, pos), 0);
    }
  }

  function handleKeyDown(e: React.KeyboardEvent<HTMLTextAreaElement>) {
    if (mention && filtered.length > 0) {
      if (e.key === 'ArrowDown') {
        e.preventDefault();
        setSelected((s) => Math.min(s + 1, filtered.length - 1));
        return;
      }
      if (e.key === 'ArrowUp') {
        e.preventDefault();
        setSelected((s) => Math.max(s - 1, 0));
        return;
      }
      if (e.key === 'Tab' || (e.key === 'Enter' && !e.shiftKey)) {
        e.preventDefault();
        const person = filtered[selected];
        if (person) insertMention(person);
        return;
      }
      if (e.key === 'Escape') {
        e.preventDefault();
        setMention(null);
        return;
      }
    }
    onKeyDown?.(e);
  }

  return (
    <div className="relative flex-1">
      {mention && filtered.length > 0 && (
        <div className="absolute bottom-full left-0 z-50 mb-1 w-56 overflow-hidden rounded-xl border border-sparrow-rule bg-white shadow-lg">
          {filtered.map((p, i) => (
            <button
              key={p.id}
              type="button"
              onMouseDown={(e) => {
                e.preventDefault();
                insertMention(p);
              }}
              className={`flex w-full items-center gap-2 px-3 py-2 text-left text-sm transition ${
                i === selected ? 'bg-sparrow-sage' : 'hover:bg-sparrow-mist'
              }`}
            >
              <span className="flex h-6 w-6 shrink-0 items-center justify-center rounded-full bg-sparrow-green text-[10px] font-semibold text-white">
                {initials(p.full_name)}
              </span>
              <span className="min-w-0 flex-1 truncate font-medium text-sparrow-ink">{p.full_name}</span>
            </button>
          ))}
        </div>
      )}
      <textarea
        ref={textareaRef}
        value={value}
        onChange={handleChange}
        onKeyDown={handleKeyDown}
        onBlur={() => setTimeout(() => setMention(null), 150)}
        rows={1}
        placeholder={placeholder}
        disabled={disabled}
        className={className}
      />
    </div>
  );
}
