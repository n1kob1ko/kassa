import type { ReactNode } from 'react';
import { Button } from './Button';
import { EmptyState } from './EmptyState';
import { Skeleton } from './Skeleton';
import styles from './DataList.module.css';

export type DataListProps = { label: string; children: ReactNode };

/** Liste von Zeilen. Ab 640 px eine Zeile pro Eintrag, darunter eine Karte mit den Knöpfen unter dem Text. */
export function DataList({ label, children }: DataListProps) {
  return (
    <ul className={styles.list} aria-label={label}>
      {children}
    </ul>
  );
}

export type DataRowProps = {
  title: string;
  /** Zeichen oder Zustand rechts vom Titel (ein `StatusChip`). */
  chips?: ReactNode;
  /** Kleine Angaben unter dem Titel. */
  meta?: ReactNode[];
  actions?: ReactNode;
  /** Stillgelegt: ruhigere Fläche und Schrift. Der Zustand steht zusätzlich als Zeichen in `chips`. */
  muted?: boolean;
};

export function DataRow({ title, chips, meta = [], actions, muted = false }: DataRowProps) {
  return (
    <li className={[styles.row, muted ? styles.muted : ''].filter(Boolean).join(' ')}>
      <div className={styles.main}>
        <div className={styles.head}>
          <p className={styles.title}>{title}</p>
          {chips}
        </div>
        {meta.length > 0 && (
          <p className={styles.meta}>
            {meta.map((m, i) => (
              <span key={i}>{m}</span>
            ))}
          </p>
        )}
      </div>
      {actions && <div className={styles.actions}>{actions}</div>}
    </li>
  );
}

/** Platzhalter einer Liste, solange sie lädt: Karten in der Höhe der späteren Zeilen. */
export function ListSkeleton({ rows = 3, label }: { rows?: number; label: string }) {
  return (
    <div className={styles.skeleton}>
      <Skeleton lines={rows} label={label} />
    </div>
  );
}

/** Wenn das Laden scheitert: der Text des Servers und ein Knopf zum Wiederholen. */
export function LoadError({ message, onRetry }: { message: string; onRetry: () => void }) {
  return (
    <EmptyState
      title="Das konnte nicht geladen werden"
      text={message}
      action={
        <Button variant="secondary" onClick={onRetry}>
          Nochmal versuchen
        </Button>
      }
    />
  );
}
