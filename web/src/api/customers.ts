import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { api, ApiError } from './client';

/** Ein Firmenkunde für die Rechnung, wie `GET …/customers` ihn liefert. */
export type Customer = {
  id: string;
  name: string;
  addressLine1: string;
  addressLine2: string;
  vatId: string | null;
  archived: boolean;
  updatedAt: string;
};

/** Was das Formular schickt. Eine leere UID heißt: keine. */
export type CustomerInput = { name: string; addressLine1: string; addressLine2: string; vatId: string };

/** Höchstlängen wie am Tablet und am Server. */
export const CUSTOMER_TEXT_MAX = 80;
export const CUSTOMER_VAT_ID_MAX = 20;

export type CustomerField = keyof CustomerInput;
export type CustomerProblems = Partial<Record<CustomerField, string>>;

const MESSAGES: Record<'name' | 'addressLine1' | 'addressLine2', string> = {
  name: `Der Name muss 1 bis ${CUSTOMER_TEXT_MAX} Zeichen lang sein.`,
  addressLine1: `Die erste Adress-Zeile muss 1 bis ${CUSTOMER_TEXT_MAX} Zeichen lang sein.`,
  addressLine2: `Die zweite Adress-Zeile muss 1 bis ${CUSTOMER_TEXT_MAX} Zeichen lang sein.`,
};
const VAT_MESSAGE = `Die UID darf höchstens ${CUSTOMER_VAT_ID_MAX} Zeichen lang sein.`;

/**
 * Prüft das Formular wie der Server (und das Tablet): Name und beide Adress-Zeilen Pflicht, je höchstens 80 Zeichen,
 * die UID frei mit höchstens 20 Zeichen. Gezählt wird ohne Leerzeichen vorn und hinten. Leer, wenn alles passt.
 */
export function customerProblems(input: CustomerInput): CustomerProblems {
  const problems: CustomerProblems = {};
  for (const field of ['name', 'addressLine1', 'addressLine2'] as const) {
    const v = input[field].trim();
    if (v.length < 1 || v.length > CUSTOMER_TEXT_MAX) problems[field] = MESSAGES[field];
  }
  if (input.vatId.trim().length > CUSTOMER_VAT_ID_MAX) problems.vatId = VAT_MESSAGE;
  return problems;
}

/** Ordnet einen Fehler des Servers dem Feld zu, zu dem er gehört; sonst `form`. */
export function customerProblemsFrom(err: ApiError): CustomerProblems & { form?: string } {
  switch (err.code) {
    case 'name_invalid':
      return { name: err.message };
    case 'address_line1_invalid':
      return { addressLine1: err.message };
    case 'address_line2_invalid':
      return { addressLine2: err.message };
    case 'vat_id_invalid':
      return { vatId: err.message };
    default:
      return { form: err.message };
  }
}

/** Was an den Server geht: ohne Leerzeichen vorn und hinten, eine leere UID als `null`. */
export function customerBody(input: CustomerInput) {
  const vatId = input.vatId.trim();
  return {
    name: input.name.trim(),
    addressLine1: input.addressLine1.trim(),
    addressLine2: input.addressLine2.trim(),
    vatId: vatId === '' ? null : vatId,
  };
}

export type CustomerBody = ReturnType<typeof customerBody>;

/**
 * Beim Bearbeiten nur die Felder, die sich gegenüber [stored] wirklich ändern (verglichen wie gespeichert: ohne
 * Leerzeichen am Rand, leere UID als `null`). Leer, wenn sich nichts ändert: dann geht nichts an den Server, und
 * die Tablets holen den Kunden nicht noch einmal.
 */
export function customerChanges(stored: Customer, input: CustomerInput): Partial<CustomerBody> {
  const next = customerBody(input);
  const changes: Partial<CustomerBody> = {};
  if (next.name !== stored.name) changes.name = next.name;
  if (next.addressLine1 !== stored.addressLine1) changes.addressLine1 = next.addressLine1;
  if (next.addressLine2 !== stored.addressLine2) changes.addressLine2 = next.addressLine2;
  if (next.vatId !== stored.vatId) changes.vatId = next.vatId;
  return changes;
}

/** Aktive zuerst, archivierte am Ende, je nach Name: wie der Server sortiert. */
export function sortCustomers(list: Customer[]): Customer[] {
  return [...list].sort(
    (x, y) => Number(x.archived) - Number(y.archived) || x.name.localeCompare(y.name, 'de') || x.id.localeCompare(y.id),
  );
}

export const customersKey = (b: string) => ['customers', b] as const;
const base = (b: string) => `/api/admin/businesses/${encodeURIComponent(b)}/customers`;

export function useCustomers(b: string) {
  return useQuery<Customer[], ApiError>({
    queryKey: customersKey(b),
    queryFn: async () => (await api.get<{ customers: Customer[] }>(base(b))).customers,
  });
}

export function useCreateCustomer(b: string) {
  const queryClient = useQueryClient();
  return useMutation<Customer, ApiError, CustomerInput>({
    mutationFn: async (input) => (await api.post<{ customer: Customer }>(base(b), customerBody(input))).customer,
    onSuccess: () => queryClient.invalidateQueries({ queryKey: customersKey(b) }),
  });
}

export function useUpdateCustomer(b: string) {
  const queryClient = useQueryClient();
  return useMutation<Customer, ApiError, Partial<CustomerBody> & { id: string }>({
    mutationFn: async ({ id, ...changes }) => (await api.patch<{ customer: Customer }>(`${base(b)}/${id}`, changes)).customer,
    onSuccess: () => queryClient.invalidateQueries({ queryKey: customersKey(b) }),
  });
}

/** Archivieren und zurückholen: sofort in der Liste, bei einem Fehler zurück (wie bei den Mitarbeitern). */
export function useSetCustomerArchived(b: string) {
  const queryClient = useQueryClient();
  return useMutation<Customer, ApiError, { id: string; archived: boolean }, { before?: Customer[] }>({
    mutationFn: async ({ id, archived }) => (await api.patch<{ customer: Customer }>(`${base(b)}/${id}`, { archived })).customer,
    onMutate: async (vars) => {
      await queryClient.cancelQueries({ queryKey: customersKey(b) });
      const before = queryClient.getQueryData<Customer[]>(customersKey(b));
      if (before) {
        queryClient.setQueryData(
          customersKey(b),
          sortCustomers(before.map((c) => (c.id === vars.id ? { ...c, archived: vars.archived } : c))),
        );
      }
      return { before };
    },
    onError: (_err, _vars, context) => {
      if (context?.before) queryClient.setQueryData(customersKey(b), context.before);
    },
    onSettled: () => queryClient.invalidateQueries({ queryKey: customersKey(b) }),
  });
}
