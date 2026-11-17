#!/usr/bin/env bash
# Installiert die Android-Werkzeuge, die `flutter build apk` braucht, nach
# ~/android-sdk. Braucht Zugriff auf dl.google.com und ein JDK (17 oder neuer).
set -euo pipefail

sdk="${ANDROID_SDK_ROOT:-$HOME/android-sdk}"
# Nummer der Kommandozeilenwerkzeuge, siehe
# https://developer.android.com/studio#command-line-tools-only
cmdline_tools_build="${ANDROID_CMDLINE_TOOLS_BUILD:-13114758}"
# Was die Flutter-Version aus app/.flutter-version verlangt
# (packages/flutter_tools/gradle/src/main/kotlin/FlutterExtension.kt).
platform="platforms;android-36"
build_tools="build-tools;36.0.0"
ndk="ndk;28.2.13676358"

flutter="${FLUTTER_BIN:-$HOME/flutter/bin/flutter}"
if [ ! -x "$flutter" ]; then
  echo "Flutter fehlt. Zuerst tool/setup_flutter.sh ausführen." >&2
  exit 1
fi

sdkmanager="$sdk/cmdline-tools/latest/bin/sdkmanager"
if [ ! -x "$sdkmanager" ]; then
  url="https://dl.google.com/android/repository/commandlinetools-linux-${cmdline_tools_build}_latest.zip"
  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' EXIT
  echo "Lade $url"
  curl -fsSL --retry 5 --retry-delay 3 -o "$tmp/cmdline-tools.zip" "$url"
  mkdir -p "$tmp/unpacked" "$sdk/cmdline-tools"
  unzip -q "$tmp/cmdline-tools.zip" -d "$tmp/unpacked"
  rm -rf "$sdk/cmdline-tools/latest"
  mv "$tmp/unpacked/cmdline-tools" "$sdk/cmdline-tools/latest"
fi

# Hinter einem Proxy braucht sdkmanager die Angabe ausdrücklich.
proxy_args=()
proxy="${HTTPS_PROXY:-${https_proxy:-}}"
if [ -n "$proxy" ]; then
  hostport="${proxy#*://}"
  hostport="${hostport%%/*}"
  hostport="${hostport##*@}"
  proxy_args=(--proxy=http "--proxy_host=${hostport%%:*}" "--proxy_port=${hostport##*:}")
fi

echo "Nehme die Lizenzen an"
yes 2>/dev/null | "$sdkmanager" --sdk_root="$sdk" "${proxy_args[@]}" --licenses >/dev/null || true

echo "Installiere $platform, $build_tools, platform-tools, $ndk"
"$sdkmanager" --sdk_root="$sdk" "${proxy_args[@]}" \
  "platform-tools" "$platform" "$build_tools" "$ndk"

"$flutter" config --android-sdk "$sdk" >/dev/null
"$flutter" doctor
echo "Android-Werkzeuge installiert in $sdk."
