#!/usr/bin/env bash
# End-to-end tests for install/install.sh and install/update.sh.
# Uses disposable HOME and project directories. Network calls use install/pins.txt.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
INSTALL="$ROOT/install/install.sh"
UPDATE="$ROOT/install/update.sh"
PINS="$ROOT/install/pins.txt"
NPM_CACHE="${NPM_CACHE:-${TMPDIR:-/tmp}/ej-npm-cache}"
mkdir -p "$NPM_CACHE"
ORIG_PATH="$PATH"
PASSES=0
FAILS=0
LAST_STATUS=0

hub_sha() { awk '$1=="hub" { print $3; exit }' "$PINS"; }
agent_sha() { awk -v n="$1" '$1=="agent" && $2==n { print $3; exit }' "$PINS"; }

ok() { echo "PASS: $*"; PASSES=$((PASSES + 1)); }
bad() { echo "FAIL: $*"; FAILS=$((FAILS + 1)); }

show() {
  echo "----- stdout -----"
  cat "$1"
  echo "----- stderr -----"
  cat "$2"
}

launch() {
  local home="$1" cwd="$2" out="$3" err="$4"
  shift 4
  mkdir -p "$home" "$cwd"
  set +e
  (
    cd "$cwd" || exit 97
    export HOME="$home" USERPROFILE="$home"
    export npm_config_cache="$NPM_CACHE"
    export npm_config_update_notifier=false
    export GIT_TERMINAL_PROMPT=0
    unset EJ_SCOPE EJ_REF EJ_PINS EJ_RAW EJ_RAW_ROOT EJ_NODE_MARKER EJ_GIT_LOG
    "$@"
  ) >"$out" 2>"$err"
  LAST_STATUS=$?
  set -e
}

assert_status() {
  local name="$1" expected="$2" out="$3" err="$4"
  if [ "$LAST_STATUS" -eq "$expected" ]; then
    ok "$name"
  else
    bad "$name (exit $LAST_STATUS, expected $expected)"
    show "$out" "$err"
  fi
}

assert_grep() {
  local file="$1" pattern="$2" name="$3"
  if grep -q "$pattern" "$file"; then
    ok "$name"
  else
    bad "$name (missing /$pattern/)"
    show "${file%/*}/stdout.txt" "${file%/*}/stderr.txt" 2>/dev/null || cat "$file"
  fi
}

assert_no_grep() {
  local file="$1" pattern="$2" name="$3"
  if grep -q "$pattern" "$file"; then
    bad "$name (found /$pattern/)"
    cat "$file"
  else
    ok "$name"
  fi
}

clean_tree() {
  local dir="$1" name="$2"
  local hit
  hit="$(find "$dir" -mindepth 1 \( -name .claude -o -name .codex -o -name .agents -o -name .engineering-judgment -o -name .engineering-workflow.json -o -name skills-lock.json -o -name .skill-lock.json \) -print 2>/dev/null || true)"
  if [ -n "$hit" ]; then
    bad "$name (unexpected install files)"
    printf '%s\n' "$hit"
  else
    ok "$name"
  fi
}

new_case() {
  CASE="$(mktemp -d)"
  HOME_DIR="$CASE/home"
  WORK="$CASE/work"
  OUT="$CASE/stdout.txt"
  ERR="$CASE/stderr.txt"
  mkdir -p "$HOME_DIR" "$WORK"
}

# --- argument and pin failures (no network install) ---------------------------------

new_case
launch "$HOME_DIR" "$WORK" "$OUT" "$ERR" bash "$INSTALL" --scope
assert_status "missing --scope value exits 2" 2 "$OUT" "$ERR"
assert_grep "$ERR" "Missing value for --scope" "missing --scope explains the flag"
assert_grep "$ERR" "Usage:" "missing --scope prints usage"
clean_tree "$HOME_DIR" "missing --scope writes nothing in HOME"
clean_tree "$WORK" "missing --scope writes nothing in the folder"

