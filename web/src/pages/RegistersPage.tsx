import { useState, type FormEvent } from 'react';
import { useQueryClient } from '@tanstack/react-query';
import { depUrl, useCreatePairingCode, useRegisters, useSetBlocked, type PairingCode, type Register } from '../api/registers';
import { staffKey, useStaff } from '../api/staff';
import { ApiError } from '../api/client';
import { ago, count } from '../format';
import { Button, ButtonLink, DownloadLink } from '../ui/Button';
import { CodeDisplay, useRemaining } from '../ui/CodeDisplay';
import { ConfirmDialog } from '../ui/ConfirmDialog';
import { DataList, DataRow, ListSkeleton, LoadError } from '../ui/DataList';
import { Dialog } from '../ui/Dialog';
import { EmptyState } from '../ui/EmptyState';
import { DownloadIcon, PlusIcon } from '../ui/icons';
import { PageHeader } from '../ui/PageHeader';
import { StatusChip } from '../ui/StatusChip';
import { TextField } from '../ui/TextField';
import { toast } from '../ui/Toast';
import { useDialogState } from '../ui/useDialogState';
import { FormAlert } from './AuthLayout';
import { BusinessName, useBusinessContext } from './BusinessLayout';
import styles from './RegistersPage.module.css';

/** Wie oft die Liste bei offenem Kopplungsdialog neu geladen wird. */
const POLL_MS = 3000;
const FORM_ID = 'kopplung-formular';
/** Ohne Chef gibt der Server keinen Code (409 no_chef): am Tablet könnte sich sonst niemand anmelden. */
const NO_CHEF = 'Lege zuerst einen Chef mit PIN an.';

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
  const queryClient = useQueryClient();
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
      onError: (err: ApiError) => {
        if (err.code === 'name_invalid') return setProblem({ field: err.message });
        if (err.code === 'no_chef') {
          // Die Seite hielt die Liste der Mitarbeiter für aktuell: neu laden, dann zeigt sie den Hinweis.
          void queryClient.invalidateQueries({ queryKey: staffKey(business) });
          return setProblem({ form: NO_CHEF });
        }
        setProblem({ form: err.message });
      },
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
          <div className={styles.where}>
            <p className={styles.help}>Neues Tablet: Mit Code koppeln</p>
            <p className={styles.help}>Tablet mit Speisekarte: Einstellungen, Server, Mit Server verbinden</p>
          </div>
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

function lastReceipt(r: Register, now: Date): string {
  return r.lastReceiptAt ? `Letzter Bon ${ago(new Date(r.lastReceiptAt), now)}` : 'Noch kein Bon';
}

/**
 * Die Ketten der Signatur dieser Kassa, die neueste zuerst, je mit dem Protokoll als Datei. Ohne Kette steht
 * hier nichts, auch keine Überschrift.
 */
function Chains({ business, register }: { business: string; register: Register }) {
  if (register.chains.length === 0) return null;
  const chains = [...register.chains].sort((a, b) => b.chain - a.chain);
  return (
    <section className={styles.chains} aria-labelledby={`ketten-${register.id}`}>
      <h3 id={`ketten-${register.id}`} className={styles.chainsTitle}>
        Protokoll der Signatur
      </h3>
      <ul className={styles.chainList} aria-label={`Ketten der Signatur: ${register.name}`}>
        {chains.map((c) => (
          <li key={c.chain} className={styles.chain}>
            <div className={styles.chainText}>
              <span className={styles.chainName}>
                Kassen-ID {c.cashBoxId} · {count(c.entries, 'Eintrag', 'Einträge')}
              </span>
              {(c.mode === 'probe' || c.endedAt) && (
                <span className={styles.chainMarks}>
                  {c.mode === 'probe' && <StatusChip tone="neutral">Probe</StatusChip>}
                  {c.endedAt && <StatusChip tone="neutral">Beendet</StatusChip>}
                </span>
              )}
            </div>
            <DownloadLink
              variant="secondary"
              className={styles.chainDownload}
              href={depUrl(business, register.id, c.chain)}
              aria-label={`Protokoll herunterladen, Kassen-ID ${c.cashBoxId}, Kette ${c.chain}`}
            >
              <DownloadIcon size={18} />
              Protokoll herunterladen
            </DownloadLink>
          </li>
        ))}
      </ul>
    </section>
  );
}

export function RegistersPage() {
  const { detail } = useBusinessContext();
  const b = detail.business;
  const pair = useDialogState();
  const confirm = useDialogState<Register>();
  const query = useRegisters(b.id, pair.open ? POLL_MS : undefined);
  const staff = useStaff(b.id);
  // Solange die Liste lädt, weder Knopf noch Hinweis. Kann sie nicht laden, entscheidet der Server (no_chef).
  const hasChef = staff.data ? staff.data.some((s) => s.role === 'chef' && !s.archived) : staff.isError ? true : undefined;
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

  const toStaff = (variant: 'primary' | 'secondary') => (
    <ButtonLink variant={variant} to={`/b/${b.id}/mitarbeiter`}>
      Zu den Mitarbeitern
    </ButtonLink>
  );
  const headerAction =
    hasChef === undefined ? undefined : hasChef ? (
      addButton
    ) : (
      <div className={styles.noChef}>
        <p className={styles.noChefText}>{NO_CHEF}</p>
        {toStaff('secondary')}
      </div>
    );

  return (
    <>
      <PageHeader title="Kassen" subtitle={<BusinessName />} actions={list && list.length > 0 ? headerAction : undefined} />

      {query.isPending && <ListSkeleton label="Kassen werden geladen" />}
      {query.isError && !list && <LoadError message={query.error.message} onRetry={() => void query.refetch()} />}
      {list?.length === 0 && (
        <EmptyState
          title="Noch keine Kassa gekoppelt."
          text={hasChef === false ? NO_CHEF : 'Kopple das erste Tablet: Du bekommst einen Code, den du in der Kassa-App eingibst.'}
          action={hasChef === undefined ? undefined : hasChef ? addButton : toStaff('primary')}
        />
      )}
      {list && list.length > 0 && (
        <DataList label="Kassen">
          {list.map((r) => (
            <DataRow
              key={r.id}
              title={r.name}
              chips={r.blocked ? <StatusChip tone="off">Gesperrt</StatusChip> : <StatusChip tone="ok">Verbunden</StatusChip>}
              meta={[lastSeen(r, now), lastReceipt(r, now), r.appVersion ? `Version ${r.appVersion}` : 'Version unbekannt']}
              extra={r.chains.length > 0 ? <Chains business={b.id} register={r} /> : undefined}
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

