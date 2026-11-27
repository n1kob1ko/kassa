import { useState, type CSSProperties } from 'react';
import { useSearchParams } from 'react-router';
import { useOverview, type Overview, type OverviewRange } from '../api/overview';
import { comparison, money, share } from '../format';
import { BarChart, type ChartBucket } from '../ui/BarChart';
import { Card } from '../ui/Card';
import { LoadError } from '../ui/DataList';
import { EmptyState } from '../ui/EmptyState';
import { AlertIcon, ArrowDownIcon, ArrowUpIcon } from '../ui/icons';
import { PageHeader } from '../ui/PageHeader';
import { Segmented } from '../ui/Segmented';
import { BusinessName, useBusinessContext } from './BusinessLayout';
import styles from './OverviewPage.module.css';

/** Der Zeitraum steht in der Adresse (`?zeit=7`, `?zeit=30`), heute ohne. So bleibt er beim Neuladen und Zurück. */
const RANGES: { value: OverviewRange; label: string; param: string | null }[] = [
  { value: 'today', label: 'Heute', param: null },
  { value: 'days7', label: '7 Tage', param: '7' },
  { value: 'days30', label: '30 Tage', param: '30' },
];
const PARAM = 'zeit';

function rangeFrom(param: string | null): OverviewRange {
  return RANGES.find((r) => r.param !== null && r.param === param)?.value ?? 'today';
}

/** Balken des Servers für das Diagramm: Stunden heißen "14 Uhr", Tage bleiben "19.11.". */
function chartBuckets(data: Overview): ChartBucket[] {
  return data.buckets.map((b) => ({
    key: b.start,
    axisLabel: b.label,
    name: data.range === 'today' ? `${b.label} Uhr` : b.label,
    cents: b.cents,
  }));
}

function Comparison({ data }: { data: Overview }) {
  const text = comparison(data.range, data.revenueCents, data.previousRevenueCents, new Date());
  if (!text) return null;
  const tone = text.startsWith('Gleich') ? 'same' : data.revenueCents > data.previousRevenueCents ? 'up' : 'down';
  return (
    <p className={styles.compare} data-tone={tone}>
      {tone === 'up' && <ArrowUpIcon size={16} />}
      {tone === 'down' && <ArrowDownIcon size={16} />}
      {text}
    </p>
  );
}

/** Bar und Karte; mit Gutschein bezahlt als dritte Art, nur wenn nicht 0. */
export function OverviewPayments({ data }: { data: Overview }) {
  const cash = Math.max(0, data.cashCents);
  const card = Math.max(0, data.cardCents);
  const voucher = Math.max(0, data.voucherCents);
  const withVoucher = data.voucherCents !== 0;
  const total = cash + card + (withVoucher ? voucher : 0);
  const parts = [
    { key: 'cash', label: 'Bar', cents: data.cashCents, part: cash, tone: styles.cash },
    { key: 'card', label: 'Karte', cents: data.cardCents, part: card, tone: styles.cardPay },
    ...(withVoucher ? [{ key: 'voucher', label: 'Gutschein', cents: data.voucherCents, part: voucher, tone: styles.voucherPay }] : []),
  ];
  return (
    <Card className={styles.payments} aria-labelledby="umsatz-zahlung">
      <h2 id="umsatz-zahlung" className={styles.cardTitle}>
        {withVoucher ? 'Bar, Karte und Gutschein' : 'Bar und Karte'}
      </h2>
      <div className={styles.split} aria-hidden="true">
        {parts.map((p) =>
          p.part > 0 ? (
            <span key={p.key} className={[styles.splitPart, p.tone].join(' ')} style={{ '--part': p.part } as CSSProperties} />
          ) : null,
        )}
      </div>
      <dl className={styles.payFigures} data-three={withVoucher || undefined}>
        {parts.map((p) => (
          <div key={p.key} className={styles.payFigure}>
            <dt className={styles.payLabel}>
              <span className={[styles.swatch, p.tone].join(' ')} aria-hidden="true" />
              {p.label}
            </dt>
            <dd className={styles.payAmount} data-testid={p.key}>
              {money(p.cents)}
            </dd>
            {total > 0 && (
              <dd className={styles.payShare} data-testid={`${p.key}-share`}>
                {share(p.part, total)} %
              </dd>
            )}
          </div>
        ))}
      </dl>
    </Card>
  );
}

function TopItems({ data }: { data: Overview }) {
  return (
    <Card className={styles.top} aria-labelledby="umsatz-meistverkauft">
      <h2 id="umsatz-meistverkauft" className={styles.cardTitle}>
        Meistverkauft
      </h2>
      {data.topItems.length === 0 ? (
        <p className={styles.muted}>Kein Verkauf in diesem Zeitraum.</p>
      ) : (
        <ol className={styles.rows} aria-label="Meistverkauft">
          {data.topItems.map((item) => (
            <li key={item.name} className={styles.row}>
              <span className={styles.rowName}>{item.name}</span>
              <span className={styles.rowQuantity}>{item.quantity} Stück</span>
              <span className={styles.rowAmount}>{money(item.cents)}</span>
            </li>
          ))}
        </ol>
      )}
    </Card>
  );
}

