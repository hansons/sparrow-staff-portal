import { SignOutButton } from './SignOutButton';
import { NotificationBell } from './NotificationBell';
import type { Profile } from '@/lib/types';

export function Header({ profile }: { profile: Profile }) {
  return (
    <header className="flex items-center justify-between border-b border-sparrow-rule bg-white px-4 py-3 sm:px-6">
      <span className="font-serif text-lg font-semibold text-sparrow-green">Sparrow</span>
      <div className="flex items-center gap-3">
        <NotificationBell />
        <div className="text-right">
          <p className="text-sm font-medium text-sparrow-ink">{profile.full_name}</p>
          <p className="text-xs capitalize text-sparrow-gray">{profile.role}</p>
        </div>
        <SignOutButton />
      </div>
    </header>
  );
}
