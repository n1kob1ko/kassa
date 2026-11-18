import { useEffect, useState } from 'react';
import { codeGroups, countdown } from '../format';
import styles from './CodeDisplay.module.css';

/** Wie viele Millisekunden bis `expiresAt` bleiben, gegen die Uhr des Browsers, neu gerechnet jede halbe Sekunde. */
export function useRemaining(expiresAt: Date | null): number {
  const [now, setNow] = useState(() => Date.now());
  useEffect(() => {
    if (!expiresAt) return;
    setNow(Date.now());
    const timer = setInterval(() => setNow(Date.now()), 500);
    return () => clearInterval(timer);
  }, [expiresAt]);
  return expiresAt ? expiresAt.getTime() - now : 0;
}

export type CodeDisplayProps = { code: string; remainingMs: number };

/** Der Kopplungscode groß in zwei Vierergruppen, darunter die Restzeit. Abgelaufen steht dort der Hinweis. */
export function CodeDisplay({ code, remainingMs }: CodeDisplayProps) {
  if (remainingMs <= 0) {
    return (
      <div className={styles.box}>
        <p className={styles.expired}>Der Code ist abgelaufen.</p>
      </div>
    );
  }
  return (
    <div className={styles.box}>
      <p className={styles.code} data-testid="pairing-code">
        {codeGroups(code)}
      </p>
      <p className={styles.countdown} role="timer">
        gilt noch {countdown(remainingMs)}
      </p>
    </div>
  );
}