function Categories({ data }: { data: Overview }) {
  const max = data.byCategory.reduce((m, c) => Math.max(m, c.cents), 0);
  return (
    <Card className={styles.categories} aria-labelledby="umsatz-kategorien">
      <h2 id="umsatz-kategorien" className={styles.cardTitle}>
        Umsatz nach Kategorie
      </h2>
      {data.byCategory.length === 0 ? (
        <p className={styles.muted}>Kein Verkauf in diesem Zeitraum.</p>
      ) : (
        <ul className={styles.rows} aria-label="Umsatz nach Kategorie">
          {data.byCategory.map((c) => (
            <li key={c.name} className={styles.categoryRow}>
              <span className={styles.rowName}>{c.name}</span>
              <span className={styles.rowAmount}>{money(c.cents)}</span>
              <span
                className={styles.categoryBar}
                aria-hidden="true"
                style={{ '--share': max > 0 ? Math.max(0, c.cents) / max : 0 } as CSSProperties}
              />
            </li>
          ))}
        </ul>
      )}
    </Card>
  );
}

function Content({ data, refreshing }: { data: Overview; refreshing: boolean }) {
  return (
    <div className={styles.content} aria-busy={refreshing || undefined}>
      {data.testMode && (
        <p className={styles.testMode}>
          <AlertIcon size={18} />
          Testbetrieb: Alle Bons sind Testbons.
        </p>
      )}
      <div className={styles.layout}>
        <Card className={styles.main} aria-labelledby="umsatz-titel">
          <div className={styles.summary}>
            <div className={styles.revenue}>
              <h2 id="umsatz-titel" className={styles.revenueLabel}>
                Umsatz
              </h2>
              <p className={styles.hero} data-testid="revenue">
                {money(data.revenueCents)}
              </p>
              <Comparison data={data} />
            </div>
            <dl className={styles.figures}>
              <div className={styles.figure}>
                <dt>Bons</dt>
                <dd data-testid="receipt-count">{data.receiptCount}</dd>
              </div>
              <div className={styles.figure}>
                <dt>Stornos</dt>
                <dd data-testid="void-count">{data.voidCount}</dd>
              </div>
            </dl>
          </div>
          <BarChart
            key={data.range}
            emptyText={data.range === 'today' ? 'Heute noch kein Bon.' : 'Kein Verkauf in diesem Zeitraum.'}
            buckets={chartBuckets(data)}
            label={data.range === 'today' ? 'Umsatz pro Stunde' : 'Umsatz pro Tag'}
          />
        </Card>
        <OverviewPayments data={data} />
        <TopItems data={data} />
        <Categories data={data} />
      </div>
    </div>
  );
}

/** Platzhalter beim ersten Laden, in der Form der Seite: große Zahl, Säulen, die Karten rechts. */
function OverviewSkeleton() {
  return (
    <div className={styles.layout} role="status" aria-busy="true">
      <span className="visually-hidden">Umsätze werden geladen</span>
      <Card className={styles.main} aria-hidden="true">
        <span className={[styles.bone, styles.boneLabel].join(' ')} />
        <span className={[styles.bone, styles.boneHero].join(' ')} />
        <span className={[styles.bone, styles.boneChart].join(' ')} />
      </Card>
      {[styles.payments, styles.top, styles.categories].map((area) => (
        <Card key={area} className={area} aria-hidden="true">
          <span className={[styles.bone, styles.boneLabel].join(' ')} />
          <span className={[styles.bone, styles.boneLine].join(' ')} />
          <span className={[styles.bone, styles.boneLine].join(' ')} />
        </Card>
      ))}
    </div>
  );
}

export function OverviewPage() {
  const { detail } = useBusinessContext();
  const b = detail.business;
  const [params, setParams] = useSearchParams();
  const fromAddress = rangeFrom(params.get(PARAM));
  // Der Umschalter folgt dem Finger sofort; die Adresse zieht nach (der Router ändert sie in einem Übergang).
  // Ändert sich die Adresse von außen (Zurück, Link), gilt sie.
  const [range, setRange] = useState(fromAddress);
  const [seen, setSeen] = useState(fromAddress);
  if (fromAddress !== seen) {
    setSeen(fromAddress);
    setRange(fromAddress);
  }
  const query = useOverview(b.id, range);

  const select = (next: OverviewRange) => {
    setRange(next);
    setParams(
      (current) => {
        const updated = new URLSearchParams(current);
        const param = RANGES.find((r) => r.value === next)?.param ?? null;
        if (param === null) updated.delete(PARAM);
        else updated.set(PARAM, param);
        return updated;
      },
      { replace: true },
    );
  };

  const data = query.data;
  let body;
  if (data) {
    body =
      // Leer nur, solange der Betrieb noch gar keinen Bon hat. Ein Zeitraum ohne Bon zeigt die Seite mit 0,00 €.
      !data.hasReceipts ? (
        <EmptyState title="Noch kein Bon." text="Sobald an der Kassa boniert wird, erscheinen die Umsätze hier." />
      ) : (
        // Ein Fehler beim stillen Nachladen lässt die letzten Zahlen stehen.
        <Content data={data} refreshing={query.isPlaceholderData} />
      );
  } else if (query.isError) {
    body = <LoadError message={query.error.message} onRetry={() => void query.refetch()} />;
  } else {
    body = <OverviewSkeleton />;
  }

  return (
    <>
      <PageHeader
        title="Umsätze"
        subtitle={<BusinessName />}
        wideActions
        actions={
          <Segmented
            label="Zeitraum"
            className={styles.switch}
            options={RANGES.map(({ value, label }) => ({ value, label }))}
            value={range}
            onChange={select}
          />
        }
      />
      {body}
    </>
  );
}
