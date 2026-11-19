import { useEffect, useId, useRef, type ReactNode } from 'react';
import { ChevronLeftIcon, CloseIcon } from './icons';
import styles from './Dialog.module.css';

export type DialogProps = {
  title: string;
  open: boolean;
  onClose: () => void;
  children: ReactNode;
  /** Knöpfe unten, die Hauptaktion zuletzt. Ohne: kein Fuß (etwa ein Blatt, das nur zeigt). */
  actions?: ReactNode;
  /**
   * `center` (Vorgabe): Dialog in der Mitte, unter 640 px ein Blatt von unten.
   * `side`: ab 640 px ein Blatt von rechts über der abgedunkelten Seite, darunter eine ganze Seite mit "Zurück".
   */
  variant?: 'center' | 'side';
  /** Wohin der Fokus nach dem Schließen geht, wenn nicht dorthin, wo er vor dem Öffnen war (etwa nach dem Neuladen). */
  returnFocus?: () => HTMLElement | null | undefined;
};

const FOCUSABLE =
  'a[href], button:not([disabled]), input:not([disabled]), select:not([disabled]), textarea:not([disabled]), [tabindex]:not([tabindex="-1"])';

/**
 * Dialog über der Seite (das native `<dialog>` als Modal: der Rest der Seite ist gesperrt).
 * Der Fokus bleibt im Dialog, Escape schließt ihn, danach geht der Fokus zurück, wo er vorher war.
 * Unter 640 px kommt er als Blatt von unten.
 */
export function Dialog({ title, open, onClose, children, actions, variant = 'center', returnFocus }: DialogProps) {
  const ref = useRef<HTMLDialogElement>(null);
  const titleId = useId();
  const opener = useRef<Element | null>(null);
  const returnTo = useRef(returnFocus);
  returnTo.current = returnFocus;

  const giveFocusBack = () => {
    const target = returnTo.current?.() ?? opener.current;
    if (target instanceof HTMLElement && target.isConnected) target.focus();
  };

  useEffect(() => {
    const dialog = ref.current;
    if (!dialog) return;
    if (open && !dialog.open) {
      opener.current = document.activeElement;
      dialog.showModal();
      // Ein Eingabefeld bekommt den Fokus gleich (React setzt `autoFocus` schon vor dem Öffnen, da geht es ins Leere).
      dialog.querySelector<HTMLElement>('input:not([type="file"]):not([type="radio"]), textarea, select')?.focus();
    } else if (!open && dialog.open) {
      dialog.close();
      giveFocusBack();
    }
  }, [open]);

  // Beim Verschwinden der Komponente mit offenem Dialog den Fokus trotzdem zurückgeben.
  useEffect(
    () => () => {
      if (ref.current?.open) giveFocusBack();
    },
    [],
  );

  return (
    <dialog
      ref={ref}
      className={[styles.dialog, variant === 'side' ? styles.side : ''].filter(Boolean).join(' ')}
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
      onClose={() => {
        // Der Browser kann den Dialog auch selbst schließen (in Chromium etwa das zweite Escape, das sich nicht
        // abbrechen lässt). Dann muss der Zustand der Seite mitgehen.
        if (open) onClose();
      }}
      onClick={(e) => {
        // Klick auf den abgedunkelten Rand schließt, Klicks im Inhalt nicht.
        if (e.target === e.currentTarget) onClose();
      }}
    >
      {open && (
        <div className={styles.panel}>
          <header className={styles.head}>
            {variant === 'side' && (
              // Am Handy ist das Blatt eine eigene Seite: zurück statt schließen. Ab 640 px ist der Knopf versteckt.
              <button type="button" className={styles.back} onClick={onClose}>
                <ChevronLeftIcon size={22} />
                Zurück
              </button>
            )}
            <h2 id={titleId} className={styles.title}>
              {title}
            </h2>
            <button type="button" className={styles.close} onClick={onClose} aria-label="Schließen">
              <CloseIcon size={20} />
            </button>
          </header>
          <div className={styles.body}>{children}</div>
          {actions && <footer className={styles.actions}>{actions}</footer>}
        </div>
      )}
    </dialog>
  );
}
