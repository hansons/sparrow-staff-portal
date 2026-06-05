import { useState } from 'react';
import { useAuth } from '@/auth/AuthContext';
import { Header } from './Header';
import { Sidebar, type View } from './Sidebar';
import { HomeView } from '@/pages/HomeView';
import { TwinOaksRoom } from './twinoaks/TwinOaksRoom';

export function AppShell() {
  const { profile } = useAuth();
  const [view, setView] = useState<View>('home');

  if (!profile) return null;

  return (
    <div className="flex min-h-screen flex-col">
      <Header profile={profile} />
      <div className="flex flex-1">
        <Sidebar view={view} onNavigate={setView} />
        <main className="flex-1">{view === 'home' ? <HomeView /> : <TwinOaksRoom />}</main>
      </div>
    </div>
  );
}
