#!/usr/bin/env python3
"""Validate core Agent Skills structure and local resource references without dependencies."""
import pathlib
import re
import sys

root = pathlib.Path(__file__).resolve().parents[1]
skill_dir = root / "skills" / "mydevfactory"
main = skill_dir / "SKILL.md"
errors = []
if not main.is_file():
    errors.append(f"Missing {main}")
else:
    body = main.read_text(encoding="utf-8")
    match = re.match(r"\A---\n(.*?)\n---\n", body, re.S)
    if not match:
        errors.append("SKILL.md must start with YAML frontmatter")
    else:
        frontmatter = match.group(1)
        for field in ("name", "description"):
            if not re.search(rf"(?m)^{field}:\s*\S+", frontmatter):
                errors.append(f"Missing nonempty frontmatter field: {field}")
        if not re.search(r"(?m)^name:\s*mydevfactory\s*$", frontmatter):
            errors.append("Skill name must be mydevfactory")
    refs = set(re.findall(r"(?:references|templates)/[a-z0-9-]+\.md", body))
    for ref in sorted(refs):
        if not (skill_dir / ref).is_file():
            errors.append(f"Broken skill reference: {ref}")
    if len(body.splitlines()) > 500:
        errors.append("SKILL.md too long; move detail into references")
for p in ("README.md", "LICENSE", "CONTRIBUTING.md", ".engineering-workflow.json"):
    if not (root / p).is_file():
        errors.append(f"Missing {p}")

