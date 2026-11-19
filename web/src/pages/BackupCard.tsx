import { useId } from 'react';
import { backupView, useBackup } from '../api/reports';
import { megabytes, moment } from '../format';
import { Button } from '../ui/Button';
import { Card } from '../ui/Card';
import { AlertIcon, CheckCircleIcon } from '../ui/icons';
import { Bone } from '../ui/Skeleton';
import styles from './BackupCard.module.css';

/**
 * Der Stand der nächtlichen Sicherung, oben auf "Fehlerberichte". Lädt und scheitert für sich: ein Fehler hier
 * verdeckt die Berichte nicht. Eine Warnung steht nie nur als Farbe da, sondern mit Symbol und Satz.
 */
export function BackupCard() {
  const titleId = useId();
  const query = useBackup();
  const now = new Date();

  let body;
  if (query.data) {
    const { latest, lastError } = query.data;
    const { tone, stale } = backupView(query.data, now);
    const when = latest && (
      <p className={styles.when}>
        <span>
          Letzte Sicherung: <span className={styles.moment}>{moment(new Date(latest.finishedAt), now)}</span>
        </span>{' '}
        <span className={styles.size}>{megabytes(latest.size)}</span>
      </p>
    );
    if (tone === 'none') {
      body = <p className={styles.none}>Noch keine Sicherung.</p>;
    } else if (tone === 'ok') {
      body = (
        <div className={styles.status}>
          <CheckCircleIcon size={20} className={[styles.icon, styles.ok].join(' ')} />
          <div className={styles.statusText}>{when}</div>
        </div>
      );
    } else {
      // Warnung: Fläche in Warnfarbe, dazu Symbol und Satz, nie nur die Farbe.
      body = (
        <div className={[styles.status, styles.warn].join(' ')} data-testid="backup-warning">
          <AlertIcon size={20} className={styles.icon} />
          <div className={styles.statusText}>
            {when ?? <p className={styles.when}>Noch keine Sicherung.</p>}
            {stale && <p className={styles.sentence}>Die letzte Sicherung ist älter als 36 Stunden.</p>}
            {lastError && (
              <div className={styles.lastError}>
                <p className={styles.errorWhen}>
                  Letzter Fehler: <span className={styles.moment}>{moment(new Date(lastError.at), now)}</span>
                </p>
                {/* Der Text kommt vom Server, ohne Passwort und Adresse; er steht nur als Text da. */}
                <p className={styles.errorText}>{lastError.error}</p>
              </div>
            )}
          </div>
        </div>
      );
    }
  } else if (query.isError) {
    body = (
      <div className={styles.failed}>
        <p className={styles.none}>Der Stand der Sicherung konnte nicht geladen werden.</p>
        <Button variant="secondary" onClick={() => void query.refetch()} busy={query.isFetching}>
          Nochmal versuchen
        </Button>
      </div>
    );
  } else {
    body = (
      <div className={styles.loading} role="status" aria-busy="true">
        <span className="visually-hidden">Sicherung wird geladen</span>
        <Bone className={styles.boneLine} />
        <Bone className={styles.boneShort} />
      </div>
    );
  }

  return (
    <Card className={styles.card} aria-labelledby={titleId}>
      <h2 id={titleId} className={styles.title}>
        Sicherung
      </h2>
      {body}
    </Card>
  );
}
