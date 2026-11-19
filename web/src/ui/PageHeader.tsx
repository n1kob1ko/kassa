import type { ReactNode } from 'react';
import styles from './PageHeader.module.css';

export type PageHeaderProps = {
  title: string;
  /** Eine Zeile unter dem Titel, etwa der Name des Betriebs. */
  subtitle?: ReactNode;
  /** Knöpfe rechts neben dem Titel (unter 640 px darunter). */
  actions?: ReactNode;
  /** Unter 640 px nutzen die Bedienelemente rechts die ganze Breite (der Umschalter auf "Umsätze"). */
  wideActions?: boolean;
};

export function PageHeader({ title, subtitle, actions, wideActions = false }: PageHeaderProps) {
  return (
    <header className={styles.header}>
      <div className={styles.text}>
        <h1 className={styles.title}>{title}</h1>
        {subtitle && <p className={styles.subtitle}>{subtitle}</p>}
      </div>
      {actions && <div className={[styles.actions, wideActions ? styles.wide : ''].filter(Boolean).join(' ')}>{actions}</div>}
    </header>
  );
}
