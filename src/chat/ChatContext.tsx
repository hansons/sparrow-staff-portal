import { createContext, useCallback, useContext, useEffect, useState, type ReactNode } from 'react';
import { isSupabaseConfigured } from '@/lib/supabase';
import { listConversations, subscribeToMessages, type ChatConversation } from '@/lib/chat';

interface ChatState {
  conversations: ChatConversation[];
  unreadTotal: number;
  loading: boolean;
  refresh: () => void;
}

const ChatContext = createContext<ChatState>({
  conversations: [],
  unreadTotal: 0,
  loading: true,
  refresh: () => {},
});

// Gentle fallback poll so the list/badges stay fresh even where Realtime is off.
const POLL_MS = 20_000;

export function ChatProvider({ children }: { children: ReactNode }) {
  const [conversations, setConversations] = useState<ChatConversation[]>([]);
  const [loading, setLoading] = useState(true);

  // Stable (deps []) so consumers can safely depend on it without re-running effects.
  const refresh = useCallback(async () => {
    if (!isSupabaseConfigured) {
      setLoading(false);
      return;
    }
    try {
      setConversations(await listConversations());
    } catch {
      /* non-critical: keep last good list */
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    if (!isSupabaseConfigured) {
      setLoading(false);
      return;
    }
    void refresh();

    // Realtime delivers instantly (RLS-filtered); the poll + focus refresh are belt-and-suspenders.
    const unsub = subscribeToMessages(() => void refresh());
    const interval = window.setInterval(() => void refresh(), POLL_MS);
    const onFocus = () => void refresh();
    window.addEventListener('focus', onFocus);

    return () => {
      unsub();
      window.clearInterval(interval);
      window.removeEventListener('focus', onFocus);
    };
  }, [refresh]);

  const unreadTotal = conversations.reduce((sum, c) => sum + c.unread, 0);

  return (
    <ChatContext.Provider value={{ conversations, unreadTotal, loading, refresh }}>
      {children}
    </ChatContext.Provider>
  );
}

// eslint-disable-next-line react-refresh/only-export-components
export function useChat() {
  return useContext(ChatContext);
}
