import { createClient } from '@supabase/supabase-js';

const url = import.meta.env.VITE_SUPABASE_URL as string | undefined;
const anonKey = import.meta.env.VITE_SUPABASE_ANON_KEY as string | undefined;

/** Whether the Supabase env vars are present (used to show a setup notice). */
export const isSupabaseConfigured = Boolean(url && anonKey);

// One browser client for the whole app. Placeholder values keep construction safe
// before the project is connected; the UI gates on isSupabaseConfigured so no real
// call is made until env vars exist. Auth options handle the OAuth redirect return.
export const supabase = createClient(url ?? 'http://localhost:54321', anonKey ?? 'public-anon-key', {
  auth: {
    persistSession: true,
    autoRefreshToken: true,
    detectSessionInUrl: true,
  },
});
