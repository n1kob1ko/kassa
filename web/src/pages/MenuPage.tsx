import { useId, useState, type ReactNode } from 'react';
import { summaryText, useReimportMenu } from '../api/businesses';
import { fileUrl, type UploadOptions } from '../api/files';
import { useItems, usePatchItem, useRemovePhoto, useSetPhoto, type ItemCategory, type ItemChange, type MenuItem } from '../api/items';
import { Button } from '../ui/Button';
import { LoadError } from '../ui/DataList';
import { Dialog } from '../ui/Dialog';
import { EmptyState } from '../ui/EmptyState';
import { FileDrop, UploadError } from '../ui/FileDrop';
import { UploadIcon } from '../ui/icons';
import { PageHeader } from '../ui/PageHeader';
import { Bone } from '../ui/Skeleton';
import { StatusChip } from '../ui/StatusChip';
import { toast } from '../ui/Toast';
import { useDialogState } from '../ui/useDialogState';
import { count } from '../format';
import { BusinessName, useBusinessContext } from './BusinessLayout';
import { ArchivedItemRow, MenuItemRow } from './MenuItemRow';
import { imageErrorText, PhotoDialog } from './PhotoDialog';
import { useSyncHint, useUploadMemory } from './useSyncHint';
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

/** Aktive Kategorien zuerst, stillgelegte am Ende; in einer Kategorie stehen stillgelegte Artikel ganz unten. */
function menuOrder(categories: ItemCategory[]): ItemCategory[] {
  const byArchived = <T extends { archived: boolean }>(list: T[]) => [...list.filter((x) => !x.archived), ...list.filter((x) => x.archived)];
  return byArchived(categories).map((c) => ({ ...c, items: byArchived(c.items) }));
}

function CategoryGroup({ category, children }: { category: ItemCategory; children: ReactNode }) {
  const headingId = useId();
  const active = category.items.filter((i) => !i.archived).length;
  return (
    <section className={[styles.group, category.archived ? styles.archivedGroup : ''].filter(Boolean).join(' ')} aria-labelledby={headingId}>
      <div className={styles.groupHead}>
        <div className={styles.title}>
          <h2 id={headingId} className={styles.heading}>
            <span>{category.name}</span>
            {category.archived && <StatusChip tone="neutral">Stillgelegt</StatusChip>}
          </h2>
          {!category.archived && <span className={styles.count}>{count(active, 'Artikel')}</span>}
        </div>
        {!category.archived && (
          <>
            {/* Spaltenköpfe ab 640 px; die Felder tragen ihren Namen selbst, darum nur zum Sehen. */}
            <span className={styles.columnPrice} aria-hidden="true">
              Preis
            </span>
            <span className={styles.columnSale} aria-hidden="true">
              Im Verkauf
            </span>
            <span className={styles.columnStar} aria-hidden="true">
              Favorit
            </span>
          </>
        )}
      </div>
      <ul className={styles.card} aria-label={category.name}>
        {children}
      </ul>
    </section>
  );
}

/** Platzhalter in der Form der Speisekarte: Kategorie, Zeilen mit Foto, Name, Preis, Schalter und Stern. */
function MenuSkeleton() {
  return (
    <div className={styles.skeleton} role="status" aria-busy="true">
      <span className="visually-hidden">Speisekarte wird geladen</span>
      {[3, 2].map((rows, g) => (
        <div key={g} className={styles.group} aria-hidden="true">
          <div className={styles.groupHead}>
            <Bone className={styles.boneHeading} />
          </div>
          <div className={styles.card}>
            {Array.from({ length: rows }, (_, i) => (
              <div key={i} className={styles.row}>
                <Bone className={[styles.photo, styles.bonePhoto].join(' ')} />
                <Bone className={[styles.name, styles.boneName].join(' ')} />
                <Bone className={[styles.price, styles.bonePrice].join(' ')} />
                <span className={styles.sale}>
                  <Bone className={styles.boneSwitch} />
                </span>
                <span className={styles.star}>
                  <Bone className={styles.boneStar} />
                </span>
              </div>
            ))}
          </div>
        </div>
      ))}
    </div>
  );
}

