import { useEffect, useRef, useState, type CSSProperties } from 'react';
import { ApiError } from '../api/client';
import { isAbort, type Picture, type UploadOptions } from '../api/files';
import { Button } from '../ui/Button';
import { Dialog } from '../ui/Dialog';
import { FileDrop } from '../ui/FileDrop';
import { FormAlert } from './AuthLayout';
import { IMAGE_TOO_LARGE, NOT_AN_IMAGE } from './validate';
import styles from './PhotoDialog.module.css';

/** Ein Fehler beim Hochladen als ein Satz: Art und Größe wie bei der Prüfung im Browser, sonst der Text des Servers. */
export function imageErrorText(err: unknown): string {
  if (err instanceof ApiError) {
    if (err.code === 'unsupported_media_type' || err.code === 'image_invalid') return NOT_AN_IMAGE;
    if (err.status === 413) return IMAGE_TOO_LARGE;
    return err.message;
  }
  return 'Das hat nicht geklappt. Bitte nochmal versuchen.';
}

export type PhotoDialogProps = {
  open: boolean;
  onClose: () => void;
  /** "Foto für Huhn Bowl" oder "Logo". */
  title: string;
  /** Wie das Bild heißt: in "Foto entfernen", "Logo wirklich entfernen?". */
  noun: 'Foto' | 'Logo';
  current: Picture | null;
  src: (id: string) => string;
  fit?: 'cover' | 'contain';
  /** Lädt hoch; scheitert mit `ApiError` oder beim Abbrechen mit einem `AbortError`. */
  onSave: (file: File, options: UploadOptions) => Promise<void>;
  /**
   * Entfernt das Bild. Mit `undoable` schließt das Fenster gleich und die Seite bietet "Rückgängig" an; sonst
   * fragt das Fenster erst nach und wartet auf den Server.
   */
  onRemove: () => Promise<void> | void;
  undoable: boolean;
  /** Wohin der Fokus nach dem Schließen geht, wenn nicht zum Knopf, der das Fenster geöffnet hat. */
  returnFocus?: () => HTMLElement | null;
};

/**
 * Fenster für ein Bild: Datei wählen oder hineinziehen, Vorschau, Fortschritt, "Speichern", bei vorhandenem Bild
 * auch entfernen. Schließen während des Hochladens bricht es ab. Während es läuft, bleibt das Fenster bedienbar.
 */
