import styles from './Switch.module.css';

export type SwitchProps = {
  label: string;
  checked: boolean;
  onChange: (checked: boolean) => void;
  className?: string;
  /** Name für Screenreader, wenn er mehr sagen muss als die sichtbare Beschriftung ("Huhn Bowl: im Verkauf"). */
  name?: string;
  /** Klasse für die sichtbare Beschriftung, etwa um sie unter einer Spaltenüberschrift ab einer Breite zu verstecken. */
  labelClassName?: string;
};

/**
 * Schalter wie in der App: Beschriftung links, Bahn 52 × 32 rechts, Knopf 26 px mit 20 px Weg. Ein echtes
 * Kästchen mit `role="switch"`: Leertaste schaltet, der Zustand steht in Position und Farbe, nie nur in Farbe.
 * Die ganze Zeile ist die Tippfläche (mindestens 44 px hoch).
 */
export function Switch({ label, checked, onChange, className, name, labelClassName }: SwitchProps) {
  return (
    <label className={[styles.switch, className].filter(Boolean).join(' ')}>
      <span className={[styles.label, labelClassName].filter(Boolean).join(' ')}>{label}</span>
      <input
        type="checkbox"
        role="switch"
        className={styles.input}
        aria-label={name}
        checked={checked}
        onChange={(e) => onChange(e.currentTarget.checked)}
      />
      <span className={styles.track} aria-hidden="true">
        <span className={styles.knob} />
      </span>
    </label>
  );
}
