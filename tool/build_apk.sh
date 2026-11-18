#!/usr/bin/env bash
# Baut die Installationsdatei (APK) der Kassa und legt sie als
# kassa-<version>.apk in den Ausgabe-Ordner.
#
# Der Schlüssel zum Signieren liegt außerhalb des Repos. Er muss für jede
# spätere Version derselbe bleiben, sonst lässt sich ein Update nicht über die
# alte Version installieren. Fehlt key.properties, bricht das Skript ab; einen
# neuen Schlüssel legt es nur mit KASSA_NEW_KEY=1 an. Steht in key.properties
# eine Zeile certSha256=<SHA-256 des Zertifikats>, prüft das Skript die
# gebaute Datei damit und legt sie nur ab, wenn sie passt.
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
#                     $KASSA_BUILD_DIR/sumup.properties)
#   KASSA_ALLOW_NO_SUMUP=1
#                     ohne SumUp-Schlüssel bauen (die Datei hat dann keine
#                     Kartenzahlung)
#   KASSA_NEW_KEY=1   einen neuen Test-Schlüssel anlegen, wenn keiner da ist
set -euo pipefail

# Relative Angaben gelten ab dem Ordner, in dem das Skript aufgerufen wird.
absolute() {
  case "$1" in
    /*) printf '%s\n' "$1" ;;
    *) printf '%s\n' "$PWD/$1" ;;
  esac
}

root="$(cd "$(dirname "$0")/.." && pwd)"
out="$(absolute "${KASSA_BUILD_DIR:-/mnt/project-files/kassa-build}")"
flutter="${FLUTTER_BIN:-$HOME/flutter/bin/flutter}"
export ANDROID_SDK_ROOT="${ANDROID_SDK_ROOT:-$HOME/android-sdk}"

mkdir -p "$out"
key_properties="$out/key.properties"
keystore_name="kassa-test.jks"

if [ ! -f "$key_properties" ]; then
  if [ "${KASSA_NEW_KEY:-}" != "1" ]; then
    {
      echo "Keine key.properties in $out."
      echo "Ohne den bisherigen Schlüssel lässt sich die neue Version nicht über die installierte installieren."
      echo "Bitte key.properties und den Schlüssel in diesen Ordner legen."
      echo "Nur für ein ganz neues Gerät ohne Kassa: KASSA_NEW_KEY=1 legt einen neuen Schlüssel an."
    } >&2
    exit 1
  fi
  if [ -f "$out/$keystore_name" ]; then
    echo "Es gibt $out/$keystore_name, aber keine key.properties. Bitte prüfen, nichts überschrieben." >&2
    exit 1
  fi
  echo "Lege einen neuen Test-Schlüssel an in $out (KASSA_NEW_KEY=1)"
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
if [ -n "${KASSA_SUMUP_PROPERTIES:-}" ]; then
  KASSA_SUMUP_PROPERTIES="$(absolute "$KASSA_SUMUP_PROPERTIES")"
  if [ ! -f "$KASSA_SUMUP_PROPERTIES" ]; then
    echo "KASSA_SUMUP_PROPERTIES zeigt auf $KASSA_SUMUP_PROPERTIES, die Datei fehlt." >&2
    exit 1
  fi
elif [ -f "$out/sumup.properties" ]; then
  KASSA_SUMUP_PROPERTIES="$out/sumup.properties"
fi
if [ -n "${KASSA_SUMUP_PROPERTIES:-}" ]; then
  export KASSA_SUMUP_PROPERTIES
  echo "Kartenzahlung mit SumUp: Schlüssel aus $KASSA_SUMUP_PROPERTIES"
elif [ "${KASSA_ALLOW_NO_SUMUP:-}" = "1" ]; then
  unset KASSA_SUMUP_PROPERTIES
  echo "Diese Installationsdatei hat keine Kartenzahlung (keine sumup.properties, KASSA_ALLOW_NO_SUMUP=1)."
else
  {
    echo "Keine sumup.properties in $out: Ohne sie hat die Installationsdatei keine Kartenzahlung."
    echo "Bitte die Datei mit der Zeile affiliateKey=… dort ablegen, oder bewusst ohne Kartenzahlung bauen: KASSA_ALLOW_NO_SUMUP=1."
  } >&2
  exit 1
fi

version="$(sed -n 's/^version: *\([^+ ]*\).*/\1/p' "$root/app/pubspec.yaml")"
if [ -z "$version" ]; then
  echo "Keine Version in app/pubspec.yaml gefunden." >&2
  exit 1
fi

# Erwartetes Zertifikat: SHA-256 in Kleinbuchstaben ohne Doppelpunkte, leer,
# wenn key.properties keine Zeile certSha256= hat.
expected_cert="$(sed -n 's/^certSha256=//p' "$key_properties" | head -n 1 | tr -d ' :\r' | tr 'A-F' 'a-f')"

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
built="build/app/outputs/flutter-apk/app-release.apk"

# Die Signatur der gebauten Datei: nur das Zertifikat, nie der Schlüssel.
apksigner="$(ls -d "$ANDROID_SDK_ROOT"/build-tools/*/apksigner 2>/dev/null | sort -V | tail -n 1 || true)"
if [ -z "$apksigner" ]; then
  if [ -n "$expected_cert" ]; then
    echo "apksigner nicht gefunden: Die Signatur lässt sich nicht prüfen. Die Datei wird nicht abgelegt." >&2
    exit 1
  fi
  echo "apksigner nicht gefunden: Die Signatur wurde nicht geprüft."
else
  if ! certs="$("$apksigner" verify --print-certs "$built" 2>&1)"; then
    echo "Die gebaute Datei ist nicht gültig signiert. Sie wird nicht abgelegt." >&2
    exit 1
  fi
  actual_cert="$(printf '%s\n' "$certs" | sed -n 's/^Signer #1 certificate SHA-256 digest: *//p' | head -n 1 | tr -d ' :' | tr 'A-F' 'a-f')"
  echo "Zertifikat (SHA-256): $actual_cert"
  if [ -n "$expected_cert" ]; then
    if [ "$actual_cert" != "$expected_cert" ]; then
      {
        echo "Die Datei ist mit einem anderen Schlüssel signiert als erwartet."
        echo "Erwartet (certSha256 in key.properties): $expected_cert"
        echo "Sie ließe sich nicht über die installierte Kassa installieren und wird nicht abgelegt."
      } >&2
      exit 1
    fi
    echo "Die Signatur passt zu certSha256 in key.properties."
  else
    echo "In key.properties steht keine Zeile certSha256=: Die Signatur wurde nicht verglichen."
  fi
fi

apk="$out/kassa-$version$suffix.apk"
cp "$built" "$apk"
echo "Installationsdatei: $apk"
