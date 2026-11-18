import { useEffect, useRef, useState, useSyncExternalStore } from 'react';
import styles from './Toast.module.css';

type ToastState = { id: number; message: string; undo?: () => void };

/** Wie lange ein Hinweis stehen bleibt (DESIGN.md, Hinweis mit Rückgängig). */
const VISIBLE_MS = 7000;

let current: ToastState | null = null;
let nextId = 1;
const listeners = new Set<() => void>();

function emit(): void {
  for (const l of listeners) l();
}

function dismiss(id: number): void {
  if (current?.id !== id) return;
  current = null;
  emit();
}

/**
 * Kurzer Hinweis unten in der Mitte. Ein neuer ersetzt den alten. Mit `undo` steht daneben "Rückgängig":
 * so wird gelöscht oder stillgelegt, ohne vorher zu fragen.
 */
export const toast = {
  show(message: string, options: { undo?: () => void } = {}): void {
    current = { id: nextId++, message, ...(options.undo ? { undo: options.undo } : {}) };
    emit();
  },
};

function subscribe(listener: () => void): () => void {
  listeners.add(listener);
  return () => listeners.delete(listener);
}

/**
 * Einmal in der App, zeigt den jeweils letzten Hinweis. Er liegt als Popover in der obersten Ebene des Browsers,
 * damit er auch über einem offenen Dialog zu sehen ist. Solange die Maus darauf steht oder der Fokus darin ist,
 * läuft die Zeit nicht weiter.
 */
export function Toaster() {
  const state = useSyncExternalStore(subscribe, () => current);
  const popover = useRef<HTMLDivElement>(null);
  const remaining = useRef(VISIBLE_MS);
  const [hovered, setHovered] = useState(false);
  const [focused, setFocused] = useState(false);
  const paused = hovered || focused;

  // Jeder neue Hinweis bekommt die volle Zeit und kommt (wieder) ganz nach oben, auch über einen später geöffneten Dialog.
  useEffect(() => {
    remaining.current = VISIBLE_MS;
    setHovered(false);
    setFocused(false);
    const el = popover.current;
    if (!el) return;
    if (el.matches(':popover-open')) el.hidePopover();
    if (state) el.showPopover();
  }, [state]);

  useEffect(() => {
    if (!state || paused) return;
    const started = Date.now();
    const timer = setTimeout(() => dismiss(state.id), remaining.current);
    return () => {
      clearTimeout(timer);
      remaining.current = Math.max(0, remaining.current - (Date.now() - started));
    };
  }, [state, paused]);

  return (
    <>
      <div className="visually-hidden" role="status" aria-live="polite">
        {state?.message}
      </div>
      <div
        ref={popover}
        popover="manual"
        className={styles.region}
        onMouseEnter={() => setHovered(true)}
        onMouseLeave={() => setHovered(false)}
        onFocus={() => setFocused(true)}
        onBlur={(e) => {
          if (!e.currentTarget.contains(e.relatedTarget)) setFocused(false);
        }}
      >
        {state && (
          <div key={state.id} className={styles.toast}>
            <span className={styles.message}>{state.message}</span>
            {state.undo && (
              <button
                type="button"
                className={styles.undo}
                onClick={() => {
                  const undo = state.undo;
                  dismiss(state.id);
                  undo?.();
                }}
              >
                Rückgängig
              </button>
            )}
          </div>
        )}
      </div>
    </>
  );
}
