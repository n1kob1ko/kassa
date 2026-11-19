import { useState } from 'react';
import { kindLabel, useReports, type Report } from '../api/reports';
import { dayHeading, timeText } from '../format';
import { LoadError } from '../ui/DataList';
import { EmptyState } from '../ui/EmptyState';
import { LoadMore } from '../ui/LoadMore';
import { PageHeader } from '../ui/PageHeader';
import { RowDisclosure, RowGroup, RowListSkeleton } from '../ui/RowList';
import { StatusChip } from '../ui/StatusChip';
import { BackupCard } from './BackupCard';
import { ReportContent } from './ReportContent';
import styles from './ReportsPage.module.css';

/** Eine Zeile: Tag und Uhrzeit, Betrieb und Kassa, Art, App-Version und, wenn öfter gesehen, der Zähler. */
function Summary({ report, now }: { report: Report; now: Date }) {
  const at = new Date(report.at);
  return (
    <>
      {/* Zwei Zeilen am Handy, ab 640 px lösen sich beide auf (display: contents) in die Spalten einer Tabelle.
          Leerzeichen zwischen den Teilen: der Name liest sich "Heute, 08:11 Fehler 3 Mal Imbiss · Theke Version 1.5.0". */}
      <span className={styles.head}>
        <span className={styles.time} data-part="time">
          {dayHeading(at, now)}, {timeText(at)}
        </span>{' '}
        <span className={styles.kind} data-part="kind">
          <StatusChip tone="neutral">{kindLabel(report)}</StatusChip>
        </span>{' '}
        {report.count > 1 && (
          <span className={styles.count} data-part="count">
            <span aria-hidden="true">×{report.count}</span>
            <span className="visually-hidden">{report.count} Mal</span>
          </span>
        )}
      </span>{' '}
      <span className={styles.sub}>
        <span className={styles.where} data-part="where">
          {report.businessName} · {report.registerName ?? 'ohne Kassa'}
        </span>{' '}
        {report.appVersion && (
          <span className={styles.version} data-part="version">
            <span className="visually-hidden">Version </span>
            {report.appVersion}
          </span>
        )}
      </span>
    </>
  );
}

/**
 * Fehlerberichte (nur Anbieter): oben der Stand der Sicherung, darunter die Berichte aller Betriebe, die neuesten
 * zuerst, so wie der Server sie liefert. Eine Zeile klappt ihren Inhalt an Ort und Stelle auf, mehrere zugleich.
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
        {/* In der Reihenfolge des Servers (nach Eingang): ein spät gesendeter Bericht steht, wo er ankam, darum keine
            Überschriften nach Tagen; jede Zeile nennt ihren Tag selbst. */}
        <RowGroup label="Berichte">
          {reports.map((r) => (
            <RowDisclosure
              key={r.id}
              open={open.has(r.id)}
              onToggle={() => toggle(r.id)}
              className={styles.row}
              summary={<Summary report={r} now={now} />}
            >
              <ReportContent report={r} />
            </RowDisclosure>
          ))}
        </RowGroup>
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
    body = <RowListSkeleton rows={8} label="Berichte werden geladen" />;
  }

  return (
    <>
      <PageHeader title="Fehlerberichte" subtitle="Von allen Betrieben, die neuesten zuerst." />
      <BackupCard />
      {body}
    </>
  );
}
