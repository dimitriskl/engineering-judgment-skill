#!/usr/bin/env bash
# Installs or updates the mydevfactory skill and the pinned agents (Linux and macOS).
# From a checkout:  bash install/install.sh
# From a pipe:      curl -fsSL <raw>/install/install.sh | bash -s -- --ref <commit-tag-or-branch>
# Pins: install/pins.txt (full commit SHAs). --ref / EJ_REF overrides only the hub ref.
# Change scope with --scope personal|project or EJ_SCOPE. Project scope sticks to that folder.
set -euo pipefail

OWNER="dimitriskl"
RAW_ROOT="${EJ_RAW_ROOT:-https://raw.githubusercontent.com}"
RAW_ROOT="${RAW_ROOT%/}"
SCOPE="${EJ_SCOPE:-}"
REF_OVERRIDE="${EJ_REF:-}"
EXPLICIT_SCOPE=0
if [ -n "$SCOPE" ]; then EXPLICIT_SCOPE=1; fi

die() {
  code="$1"
  shift
  printf '%s\n' "$*" >&2
  exit "$code"
}

usage() {
  cat <<'EOF'
Usage: install.sh [--scope personal|project] [--ref <commit-tag-or-branch>]

Installs the mydevfactory skill and the agents pinned in install/pins.txt.
Personal scope is remembered for your user account. Project scope is remembered only in that folder.

  --scope personal|project   where to install (or set EJ_SCOPE)
  --ref <ref>                hub commit, tag, or branch for this run (or set EJ_REF)
  EJ_PINS                    path to an alternate pins file
  EJ_RAW_ROOT                raw download host (default https://raw.githubusercontent.com)
EOF
}

require_node() {
  if ! command -v node >/dev/null 2>&1; then
    die 1 "Node.js 22.20 or later is required, but node was not found.
Install Node.js 22.20 or newer from https://nodejs.org and run this installer again.
Nothing was installed. Rerunning is safe."
  fi
  if ! command -v npx >/dev/null 2>&1; then
    die 1 "Node.js 22.20 or later is required, but npx was not found.
Install Node.js 22.20 or newer from https://nodejs.org and run this installer again.
Nothing was installed. Rerunning is safe."
  fi
  ver="$(node -v 2>/dev/null | tr -d '\r\n' || true)"
  if [[ ! "$ver" =~ ^v([0-9]+)\.([0-9]+)(\.[0-9]+)?$ ]]; then
    die 1 "Node.js 22.20 or later is required. Could not read the version from node -v (got: ${ver:-nothing}).
Install Node.js 22.20 or newer from https://nodejs.org and run this installer again.
Nothing was installed. Rerunning is safe."
  fi
  major="${BASH_REMATCH[1]}"
  minor="${BASH_REMATCH[2]}"
  if [ "$major" -lt 22 ] || { [ "$major" -eq 22 ] && [ "$minor" -lt 20 ]; }; then
    die 1 "Node.js 22.20 or later is required. Found ${ver}.
Install Node.js 22.20 or newer from https://nodejs.org and run this installer again.
Nothing was installed. Rerunning is safe."
  fi
}

require_curl() {
  command -v curl >/dev/null 2>&1 || die 1 "curl is required.
Nothing was installed. Rerunning is safe."
}

urlencode() {
  # Percent-encode every byte except RFC 3986 unreserved characters.
  s="$1"
  out=""
  i=0
  while [ "$i" -lt "${#s}" ]; do
    c="${s:$i:1}"
    case "$c" in
      [A-Za-z0-9._~-]) out="${out}${c}" ;;
      *)
        printf -v hex '%%%02X' "'$c"
        out="${out}${hex}"
        ;;
    esac
    i=$((i + 1))
  done
  printf '%s' "$out"
}

resolve_hub_ref_api() {
  ref="$1"
  require_curl
  encoded="$(urlencode "$ref")"
  body="$(mktemp)"
  url="https://api.github.com/repos/${OWNER}/mydevfactory/commits/${encoded}"
  if ! curl -fsSL --connect-timeout 15 --max-time 60 \
      -H "Accept: application/vnd.github+json" \
      -H "User-Agent: mydevfactory-install" \
      -o "$body" "$url"; then
    rm -f "$body"
    die 1 "Could not resolve hub ref '${ref}'.
Pass a tag or a 40-character commit SHA.
Nothing was installed. Rerunning is safe."
  fi
  sha="$(awk -F'"' '/"sha":/ { print $4; exit }' "$body")"
  rm -f "$body"
  if printf '%s\n' "$sha" | grep -Eq '^[0-9a-fA-F]{40}$'; then
    printf '%s\n' "$sha"
    return 0
  fi
  die 1 "Could not resolve hub ref '${ref}'.
Pass a tag or a 40-character commit SHA.
Nothing was installed. Rerunning is safe."
}