export function MenuPage() {
  const { detail, isProvider } = useBusinessContext();
  const { business } = detail;
  const b = business.id;
  const items = useItems(b);
  const patch = usePatchItem(b);
  const setPhoto = useSetPhoto(b);
  const removePhoto = useRemovePhoto(b);
  const hint = useSyncHint();
  const memory = useUploadMemory();
  const reimportDialog = useDialogState();
  const photoDialog = useDialogState<string>();

  const change = (item: MenuItem, c: ItemChange) => patch.mutate({ id: item.id, change: c }, { onSuccess: hint });

  const upload = async (itemId: string, file: File, options: UploadOptions) => {
    const saved = await setPhoto.mutateAsync({ itemId, file, ...options });
    memory.remember(itemId, saved.id, file);
    return saved;
  };

  /** Sofort weg, "Rückgängig" lädt dieselbe Datei aus diesem Besuch noch einmal hoch. */
  const removeWithUndo = (item: MenuItem, file: File) => {
    const removal = removePhoto.mutateAsync(item.id);
    removal.catch((err: Error) => toast.show(err.message));
    toast.show('Foto entfernt.', {
      undo: () => {
        void (async () => {
          try {
            await removal;
          } catch {
            return;
          }
          try {
            await upload(item.id, file, {});
          } catch (err) {
            toast.show(imageErrorText(err));
          }
        })();
      },
    });
  };

  const all = items.data?.categories.flatMap((c) => c.items) ?? [];
  const photoItem = all.find((i) => i.id === photoDialog.value);
  const photoFile = photoItem ? memory.fileOf(photoItem.id, photoItem.photo?.id) : undefined;

  let content: ReactNode;
  if (items.isPending) {
    content = <MenuSkeleton />;
  } else if (items.isError) {
    content = <LoadError message={items.error.message} onRetry={() => void items.refetch()} />;
  } else if (items.data.categories.length === 0) {
    content = (
      <EmptyState
        title="Noch keine Artikel."
        text={isProvider ? 'Spiel die Speisekarte ein, dann stehen die Artikel hier.' : 'Sobald dein Anbieter die Speisekarte einspielt, stehen die Artikel hier.'}
      />
    );
  } else {
    content = (
      <div className={styles.groups}>
        {menuOrder(items.data.categories).map((category) => (
          <CategoryGroup key={category.id} category={category}>
            {category.items.map((item) =>
              category.archived || item.archived ? (
                <ArchivedItemRow key={item.id} business={b} item={item} chip={!category.archived} />
              ) : (
                <MenuItemRow key={item.id} business={b} item={item} onChange={(c) => change(item, c)} onPhoto={() => photoDialog.show(item.id)} />
              ),
            )}
          </CategoryGroup>
        ))}
      </div>
    );
  }

  return (
    <>
      <PageHeader
        title="Speisekarte"
        subtitle={<BusinessName />}
        actions={
          isProvider ? (
            <Button variant="secondary" onClick={() => reimportDialog.show()}>
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

      {content}

      {photoItem && (
        <PhotoDialog
          key={photoDialog.key}
          open={photoDialog.open}
          onClose={photoDialog.close}
          title={`Foto für ${photoItem.name}`}
          noun="Foto"
          current={photoItem.photo}
          src={(id) => fileUrl(b, id)}
          onSave={async (file, options) => {
            await upload(photoItem.id, file, options);
            hint();
          }}
          undoable={photoFile !== undefined}
          onRemove={async () => {
            if (photoFile) {
              removeWithUndo(photoItem, photoFile);
              return;
            }
            await removePhoto.mutateAsync(photoItem.id);
            toast.show('Foto entfernt.');
          }}
        />
      )}

      {isProvider && <ReimportDialog key={reimportDialog.key} business={b} open={reimportDialog.open} onClose={reimportDialog.close} />}
    </>
  );
}
