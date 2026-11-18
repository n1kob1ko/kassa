import { useState } from 'react';
import { summaryText, useReimportMenu } from '../api/businesses';
import { Button } from '../ui/Button';
import { DataList, DataRow } from '../ui/DataList';
import { Dialog } from '../ui/Dialog';
import { FileDrop, UploadError } from '../ui/FileDrop';
import { UploadIcon } from '../ui/icons';
import { PageHeader } from '../ui/PageHeader';
import { StatusChip } from '../ui/StatusChip';
import { toast } from '../ui/Toast';
import { useDialogState } from '../ui/useDialogState';
import { count } from '../format';
import { useBusinessContext } from './BusinessLayout';
import styles from './MenuPage.module.css';

const WARNING = 'Die Datei gewinnt bei allem, was in ihr steht, auch bei Preisen. Favoriten, "Im Verkauf" und Fotos bleiben.';

function ReimportDialog({ business, open, onClose }: { business: string; open: boolean; onClose: () => void }) {
  const reimport = useReimportMenu(business);
  const [file, setFile] = useState<File>();

  const submit = async () => {
    if (!file || reimport.isPending) return;
    reimport.mutate(await file.text(), {
      onSuccess: ({ summary }) => {
        onClose();
        // Der Hinweis erst nach dem Schließen: ein später geöffneter Dialog läge sonst über ihm.
        toast.show(summaryText(summary));
      },
    });
  };

  return (
    <Dialog
      title="Speisekarte neu einspielen"
      open={open}
      onClose={onClose}
      actions={
        <>
          <Button variant="quiet" onClick={onClose}>
            Abbrechen
          </Button>
          <Button variant="primary" busy={reimport.isPending} disabled={!file} onClick={() => void submit()}>
            Neu einspielen
          </Button>
        </>
      }
    >
      <div className={styles.dialogBody}>
        <p>{WARNING}</p>
        <FileDrop
          onFile={(f) => {
            reimport.reset();
            setFile(f);
          }}
          fileName={file?.name}
          disabled={reimport.isPending}
        />
        {reimport.error && <UploadError error={reimport.error} />}
      </div>
    </Dialog>
  );
}

export function MenuPage() {
  const { detail, isProvider } = useBusinessContext();
  const { business, categories } = detail;
  const dialog = useDialogState();
  // Stillgelegte Kategorien stehen am Ende.
  const sorted = [...categories].sort((a, b) => Number(a.archived) - Number(b.archived));

  return (
    <>
      <PageHeader
        title="Speisekarte"
        subtitle={business.name}
        actions={
          isProvider ? (
            <Button variant="secondary" onClick={() => dialog.show()}>
              <UploadIcon size={18} />
              Speisekarte neu einspielen
            </Button>
          ) : undefined
        }
      />

      <p className={styles.facts}>
        <span>{count(business.counts.items, 'Artikel')}</span>
        <span>{count(business.counts.categories, 'Kategorie', 'Kategorien')}</span>
        <span>{count(business.counts.templates, 'Vorlage', 'Vorlagen')}</span>
      </p>

      <h2 className={styles.heading}>Kategorien</h2>
      <DataList label="Kategorien">
        {sorted.map((k) => (
          <DataRow
            key={k.id}
            title={k.name}
            muted={k.archived}
            chips={k.archived ? <StatusChip tone="neutral">Stillgelegt</StatusChip> : undefined}
            meta={[count(k.itemCount, 'Artikel')]}
          />
        ))}
      </DataList>

      {isProvider && <ReimportDialog key={dialog.key} business={business.id} open={dialog.open} onClose={dialog.close} />}
    </>
  );
}
