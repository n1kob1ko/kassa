import type { ButtonHTMLAttributes } from 'react';
import { Link, type LinkProps } from 'react-router';
import styles from './Button.module.css';

export type ButtonProps = ButtonHTMLAttributes<HTMLButtonElement> & {
  variant: 'primary' | 'secondary' | 'danger' | 'quiet';
  /** Während einer Anfrage: der Knopf zeigt einen Kreis, bleibt gleich breit und nimmt keinen Klick an. */
  busy?: boolean;
};

export function Button({ variant, busy = false, className, children, type, disabled, onClick, ...rest }: ButtonProps) {
  return (
    <button
      type={type ?? 'button'}
      className={[styles.button, styles[variant], className].filter(Boolean).join(' ')}
      // Ein beschäftigter Knopf bleibt fokussierbar (kein disabled), damit der Fokus nicht verloren geht.
      aria-disabled={busy || disabled ? true : undefined}
      aria-busy={busy || undefined}
      disabled={disabled}
      onClick={(e) => {
        if (busy) {
          e.preventDefault();
          return;
        }
        onClick?.(e);
      }}
      {...rest}
    >
      <span className={styles.label}>{children}</span>
      {busy && <span className={styles.spinner} aria-hidden="true" />}
    </button>
  );
}

/** Ein Link, der wie ein Knopf aussieht: für einen Weg zu einer anderen Seite. */
export function ButtonLink({ variant, className, children, ...rest }: LinkProps & { variant: 'primary' | 'secondary' }) {
  return (
    <Link className={[styles.button, styles[variant], className].filter(Boolean).join(' ')} {...rest}>
      <span className={styles.label}>{children}</span>
    </Link>
  );
}
