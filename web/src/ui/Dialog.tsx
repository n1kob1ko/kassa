import { useEffect, useId, useRef, type ReactNode } from 'react';
import { CloseIcon } from './icons';
import styles from './Dialog.module.css';

export type DialogProps = {
  title: string;
  open: boolean;
  onClose: () => void;
  children: ReactNode;
  /** Knöpfe unten, die Hauptaktion zuletzt. */
  actions: ReactNode;
};

const FOCUSABLE =
  'a[href], button:not([disabled]), input:not([disabled]), select:not([disabled]), textarea:not([disabled]), [tabindex]:not([tabindex="-1"])';

/**
 * Dialog über der Seite (das native `<dialog>` als Modal: der Rest der Seite ist gesperrt).
 * Der Fokus bleibt im Dialog, Escape schließt ihn, danach geht der Fokus zurück, wo er vorher war.
 * Unter 640 px kommt er als Blatt von unten.
 */
export function Dialog({ title, open, onClose, children, actions }: DialogProps) {
  const ref = useRef<HTMLDialogElement>(null);
  const titleId = useId();
  const opener = useRef<Element | null>(null);

  useEffect(() => {
    const dialog = ref.current;
    if (!dialog) return;
    if (open && !dialog.open) {
      opener.current = document.activeElement;
      dialog.showModal();
    } else if (!open && dialog.open) {
      dialog.close();
      if (opener.current instanceof HTMLElement) opener.current.focus();
    }
  }, [open]);

  // Beim Verschwinden der Komponente mit offenem Dialog den Fokus trotzdem zurückgeben.
  useEffect(
    () => () => {
      if (opener.current instanceof HTMLElement && ref.current?.open) opener.current.focus();
    },
    [],
  );

  return (
    <dialog
      ref={ref}
      className={styles.dialog}
      aria-labelledby={titleId}
      onCancel={(e) => {
        // Escape: der Zustand gehört der Seite, sie schließt über onClose.
        e.preventDefault();
        onClose();
      }}
      onKeyDown={(e) => {
        if (e.key !== 'Tab') return;
        const items = Array.from(e.currentTarget.querySelectorAll<HTMLElement>(FOCUSABLE));
        const first = items[0];
        const last = items[items.length - 1];
        if (!first || !last) return;
        if (e.shiftKey && document.activeElement === first) {
          e.preventDefault();
          last.focus();
        } else if (!e.shiftKey && document.activeElement === last) {
          e.preventDefault();
          first.focus();
        }
      }}
      onClick={(e) => {
        // Klick auf den abgedunkelten Rand schließt, Klicks im Inhalt nicht.
        if (e.target === e.currentTarget) onClose();
      }}
    >
      {open && (
        <div className={styles.panel}>
          <header className={styles.head}>
            <h2 id={titleId} className={styles.title}>
              {title}
            </h2>
            <button type="button" className={styles.close} onClick={onClose} aria-label="Schließen">
              <CloseIcon size={20} />
            </button>
          </header>
          <div className={styles.body}>{children}</div>
          <footer className={styles.actions}>{actions}</footer>
        </div>
      )}
    </dialog>
  );
}
