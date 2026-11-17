#!/usr/bin/env bash
# Installiert die in app/.flutter-version festgelegte Flutter-Version nach ~/flutter.
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
version="$(tr -d '[:space:]' < "$root/app/.flutter-version")"
target="$HOME/flutter"

if [ -x "$target/bin/flutter" ] && "$target/bin/flutter" --version 2>/dev/null | grep -q "Flutter $version"; then
  echo "Flutter $version ist schon installiert."
  exit 0
fi

url="https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_${version}-stable.tar.xz"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

echo "Lade $url"
curl -fsSL --retry 5 --retry-delay 3 -C - -o "$tmp/flutter.tar.xz" "$url"
rm -rf "$target"
tar -xf "$tmp/flutter.tar.xz" -C "$HOME"
echo "Flutter $version installiert in $target."
