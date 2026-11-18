import type { HTMLAttributes } from 'react';
import styles from './Card.module.css';

/** Weiße Karte mit 20 px Rundung und feiner Linie. */
export function Card({ className, ...rest }: HTMLAttributes<HTMLElement>) {
  return <section className={[styles.card, className].filter(Boolean).join(' ')} {...rest} />;
}
