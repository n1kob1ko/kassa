import { useId, useState } from 'react';
import { useSearchParams } from 'react-router';
import {
  filterFromParams,
  filterToParams,
  isFiltered,
  useReceipt,
  useReceipts,
  type ReceiptFilter,
  type ReceiptHead,
} from '../api/receipts';
import { dateInputValue, dayHeading, dayKey, money, timeText } from '../format';
import { Button } from '../ui/Button';
import { LoadError } from '../ui/DataList';
import { Dialog } from '../ui/Dialog';
import { EmptyState } from '../ui/EmptyState';
import { CloseIcon } from '../ui/icons';
import { PageHeader } from '../ui/PageHeader';
import { RowGroup, RowLink, RowListSkeleton } from '../ui/RowList';
import { Segmented } from '../ui/Segmented';
import { Switch } from '../ui/Switch';
import { useBusinessContext } from './BusinessLayout';
import { ReceiptChips, ReceiptDetailView, SPECIAL_NAMES } from './ReceiptDetail';
import { useDetailRoute } from './useDetailRoute';
import styles from './ReceiptsPage.module.css';

type PaymentChoice = 'all' | 'cash' | 'card';
const PAYMENTS: { value: PaymentChoice; label: string }[] = [
  { value: 'all', label: 'Alle' },
  { value: 'cash', label: 'Bar' },
  { value: 'card', label: 'Karte' },
];

function Amount({ receipt }: { receipt: ReceiptHead }) {
  const special = SPECIAL_NAMES[receipt.kind];
  if (special) return <span className={[styles.amount, styles.special].join(' ')}>{special}</span>;
  return (
    <span className={[styles.amount, receipt.voided ? styles.struck : ''].filter(Boolean).join(' ')}>
      {money(receipt.totalCents)}
    </span>
  );
}

function Filters({ filter, onChange }: { filter: ReceiptFilter; onChange: (f: ReceiptFilter) => void }) {
  const dayId = useId();
  return (
    <div className={styles.filters} role="group" aria-label="Filter">
      <div className={styles.dayFilter}>
        <div className={styles.dayField} data-empty={filter.day === null || undefined}>
          <label className={styles.dayLabel} htmlFor={dayId}>
            Tag
          </label>
          <input
            id={dayId}
            type="date"
            className={styles.dayInput}
            value={filter.day ?? ''}
            onChange={(e) => onChange({ ...filter, day: e.currentTarget.value || null })}
          />
          {/* Leer heißt alle Tage: das sagt das Feld, statt "tt.mm.jjjj" zu zeigen. */}
          <span className={styles.dayAll} aria-hidden="true">
            Alle Tage
          </span>
        </div>
        {filter.day !== null && (
          <button
            type="button"
            className={styles.clearDay}
            aria-label="Tag löschen"
            onClick={() => onChange({ ...filter, day: null })}
          >
            <CloseIcon size={18} />
          </button>
        )}
        <Button
          variant="secondary"
          className={styles.today}
          onClick={() => onChange({ ...filter, day: dateInputValue(new Date()) })}
        >
          Heute
        </Button>
      </div>
      <Segmented
        label="Zahlungsart"
        className={styles.payment}
        options={PAYMENTS}
        value={filter.payment ?? 'all'}
        onChange={(value) => onChange({ ...filter, payment: value === 'all' ? null : value })}
      />
      <Switch
        label="Nur Stornos"
        className={styles.voided}
        checked={filter.voidedOnly}
        onChange={(voidedOnly) => onChange({ ...filter, voidedOnly })}
      />
    </div>
  );
}

/** Bons nach Tag gruppiert (in Wiener Zeit), in der Reihenfolge der Liste. */
function byDay(receipts: ReceiptHead[]): { key: string; first: Date; receipts: ReceiptHead[] }[] {
  const groups: { key: string; first: Date; receipts: ReceiptHead[] }[] = [];
  for (const r of receipts) {
    const at = new Date(r.createdAt);
    const key = dayKey(at);
    const last = groups[groups.length - 1];
    if (last && last.key === key) last.receipts.push(r);
    else groups.push({ key, first: at, receipts: [r] });
  }
  return groups;
}

