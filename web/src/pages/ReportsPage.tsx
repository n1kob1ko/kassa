import { useState } from 'react';
import { kindLabel, useReports, type Report } from '../api/reports';
import { byDay, dayHeading, timeText } from '../format';
import { LoadError } from '../ui/DataList';
import { EmptyState } from '../ui/EmptyState';
import { LoadMore } from '../ui/LoadMore';
import { PageHeader } from '../ui/PageHeader';
import { RowDisclosure, RowGroup, RowListSkeleton } from '../ui/RowList';
import { StatusChip } from '../ui/StatusChip';
import { BackupCard } from './BackupCard';
import { ReportContent } from './ReportContent';
import styles from './ReportsPage.module.css';

/** Eine Zeile: Uhrzeit, Betrieb und Kassa, Art, App-Version und, wenn öfter gesehen, der Zähler. */
function Summary({ report }: { report: Report }) {
  return (
    <>
      {/* Leerzeichen zwischen den Teilen: der Name des Knopfs liest sich "08:11 Imbiss · Theke Fehler Version 1.5.0 3 Mal". */}
      <span className={styles.time}>{timeText(new Date(report.at))}</span>{' '}
      <span className={styles.where}>
        {report.businessName} · {report.registerName ?? 'ohne Kassa'}
      </span>{' '}
      <span className={styles.kind}>
        <StatusChip tone="neutral">{kindLabel(report)}</StatusChip>
      </span>{' '}
      {report.appVersion && (
        <span className={styles.version}>
          <span className="visually-hidden">Version </span>
          {report.appVersion}
        </span>
      )}{' '}
      {report.count > 1 && (
        <span className={styles.count}>
          <span aria-hidden="true">×{report.count}</span>
          <span className="visually-hidden">{report.count} Mal</span>
        </span>
      )}
    </>
  );
}

/**
 * Fehlerberichte (nur Anbieter): oben der Stand der Sicherung, darunter die Berichte aller Betriebe, die neuesten
 * zuerst, nach Tagen gruppiert. Eine Zeile klappt ihren Inhalt an Ort und Stelle auf, mehrere zugleich.
 */
export function ReportsPage() {
  const query = useReports();
  const [open, setOpen] = useState<ReadonlySet<string>>(() => new Set());
  const toggle = (id: string) =>
    setOpen((current) => {
      const next = new Set(current);
      if (next.has(id)) next.delete(id);
      else next.add(id);
      return next;
    });

  const reports = query.data?.pages.flatMap((p) => p.reports) ?? [];
  const now = new Date();

  let body;
  if (query.data && reports.length === 0) {
    body = (
      <EmptyState
        title="Keine Berichte. Das ist gut."
        text="Hier erscheinen Fehler und Geräte-Tests der Tablets und was dem Server beim Abgleich auffällt."
      />
    );
  } else if (query.data) {
    body = (
      <div className={styles.list}>
        {/* Die Liste kommt nach Eingang beim Server; ein spät gesendeter Bericht kann einen Tag ein zweites Mal öffnen. */}
        {byDay(reports, (r) => new Date(r.at)).map((g, i) => (
          <RowGroup key={`${i}-${g.key}`} label={`Berichte ${dayHeading(g.first, now)}`} heading={dayHeading(g.first, now)}>
            {g.items.map((r) => (
              <RowDisclosure
                key={r.id}
                open={open.has(r.id)}
                onToggle={() => toggle(r.id)}
                className={styles.row}
                summary={<Summary report={r} />}
              >
                <ReportContent report={r} />
              </RowDisclosure>
            ))}
          </RowGroup>
        ))}
        {(query.hasNextPage || query.isFetchNextPageError) && (
          <LoadMore
            busy={query.isFetchingNextPage}
            failed={query.isFetchNextPageError}
            failedText="Weitere Berichte konnten nicht geladen werden."
            onLoad={() => void query.fetchNextPage()}
          />
        )}
      </div>
    );
  } else if (query.isError) {
    body = <LoadError message={query.error.message} onRetry={() => void query.refetch()} />;
  } else {
    body = <RowListSkeleton rows={8} label="Berichte werden geladen" headings />;
  }

  return (
    <>
      <PageHeader title="Fehlerberichte" subtitle="Von allen Betrieben, die neuesten zuerst." />
      <BackupCard />
      {body}
    </>
  );
}
