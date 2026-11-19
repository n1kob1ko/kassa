import { useId } from 'react';
import styles from './Segmented.module.css';

export type SegmentedOption<T extends string> = { value: T; label: string };

export type SegmentedProps<T extends string> = {
  /** Name der Gruppe für Screenreader, etwa "Zeitraum". */
  label: string;
  options: SegmentedOption<T>[];
  value: T;
  onChange: (value: T) => void;
  className?: string;
};

/**
 * Umschalter in Segmenten (wie "Mit Bildern / Kompakt" in der App): eine Gruppe echter Auswahlknöpfe, also ein
 * Tab-Halt und Pfeiltasten von selbst. Der gewählte Knopf ist eine Karte auf `fill2`. Jedes Segment ist 44 px hoch.
 */
export function Segmented<T extends string>({ label, options, value, onChange, className }: SegmentedProps<T>) {
  const name = useId();
  return (
    <div role="radiogroup" aria-label={label} className={[styles.group, className].filter(Boolean).join(' ')}>
      {options.map((o) => (
        <label key={o.value} className={styles.option}>
          <input
            type="radio"
            className={styles.input}
            name={name}
            value={o.value}
            checked={o.value === value}
            onChange={() => onChange(o.value)}
          />
          <span className={styles.text}>{o.label}</span>
        </label>
      ))}
    </div>
  );
}