new_case
launch "$HOME_DIR" "$WORK" "$OUT" "$ERR" bash "$INSTALL" --scope sideways
assert_status "bad --scope exits 2" 2 "$OUT" "$ERR"
assert_grep "$ERR" "Scope must be personal or project, not 'sideways'" "bad --scope names the value"

new_case
launch "$HOME_DIR" "$WORK" "$OUT" "$ERR" env EJ_RAW="https://example.invalid/raw" bash "$INSTALL" --scope personal
assert_status "EJ_RAW is rejected" 1 "$OUT" "$ERR"
assert_grep "$ERR" "EJ_RAW is no longer used" "EJ_RAW tells you what to set instead"
clean_tree "$HOME_DIR" "EJ_RAW writes nothing"

new_case
shim="$CASE/shim"
marker="$CASE/marker"
mkdir -p "$shim"
cat > "$shim/node" <<'EOF'
#!/bin/sh
if [ "${1:-}" = "-v" ]; then
  printf '%s\n' "v18.20.4"
  exit 0
fi
if [ -n "${EJ_NODE_MARKER:-}" ]; then printf '%s\n' "node $*" > "$EJ_NODE_MARKER"; fi
printf '%s\n' "SyntaxError: The requested module 'node:util' does not provide an export named 'styleText'" >&2
printf '%s\n' "npm warn EBADENGINE unsupported engine" >&2
exit 1
EOF
cat > "$shim/npx" <<'EOF'
#!/bin/sh
if [ -n "${EJ_NODE_MARKER:-}" ]; then printf '%s\n' "npx $*" > "$EJ_NODE_MARKER"; fi
printf '%s\n' "SyntaxError: The requested module 'node:util' does not provide an export named 'styleText'" >&2
printf '%s\n' "npm warn EBADENGINE unsupported engine" >&2
exit 1
EOF
chmod +x "$shim/node" "$shim/npx"
launch "$HOME_DIR" "$WORK" "$OUT" "$ERR" env PATH="$shim:$ORIG_PATH" EJ_NODE_MARKER="$marker" bash "$INSTALL" --scope personal
assert_status "Node 18 exits 1" 1 "$OUT" "$ERR"
assert_grep "$ERR" "Node.js 22.20 or later is required. Found v18.20.4." "Node 18 names the installed version"
assert_grep "$ERR" "https://nodejs.org" "Node 18 tells you where to install Node"
assert_grep "$ERR" "Nothing was installed. Rerunning is safe." "Node 18 says rerunning is safe"
assert_no_grep "$ERR" "styleText" "Node 18 does not reach the skills CLI stack trace"
assert_no_grep "$OUT" "styleText" "Node 18 stdout has no skills CLI stack trace"
if [ -e "$marker" ]; then
  bad "Node 18 invoked node or npx for more than node -v ($(cat "$marker"))"
else
  ok "Node 18 stops before npx"
fi
clean_tree "$HOME_DIR" "Node 18 does not save a scope file or agents"
clean_tree "$WORK" "Node 18 does not write the working folder"

if [ -x /tmp/node18/node-v18.20.4-linux-x64/bin/node ]; then
  new_case
  launch "$HOME_DIR" "$WORK" "$OUT" "$ERR" env PATH="/tmp/node18/node-v18.20.4-linux-x64/bin:$ORIG_PATH" bash "$INSTALL" --scope personal
  assert_status "real Node 18.20.4 exits 1" 1 "$OUT" "$ERR"
  assert_grep "$ERR" "Node.js 22.20 or later is required. Found v18.20.4." "real Node 18.20.4 names the version"
  assert_no_grep "$ERR" "styleText" "real Node 18.20.4 does not print styleText"
  assert_no_grep "$OUT" "EBADENGINE" "real Node 18.20.4 does not print EBADENGINE"
  clean_tree "$HOME_DIR" "real Node 18.20.4 writes nothing"
else
  echo "SKIP: real Node 18.20.4 binary is not installed"
fi

