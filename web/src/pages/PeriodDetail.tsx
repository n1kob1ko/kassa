import type { UseQueryResult } from '@tanstack/react-query';
import type { ReactNode } from 'react';
import type { ApiError } from '../api/client';
import type { TaxLine } from '../api/days';
import type { PeriodSummary } from '../api/months';
import { count, money } from '../format';
import { dayLabel, monthLabel, periodDates, type Period } from '../period';
import { Button } from '../ui/Button';
import { StatusChip } from '../ui/StatusChip';
import styles from './PeriodDetail.module.css';

const PERIOD_NOT_FOUND = 'Diese Abrechnung gibt es nicht.';

const bons = (n: number) => count(n, 'Bon', 'Bons');

/** Eine Zeile der Einnahmen: Name, Anzahl Bons klein daneben, Betrag rechts. */
function IncomeRow({
  label,
  receipts,
  cents,
  testId,
  tone = 'normal',
}: {
  label: string;
  receipts: number;
  cents: number;
  testId: string;
  /** `total` fett (Gesamt), `muted` ruhig (Storniert). */
  tone?: 'normal' | 'total' | 'muted';
}) {
  return (
    <div className={styles.row} data-tone={tone}>
      <dt className={styles.label}>
        {label} <span className={styles.note} data-testid={`${testId}-count`}>{bons(receipts)}</span>
      </dt>
      <dd className={styles.amount} data-testid={testId}>
        {money(cents)}
      </dd>
    </div>
  );
}

/** Eine Zeile mit Betrag ohne Anzahl Bons; `person` eingerückt und ruhig (Trinkgeld je Person). */
function AmountRow({ label, cents, testId, tone = 'normal' }: { label: string; cents: number; testId: string; tone?: 'normal' | 'person' }) {
  return (
    <div className={styles.row} data-tone={tone}>
      <dt className={styles.label}>{label}</dt>
      <dd className={styles.amount} data-testid={testId}>
        {money(cents)}
      </dd>
    </div>
  );
}

/** Steuer je Satz (Umsatz brutto und davon MwSt), darunter das Pfand ohne MwSt, wenn es eines gibt. */
export function TaxTable({ lines, depositCents }: { lines: TaxLine[]; depositCents: number }) {
  if (lines.length === 0 && depositCents === 0) return null;
  return (
    <table className={styles.tax} aria-label="Steuer">
      <thead>
        <tr>
          <th scope="col" className={styles.taxTitle}>
            Steuer
          </th>
          <th scope="col">Umsatz</th>
          <th scope="col">davon MwSt</th>
        </tr>
      </thead>
      <tbody>
        {lines.map((l) => (
          <tr key={l.percent}>
            <th scope="row">MwSt {l.percent} %</th>
            <td>{money(l.grossCents)}</td>
            <td className={styles.strongCell}>{money(l.taxCents)}</td>
          </tr>
        ))}
        {depositCents !== 0 && (
          <tr>
            <th scope="row">Pfand, ohne MwSt</th>
            <td data-testid="deposit">{money(depositCents)}</td>
            <td />
          </tr>
        )}
      </tbody>
    </table>
  );
}

function Section({ id, title, children }: { id: string; title: string; children: ReactNode }) {
  return (
    <section className={styles.section} aria-labelledby={id}>
      <h3 id={id} className={styles.sectionTitle}>
        {title}
      </h3>
      {children}
    </section>
  );
}

function DetailSkeleton() {
  return (
    <div className={styles.detail} role="status" aria-busy="true">
      <span className="visually-hidden">Abrechnung wird geladen</span>
      {[0, 1, 2, 3, 4, 5].map((i) => (
        <span key={i} className={styles.bone} aria-hidden="true" />
      ))}
    </div>
  );
}

/**
 * Inhalt des Blatts eines Monats oder Zeitraums: von bis, Einnahmen, Steuer, Pfand und je Tag oder je Monat eine Zeile.
 * `period` ist `null` bei einer unsinnigen Adresse; dann gibt es keine Anfrage.
 */
export function PeriodDetailView({ period, query }: { period: Period | null; query: UseQueryResult<PeriodSummary, ApiError> }) {
  if (period === null) return <p className={styles.problem}>{PERIOD_NOT_FOUND}</p>;
  // Scheitert nur ein Neuladen, bleibt die Abrechnung stehen.
  if (query.isError && !query.data) {
    return query.error.status === 404 || query.error.status === 422 ? (
      <p className={styles.problem}>{PERIOD_NOT_FOUND}</p>
    ) : (
      <div className={styles.problemBox}>
        <p className={styles.problem}>{query.error.message}</p>
        <Button variant="secondary" onClick={() => void query.refetch()}>
          Nochmal versuchen
        </Button>
      </div>
    );
  }
  const s = query.data;
  if (!s) return <DetailSkeleton />;
  const single = period.from === period.to;
  const rowsTitle = single ? 'Tage' : 'Monate';

  return (
    <div className={styles.detail}>
      <div className={styles.head}>
        <p className={styles.meta}>{periodDates(period)} · alle Kassen des Betriebs</p>
        {s.testMode && <StatusChip tone="neutral">Testbetrieb</StatusChip>}
      </div>

      <Section id="zeitraum-einnahmen" title="Einnahmen">
        <dl className={styles.rows}>
          <IncomeRow label="Bar" receipts={s.cashReceiptCount} cents={s.cashRevenueCents} testId="cash" />
          <IncomeRow label="Karte" receipts={s.cardReceiptCount} cents={s.cardRevenueCents} testId="card" />
          <IncomeRow label="Gesamt" receipts={s.receiptCount} cents={s.revenueCents} testId="total" tone="total" />
          {s.voidCount > 0 && (
            <IncomeRow label="Storniert" receipts={s.voidCount} cents={s.voidedCents} testId="voided" tone="muted" />
          )}
          {s.discountCents !== 0 && (
            <IncomeRow label="Rabatte" receipts={s.discountCount} cents={s.discountCents} testId="discounts" />
          )}
          {s.cardTipCents !== 0 && <AmountRow label="Trinkgeld Karte" cents={s.cardTipCents} testId="card-tip" />}
          {s.cardTipCents !== 0 &&
            s.tipsByStaff.map((t) => (
              <AmountRow key={t.staffName} label={t.staffName} cents={t.cents} testId="card-tip-staff" tone="person" />
            ))}
          {s.cardAccountCents !== 0 && <AmountRow label="Am Kartenkonto" cents={s.cardAccountCents} testId="card-account" />}
        </dl>
      </Section>

      <TaxTable lines={s.taxLines} depositCents={s.depositCents} />

      <Section id="zeitraum-zeilen" title={rowsTitle}>
        {s.rows.length === 0 ? (
          <p className={styles.problem}>In diesem Zeitraum gibt es keine Bons.</p>
        ) : (
          <ul className={styles.list} aria-label={rowsTitle}>
            {s.rows.map((r) => (
              <li key={r.key} className={styles.item}>
                <span className={styles.itemLabel}>{single ? dayLabel(r.key) : monthLabel(r.key)}</span>
                <span className={styles.itemCount}>{bons(r.receiptCount)}</span>
                <span className={styles.itemAmount}>{money(r.revenueCents)}</span>
              </li>
            ))}
          </ul>
        )}
      </Section>
    </div>
  );
}
