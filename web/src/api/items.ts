import { useMutation, useQuery, useQueryClient, type QueryClient } from '@tanstack/react-query';
import { toast } from '../ui/Toast';
import { api, ApiError } from './client';
import { isAbort, uploadImage, type Picture, type UploadedFile, type UploadOptions } from './files';

/** Ein Artikel, wie ihn `GET /api/admin/businesses/:b/items` nennt. */
export type MenuItem = {
  id: string;
  name: string;
  priceCents: number;
  inSale: boolean;
  favorite: boolean;
  archived: boolean;
  photo: Picture | null;
};
export type ItemCategory = { id: string; name: string; archived: boolean; items: MenuItem[] };
export type Items = { categories: ItemCategory[] };

/** Was der Browser an einem Artikel ändern darf. */
export type ItemChange = Partial<Pick<MenuItem, 'priceCents' | 'inSale' | 'favorite'>>;
type Field = keyof ItemChange;

export const itemsKey = (b: string) => ['items', b] as const;
const changeKey = (b: string) => ['items', b, 'change'] as const;
const itemPath = (b: string, id: string) => `/api/admin/businesses/${encodeURIComponent(b)}/items/${encodeURIComponent(id)}`;

/** Die Artikel nach Kategorie, in der Reihenfolge der Speisekarte (stillgelegte mit dabei). */
export function useItems(b: string) {
  return useQuery<Items, ApiError>({
    queryKey: itemsKey(b),
    queryFn: () => api.get<Items>(`/api/admin/businesses/${encodeURIComponent(b)}/items`),
  });
}

function mapItem(data: Items | undefined, id: string, change: (item: MenuItem) => MenuItem): Items | undefined {
  if (!data) return data;
  return {
    categories: data.categories.map((c) =>
      c.items.some((i) => i.id === id) ? { ...c, items: c.items.map((i) => (i.id === id ? change(i) : i)) } : c,
    ),
  };
}

function findItem(data: Items | undefined, id: string): MenuItem | undefined {
  return data?.categories.flatMap((c) => c.items).find((i) => i.id === id);
}

/**
 * Änderungen an einem Artikel gehen nacheinander zum Server, nie überholt eine ältere eine neuere. Was gerade
 * unterwegs ist, zählt `inFlight` je Artikel und Feld; `latest` merkt sich die jüngste Änderung je Feld.
 */
const queues = new Map<string, Promise<unknown>>();
const inFlight = new Map<string, number>();
const latest = new Map<string, number>();
let nextToken = 1;

/**
 * Je Betrieb: wie viele Änderungen laufen, und ob die Liste danach neu geholt werden muss (nach einem Fehler, oder weil
 * ein Neuladen abgebrochen wurde). Geholt wird erst, wenn nichts mehr läuft; dann hat der Server alles.
 */
const running = new Map<string, number>();
const owed = new Set<string>();

/** Die Werte, die im Browser schon stehen, deren Antwort aber noch fehlt: je Betrieb, Artikel und Feld. */
const unconfirmed = new Map<string, Map<string, Map<Field, { token: number; value: unknown }>>>();

function inOrder<T>(key: string, run: () => Promise<T>): Promise<T> {
  const next = (queues.get(key) ?? Promise.resolve()).then(run, run);
  queues.set(key, next);
  const cleanup = () => {
    if (queues.get(key) === next) queues.delete(key);
  };
  next.then(cleanup, cleanup);
  return next;
}

const fieldKey = (b: string, id: string, field: string) => `${b}/${id}/${field}`;
const count = (key: string) => inFlight.get(key) ?? 0;

function remember(b: string, id: string, change: ItemChange, token: number) {
  const items = unconfirmed.get(b) ?? new Map<string, Map<Field, { token: number; value: unknown }>>();
  const fields = items.get(id) ?? new Map<Field, { token: number; value: unknown }>();
  for (const [f, value] of Object.entries(change) as [Field, unknown][]) fields.set(f, { token, value });
  items.set(id, fields);
  unconfirmed.set(b, items);
}

