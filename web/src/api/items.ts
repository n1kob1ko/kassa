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

type PatchVars = { id: string; change: ItemChange };
type PatchContext = { token: number; previous: ItemChange };

/**
 * Preis, "Im Verkauf" oder Favorit ändern, optimistisch: der Wert steht sofort da. Scheitert es, springt er
 * zurück (nur wenn danach nichts Neueres kam), der Hinweis nennt den Grund, und die Liste wird neu geholt.
 * Eine Änderung im Browser gewinnt am Server immer gegen das Tablet.
 */
export function usePatchItem(b: string) {
  const queryClient = useQueryClient();
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
      await queryClient.cancelQueries({ queryKey: itemsKey(b) });
      const token = nextToken++;
      const before = findItem(queryClient.getQueryData<Items>(itemsKey(b)), id);
      const previous: ItemChange = {};
      for (const f of Object.keys(change) as Field[]) {
        if (before) (previous as Record<Field, unknown>)[f] = before[f];
        const key = fieldKey(b, id, f);
        inFlight.set(key, count(key) + 1);
        latest.set(key, token);
      }
      queryClient.setQueryData<Items>(itemsKey(b), (d) => mapItem(d, id, (i) => ({ ...i, ...change })));
      return { token, previous };
    },
    onSuccess: (item, { id }) => {
      // Nur Felder übernehmen, an denen nicht schon eine neuere Änderung unterwegs ist.
      queryClient.setQueryData<Items>(itemsKey(b), (d) =>
        mapItem(d, id, (current) => {
          const merged = { ...current, ...item };
          for (const f of ['priceCents', 'inSale', 'favorite'] as Field[]) {
            if (count(fieldKey(b, id, f)) > 1) (merged as Record<Field, unknown>)[f] = current[f];
          }
          return merged;
        }),
      );
    },
    onError: (err, { id, change }, context) => {
      if (context) {
        const back: ItemChange = {};
        for (const f of Object.keys(change) as Field[]) {
          if (latest.get(fieldKey(b, id, f)) === context.token && f in context.previous) {
            (back as Record<Field, unknown>)[f] = context.previous[f];
          }
        }
        queryClient.setQueryData<Items>(itemsKey(b), (d) => mapItem(d, id, (i) => ({ ...i, ...back })));
      }
      toast.show(err.message);
    },
    onSettled: (_item, err, { id, change }) => {
      settle(Object.keys(change) as Field[], id);
      // Nach einem Fehler zeigt die Liste, was der Server wirklich hat, sobald nichts mehr unterwegs ist.
      if (err && queryClient.isMutating({ mutationKey: changeKey(b) }) <= 1) {
        void queryClient.invalidateQueries({ queryKey: itemsKey(b) });
      }
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
