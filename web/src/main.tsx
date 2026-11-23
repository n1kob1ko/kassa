import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { StrictMode } from 'react';
import { createRoot } from 'react-dom/client';
import { RouterProvider } from 'react-router/dom';
import { ME_KEY } from './api/auth';
import { ApiError, setUnauthorizedHandler } from './api/client';
import { router } from './routes';
import './styles/tokens.css';
import './styles/base.css';
import './styles/print.css';
import { Toaster } from './ui/Toast';

// Daten bleiben sichtbar, während sie im Hintergrund neu geladen werden (stale-while-revalidate).
const queryClient = new QueryClient({
  defaultOptions: {
    // Eine Antwort des Servers mit Fehler wird nicht wiederholt (der Text sagt, was zu tun ist); ein fehlendes Netz zweimal.
    queries: {
      staleTime: 30_000,
      refetchOnWindowFocus: true,
      retry: (count, err) => err instanceof ApiError && err.code === 'network' && count < 2,
    },
  },
});

// Sitzung abgelaufen oder abgemeldet: zur Anmeldung, danach zurück zur Seite, auf der man war.
setUnauthorizedHandler(() => {
  queryClient.setQueryData(ME_KEY, null);
  const from = router.state.location.pathname;
  void router.navigate('/anmelden', { replace: true, state: { from } });
});

createRoot(document.getElementById('root')!).render(
  <StrictMode>
    <QueryClientProvider client={queryClient}>
      <RouterProvider router={router} />
      <Toaster />
    </QueryClientProvider>
  </StrictMode>,
);
