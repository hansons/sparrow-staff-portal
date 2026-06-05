import { SignOutButton } from './SignOutButton';
import { NotificationBell } from './NotificationBell';
import type { Profile } from '@/lib/types';

export function Header({ profile, onMenu }: { profile: Profile; onMenu: () => void }) {
  return (
    <header className="flex items-center justify-between border-b border-sparrow-rule bg-white px-4 py-3 sm:px-6">
      <div className="flex items-center gap-2">
        <button
          onClick={onMenu}
          className="rounded-lg p-2 text-sparrow-gray transition hover:bg-sparrow-mist hover:text-sparrow-ink md:hidden"
          aria-label="Open menu"
        >
          <svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" aria-hidden>
            <line x1="3" y1="6" x2="21" y2="6" />
            <line x1="3" y1="12" x2="21" y2="12" />
            <line x1="3" y1="18" x2="21" y2="18" />
          </svg>
        </button>
        <span className="font-serif text-lg font-semibold text-sparrow-green">Sparrow</span>
      </div>
      <div className="flex items-center gap-3">
        <NotificationBell />
        <div className="hidden text-right sm:block">
          <p className="text-sm font-medium text-sparrow-ink">{profile.full_name}</p>
          <p className="text-xs capitalize text-sparrow-gray">{profile.role}</p>
        </div>
        <SignOutButton />
      </div>
    </header>
  );
}
