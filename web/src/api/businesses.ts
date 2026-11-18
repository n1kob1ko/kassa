import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { api, ApiError } from './client';

export type BusinessSummary = { id: string; name: string; counts: { items: number; staff: number; registers: number } };

export type Business = {
  id: string;
  name: string;
  addressLines: string[];
  vatId: string | null;
  receiptFooter: string | null;
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
