import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { api, ApiError } from './client';
import { isAbort, uploadImage, type Picture, type UploadedFile, type UploadOptions } from './files';

export type BusinessSummary = { id: string; name: string; counts: { items: number; staff: number; registers: number } };

export type Business = {
  id: string;
  name: string;
  addressLines: string[];
  vatId: string | null;
  receiptFooter: string | null;
  /** Das Logo des Betriebs, oder keines. */
  logo: Picture | null;
  counts: { categories: number; items: number; templates: number; staff: number; registers: number };
};

export type Category = { id: string; name: string; itemCount: number; archived: boolean };
export type BusinessDetail = { business: Business; categories: Category[] };

type Counts = { added: number; changed: number; archived: number };
export type ImportSummary = { categories: Counts; items: Counts; templates: Counts };

export const BUSINESSES_KEY = ['businesses'] as const;
export const businessKey = (id: string) => ['business', id] as const;

export function useBusinesses() {
  return useQuery<BusinessSummary[], ApiError>({
    queryKey: BUSINESSES_KEY,
    queryFn: async () => (await api.get<{ businesses: BusinessSummary[] }>('/api/admin/businesses')).businesses,
  });
}

export function useBusiness(id: string) {
  return useQuery<BusinessDetail, ApiError>({
    queryKey: businessKey(id),
    queryFn: () => api.get<BusinessDetail>(`/api/admin/businesses/${encodeURIComponent(id)}`),
  });
}

/** Speisekarten-Datei als Text an die Schnittstelle: so nimmt der Server sie an. */
export function useCreateBusiness() {
  const queryClient = useQueryClient();
  return useMutation<{ business: { id: string; name: string } }, ApiError, string>({
    mutationFn: (menuFile) => api.post('/api/admin/businesses', { menuFile }),
    onSuccess: () => queryClient.invalidateQueries({ queryKey: BUSINESSES_KEY }),
  });
}

export function useReimportMenu(id: string) {
  const queryClient = useQueryClient();
  return useMutation<{ summary: ImportSummary; ignoredStaff: number }, ApiError, string>({
    mutationFn: (menuFile) => api.post(`/api/admin/businesses/${encodeURIComponent(id)}/menu`, { menuFile }),
    onSuccess: async () => {
      await Promise.all([
        queryClient.invalidateQueries({ queryKey: businessKey(id) }),
        queryClient.invalidateQueries({ queryKey: BUSINESSES_KEY }),
      ]);
    },
  });
}

/** Neu, geändert, stillgelegt: die Summe über Kategorien, Artikel und Vorlagen. */
export function summaryText(s: ImportSummary): string {
  const sum = (key: keyof Counts) => s.categories[key] + s.items[key] + s.templates[key];
  return `${sum('added')} neu, ${sum('changed')} geändert, ${sum('archived')} stillgelegt`;
}

const logoPath = (id: string) => `/api/admin/businesses/${encodeURIComponent(id)}/logo`;

function setLogo(queryClient: ReturnType<typeof useQueryClient>, id: string, logo: Picture | null) {
  queryClient.setQueryData<BusinessDetail>(businessKey(id), (d) => (d ? { ...d, business: { ...d.business, logo } } : d));
}

export type SetLogoVars = { file: Blob } & UploadOptions;

/** Das Logo hochladen (ersetzt ein vorhandenes). Die Kopfzeile und die Seite "Betrieb" zeigen es gleich danach. */
export function useSetLogo(id: string) {
  const queryClient = useQueryClient();
  return useMutation<UploadedFile, ApiError | DOMException, SetLogoVars>({
    mutationFn: ({ file, onProgress, signal }) => uploadImage(logoPath(id), file, { onProgress, signal }),
    onSuccess: (file) => setLogo(queryClient, id, { id: file.id, color: file.color }),
    onError: (err) => {
      if (isAbort(err)) void queryClient.invalidateQueries({ queryKey: businessKey(id) });
    },
  });
}

/** Das Logo entfernen, sofort überall. Scheitert es, kommt es zurück; den Grund zeigt die Seite. */
export function useRemoveLogo(id: string) {
  const queryClient = useQueryClient();
  return useMutation<void, ApiError, void, { previous: Picture | null }>({
    mutationFn: () => api.del(logoPath(id)),
    onMutate: async () => {
      await queryClient.cancelQueries({ queryKey: businessKey(id) });
      const previous = queryClient.getQueryData<BusinessDetail>(businessKey(id))?.business.logo ?? null;
      setLogo(queryClient, id, null);
      return { previous };
    },
    onError: (_err, _v, context) => {
      setLogo(queryClient, id, context?.previous ?? null);
      void queryClient.invalidateQueries({ queryKey: businessKey(id) });
    },
  });
}
