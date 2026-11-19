import { useState, type FormEvent } from 'react';
import { useSetArchived, useStaff, useCreateStaff, useUpdateStaff, type Role, type StaffMember } from '../api/staff';
import { Button } from '../ui/Button';
import { DataList, DataRow, ListSkeleton, LoadError } from '../ui/DataList';
import { Dialog } from '../ui/Dialog';
import { EmptyState } from '../ui/EmptyState';
import { PlusIcon } from '../ui/icons';
import { PageHeader } from '../ui/PageHeader';
import { StatusChip } from '../ui/StatusChip';
import { TextField } from '../ui/TextField';
import { toast } from '../ui/Toast';
import { useDialogState } from '../ui/useDialogState';
import { ApiError } from '../api/client';
import { FormAlert } from './AuthLayout';
import { BusinessName, useBusinessContext } from './BusinessLayout';
import styles from './StaffPage.module.css';

const ROLE_LABEL: Record<Role, string> = { chef: 'Chef', staff: 'Mitarbeiter' };
const FORM_ID = 'mitarbeiter-formular';

type Problems = { name?: string; role?: string; pin?: string; form?: string };

/** Ordnet einen Fehler des Servers dem Feld zu, zu dem er gehört. */
function problemsFrom(err: ApiError): Problems {
  switch (err.code) {
    case 'name_invalid':
      return { name: err.message };
    case 'pin_invalid':
    case 'pin_taken':
      return { pin: err.message };
    case 'role_invalid':
    case 'last_chef':
    case 'first_must_be_chef':
      return { role: err.message };
    default:
      return { form: err.message };
  }
}

/** Anlegen und Bearbeiten in einem Dialog. Der Server prüft PIN und Rolle, darum wartet der Dialog auf seine Antwort. */
function StaffDialog({
  business,
  member,
  firstOne,
  open,
  onClose,
}: {
  business: string;
  member?: StaffMember;
  firstOne: boolean;
  open: boolean;
  onClose: () => void;
}) {
  const create = useCreateStaff(business);
  const update = useUpdateStaff(business);
  const editing = member !== undefined;
  const pending = create.isPending || update.isPending;

  const [name, setName] = useState(member?.name ?? '');
  const [role, setRole] = useState<Role>(member?.role ?? (firstOne ? 'chef' : 'staff'));
  const [pin, setPin] = useState('');
  const [problems, setProblems] = useState<Problems>({});

  const onSubmit = (e: FormEvent) => {
    e.preventDefault();
    if (pending) return;
    const trimmed = name.trim();
    const next: Problems = {};
    if (trimmed.length < 1 || trimmed.length > 40) next.name = 'Der Name muss 1 bis 40 Zeichen lang sein.';
    if ((!editing || pin !== '') && !/^[0-9]{4}$/.test(pin)) next.pin = 'Die PIN besteht aus genau vier Ziffern.';
    setProblems(next);
    if (next.name || next.pin) {
      document.getElementById(next.name ? 'mitarbeiter-name' : 'mitarbeiter-pin')?.focus();
      return;
    }
    const onError = (err: ApiError) => setProblems(problemsFrom(err));
    if (editing) {
      update.mutate(
        { id: member.id, name: trimmed, role, ...(pin !== '' ? { pin } : {}) },
        { onSuccess: onClose, onError },
      );
    } else {
      create.mutate({ name: trimmed, role, pin }, { onSuccess: onClose, onError });
    }
  };

  return (
    <Dialog
      title={editing ? 'Mitarbeiter bearbeiten' : 'Mitarbeiter anlegen'}
      open={open}
      onClose={onClose}
      actions={
        <>
          <Button variant="quiet" onClick={onClose}>
            Abbrechen
          </Button>
          <Button type="submit" form={FORM_ID} variant="primary" busy={pending}>
            {editing ? 'Speichern' : 'Anlegen'}
          </Button>
        </>
      }
    >
      <form id={FORM_ID} className={styles.form} onSubmit={onSubmit} noValidate>
        <TextField
          id="mitarbeiter-name"
          label="Name"
          name="name"
          autoComplete="off"
          maxLength={40}
          value={name}
          onChange={(e) => setName(e.target.value)}
          error={problems.name}
        />
        <fieldset className={styles.roles} aria-describedby={problems.role ? 'mitarbeiter-rolle-meldung' : undefined}>
          <legend className={styles.legend}>Rolle</legend>
          <div className={styles.roleChoices}>
            {(['chef', 'staff'] as const).map((r) => (
              <label key={r} className={styles.role}>
                <input
                  type="radio"
                  name="role"
                  value={r}
                  checked={role === r}
                  onChange={() => setRole(r)}
                  className={styles.radio}
                />
                <span className={styles.roleLabel}>{ROLE_LABEL[r]}</span>
              </label>
            ))}
          </div>
          {problems.role && (
            <p id="mitarbeiter-rolle-meldung" className={styles.roleError} role="alert">
              {problems.role}
            </p>
          )}
        </fieldset>
        <TextField
          id="mitarbeiter-pin"
          label={editing ? 'PIN neu setzen' : 'PIN'}
          name="pin"
          inputMode="numeric"
          maxLength={4}
          autoComplete="off"
          value={pin}
          onChange={(e) => setPin(e.target.value.replace(/\D/g, ''))}
          hint={editing ? 'Leer lassen, wenn die PIN bleibt. Vier Ziffern.' : 'Vier Ziffern. Mit der PIN meldet sich die Person an der Kassa an.'}
          error={problems.pin}
        />
        {problems.form && <FormAlert>{problems.form}</FormAlert>}
      </form>
    </Dialog>
  );
}

