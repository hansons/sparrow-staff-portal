export type View = 'home' | 'twin-oaks' | 'staff';

interface Props {
  view: View;
  isAdmin: boolean;
  onNavigate: (v: View) => void;
  open: boolean; // mobile drawer
  onClose: () => void;
}

function Soon() {
  return (
    <span className="ml-auto rounded-full bg-sparrow-rule/60 px-1.5 py-0.5 text-[10px] font-medium uppercase text-sparrow-gray">
      Soon
    </span>
  );
}

const SOON_ROOMS = ['LifeChange', 'Partnerships', 'Operations'];

function NavContent({
  view,
  isAdmin,
  onNavigate,
}: {
  view: View;
  isAdmin: boolean;
  onNavigate: (v: View) => void;
}) {
  const itemBase = 'flex items-center gap-2 rounded-lg px-3 py-2 text-left transition';
  const active = 'bg-sparrow-sage font-medium text-sparrow-green';
  const idle = 'text-sparrow-gray hover:bg-sparrow-mist hover:text-sparrow-ink';

  return (
    <>
      <nav className="flex flex-1 flex-col gap-1 text-sm">
        <button onClick={() => onNavigate('home')} className={`${itemBase} ${view === 'home' ? active : idle}`}>
          Home
        </button>
        <button onClick={() => onNavigate('home')} className={`${itemBase} ${idle}`}>
          My tasks
        </button>
        <span className={`${itemBase} text-sparrow-gray`}>
          Calendar <Soon />
        </span>

        <div className="my-3 border-t border-sparrow-rule" />
        <p className="px-3 pb-1 text-xs font-semibold uppercase tracking-wide text-sparrow-gray">Rooms</p>
        <button
          onClick={() => onNavigate('twin-oaks')}
          className={`${itemBase} ${view === 'twin-oaks' ? active : idle}`}
        >
          Twin Oaks
        </button>
        {SOON_ROOMS.map((r) => (
          <span key={r} className={`${itemBase} text-sparrow-gray/70`}>
            {r} <Soon />
          </span>
        ))}

        {isAdmin && (
          <>
            <div className="my-3 border-t border-sparrow-rule" />
            <p className="px-3 pb-1 text-xs font-semibold uppercase tracking-wide text-sparrow-gray">Admin</p>
            <button onClick={() => onNavigate('staff')} className={`${itemBase} ${view === 'staff' ? active : idle}`}>
              Staff
            </button>
          </>
        )}
      </nav>

      <span className={`${itemBase} text-sparrow-gray`}>
        Settings <Soon />
      </span>
    </>
  );
}

export function Sidebar({ view, isAdmin, onNavigate, open, onClose }: Props) {
  return (
    <>
      {/* Desktop: static sidebar */}
      <aside className="hidden w-56 shrink-0 flex-col border-r border-sparrow-rule bg-white px-3 py-5 md:flex">
        <NavContent view={view} isAdmin={isAdmin} onNavigate={onNavigate} />
      </aside>

      {/* Mobile: slide-in drawer */}
      <div
        onClick={onClose}
        className={`fixed inset-0 z-40 bg-sparrow-ink/30 transition-opacity md:hidden ${
          open ? 'opacity-100' : 'pointer-events-none opacity-0'
        }`}
        aria-hidden
      />
      <aside
        className={`fixed inset-y-0 left-0 z-50 flex w-64 flex-col border-r border-sparrow-rule bg-white px-3 py-5 transition-transform md:hidden ${
          open ? 'translate-x-0' : '-translate-x-full'
        }`}
      >
        <NavContent
          view={view}
          isAdmin={isAdmin}
          onNavigate={(v) => {
            onNavigate(v);
            onClose();
          }}
        />
      </aside>
    </>
  );
}