export function PhotoDialog({
  open,
  onClose,
  title,
  noun,
  current,
  src,
  fit = 'cover',
  onSave,
  onRemove,
  undoable,
  returnFocus,
}: PhotoDialogProps) {
  const [file, setFile] = useState<File | null>(null);
  const [preview, setPreview] = useState<string | null>(null);
  const [problem, setProblem] = useState<string | null>(null);
  const [progress, setProgress] = useState<number | null>(null);
  const [confirming, setConfirming] = useState(false);
  const [removing, setRemoving] = useState(false);
  const [backFromConfirm, setBackFromConfirm] = useState(false);
  const upload = useRef<AbortController | null>(null);

  // Die Vorschau ist eine Adresse auf die Datei im Speicher des Browsers; sie wird wieder freigegeben.
  useEffect(() => {
    if (!file) {
      setPreview(null);
      return;
    }
    const url = URL.createObjectURL(file);
    setPreview(url);
    return () => URL.revokeObjectURL(url);
  }, [file]);

  useEffect(() => () => upload.current?.abort(), []);

  const cancelUpload = () => {
    upload.current?.abort();
    upload.current = null;
    setProgress(null);
  };

  const close = () => {
    cancelUpload();
    onClose();
  };

  const save = async () => {
    if (!file || upload.current) return;
    const controller = new AbortController();
    upload.current = controller;
    setProblem(null);
    setProgress(0);
    try {
      await onSave(file, { signal: controller.signal, onProgress: (share) => setProgress(share) });
      if (upload.current !== controller) return;
      upload.current = null;
      onClose();
    } catch (err) {
      if (upload.current === controller) {
        upload.current = null;
        setProgress(null);
      }
      if (!isAbort(err)) setProblem(imageErrorText(err));
    }
  };

  const remove = async () => {
    if (undoable) {
      onClose();
      void onRemove();
      return;
    }
    if (!confirming) {
      setConfirming(true);
      return;
    }
    setRemoving(true);
    setProblem(null);
    try {
      await onRemove();
      onClose();
    } catch (err) {
      setRemoving(false);
      setProblem(err instanceof ApiError ? err.message : 'Das hat nicht geklappt. Bitte nochmal versuchen.');
    }
  };

  const uploading = progress !== null;
  const shown = preview ?? (current ? src(current.id) : null);
  const percent = Math.round((progress ?? 0) * 100);

  // Ein Fenster, zwei Schritte: die Rückfrage ersetzt den Inhalt, das Fenster bleibt offen (kein zweites Öffnen).
  const confirmActions = (
    <>
      {/* Der Knopf, der die Rückfrage brachte, ist weg: der Fokus geht auf "Abbrechen", danach zurück. */}
      <Button
        variant="quiet"
        autoFocus
        onClick={() => {
          setConfirming(false);
          setBackFromConfirm(true);
        }}
        disabled={removing}
      >
        Abbrechen
      </Button>
      <Button variant="danger" busy={removing} onClick={() => void remove()}>
        Ja, entfernen
      </Button>
    </>
  );
  const confirmBody = (
    <div className={styles.body}>
      {current && (
        <span className={styles.frame} style={{ '--placeholder': current.color } as CSSProperties}>
          <img
            className={[styles.image, fit === 'contain' ? styles.contain : ''].filter(Boolean).join(' ')}
            src={src(current.id)}
            alt="Vorschau"
            onLoad={(e) => {
              e.currentTarget.dataset.loaded = 'true';
            }}
          />
        </span>
      )}
      <p className={styles.question}>{noun} wirklich entfernen?</p>
      <p className={styles.note}>Das lässt sich nicht rückgängig machen.</p>
      {problem && <FormAlert>{problem}</FormAlert>}
    </div>
  );

  const pickActions = (
    <>
      {current && !file && (
        <Button variant="danger" className={styles.remove} autoFocus={backFromConfirm} onClick={() => void remove()}>
          {noun} entfernen
        </Button>
      )}
      <Button variant="quiet" onClick={close}>
        Abbrechen
      </Button>
      <Button variant="primary" busy={uploading} disabled={!file} onClick={() => void save()}>
        Speichern
      </Button>
    </>
  );

  const pickBody = (
    <div className={styles.body}>
      {shown && (
        <span
          className={[styles.frame, uploading ? styles.sending : ''].filter(Boolean).join(' ')}
          style={!preview && current ? ({ '--placeholder': current.color } as CSSProperties) : undefined}
        >
          <img
            key={shown}
            className={[styles.image, fit === 'contain' ? styles.contain : ''].filter(Boolean).join(' ')}
            src={shown}
            alt="Vorschau"
            onLoad={(e) => {
              e.currentTarget.dataset.loaded = 'true';
            }}
          />
        </span>
      )}
      {uploading && (
        <div className={styles.progress}>
          <span className={styles.progressText}>
            {/* Ist alles gesendet, rechnet der Server das Bild noch um. */}
            <span>{percent < 100 ? 'Wird hochgeladen' : 'Wird gespeichert'}</span>
            <span className={styles.percent}>{percent} %</span>
          </span>
          <progress className={styles.bar} max={100} value={percent} aria-label="Hochladen" />
        </div>
      )}
      <FileDrop
        kind="image"
        fileName={file?.name}
        onReject={(p) => {
          if (p) {
            cancelUpload();
            setFile(null);
          }
          setProblem(null);
        }}
        onFile={(f) => {
          cancelUpload();
          setProblem(null);
          setFile(f);
        }}
      />
      {problem && <FormAlert>{problem}</FormAlert>}
    </div>
  );

  return (
    <Dialog
      title={title}
      open={open}
      onClose={close}
      returnFocus={returnFocus}
      actions={confirming ? confirmActions : pickActions}
    >
      {confirming ? confirmBody : pickBody}
    </Dialog>
  );
}
