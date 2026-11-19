import { Navigate, Outlet, useOutletContext, useParams } from 'react-router';
import { useMe } from '../api/auth';
import { useBusiness, type BusinessDetail } from '../api/businesses';
import { EmptyState } from '../ui/EmptyState';
import { LoadError, ListSkeleton } from '../ui/DataList';

export type BusinessContext = { detail: BusinessDetail; isProvider: boolean };

/** Der Betrieb und die Rolle für die Seiten darunter. */
export function useBusinessContext(): BusinessContext {
  return useOutletContext<BusinessContext>();
}

/** Lädt den Betrieb aus der Adresse. Gibt es ihn nicht (oder gehört er nicht zum Chef), steht das im Rahmen. */
export function BusinessLayout() {
  const { b = '' } = useParams();
  const me = useMe();
  const query = useBusiness(b);
  const isProvider = me.data?.role === 'provider';

  if (query.isPending) return <ListSkeleton label="Betrieb wird geladen" />;
  if (query.isError) {
    if (query.error.status === 404) {
      return (
        <EmptyState
          title="Diesen Betrieb gibt es nicht."
          text={isProvider ? 'Prüf die Adresse oder such ihn unter "Alle Betriebe".' : 'Prüf die Adresse oder melde dich bei deinem Anbieter.'}
        />
      );
    }
    return <LoadError message={query.error.message} onRetry={() => void query.refetch()} />;
  }
  return <Outlet context={{ detail: query.data, isProvider } satisfies BusinessContext} />;
}

/** `/b/:b` ohne Bereich führt zu den Umsätzen. */
export function BusinessIndex() {
  return <Navigate to="umsaetze" replace />;
}
