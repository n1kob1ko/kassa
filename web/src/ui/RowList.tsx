import { useId, type ReactNode } from 'react';
import { Link, type LinkProps } from 'react-router';
import { ChevronDownIcon, ChevronRightIcon } from './icons';
import styles from './RowList.module.css';

export type RowGroupProps = {
  /** Name der Liste für Screenreader. */
  label: string;
  /** Ruhige Überschrift über der Karte, etwa "Heute" oder "Mi., 18.11.". */
  heading?: string;
  children: ReactNode;
};

/**
 * Eine Karte mit Zeilen (wie die Bonliste der App): Rundung 20, feine Linie zwischen den Zeilen, darüber
 * optional eine ruhige Überschrift. Für lange Listen, die man liest und antippt, nicht bearbeitet.
 */
export function RowGroup({ label, heading, children }: RowGroupProps) {
  return (
    <section className={styles.group}>
      {heading && <h2 className={styles.heading}>{heading}</h2>}
      <ul className={styles.card} aria-label={label}>
        {children}
      </ul>
    </section>
  );
}

export type RowLinkProps = Omit<LinkProps, 'className' | 'children'> & {
  /** Die Zeile ist gerade offen (ihr Detail liegt darüber): Fläche `accentSoft`. */
  selected?: boolean;
  /** Kennung für das Zurückgeben des Fokus (`data-row-id`). */
  rowId: string;
  className?: string;
  children: ReactNode;
};

/** Eine Zeile, die als Ganzes ein Link ist (mindestens 60 px hoch), mit Pfeil rechts. */
export function RowLink({ selected = false, rowId, className, children, ...link }: RowLinkProps) {
  return (
    <li className={styles.item}>
      <Link {...link} data-row-id={rowId} className={[styles.row, selected ? styles.selected : ''].filter(Boolean).join(' ')}>
        <span className={[styles.content, className].filter(Boolean).join(' ')}>{children}</span>
        <ChevronRightIcon size={18} className={styles.chevron} />
      </Link>
    </li>
  );
}

export type RowDisclosureProps = {
  open: boolean;
  onToggle: () => void;
  /** Die Zeile selbst; ihr Text ist zugleich der Name des Knopfs und des aufgeklappten Bereichs. */
  summary: ReactNode;
  /** Der Inhalt, der unter der Zeile aufklappt (nur, solange sie offen ist). */
  children: ReactNode;
  className?: string;
};

/**
 * Eine Zeile, die als Ganzes ein Knopf ist und ihren Inhalt an Ort und Stelle aufklappt (mindestens 60 px hoch),
 * mit Pfeil nach unten, der sich beim Öffnen dreht. Mehrere Zeilen können zugleich offen sein.
 */
export function RowDisclosure({ open, onToggle, summary, children, className }: RowDisclosureProps) {
  const id = useId();
  return (
    <li className={styles.item}>
      <button
        type="button"
        id={`${id}-zeile`}
        className={[styles.row, styles.toggle].join(' ')}
        aria-expanded={open}
        aria-controls={`${id}-inhalt`}
        onClick={onToggle}
      >
        <span className={[styles.content, className].filter(Boolean).join(' ')}>{summary}</span>
        <ChevronDownIcon size={18} className={[styles.chevron, styles.turn].join(' ')} />
      </button>
      {open && (
        <div id={`${id}-inhalt`} role="region" aria-labelledby={`${id}-zeile`} className={styles.panel}>
          {children}
        </div>
      )}
    </li>
  );
}

/** Platzhalter beim ersten Laden: eine Karte mit Zeilen in der Form der späteren Zeilen. */
export function RowListSkeleton({ rows = 6, label, headings = false }: { rows?: number; label: string; headings?: boolean }) {
  return (
    <div className={styles.skeleton} role="status" aria-busy="true">
      <span className="visually-hidden">{label}</span>
      {headings && <span className={[styles.bone, styles.boneHeading].join(' ')} aria-hidden="true" />}
      <div className={styles.card} aria-hidden="true">
        {Array.from({ length: rows }, (_, i) => (
          <div key={i} className={styles.boneRow}>
            <span className={styles.boneText}>
              <span className={[styles.bone, styles.boneTitle].join(' ')} />
              <span className={[styles.bone, styles.boneMeta].join(' ')} />
            </span>
            <span className={[styles.bone, styles.boneAmount].join(' ')} />
          </div>
        ))}
      </div>
    </div>
  );
}
