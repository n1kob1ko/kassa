#!/usr/bin/env bash
# Zusammenspiel von Tablet und Server: startet eine frische Test-Datenbank, baut
# Web und Server, startet den Server auf einem freien Port, legt mit
# server/src/dev/seed.ts einen Betrieb samt Kopplungscode an und lässt die Tests
# in app/test_e2e dagegen laufen. Am Ende (auch nach einem Fehler) sind Server,
# Datenbank und Temp-Ordner weg; ein Cluster, den das Skript nicht gestartet hat,
# bleibt an.
#
# Aufruf: tool/e2e.sh
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
pgbin=/usr/lib/postgresql/16/bin
port_db=54329
db_url="$("$root/server/tool/test-db.sh" url)"
export PATH="$HOME/flutter/bin:$PATH"

# Die Fälle, in denen das Bau-Skript vor dem Bau abbricht (baut nichts).
"$root/tool/test_build_apk.sh"

started_cluster=0
db_name=""
tmp=""
server_pid=""

cleanup() {
  status=$?
  trap - EXIT
  if [ -n "$server_pid" ]; then
    kill "$server_pid" 2>/dev/null || true
    wait "$server_pid" 2>/dev/null || true
  fi
  if [ -n "$db_name" ]; then
    "$pgbin/psql" -q "$db_url" -c "drop database if exists $db_name with (force)" >/dev/null 2>&1 || true
  fi
  if [ -n "$tmp" ]; then rm -rf "$tmp"; fi
  if [ "$started_cluster" = "1" ]; then "$root/server/tool/test-db.sh" stop || true; fi
  exit "$status"
}
trap cleanup EXIT

if ! "$pgbin/pg_isready" -q -h 127.0.0.1 -p "$port_db"; then
  started_cluster=1
  "$root/server/tool/test-db.sh" start
fi

echo "Baue Server und Seiten ..."
(cd "$root" && npm run build --workspace server >/dev/null && npm run build --workspace web >/dev/null)

db_name="kassa_e2e_$(od -An -N6 -tx1 /dev/urandom | tr -d ' \n')"
"$pgbin/psql" -q "$db_url" -c "create database $db_name" >/dev/null
tmp="$(mktemp -d "${TMPDIR:-/tmp}/kassa-e2e-XXXXXX")"

port="$(node -e "const s=require('net').createServer();s.listen(0,'127.0.0.1',()=>{console.log(s.address().port);s.close()})")"
base="http://127.0.0.1:$port"
db_for_server="${db_url%/*}/$db_name"

export DATABASE_URL="$db_for_server"
export APP_DB_PASSWORD="test-app-passwort"
export PORT="$port"
export PUBLIC_URL="$base"
export FILE_DIR="$tmp/files"
export WEB_DIR="$root/web/dist"
export SETUP_TOKEN="e2e-setup-token-0123456789abcdefghij"
export RELEASE_TOKEN="e2e-release-token-0123456789abcdefghi"

(cd "$root" && exec node server/dist/main.js >"$tmp/server.log" 2>&1) &
server_pid=$!

up=0
for _ in $(seq 1 300); do
  if curl -fsS "$base/healthz" >/dev/null 2>&1; then up=1; break; fi
  if ! kill -0 "$server_pid" 2>/dev/null; then break; fi
  sleep 0.1
done
if [ "$up" != "1" ]; then
  echo "Der Server ist nicht gestartet:" >&2
  tail -n 40 "$tmp/server.log" >&2
  exit 1
fi

seed="$(cd "$root/server" && npx tsx src/dev/seed.ts)"
field() { printf '%s' "$seed" | node -e "let s='';process.stdin.on('data',d=>s+=d).on('end',()=>process.stdout.write(String(JSON.parse(s)['$1'])))"; }
code="$(field code)"
cookie="$(field cookie)"
business="$(field businessId)"

cd "$root/app"
flutter test test_e2e \
  --dart-define=E2E_SERVER="$base" \
  --dart-define=E2E_CODE="$code" \
  --dart-define=E2E_COOKIE="$cookie" \
  --dart-define=E2E_BUSINESS="$business"
