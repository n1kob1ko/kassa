import { useState, type FormEvent } from 'react';
import {
  customerChanges,
  customerProblems,
  customerProblemsFrom,
  CUSTOMER_TEXT_MAX,
  CUSTOMER_VAT_ID_MAX,
  useCreateCustomer,
  useCustomers,
  useSetCustomerArchived,
  useUpdateCustomer,
  type Customer,
  type CustomerField,
  type CustomerInput,
} from '../api/customers';
import type { ApiError } from '../api/client';
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
import { FormAlert } from './AuthLayout';
import { BusinessName, useBusinessContext } from './BusinessLayout';
import styles from './CustomersPage.module.css';

const FORM_ID = 'firmenkunde-formular';
const FIELD_IDS: Record<CustomerField, string> = {
  name: 'firmenkunde-name',
  addressLine1: 'firmenkunde-adresse-1',
  addressLine2: 'firmenkunde-adresse-2',
  vatId: 'firmenkunde-uid',
};
const ORDER: CustomerField[] = ['name', 'addressLine1', 'addressLine2', 'vatId'];

type Problems = Partial<Record<CustomerField, string>> & { form?: string };

/** Anlegen und Bearbeiten in einem Dialog, mit denselben Pflichtfeldern und Längen wie am Tablet. */
function CustomerDialog({
  business,
  customer,
  open,
  onClose,
}: {
  business: string;
  customer?: Customer;
  open: boolean;
  onClose: () => void;
}) {
  const create = useCreateCustomer(business);
  const update = useUpdateCustomer(business);
  const editing = customer !== undefined;
  const pending = create.isPending || update.isPending;

  const [values, setValues] = useState<CustomerInput>({
    name: customer?.name ?? '',
    addressLine1: customer?.addressLine1 ?? '',
    addressLine2: customer?.addressLine2 ?? '',
    vatId: customer?.vatId ?? '',
  });
  const [problems, setProblems] = useState<Problems>({});
  const set = (field: CustomerField) => (e: { target: { value: string } }) => setValues((v) => ({ ...v, [field]: e.target.value }));

  const onSubmit = (e: FormEvent) => {
    e.preventDefault();
    if (pending) return;
    const next = customerProblems(values);
    setProblems(next);
    const first = ORDER.find((f) => next[f]);
    if (first) {
      document.getElementById(FIELD_IDS[first])?.focus();
      return;
    }
    const onError = (err: ApiError) => setProblems(customerProblemsFrom(err));
    if (editing) {
      // Nichts geändert: nichts senden, der Dialog geht zu.
      const changes = customerChanges(customer, values);
      if (Object.keys(changes).length === 0) onClose();
      else update.mutate({ id: customer.id, ...changes }, { onSuccess: onClose, onError });
    }
    else create.mutate(values, { onSuccess: onClose, onError });
  };

  return (
    <Dialog
      title={editing ? 'Firmenkunde bearbeiten' : 'Neuer Kunde'}
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
          id={FIELD_IDS.name}
          label="Name"
          name="name"
          autoComplete="organization"
          maxLength={CUSTOMER_TEXT_MAX}
          placeholder="Muster GmbH"
          value={values.name}
          onChange={set('name')}
          error={problems.name}
        />
        <TextField
          id={FIELD_IDS.addressLine1}
          label="Adresse, Zeile 1"
          name="addressLine1"
          autoComplete="address-line1"
          maxLength={CUSTOMER_TEXT_MAX}
          placeholder="Musterweg 1"
          value={values.addressLine1}
          onChange={set('addressLine1')}
          error={problems.addressLine1}
        />
        <TextField
          id={FIELD_IDS.addressLine2}
          label="Adresse, Zeile 2"
          name="addressLine2"
          autoComplete="address-line2"
          maxLength={CUSTOMER_TEXT_MAX}
          placeholder="1010 Wien"
          value={values.addressLine2}
          onChange={set('addressLine2')}
          error={problems.addressLine2}
        />
        <TextField
          id={FIELD_IDS.vatId}
          label="UID (frei)"
          name="vatId"
          autoComplete="off"
          maxLength={CUSTOMER_VAT_ID_MAX}
          placeholder="ATU00000000"
          value={values.vatId}
          onChange={set('vatId')}
          hint="Leer lassen, wenn der Kunde keine hat. Über 10.000 € verlangt die Kassa sie auf der Rechnung."
          error={problems.vatId}
        />
        {problems.form && <FormAlert>{problems.form}</FormAlert>}
      </form>
    </Dialog>
  );
}

/** Firmenkunden für "Rechnung an Firma" (Spec 5.3): anlegen, ändern, archivieren. Änderungen gehen an alle Tablets. */
export function CustomersPage() {
  const { detail } = useBusinessContext();
  const b = detail.business;
  const query = useCustomers(b.id);
  const setArchived = useSetCustomerArchived(b.id);
  const dialog = useDialogState<Customer>();

  const archive = (customer: Customer) =>
    setArchived.mutate(
      { id: customer.id, archived: true },
      {
        onSuccess: () =>
          toast.show(`${customer.name} ist archiviert.`, {
            undo: () => restore(customer),
          }),
        onError: (err) => toast.show(err.message),
      },
    );

  const restore = (customer: Customer) =>
    setArchived.mutate({ id: customer.id, archived: false }, { onError: (err) => toast.show(err.message) });

  const list = query.data;
  const addButton = (
    <Button variant="primary" onClick={() => dialog.show()}>
      <PlusIcon size={18} />
      Neuer Kunde
    </Button>
  );

  return (
    <>
      <PageHeader title="Firmenkunden" subtitle={<BusinessName />} actions={list && list.length > 0 ? addButton : undefined} />

      {query.isPending && <ListSkeleton label="Firmenkunden werden geladen" />}
      {query.isError && <LoadError message={query.error.message} onRetry={() => void query.refetch()} />}
      {list?.length === 0 && (
        <EmptyState
          title="Noch kein Firmenkunde."
          text={'Firmenkunden stehen an der Kassa bei "Rechnung an Firma" zur Wahl. Du kannst sie hier oder an der Kassa anlegen.'}
          action={addButton}
        />
      )}
      {list && list.length > 0 && (
        <DataList label="Firmenkunden">
          {list.map((c) => (
            <DataRow
              key={c.id}
              title={c.name}
              muted={c.archived}
              chips={c.archived ? <StatusChip tone="off">Archiviert</StatusChip> : undefined}
              meta={[
                <span key="adresse" className={styles.address}>
                  <span>{c.addressLine1}</span>
                  <span>{c.addressLine2}</span>
                </span>,
                c.vatId ? `UID ${c.vatId}` : 'Ohne UID',
              ]}
              actions={
                c.archived ? (
                  <Button variant="secondary" aria-label={`Zurückholen: ${c.name}`} onClick={() => restore(c)}>
                    Zurückholen
                  </Button>
                ) : (
                  <>
                    <Button variant="secondary" aria-label={`Bearbeiten: ${c.name}`} onClick={() => dialog.show(c)}>
                      Bearbeiten
                    </Button>
                    <Button variant="danger" aria-label={`Archivieren: ${c.name}`} onClick={() => archive(c)}>
                      Archivieren
                    </Button>
                  </>
                )
              }
            />
          ))}
        </DataList>
      )}

      <CustomerDialog key={dialog.key} business={b.id} customer={dialog.value} open={dialog.open} onClose={dialog.close} />
    </>
  );
}
