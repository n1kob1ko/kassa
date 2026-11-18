import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { createElement, type ReactNode } from 'react';
import { Navigate, useLocation, useNavigate } from 'react-router';
import { Button } from '../ui/Button';
import { EmptyState } from '../ui/EmptyState';
import { Skeleton } from '../ui/Skeleton';
import { api, ApiError } from './client';

export type User = {
  id: string;
  email: string;
  role: 'provider' | 'chef';
  businessId: string | null;
};

export const ME_KEY = ['me'] as const;

/** Wohin es nach der Anmeldung geht, wenn niemand ein anderes Ziel genannt hat. */
export const HOME = '/betriebe';

/** Ziel nach der Anmeldung: nur eigene Seitenadressen, nie eine fremde Adresse und nie die Anmeldeseiten. */
export function afterLoginPath(from: unknown): string {
  if (typeof from !== 'string' || !from.startsWith('/') || from.startsWith('//')) return HOME;
  if (from === '/' || from.startsWith('/anmelden') || from.startsWith('/einrichten')) return HOME;
  return from;
}

/** Der angemeldete Benutzer, `null` ohne Sitzung. Andere Fehler (kein Netz) kommen als `error`. */
export function useMe() {
  return useQuery<User | null, ApiError>({
    queryKey: ME_KEY,
    queryFn: async () => {
      try {
        return (await api.get<{ user: User }>('/api/auth/me')).user;
      } catch (err) {
        if (err instanceof ApiError && err.status === 401) return null;
        throw err;
      }
    },
    staleTime: 60_000,
    retry: (count, err) => err.code === 'network' && count < 2,
  });
}

/** Wächter einer Route: ohne Anmeldung weiter zu /anmelden, danach zurück hierher. */
export function RequireUser({ children }: { children: ReactNode }) {
  const me = useMe();
  const location = useLocation();
  if (me.data === null) {
    return createElement(Navigate, { to: '/anmelden', replace: true, state: { from: location.pathname } });
  }
  if (me.data === undefined && me.isError) {
    return createElement(EmptyState, {
      title: 'Der Server antwortet nicht',
      text: me.error.message,
      action: createElement(Button, { variant: 'secondary', onClick: () => void me.refetch() }, 'Nochmal versuchen'),
    });
  }
  if (me.data === undefined) return createElement(Skeleton, { lines: 4, label: 'Anmeldung wird geprüft' });
  return children;
}

export function useLogin() {
  const queryClient = useQueryClient();
  return useMutation<User, ApiError, { email: string; password: string }>({
    mutationFn: async (body) => (await api.post<{ user: User }>('/api/auth/login', body)).user,
    onSuccess: (user) => queryClient.setQueryData(ME_KEY, user),
  });
}

export function useLogout() {
  const queryClient = useQueryClient();
  const navigate = useNavigate();
  return useMutation<void, ApiError>({
    mutationFn: () => api.post<void>('/api/auth/logout'),
    onSuccess: async () => {
      await navigate('/anmelden', { replace: true });
      queryClient.clear();
      queryClient.setQueryData(ME_KEY, null);
    },
  });
}

/** Prüft den Einmal-Schlüssel aus dem Link, ohne ihn zu verbrauchen. */
export function useSetupToken(token: string) {
  return useQuery<boolean, ApiError>({
    queryKey: ['setup-token', token],
    queryFn: async () =>
      token === '' ? false : (await api.get<{ valid: boolean }>(`/api/auth/setup?token=${encodeURIComponent(token)}`)).valid,
    staleTime: Infinity,
    retry: false,
  });
}

export function useSetup() {
  const queryClient = useQueryClient();
  return useMutation<User, ApiError, { token: string; email: string; password: string }>({
    // 201 für ein neues Konto, 200 wenn das Passwort eines bestehenden Anbieters neu gesetzt wird.
    mutationFn: async (body) => (await api.post<{ user: User }>('/api/auth/setup', body)).user,
    onSuccess: (user) => queryClient.setQueryData(ME_KEY, user),
  });
}
