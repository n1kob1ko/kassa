import { useCallback, useState } from 'react';

/**
 * Zustand eines Dialogs. Jedes `show` zählt `key` hoch: die Seite gibt ihn dem Dialog als `key`, so beginnt
 * jeder Dialog mit leeren Feldern und frischem Zustand, und der geschlossene bleibt zum Zurückgeben des Fokus stehen.
 */
export function useDialogState<T = undefined>() {
  const [state, setState] = useState<{ key: number; open: boolean; value: T | undefined }>({
    key: 0,
    open: false,
    value: undefined,
  });
  const show = useCallback((value?: T) => setState((s) => ({ key: s.key + 1, open: true, value })), []);
  const close = useCallback(() => setState((s) => ({ ...s, open: false })), []);
  return { key: state.key, open: state.open, value: state.value, show, close };
}
