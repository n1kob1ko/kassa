import { useEffect, useSyncExternalStore } from 'react';
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

/** Einmal in der App, zeigt den jeweils letzten Hinweis. */
export function Toaster() {
  const state = useSyncExternalStore(subscribe, () => current);

  useEffect(() => {
    if (!state) return;
    const timer = setTimeout(() => dismiss(state.id), VISIBLE_MS);
    return () => clearTimeout(timer);
  }, [state]);

  return (
    <div className={styles.region} role="status" aria-live="polite">
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
  );
}
