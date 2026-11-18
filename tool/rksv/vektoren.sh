#!/usr/bin/env bash
# Erzeugt app/test/rksv/fixtures/mustercode_vectors.json neu: Vergleichswerte
# aus dem Mustercode des Finanzministeriums. Braucht Java und die Bibliotheken
# des Prüfwerkzeugs (nicht im Repo). Ort: erster Parameter oder KASSA_RKSV_LIB.
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
lib="${1:-${KASSA_RKSV_LIB:-/mnt/project-files/kassa-build/rksv/pruefwerkzeug/regkassen-verification-1.1.1/lib}}"
if ! ls "$lib"/regkassen-common-*.jar >/dev/null 2>&1; then
  echo "Die Bibliotheken des Prüfwerkzeugs fehlen unter $lib." >&2
  exit 1
fi
cp="$(ls "$lib"/*.jar | tr '\n' ':')"
out="$(mktemp -d)"
trap 'rm -rf "$out"' EXIT
JAVA_TOOL_OPTIONS= javac -cp "$cp" -d "$out" "$here/Vektoren.java" 2>/dev/null
JAVA_TOOL_OPTIONS= java -cp "$cp$out" Vektoren 2>/dev/null \
  > "$here/../../app/test/rksv/fixtures/mustercode_vectors.json"
echo "Geschrieben: app/test/rksv/fixtures/mustercode_vectors.json"
