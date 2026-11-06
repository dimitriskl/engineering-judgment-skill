#!/usr/bin/env bash
# Update using the same scope and behavior as the installer.
set -euo pipefail
RAW="${EJ_RAW:-https://raw.githubusercontent.com/dimitriskl/engineering-judgment-skill/main}"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
if [ -f "$RAW/install/install.sh" ]; then
  cp "$RAW/install/install.sh" "$TMP/install.sh"
else
  curl -fsSL "$RAW/install/install.sh" -o "$TMP/install.sh"
fi
bash "$TMP/install.sh" "$@"
