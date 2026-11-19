import { useCallback, useRef } from 'react';
import { toast } from '../ui/Toast';
import { imageErrorText } from './PhotoDialog';

export const SYNC_HINT = 'Kommt beim nächsten Abgleich an die Kassa.';

type ToastOptions = { undo?: () => void };

/**
 * Meldet eine geglückte Änderung. Die erste eines Besuchs der Seite bekommt den ruhigen Hinweis zum Abgleich dazu,
 * danach nicht mehr, bis die Seite verlassen und wieder geöffnet wird (der Zustand lebt mit der Seite).
 * Ohne eigene Meldung steht nur der Hinweis da, und nur beim ersten Mal; mit Meldung (etwa "Foto entfernt." mit
 * "Rückgängig") kommt der Hinweis in dieselbe Meldung, damit sie nicht ersetzt wird.
 */
export function useSyncHint(): (message?: string, options?: ToastOptions) => void {
  const shown = useRef(false);
  return useCallback((message?: string, options?: ToastOptions) => {
    const first = !shown.current;
    shown.current = true;
    if (message === undefined) {
      if (first) toast.show(SYNC_HINT);
      return;
    }
    toast.show(first ? `${message} ${SYNC_HINT}` : message, options);
  }, []);
}

/**
 * Die Dateien, die in diesem Besuch hochgeladen wurden, je Artikel (oder Logo). Nur mit ihnen lässt sich ein
 * Entfernen ehrlich rückgängig machen: das Bild geht noch einmal zum Server.
 */
export function useUploadMemory() {
  const files = useRef(new Map<string, { pictureId: string; file: File }>());
  return {
    remember: useCallback((key: string, pictureId: string, file: File) => files.current.set(key, { pictureId, file }), []),
    /** Die Datei hinter dem Bild `pictureId`, wenn sie in diesem Besuch hochgeladen wurde. */
    fileOf: useCallback((key: string, pictureId: string | undefined) => {
      const known = files.current.get(key);
      return known && known.pictureId === pictureId ? known.file : undefined;
    }, []),
  };
}

export type RemoveWithUndo = {
  /** Entfernt am Server (die Liste zeigt es schon vorher nicht mehr). */
  remove: () => Promise<unknown>;
  /** Lädt die gemerkte Datei noch einmal hoch. */
  reupload: () => Promise<unknown>;
  /** Die Meldung, etwa "Foto entfernt.". */
  message: string;
  /** Wie die Meldung erscheint, mit dem Hinweis zum Abgleich (aus `useSyncHint`). */
  notify: (message: string, options: ToastOptions) => void;
};

/**
 * Sofort weg, "Rückgängig" lädt dieselbe Datei aus diesem Besuch noch einmal hoch, sobald das Entfernen durch ist.
 * Scheitert das Entfernen, nennt der Hinweis den Grund, und "Rückgängig" tut nichts mehr.
 */
export function removeWithUndo({ remove, reupload, message, notify }: RemoveWithUndo): void {
  const removal = remove();
  removal.catch((err: Error) => toast.show(err.message));
  notify(message, {
    undo: () => {
      void (async () => {
        try {
          await removal;
        } catch {
          return;
        }
        try {
          await reupload();
        } catch (err) {
          toast.show(imageErrorText(err));
        }
      })();
    },
  });
}