# Content checks: each file must contain every listed phrase.
REQUIRED = {
    "skills/mydevfactory/templates/prd.md": [
        "## Problem Statement", "## Solution", "## User Stories",
        "## Invariants", "## Implementation Decisions", "## Testing Decisions",
        "## Out of Scope", "## Open questions & answers", "## Slices",
        "## Developer sign-off", "## Further Notes",
    ],
    "skills/mydevfactory/templates/slice.md": [
        "Status:", "Blocked by:", "Failures:", "## What to build", "## Contract",
        "## Backend part", "## Frontend part", "Owned files:", "Test commands:",
        "Part status:", "## Acceptance criteria", "## Questions & answers",
        "## Review notes", "## QA notes", "## Change requests", "## History",
        "## Developer sign-off",
    ],
    "skills/mydevfactory/references/kanban-protocol.md": [
        "## Folder layout", "## Statuses", "## Transition table", "## Who writes what",
        "## Fresh agent prompts", "## Questions", "## Retry cap", "## Branches and commits",
        "## Parallel worktrees", "## After merge", "## Resume", "## Verdict enforcement",
        "Blocked: needs clarification", "git worktree list", "git diff --name-only",
        "uncommitted", "feature/<prd-name>", "not in the transition table",
    ],
    "skills/mydevfactory/references/analyst-playbook.md": [
        "## Explore before asking", "CONTEXT.md", "CONTEXT-MAP.md", "docs/adr/",
        "## Questions", "recommended answer", "## Writing the PRD", "## Slicing",
        "vertical slice", "## Contract first", "exact files", "## Existing plans",
        "## Data checks", "read-only",
    ],
    "skills/mydevfactory/references/walkthrough.md": [
        "## Step list", "execution-flow order", "## Step card", "What:", "Why:", "Tests:",
        "## Commands", "next", "back", "go N", "ask", "change", "approve all",
        "Change request by", "approved without viewing steps", "## Sign-off", "ACCEPT", "REJECT",
    ],
    "skills/mydevfactory/SKILL.md": [
        'version: "3.5.0"', "human-on-the-loop", "`Walkthrough`", "references/kanban-protocol.md",
        "references/analyst-playbook.md", "references/walkthrough.md", "templates/prd.md",
        "templates/slice.md", "fresh agent", "Developer sign-off", "only in Drill",
    ],
    "skills/mydevfactory/references/handoff-contract.md": [
        "slice file", "git diff --name-only", "recorded by orchestrator",
    ],
    "skills/mydevfactory/references/orchestration-matrix.md": ["Walkthrough", "prd/"],
    "skills/mydevfactory/references/training-drills.md": ["teach-back"],
    "README.md": ["Walkthrough", "prd/", "human-on-the-loop", "Developer sign-off"],
    "CHANGELOG.md": ["## 3.2.0", "## 3.1.0", "## 3.0.0"],
}
# Final-review fixes: snapshots, evidence, blocked state, change-request state, base branch.
REQUIRED["skills/mydevfactory/templates/slice.md"] += ["Blocked from:", "Evidence:", "- Backend:", "- Frontend:"]
REQUIRED["skills/mydevfactory/templates/prd.md"] += ["| Blocks |", "Base:"]
REQUIRED["skills/mydevfactory/references/kanban-protocol.md"] += [
    "Blocked from:", "git status --porcelain", "never revert a path that was already",
    "one corrective re-run", "stash", "parts run one after another", "Evidence:",
]
REQUIRED["skills/mydevfactory/references/walkthrough.md"] += ["· open", "· done", "Base:"]
REQUIRED["skills/mydevfactory/SKILL.md"] += ["before dispatching the analyst", "Evidence:"]
REQUIRED["skills/mydevfactory/references/handoff-contract.md"] += ["git status --porcelain"]
# Questions to the developer show their position and the total, e.g. "Question 4/10".
REQUIRED["skills/mydevfactory/references/kanban-protocol.md"] += ["Question n/N"]
REQUIRED["skills/mydevfactory/references/analyst-playbook.md"] += ["Question n/N"]
REQUIRED["skills/mydevfactory/references/training-drills.md"] += ["Question n/N"]
REQUIRED["skills/mydevfactory/SKILL.md"] += ["Question n/N"]
REQUIRED["README.md"] += ["## Updating the skill", "npx skills check", "npx skills update mydevfactory"]
# The default analyst is requirements-analyst, linked for download.
REQUIRED[".engineering-workflow.json"] = ['"name": "requirements-analyst"']
REQUIRED["README.md"] += ["https://github.com/dimitriskl/requirements-analyst", '"name": "requirements-analyst"']
# Chat text names its speaker, with one color marker per role.
ROLE_COLORS = ["🟣 analyst", "🔵 backend", "🟢 frontend", "🟠 reviewer", "🟡 qa", "⚪ orchestrator"]
REQUIRED["skills/mydevfactory/SKILL.md"] += ROLE_COLORS + ["<role> [<model>, <effort>] (<agent name>):"]
REQUIRED["skills/mydevfactory/references/kanban-protocol.md"] += ["<role> [<model>, <effort>] (<agent name>) · Question n/N"]
REQUIRED["README.md"] += ROLE_COLORS + ["🟣 analyst [opus, high] (requirements-analyst):"]
# Lean orchestrator: board-only reads, short agent reports.
# Every agent auto-compacts at 40% context used while its job runs; a fresh agent starts only for a new job.
REQUIRED["skills/mydevfactory/SKILL.md"] += ["**Lean orchestrator.**", "40%", "Context checkpoints", "auto-compact"]
REQUIRED["skills/mydevfactory/references/kanban-protocol.md"] += [
    "## Context checkpoints", "40%", "at most 10 lines", "CLAUDE_AUTOCOMPACT_PCT_OVERRIDE",
    "model_auto_compact_token_limit", "new job",
]
REQUIRED["README.md"] += [
    "### What happens in the Walkthrough step", "Step 2/7", "CLAUDE_AUTOCOMPACT_PCT_OVERRIDE",
    "model_auto_compact_token_limit",
]
# The user sees in plain words that a subagent started, under a readable run name.
REQUIRED["skills/mydevfactory/SKILL.md"] += ["subagent `<run name>` started", "<role>_<slice or phase>"]
REQUIRED["README.md"] += ["Interacted with `/root/backend_s001`", "subagent `backend_s001` started"]
# Every Walkthrough step card lists the tests written for that step, and `tests` shows their code.
REQUIRED["skills/mydevfactory/references/walkthrough.md"] += ["Tests:", "new | changed | existing", "`tests`", "none written"]
REQUIRED["README.md"] += ["VerifyCode_WrongCode_Returns401", "**`tests`**"]
# Per-role model and effort, one value per host; the orchestrator detects the host.
REQUIRED["skills/mydevfactory/SKILL.md"] += [
    "model.claude", "effort.codex", "host: Claude Code | Codex", "CLAUDECODE",
    "`reviewer: opus high`", "asks once", "▶ Now working: <role> [<model>, <effort>]",
]
REQUIRED["README.md"] += ['"claude": "opus"', '"codex": "gpt-6.1-sol"', '"codex": "gpt-6.1-terra"', "`reviewer: opus high`"]
# The mode was renamed from "Guide me" to "Walkthrough"; the old name may appear only as an alias.
REQUIRED["skills/mydevfactory/SKILL.md"] += ["formerly `Guide me`"]
_old_name = re.compile(r"guide[ -]me", re.I)
for scope in ("skills", "README.md", "examples"):
    target = root / scope
    for f in ([target] if target.is_file() else sorted(target.rglob("*.md"))):
        for n, line in enumerate(f.read_text(encoding="utf-8").splitlines(), 1):
            if _old_name.search(line) and "formerly" not in line:
                errors.append(f"{f.relative_to(root).as_posix()}:{n} uses the old name Guide me")