export function ReceiptsPage() {
  const { detail } = useBusinessContext();
  const b = detail.business;
  const listPath = `/b/${b.id}/bons`;
  const [params, setParams] = useSearchParams();
  const route = useDetailRoute(listPath);

  // Die Filter folgen dem Finger sofort, die Adresse zieht nach (wie auf "Umsätze"). Ändert sich die Adresse von
  // außen (Zurück, Neuladen), gilt sie.
  const fromAddress = filterFromParams(params);
  const addressKey = JSON.stringify(fromAddress);
  const [filter, setFilter] = useState(fromAddress);
  const [seen, setSeen] = useState(addressKey);
  if (addressKey !== seen) {
    setSeen(addressKey);
    setFilter(fromAddress);
  }
  const change = (next: ReceiptFilter) => {
    setFilter(next);
    setParams((current) => filterToParams(next, current), { replace: true });
  };

  const query = useReceipts(b.id, filter);
  const receipts = query.data?.pages.flatMap((p) => p.receipts) ?? [];
  const filtered = isFiltered(filter);
  const now = new Date();

  let body;
  if (query.data && receipts.length === 0) {
    body = filtered ? (
      <EmptyState
        title="Kein Bon passt zu diesem Filter."
        text="Wähl einen anderen Tag oder eine andere Zahlungsart."
        action={
          <Button variant="secondary" onClick={() => change({ day: null, payment: null, voidedOnly: false })}>
            Filter zurücksetzen
          </Button>
        }
      />
    ) : (
      <EmptyState title="Noch kein Bon." text="Sobald an der Kassa boniert wird, erscheinen die Umsätze hier." />
    );
  } else if (query.data) {
    // Mit einem Tag im Filter steht das Datum schon oben; sonst trägt jede Gruppe ihren Tag als Überschrift.
    const groups = byDay(receipts);
    body = (
      <div className={styles.list} aria-busy={query.isPlaceholderData || undefined}>
        {groups.map((g) => (
          <RowGroup
            key={g.key}
            label={filter.day ? 'Bons' : `Bons ${dayHeading(g.first, now)}`}
            heading={filter.day ? undefined : dayHeading(g.first, now)}
          >
            {g.receipts.map((r) => (
              <RowLink
                key={r.id}
                rowId={r.id}
                to={route.detailTo(r.id)}
                state={route.fromListState}
                selected={route.id === r.id}
                className={styles.row}
              >
                {/* Leerzeichen zwischen den Teilen: der Name des Links liest sich "Bon 12 14:05 Theke · Chefin …". */}
                <span className={styles.number}>Bon {r.number}</span>{' '}
                <span className={styles.meta}>
                  <span className={styles.time}>{timeText(new Date(r.createdAt))}</span>{' '}
                  <span className={styles.who}>{[r.registerName, r.staffName].filter(Boolean).join(' · ')}</span>
                </span>{' '}
                <span className={styles.chips}>
                  <ReceiptChips receipt={r} />
                </span>{' '}
                <Amount receipt={r} />
              </RowLink>
            ))}
          </RowGroup>
        ))}
        {(query.hasNextPage || query.isFetchNextPageError) && (
          // Ein Knopf an derselben Stelle: nach einem Fehler heißt er "Nochmal versuchen", der Fokus bleibt auf ihm.
          <div className={styles.more}>
            {query.isFetchNextPageError && (
              <p className={styles.moreError} role="alert">
                Weitere Bons konnten nicht geladen werden.
              </p>
            )}
            <Button variant="secondary" busy={query.isFetchingNextPage} onClick={() => void query.fetchNextPage()}>
              {query.isFetchNextPageError ? 'Nochmal versuchen' : 'Mehr laden'}
            </Button>
          </div>
        )}
      </div>
    );
  } else if (query.isError) {
    body = <LoadError message={query.error.message} onRetry={() => void query.refetch()} />;
  } else {
    body = <RowListSkeleton rows={8} label="Bons werden geladen" headings={!filter.day} />;
  }

  // Ohne einen einzigen Bon gibt es nichts zu filtern.
  const showFilters = filtered || receipts.length > 0 || !query.data;
  const opened = useReceipt(b.id, route.id);
  const openNumber = opened.data?.number ?? receipts.find((r) => r.id === route.id)?.number;

  return (
    <>
      <PageHeader title="Bons" subtitle={b.name} />
      {showFilters && <Filters filter={filter} onChange={change} />}
      {body}
      <Dialog
        variant="side"
        title={openNumber === undefined ? 'Bon' : `Bon ${openNumber}`}
        open={route.id !== null}
        onClose={route.close}
        returnFocus={route.rowOf}
      >
        {route.id && (
          <ReceiptDetailView
            businessId={b.id}
            query={opened}
            linkTo={(id) => ({ to: route.detailTo(id), state: route.currentState })}
          />
        )}
      </Dialog>
    </>
  );
}
