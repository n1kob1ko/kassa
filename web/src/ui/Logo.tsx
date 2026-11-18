import { ReceiptIcon } from './icons';
import styles from './Logo.module.css';

/** Logo-Kachel und Wortmarke wie in der Kopfleiste der App, dazu "Verwaltung". */
export function Logo({ compact = false }: { compact?: boolean }) {
  return (
    <span className={styles.logo}>
      <span className={styles.tile} aria-hidden="true">
        <ReceiptIcon size={20} />
      </span>
      <span className={styles.words}>
        <span className={styles.mark}>Kassa</span>
        {!compact && <span className={styles.area}>Verwaltung</span>}
      </span>
    </span>
  );
}
