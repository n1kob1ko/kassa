#!/usr/bin/env bash
# Prüft die Fälle, in denen tool/build_apk.sh vor dem Bau abbricht. Es wird
# nichts gebaut und kein echter Schlüssel angefasst: alles geschieht in einem
# Temp-Ordner mit einer Platzhalter-key.properties.
#
# Aufruf: tool/test_build_apk.sh
set -uo pipefail

script="$(cd "$(dirname "$0")" && pwd)/build_apk.sh"
tmp="$(mktemp -d "${TMPDIR:-/tmp}/kassa-build-test-XXXXXX")"
trap 'rm -rf "$tmp"' EXIT
failures=0

# Der Wert steht nur hier im Test und ist erfunden.
secret="https://geheim.example.invalid"

fresh() {
  rm -rf "$tmp/build"
  mkdir -p "$tmp/build"
  printf 'storeFile=x.jks\nstorePassword=x\nkeyAlias=x\nkeyPassword=x\n' > "$tmp/build/key.properties"
}

# expect_refusal <Name> <Text, der in der Meldung stehen muss> [VAR=Wert ...]
expect_refusal() {
  local name="$1" needle="$2"
  shift 2
  local out status
  out="$(env KASSA_BUILD_DIR="$tmp/build" FLUTTER_BIN=/nonexistent "$@" "$script" 2>&1)"
  status=$?
  if [ "$status" -eq 0 ] || [[ "$out" != *"$needle"* ]]; then
    echo "FEHLER: $name (Ende $status)"
    printf '%s\n' "$out" | sed 's/^/  /'
    failures=$((failures + 1))
  elif [[ "$out" == *"$secret"* || "$out" == *"geheim.example"* ]]; then
    echo "FEHLER: $name gibt die Adresse aus"
    failures=$((failures + 1))
  else
    echo "ok: $name"
  fi
}

fresh
expect_refusal "ohne server.properties" "Keine Adresse des Servers" KASSA_ALLOW_NO_SUMUP=1

fresh
printf 'serverUrl=\n' > "$tmp/build/server.properties"
expect_refusal "leerer Wert" "Keine Adresse des Servers" KASSA_ALLOW_NO_SUMUP=1

fresh
printf 'andere=1\n' > "$tmp/build/server.properties"
expect_refusal "Datei ohne serverUrl" "Keine Adresse des Servers" KASSA_ALLOW_NO_SUMUP=1

fresh
printf 'serverUrl=http://geheim.example.invalid\n' > "$tmp/build/server.properties"
expect_refusal "Adresse ohne https" "https://" KASSA_ALLOW_NO_SUMUP=1

fresh
printf 'serverUrl=https://\n' > "$tmp/build/server.properties"
expect_refusal "nur https:// ohne Rechner" "https://" KASSA_ALLOW_NO_SUMUP=1

fresh
expect_refusal "KASSA_SERVER_PROPERTIES zeigt ins Leere" "die Datei fehlt" \
  KASSA_ALLOW_NO_SUMUP=1 KASSA_SERVER_PROPERTIES="$tmp/gibt-es-nicht.properties"

fresh
printf 'serverUrl=%s\n' "$secret" > "$tmp/build/server.properties"
expect_refusal "ohne sumup.properties (Adresse ist da)" "Keine sumup.properties"

# Mit allen Angaben läuft das Skript bis zum Bau: ohne Flutter bricht es dort
# ab, nicht vorher. Die Adresse steht dabei nicht in der Ausgabe.
fresh
printf 'serverUrl=%s\n' "$secret" > "$tmp/build/server.properties"
out="$(env KASSA_BUILD_DIR="$tmp/build" KASSA_ALLOW_NO_SUMUP=1 FLUTTER_BIN=/nonexistent "$script" 2>&1)"
if [[ "$out" == *"Server: Adresse aus"* && "$out" != *"geheim.example"* ]]; then
  echo "ok: gültige Adresse wird angenommen und nicht ausgegeben"
else
  echo "FEHLER: gültige Adresse"
  printf '%s\n' "$out" | sed 's/^/  /'
  failures=$((failures + 1))
fi

fresh
out="$(env KASSA_BUILD_DIR="$tmp/build" KASSA_ALLOW_NO_SUMUP=1 KASSA_ALLOW_NO_SERVER=1 FLUTTER_BIN=/nonexistent "$script" 2>&1)"
if [[ "$out" == *"keinen Server"* ]]; then
  echo "ok: KASSA_ALLOW_NO_SERVER=1 baut ohne Server"
else
  echo "FEHLER: KASSA_ALLOW_NO_SERVER=1"
  printf '%s\n' "$out" | sed 's/^/  /'
  failures=$((failures + 1))
fi

if [ "$failures" -ne 0 ]; then
  echo "$failures Fehler"
  exit 1
fi
echo "Alle Fälle bestehen."
