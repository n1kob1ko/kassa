import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { api, ApiError } from './client';
import { BUSINESSES_KEY } from './businesses';

export type Register = {
  id: string;
  name: string;
  pairedAt: string;
  lastSeenAt: string | null;
  appVersion: string | null;
  deviceModel: string | null;
  blocked: boolean;
};

export type PairingCode = { code: string; expiresAt: string };

export const registersKey = (b: string) => ['registers', b] as const;

/** Solange `pollMs` gesetzt ist (Kopplungsdialog offen), lädt die Liste in diesem Takt neu. */
export function useRegisters(b: string, pollMs?: number) {
  return useQuery<Register[], ApiError>({
    queryKey: registersKey(b),
    queryFn: async () =>
      (await api.get<{ registers: Register[] }>(`/api/admin/businesses/${encodeURIComponent(b)}/registers`)).registers,
    refetchInterval: pollMs ?? false,
  });
}

export function useCreatePairingCode(b: string) {
  return useMutation<PairingCode, ApiError, string>({
    mutationFn: (name) => api.post<PairingCode>(`/api/admin/businesses/${encodeURIComponent(b)}/pairing-codes`, { name }),
  });
}

/** Sperren und Sperre aufheben: sofort in der Liste, bei Fehler zurück. */
export function useSetBlocked(b: string) {
  const queryClient = useQueryClient();
  return useMutation<Register, ApiError, { id: string; blocked: boolean }, { before?: Register[] }>({
    mutationFn: async ({ id, blocked }) =>
      (
        await api.post<{ register: Register }>(
          `/api/admin/businesses/${encodeURIComponent(b)}/registers/${id}/${blocked ? 'block' : 'unblock'}`,
        )
      ).register,
    onMutate: async ({ id, blocked }) => {
      await queryClient.cancelQueries({ queryKey: registersKey(b) });
      const before = queryClient.getQueryData<Register[]>(registersKey(b));
      if (before) queryClient.setQueryData(registersKey(b), before.map((r) => (r.id === id ? { ...r, blocked } : r)));
      return { before };
    },
    onError: (_err, _vars, context) => {
      if (context?.before) queryClient.setQueryData(registersKey(b), context.before);
    },
    onSettled: async () => {
      await Promise.all([
        queryClient.invalidateQueries({ queryKey: registersKey(b) }),
        queryClient.invalidateQueries({ queryKey: BUSINESSES_KEY }),
      ]);
    },
  });
}
