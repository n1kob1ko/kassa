import type { ReactNode } from 'react';
import { Card } from '../ui/Card';
import { AlertIcon } from '../ui/icons';
import { Logo } from '../ui/Logo';
import styles from './AuthLayout.module.css';

/** Rahmen der Seiten ohne Anmeldung: Logo, eine Karte mit Titel, darunter ein kurzer Hinweis. */
export function AuthLayout({
  title,
  lead,
  children,
  footer,
}: {
  title: string;
  lead?: ReactNode;
  children: ReactNode;
  footer?: ReactNode;
}) {
  return (
    <main className={styles.page}>
      <div className={styles.column}>
        <div className={styles.logo}>
          <Logo />
        </div>
        <Card className={styles.card}>
          <div className={styles.heading}>
            <h1 className={styles.title}>{title}</h1>
            {lead && <p className={styles.lead}>{lead}</p>}
          </div>
          {children}
        </Card>
        {footer && <p className={styles.footer}>{footer}</p>}
      </div>
    </main>
  );
}

/** Meldung über dem Knopf eines Formulars, wenn sie zu keinem einzelnen Feld gehört. */
export function FormAlert({ children }: { children: ReactNode }) {
  return (
    <p className={styles.alert} role="alert">
      <AlertIcon size={18} className={styles.alertIcon} />
      <span>{children}</span>
    </p>
  );
}

export const formClass = styles.form;
