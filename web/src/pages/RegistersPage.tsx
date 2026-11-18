import { useState, type FormEvent } from 'react';
import { useCreatePairingCode, useRegisters, useSetBlocked, type PairingCode, type Register } from '../api/registers';
import { ApiError } from '../api/client';
import { ago } from '../format';
import { Button } from '../ui/Button';
import { CodeDisplay, useRemaining } from '../ui/CodeDisplay';
import { ConfirmDialog } from '../ui/ConfirmDialog';
import { DataList, DataRow, ListSkeleton, LoadError } from '../ui/DataList';
import { Dialog } from '../ui/Dialog';
import { EmptyState } from '../ui/EmptyState';
import { PlusIcon } from '../ui/icons';
import { PageHeader } from '../ui/PageHeader';
import { StatusChip } from '../ui/StatusChip';
import { TextField } from '../ui/TextField';
import { toast } from '../ui/Toast';
import { useDialogState } from '../ui/useDialogState';
import { FormAlert } from './AuthLayout';
import { useBusinessContext } from './BusinessLayout';
import styles from './RegistersPage.module.css';

/** Wie oft die Liste bei offenem Kopplungsdialog neu geladen wird. */
const POLL_MS = 3000;
const FORM_ID = 'kopplung-formular';

type Issued = PairingCode & { expires: Date; knownIds: string[] };

/**
 * Kassa koppeln: erst der Name, dann der Code. Solange der Dialog offen ist, lädt die Seite die Liste neu;
 * sobald eine Kassa dazukommt, die es beim Erzeugen des Codes noch nicht gab, steht hier "Verbunden".
 */
function PairDialog({
  business,
  registers,
  open,
  onClose,
}: {
  business: string;
  registers: Register[];
  open: boolean;
  onClose: () => void;
}) {
  const create = useCreatePairingCode(business);
  const [name, setName] = useState(`Kassa ${registers.length + 1}`);
  const [problem, setProblem] = useState<{ field?: string; form?: string }>({});
  const [issued, setIssued] = useState<Issued | null>(null);
  const remaining = useRemaining(issued?.expires ?? null);

  const connected = issued ? registers.find((r) => !issued.knownIds.includes(r.id)) : undefined;
  const expired = issued !== null && remaining <= 0;

  const issue = (e?: FormEvent) => {
    e?.preventDefault();
    if (create.isPending) return;
    const trimmed = name.trim();
    if (trimmed.length < 1 || trimmed.length > 30) {
      setProblem({ field: 'Der Name muss 1 bis 30 Zeichen lang sein.' });
      document.getElementById('kassa-name')?.focus();
      return;
    }
    setProblem({});
    const knownIds = registers.map((r) => r.id);
    create.mutate(trimmed, {
      onSuccess: (code) => setIssued({ ...code, expires: new Date(code.expiresAt), knownIds }),
      onError: (err: ApiError) => setProblem(err.code === 'name_invalid' ? { field: err.message } : { form: err.message }),
    });
  };

  let title = 'Kassa koppeln';
  let body;
  let actions;
  if (connected) {
    title = 'Kassa gekoppelt';
    body = (
      <div className={styles.connected}>
        <p className={styles.connectedName}>{connected.name}</p>
        <StatusChip tone="ok">Verbunden</StatusChip>
        <p className={styles.help}>Das Tablet ist jetzt mit dem Betrieb verbunden und gleicht ab.</p>
      </div>
    );
    actions = (
      <Button variant="primary" onClick={onClose}>
        Fertig
      </Button>
    );
  } else if (issued) {
    body = (
      <div className={styles.code}>
        <CodeDisplay code={issued.code} remainingMs={remaining} />
        {expired ? (
          <p className={styles.help}>Erzeuge einen neuen Code und gib ihn am Tablet ein.</p>
        ) : (
          <p className={styles.help}>Am Tablet: Mit Code koppeln</p>
        )}
        {problem.form && <FormAlert>{problem.form}</FormAlert>}
      </div>
    );
    actions = (
      <>
        <Button variant="quiet" onClick={onClose}>
          Schließen
        </Button>
        {expired && (
          <Button variant="primary" busy={create.isPending} onClick={() => issue()}>
            Neuen Code erzeugen
          </Button>
        )}
      </>
    );
  } else {
    body = (
      <form id={FORM_ID} className={styles.form} onSubmit={issue} noValidate>
        <TextField
          id="kassa-name"
          label="Name"
          name="name"
          autoComplete="off"
          maxLength={30}
          value={name}
          onChange={(e) => setName(e.target.value)}
          hint="So heißt die Kassa in dieser Liste, zum Beispiel Theke oder Gastgarten."
          error={problem.field}
        />
        {problem.form && <FormAlert>{problem.form}</FormAlert>}
      </form>
    );
    actions = (
      <>
        <Button variant="quiet" onClick={onClose}>
          Abbrechen
        </Button>
        <Button type="submit" form={FORM_ID} variant="primary" busy={create.isPending}>
          Code erzeugen
        </Button>
      </>
    );
  }

  return (
    <Dialog title={title} open={open} onClose={onClose} actions={actions}>
      {body}
    </Dialog>
  );
}