export function StaffPage() {
  const { detail } = useBusinessContext();
  const b = detail.business;
  const query = useStaff(b.id);
  const setArchived = useSetArchived(b.id);
  const dialog = useDialogState<StaffMember>();

  const archive = (member: StaffMember) =>
    setArchived.mutate(
      { id: member.id, archived: true },
      {
        onSuccess: () =>
          toast.show(`${member.name} ist stillgelegt.`, {
            undo: () => restore(member),
          }),
        onError: (err) => toast.show(err.message),
      },
    );

  const restore = (member: StaffMember) =>
    setArchived.mutate({ id: member.id, archived: false }, { onError: (err) => toast.show(err.message) });

  const list = query.data;
  const addButton = (
    <Button variant="primary" onClick={() => dialog.show()}>
      <PlusIcon size={18} />
      Mitarbeiter anlegen
    </Button>
  );

  return (
    <>
      <PageHeader title="Mitarbeiter" subtitle={<BusinessName />} actions={list && list.length > 0 ? addButton : undefined} />

      {query.isPending && <ListSkeleton label="Mitarbeiter werden geladen" />}
      {query.isError && <LoadError message={query.error.message} onRetry={() => void query.refetch()} />}
      {list?.length === 0 && (
        <EmptyState
          title="Noch kein Mitarbeiter. Lege zuerst einen Chef an."
          text="Der Chef darf alles an der Kassa. Weitere Personen kannst du danach anlegen."
          action={addButton}
        />
      )}
      {list && list.length > 0 && (
        <DataList label="Mitarbeiter">
          {list.map((s) => (
            <DataRow
              key={s.id}
              title={s.name}
              muted={s.archived}
              chips={
                <>
                  <StatusChip tone="neutral">{ROLE_LABEL[s.role]}</StatusChip>
                  {s.archived && <StatusChip tone="off">Stillgelegt</StatusChip>}
                </>
              }
              actions={
                s.archived ? (
                  <Button variant="secondary" aria-label={`Wieder einsetzen: ${s.name}`} onClick={() => restore(s)}>
                    Wieder einsetzen
                  </Button>
                ) : (
                  <>
                    <Button variant="secondary" aria-label={`Bearbeiten: ${s.name}`} onClick={() => dialog.show(s)}>
                      Bearbeiten
                    </Button>
                    <Button variant="danger" aria-label={`Stilllegen: ${s.name}`} onClick={() => archive(s)}>
                      Stilllegen
                    </Button>
                  </>
                )
              }
            />
          ))}
        </DataList>
      )}

      <StaffDialog
        key={dialog.key}
        business={b.id}
        member={dialog.value}
        firstOne={(list?.length ?? 0) === 0}
        open={dialog.open}
        onClose={dialog.close}
      />
    </>
  );
}
