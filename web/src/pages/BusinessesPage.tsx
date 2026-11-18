import { useState } from 'react';
import { Link, useNavigate } from 'react-router';
import { useBusinesses, useCreateBusiness } from '../api/businesses';
import { Button } from '../ui/Button';
import { Dialog } from '../ui/Dialog';
import { LoadError, ListSkeleton } from '../ui/DataList';
import { EmptyState } from '../ui/EmptyState';
import { FileDrop, UploadError } from '../ui/FileDrop';
import { ChevronRightIcon, PlusIcon } from '../ui/icons';
import { PageHeader } from '../ui/PageHeader';
import { useDialogState } from '../ui/useDialogState';
import { count } from '../format';
import styles from './BusinessesPage.module.css';

/** Betrieb anlegen: die Speisekarten-Datei wird gleich nach dem Wählen geprüft und eingespielt. */
function CreateBusinessDialog({ open, onClose }: { open: boolean; onClose: () => void }) {
  const create = useCreateBusiness();
  const navigate = useNavigate();
  const [fileName, setFileName] = useState<string>();

  const upload = async (file: File) => {
    setFileName(file.name);
    create.mutate(await file.text(), {
      // Zuerst ein Chef mit PIN: ohne ihn gibt es keinen Kopplungscode.
      onSuccess: ({ business }) => void navigate(`/b/${business.id}/mitarbeiter`),
    });
  };

  return (
    <Dialog
      title="Betrieb anlegen"
      open={open}
      onClose={onClose}
      actions={
        <Button variant="quiet" onClick={onClose}>
          Abbrechen
        </Button>
      }
    >
      <div className={styles.dialogBody}>
        <p>Die Datei enthält den Namen des Betriebs, seine Adresse und die Speisekarte.</p>
        <FileDrop onFile={(f) => void upload(f)} fileName={create.isPending ? `${fileName} wird eingespielt` : fileName} disabled={create.isPending} />
        {create.error && <UploadError error={create.error} />}
      </div>
    </Dialog>
  );
}

export function BusinessesPage() {
  const query = useBusinesses();
  const dialog = useDialogState();

  const addButton = (
    <Button variant="primary" onClick={() => dialog.show()}>
      <PlusIcon size={18} />
      Betrieb anlegen
    </Button>
  );

  return (
    <>
      <PageHeader title="Betriebe" actions={query.data && query.data.length > 0 ? addButton : undefined} />

      {query.isPending && <ListSkeleton label="Betriebe werden geladen" />}
      {query.isError && <LoadError message={query.error.message} onRetry={() => void query.refetch()} />}
      {query.data?.length === 0 && (
        <EmptyState
          title="Noch kein Betrieb"
          text="Lege den ersten Betrieb mit seiner Speisekarten-Datei an. Danach koppelst du die Kassen und legst die Mitarbeiter an."
          action={addButton}
        />
      )}
      {query.data && query.data.length > 0 && (
        <ul className={styles.grid} aria-label="Betriebe">
          {query.data.map((b) => (
            <li key={b.id}>
              <Link to={`/b/${b.id}/kassen`} className={styles.card}>
                <span className={styles.name}>{b.name}</span>
                <span className={styles.counts}>
                  <span>{count(b.counts.items, 'Artikel')}</span>
                  <span>{count(b.counts.registers, 'Kassa', 'Kassen')}</span>
                </span>
                <ChevronRightIcon size={20} className={styles.chevron} />
              </Link>
            </li>
          ))}
        </ul>
      )}

      <CreateBusinessDialog key={dialog.key} open={dialog.open} onClose={dialog.close} />
    </>
  );
}
