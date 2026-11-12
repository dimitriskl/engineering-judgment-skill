#!/usr/bin/env bash
# Installs or updates the mydevfactory skill and all of the author's agents (Linux and macOS).
#   curl -fsSL https://raw.githubusercontent.com/dimitriskl/mydevfactory/main/install/install.sh | bash
# The first run asks where to install; later runs reuse that answer and update everything in place.
# Change the answer with:  ... | bash -s -- --scope personal   (or --scope project)
set -euo pipefail

OWNER="dimitriskl"
RAW="${EJ_RAW:-https://raw.githubusercontent.com/$OWNER/mydevfactory/main}"
STATE_DIR="$HOME/.engineering-judgment"
STATE_FILE="$STATE_DIR/install-scope"
SCOPE="${EJ_SCOPE:-}"

while [ $# -gt 0 ]; do
  case "$1" in
    --scope) SCOPE="${2:-}"; shift 2 ;;
    *) echo "Unknown option: $1" >&2; exit 2 ;;
  esac
done

command -v curl >/dev/null || { echo "curl is required." >&2; exit 1; }
command -v npx >/dev/null || { echo "Node.js 22.20 or later is required (npx not found): https://nodejs.org" >&2; exit 1; }

# --- Scope: ask once, then remember -------------------------------------------------
if [ -z "$SCOPE" ] && [ -f "$STATE_FILE" ]; then SCOPE="$(cat "$STATE_FILE")"; fi
if [ -z "$SCOPE" ]; then
  echo "Where should the skill and agents be installed?"
  echo "  1) personal - all your projects (~/.claude, ~/.codex)   [default]"
  echo "  2) project  - only this folder: $(pwd)"
  answer=""
  if [ -r /dev/tty ]; then read -r -p "Choose 1 or 2: " answer </dev/tty || true; fi
  case "$answer" in 2|project) SCOPE="project" ;; *) SCOPE="personal" ;; esac
fi
case "$SCOPE" in personal|project) ;; *) echo "Scope must be personal or project, not '$SCOPE'." >&2; exit 2 ;; esac
mkdir -p "$STATE_DIR" && echo "$SCOPE" > "$STATE_FILE"

if [ "$SCOPE" = "personal" ]; then BASE="$HOME"; GLOBAL="-g"; else BASE="$(pwd)"; GLOBAL=""; fi
echo "Scope: $SCOPE ($BASE). Run again with --scope personal|project to change it."

# --- 1. Skill (npx skills add installs or updates) -----------------------------------
echo "Skill: mydevfactory"
npx -y skills add "$OWNER/mydevfactory" --skill mydevfactory -a claude-code codex $GLOBAL -y </dev/null

# --- 2. Agents: install, or update when the published file changed ------------------
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
mkdir -p "$BASE/.claude/agents" "$BASE/.codex/agents"
place() { # place <downloaded file> <target>: install, update (keeping a .bak of the old file) or leave as is
  if [ ! -f "$2" ]; then cp "$1" "$2"; echo "    installed  $2"
  elif cmp -s "$1" "$2"; then echo "    up to date $2"
  else cp "$2" "$2.bak"; cp "$1" "$2"; echo "    updated    $2 (old file: $2.bak)"; fi
}
curl -fsSL "$RAW/install/agents.txt" | tr -d '\r' | grep -v '^[[:space:]]*#' | grep -v '^[[:space:]]*$' > "$TMP/agents.txt"
while read -r agent; do
  echo "Agent: $agent"
  repo="https://raw.githubusercontent.com/$OWNER/$agent/main"
  curl -fsSL "$repo/.claude/agents/$agent.md" -o "$TMP/$agent.md"
  curl -fsSL "$repo/.codex/agents/$agent.toml" -o "$TMP/$agent.toml"
  place "$TMP/$agent.md" "$BASE/.claude/agents/$agent.md"
  place "$TMP/$agent.toml" "$BASE/.codex/agents/$agent.toml"
done < "$TMP/agents.txt"

# --- 3. Auto-compact at 40% (only added when not set; your own values are kept) -----
mkdir -p "$BASE/.claude" "$BASE/.codex"
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

# --- 4. Agent mapping for the skill -------------------------------------------------
if [ "$SCOPE" = "project" ]; then
  if [ -f ".engineering-workflow.json" ]; then echo "Config: .engineering-workflow.json kept as is"
  else curl -fsSL "$RAW/.engineering-workflow.json" -o ".engineering-workflow.json"; echo "Config: .engineering-workflow.json added"; fi
else
  echo "Config: in each project root, add .engineering-workflow.json:"
  echo "  curl -fsSL $RAW/.engineering-workflow.json -o .engineering-workflow.json"
fi

echo "Done. Start a new Claude Code or Codex session to use the updated skill and agents."
