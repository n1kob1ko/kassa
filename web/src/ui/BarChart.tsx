import { useLayoutEffect, useRef, useState, type CSSProperties, type KeyboardEvent, type PointerEvent } from 'react';
import { money } from '../format';
import styles from './BarChart.module.css';

export type ChartBucket = {
  /** Eindeutig im Diagramm, etwa der Beginn als Zeitpunkt. */
  key: string;
  /** Kurz unter der Achse: "14" oder "19.11.". */
  axisLabel: string;
  /** Ausgeschrieben für Anzeige und Screenreader: "14 Uhr" oder "19.11.". */
  name: string;
  cents: number;
};

export type BarChartProps = {
  buckets: ChartBucket[];
  /** Titel über dem Diagramm und Name der Gruppe: "Umsatz pro Stunde". */
  label: string;
};

/** Ungefähre Breite einer Achsenbeschriftung in px pro Zeichen bei 12 px, plus Luft dazwischen. */
const CHAR_PX = 7.2;
const LABEL_GAP_PX = 10;

/** Obere Linie: die kleinste runde Zahl in Euro (1; 1,2; 1,5; 2; 2,5; 3; 4; 5; 6; 8; 10 mal eine Zehnerpotenz), die den größten Wert fasst. */
export function niceTop(maxCents: number): number {
  const euros = maxCents / 100;
  if (euros <= 1) return 100;
  const power = 10 ** Math.floor(Math.log10(euros));
  const step = [1, 1.2, 1.5, 2, 2.5, 3, 4, 5, 6, 8, 10].find((m) => m * power >= euros) ?? 10;
  return Math.round(step * power * 100);
}

/** Jede wievielte Beschriftung passt nebeneinander, ohne dass sie sich berühren. Die letzte steht immer. */
export function labelStep(count: number, longest: number, width: number): number {
  if (count <= 1 || width <= 0) return 1;
  return Math.max(1, Math.ceil((count * (longest * CHAR_PX + LABEL_GAP_PX)) / width));
}

function tick(cents: number): string {
  return money(cents).replace(',00', '');
}

function useWidth<T extends HTMLElement>() {
  const ref = useRef<T>(null);
  const [width, setWidth] = useState(0);
  useLayoutEffect(() => {
    const el = ref.current;
    if (!el) return;
    setWidth(el.clientWidth);
    const observer = new ResizeObserver(([entry]) => setWidth(entry!.contentRect.width));
    observer.observe(el);
    return () => observer.disconnect();
  }, []);
  return [ref, width] as const;
}

/**
 * Säulen für eine Reihe (ohne Legende, der Titel nennt sie). Jede Säule ist ein Knopf mit Zeit und Betrag als Namen;
 * die Gruppe ist ein Tab-Halt, Pfeile, Pos1 und Ende wandern. Zeiger und Finger wählen die Säule unter sich, auch beim
 * Wischen über das Diagramm, also ist die ganze Fläche die Tippfläche. Was gewählt ist, steht oben rechts als Text;
 * ohne Wahl die höchste Säule. Säulen ohne Umsatz behalten ihren Platz auf der Achse.
 */
export function BarChart({ buckets, label }: BarChartProps) {
  const [barsRef, width] = useWidth<HTMLDivElement>();
  const [picked, setPicked] = useState<string | null>(null);
  const [hovered, setHovered] = useState<number | null>(null);

  const n = buckets.length;
  const max = buckets.reduce((m, b) => Math.max(m, b.cents), 0);
  const top = niceTop(max);
  const highest = buckets.findIndex((b) => b.cents === max);
  const pickedIndex = picked === null ? -1 : buckets.findIndex((b) => b.key === picked);
  const chosen = pickedIndex >= 0 ? pickedIndex : Math.max(0, highest);
  const active = hovered !== null && hovered < n ? hovered : chosen;
  const shown = buckets[active];

  const longest = buckets.reduce((m, b) => Math.max(m, b.axisLabel.length), 1);
  const step = labelStep(n, longest, width);
  // Ist eine Beschriftung breiter als ihre Säule, schließt sie am Rand bündig ab, statt überzustehen.
  const overhang = n > 1 && width > 0 && longest * CHAR_PX > width / n;

  const focusBar = (i: number) => {
    const target = Math.min(n - 1, Math.max(0, i));
    setPicked(buckets[target]!.key);
    barsRef.current?.querySelectorAll<HTMLButtonElement>('button')[target]?.focus();
  };

  const onKeyDown = (e: KeyboardEvent<HTMLDivElement>) => {
    const moves: Record<string, number> = { ArrowLeft: chosen - 1, ArrowRight: chosen + 1, Home: 0, End: n - 1 };
    const next = moves[e.key];
    if (next === undefined) return;
    e.preventDefault();
    focusBar(next);
  };

  const indexAt = (e: PointerEvent<HTMLDivElement>) => {
    const rect = e.currentTarget.getBoundingClientRect();
    return Math.min(n - 1, Math.max(0, Math.floor(((e.clientX - rect.left) / rect.width) * n)));
  };

  return (
    <figure className={styles.chart}>
      <div className={styles.head}>
        <h3 className={styles.title}>{label}</h3>
        {shown && (
          <p className={styles.readout} data-testid="bar-readout">
            <span className={styles.readoutName}>{shown.name}</span> <span className={styles.readoutValue}>{money(shown.cents)}</span>
          </p>
        )}
      </div>

      <div className={styles.plot}>
        <div className={styles.ticks} aria-hidden="true">
          <span>{tick(top)}</span>
          <span>{tick(top / 2)}</span>
          <span>{tick(0)}</span>
        </div>
        <div className={styles.area}>
          <div className={styles.grid} aria-hidden="true">
            <span />
            <span />
            <span />
          </div>
          <div
            ref={barsRef}
            role="group"
            aria-label={label}
            className={styles.bars}
            onKeyDown={onKeyDown}
            onPointerMove={(e) => {
              const i = indexAt(e);
              setHovered(i);
              // Mit dem Finger über das Diagramm wischen: was zuletzt unter dem Finger war, bleibt gewählt.
              if (e.pointerType !== 'mouse' && e.buttons > 0) setPicked(buckets[i]!.key);
            }}
            onPointerDown={(e) => {
              const i = indexAt(e);
              setHovered(i);
              setPicked(buckets[i]!.key);
            }}
            onPointerLeave={() => setHovered(null)}
            onPointerCancel={() => setHovered(null)}
          >
            {buckets.map((b, i) => (
              <button
                key={b.key}
                type="button"
                className={styles.slot}
                tabIndex={i === chosen ? 0 : -1}
                aria-label={`${b.name}: ${money(b.cents)}`}
                data-active={i === active || undefined}
                onFocus={() => setPicked(b.key)}
              >
                <span
                  className={b.cents > 0 ? styles.bar : styles.empty}
                  // Die Höhe als Anteil an der oberen Linie. Gesetzt über das CSSOM, nicht als Attribut im HTML.
                  style={{ '--v': Math.max(0, b.cents) / top } as CSSProperties}
                />
              </button>
            ))}
          </div>
        </div>
        <div className={styles.axis} aria-hidden="true">
          {buckets.map((b, i) => {
            const show = (n - 1 - i) % step === 0;
            const edge = !overhang ? '' : i === n - 1 ? styles.end : i === 0 ? styles.start : '';
            return (
              <span key={b.key} className={styles.axisSlot}>
                {show && <span className={[styles.axisLabel, edge].filter(Boolean).join(' ')}>{b.axisLabel}</span>}
              </span>
            );
          })}
        </div>
      </div>
    </figure>
  );
}
