import type { ReactNode } from 'react';
import { createBrowserRouter, Link, Navigate, Outlet, useMatch } from 'react-router';
import { HOME, RequireUser, useMe } from './api/auth';
import { AuthLayout } from './pages/AuthLayout';
import { BusinessesPage } from './pages/BusinessesPage';
import { BusinessPage } from './pages/BusinessPage';
import { CustomersPage } from './pages/CustomersPage';
import { DaysPage } from './pages/DaysPage';
import { BusinessIndex, BusinessLayout } from './pages/BusinessLayout';
import { LoginPage } from './pages/LoginPage';
import { MenuPage } from './pages/MenuPage';
import { TranslationsPage } from './pages/TranslationsPage';
import { MonthsPage } from './pages/MonthsPage';
import { OverviewPage } from './pages/OverviewPage';
import { ReceiptsPage } from './pages/ReceiptsPage';
import { RegistersPage } from './pages/RegistersPage';
import { ReportsPage } from './pages/ReportsPage';
import { ReleasesPage } from './pages/ReleasesPage';
import { SetupPage } from './pages/SetupPage';
import { StaffPage } from './pages/StaffPage';
import { AppShell, type NavItem } from './ui/AppShell';
import { BookIcon, BugIcon, BuildingIcon, CalendarCheckIcon, ChartIcon, DownloadIcon, LanguagesIcon, ReceiptLinesIcon, SlidersIcon, StoreIcon, TabletIcon, UsersIcon } from './ui/icons';
import { Skeleton } from './ui/Skeleton';

/** Bereiche des Anbieters außerhalb eines Betriebs. */
export const providerNav: NavItem[] = [
  { to: '/betriebe', label: 'Betriebe', icon: <StoreIcon size={22} /> },
  { to: '/installationsdateien', label: 'Installationsdateien', icon: <DownloadIcon size={22} /> },
  { to: '/fehlerberichte', label: 'Fehlerberichte', icon: <BugIcon size={22} /> },
];

/**
 * Bereiche eines Betriebs, so oft genutzt wie gereiht: Umsätze, Bons, Abschlüsse, Speisekarte, Übersetzungen, Kassen,
 * Mitarbeiter, Firmenkunden, Betrieb. Der Anbieter hat davor den Weg zurück zu allen Betrieben (am Handy unter "Mehr").
 */
export function businessNav(businessId: string, provider: boolean): NavItem[] {
  const own: NavItem[] = [
    { to: `/b/${businessId}/umsaetze`, label: 'Umsätze', icon: <ChartIcon size={22} /> },
    { to: `/b/${businessId}/bons`, label: 'Bons', icon: <ReceiptLinesIcon size={22} /> },
    {
      to: `/b/${businessId}/tage`,
      label: 'Abschlüsse',
      shortLabel: 'Abschluss',
      icon: <CalendarCheckIcon size={22} />,
      also: [`/b/${businessId}/monate`],
    },
    { to: `/b/${businessId}/speisekarte`, label: 'Speisekarte', icon: <BookIcon size={22} /> },
    { to: `/b/${businessId}/uebersetzungen`, label: 'Übersetzungen', icon: <LanguagesIcon size={22} /> },
    { to: `/b/${businessId}/kassen`, label: 'Kassen', icon: <TabletIcon size={22} /> },
    { to: `/b/${businessId}/mitarbeiter`, label: 'Mitarbeiter', icon: <UsersIcon size={22} /> },
    { to: `/b/${businessId}/firmenkunden`, label: 'Firmenkunden', icon: <BuildingIcon size={22} /> },
    { to: `/b/${businessId}/betrieb`, label: 'Betrieb', icon: <SlidersIcon size={22} /> },
  ];
  return provider
    ? [{ to: '/betriebe', label: 'Alle Betriebe', icon: <StoreIcon size={22} />, phoneInMore: true }, ...own]
    : own;
}

/** `/` führt angemeldet zu den Betrieben, sonst zur Anmeldung. */
function StartRedirect() {
  const me = useMe();
  if (me.data === null) return <Navigate to="/anmelden" replace />;
  if (me.data) return <Navigate to={HOME} replace />;
  if (me.isError) return <Navigate to="/anmelden" replace />;
  return <Skeleton lines={3} label="Wird geladen" />;
}

/** Die Leiste hängt davon ab, wo man ist und wer man ist: ein Chef sieht nur die Bereiche seines Betriebs. */
function ShellWithNav() {
  const me = useMe();
  const inBusiness = useMatch({ path: '/b/:b', end: false });
  const user = me.data;
  let nav: NavItem[] = providerNav;
  if (user?.role === 'chef') {
    nav = user.businessId ? businessNav(user.businessId, false) : [];
  } else if (inBusiness?.params.b) {
    nav = businessNav(inBusiness.params.b, true);
  }
  return (
    <AppShell nav={nav}>
      <Outlet />
    </AppShell>
  );
}

function AdminLayout() {
  return (
    <RequireUser>
      <ShellWithNav />
    </RequireUser>
  );
}

/** Seiten nur für den Anbieter: ein Chef geht zu den Umsätzen seines Betriebs. Der Server sperrt sie ohnehin. */
function ProviderOnly({ children }: { children: ReactNode }) {
  const me = useMe();
  if (me.data?.role === 'chef') {
    return me.data.businessId ? <Navigate to={`/b/${me.data.businessId}/umsaetze`} replace /> : <Navigate to="/anmelden" replace />;
  }
  return children;
}

function NotFoundPage() {
  return (
    <AuthLayout title="Diese Seite gibt es nicht" lead="Prüf die Adresse oder geh zur Startseite.">
      <Link to="/">Zur Startseite</Link>
    </AuthLayout>
  );
}

export const router = createBrowserRouter([
  { path: '/', element: <StartRedirect /> },
  { path: '/einrichten', element: <SetupPage /> },
  { path: '/anmelden', element: <LoginPage /> },
  {
    element: <AdminLayout />,
    children: [
      {
        path: '/betriebe',
        element: (
          <ProviderOnly>
            <BusinessesPage />
          </ProviderOnly>
        ),
      },
      {
        path: '/installationsdateien',
        element: (
          <ProviderOnly>
            <ReleasesPage />
          </ProviderOnly>
        ),
      },
      {
        path: '/fehlerberichte',
        element: (
          <ProviderOnly>
            <ReportsPage />
          </ProviderOnly>
        ),
      },
      {
        path: '/b/:b',
        element: <BusinessLayout />,
        children: [
          { index: true, element: <BusinessIndex /> },
          { path: 'umsaetze', element: <OverviewPage /> },
          // Das Detail liegt über der Liste: die Seite bleibt dieselbe, sie liest die Kennung aus der Adresse.
          { path: 'bons', element: <ReceiptsPage />, children: [{ path: ':id', element: null }] },
          { path: 'tage', element: <DaysPage />, children: [{ path: ':id', element: null }] },
          { path: 'monate', element: <MonthsPage />, children: [{ path: ':id', element: null }] },
          { path: 'kassen', element: <RegistersPage /> },
          { path: 'mitarbeiter', element: <StaffPage /> },
          { path: 'firmenkunden', element: <CustomersPage /> },
          { path: 'speisekarte', element: <MenuPage /> },
          { path: 'uebersetzungen', element: <TranslationsPage /> },
          { path: 'betrieb', element: <BusinessPage /> },
        ],
      },
    ],
  },
  { path: '*', element: <NotFoundPage /> },
]);
