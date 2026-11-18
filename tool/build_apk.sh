#!/usr/bin/env bash
# Baut die Installationsdatei (APK) der Kassa und legt sie als
# kassa-<version>.apk in den Ausgabe-Ordner.
#
# Der Schlüssel zum Signieren liegt außerhalb des Repos. Er muss für jede
# spätere Version derselbe bleiben, sonst lässt sich ein Update nicht über die
# alte Version installieren. Fehlt er, legt dieses Skript ihn einmal an.
#
# Aufruf:
#   tool/build_apk.sh          eine Datei für alle Android-Geräte
#   tool/build_apk.sh arm64    kleinere Datei nur für heutige Tablets und
#                              Telefone (64 Bit ARM), kassa-<version>-arm64.apk
#
#   KASSA_BUILD_DIR   Ordner für Schlüssel und Installationsdatei
#                     (Vorgabe: /mnt/project-files/kassa-build)
#   KASSA_SUMUP_PROPERTIES
#                     Datei mit der Zeile affiliateKey=… für die
#                     Kartenzahlung mit SumUp (Vorgabe:
#                     $KASSA_BUILD_DIR/sumup.properties, falls vorhanden)
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
out="${KASSA_BUILD_DIR:-/mnt/project-files/kassa-build}"
flutter="${FLUTTER_BIN:-$HOME/flutter/bin/flutter}"
export ANDROID_SDK_ROOT="${ANDROID_SDK_ROOT:-$HOME/android-sdk}"

mkdir -p "$out"
key_properties="$out/key.properties"
keystore_name="kassa-test.jks"

if [ ! -f "$key_properties" ]; then
  if [ -f "$out/$keystore_name" ]; then
    echo "Es gibt $out/$keystore_name, aber keine key.properties. Bitte prüfen, nichts überschrieben." >&2
    exit 1
  fi
  echo "Lege einen neuen Test-Schlüssel an in $out"
  password="$(openssl rand -hex 24)"
  keytool -genkeypair -noprompt \
    -keystore "$out/$keystore_name" -storetype PKCS12 \
    -alias kassa -keyalg RSA -keysize 2048 -validity 10000 \
    -storepass "$password" -keypass "$password" \
    -dname "CN=Kassa Test, O=Kassa" >/dev/null 2>&1
  (
    umask 077
    cat > "$key_properties" <<PROPS
storeFile=$keystore_name
storePassword=$password
keyAlias=kassa
keyPassword=$password
PROPS
  )
fi
export KASSA_KEY_PROPERTIES="$key_properties"

# Der SumUp-Schlüssel wird nie ausgegeben, nur die Datei wird genannt.
if [ -z "${KASSA_SUMUP_PROPERTIES:-}" ] && [ -f "$out/sumup.properties" ]; then
  KASSA_SUMUP_PROPERTIES="$out/sumup.properties"
fi
if [ -n "${KASSA_SUMUP_PROPERTIES:-}" ] && [ -f "$KASSA_SUMUP_PROPERTIES" ]; then
  export KASSA_SUMUP_PROPERTIES
  echo "Kartenzahlung mit SumUp: Schlüssel aus $KASSA_SUMUP_PROPERTIES"
elif [ -n "${KASSA_SUMUP_PROPERTIES:-}" ]; then
  echo "$KASSA_SUMUP_PROPERTIES fehlt: Es wird ohne Kartenzahlung gebaut."
  unset KASSA_SUMUP_PROPERTIES
else
  echo "Keine sumup.properties in $out: Es wird ohne Kartenzahlung gebaut."
fi

version="$(sed -n 's/^version: *\([^+ ]*\).*/\1/p' "$root/app/pubspec.yaml")"
if [ -z "$version" ]; then
  echo "Keine Version in app/pubspec.yaml gefunden." >&2
  exit 1
fi

build_args=()
suffix=""
case "${1:-}" in
  "") ;;
  arm64)
    build_args=(--target-platform android-arm64)
    suffix="-arm64"
    ;;
  *)
    echo "Unbekannte Angabe: $1 (erlaubt: arm64)" >&2
    exit 1
    ;;
esac

cd "$root/app"
"$flutter" build apk --release "${build_args[@]}"

apk="$out/kassa-$version$suffix.apk"
cp build/app/outputs/flutter-apk/app-release.apk "$apk"
echo "Installationsdatei: $apk"
