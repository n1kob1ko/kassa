#!/usr/bin/env bash
# Lässt das Prüfwerkzeug des Finanzministeriums über ein Protokoll laufen, das
# die Kassa mit der Attrappe der Signatur erzeugt
# (app/test/rksv/pruefwerkzeug_test.dart). Das Werkzeug selbst liegt nicht im
# Repo.
#
# Aufruf: tool/rksv/pruefen.sh [Ordner des Prüfwerkzeugs]
set -euo pipefail

root="$(cd "$(dirname "$0")/../.." && pwd)"
dir="${1:-/mnt/project-files/kassa-build/rksv/pruefwerkzeug/regkassen-verification-1.1.1}"

if [ ! -f "$dir/regkassen-verification-depformat-1.1.1.jar" ]; then
  echo "Das Prüfwerkzeug fehlt unter $dir." >&2
  exit 1
fi

export KASSA_RKSV_TOOL="$dir"
export PATH="$HOME/flutter/bin:$PATH"
cd "$root/app"
flutter test test/rksv/pruefwerkzeug_test.dart
