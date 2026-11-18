import { createBrowserRouter, Link, Navigate, Outlet } from 'react-router';
import { HOME, RequireUser, useMe } from './api/auth';
import { AuthLayout } from './pages/AuthLayout';
import { LoginPage } from './pages/LoginPage';
import { SetupPage } from './pages/SetupPage';
import { AppShell, type NavItem } from './ui/AppShell';
import { StoreIcon } from './ui/icons';
import { PageHeader } from './ui/PageHeader';
import { Skeleton } from './ui/Skeleton';

/** Bereiche des Anbieters in der Seitenleiste und der Leiste unten. */
export const providerNav: NavItem[] = [{ to: '/betriebe', label: 'Betriebe', icon: <StoreIcon size={22} /> }];

/** `/` führt angemeldet zu den Betrieben, sonst zur Anmeldung. */
function StartRedirect() {
  const me = useMe();
  if (me.data === null) return <Navigate to="/anmelden" replace />;
  if (me.data) return <Navigate to={HOME} replace />;
  if (me.isError) return <Navigate to="/anmelden" replace />;
  return <Skeleton lines={3} label="Wird geladen" />;
}

function AdminLayout() {
  return (
    <RequireUser>
      <AppShell nav={providerNav}>
        <Outlet />
      </AppShell>
    </RequireUser>
  );
}

function BusinessesPage() {
  return <PageHeader title="Betriebe" />;
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
    children: [{ path: '/betriebe', element: <BusinessesPage /> }],
  },
  { path: '*', element: <NotFoundPage /> },
]);
