import { useRef } from 'react';
import { useLocation, useMatch, useNavigate, type To } from 'react-router';

/** Kommt man aus der Liste (Klick auf eine Zeile), trägt der Eintrag im Verlauf das: Schließen ist dann "Zurück". */
type FromList = { fromList?: boolean } | null;

/**
 * Ein Detail mit eigener Adresse über einer Liste (`/b/:b/bons/:id`). Die Parameter der Liste (Filter) bleiben in der
 * Adresse des Details. Schließen geht zurück im Verlauf, wenn man aus der Liste kam (dieselbe Stelle, derselbe Filter),
 * sonst (Neuladen, Link von außen) ersetzt es die Adresse durch die der Liste.
 */
export function useDetailRoute(listPath: string) {
  const location = useLocation();
  const navigate = useNavigate();
  const match = useMatch(`${listPath}/:id`);
  const id = match?.params.id ?? null;
  // Die zuletzt offene Kennung: nach dem Schließen geht der Fokus zu ihrer Zeile.
  const lastId = useRef<string | null>(null);
  if (id) lastId.current = id;
  const fromList = (location.state as FromList)?.fromList === true;

  /** Weg zum Detail mit den Parametern der Liste. */
  const detailTo = (detailId: string): To => ({
    pathname: `${listPath}/${encodeURIComponent(detailId)}`,
    search: location.search,
  });

  const close = () => {
    if (fromList) navigate(-1);
    else navigate({ pathname: listPath, search: location.search }, { replace: true });
  };

  /** Die Zeile der zuletzt offenen Kennung, für den Fokus nach dem Schließen. */
  const rowOf = () =>
    lastId.current ? document.querySelector<HTMLElement>(`[data-row-id="${CSS.escape(lastId.current)}"]`) : null;

  return { id, detailTo, close, rowOf, fromListState: { fromList: true }, currentState: location.state as FromList };
}
