import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { api, ApiError } from './client';

export type Role = 'chef' | 'staff';
export type StaffMember = { id: string; name: string; role: Role; archived: boolean };

export const staffKey = (b: string) => ['staff', b] as const;

/** Aktive zuerst, stillgelegte am Ende, je nach Name: wie der Server sortiert. */
export function sortStaff(list: StaffMember[]): StaffMember[] {
  return [...list].sort(
    (x, y) => Number(x.archived) - Number(y.archived) || x.name.localeCompare(y.name, 'de') || x.id.localeCompare(y.id),
  );
}

export function useStaff(b: string) {
  return useQuery<StaffMember[], ApiError>({
    queryKey: staffKey(b),
    queryFn: async () => (await api.get<{ staff: StaffMember[] }>(`/api/admin/businesses/${encodeURIComponent(b)}/staff`)).staff,
  });
}

/** Zeichnet die Liste sofort um und rollt bei einem Fehler zurück. Die Seite zeigt die Meldung des Servers. */
function optimistic(b: string, queryClient: ReturnType<typeof useQueryClient>) {
  return {
    onMutate: async (vars: { id: string; archived?: boolean }) => {
      await queryClient.cancelQueries({ queryKey: staffKey(b) });
      const before = queryClient.getQueryData<StaffMember[]>(staffKey(b));
      if (before) {
        queryClient.setQueryData(
          staffKey(b),
          sortStaff(before.map((s) => (s.id === vars.id ? { ...s, archived: vars.archived ?? s.archived } : s))),
        );
      }
      return { before };
    },
    onError: (_err: unknown, _vars: unknown, context?: { before?: StaffMember[] }) => {
      if (context?.before) queryClient.setQueryData(staffKey(b), context.before);
    },
    onSettled: () => queryClient.invalidateQueries({ queryKey: staffKey(b) }),
  };
}

export function useCreateStaff(b: string) {
  const queryClient = useQueryClient();
  return useMutation<StaffMember, ApiError, { name: string; role: Role; pin: string }>({
    mutationFn: async (body) =>
      (await api.post<{ staff: StaffMember }>(`/api/admin/businesses/${encodeURIComponent(b)}/staff`, body)).staff,
    onSuccess: () => queryClient.invalidateQueries({ queryKey: staffKey(b) }),
  });
}

export function useUpdateStaff(b: string) {
  const queryClient = useQueryClient();
  return useMutation<StaffMember, ApiError, { id: string; name?: string; role?: Role; pin?: string }>({
    mutationFn: async ({ id, ...body }) =>
      (await api.patch<{ staff: StaffMember }>(`/api/admin/businesses/${encodeURIComponent(b)}/staff/${id}`, body)).staff,
    onSuccess: () => queryClient.invalidateQueries({ queryKey: staffKey(b) }),
  });
}

/** Stilllegen und wieder einsetzen: beides dieselbe Schnittstelle, sofort in der Liste, bei Fehler zurück. */
export function useSetArchived(b: string) {
  const queryClient = useQueryClient();
  return useMutation<StaffMember, ApiError, { id: string; archived: boolean }, { before?: StaffMember[] }>({
    mutationFn: async ({ id, archived }) =>
      (await api.patch<{ staff: StaffMember }>(`/api/admin/businesses/${encodeURIComponent(b)}/staff/${id}`, { archived })).staff,
    ...optimistic(b, queryClient),
  });
}
