import { Button } from './Button';
import styles from './LoadMore.module.css';

export type LoadMoreProps = {
  /** Die nächste Seite lädt gerade: der Knopf zeigt den Kreis und behält seine Breite. */
  busy: boolean;
  /** Die letzte nächste Seite ist gescheitert: die Zeilen bleiben, der Knopf heißt "Nochmal versuchen". */
  failed: boolean;
  /** Der Satz über dem Knopf nach einem Fehler, etwa "Weitere Bons konnten nicht geladen werden." */
  failedText: string;
  onLoad: () => void;
};

/** "Mehr laden" unter einer Liste. Ein Knopf an derselben Stelle: nach einem Fehler bleibt der Fokus auf ihm. */
export function LoadMore({ busy, failed, failedText, onLoad }: LoadMoreProps) {
  return (
    <div className={styles.more}>
      {failed && (
        <p className={styles.error} role="alert">
          {failedText}
        </p>
      )}
      <Button variant="secondary" busy={busy} onClick={onLoad}>
        {failed ? 'Nochmal versuchen' : 'Mehr laden'}
      </Button>
    </div>
  );
}
