import { useEffect, useId, useRef, useState } from 'react';
import { parsePrice, priceText } from '../pages/validate';
import { AlertIcon } from './icons';
import styles from './PriceField.module.css';

export const PRICE_PROBLEM = 'Gib einen Preis wie 9,90 ein.';

export type PriceFieldProps = {
  /** Name für Screenreader, etwa "Huhn Bowl: Preis". */
  label: string;
  /** Der gespeicherte (oder gerade gespeicherte) Preis in Cent. */
  cents: number;
  /** Ein neuer, lesbarer Preis, der sich vom gespeicherten unterscheidet. */
  onCommit: (cents: number) => void;
  /** Klasse für das Feld und für die Meldung: die Zeile stellt beide in ihr Raster. */
  className?: string;
  errorClassName?: string;
};

/**
 * Preisfeld: zeigt `9,90`, das Eurozeichen steht fest daneben. Antippen markiert den Preis. Enter und Verlassen
 * speichern, aber nur einen anderen Preis; Escape stellt den gespeicherten wieder her und bleibt im Feld.
 * Unlesbares bleibt stehen, die Meldung steht am Feld, gespeichert wird nichts.
 */
export function PriceField({ label, cents, onCommit, className, errorClassName }: PriceFieldProps) {
  const errorId = useId();
  const [text, setText] = useState(() => priceText(cents));
  const [editing, setEditing] = useState(false);
  const [invalid, setInvalid] = useState(false);
  // Der zuletzt abgeschickte Preis, bis er als `cents` zurückkommt: Enter und gleich danach Verlassen speichert nur einmal.
  const sent = useRef<number | null>(null);
  const justFocused = useRef(false);

  // Kommt ein anderer Preis vom Server (oder springt er nach einem Fehler zurück), steht er da, solange niemand tippt.
  useEffect(() => {
    sent.current = null;
  }, [cents]);
  useEffect(() => {
    if (!editing && !invalid) setText(priceText(cents));
  }, [cents, editing, invalid]);

  const commit = () => {
    const value = parsePrice(text);
    if (value === null) {
      setInvalid(true);
      return;
    }
    setInvalid(false);
    setEditing(false);
    setText(priceText(value));
    if (value !== (sent.current ?? cents)) {
      sent.current = value;
      onCommit(value);
    }
  };

  const restore = () => {
    setInvalid(false);
    setEditing(false);
    setText(priceText(cents));
  };

  return (
    <>
      {/* Ein Klick auf das Eurozeichen oder den Rand setzt den Fokus ins Feld. */}
      <label className={[styles.box, invalid ? styles.invalid : '', className].filter(Boolean).join(' ')}>
        <input
          className={styles.input}
          type="text"
          inputMode="decimal"
          autoComplete="off"
          enterKeyHint="done"
          spellCheck={false}
          aria-label={label}
          aria-invalid={invalid || undefined}
          aria-describedby={invalid ? errorId : undefined}
          value={text}
          onFocus={(e) => {
            justFocused.current = true;
            e.currentTarget.select();
          }}
          // Das Loslassen des Klicks, der den Fokus brachte, würde die Markierung wieder aufheben.
          onMouseUp={(e) => {
            if (justFocused.current) e.preventDefault();
            justFocused.current = false;
          }}
          onChange={(e) => {
            setEditing(true);
            setText(e.currentTarget.value);
          }}
          onKeyDown={(e) => {
            justFocused.current = false;
            if (e.key === 'Enter') {
              e.preventDefault();
              commit();
            } else if (e.key === 'Escape') {
              e.preventDefault();
              e.stopPropagation();
              const input = e.currentTarget;
              restore();
              requestAnimationFrame(() => input.select());
            }
          }}
          onBlur={commit}
        />
        <span className={styles.suffix} aria-hidden="true">
          €
        </span>
      </label>
      {invalid && (
        <p id={errorId} className={[styles.error, errorClassName].filter(Boolean).join(' ')}>
          <AlertIcon size={16} className={styles.errorIcon} />
          <span>{PRICE_PROBLEM}</span>
        </p>
      )}
    </>
  );
}