function forget(b: string, id: string, change: ItemChange, token: number) {
  const fields = unconfirmed.get(b)?.get(id);
  if (!fields) return;
  for (const f of Object.keys(change) as Field[]) if (fields.get(f)?.token === token) fields.delete(f);
  if (fields.size === 0) unconfirmed.get(b)!.delete(id);
  if (unconfirmed.get(b)!.size === 0) unconfirmed.delete(b);
}

/**
 * Kommt eine Liste vom Server, während Änderungen noch unterwegs sind, kennt sie diese noch nicht: die Werte aus dem
 * Browser bleiben stehen, bis ihre Antwort da ist. Einmal je QueryClient.
 */
const watched = new WeakSet<QueryClient>();
function keepUnconfirmed(queryClient: QueryClient) {
  if (watched.has(queryClient)) return;
  watched.add(queryClient);
  queryClient.getQueryCache().subscribe((event) => {
    if (event.type !== 'updated' || event.action.type !== 'success' || event.action.manual) return;
    const [kind, b, ...rest] = event.query.queryKey as unknown[];
    if (kind !== 'items' || typeof b !== 'string' || rest.length > 0) return;
    const items = unconfirmed.get(b);
    if (!items) return;
    queryClient.setQueryData<Items>(itemsKey(b), (d) => {
      let next = d;
      for (const [id, fields] of items) {
        const change = Object.fromEntries([...fields].map(([f, { value }]) => [f, value])) as ItemChange;
        next = mapItem(next, id, (i) => ({ ...i, ...change }));
      }
      return next;
    });
  });
}

/** Läuft gerade ein Neuladen der Liste, wird es abgebrochen (es kennt die Änderung nicht) und danach nachgeholt. */
async function stopRefetch(queryClient: QueryClient, b: string) {
  if (queryClient.isFetching({ queryKey: itemsKey(b), exact: true }) > 0) owed.add(b);
  await queryClient.cancelQueries({ queryKey: itemsKey(b), exact: true });
}

type PatchVars = { id: string; change: ItemChange };
type PatchContext = { token: number; previous: ItemChange };

/**
 * Preis, "Im Verkauf" oder Favorit ändern, optimistisch: der Wert steht sofort da. Scheitert es, springt er
 * zurück (nur wenn danach nichts Neueres kam), der Hinweis nennt den Grund, und sobald keine Änderung des Betriebs
 * mehr läuft, wird die Liste neu geholt. `onSaved` kommt nach jeder geglückten Änderung.
 * Eine Änderung im Browser gewinnt am Server immer gegen das Tablet.
 */
