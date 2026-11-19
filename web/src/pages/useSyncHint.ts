import { useCallback, useRef } from 'react';
import { toast } from '../ui/Toast';

export const SYNC_HINT = 'Kommt beim nächsten Abgleich an die Kassa.';

/**
 * Der ruhige Hinweis nach der ersten geglückten Änderung eines Besuchs der Seite. Danach nicht mehr, bis die Seite
 * verlassen und wieder geöffnet wird (der Zustand lebt mit der Seite).
 */
export function useSyncHint(): () => void {
  const shown = useRef(false);
  return useCallback(() => {
    if (shown.current) return;
    shown.current = true;
    toast.show(SYNC_HINT);
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
