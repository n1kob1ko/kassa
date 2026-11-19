# Kassa-Server

Lokal starten (Node 22, PostgreSQL 16):

1. Aus dem Wurzelordner `npm install`, dann in `server/` weiter.
2. Eine Datenbank anlegen, zum Beispiel `server/tool/test-db.sh start` und `createdb -h 127.0.0.1 -p 54329 -U kassa kassa_dev`.
3. Einstellungen setzen: `DATABASE_URL=postgres://kassa@127.0.0.1:54329/kassa_dev APP_DB_PASSWORD=<frei gewählt> PUBLIC_URL=http://localhost:3000 FILE_DIR=/var/tmp/kassa-dateien`.
4. `npm run dev` startet den Server und legt das Schema selbst an. Kontrolle: `curl localhost:3000/healthz`.
5. Tests: `tool/test-db.sh start && npx vitest run`, dazu `npm run typecheck`.

Die Rolle aus `DATABASE_URL` muss Superuser sein oder BYPASSRLS haben (der Benutzer `postgres` bei Railway ist das). Ihr gehören die Tabellen, und die Funktionen für Geräte-Schlüssel und Kopplungscode laufen mit ihren Rechten, bevor der Betrieb bekannt ist. Sonst würde die Sperre pro Betrieb (FORCE ROW LEVEL SECURITY) ihnen jede Zeile verbergen. `migrate` bricht in diesem Fall mit einer Meldung ab.

`CLIENT_IP_HEADER` (optional, zum Beispiel `x-real-ip` bei Railway) nennt die Kopfzeile, aus der der Server die Adresse des Clients für die Grenze bei falschen Kopplungscodes liest. Nur hinter einem Proxy setzen, der diese Kopfzeile bei jeder Anfrage selbst überschreibt, sonst kann jeder Client sie fälschen und sich so beliebig viele Versuche verschaffen. Ohne Angabe gilt die Adresse der Verbindung.

`WEB_DIR` (optional, zum Beispiel `web/dist` aus dem Wurzelordner) nennt den gebauten Ordner der Verwaltung (`npm run build` in `web/`). Ohne ihn liefert der Server nur die Schnittstelle. Zum Entwickeln der Seiten läuft `npm run dev` in `web/` und leitet `/api` und `/laden` an diesen Server auf Port 3000 weiter.

`FILE_DIR` oder die `S3_`-Variablen (genau eines davon) bestimmen, wo die Installationsdateien liegen. Für einen Bucket: `S3_ENDPOINT`, `S3_BUCKET`, `S3_ACCESS_KEY_ID`, `S3_SECRET_ACCESS_KEY`, `S3_REGION`, dazu optional `S3_URL_STYLE` mit `virtual` (Vorgabe, der Bucket steht im Hostnamen, so arbeiten die Buckets bei Railway) oder `path` (der Bucket steht im Pfad, etwa für eine lokale Nachbildung). Jeder andere Wert bricht den Start ab.

`SETUP_TOKEN` und `RELEASE_TOKEN` (beide optional) müssen mindestens 32 Zeichen lang sein, sonst bricht der Start ab. `PUBLIC_URL` wird auf die Herkunft gekürzt (Schema, Host, Port), ein Pfad oder ein Schrägstrich am Ende stört also nicht. Ist `PUBLIC_URL` eine https-Adresse und `CLIENT_IP_HEADER` nicht gesetzt, schreibt der Server beim Start eine Warnung: Hinter einem Proxy teilen sich dann alle Geräte einen Zähler für Fehlversuche.

## Was Stufe 2 dazubringt

Für den Betrieb des Servers ändert sich mit Stufe 2 (Abgleich, Fotos, Umsätze, Sicherung) Folgendes:

- **Neue Tabellen:** Der Server legt sie beim Start selbst an (Migration `0002_sync.sql`), wie in Stufe 1. Nach dem Ausrollen ist nichts von Hand zu tun.
- **Neue Variablen:** nur `PG_DUMP_PATH` und `BACKUP_DISABLED` (beide optional, siehe unten bei "Sicherung"). Alle anderen bleiben, wie sie in Stufe 1 waren.
- **Ablage:** `FILE_DIR` oder die `S3_`-Variablen gelten jetzt für mehr als die Installationsdateien. Dort liegen auch die Fotos der Artikel und die Logos (unter `businesses/<Betrieb>/files/`, als WebP) und die Sicherungen (unter `backups/`). Die Ablage muss privat bleiben: Der Server liefert Fotos nur an angemeldete Benutzer und gekoppelte Kassen des Betriebs aus, eine Sicherung über gar keine Adresse.
- **Nächtliche Sicherung:** läuft im Dienst selbst, ohne eigenen Lauf bei Railway. Dafür braucht das Abbild `pg_dump` in der Hauptversion der Datenbank oder neuer. Bei Railway ist das PostgreSQL 18, also `pg_dump` 18. Ist es älter, schreibt der Server beim Start einen Hinweis ins Protokoll, und jede Sicherung scheitert. Den Fehler zeigt die Verwaltung dem Anbieter oben auf der Seite "Fehlerberichte" in der Karte "Sicherung".
- **Zeitgrenzen:** Kopfzeilen einer Anfrage müssen binnen 30 Sekunden da sein, eine Verbindung ohne Daten endet nach 60 Sekunden, eine ganze Anfrage darf höchstens 5 Minuten dauern. Das gilt auch für das Hochladen einer Installationsdatei.
- **Koppeln:** Über alle Adressen zusammen nimmt der Server höchstens 200 falsche Kopplungscodes in 15 Minuten an. Danach geht für den Rest dieser Zeit auch ein richtiger Code nicht.
- **Zurückspielen einer Sicherung:** `docs/betrieb/sicherung-zurueckspielen.md`.

## Sicherung

Der Server sichert die Datenbank jede Nacht (nach 3 Uhr Wiener Zeit) mit `pg_dump` in die Ablage, unter `backups/kassa-<Tag>.dump`. Die Dateien der letzten 14 gelungenen Sicherungen bleiben; bei älteren löscht der Server die Datei, die Zeile in der Tabelle `backups` bleibt als Verlauf. Beim Start prüft der Server, ob `pg_dump` mindestens so neu ist wie die Datenbank (sonst steht ein Hinweis im Protokoll); nach einer Minute und dann jede Stunde schaut er, ob eine Sicherung fällig ist.

- `PG_DUMP_PATH` (optional): Pfad zu `pg_dump`. Vorgabe `pg_dump`. Die Hauptversion muss mindestens die der Datenbank sein.
- `BACKUP_DISABLED=1` (optional): schaltet die nächtliche Sicherung ab, etwa in der Entwicklung.
- `DATABASE_URL` muss die Besitzer-Rolle der Datenbank sein (Superuser oder `BYPASSRLS`): Die Tabellen haben Zeilensperren, mit einer anderen Rolle bricht `pg_dump` mit einem Fehler zur Zeilensicherheit ab ("query would be affected by row-level security policy"), und es gibt keine Sicherung. `pg_dump` bekommt die Zugangsdaten über `PG…`-Variablen, nie in der Befehlszeile.
- Fotos und Installationsdateien liegen in der Ablage und gehören nicht zur Sicherung.

Zurückspielen: `docs/betrieb/sicherung-zurueckspielen.md`. Der Anbieter sieht den Stand unter `GET /api/admin/backups/latest`.
