import styles from './Skeleton.module.css';

export type SkeletonProps = {
  /** Anzahl der Zeilen, in der Form des späteren Inhalts. */
  lines: number;
  /** Beschriftung für Screenreader. */
  label?: string;
};

/** Platzhalter, solange Daten laden. Die letzte Zeile ist kürzer, wie Text. */
export function Skeleton({ lines, label = 'Wird geladen' }: SkeletonProps) {
  return (
    <div className={styles.skeleton} role="status" aria-live="polite" aria-busy="true">
      <span className="visually-hidden">{label}</span>
      {Array.from({ length: lines }, (_, i) => (
        <span key={i} className={styles.line} aria-hidden="true" />
      ))}
    </div>
  );
}

/**
 * Ein einzelner schimmernder Platzhalter für Skeletons in der Form einer Seite. Größe und Rundung gibt die Seite
 * über `className`; der Schimmer kommt von hier.
 */
export function Bone({ className }: { className?: string }) {
  return <span className={[styles.bone, className].filter(Boolean).join(' ')} aria-hidden="true" />;
}
