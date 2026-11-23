import { useId, useState } from 'react';
import { useNavigate, type To } from 'react-router';
import { useMonths, usePeriodSummary, type MonthHead } from '../api/months';
import { count, money } from '../format';
import { dayMonthText, monthLabel, parsePeriodId, periodId, periodPrintTitle, periodTitle } from '../period';
import { Button } from '../ui/Button';
import { LoadError } from '../ui/DataList';
import { Dialog } from '../ui/Dialog';
import { EmptyState } from '../ui/EmptyState';
import { PageHeader } from '../ui/PageHeader';
import { RowGroup, RowLink, RowListSkeleton } from '../ui/RowList';
import { StatusChip } from '../ui/StatusChip';
import { BusinessName, useBusinessContext } from './BusinessLayout';
import { ClosingTabs } from './ClosingTabs';
import { PeriodDetailView } from './PeriodDetail';
import { PrintButton, PrintFrame } from './PrintFrame';
import { useDetailRoute } from './useDetailRoute';
import styles from './MonthsPage.module.css';

function MonthRow({ month, to, state, selected }: { month: MonthHead; to: To; state: unknown; selected: boolean }) {
  return (
    <RowLink rowId={month.month} to={to} state={state} selected={selected} className={styles.row}>
      <span className={styles.name}>{monthLabel(month.month)}</span>{' '}
      <span className={styles.count}>{count(month.receiptCount, 'Bon', 'Bons')}</span>{' '}
      <span className={styles.revenue}>
        <span className="visually-hidden">Umsatz </span>
        {money(month.revenueCents)}
      </span>
    </RowLink>
  );
}

/**
 * "Von" vorgewählt: Jänner des Jahres des neuesten Monats, oder der älteste Monat, wenn die Liste später beginnt.
 * "Bis": der neueste Monat.
 */
function defaultFrom(months: MonthHead[]): string {
  const newest = months[0]!.month;
  const sameYear = months.filter((m) => m.month.slice(0, 4) === newest.slice(0, 4));
  return sameYear[sameYear.length - 1]!.month;
}

/** "Mehrere Monate": Von und Bis aus den abgeschlossenen Monaten, "Bis" bietet nur Monate ab "Von". */
function RangePicker({ months, onShow }: { months: MonthHead[]; onShow: (from: string, to: string) => void }) {
  const fromId = useId();
  const toId = useId();
  const [from, setFrom] = useState<string | null>(null);
  const [to, setTo] = useState<string | null>(null);
  const fromValue = from ?? defaultFrom(months);
  const toChoices = months.filter((m) => m.month >= fromValue);
  const toValue = to !== null && to >= fromValue ? to : months[0]!.month;

  return (
    <form
      className={styles.range}
      onSubmit={(e) => {
        e.preventDefault();
        onShow(fromValue, toValue);
      }}
    >
      <span className={styles.rangeTitle}>Mehrere Monate</span>
      <span className={styles.field}>
        <label htmlFor={fromId} className={styles.fieldLabel}>
          Von
        </label>
        <select id={fromId} className={styles.select} value={fromValue} onChange={(e) => setFrom(e.currentTarget.value)}>
          {months.map((m) => (
            <option key={m.month} value={m.month}>
              {monthLabel(m.month)}
            </option>
          ))}
        </select>
      </span>
      <span className={styles.field}>
        <label htmlFor={toId} className={styles.fieldLabel}>
          Bis
        </label>
        <select id={toId} className={styles.select} value={toValue} onChange={(e) => setTo(e.currentTarget.value)}>
          {toChoices.map((m) => (
            <option key={m.month} value={m.month}>
              {monthLabel(m.month)}
            </option>
          ))}
        </select>
      </span>
      <Button variant="primary" type="submit" className={styles.show}>
        Anzeigen
      </Button>
    </form>
  );
}

export function MonthsPage() {
  const { detail } = useBusinessContext();
  const b = detail.business;
  const route = useDetailRoute(`/b/${b.id}/monate`);
  const navigate = useNavigate();
  const query = useMonths(b.id);
  const period = route.id === null ? null : parsePeriodId(route.id);
  const summary = usePeriodSummary(b.id, period);

  let body;
  if (query.data && query.data.months.length === 0) {
    body = (
      <EmptyState
        title="Noch keine Monatsabrechnung."
        text={`Die erste gibt es ab ${dayMonthText(query.data.nextAvailable)}.`}
      />
    );
  } else if (query.data) {
    const months = query.data.months;
    body = (
      <div className={styles.content}>
        {query.data.testMode && (
          <p className={styles.testMode}>
            <StatusChip tone="neutral">Testbetrieb</StatusChip>
          </p>
        )}
        <RangePicker
          months={months}
          onShow={(from, to) => navigate(route.detailTo(periodId({ from, to })), { state: route.fromListState })}
        />
        <RowGroup label="Monate">
          {months.map((m) => (
            <MonthRow
              key={m.month}
              month={m}
              to={route.detailTo(m.month)}
              state={route.fromListState}
              selected={period !== null && period.from === m.month && period.to === m.month}
            />
          ))}
        </RowGroup>
      </div>
    );
  } else if (query.isError) {
    body = <LoadError message={query.error.message} onRetry={() => void query.refetch()} />;
  } else {
    body = (
      <div className={styles.content}>
        <div className={styles.rangeBone} aria-hidden="true" />
        <RowListSkeleton rows={4} label="Monate werden geladen" />
      </div>
    );
  }

  const title = period ? periodTitle(period) : 'Abrechnung';

  return (
    <>
      <PageHeader title="Abschlüsse" subtitle={<BusinessName />} />
      <ClosingTabs businessId={b.id} current="monate" />
      {body}
      <Dialog
        variant="side"
        title={title}
        open={route.id !== null}
        onClose={route.close}
        returnFocus={route.rowOf}
        headerActions={period && summary.data ? <PrintButton /> : undefined}
      >
        {route.id !== null && (
          <PrintFrame title={period ? periodPrintTitle(period) : title}>
            <PeriodDetailView period={period} query={summary} />
          </PrintFrame>
        )}
      </Dialog>
    </>
  );
}
