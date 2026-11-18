import type { ReactNode } from 'react';
import { NavLink } from 'react-router';
import { useLogout, useMe } from '../api/auth';
import { toast } from './Toast';
import { LogOutIcon } from './icons';
import { Logo } from './Logo';
import styles from './AppShell.module.css';

export type NavItem = { to: string; label: string; icon: ReactNode };

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

  const links = (className: string) =>
    nav.map((item) => (
      <NavLink
        key={item.to}
        to={item.to}
        className={({ isActive }) => [className, isActive ? styles.active : ''].filter(Boolean).join(' ')}
      >
        <span className={styles.navIcon} aria-hidden="true">
          {item.icon}
        </span>
        <span className={styles.navLabel}>{item.label}</span>
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
          {links(styles.sideLink!)}
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
        {links(styles.bottomLink!)}
      </nav>
    </div>
  );
}
