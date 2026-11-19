import type { To } from 'react-router';
import { useDay, useDays, type DayHead } from '../api/days';
import { dateText, dayHeading, money, timeText } from '../format';
import { LoadError } from '../ui/DataList';
import { Dialog } from '../ui/Dialog';
import { EmptyState } from '../ui/EmptyState';
import { PageHeader } from '../ui/PageHeader';
import { RowGroup, RowLink, RowListSkeleton } from '../ui/RowList';
import { StatusChip } from '../ui/StatusChip';
import { BusinessName, useBusinessContext } from './BusinessLayout';
import { DayDetailView, Difference } from './DayDetail';
import { useDetailRoute } from './useDetailRoute';
import styles from './DaysPage.module.css';

function DayRow({ day, to, state, selected, now }: { day: DayHead; to: To; state: unknown; selected: boolean; now: Date }) {
  const opened = new Date(day.openedAt);
  return (
    <RowLink rowId={day.id} to={to} state={state} selected={selected} className={styles.row}>
      <span className={styles.main}>
        <span className={styles.title}>
          <span className={styles.date}>{dayHeading(opened, now)}</span>{' '}
          {day.closedAt === null && <StatusChip tone="neutral">offen</StatusChip>}
        </span>{' '}
        <span className={styles.meta}>
          {[
            day.registerName,
            day.closedAt === null ? `seit ${timeText(opened)}` : `Abschluss ${timeText(new Date(day.closedAt))}`,
          ]
            .filter(Boolean)
            .join(' · ')}
        </span>
      </span>{' '}
      <span className={styles.figures}>
        <span className={styles.revenue}>
          <span className="visually-hidden">Umsatz </span>
          {money(day.revenueCents)}
        </span>{' '}
        {day.differenceCents !== null && <Difference cents={day.differenceCents} />}
      </span>
    </RowLink>
  );
}

export function DaysPage() {
  const { detail } = useBusinessContext();
  const b = detail.business;
  const route = useDetailRoute(`/b/${b.id}/tage`);
  const query = useDays(b.id);
  const opened = useDay(b.id, route.id);
  const now = new Date();

  let body;
  if (query.data && query.data.length === 0) {
    body = (
      <EmptyState
        title="Noch kein Tag."
        text="Sobald an der Kassa ein Tag geöffnet wird, erscheint er hier mit seinem Abschluss."
      />
    );
  } else if (query.data) {
    body = (
      <RowGroup label="Tage">
        {query.data.map((d) => (
          <DayRow
            key={d.id}
            day={d}
            to={route.detailTo(d.id)}
            state={route.fromListState}
            selected={route.id === d.id}
            now={now}
          />
        ))}
      </RowGroup>
    );
  } else if (query.isError) {
    body = <LoadError message={query.error.message} onRetry={() => void query.refetch()} />;
  } else {
    body = <RowListSkeleton rows={6} label="Tage werden geladen" />;
  }

  const head = opened.data ?? query.data?.find((d) => d.id === route.id);
  const title = head ? `${dateText(new Date(head.openedAt))}${head.registerName ? `, ${head.registerName}` : ''}` : 'Tag';

  return (
    <>
      <PageHeader title="Tagesabschlüsse" subtitle={<BusinessName />} />
      {body}
      <Dialog variant="side" title={title} open={route.id !== null} onClose={route.close} returnFocus={route.rowOf}>
        {route.id && <DayDetailView query={opened} />}
      </Dialog>
    </>
  );
}
