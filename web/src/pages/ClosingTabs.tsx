import { Link } from 'react-router';
import styles from './ClosingTabs.module.css';

/**
 * Die zwei Seiten der Abschlüsse, "Tage" und "Monate", im Aussehen des Umschalters. Es sind echte Verweise (jede Seite
 * hat ihre Adresse), der aktuelle trägt `aria-current="page"`.
 */
export function ClosingTabs({ businessId, current }: { businessId: string; current: 'tage' | 'monate' }) {
  const tabs = [
    { key: 'tage', label: 'Tage' },
    { key: 'monate', label: 'Monate' },
  ] as const;
  return (
    <nav aria-label="Abschlüsse" className={styles.tabs}>
      {tabs.map((t) => (
        <Link
          key={t.key}
          to={`/b/${businessId}/${t.key}`}
          className={styles.tab}
          aria-current={t.key === current ? 'page' : undefined}
        >
          {t.label}
        </Link>
      ))}
    </nav>
  );
}