new_case
launch "$HOME_DIR" "$WORK" "$OUT" "$ERR" env PATH="/bin:/usr/bin" bash "$INSTALL" --scope personal
assert_status "missing node exits 1" 1 "$OUT" "$ERR"
if grep -q "node was not found" "$ERR" || grep -q "npx was not found" "$ERR"; then
  ok "missing node says node or npx was not found"
else
  bad "missing node says node or npx was not found"
  show "$OUT" "$ERR"
fi
clean_tree "$HOME_DIR" "missing node writes nothing"

copy="$CASE/copy-pins"
mkdir -p "$copy"
cp "$INSTALL" "$ROOT/install/pins.txt" "$ROOT/install/agents.txt" "$copy/"
python3 - "$copy/pins.txt" <<'PY'
import pathlib, sys
path = pathlib.Path(sys.argv[1])
lines = []
for line in path.read_text(encoding="utf-8").splitlines():
    if line.startswith("agent requirements-analyst "):
        line = "agent requirements-analyst main"
    lines.append(line)
path.write_text("\n".join(lines) + "\n", encoding="utf-8")
PY
new_case
launch "$HOME_DIR" "$WORK" "$OUT" "$ERR" bash "$copy/install.sh" --scope personal
assert_status "branch name in pins.txt exits 1" 1 "$OUT" "$ERR"
assert_grep "$ERR" "full 40-character commit SHA, not 'main'" "branch pin is rejected"
clean_tree "$HOME_DIR" "bad pin writes nothing"

copy="$CASE/copy-agents"
mkdir -p "$copy"
cp "$INSTALL" "$ROOT/install/pins.txt" "$ROOT/install/agents.txt" "$copy/"
printf '%s\n' "not-a-real-agent" >> "$copy/agents.txt"
new_case
launch "$HOME_DIR" "$WORK" "$OUT" "$ERR" bash "$copy/install.sh" --scope personal
assert_status "agents.txt drift exits 1" 1 "$OUT" "$ERR"
assert_grep "$ERR" "install/pins.txt and install/agents.txt list different agents" "agents.txt drift is named"
clean_tree "$HOME_DIR" "agents.txt drift writes nothing"

new_case
launch "$HOME_DIR" "$WORK" "$OUT" "$ERR" bash -c "$(cat "$INSTALL")" bash --scope personal
assert_status "piped install.sh without --ref exits 1" 1 "$OUT" "$ERR"
assert_grep "$ERR" "started from a pipe" "piped install.sh explains the pipe"
assert_grep "$ERR" "install/pins.txt" "piped install.sh points at the pin file"
clean_tree "$HOME_DIR" "piped install.sh writes nothing"

new_case
launch "$HOME_DIR" "$WORK" "$OUT" "$ERR" bash -c "$(cat "$UPDATE")" bash
assert_status "piped update.sh without --ref exits 1" 1 "$OUT" "$ERR"
assert_grep "$ERR" "update.sh was started from a pipe" "piped update.sh explains the pipe"
clean_tree "$HOME_DIR" "piped update.sh writes nothing"

new_case
mkdir -p "$HOME_DIR/.engineering-judgment"
printf '%s\n' project > "$HOME_DIR/.engineering-judgment/install-scope"
launch "$HOME_DIR" "$WORK" "$OUT" "$ERR" bash "$INSTALL"
assert_status "legacy global project scope exits 2" 2 "$OUT" "$ERR"
assert_grep "$ERR" "remembered project scope for every folder" "legacy project scope explains the change"
assert_grep "$ERR" "\-\-scope project" "legacy project scope tells you how to rerun"
clean_tree "$WORK" "legacy project scope does not install into the current folder"
if [ -d "$HOME_DIR/.claude" ] || [ -d "$HOME_DIR/.agents" ]; then
  bad "legacy project scope installed files"
else
  ok "legacy project scope installs nothing"
fi

# --- network failures ----------------------------------------------------------------

