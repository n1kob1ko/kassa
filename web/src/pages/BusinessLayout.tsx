import type { CSSProperties } from 'react';
import { Navigate, Outlet, useOutletContext, useParams } from 'react-router';
import { useMe } from '../api/auth';
import { useBusiness, type BusinessDetail } from '../api/businesses';
import { fileUrl } from '../api/files';
import { EmptyState } from '../ui/EmptyState';
import { LoadError, ListSkeleton } from '../ui/DataList';
import styles from './BusinessLayout.module.css';

export type BusinessContext = { detail: BusinessDetail; isProvider: boolean };

/** Der Betrieb und die Rolle für die Seiten darunter. */
export function useBusinessContext(): BusinessContext {
  return useOutletContext<BusinessContext>();
}

/**
 * Der Name des Betriebs für die Zeile unter dem Seitentitel, mit dem Logo davor, sobald es eines gibt (32 px,
 * Hauptfarbe als Platzhalter). Das Bild hat kein `alt`: der Name steht daneben.
 */
export function BusinessName() {
  const { business } = useBusinessContext().detail;
  const logo = business.logo;
  return (
    <span className={styles.name}>
      {logo && (
        <span className={styles.logo} style={{ '--placeholder': logo.color } as CSSProperties}>
          <img
            key={logo.id}
            data-testid="business-logo"
            className={styles.logoImage}
            src={fileUrl(business.id, logo.id)}
            alt=""
            width={32}
            height={32}
            decoding="async"
            onLoad={(e) => {
              e.currentTarget.dataset.loaded = 'true';
            }}
          />
        </span>
      )}
      <span className={styles.text}>{business.name}</span>
    </span>
  );
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
