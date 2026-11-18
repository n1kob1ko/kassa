import type { ReactNode } from 'react';
import { BanIcon, CheckCircleIcon } from './icons';
import styles from './StatusChip.module.css';

export type StatusChipProps = {
  /** `ok` grün mit Haken, `off` rot mit Strich, `neutral` grau. Der Zustand steht immer auch im Text. */
  tone: 'ok' | 'off' | 'neutral';
  children: ReactNode;
};

export function StatusChip({ tone, children }: StatusChipProps) {
  return (
    <span className={[styles.chip, styles[tone]].join(' ')}>
      {tone === 'ok' && <CheckCircleIcon size={16} />}
      {tone === 'off' && <BanIcon size={16} />}
      {children}
    </span>
  );
}