# A branch or tag becomes the commit SHA before any URL is built. A 40-character
# SHA is kept as given. Slash branches otherwise look like a branch plus a path
# to the skills CLI (it would clone the branch named before the first slash).
resolve_hub_ref() {
  ref="$1"
  if printf '%s\n' "$ref" | grep -Eq '^[0-9a-fA-F]{40}$'; then
    printf '%s\n' "$ref"
    return 0
  fi
  case "$ref" in
    *[!A-Za-z0-9._/-]*|/*|*/|*//*|..|../*|*/..|*/../*)
      die 1 "Hub ref '${ref}' is not a full commit SHA, tag, or branch name.
Pass a tag or a 40-character commit SHA.
Nothing was installed. Rerunning is safe."
      ;;
  esac
  if ! command -v git >/dev/null 2>&1; then
    resolve_hub_ref_api "$ref"
    return 0
  fi
  remote="https://github.com/${OWNER}/mydevfactory.git"
  set +e
  listing="$(git ls-remote "$remote" "refs/heads/${ref}" "refs/tags/${ref}" "refs/tags/${ref}^{}" 2>&1)"
  status=$?
  set -e
  if [ "$status" -ne 0 ]; then
    die 1 "Could not resolve hub ref '${ref}'.
${listing}
Pass a tag or a 40-character commit SHA.
Nothing was installed. Rerunning is safe."
  fi
  branch_sha=""
  tag_sha=""
  peeled=""
  while IFS="$(printf '\t')" read -r sha name; do
    [ -z "${sha:-}" ] && continue
    case "$name" in
      "refs/heads/${ref}") branch_sha="$sha" ;;
      "refs/tags/${ref}") tag_sha="$sha" ;;
      "refs/tags/${ref}^{}") peeled="$sha" ;;
    esac
  done <<EOF
$listing
EOF
  tag_commit="$tag_sha"
  if [ -n "$peeled" ]; then tag_commit="$peeled"; fi
  if [ -n "$branch_sha" ] && [ -n "$tag_commit" ] && [ "$branch_sha" != "$tag_commit" ]; then
    die 1 "Hub ref '${ref}' matches both a branch (${branch_sha}) and a tag (${tag_commit}).
Pass the full commit SHA you want.
Nothing was installed. Rerunning is safe."
  fi
  if [ -n "$tag_commit" ]; then
    printf '%s\n' "$tag_commit"
    return 0
  fi
  if [ -n "$branch_sha" ]; then
    printf '%s\n' "$branch_sha"
    return 0
  fi
  die 1 "Could not resolve hub ref '${ref}'. It is not a branch or tag on https://github.com/${OWNER}/mydevfactory.
Pass a tag or a 40-character commit SHA.
Nothing was installed. Rerunning is safe."
}

# The skills CLI checks the skill out with git. Force LF so a Windows
# core.autocrlf=true setting does not change the installed bytes.
use_lf_checkout() {
  idx="${GIT_CONFIG_COUNT:-0}"
  case "$idx" in
    ''|*[!0-9]*) idx=0 ;;
  esac
  export "GIT_CONFIG_KEY_${idx}=core.autocrlf"
  export "GIT_CONFIG_VALUE_${idx}=false"
  idx=$((idx + 1))
  export "GIT_CONFIG_KEY_${idx}=core.eol"
  export "GIT_CONFIG_VALUE_${idx}=lf"
  idx=$((idx + 1))
  export GIT_CONFIG_COUNT="$idx"
}

download() {
  url="$1"
  dest="$2"
  label="$3"
  err="$(mktemp)"
  if ! curl -fsSL --connect-timeout 15 --max-time 60 --retry 2 --retry-delay 1 "$url" -o "$dest" 2>"$err"; then
    printf 'Failed to download %s.\n' "$label" >&2
    printf 'URL: %s\n' "$url" >&2
    if [ -s "$err" ]; then
      while IFS= read -r line; do printf '  %s\n' "$line" >&2; done < "$err"
    fi
    rm -f "$err" "$dest"
    echo "Nothing was installed. Rerunning is safe." >&2
    exit 1
  fi
  rm -f "$err"
  if [ ! -s "$dest" ]; then
    printf 'Failed to download %s: the file was empty.\n' "$label" >&2
    printf 'URL: %s\n' "$url" >&2
    echo "Nothing was installed. Rerunning is safe." >&2
    exit 1
  fi
}

