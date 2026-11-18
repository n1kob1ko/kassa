# Kassa-Server

Lokal starten (Node 22, PostgreSQL 16):

1. Aus dem Wurzelordner `npm install`, dann in `server/` weiter.
2. Eine Datenbank anlegen, zum Beispiel `server/tool/test-db.sh start` und `createdb -h 127.0.0.1 -p 54329 -U kassa kassa_dev`.
3. Einstellungen setzen: `DATABASE_URL=postgres://kassa@127.0.0.1:54329/kassa_dev APP_DB_PASSWORD=<frei gewählt> PUBLIC_URL=http://localhost:3000 FILE_DIR=/var/tmp/kassa-dateien`.
4. `npm run dev` startet den Server und legt das Schema selbst an. Kontrolle: `curl localhost:3000/healthz`.
5. Tests: `tool/test-db.sh start && npx vitest run`, dazu `npm run typecheck`.
