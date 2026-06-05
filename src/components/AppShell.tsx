import { useState } from 'react';
import { useAuth } from '@/auth/AuthContext';
import { ChatProvider } from '@/chat/ChatContext';
import { Header } from './Header';
import { Sidebar, type View } from './Sidebar';
import { WidgetHome } from './home/WidgetHome';
import { TasksView } from '@/pages/TasksView';
import { CalendarView } from '@/pages/CalendarView';
import { MessagesView } from '@/pages/MessagesView';
import { SettingsView } from '@/pages/SettingsView';
import { TwinOaksRoom } from './twinoaks/TwinOaksRoom';
import { LcpRoom } from './lcp/LcpRoom';
import { PartnershipsRoom } from './partnerships/PartnershipsRoom';
import { OperationsRoom } from './ops/OperationsRoom';
import { StaffAdmin } from './admin/StaffAdmin';
import { ValuesFooter } from './ValuesFooter';

export function AppShell() {
  const { profile } = useAuth();
  const [view, setView] = useState<View>('home');
  const [navOpen, setNavOpen] = useState(false);

  if (!profile) return null;
  const isAdmin = profile.role === 'admin';
  // Phase 1: the LCP Room serves full LCP staff (Shelly, Audrey, Andrew). Extended
  // read-only access (Bethany, Susanna) lands in Phase 2 (Stories & Prayer).
  const lcpAccess = profile.lcp_role === 'full';
  // CRM-facing roles see the Partnerships Room nav: partnerships staff (Bethany), admins
  // (Andrew, Susanna), and anyone granted the per-person flag in the Staff panel (e.g. FST /
  // volunteer leads). Named owners without the flag still reach their own partners via the
  // tasks the room emits to their triage inbox (RLS scopes their direct access by ownership).
  const partnershipsAccess =
    isAdmin || profile.department === 'partnerships' || profile.partnerships_access;
  // Operations Room (staff management): Andrew, Susanna, Shelly (set via ops_access).
  const opsAccess = profile.ops_access;

  return (
    <ChatProvider>
      <div className="flex min-h-screen flex-col">
        <Header profile={profile} onMenu={() => setNavOpen(true)} onNavigate={setView} />
        <div className="flex flex-1">
          <Sidebar
            view={view}
            isAdmin={isAdmin}
            lcpAccess={lcpAccess}
            partnershipsAccess={partnershipsAccess}
            opsAccess={opsAccess}
            onNavigate={setView}
            open={navOpen}
            onClose={() => setNavOpen(false)}
          />
          <main className="flex-1">
            {view === 'home' && <WidgetHome onNavigate={setView} />}
            {view === 'tasks' && <TasksView />}
            {view === 'calendar' && <CalendarView />}
            {view === 'messages' && <MessagesView />}
            {view === 'settings' && <SettingsView />}
            {view === 'twin-oaks' && <TwinOaksRoom />}
            {view === 'lcp' && <LcpRoom />}
            {view === 'partnerships' && <PartnershipsRoom />}
            {view === 'operations' && <OperationsRoom />}
            {view === 'staff' && <StaffAdmin />}
          </main>
        </div>
        <ValuesFooter />
      </div>
    </ChatProvider>
  );
}
