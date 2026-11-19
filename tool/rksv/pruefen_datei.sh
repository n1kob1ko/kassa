#!/usr/bin/env bash
# Lässt das Prüfwerkzeug des Finanzministeriums über zwei fertige Dateien
# laufen, etwa die aus dem Lauf "atrust-testsystem"
# (app/test/rksv/online/atrust_testsystem_test.dart, Schritt 6). Das Werkzeug
# selbst liegt nicht im Repo.
#
# Endet mit Fehler, wenn das Werkzeug scheitert oder in einer Ergebnisdatei
# der oberste verificationState nicht PASS ist.
#
# Aufruf: tool/rksv/pruefen_datei.sh <dep-export.json>
#           <cryptographicMaterialContainer.json> [Ordner des Prüfwerkzeugs]
set -euo pipefail

if [ $# -lt 2 ] || [ $# -gt 3 ]; then
  echo "Aufruf: $0 <dep-export.json> <cryptographicMaterialContainer.json> [Ordner des Prüfwerkzeugs]" >&2
  exit 2
fi

dep="$1"
crypto="$2"
dir="${3:-/mnt/project-files/kassa-build/rksv/pruefwerkzeug/regkassen-verification-1.1.1}"
jar="$dir/regkassen-verification-depformat-1.1.1.jar"

for f in "$dep" "$crypto"; do
  if [ ! -f "$f" ]; then
    echo "Die Datei $f fehlt." >&2
    exit 1
  fi
done
if [ ! -f "$jar" ]; then
  echo "Das Prüfwerkzeug fehlt unter $dir." >&2
  exit 1
fi

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
cp "$dep" "$work/dep-export.json"
cp "$crypto" "$work/cryptographicMaterialContainer.json"

status=0
(
  cd "$work"
  JAVA_TOOL_OPTIONS='' java -jar "$jar" -v -f \
    -i dep-export.json -c cryptographicMaterialContainer.json -o aus
) >"$work/ausgabe.txt" 2>&1 || status=$?

echo "Prüfwerkzeug: Ausgang $status, letzte Zeilen:"
tail -n 20 "$work/ausgabe.txt"
echo
if [ "$status" -ne 0 ]; then
  echo "Das Prüfwerkzeug ist gescheitert." >&2
  exit 1
fi

python3 -I -u - "$work/aus" <<'EOF'
import json
import pathlib
import sys

out = pathlib.Path(sys.argv[1])
files = sorted(out.glob("*.json")) if out.is_dir() else []
if not files:
    print("Keine Ergebnisdatei.", file=sys.stderr)
    sys.exit(1)
bad = 0
for f in files:
    try:
        state = json.loads(f.read_text(encoding="utf-8", errors="replace")).get(
            "verificationState"
        )
    except (ValueError, AttributeError):
        state = "nicht lesbar"
    if state != "PASS":
        bad += 1
    print(f"{f.name}: {state}")
print()
if bad:
    print(f"{bad} von {len(files)} Ergebnisdateien nicht PASS.", file=sys.stderr)
    sys.exit(1)
print(f"Alle {len(files)} Ergebnisdateien PASS.")
EOF