export function usePatchItem(b: string, { onSaved }: { onSaved?: () => void } = {}) {
  const queryClient = useQueryClient();
  keepUnconfirmed(queryClient);
  const settle = (fields: Field[], id: string) => {
    for (const f of fields) {
      const key = fieldKey(b, id, f);
      const n = count(key) - 1;
      if (n > 0) inFlight.set(key, n);
      else inFlight.delete(key);
    }
  };

  return useMutation<MenuItem, ApiError, PatchVars, PatchContext>({
    mutationKey: changeKey(b),
    mutationFn: ({ id, change }) => inOrder(`${b}/${id}`, () => api.patch<MenuItem>(itemPath(b, id), change)),
    onMutate: async ({ id, change }) => {
      running.set(b, (running.get(b) ?? 0) + 1);
      const token = nextToken++;
      const before = findItem(queryClient.getQueryData<Items>(itemsKey(b)), id);
      const previous: ItemChange = {};
      for (const f of Object.keys(change) as Field[]) {
        if (before) (previous as Record<Field, unknown>)[f] = before[f];
        const key = fieldKey(b, id, f);
        inFlight.set(key, count(key) + 1);
        latest.set(key, token);
      }
      remember(b, id, change, token);
      await stopRefetch(queryClient, b);
      queryClient.setQueryData<Items>(itemsKey(b), (d) => mapItem(d, id, (i) => ({ ...i, ...change })));
      return { token, previous };
    },
    onSuccess: async (item, { id, change }) => {
      // Ein Neuladen, das vor dieser Antwort begann, brächte den alten Wert zurück.
      await stopRefetch(queryClient, b);
      // Nur Felder übernehmen, an denen nicht noch eine Änderung unterwegs ist: an eigenen Feldern eine neuere (die
      // eigene zählt mit), an anderen jede. Die Antwort kennt sie noch nicht.
      queryClient.setQueryData<Items>(itemsKey(b), (d) =>
        mapItem(d, id, (current) => {
          const merged = { ...current, ...item };
          for (const f of ['priceCents', 'inSale', 'favorite'] as Field[]) {
            const own = f in change ? 1 : 0;
            if (count(fieldKey(b, id, f)) > own) (merged as Record<Field, unknown>)[f] = current[f];
          }
          return merged;
        }),
      );
      onSaved?.();
    },
    onError: (err, { id, change }, context) => {
      owed.add(b);
      if (context) {
        const back: ItemChange = {};
        for (const f of Object.keys(change) as Field[]) {
          if (latest.get(fieldKey(b, id, f)) === context.token && f in context.previous) {
            (back as Record<Field, unknown>)[f] = context.previous[f];
          }
        }
        forget(b, id, change, context.token);
        queryClient.setQueryData<Items>(itemsKey(b), (d) => mapItem(d, id, (i) => ({ ...i, ...back })));
      }
      toast.show(err.message);
    },
    onSettled: (_item, _err, { id, change }, context) => {
      settle(Object.keys(change) as Field[], id);
      if (context) forget(b, id, change, context.token);
      const left = (running.get(b) ?? 1) - 1;
      if (left > 0) {
        running.set(b, left);
        return;
      }
      running.delete(b);
      // Die Liste zeigt dann, was der Server wirklich hat.
      if (owed.delete(b)) void queryClient.invalidateQueries({ queryKey: itemsKey(b), exact: true });
    },
  });
}

function setPhoto(queryClient: QueryClient, b: string, itemId: string, photo: Picture | null) {
  queryClient.setQueryData<Items>(itemsKey(b), (d) => mapItem(d, itemId, (i) => ({ ...i, photo })));
}

export type SetPhotoVars = { itemId: string; file: Blob } & UploadOptions;

/** Ein Foto hochladen (ersetzt ein vorhandenes). Danach zeigt die Zeile das neue Bild. Abgebrochen: die Liste wird neu geholt. */
export function useSetPhoto(b: string) {
  const queryClient = useQueryClient();
  return useMutation<UploadedFile, ApiError | DOMException, SetPhotoVars>({
    mutationFn: ({ itemId, file, onProgress, signal }) => uploadImage(`${itemPath(b, itemId)}/photo`, file, { onProgress, signal }),
    onSuccess: (file, { itemId }) => setPhoto(queryClient, b, itemId, { id: file.id, color: file.color }),
    onError: (err) => {
      // War das Bild schon ganz beim Server, hat er es vielleicht angenommen: die Liste zeigt dann die Wahrheit.
      if (isAbort(err)) void queryClient.invalidateQueries({ queryKey: itemsKey(b) });
    },
  });
}

/** Das Foto entfernen, sofort in der Liste. Scheitert es, kommt es zurück; den Grund zeigt die Seite. */
export function useRemovePhoto(b: string) {
  const queryClient = useQueryClient();
  return useMutation<void, ApiError, string, { previous: Picture | null }>({
    mutationFn: (itemId) => api.del(`${itemPath(b, itemId)}/photo`),
    onMutate: async (itemId) => {
      await queryClient.cancelQueries({ queryKey: itemsKey(b) });
      const previous = findItem(queryClient.getQueryData<Items>(itemsKey(b)), itemId)?.photo ?? null;
      setPhoto(queryClient, b, itemId, null);
      return { previous };
    },
    onError: (_err, itemId, context) => {
      setPhoto(queryClient, b, itemId, context?.previous ?? null);
      void queryClient.invalidateQueries({ queryKey: itemsKey(b) });
    },
  });
}
