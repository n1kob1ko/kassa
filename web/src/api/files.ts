import { ApiError, errorOf, networkError } from './client';

/** Ein Bild am Server: die Kennung (sie ändert sich mit jedem neuen Bild) und seine Hauptfarbe als Platzhalter. */
export type Picture = { id: string; color: string };
export type UploadedFile = Picture & { width: number; height: number };

export type UploadOptions = {
  /** Anteil von 0 bis 1, so wie der Browser sendet. */
  onProgress?: (share: number) => void;
  /** Abbrechen: die Anfrage wird abgebrochen, das Versprechen scheitert mit einem `AbortError`. */
  signal?: AbortSignal;
};

/** Adresse eines Bilds des Betriebs (WebP, höchstens 800 px breit). */
export function fileUrl(businessId: string, fileId: string): string {
  return `/api/admin/businesses/${encodeURIComponent(businessId)}/files/${encodeURIComponent(fileId)}`;
}

/** `AbortError`, wie ihn auch `fetch` beim Abbrechen wirft. */
export function isAbort(err: unknown): boolean {
  return err instanceof DOMException && err.name === 'AbortError';
}

/**
 * Lädt ein Bild roh hoch (`PUT` mit dem Typ der Datei). Mit `XMLHttpRequest`, weil nur das den Fortschritt des
 * Sendens meldet. Kopfzeilen, Cookie und Fehlerform wie bei `api`: jeder Fehler wird ein `ApiError`.
 */
export function uploadImage(path: string, file: Blob, { onProgress, signal }: UploadOptions = {}): Promise<UploadedFile> {
  return new Promise((resolve, reject) => {
    if (signal?.aborted) {
      reject(new DOMException('Abgebrochen', 'AbortError'));
      return;
    }
    const xhr = new XMLHttpRequest();
    xhr.open('PUT', path);
    xhr.withCredentials = true;
    xhr.setRequestHeader('X-Kassa-Request', '1');
    xhr.setRequestHeader('Content-Type', file.type);
    xhr.responseType = 'text';

    const onAbort = () => xhr.abort();
    signal?.addEventListener('abort', onAbort, { once: true });
    const done = () => signal?.removeEventListener('abort', onAbort);

    xhr.upload.onprogress = (e) => {
      if (e.lengthComputable && e.total > 0) onProgress?.(e.loaded / e.total);
    };
    xhr.onload = () => {
      done();
      const res = new Response(xhr.status === 204 ? null : xhr.responseText, {
        status: xhr.status,
        headers: { 'content-type': xhr.getResponseHeader('content-type') ?? 'application/json' },
      });
      if (!res.ok) {
        void errorOf(res).then(reject);
        return;
      }
      try {
        const body = JSON.parse(xhr.responseText) as { file?: UploadedFile };
        if (!body.file || typeof body.file.id !== 'string') throw new Error('ohne Datei');
        resolve(body.file);
      } catch {
        reject(new ApiError(xhr.status, 'internal', 'Das hat nicht geklappt. Bitte nochmal versuchen.'));
      }
    };
    xhr.onerror = () => {
      done();
      reject(networkError());
    };
    xhr.onabort = () => {
      done();
      reject(new DOMException('Abgebrochen', 'AbortError'));
    };
    xhr.send(file);
  });
}