function lastSeen(r: Register, now: Date): string {
  return r.lastSeenAt ? `zuletzt gesehen ${ago(new Date(r.lastSeenAt), now)}` : 'zuletzt gesehen: noch nie';
}

export function RegistersPage() {
  const { detail } = useBusinessContext();
  const b = detail.business;
  const pair = useDialogState();
  const confirm = useDialogState<Register>();
  const query = useRegisters(b.id, pair.open ? POLL_MS : undefined);
  const setBlocked = useSetBlocked(b.id);

  const block = (r: Register, blocked: boolean) =>
    setBlocked.mutate({ id: r.id, blocked }, { onError: (err) => toast.show(err.message) });

  const list = query.data;
  const now = new Date();
  const addButton = (
    <Button variant="primary" onClick={() => pair.show()}>
      <PlusIcon size={18} />
      Kassa koppeln
    </Button>
  );

  return (
    <>
      <PageHeader title="Kassen" subtitle={b.name} actions={list && list.length > 0 ? addButton : undefined} />

      {query.isPending && <ListSkeleton label="Kassen werden geladen" />}
      {query.isError && !list && <LoadError message={query.error.message} onRetry={() => void query.refetch()} />}
      {list?.length === 0 && (
        <EmptyState
          title="Noch keine Kassa gekoppelt."
          text="Koppel das erste Tablet: Du bekommst einen Code, den du in der Kassa-App eingibst."
          action={addButton}
        />
      )}
      {list && list.length > 0 && (
        <DataList label="Kassen">
          {list.map((r) => (
            <DataRow
              key={r.id}
              title={r.name}
              chips={r.blocked ? <StatusChip tone="off">Gesperrt</StatusChip> : <StatusChip tone="ok">Verbunden</StatusChip>}
              meta={[lastSeen(r, now), r.appVersion ? `Version ${r.appVersion}` : 'Version unbekannt']}
              actions={
                r.blocked ? (
                  <Button variant="secondary" aria-label={`Sperre aufheben: ${r.name}`} onClick={() => block(r, false)}>
                    Sperre aufheben
                  </Button>
                ) : (
                  <Button variant="danger" aria-label={`Sperren: ${r.name}`} onClick={() => confirm.show(r)}>
                    Sperren
                  </Button>
                )
              }
            />
          ))}
        </DataList>
      )}

      <PairDialog key={pair.key} business={b.id} registers={list ?? []} open={pair.open} onClose={pair.close} />
      <ConfirmDialog
        key={confirm.key}
        open={confirm.open}
        title={confirm.value ? `${confirm.value.name} sperren?` : 'Kassa sperren?'}
        text="Diese Kassa gleicht dann nicht mehr ab. Bonieren geht am Tablet weiter."
        confirmLabel="Sperren"
        danger
        onClose={confirm.close}
        onConfirm={() => {
          const r = confirm.value;
          confirm.close();
          if (r) block(r, true);
        }}
      />
    </>
  );
}