# Brackets are mandatory, also for the orchestrator; global installs update with -g.
REQUIRED["skills/mydevfactory/SKILL.md"] += ["Never omit the brackets", "⚪ orchestrator [session]:"]
REQUIRED["README.md"] += ["npx skills update -g"]
_skill_text = (root / "skills/mydevfactory/SKILL.md").read_text(encoding="utf-8")
if "`⚪ orchestrator:` if you don't know" in _skill_text:
    errors.append("SKILL.md still allows an orchestrator label without brackets")
for f in sorted((root / "skills").rglob("*.md")) + [root / "README.md"] + sorted((root / "examples").rglob("*.md")):
    for n, line in enumerate(f.read_text(encoding="utf-8").splitlines(), 1):
        if "⚪ orchestrator:" in line:
            errors.append(f"{f.relative_to(root).as_posix()}:{n} orchestrator label without brackets")
# One-command installer for the skill and every agent, on Windows, Linux and macOS.
REQUIRED["install/agents.txt"] = ["requirements-analyst", "csharp-expert-developer", "angular-typescript-developer",
                                  "qa-automation-engineer", "senior-code-reviewer"]
REQUIRED["install/install.sh"] = ["install/agents.txt", "install/pins.txt", "skills add", "install-scope", "CLAUDE_AUTOCOMPACT_PCT_OVERRIDE", "model_auto_compact_token_limit", "Node.js 22.20", "Rerunning is safe.", ".bak-"]
REQUIRED["install/install.ps1"] = REQUIRED["install/install.sh"]
REQUIRED["README.md"] += ["install/install.ps1 | iex", "install/install.sh | bash", "install/pins.txt", "v3.5.0", "tests/installer_e2e.sh", "tests/installer_e2e.ps1"]
# Locations are clickable (path:line from the repo root) and the Walkthrough moves the editor to each step.
REQUIRED["skills/mydevfactory/SKILL.md"] += ["path/from/repo/root.ext:line"]
REQUIRED["skills/mydevfactory/references/walkthrough.md"] += [
    "## Editor follows the walk", "code -r -g", "TERM_PROGRAM", "`open N`", "`editor off`",
]
REQUIRED["README.md"] += ["code -r -g", "`open 2`"]
# The example PRD folder must follow the templates.
REQUIRED["examples/prd/invoice-approval/invoice-approval.md"] = REQUIRED["skills/mydevfactory/templates/prd.md"]
REQUIRED["examples/prd/invoice-approval/prd-tasks/001-approve-invoice.md"] = REQUIRED["skills/mydevfactory/templates/slice.md"]
REQUIRED["examples/prd/invoice-approval/invoice-approval.md"] = REQUIRED["examples/prd/invoice-approval/invoice-approval.md"] + ["Not signed yet"]
import json
try:
    cfg = json.loads((root / ".engineering-workflow.json").read_text(encoding="utf-8"))
    for role in ("analyst", "backend", "frontend", "qa", "reviewer"):
        a = cfg["agents"][role]
        for key in ("model", "effort"):
            for host in ("claude", "codex"):
                if not isinstance(a.get(key, {}).get(host), str) or not a[key][host]:
                    errors.append(f".engineering-workflow.json: agents.{role}.{key}.{host} missing")
except (ValueError, KeyError) as exc:
    errors.append(f".engineering-workflow.json invalid: {exc}")
for rel, phrases in REQUIRED.items():
    path = root / rel
    if not path.is_file():
        errors.append(f"Missing file: {rel}")
        continue
    text = path.read_text(encoding="utf-8")
    for phrase in phrases:
        if phrase not in text:
            errors.append(f'{rel} missing: "{phrase}"')

