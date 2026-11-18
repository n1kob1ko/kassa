import { useId, type ComponentPropsWithRef, type ReactNode } from 'react';
import { AlertIcon } from './icons';
import styles from './TextField.module.css';

export type TextFieldProps = ComponentPropsWithRef<'input'> & {
  label: string;
  /** Meldung am Feld: sagt, was nicht stimmt und was zu tun ist. */
  error?: ReactNode;
  hint?: ReactNode;
};

/** Eingabefeld, 44 px hoch, Beschriftung darüber, Hinweis oder Meldung darunter. */
export function TextField({ label, error, hint, id, className, ref, ...input }: TextFieldProps) {
  const autoId = useId();
  const inputId = id ?? autoId;
  const hintId = `${inputId}-hinweis`;
  const errorId = `${inputId}-meldung`;
  const describedBy = [error ? errorId : null, hint ? hintId : null].filter(Boolean).join(' ') || undefined;

  return (
    <div className={[styles.field, className].filter(Boolean).join(' ')}>
      <label className={styles.label} htmlFor={inputId}>
        {label}
      </label>
      <input
        ref={ref}
        id={inputId}
        className={styles.input}
        aria-invalid={error ? true : undefined}
        aria-describedby={describedBy}
        {...input}
      />
      {error && (
        <p id={errorId} className={styles.error}>
          <AlertIcon size={16} className={styles.errorIcon} />
          <span>{error}</span>
        </p>
      )}
      {hint && (
        <p id={hintId} className={styles.hint}>
          {hint}
        </p>
      )}
    </div>
  );
}