HUB="$(hub_sha)"
REQ="$(agent_sha requirements-analyst)"
new_case
badpins="$CASE/bad-pins.txt"
cat > "$badpins" <<EOF
hub mydevfactory $HUB
agent requirements-analyst $REQ
agent csharp-expert-developer 0000000000000000000000000000000000000000
EOF
launch "$HOME_DIR" "$WORK" "$OUT" "$ERR" env EJ_PINS="$badpins" bash "$INSTALL" --scope personal
assert_status "bad agent ref exits 1" 1 "$OUT" "$ERR"
assert_grep "$ERR" "Failed to download csharp-expert-developer .claude/agents/csharp-expert-developer.md." "bad ref names the agent file"
assert_grep "$ERR" "0000000000000000000000000000000000000000" "bad ref prints the URL"
assert_grep "$ERR" "Nothing was installed. Rerunning is safe." "bad ref says rerunning is safe"
clean_tree "$HOME_DIR" "bad ref does not leave the earlier agent installed"
clean_tree "$WORK" "bad ref does not write the working folder"
if grep -q "Skill: mydevfactory" "$OUT"; then
  bad "bad ref ran the skill install before every download finished"
else
  ok "bad ref stops before npx skills add"
fi

new_case
launch "$HOME_DIR" "$WORK" "$OUT" "$ERR" env EJ_RAW_ROOT="http://127.0.0.1:9" bash "$INSTALL" --scope personal
assert_status "network failure exits 1" 1 "$OUT" "$ERR"
assert_grep "$ERR" "Failed to download requirements-analyst .claude/agents/requirements-analyst.md." "network failure names the first file"
assert_grep "$ERR" "127.0.0.1" "network failure prints the URL"
assert_grep "$ERR" "Nothing was installed. Rerunning is safe." "network failure says rerunning is safe"
clean_tree "$HOME_DIR" "network failure writes nothing"

# --- hub ref resolution (slash branches, tags, SHAs) --------------------------------

new_case
shim="$CASE/git-shim"
mkdir -p "$shim"
cat > "$shim/git" <<'EOF'
#!/bin/sh
printf '%s\n' "$*" > "${EJ_GIT_LOG:?}"
if [ "${1:-}" != "ls-remote" ]; then
  printf '%s\n' "unexpected git $*" >> "$EJ_GIT_LOG"
  exit 1
fi
case "$*" in
  *refs/heads/cursor/feature*)
    printf '%s\t%s\n' "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa" "refs/heads/cursor/feature"
    ;;
  *refs/tags/v9.9.9*)
    printf '%s\t%s\n' "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb" "refs/tags/v9.9.9"
    printf '%s\t%s\n' "cccccccccccccccccccccccccccccccccccccccc" "refs/tags/v9.9.9^{}"
    ;;
  *refs/heads/both-ej*)
    printf '%s\t%s\n' "dddddddddddddddddddddddddddddddddddddddd" "refs/heads/both-ej"
    printf '%s\t%s\n' "eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee" "refs/tags/both-ej"
    ;;
esac
exit 0
EOF
chmod +x "$shim/git"
gitlog="$CASE/git.log"
launch "$HOME_DIR" "$WORK" "$OUT" "$ERR" env PATH="$shim:$ORIG_PATH" EJ_GIT_LOG="$gitlog" EJ_RAW_ROOT="http://127.0.0.1:9" \
  bash "$INSTALL" --scope personal --ref cursor/feature
assert_status "slash branch ref exits 1 before install" 1 "$OUT" "$ERR"
assert_grep "$OUT" "Hub: mydevfactory @ aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa (--ref cursor/feature resolved" "slash branch resolves to the commit SHA"
assert_grep "$gitlog" "refs/heads/cursor/feature" "slash branch asks git for the full branch ref"
if grep -F 'refs/tags/cursor/feature^{}' "$gitlog" >/dev/null; then
  ok "slash branch also asks git for a peeled tag"
else
  bad "slash branch also asks git for a peeled tag"
  cat "$gitlog"
fi
assert_no_grep "$OUT" "Skill: mydevfactory" "slash branch stops before npx"
assert_no_grep "$ERR" "Remote branch cursor" "slash branch does not clone the name before the slash"
clean_tree "$HOME_DIR" "slash branch writes nothing"

