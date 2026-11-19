import { useRef, type ReactNode } from 'react';
import { NavLink, useLocation, useNavigate } from 'react-router';
import { useLogout, useMe } from '../api/auth';
import { Dialog } from './Dialog';
import { toast } from './Toast';
import { ChevronRightIcon, GridIcon, LogOutIcon } from './icons';
import { Logo } from './Logo';
import styles from './AppShell.module.css';

export type NavItem = {
  to: string;
  label: string;
  icon: ReactNode;
  /** Kürzere Beschriftung für die Leiste unten am Handy ("Tage" statt "Tagesabschlüsse"). */
  shortLabel?: string;
  /** Am Rechner in der Reihe wie die anderen, am Handy immer unter "Mehr" (der Weg zu "Alle Betriebe"). */
  phoneInMore?: boolean;
};

/** So viele Ziele passen in die Leiste unten. Sind es mehr Bereiche, zeigt sie vier und "Mehr". */
const BAR_TARGETS = 5;

/** Die Bereiche für die Leiste unten und für das Blatt "Mehr". */
export function splitForPhone(nav: NavItem[]): { bar: NavItem[]; more: NavItem[] } {
  if (nav.length <= BAR_TARGETS) return { bar: nav, more: [] };
  const regular = nav.filter((item) => !item.phoneInMore);
  const bar = regular.slice(0, BAR_TARGETS - 1);
  return { bar, more: [...regular.slice(BAR_TARGETS - 1), ...nav.filter((item) => item.phoneInMore)] };
}

/**
 * Das Blatt "Mehr" ist ein Eintrag im Verlauf: Zurück am Handy schließt es. Der Eintrag trägt die Kennung dieses
 * Ladens der Seite; nach dem Neuladen passt sie nicht mehr, und das Blatt bleibt zu.
 */
type MoreState = { more?: string } | null;
const PAGE_LOAD = Math.random().toString(36).slice(2);

function isCurrent(pathname: string, to: string): boolean {
  return pathname === to || pathname.startsWith(`${to}/`);
}

export type AppShellProps = {
  nav: NavItem[];
  children: ReactNode;
};

/**
 * Rahmen jeder Seite nach der Anmeldung. Ab 1024 px eine Seitenleiste mit den Bereichen und dem Konto,
 * darunter eine Kopfzeile mit Logo und "Abmelden" und unten eine Leiste mit den Bereichen.
 */
export function AppShell({ nav, children }: AppShellProps) {
  const me = useMe();
  const logout = useLogout();
  const signOut = () =>
    logout.mutate(undefined, {
      onError: (err) => toast.show(err.message),
    });

  const location = useLocation();
  const navigate = useNavigate();
  const { bar, more } = splitForPhone(nav);
  const moreOpen = (location.state as MoreState)?.more === PAGE_LOAD && more.length > 0;
  const moreButton = useRef<HTMLButtonElement>(null);
  const moreCurrent = more.some((item) => isCurrent(location.pathname, item.to));

  const openMore = () => navigate({ pathname: location.pathname, search: location.search, hash: location.hash }, { state: { more: PAGE_LOAD } });
  const closeMore = () => navigate(-1);

  const links = (items: NavItem[], className: string, short = false) =>
    items.map((item) => (
      <NavLink
        key={item.to}
        to={item.to}
        className={({ isActive }) => [className, isActive ? styles.active : ''].filter(Boolean).join(' ')}
        aria-label={short && item.shortLabel ? item.label : undefined}
      >
        <span className={styles.navIcon} aria-hidden="true">
          {item.icon}
        </span>
        <span className={styles.navLabel}>{short ? (item.shortLabel ?? item.label) : item.label}</span>
      </NavLink>
    ));

  return (
    <div className={styles.shell}>
      <a className={styles.skip} href="#inhalt">
        Zum Inhalt
      </a>

      <aside className={styles.sidebar}>
        <div className={styles.sidebarLogo}>
          <Logo />
        </div>
        <nav className={styles.sideNav} aria-label="Bereiche">
          {links(nav, styles.sideLink!)}
        </nav>
        <div className={styles.account}>
          {me.data && (
            <p className={styles.email} title={me.data.email}>
              {me.data.email}
            </p>
          )}
          <button type="button" className={styles.signOut} onClick={signOut} disabled={logout.isPending}>
            <LogOutIcon size={20} />
            Abmelden
          </button>
        </div>
      </aside>

      <header className={styles.topBar}>
        <Logo compact />
        <button type="button" className={styles.signOut} onClick={signOut} disabled={logout.isPending}>
          <LogOutIcon size={20} />
          Abmelden
        </button>
      </header>

      <main id="inhalt" className={styles.main} tabIndex={-1}>
        {children}
      </main>

      <nav className={styles.bottomBar} aria-label="Bereiche">
        {links(bar, styles.bottomLink!, true)}
        {more.length > 0 && (
          <button
            ref={moreButton}
            type="button"
            className={[styles.bottomLink, moreCurrent ? styles.active : ''].filter(Boolean).join(' ')}
            aria-haspopup="dialog"
            aria-expanded={moreOpen}
            aria-current={moreCurrent ? 'true' : undefined}
            onClick={openMore}
          >
            <span className={styles.navIcon} aria-hidden="true">
              <GridIcon size={22} />
            </span>
            <span className={styles.navLabel}>Mehr</span>
          </button>
        )}
      </nav>

      <Dialog title="Mehr" open={moreOpen} onClose={closeMore} returnFocus={() => moreButton.current}>
        <nav aria-label="Weitere Bereiche">
          <ul className={styles.moreList}>
            {more.map((item) => (
              <li key={item.to}>
                <NavLink
                  to={item.to}
                  // Ersetzt den Eintrag des Blatts: Zurück führt danach zur Seite davor, nicht zum Blatt.
                  replace
                  className={({ isActive }) => [styles.moreLink, isActive ? styles.active : ''].filter(Boolean).join(' ')}
                >
                  <span className={styles.moreIcon} aria-hidden="true">
                    {item.icon}
                  </span>
                  <span className={styles.moreLabel}>{item.label}</span>
                  <ChevronRightIcon size={20} className={styles.moreChevron} />
                </NavLink>
              </li>
            ))}
          </ul>
        </nav>
      </Dialog>
    </div>
  );
}
