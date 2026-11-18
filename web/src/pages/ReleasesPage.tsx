import { useReleases, useWithdrawRelease, type Release } from '../api/releases';
import { dateText, megabytes } from '../format';
import { Button } from '../ui/Button';
import { ConfirmDialog } from '../ui/ConfirmDialog';
import { DataList, DataRow, ListSkeleton, LoadError } from '../ui/DataList';
import { EmptyState } from '../ui/EmptyState';
import { PageHeader } from '../ui/PageHeader';
import { StatusChip } from '../ui/StatusChip';
import { toast } from '../ui/Toast';
import { useDialogState } from '../ui/useDialogState';
import styles from './ReleasesPage.module.css';

async function copyLink(release: Release): Promise<void> {
  if (!release.downloadPath) return;
  const url = `${window.location.origin}${release.downloadPath}`;
  try {
    await navigator.clipboard.writeText(url);
    toast.show('Link kopiert.');
  } catch {
    // Ohne Zugriff auf die Zwischenablage: der Link steht im Hinweis zum Markieren.
    toast.show(`Kopieren geht hier nicht. Der Link: ${url}`);
  }
}

export function ReleasesPage() {
  const query = useReleases();
  const withdraw = useWithdrawRelease();
  const confirm = useDialogState<Release>();
  const list = query.data;

  return (
    <>
      <PageHeader title="Installationsdateien" subtitle="Die Kassa-App für die Tablets, jede Version mit eigenem Link." />

      {query.isPending && <ListSkeleton label="Installationsdateien werden geladen" />}
      {query.isError && !list && <LoadError message={query.error.message} onRetry={() => void query.refetch()} />}
      {list?.length === 0 && (
        <EmptyState
          title="Noch keine Installationsdatei."
          text="Lade eine Version mit dem Freigabe-Schlüssel hoch, dann steht sie hier mit ihrem Link."
        />
      )}
      {list && list.length > 0 && (
        <DataList label="Installationsdateien">
          {list.map((r) => (
            <DataRow
              key={r.id}
              title={`Version ${r.version}`}
              muted={r.withdrawn}
              chips={r.withdrawn ? <StatusChip tone="off">Zurückgezogen</StatusChip> : undefined}
              meta={[
                `Build ${r.build}`,
                dateText(new Date(r.uploadedAt)),
                megabytes(r.size),
                <span key="sum" className={styles.sum}>
                  Prüfsumme {r.sha256.slice(0, 12)}
                </span>,
              ]}
              actions={
                r.withdrawn ? undefined : (
                  <>
                    <Button variant="secondary" aria-label={`Link kopieren: Version ${r.version}`} onClick={() => void copyLink(r)}>
                      Link kopieren
                    </Button>
                    <Button variant="danger" aria-label={`Zurückziehen: Version ${r.version}`} onClick={() => confirm.show(r)}>
                      Zurückziehen
                    </Button>
                  </>
                )
              }
            />
          ))}
        </DataList>
      )}

      <ConfirmDialog
        key={confirm.key}
        open={confirm.open}
        title={confirm.value ? `Version ${confirm.value.version} zurückziehen?` : 'Zurückziehen?'}
        text="Der Link gilt dann nicht mehr, und die Datei wird gelöscht. Das lässt sich nicht rückgängig machen."
        confirmLabel="Zurückziehen"
        danger
        onClose={confirm.close}
        onConfirm={() => {
          const r = confirm.value;
          confirm.close();
          if (r) {
            withdraw.mutate(r.id, { onError: (err) => toast.show(err.message) });
          }
        }}
      />
    </>
  );
}