new_case
launch "$HOME_DIR" "$WORK" "$OUT" "$ERR" env PATH="$shim:$ORIG_PATH" EJ_GIT_LOG="$CASE/git-tag.log" EJ_RAW_ROOT="http://127.0.0.1:9" \
  bash "$INSTALL" --scope personal --ref v9.9.9
assert_status "annotated tag ref exits 1 before install" 1 "$OUT" "$ERR"
assert_grep "$OUT" "Hub: mydevfactory @ cccccccccccccccccccccccccccccccccccccccc (--ref v9.9.9 resolved" "annotated tag uses the peeled commit"
assert_no_grep "$OUT" "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb" "annotated tag does not use the tag object"

new_case
launch "$HOME_DIR" "$WORK" "$OUT" "$ERR" env PATH="$shim:$ORIG_PATH" EJ_GIT_LOG="$CASE/git-both.log" \
  bash "$INSTALL" --scope personal --ref both-ej
assert_status "ambiguous ref exits 1" 1 "$OUT" "$ERR"
assert_grep "$ERR" "matches both a branch" "ambiguous ref names the collision"
assert_grep "$ERR" "Nothing was installed. Rerunning is safe." "ambiguous ref says rerunning is safe"
clean_tree "$HOME_DIR" "ambiguous ref writes nothing"

new_case
launch "$HOME_DIR" "$WORK" "$OUT" "$ERR" env PATH="$shim:$ORIG_PATH" EJ_GIT_LOG="$CASE/git-miss.log" \
  bash "$INSTALL" --scope personal --ref missing-ej-ref
assert_status "unknown ref exits 1" 1 "$OUT" "$ERR"
assert_grep "$ERR" "Could not resolve hub ref 'missing-ej-ref'" "unknown ref is named"
clean_tree "$HOME_DIR" "unknown ref writes nothing"

new_case
sha_log="$CASE/git-sha.log"
cat > "$shim/git" <<'EOF'
#!/bin/sh
printf '%s\n' "$*" > "${EJ_GIT_LOG:?}"
exit 1
EOF
chmod +x "$shim/git"
launch "$HOME_DIR" "$WORK" "$OUT" "$ERR" env PATH="$shim:$ORIG_PATH" EJ_GIT_LOG="$sha_log" EJ_RAW_ROOT="http://127.0.0.1:9" \
  bash "$INSTALL" --scope personal --ref "$(hub_sha)"
assert_status "full SHA ref exits 1 before install" 1 "$OUT" "$ERR"
assert_grep "$OUT" "Hub: mydevfactory @ $(hub_sha) (--ref override" "full SHA is used unchanged"
if [ -e "$sha_log" ]; then
  bad "full SHA ref called git ($(cat "$sha_log"))"
else
  ok "full SHA ref does not ask git to resolve it"
fi
clean_tree "$HOME_DIR" "full SHA ref writes nothing"

remote_branch="cursor/reproducible-installs-3628"
remote_sha="$(git ls-remote https://github.com/dimitriskl/mydevfactory.git "refs/heads/${remote_branch}" | awk 'NR==1 { print $1 }')"
if [ -n "$remote_sha" ]; then
  new_case
  launch "$HOME_DIR" "$WORK" "$OUT" "$ERR" env EJ_RAW_ROOT="http://127.0.0.1:9" \
    bash "$INSTALL" --scope personal --ref "$remote_branch"
  assert_status "live slash branch exits 1 before install" 1 "$OUT" "$ERR"
  assert_grep "$OUT" "Hub: mydevfactory @ ${remote_sha} (--ref ${remote_branch} resolved" "live slash branch matches git ls-remote"
  assert_no_grep "$ERR" "Remote branch cursor" "live slash branch does not clone the short name"
  clean_tree "$HOME_DIR" "live slash branch writes nothing"
else
  echo "SKIP: refs/heads/${remote_branch} is not on origin"
fi

# --- fresh personal install, update, and backups ------------------------------------

