import type { ReactNode } from 'react';
import styles from './EmptyState.module.css';

export type EmptyStateProps = {
  title: string;
  /** Sagt, was als Nächstes zu tun ist. */
  text: ReactNode;
  action?: ReactNode;
};

export function EmptyState({ title, text, action }: EmptyStateProps) {
  return (
    <div className={styles.empty}>
      <h2 className={styles.title}>{title}</h2>
      <p className={styles.text}>{text}</p>
      {action && <div className={styles.action}>{action}</div>}
    </div>
  );
}
