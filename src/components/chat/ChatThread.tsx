import { useEffect, useRef, useState } from 'react';
import type { ChatMessageWithAuthor } from '@/lib/chat';

function timeLabel(iso: string): string {
  return new Date(iso).toLocaleTimeString(undefined, { hour: 'numeric', minute: '2-digit' });
}

function dayLabel(iso: string): string {
  const d = new Date(iso);
  const today = new Date();
  const isToday = d.toDateString() === today.toDateString();
  if (isToday) return 'Today';
  return d.toLocaleDateString(undefined, { weekday: 'short', month: 'short', day: 'numeric' });
}

export function ChatThread({
  messages,
  meId,
  isGroup,
  onSend,
}: {
  messages: ChatMessageWithAuthor[];
  meId: string;
  isGroup: boolean;
  onSend: (body: string) => Promise<void>;
}) {
  const [draft, setDraft] = useState('');
  const [busy, setBusy] = useState(false);
  const endRef = useRef<HTMLDivElement>(null);

  // Pin to the newest message as the thread grows.
  useEffect(() => {
    endRef.current?.scrollIntoView({ block: 'end' });
  }, [messages.length]);

  async function submit() {
    const body = draft.trim();
    if (!body || busy) return;
    setBusy(true);
    try {
      await onSend(body);
      setDraft('');
    } finally {
      setBusy(false);
    }
  }

  function onKeyDown(e: React.KeyboardEvent<HTMLTextAreaElement>) {
    if (e.key === 'Enter' && !e.shiftKey) {
      e.preventDefault();
      void submit();
    }
  }

  return (
    <div className="flex h-full flex-col">
      <div className="flex-1 space-y-2 overflow-y-auto px-4 py-4">
        {messages.length === 0 ? (
          <p className="mt-8 text-center text-sm text-sparrow-gray">
            No messages yet — say hello.
          </p>
        ) : (
          messages.map((m, i) => {
            const mine = m.author_id === meId;
            const prev = messages[i - 1];
            const newDay = !prev || dayLabel(prev.created_at) !== dayLabel(m.created_at);
            // In group threads, show the sender's name above their first message in a run.
            const showName = isGroup && !mine && (!prev || prev.author_id !== m.author_id || newDay);
            return (
              <div key={m.id}>
                {newDay && (
                  <p className="my-3 text-center text-[11px] font-medium uppercase tracking-wide text-sparrow-gray">
                    {dayLabel(m.created_at)}
                  </p>
                )}
                <div className={`flex ${mine ? 'justify-end' : 'justify-start'}`}>
                  <div className="max-w-[80%]">
                    {showName && (
                      <p className="mb-0.5 pl-1 text-[11px] font-medium text-sparrow-gray">
                        {m.author?.full_name ?? 'Staff'}
                      </p>
                    )}
                    <div
                      className={`rounded-2xl px-3.5 py-2 text-sm ${
                        mine
                          ? 'rounded-br-sm bg-sparrow-green text-white'
                          : 'rounded-bl-sm bg-sparrow-mist text-sparrow-ink'
                      }`}
                    >
                      <p className="whitespace-pre-wrap break-words">{m.body}</p>
                      <p className={`mt-1 text-[10px] ${mine ? 'text-white/70' : 'text-sparrow-gray'}`}>
                        {timeLabel(m.created_at)}
                      </p>
                    </div>
                  </div>
                </div>
              </div>
            );
          })
        )}
        <div ref={endRef} />
      </div>

      <div className="flex items-end gap-2 border-t border-sparrow-rule px-4 py-3">
        <textarea
          value={draft}
          onChange={(e) => setDraft(e.target.value)}
          onKeyDown={onKeyDown}
          rows={1}
          placeholder="Write a message…"
          className="field-input mt-0 max-h-32 flex-1 resize-none"
        />
        <button onClick={() => void submit()} disabled={busy || !draft.trim()} className="btn-primary">
          Send
        </button>
      </div>
    </div>
  );
}