trim_line() {
  line="$1"
  line="${line%%#*}"
  line="$(printf '%s' "$line" | tr -d '\r')"
  line="${line#"${line%%[![:space:]]*}"}"
  line="${line%"${line##*[![:space:]]}"}"
  printf '%s' "$line"
}

backup_path() {
  target="$1"
  stamp="$(date -u +%Y%m%d-%H%M%S)"
  candidate="${target}.bak-${stamp}"
  n=2
  while [ -e "$candidate" ]; do
    candidate="${target}.bak-${stamp}-${n}"
    n=$((n + 1))
  done
  printf '%s\n' "$candidate"
}

place_file() {
  src="$1"
  dest="$2"
  mkdir -p "$(dirname "$dest")"
  if [ ! -f "$dest" ]; then
    cp "$src" "$dest"
    printf '    installed  %s\n' "$dest"
    return
  fi
  if cmp -s "$src" "$dest"; then
    printf '    up to date %s\n' "$dest"
    return
  fi
  bak="$(backup_path "$dest")"
  cp "$dest" "$bak"
  cp "$src" "$dest"
  printf '    updated    %s (old file: %s)\n' "$dest" "$bak"
}

while [ $# -gt 0 ]; do
  case "$1" in
    --scope)
      if [ $# -lt 2 ] || [ -z "${2:-}" ] || [[ "$2" == -* ]]; then
        usage >&2
        die 2 "Missing value for --scope.
Nothing was installed. Rerunning is safe."
      fi
      SCOPE="$2"
      EXPLICIT_SCOPE=1
      shift 2
      ;;
    --ref)
      if [ $# -lt 2 ] || [ -z "${2:-}" ] || [[ "$2" == -* ]]; then
        usage >&2
        die 2 "Missing value for --ref.
Nothing was installed. Rerunning is safe."
      fi
      REF_OVERRIDE="$2"
      shift 2
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      usage >&2
      die 2 "Unknown option: $1
Nothing was installed. Rerunning is safe."
      ;;
  esac
done

# Node is checked before scope is saved and before any download or npx call.
require_node

if [ -n "${EJ_RAW:-}" ]; then
  die 1 "EJ_RAW is no longer used. Set EJ_REF to a commit, tag, or branch, or set EJ_PINS to a pins file.
Nothing was installed. Rerunning is safe."
fi
case "$RAW_ROOT" in
  http://*|https://*) ;;
  *) die 1 "EJ_RAW_ROOT must start with http:// or https://.
Nothing was installed. Rerunning is safe." ;;
esac
if [ -z "${HOME:-}" ]; then
  die 1 "HOME is not set, so the installer cannot find your user directory.
Nothing was installed. Rerunning is safe."
fi

script_dir=""
src="${BASH_SOURCE[0]:-}"
if [ -n "$src" ] && [ -f "$src" ]; then
  case "$src" in
    /dev/fd/*|/dev/stdin|/proc/self/fd/*) ;;
    *) script_dir="$(cd "$(dirname "$src")" && pwd)" ;;
  esac
fi

workdir="$(mktemp -d)"
trap 'rm -rf "$workdir"' EXIT

ORIGINAL_REF="$REF_OVERRIDE"
if [ -n "$REF_OVERRIDE" ]; then
  REF_OVERRIDE="$(resolve_hub_ref "$REF_OVERRIDE")"
fi

pins_file=""
agents_file=""
if [ -n "${EJ_PINS:-}" ]; then
  pins_file="$EJ_PINS"
  if [ ! -f "$pins_file" ]; then
    die 1 "Pins file not found: ${EJ_PINS}
Nothing was installed. Rerunning is safe."
  fi
elif [ -n "$script_dir" ] && [ -f "$script_dir/pins.txt" ]; then
  pins_file="$script_dir/pins.txt"
  agents_file="$script_dir/agents.txt"
else
  if [ -z "$REF_OVERRIDE" ]; then
    die 1 "This installer was started from a pipe and has no local install/pins.txt.
Run bash install/install.sh from a checkout, or pass --ref <commit-tag-or-branch> (or set EJ_REF) so install/pins.txt can be downloaded.
Nothing was installed. Rerunning is safe."
  fi
  require_curl
  base="${RAW_ROOT}/${OWNER}/mydevfactory/${REF_OVERRIDE}/install"
  download "$base/pins.txt" "$workdir/pins.txt" "install/pins.txt"
  download "$base/agents.txt" "$workdir/agents.txt" "install/agents.txt"
  pins_file="$workdir/pins.txt"
  agents_file="$workdir/agents.txt"
  script_dir="$workdir"
fi

HUB_NAME=""
HUB_SHA=""
: > "$workdir/agent-pins.tsv"
: > "$workdir/seen-names"
line_no=0
while IFS= read -r raw_line || [ -n "$raw_line" ]; do
  line_no=$((line_no + 1))
  line="$(trim_line "$raw_line")"
  [ -z "$line" ] && continue
  kind="" name="" sha="" extra=""
  # shellcheck disable=SC2229
  read -r kind name sha extra <<EOF
$line
EOF
  if [ -z "$kind" ] || [ -z "$name" ] || [ -z "$sha" ] || [ -n "$extra" ]; then
    die 1 "install/pins.txt:${line_no} must be: hub|agent <repo> <40-character sha>
Nothing was installed. Rerunning is safe."
  fi
  if ! [[ "$name" =~ ^[A-Za-z0-9._-]+$ ]]; then
    die 1 "install/pins.txt:${line_no} has an invalid repository name '${name}'.
Nothing was installed. Rerunning is safe."
  fi
  if ! [[ "$sha" =~ ^[0-9a-fA-F]{40}$ ]]; then
    die 1 "Pin for ${name} must be a full 40-character commit SHA, not '${sha}'. Branches and tags are not pins.
Nothing was installed. Rerunning is safe."
  fi
  if [ "$kind" = "hub" ]; then
    if [ -n "$HUB_NAME" ]; then
      die 1 "install/pins.txt has more than one hub line.
Nothing was installed. Rerunning is safe."
    fi
    HUB_NAME="$name"
    HUB_SHA="$sha"
  elif [ "$kind" = "agent" ]; then
    if grep -qx "$name" "$workdir/seen-names"; then
      die 1 "install/pins.txt lists ${name} more than once.
Nothing was installed. Rerunning is safe."
    fi
    printf '%s\n' "$name" >> "$workdir/seen-names"
    printf '%s\t%s\n' "$name" "$sha" >> "$workdir/agent-pins.tsv"
  else
    die 1 "install/pins.txt:${line_no} has an unknown kind '${kind}'. Use hub or agent.
Nothing was installed. Rerunning is safe."
  fi
done < "$pins_file"

if [ -z "$HUB_SHA" ]; then
  die 1 "install/pins.txt has no hub line.
Nothing was installed. Rerunning is safe."
fi
if [ ! -s "$workdir/agent-pins.tsv" ]; then
  die 1 "install/pins.txt has no agent lines.
Nothing was installed. Rerunning is safe."
fi

if [ -z "${EJ_PINS:-}" ]; then
  if [ -z "$agents_file" ] || [ ! -f "$agents_file" ]; then
    die 1 "Missing install/agents.txt beside the pins file.
Nothing was installed. Rerunning is safe."
  fi
  : > "$workdir/agent-names.txt"
  while IFS= read -r raw_line || [ -n "$raw_line" ]; do
    line="$(trim_line "$raw_line")"
    [ -z "$line" ] && continue
    printf '%s\n' "$line" >> "$workdir/agent-names.txt"
  done < "$agents_file"
  sort "$workdir/seen-names" > "$workdir/pins-sorted.txt"
  sort "$workdir/agent-names.txt" > "$workdir/list-sorted.txt"
  if [ -n "$(uniq -d "$workdir/pins-sorted.txt")" ] || [ -n "$(uniq -d "$workdir/list-sorted.txt")" ]; then
    die 1 "install/pins.txt and install/agents.txt must list each agent once.
Nothing was installed. Rerunning is safe."
  fi
  if ! cmp -s "$workdir/pins-sorted.txt" "$workdir/list-sorted.txt"; then
    die 1 "install/pins.txt and install/agents.txt list different agents.
Nothing was installed. Rerunning is safe."
  fi
fi

# Scope is chosen before downloads. It is written only after a successful install.
reason="chosen"
if [ "$EXPLICIT_SCOPE" -eq 0 ]; then
  cwd_marker="$(pwd)/.engineering-judgment/install-scope"
  global_file="$HOME/.engineering-judgment/install-scope"
  if [ -f "$cwd_marker" ]; then
    marker_value="$(tr -d '\r\n' < "$cwd_marker")"
    if [ "$marker_value" != "project" ]; then
      die 2 "Project scope file ${cwd_marker} must contain project, not '${marker_value}'.
Nothing was installed. Rerunning is safe."
    fi
    SCOPE="project"
    reason="remembered-project"
  elif [ -f "$global_file" ]; then
    global_value="$(tr -d '\r\n' < "$global_file")"
    if [ "$global_value" = "personal" ]; then
      SCOPE="personal"
      reason="remembered-personal"
    elif [ "$global_value" = "project" ]; then
      die 2 "A previous install remembered project scope for every folder. Project scope now applies only to the folder it was installed in.
Nothing was installed. Run again in that project with --scope project, or choose a personal install with --scope personal.
Rerunning is safe."
    else
      die 2 "Scope must be personal or project, not '${global_value}'.
Nothing was installed. Rerunning is safe."
    fi
  else
    answer=""
    if { exec 3<>/dev/tty; } 2>/dev/null; then
      interactive=0
      if [ -t 3 ]; then interactive=1; fi
      exec 3<&-
      if [ "$interactive" -eq 1 ]; then
        echo "Where should the skill and agents be installed?"
        echo "  1) personal - all your projects (~/.agents, ~/.claude, ~/.codex)   [default]"
        echo "  2) project  - only this folder: $(pwd)"
        if ! read -r -p "Choose 1 or 2: " answer </dev/tty 2>/dev/null; then
          answer=""
        fi
        case "$answer" in
          2|project) SCOPE="project" ;;
          *) SCOPE="personal" ;;
        esac
        reason="chosen"
      else
        SCOPE="personal"
        reason="default"
      fi
    else
      SCOPE="personal"
      reason="default"
    fi
  fi
fi
case "$SCOPE" in
  personal|project) ;;
  *) die 2 "Scope must be personal or project, not '${SCOPE}'.
Nothing was installed. Rerunning is safe." ;;
esac

if [ "$SCOPE" = "personal" ]; then BASE="$HOME"; else BASE="$(pwd)"; fi
case "$reason" in
  default)
    echo "Scope: personal ($BASE). No saved choice and no terminal, so the default is personal. Run again with --scope personal or --scope project to change it."
    ;;
  remembered-personal)
    echo "Scope: personal ($BASE). Remembered for your user account. Run again with --scope personal or --scope project to change it."
    ;;
  remembered-project)
    echo "Scope: project ($BASE). Remembered for this folder only. Run again with --scope personal or --scope project to change it."
    ;;
  *)
    echo "Scope: $SCOPE ($BASE). Run again with --scope personal or --scope project to change it."
    ;;
esac

if [ -n "$REF_OVERRIDE" ]; then
  HUB_REF="$REF_OVERRIDE"
  if [ "$ORIGINAL_REF" = "$REF_OVERRIDE" ]; then
    echo "Hub: ${HUB_NAME} @ ${HUB_REF} (--ref override; pin file says ${HUB_SHA})"
  else
    echo "Hub: ${HUB_NAME} @ ${HUB_REF} (--ref ${ORIGINAL_REF} resolved; pin file says ${HUB_SHA})"
  fi
else
  HUB_REF="$HUB_SHA"
  echo "Hub: ${HUB_NAME} @ ${HUB_REF}"
  if [ -n "$script_dir" ] && command -v git >/dev/null 2>&1; then
    head_sha="$(git -C "$script_dir" rev-parse HEAD 2>/dev/null || true)"
    if [ -n "$head_sha" ] && [ "$head_sha" != "$HUB_SHA" ]; then
      echo "Note: hub pin is ${HUB_SHA}. This checkout is ${head_sha}. The installer uses the pin. Pass --ref to install a different hub commit." >&2
    fi
  fi
fi

require_curl
hub_raw="${RAW_ROOT}/${OWNER}/${HUB_NAME}/${HUB_REF}"
while IFS=$'\t' read -r name sha; do
  [ -z "$name" ] && continue
  download "${RAW_ROOT}/${OWNER}/${name}/${sha}/.claude/agents/${name}.md" \
    "$workdir/${name}.md" "${name} .claude/agents/${name}.md"
  download "${RAW_ROOT}/${OWNER}/${name}/${sha}/.codex/agents/${name}.toml" \
    "$workdir/${name}.toml" "${name} .codex/agents/${name}.toml"
done < "$workdir/agent-pins.tsv"
download "${hub_raw}/.engineering-workflow.json" "$workdir/workflow.json" ".engineering-workflow.json"

skill_url="https://github.com/${OWNER}/${HUB_NAME}/tree/${HUB_REF}"
echo "Skill: mydevfactory @ ${HUB_REF}"
global_flag=""
if [ "$SCOPE" = "personal" ]; then global_flag="-g"; fi
use_lf_checkout
set +e
npx -y skills add "$skill_url" --skill mydevfactory -a claude-code codex $global_flag -y </dev/null
status=$?
set -e
if [ "$status" -ne 0 ]; then
  die 1 "Skill install failed (npx exit code ${status}).
Source: ${skill_url}
No agent files were written. Rerunning is safe."
fi

while IFS=$'\t' read -r name sha; do
  [ -z "$name" ] && continue
  echo "Agent: ${name} @ ${sha}"
  place_file "$workdir/${name}.md" "$BASE/.claude/agents/${name}.md"
  place_file "$workdir/${name}.toml" "$BASE/.codex/agents/${name}.toml"
done < "$workdir/agent-pins.tsv"

if [ "$SCOPE" = "project" ]; then
  if [ -f "$BASE/.engineering-workflow.json" ]; then
    echo "Config: .engineering-workflow.json kept as is"
  else
    cp "$workdir/workflow.json" "$BASE/.engineering-workflow.json"
    echo "Config: .engineering-workflow.json added"
  fi
fi

mkdir -p "$BASE/.claude" "$BASE/.codex"
set +e
node - "$BASE/.claude/settings.json" "$BASE/.codex/config.toml" <<'NODE'
const fs = require("fs");
const [settingsPath, tomlPath] = process.argv.slice(2);
let s = {};
if (fs.existsSync(settingsPath)) s = JSON.parse(fs.readFileSync(settingsPath, "utf8") || "{}");
s.env = s.env || {};
if (s.env.CLAUDE_AUTOCOMPACT_PCT_OVERRIDE === undefined) {
  s.env.CLAUDE_AUTOCOMPACT_PCT_OVERRIDE = "40";
  fs.writeFileSync(settingsPath, JSON.stringify(s, null, 2) + "\n");
  console.log(`Claude Code: auto-compact at 40% set in ${settingsPath}`);
} else console.log(`Claude Code: auto-compact already set (${s.env.CLAUDE_AUTOCOMPACT_PCT_OVERRIDE}) in ${settingsPath}`);
let t = fs.existsSync(tomlPath) ? fs.readFileSync(tomlPath, "utf8") : "";
if (/^\s*model_auto_compact_token_limit\s*=/m.test(t)) {
  console.log(`Codex: model_auto_compact_token_limit already set in ${tomlPath}`);
} else {
  // Top-level keys must come before the first [table], or TOML puts them inside that table.
  const line = "model_auto_compact_token_limit = 160000  # 40% of a 400,000-token context window\n";
  const i = t.search(/^[ \t]*\[/m);
  const pre = (i < 0 ? t : t.slice(0, i)).replace(/\s+$/, "");
  t = (pre ? pre + "\n" : "") + line + (i < 0 ? "" : "\n" + t.slice(i));
  fs.writeFileSync(tomlPath, t);
  console.log(`Codex: auto-compact at 160000 tokens set in ${tomlPath}`);
}
NODE
status=$?
set -e
if [ "$status" -ne 0 ]; then
  die 1 "Failed while writing auto-compact settings.
Agent files are already in place. Rerunning is safe."
fi

if [ "$SCOPE" = "project" ]; then
  mkdir -p "$BASE/.engineering-judgment"
  printf '%s\n' project > "$BASE/.engineering-judgment/install-scope"
  global_file="$HOME/.engineering-judgment/install-scope"
  if [ -f "$global_file" ] && [ "$(tr -d '\r\n' < "$global_file")" = "project" ]; then
    rm -f "$global_file"
  fi
else
  mkdir -p "$HOME/.engineering-judgment"
  printf '%s\n' personal > "$HOME/.engineering-judgment/install-scope"
  if [ "$EXPLICIT_SCOPE" -eq 1 ]; then
    cwd_marker="$(pwd)/.engineering-judgment/install-scope"
    if [ -f "$cwd_marker" ]; then rm -f "$cwd_marker"; fi
  fi
fi

if [ "$SCOPE" = "personal" ]; then
  echo "Config: in each project root, add .engineering-workflow.json:"
  echo "  curl -fsSL ${hub_raw}/.engineering-workflow.json -o .engineering-workflow.json"
fi

echo "Done. Start a new Claude Code or Codex session to use the updated skill and agents."
