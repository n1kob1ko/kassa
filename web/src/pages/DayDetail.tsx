import type { UseQueryResult } from '@tanstack/react-query';
import type { ApiError } from '../api/client';
import type { CashMovement, DayDetail } from '../api/days';
import { count, money, signedMoney, timeText } from '../format';
import { Button } from '../ui/Button';
import { StatusChip } from '../ui/StatusChip';
import styles from './DayDetail.module.css';

/** Gründe einer Bewegung wie in der App (`close_format.dart`); Unbekanntes steht, wie es kommt. */
const REASONS: Record<string, string> = { bank: 'Bank', purchase: 'Einkauf', change: 'Wechselgeld', other: 'Sonstiges' };

function movementText(m: CashMovement): string {
  const verb = m.kind === 'deposit' ? 'Eingelegt' : 'Entnommen';
  return m.reason ? `${verb}: ${REASONS[m.reason] ?? m.reason}` : verb;
}

/** Differenz mit Vorzeichen und dem Wort davor; nicht 0 in der Warnfarbe, nie nur als Farbe. */
export function Difference({ cents }: { cents: number }) {
  return (
    <span className={styles.difference} data-warn={cents !== 0 || undefined}>
      <span className={styles.differenceLabel}>Differenz</span> <span>{signedMoney(cents)}</span>
    </span>
  );
}

function Figure({ label, cents, testId, strong = false }: { label: string; cents: number; testId: string; strong?: boolean }) {
  return (
    <div className={[styles.figure, strong ? styles.strong : ''].filter(Boolean).join(' ')}>
      <dt>{label}</dt>
      <dd data-testid={testId}>{money(cents)}</dd>
    </div>
  );
}

function DetailSkeleton() {
  return (
    <div className={styles.detail} role="status" aria-busy="true">
      <span className="visually-hidden">Tag wird geladen</span>
      {[0, 1, 2, 3, 4].map((i) => (
        <span key={i} className={styles.bone} aria-hidden="true" />
      ))}
    </div>
  );
}

/** Inhalt des Blatts eines Tages: Wechselgeld, Umsatz, Abschluss und Bewegungen. Nichts daran ist änderbar. */
export function DayDetailView({ query }: { query: UseQueryResult<DayDetail, ApiError> }) {
  // Scheitert nur ein Neuladen, bleibt der Tag stehen.
  if (query.isError && !query.data) {
    return query.error.status === 404 ? (
      <p className={styles.problem}>Diesen Tag gibt es nicht. Prüf die Adresse.</p>
    ) : (
      <div className={styles.problemBox}>
        <p className={styles.problem}>{query.error.message}</p>
        <Button variant="secondary" onClick={() => void query.refetch()}>
          Nochmal versuchen
        </Button>
      </div>
    );
  }
  const d = query.data;
  if (!d) return <DetailSkeleton />;
  const opened = new Date(d.openedAt);
  const closed = d.closedAt ? new Date(d.closedAt) : null;

  return (
    <div className={styles.detail}>
      <div className={styles.head}>
        <p className={styles.meta}>
          {[
            `Geöffnet ${timeText(opened)}`,
            closed ? `Abschluss ${timeText(closed)}${d.closedByName ? ` von ${d.closedByName}` : ''}` : null,
          ]
            .filter(Boolean)
            .join(' · ')}
        </p>
        {!closed && (
          <div className={styles.open}>
            <StatusChip tone="neutral">offen</StatusChip>
            <p className={styles.openText}>Erwartet und gezählt stehen hier nach dem Abschluss.</p>
          </div>
        )}
      </div>

      <dl className={styles.figures}>
        <Figure label="Wechselgeld" cents={d.openingFloatCents} testId="opening-float" />
        <div className={styles.figure}>
          <dt>
            Umsatz <span className={styles.note}>{count(d.receiptCount, 'Bon', 'Bons')}</span>
          </dt>
          <dd data-testid="revenue">{money(d.revenueCents)}</dd>
        </div>
        {closed && d.expectedCents !== null && <Figure label="Erwartet" cents={d.expectedCents} testId="expected" />}
        {closed && d.countedCents !== null && <Figure label="Gezählt" cents={d.countedCents} testId="counted" strong />}
        {closed && d.differenceCents !== null && (
          <div className={styles.figure}>
            <dt>Differenz</dt>
            <dd>
              <span className={styles.differenceValue} data-warn={d.differenceCents !== 0 || undefined} data-testid="difference">
                {signedMoney(d.differenceCents)}
              </span>
            </dd>
          </div>
        )}
        {closed && d.leftInDrawerCents !== null && (
          <Figure label="In der Lade gelassen" cents={d.leftInDrawerCents} testId="left-in-drawer" />
        )}
      </dl>

      <section className={styles.section} aria-labelledby="tag-bewegungen">
        <h3 id="tag-bewegungen" className={styles.sectionTitle}>
          Bewegungen
        </h3>
        {d.movements.length === 0 ? (
          <p className={styles.problem}>Kein Bargeld eingelegt oder entnommen.</p>
        ) : (
          <ul className={styles.movements} aria-label="Bewegungen">
            {d.movements.map((m, i) => (
              <li key={`${m.createdAt}-${i}`} className={styles.movement}>
                <span className={styles.movementText}>
                  <span className={styles.movementName}>{movementText(m)}</span>
                  <span className={styles.note}>
                    {timeText(new Date(m.createdAt))} · {m.staffName}
                  </span>
                </span>
                <span className={styles.movementAmount}>
                  {signedMoney(m.kind === 'withdrawal' ? -m.amountCents : m.amountCents)}
                </span>
              </li>
            ))}
          </ul>
        )}
      </section>
    </div>
  );
}
