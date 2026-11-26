import { useId, useState, type DragEvent } from 'react';
import { ApiError } from '../api/client';
import { count } from '../format';
import { UploadIcon } from './icons';
import { FormAlert } from '../pages/AuthLayout';
import { imageProblem, IMAGE_TYPES } from '../pages/validate';
import styles from './FileDrop.module.css';

export type FileDropProps = {
  /** Eine passende Datei. Andere weist die Fläche selbst ab und sagt es in einem Satz. */
  onFile: (file: File) => void;
  /** Name der zuletzt gewählten Datei. */
  fileName?: string;
  disabled?: boolean;
  /**
   * `menu` (Vorgabe): die Speisekarten-Datei (.json). `translations`: eine Datei nur mit Übersetzungen (.json).
   * `image`: ein Bild (JPEG, PNG, WebP, bis 10 MB).
   */
  kind?: 'menu' | 'translations' | 'image';
  /** Wird eine Datei abgewiesen (dann mit dem Satz) oder angenommen (dann `null`). */
  onReject?: (problem: string | null) => void;
};

const KINDS = {
  menu: {
    accept: '.json,application/json',
    title: 'Speisekarten-Datei hierher ziehen oder auswählen',
    hint: 'Nur .json, bis 1 MB',
    problem: (file: File) => (file.name.toLowerCase().endsWith('.json') ? null : 'Das ist keine .json-Datei. Wähle die Speisekarten-Datei aus.'),
  },
  translations: {
    accept: '.json,application/json',
    title: 'Übersetzungs-Datei hierher ziehen oder auswählen',
    hint: 'Nur .json, bis 1 MB',
    problem: (file: File) => (file.name.toLowerCase().endsWith('.json') ? null : 'Das ist keine .json-Datei. Wähle die Übersetzungs-Datei aus.'),
  },
  image: {
    accept: IMAGE_TYPES.join(','),
    title: 'Bild hierher ziehen oder auswählen',
    hint: 'JPEG, PNG oder WebP, bis 10 MB',
    problem: imageProblem,
  },
} as const;

/** Fläche zum Hineinziehen oder Auswählen einer Datei. Mit Tastatur: Tab zur Fläche, Enter oder Leertaste. */
export function FileDrop({ onFile, fileName, disabled = false, kind = 'menu', onReject }: FileDropProps) {
  const inputId = useId();
  const [over, setOver] = useState(false);
  const [rejected, setRejected] = useState<string | null>(null);
  const config = KINDS[kind];

  const take = (file: File | undefined) => {
    if (!file || disabled) return;
    const problem = config.problem(file);
    setRejected(problem);
    onReject?.(problem);
    if (!problem) onFile(file);
  };

  const onDrop = (e: DragEvent) => {
    e.preventDefault();
    setOver(false);
    take(e.dataTransfer.files[0]);
  };

  return (
    <div className={styles.wrap}>
      <label
        htmlFor={inputId}
        className={[styles.drop, over ? styles.over : '', disabled ? styles.disabled : ''].filter(Boolean).join(' ')}
        onDragOver={(e) => {
          e.preventDefault();
          if (!disabled) setOver(true);
        }}
        onDragLeave={() => setOver(false)}
        onDrop={onDrop}
      >
        <input
          id={inputId}
          type="file"
          accept={config.accept}
          className={styles.input}
          disabled={disabled}
          onChange={(e) => {
            take(e.target.files?.[0]);
            // Dieselbe Datei nach einer Korrektur nochmal wählen können.
            e.target.value = '';
          }}
        />
        <UploadIcon size={28} className={styles.icon} />
        <span className={styles.title}>{config.title}</span>
        <span className={styles.hint}>{fileName ? fileName : config.hint}</span>
      </label>
      {rejected && <FormAlert>{rejected}</FormAlert>}
    </div>
  );
}

/** Der Fehler einer Datei: bei `menu_invalid` und `translations_invalid` die Zahl und jede Zeile der Probleme, sonst der Text des Servers. */
export function UploadError({ error }: { error: ApiError }) {
  if ((error.code === 'menu_invalid' || error.code === 'translations_invalid') && error.problems && error.problems.length > 0) {
    return (
      <div className={styles.problems} role="alert">
        <p className={styles.problemsTitle}>Die Datei hat {count(error.problems.length, 'Problem', 'Probleme')}</p>
        <ul className={styles.problemList}>
          {error.problems.map((p, i) => (
            <li key={i}>{p}</li>
          ))}
        </ul>
        <p className={styles.problemsHelp}>Korrigiere die Datei und wähle sie nochmal aus.</p>
      </div>
    );
  }
  return <FormAlert>{error.message}</FormAlert>;
}