new_case
PERSONAL_HOME="$HOME_DIR"
PERSONAL_WORK="$WORK"
mkdir -p "$PERSONAL_HOME/.claude/agents" "$PERSONAL_HOME/.codex"
python3 - "$PERSONAL_HOME/.claude/settings.json" <<'PY'
import json, pathlib, sys
path = pathlib.Path(sys.argv[1])
path.write_text(json.dumps({"env": {"CLAUDE_AUTOCOMPACT_PCT_OVERRIDE": "70", "OTHER": "kept"}}, indent=2) + "\n", encoding="utf-8")
PY
cp "$PERSONAL_HOME/.claude/settings.json" "$CASE/settings-before.json"
cat > "$PERSONAL_HOME/.codex/config.toml" <<'EOF'
personality = "pragmatic"

[mcp]
enabled = true
EOF
printf '%s\n' "PREEXISTING-AGENT-EDIT" > "$PERSONAL_HOME/.claude/agents/requirements-analyst.md"
launch "$PERSONAL_HOME" "$PERSONAL_WORK" "$OUT" "$ERR" bash "$INSTALL" --scope personal
assert_status "fresh personal install exits 0" 0 "$OUT" "$ERR"
assert_grep "$OUT" "Scope: personal (" "personal install announces personal scope"
assert_grep "$OUT" "Hub: mydevfactory @ $HUB" "personal install prints the hub pin"
assert_grep "$OUT" "Agent: requirements-analyst @ $REQ" "personal install prints the agent pin"
assert_grep "$OUT" "updated    $PERSONAL_HOME/.claude/agents/requirements-analyst.md" "pre-existing agent file is backed up"
assert_grep "$OUT" "\.engineering-workflow.json" "personal install prints the workflow command"
if [ -f "$PERSONAL_WORK/.engineering-workflow.json" ] || [ -d "$PERSONAL_WORK/.claude/agents" ]; then
  bad "personal install wrote project files into the working folder"
  find "$PERSONAL_WORK" -mindepth 1 -print
else
  ok "personal install leaves the working folder free of project agents"
fi
if [ "$(tr -d '\r\n' < "$PERSONAL_HOME/.engineering-judgment/install-scope")" = "personal" ]; then
  ok "personal scope is remembered under the user directory"
else
  bad "personal scope file was not saved"
fi
md_count="$(find "$PERSONAL_HOME/.claude/agents" -maxdepth 1 -name '*.md' ! -name '*.bak-*' | wc -l | tr -d ' ')"
toml_count="$(find "$PERSONAL_HOME/.codex/agents" -maxdepth 1 -name '*.toml' ! -name '*.bak-*' | wc -l | tr -d ' ')"
if [ "$md_count" = "8" ] && [ "$toml_count" = "8" ]; then
  ok "personal install places 8 agents in both hosts"
else
  bad "personal install placed $md_count markdown and $toml_count toml files"
fi
remote_md="$CASE/remote.md"
remote_toml="$CASE/remote.toml"
remote_skill="$CASE/remote-skill.md"
curl -fsSL "https://raw.githubusercontent.com/dimitriskl/requirements-analyst/${REQ}/.claude/agents/requirements-analyst.md" -o "$remote_md"
curl -fsSL "https://raw.githubusercontent.com/dimitriskl/requirements-analyst/${REQ}/.codex/agents/requirements-analyst.toml" -o "$remote_toml"
curl -fsSL "https://raw.githubusercontent.com/dimitriskl/mydevfactory/${HUB}/skills/mydevfactory/SKILL.md" -o "$remote_skill"
if cmp -s "$remote_md" "$PERSONAL_HOME/.claude/agents/requirements-analyst.md" \
  && cmp -s "$remote_toml" "$PERSONAL_HOME/.codex/agents/requirements-analyst.toml"; then
  ok "installed agent files match the pinned commits"
else
  bad "installed agent files do not match the pinned commits"
fi
installed_skill="$(find "$PERSONAL_HOME" -path '*/mydevfactory/SKILL.md' -print -quit)"
if [ -n "$installed_skill" ] && cmp -s "$remote_skill" "$installed_skill"; then
  ok "installed skill matches the pinned hub commit"
