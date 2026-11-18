#!/usr/bin/env bash
# Test-Datenbank für den Server: ein eigener PostgreSQL-Cluster auf Port 54329.
# Aufruf: tool/test-db.sh start|stop|url
set -euo pipefail

BIN=/usr/lib/postgresql/16/bin
DIR=/var/tmp/kassa-test-pg
PORT=54329

# Als root darf postgres nicht laufen, dann übernimmt der Benutzer "postgres".
as_pg() {
  if [ "$(id -u)" -eq 0 ]; then
    su postgres -c "$1"
  else
    bash -c "$1"
  fi
}

running() {
  as_pg "$BIN/pg_ctl -D $DIR/data status" >/dev/null 2>&1
}

case "${1:-}" in
  start)
    if running; then exit 0; fi
    if [ ! -d "$DIR/data" ]; then
      mkdir -p "$DIR"
      if [ "$(id -u)" -eq 0 ]; then chown postgres:postgres "$DIR"; fi
      chmod 700 "$DIR"
      as_pg "$BIN/initdb -D $DIR/data -U kassa --auth=trust -E UTF8" >/dev/null
    fi
    as_pg "$BIN/pg_ctl -D $DIR/data -o '-p $PORT -k $DIR -c listen_addresses=127.0.0.1' -l $DIR/log -w start" >/dev/null
    ;;
  stop)
    if running; then as_pg "$BIN/pg_ctl -D $DIR/data -m fast -w stop" >/dev/null; fi
    ;;
  url)
    echo "postgres://kassa@127.0.0.1:$PORT/postgres"
    ;;
  *)
    echo "Aufruf: tool/test-db.sh start|stop|url" >&2
    exit 2
    ;;
esac
