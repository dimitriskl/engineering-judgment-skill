#!/usr/bin/env bash
# Runs install.sh with the same arguments. A checkout uses the copy beside this file.
# A pipe needs --ref or EJ_REF so install.sh and install/pins.txt can be downloaded together.
set -euo pipefail

src="${BASH_SOURCE[0]:-}"
here=""
if [ -n "$src" ] && [ -f "$src" ]; then
  case "$src" in
    /dev/fd/*|/dev/stdin|/proc/self/fd/*) ;;
    *) here="$(cd "$(dirname "$src")" && pwd)" ;;
  esac
fi
if [ -n "$here" ] && [ -f "$here/install.sh" ] && [ -f "$here/pins.txt" ]; then
  exec bash "$here/install.sh" "$@"
fi

ref="${EJ_REF:-}"
prev=""
for arg in "$@"; do
  if [ "$prev" = "--ref" ]; then ref="$arg"; fi
  prev="$arg"
done
if [ -z "$ref" ]; then
  echo "update.sh was started from a pipe and has no local install/pins.txt." >&2
  echo "Run it from a checkout, or pass --ref <commit-tag-or-branch> (or set EJ_REF)." >&2
  echo "Nothing was installed. Rerunning is safe." >&2
  exit 1
fi

root="${EJ_RAW_ROOT:-https://raw.githubusercontent.com}"
root="${root%/}"
case "$root" in
  http://*|https://*) ;;
  *)
    echo "EJ_RAW_ROOT must start with http:// or https://." >&2
    echo "Nothing was installed. Rerunning is safe." >&2
    exit 1
    ;;
esac
command -v curl >/dev/null 2>&1 || {
  echo "curl is required." >&2
  echo "Nothing was installed. Rerunning is safe." >&2
  exit 1
}

tmp="$(mktemp -d)"
base="${root}/dimitriskl/engineering-judgment-skill/${ref}/install"
fetch() {
  err="$(mktemp)"
  if ! curl -fsSL --connect-timeout 15 --max-time 60 --retry 2 --retry-delay 1 "$1" -o "$2" 2>"$err"; then
    echo "Failed to download $3." >&2
    echo "URL: $1" >&2
    if [ -s "$err" ]; then
      while IFS= read -r line; do printf '  %s\n' "$line" >&2; done < "$err"
    fi
    rm -f "$err"
    echo "Nothing was installed. Rerunning is safe." >&2
    exit 1
  fi
  rm -f "$err"
  if [ ! -s "$2" ]; then
    echo "Failed to download $3: the file was empty." >&2
    echo "URL: $1" >&2
    echo "Nothing was installed. Rerunning is safe." >&2
    exit 1
  fi
}
fetch "$base/install.sh" "$tmp/install.sh" "install/install.sh"
fetch "$base/pins.txt" "$tmp/pins.txt" "install/pins.txt"
fetch "$base/agents.txt" "$tmp/agents.txt" "install/agents.txt"
# exec keeps the temp files for the installer, which reads pins.txt beside itself.
exec bash "$tmp/install.sh" "$@"
