import { useId, useState, type DragEvent } from 'react';
import { ApiError } from '../api/client';
import { count } from '../format';
import { UploadIcon } from './icons';
import { FormAlert } from '../pages/AuthLayout';
import styles from './FileDrop.module.css';

export type FileDropProps = {
  /** Eine gewählte `.json`-Datei. Andere Dateien weist die Fläche selbst ab. */
  onFile: (file: File) => void;
  /** Name der zuletzt gewählten Datei. */
  fileName?: string;
  disabled?: boolean;
};

const WRONG_TYPE = 'Das ist keine .json-Datei. Wähle die Speisekarten-Datei aus.';

/** Fläche zum Hineinziehen oder Auswählen der Speisekarten-Datei. Mit Tastatur: Tab zur Fläche, Enter oder Leertaste. */
export function FileDrop({ onFile, fileName, disabled = false }: FileDropProps) {
  const inputId = useId();
  const [over, setOver] = useState(false);
  const [rejected, setRejected] = useState(false);

  const take = (file: File | undefined) => {
    if (!file || disabled) return;
    if (!file.name.toLowerCase().endsWith('.json')) {
      setRejected(true);
      return;
    }
    setRejected(false);
    onFile(file);
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
          accept=".json,application/json"
          className={styles.input}
          disabled={disabled}
          onChange={(e) => {
            take(e.target.files?.[0]);
            // Dieselbe Datei nach einer Korrektur nochmal wählen können.
            e.target.value = '';
          }}
        />
        <UploadIcon size={28} className={styles.icon} />
        <span className={styles.title}>Speisekarten-Datei hierher ziehen oder auswählen</span>
        <span className={styles.hint}>{fileName ? fileName : 'Nur .json, bis 1 MB'}</span>
      </label>
      {rejected && <FormAlert>{WRONG_TYPE}</FormAlert>}
    </div>
  );
}

/** Der Fehler einer Datei: bei `menu_invalid` die Zahl und jede Zeile der Probleme, sonst der Text des Servers. */
export function UploadError({ error }: { error: ApiError }) {
  if (error.code === 'menu_invalid' && error.problems && error.problems.length > 0) {
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
