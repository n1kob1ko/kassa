# Das Abbild des Servers mit der Verwaltung im Browser.
#
# Stufe 1 baut Server (TypeScript) und Seiten (Vite) und lässt danach nur die
# Pakete zurück, die der Server zum Laufen braucht. Stufe 2 nimmt davon nur,
# was läuft: kein Quelltext, keine Tests, nichts von der App, den Dokumenten
# oder dem Pilotbetrieb (siehe .dockerignore).
#
# Gebaut wird vom Wurzelordner des Repos aus: docker build -t kassa-server .
# Der Dienst liest alle Einstellungen aus der Umgebung (siehe server/README.md):
# DATABASE_URL, APP_DB_PASSWORD, PUBLIC_URL, FILE_DIR oder S3_*, SETUP_TOKEN,
# RELEASE_TOKEN und bei Bedarf CLIENT_IP_HEADER.
#
# FILE_DIR, falls verwendet, muss ein Volume sein, in das der Benutzer `node`
# schreiben darf (der Dienst läuft unten als `node`, nicht als root). Beim
# geplanten Hosting liegen die Dateien im Bucket (S3_*), nicht in FILE_DIR.

FROM node:22-slim AS build
WORKDIR /app

# Zuerst nur die Paketlisten: solange sie gleich bleiben, bleibt npm ci im Zwischenspeicher.
COPY package.json package-lock.json ./
COPY server/package.json server/
COPY web/package.json web/
RUN npm ci

COPY server server
COPY web web
RUN npm run build --workspace server \
 && npm run build --workspace web \
 # Entwicklungs-Pakete weg: neu installieren, nur das, was der Server braucht.
 && rm -rf node_modules server/node_modules web/node_modules \
 && npm ci --omit=dev --workspace server

FROM node:22-slim
WORKDIR /app
ENV NODE_ENV=production \
    PORT=3000 \
    WEB_DIR=/app/web/dist

# pg_dump für die nächtliche Sicherung. Es muss mindestens so neu sein wie die
# Datenbank (PostgreSQL 18). Debian selbst liefert eine ältere Fassung, darum
# kommt das Paket aus dem Paketverzeichnis von PostgreSQL (apt.postgresql.org).
# Die letzte Zeile lässt den Bau scheitern, wenn pg_dump danach nicht startet.
# Dieser Schritt steht vor dem Code, damit eine Änderung am Code ihn nicht neu lädt.
RUN apt-get update \
 && apt-get install -y --no-install-recommends ca-certificates postgresql-common \
 && /usr/share/postgresql-common/pgdg/apt.postgresql.org.sh -y \
 && apt-get install -y --no-install-recommends postgresql-client-18 \
 && rm -rf /var/lib/apt/lists/* \
 && pg_dump --version

# Direkt das Programm von Version 18, nicht der Wrapper von postgresql-common.
ENV PG_DUMP_PATH=/usr/lib/postgresql/18/bin/pg_dump

# server/package.json gehört dazu: "type": "module" macht aus dist/*.js Module.
COPY --from=build /app/node_modules node_modules
COPY --from=build /app/server/package.json server/package.json
COPY --from=build /app/server/dist server/dist
COPY --from=build /app/server/migrations server/migrations
COPY --from=build /app/web/dist web/dist

USER node
EXPOSE 3000
HEALTHCHECK --interval=30s --timeout=5s --start-period=30s \
  CMD node -e "fetch('http://127.0.0.1:'+process.env.PORT+'/healthz').then(r=>process.exit(r.ok?0:1),()=>process.exit(1))"
CMD ["node", "server/dist/main.js"]
