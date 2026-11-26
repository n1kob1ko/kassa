import { useMutation, useQuery, useQueryClient, type QueryClient } from '@tanstack/react-query';
import { toast } from '../ui/Toast';
import { api, ApiError } from './client';

/** Die Sprachen, in die übersetzt wird. Die Speisekarte selbst ist Deutsch. */
export type TranslationLang = 'en' | 'zh' | 'tr' | 'ar';

/** Ein Name der Speisekarte mit seinen Übersetzungen; fehlt eine Sprache, gilt der Name. */
export type TranslationRow = { source: string; values: Partial<Record<TranslationLang, string>> };

/** Kategorien, dann je Kategorie ihre Artikel mit Zusatzangabe, dann "Auswahl und Extras". Jeder Name nur einmal. */
export type TranslationSection = { kind: 'categories' | 'category' | 'extras'; title: string; rows: TranslationRow[] };

/** Was `GET /api/admin/businesses/:b/translations` liefert. */
export type Translations = { sections: TranslationSection[]; total: number; done: Record<TranslationLang, number> };

export const translationsKey = (b: string) => ['translations', b] as const;
const path = (b: string) => `/api/admin/businesses/${encodeURIComponent(b)}/translations`;

/** Werte, die im Browser schon stehen, deren Antwort aber noch fehlt: je Betrieb, "Sprache/Name". */
const unconfirmed = new Map<string, Map<string, string>>();
const entry = (lang: TranslationLang, source: string) => `${lang}/${source}`;

function setValue(data: Translations | undefined, source: string, lang: TranslationLang, value: string): Translations | undefined {
  if (!data) return data;
  const set = (row: TranslationRow): TranslationRow => {
    if (row.source !== source) return row;
    const values = { ...row.values };
    if (value === '') delete values[lang];
    else values[lang] = value;
    return { ...row, values };
  };
  return { ...data, sections: data.sections.map((s) => (s.rows.some((r) => r.source === source) ? { ...s, rows: s.rows.map(set) } : s)) };
}

function valueOf(data: Translations | undefined, source: string, lang: TranslationLang): string {
  for (const s of data?.sections ?? []) for (const r of s.rows) if (r.source === source) return r.values[lang] ?? '';
  return '';
}

/** Die Namen der Speisekarte mit ihren Übersetzungen. Was gerade gespeichert wird, bleibt stehen, auch nach einem Neuladen. */
export function useTranslations(b: string) {
  return useQuery<Translations, ApiError>({
    queryKey: translationsKey(b),
    queryFn: async () => {
      let data: Translations | undefined = await api.get<Translations>(path(b));
      for (const [key, value] of unconfirmed.get(b) ?? []) {
        const slash = key.indexOf('/');
        data = setValue(data, key.slice(slash + 1), key.slice(0, slash) as TranslationLang, value);
      }
      return data!;
    },
  });
}

/** Je Name und Sprache gehen Änderungen nacheinander zum Server; `latest` merkt sich die jüngste. */
const queues = new Map<string, Promise<unknown>>();
const latest = new Map<string, number>();
let nextToken = 1;
/** Je Betrieb: wie viele Änderungen laufen, und ob die Liste danach neu geholt werden muss. */
const running = new Map<string, number>();
const owed = new Set<string>();

function inOrder<T>(key: string, run: () => Promise<T>): Promise<T> {
  const next = (queues.get(key) ?? Promise.resolve()).then(run, run);
  queues.set(key, next);
  const cleanup = () => {
    if (queues.get(key) === next) queues.delete(key);
  };
  next.then(cleanup, cleanup);
  return next;
}

/** Ein laufendes Neuladen kennt die Änderung nicht: abbrechen und nachholen, wenn nichts mehr läuft. */
async function stopRefetch(queryClient: QueryClient, b: string) {
  if (queryClient.isFetching({ queryKey: translationsKey(b), exact: true }) > 0) owed.add(b);
  await queryClient.cancelQueries({ queryKey: translationsKey(b), exact: true });
}

export type SetTranslationVars = { source: string; lang: TranslationLang; value: string };
type SetContext = { token: number; previous: string };

/**
 * Eine Übersetzung setzen, optimistisch: der Text steht sofort da (leer löscht sie). Scheitert es, kommt der alte
 * Text zurück (nur wenn danach nichts Neueres kam), und der Hinweis nennt den Grund. `onSaved` kommt nach jeder
 * geglückten Änderung.
 */
export function useSetTranslation(b: string, { onSaved }: { onSaved?: () => void } = {}) {
  const queryClient = useQueryClient();
  return useMutation<TranslationRow, ApiError, SetTranslationVars, SetContext>({
    mutationFn: ({ source, lang, value }) => inOrder(`${b}/${entry(lang, source)}`, () => api.put<TranslationRow>(path(b), { source, lang, value })),
    onMutate: async ({ source, lang, value }) => {
      running.set(b, (running.get(b) ?? 0) + 1);
      const token = nextToken++;
      const key = `${b}/${entry(lang, source)}`;
      latest.set(key, token);
      const previous = valueOf(queryClient.getQueryData<Translations>(translationsKey(b)), source, lang);
      const own = unconfirmed.get(b) ?? new Map<string, string>();
      own.set(entry(lang, source), value);
      unconfirmed.set(b, own);
      await stopRefetch(queryClient, b);
      queryClient.setQueryData<Translations>(translationsKey(b), (d) => setValue(d, source, lang, value));
      return { token, previous };
    },
    onSuccess: async (row, { source, lang }, context) => {
      await stopRefetch(queryClient, b);
      // Der Server kürzt Leerzeichen am Rand: sein Wert gilt, wenn nichts Neueres kam.
      if (latest.get(`${b}/${entry(lang, source)}`) === context.token) {
        queryClient.setQueryData<Translations>(translationsKey(b), (d) => setValue(d, source, lang, row.values[lang] ?? ''));
      }
      onSaved?.();
    },
    onError: (err, { source, lang }, context) => {
      owed.add(b);
      if (context && latest.get(`${b}/${entry(lang, source)}`) === context.token) {
        unconfirmed.get(b)?.delete(entry(lang, source));
        queryClient.setQueryData<Translations>(translationsKey(b), (d) => setValue(d, source, lang, context.previous));
      }
      toast.show(err.message);
    },
    onSettled: (_row, _err, { source, lang }, context) => {
      const key = `${b}/${entry(lang, source)}`;
      if (context && latest.get(key) === context.token) {
        latest.delete(key);
        const own = unconfirmed.get(b);
        own?.delete(entry(lang, source));
        if (own?.size === 0) unconfirmed.delete(b);
      }
      const left = (running.get(b) ?? 1) - 1;
      if (left > 0) {
        running.set(b, left);
        return;
      }
      running.delete(b);
      if (owed.delete(b)) void queryClient.invalidateQueries({ queryKey: translationsKey(b), exact: true });
    },
  });
}

/** Eine Datei nur mit Übersetzungen einspielen (nur der Anbieter). Danach zeigt die Seite den neuen Stand. */
export function useImportTranslations(b: string) {
  const queryClient = useQueryClient();
  return useMutation<{ changed: number }, ApiError, string>({
    mutationFn: (translationsFile) => api.post(`${path(b)}/import`, { translationsFile }),
    onSuccess: () => queryClient.invalidateQueries({ queryKey: translationsKey(b), exact: true }),
  });
}
