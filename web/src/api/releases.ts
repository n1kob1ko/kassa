import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { api, ApiError } from './client';

export type Release = {
  id: string;
  version: string;
  build: number;
  sha256: string;
  size: number;
  uploadedAt: string;
  withdrawn: boolean;
  /** Der geheime Teil des Links, `null` nach dem Zurückziehen. */
  downloadPath: string | null;
};

export const RELEASES_KEY = ['releases'] as const;

export function useReleases() {
  return useQuery<Release[], ApiError>({
    queryKey: RELEASES_KEY,
    queryFn: async () => (await api.get<{ releases: Release[] }>('/api/admin/releases')).releases,
  });
}

/** Zurückziehen: Link sofort aus der Liste, bei Fehler zurück. Die Datei selbst ist danach weg. */
export function useWithdrawRelease() {
  const queryClient = useQueryClient();
  return useMutation<void, ApiError, string, { before?: Release[] }>({
    mutationFn: (id) => api.del(`/api/admin/releases/${id}`),
    onMutate: async (id) => {
      await queryClient.cancelQueries({ queryKey: RELEASES_KEY });
      const before = queryClient.getQueryData<Release[]>(RELEASES_KEY);
      if (before) {
        queryClient.setQueryData(
          RELEASES_KEY,
          before.map((r) => (r.id === id ? { ...r, withdrawn: true, downloadPath: null } : r)),
        );
      }
      return { before };
    },
    onError: (_err, _id, context) => {
      if (context?.before) queryClient.setQueryData(RELEASES_KEY, context.before);
    },
    onSettled: () => queryClient.invalidateQueries({ queryKey: RELEASES_KEY }),
  });
}