else
  bad "installed skill does not match the pinned hub commit ($installed_skill)"
fi
lock="$(find "$PERSONAL_HOME" \( -name '.skill-lock.json' -o -name 'skills-lock.json' \) -print -quit)"
if [ -n "$lock" ] && grep -q "$HUB" "$lock"; then
  ok "skill lock records the hub pin"
else
  bad "skill lock does not record the hub pin"
fi
if cmp -s "$CASE/settings-before.json" "$PERSONAL_HOME/.claude/settings.json"; then
  ok "existing auto-compact value is kept"
else
  bad "existing Claude settings were rewritten"
fi
toml_text="$(cat "$PERSONAL_HOME/.codex/config.toml")"
if printf '%s' "$toml_text" | grep -q 'personality = "pragmatic"' \
  && printf '%s' "$toml_text" | grep -q 'model_auto_compact_token_limit = 160000' \
  && [ "${toml_text%%model_auto_compact_token_limit*}" != "$toml_text" ]; then
  pre="${toml_text%%model_auto_compact_token_limit*}"
  post="${toml_text#*model_auto_compact_token_limit}"
  if printf '%s' "$pre" | grep -q '\[mcp\]'; then
    bad "auto-compact key was inserted after the first TOML table"
  else
    ok "auto-compact key is inserted before the first TOML table"
  fi
else
  bad "Codex config.toml was not updated correctly"
  printf '%s\n' "$toml_text"
fi
baks="$(find "$PERSONAL_HOME/.claude/agents" -maxdepth 1 -name 'requirements-analyst.md.bak-*' | sort)"
bak_count="$(printf '%s\n' "$baks" | grep -c . || true)"
if [ "$bak_count" = "1" ] && grep -q "PREEXISTING-AGENT-EDIT" $baks; then
  ok "pre-existing agent file is kept as a timestamped backup"
else
  bad "expected one timestamped backup of the pre-existing file (found $bak_count)"
fi

launch "$PERSONAL_HOME" "$PERSONAL_WORK" "$OUT" "$ERR" bash "$UPDATE"
assert_status "update.sh over a personal install exits 0" 0 "$OUT" "$ERR"
assert_grep "$OUT" "up to date" "update.sh reports files that are already current"
assert_grep "$OUT" "Remembered for your user account" "update.sh reuses the saved personal scope"
bak_count="$(find "$PERSONAL_HOME/.claude/agents" -maxdepth 1 -name 'requirements-analyst.md.bak-*' | wc -l | tr -d ' ')"
if [ "$bak_count" = "1" ]; then
  ok "an update of an unchanged file does not add another backup"
else
  bad "unchanged update created backups (count $bak_count)"
fi

printf '%s\n' "SECOND-AGENT-EDIT" > "$PERSONAL_HOME/.claude/agents/requirements-analyst.md"
launch "$PERSONAL_HOME" "$PERSONAL_WORK" "$OUT" "$ERR" bash "$INSTALL"
assert_status "update after a local edit exits 0" 0 "$OUT" "$ERR"
printf '%s\n' "THIRD-AGENT-EDIT" > "$PERSONAL_HOME/.claude/agents/requirements-analyst.md"
launch "$PERSONAL_HOME" "$PERSONAL_WORK" "$OUT" "$ERR" bash "$INSTALL"
assert_status "second update after a local edit exits 0" 0 "$OUT" "$ERR"
if cmp -s "$remote_md" "$PERSONAL_HOME/.claude/agents/requirements-analyst.md"; then
  ok "the installed agent matches the pin after two edits"
else
  bad "the installed agent does not match the pin after two edits"
fi
found_pre=0 found_second=0 found_third=0
while IFS= read -r bak; do
  [ -n "$bak" ] || continue
  grep -q "PREEXISTING-AGENT-EDIT" "$bak" && found_pre=$((found_pre + 1))
  grep -q "SECOND-AGENT-EDIT" "$bak" && found_second=$((found_second + 1))
  grep -q "THIRD-AGENT-EDIT" "$bak" && found_third=$((found_third + 1))