# Teach-back questions belong only to Drill mode: in SKILL.md, a line mentioning
# teach-back must also mention Drill.
skill_md = skill_dir / "SKILL.md"
if skill_md.is_file():
    for n, line in enumerate(skill_md.read_text(encoding="utf-8").splitlines(), 1):
        if re.search(r"teach-back", line, re.I) and "Drill" not in line:
            errors.append(f"SKILL.md:{n} mentions teach-back outside Drill")
# Elsewhere in the skill, only training-drills.md may talk about teach-back questions.
for f in sorted(skill_dir.rglob("*.md")):
    if f.name in ("SKILL.md", "training-drills.md"):
        continue
    if re.search(r"teach-back|one question at handoff|learning question", f.read_text(encoding="utf-8"), re.I):
        errors.append(f"{f.relative_to(root).as_posix()} mentions teach-back outside Drill")

# The skill is self-contained: external planning skills must not be referenced.
BANNED = ["grill-with-docs", "grillme-with-docs", "to-prd", "to-tasks", "to-issues", "to-tickets"]
BANNED_SCOPE = ["skills", "README.md", ".engineering-workflow.json", "examples"]
banned_re = re.compile(r"(?<![\w-])(" + "|".join(map(re.escape, BANNED)) + r")(?![\w-])")
for scope in BANNED_SCOPE:
    target = root / scope
    files = [target] if target.is_file() else sorted(
        p for p in target.rglob("*") if p.suffix in (".md", ".json")
    )
    for f in files:
        for name in sorted(set(banned_re.findall(f.read_text(encoding="utf-8")))):
            errors.append(f'{f.relative_to(root).as_posix()} mentions banned skill name "{name}"')
version_path = root / "VERSION"
if not version_path.is_file():
    errors.append("Missing VERSION")
else:
    version = version_path.read_text(encoding="utf-8").strip()
    if not re.fullmatch(r"\d+\.\d+\.\d+", version):
        errors.append(f"VERSION is not major.minor.patch: {version}")
    else:
        skill_text = (root / "skills/mydevfactory/SKILL.md").read_text(encoding="utf-8")
        changelog = (root / "CHANGELOG.md").read_text(encoding="utf-8")
        if f'version: "{version}"' not in skill_text:
            errors.append("SKILL.md metadata version does not match VERSION")
        if f"## {version} " not in changelog:
            errors.append("CHANGELOG.md has no heading for VERSION")
pins_path = root / "install/pins.txt"
agents_path = root / "install/agents.txt"
hub = None
agents = {}
if pins_path.is_file():
    for n, raw in enumerate(pins_path.read_text(encoding="utf-8").splitlines(), 1):
        line = raw.split("#", 1)[0].strip()
        if not line:
            continue
        parts = line.split()
        if len(parts) != 3:
            errors.append(f"install/pins.txt:{n} expected 3 fields")
            continue
        kind, name, sha = parts
        if not re.fullmatch(r"[0-9a-fA-F]{40}", sha):
            errors.append(f"install/pins.txt:{n} {name} is not a full commit SHA")
        if kind == "hub":
            if hub:
                errors.append("install/pins.txt has more than one hub line")
            hub = (name, sha)
        elif kind == "agent":
            if name in agents:
                errors.append(f"install/pins.txt lists {name} more than once")
            agents[name] = sha
        else:
            errors.append(f"install/pins.txt:{n} unknown kind {kind}")
    if not hub or hub[0] != "mydevfactory":
        errors.append("install/pins.txt hub repo must be mydevfactory")
    if len(agents) != 8:
        errors.append(f"install/pins.txt has {len(agents)} agents, expected 8")
if agents_path.is_file() and agents:
    listed = []
    for raw in agents_path.read_text(encoding="utf-8").splitlines():
        line = raw.split("#", 1)[0].strip()
        if line:
            listed.append(line)
    if set(listed) != set(agents):
        errors.append("install/agents.txt and install/pins.txt list different agents")
for rel in ("install/install.sh", "install/install.ps1", "install/update.sh", "install/update.ps1"):
    text = (root / rel).read_text(encoding="utf-8")
    if re.search(r"/main(?:/|[\"'\s]|$)", text):
        errors.append(f"{rel} still references a /main ref")
if (root / "docs/task-cards/latest-anthropic-models.md").exists():
    errors.append("docs/task-cards/latest-anthropic-models.md should not be published")
if errors:
    for error in errors:
        print("ERROR:", error, file=sys.stderr)
    sys.exit(1)
print(f"OK: {main.relative_to(root)} and {len(refs)} resource references")