done <<EOF
$(find "$PERSONAL_HOME/.claude/agents" -maxdepth 1 -name 'requirements-analyst.md.bak-*' | sort)
EOF
if [ "$found_pre" = "1" ] && [ "$found_second" = "1" ] && [ "$found_third" = "1" ]; then
  ok "each local edit is kept in its own backup"
else
  bad "backup contents were overwritten (pre=$found_pre second=$found_second third=$found_third)"
  find "$PERSONAL_HOME/.claude/agents" -maxdepth 1 -name 'requirements-analyst.md.bak-*' -print
fi

# --- project scope is per folder ------------------------------------------------------

new_case
PROJ_HOME="$HOME_DIR"
PROJ_A="$CASE/project-a"
PROJ_B="$CASE/project-b"
mkdir -p "$PROJ_A" "$PROJ_B"
launch "$PROJ_HOME" "$PROJ_A" "$OUT" "$ERR" bash "$INSTALL" --scope project
assert_status "fresh project install exits 0" 0 "$OUT" "$ERR"
assert_grep "$OUT" "Scope: project (" "project install announces project scope"
assert_grep "$OUT" "Config: .engineering-workflow.json added" "project install adds the workflow file"
if [ -d "$PROJ_HOME/.claude/agents" ] || [ -d "$PROJ_HOME/.agents" ]; then
  bad "project install wrote agents into the user directory"
else
  ok "project install does not write agents into the user directory"
fi
if [ "$(tr -d '\r\n' < "$PROJ_A/.engineering-judgment/install-scope")" = "project" ]; then
  ok "project scope is stored in the project folder"
else
  bad "project scope marker is missing"
fi
if [ -f "$PROJ_HOME/.engineering-judgment/install-scope" ]; then
  bad "project install wrote a user-wide scope file ($(cat "$PROJ_HOME/.engineering-judgment/install-scope"))"
else
  ok "project install does not remember project scope for every folder"
fi
remote_workflow="$CASE/workflow.json"
curl -fsSL "https://raw.githubusercontent.com/dimitriskl/mydevfactory/${HUB}/.engineering-workflow.json" -o "$remote_workflow"
if cmp -s "$remote_workflow" "$PROJ_A/.engineering-workflow.json"; then
  ok "project workflow file matches the hub pin"
else
  bad "project workflow file does not match the hub pin"
fi
proj_skill="$(find "$PROJ_A" -path '*/mydevfactory/SKILL.md' -print -quit)"
if [ -n "$proj_skill" ] && cmp -s "$remote_skill" "$proj_skill"; then
  ok "project skill matches the pinned hub commit"
else
  bad "project skill does not match the pinned hub commit ($proj_skill)"
fi
printf '%s\n' '{"kept":true}' > "$PROJ_A/.engineering-workflow.json"
launch "$PROJ_HOME" "$PROJ_A" "$OUT" "$ERR" bash "$INSTALL"
assert_status "project update without a flag exits 0" 0 "$OUT" "$ERR"
assert_grep "$OUT" "Remembered for this folder only" "a later run in the project folder stays on project scope"
assert_grep "$OUT" "Config: .engineering-workflow.json kept as is" "an existing workflow file is kept"
if grep -q '"kept": true' "$PROJ_A/.engineering-workflow.json" || grep -q '"kept":true' "$PROJ_A/.engineering-workflow.json"; then
  ok "the existing workflow file was not replaced"
else
  bad "the existing workflow file was replaced"
fi

launch "$PROJ_HOME" "$PROJ_B" "$OUT" "$ERR" env EJ_RAW_ROOT="http://127.0.0.1:9" bash "$INSTALL"
assert_status "another folder does not continue a project install" 1 "$OUT" "$ERR"
assert_grep "$OUT" "Scope: personal (" "another folder defaults to personal scope"
assert_no_grep "$OUT" "Scope: project (" "another folder does not announce project scope"
clean_tree "$PROJ_B" "another folder receives no project files"

echo
echo "$PASSES passed, $FAILS failed"
if [ "$FAILS" -ne 0 ]; then exit 1; fi
