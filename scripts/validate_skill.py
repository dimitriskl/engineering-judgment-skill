#!/usr/bin/env python3
"""Validate core Agent Skills structure and local resource references without dependencies."""
import pathlib
import re
import sys

root = pathlib.Path(__file__).resolve().parents[1]
skill_dir = root / "skills" / "engineering-judgment"
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
        if not re.search(r"(?m)^name:\s*engineering-judgment\s*$", frontmatter):
            errors.append("Skill name must be engineering-judgment")
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
    "skills/engineering-judgment/templates/prd.md": [
        "## Problem Statement", "## Solution", "## User Stories",
        "## Invariants", "## Implementation Decisions", "## Testing Decisions",
        "## Out of Scope", "## Open questions & answers", "## Slices",
        "## Developer sign-off", "## Further Notes",
    ],
    "skills/engineering-judgment/templates/slice.md": [
        "Status:", "Blocked by:", "Failures:", "## What to build", "## Contract",
        "## Backend part", "## Frontend part", "Owned files:", "Test commands:",
        "Part status:", "## Acceptance criteria", "## Questions & answers",
        "## Review notes", "## QA notes", "## Change requests", "## History",
        "## Developer sign-off",
    ],
    "skills/engineering-judgment/references/kanban-protocol.md": [
        "## Folder layout", "## Statuses", "## Transition table", "## Who writes what",
        "## Fresh agent prompts", "## Questions", "## Retry cap", "## Branches and commits",
        "## Parallel worktrees", "## After merge", "## Resume", "## Verdict enforcement",
        "Blocked: needs clarification", "git worktree list", "git diff --name-only",
        "uncommitted", "feature/<prd-name>", "not in the transition table",
    ],
    "skills/engineering-judgment/references/analyst-playbook.md": [
        "## Explore before asking", "CONTEXT.md", "CONTEXT-MAP.md", "docs/adr/",
        "## Questions", "recommended answer", "## Writing the PRD", "## Slicing",
        "vertical slice", "## Contract first", "exact files", "## Existing plans",
        "## Data checks", "read-only",
    ],
    "skills/engineering-judgment/references/guide-me.md": [
        "## Step list", "execution-flow order", "## Step card", "What:", "Why:", "Proof:",
        "## Commands", "next", "back", "go N", "ask", "change", "approve all",
        "Change request by", "approved without viewing steps", "## Sign-off", "ACCEPT", "REJECT",
    ],
    "skills/engineering-judgment/SKILL.md": [
        'version: "3.0.0"', "human-on-the-loop", "`Guide me`", "references/kanban-protocol.md",
        "references/analyst-playbook.md", "references/guide-me.md", "templates/prd.md",
        "templates/slice.md", "fresh agent", "Developer sign-off", "only in Drill",
    ],
    "skills/engineering-judgment/references/handoff-contract.md": [
        "slice file", "git diff --name-only", "recorded by orchestrator",
    ],
    "skills/engineering-judgment/references/orchestration-matrix.md": ["Guide me", "prd/"],
    "skills/engineering-judgment/references/training-drills.md": ["teach-back"],
    "README.md": ["Guide me", "prd/", "human-on-the-loop", "Developer sign-off"],
    "CHANGELOG.md": ["## 3.0.0"],
}
# Final-review fixes: snapshots, evidence, blocked state, change-request state, base branch.
REQUIRED["skills/engineering-judgment/templates/slice.md"] += ["Blocked from:", "Evidence:", "- Backend:", "- Frontend:"]
REQUIRED["skills/engineering-judgment/templates/prd.md"] += ["| Blocks |", "Base:"]
REQUIRED["skills/engineering-judgment/references/kanban-protocol.md"] += [
    "Blocked from:", "git status --porcelain", "never revert a path that was already",
    "one corrective re-run", "stash", "parts run one after another", "Evidence:",
]
REQUIRED["skills/engineering-judgment/references/guide-me.md"] += ["· open", "· done", "Base:"]
REQUIRED["skills/engineering-judgment/SKILL.md"] += ["before dispatching the analyst", "Evidence:"]
REQUIRED["skills/engineering-judgment/references/handoff-contract.md"] += ["git status --porcelain"]
# Questions to the developer show their position and the total, e.g. "Question 4/10".
REQUIRED["skills/engineering-judgment/references/kanban-protocol.md"] += ["Question n/N"]
REQUIRED["skills/engineering-judgment/references/analyst-playbook.md"] += ["Question n/N"]
REQUIRED["skills/engineering-judgment/references/training-drills.md"] += ["Question n/N"]
REQUIRED["skills/engineering-judgment/SKILL.md"] += ["Question n/N"]
REQUIRED["README.md"] += ["## Updating the skill", "npx skills check", "npx skills update engineering-judgment"]
# The default analyst is requirements-analyst, linked for download.
REQUIRED[".engineering-workflow.json"] = ['"analyst": { "name": "requirements-analyst" }']
REQUIRED["README.md"] += ["https://github.com/dimitriskl/requirements-analyst", '"analyst": { "name": "requirements-analyst" }']
# Chat text names its speaker, with one color marker per role.
ROLE_COLORS = ["🟣 analyst", "🔵 backend", "🟢 frontend", "🟠 reviewer", "🟡 qa", "⚪ orchestrator"]
REQUIRED["skills/engineering-judgment/SKILL.md"] += ROLE_COLORS + ["<role> (<agent name>):"]
REQUIRED["skills/engineering-judgment/references/kanban-protocol.md"] += ["<role> (<agent name>) · Question n/N"]
REQUIRED["README.md"] += ROLE_COLORS + ["🟣 analyst (requirements-analyst):"]
# Lean orchestrator: board-only reads, short agent reports.
# Every agent auto-compacts at 40% context used while its job runs; a fresh agent starts only for a new job.
REQUIRED["skills/engineering-judgment/SKILL.md"] += ["**Lean orchestrator.**", "40%", "Context checkpoints", "auto-compact"]
REQUIRED["skills/engineering-judgment/references/kanban-protocol.md"] += [
    "## Context checkpoints", "40%", "at most 10 lines", "CLAUDE_AUTOCOMPACT_PCT_OVERRIDE",
    "model_auto_compact_token_limit", "new job",
]
REQUIRED["README.md"] += [
    "### What happens in the Guide me step", "Step 2/7", "CLAUDE_AUTOCOMPACT_PCT_OVERRIDE",
    "model_auto_compact_token_limit",
]
# The user sees in plain words that a subagent started, under a readable run name.
REQUIRED["skills/engineering-judgment/SKILL.md"] += ["subagent `<run name>` started", "<role>_<slice or phase>"]
REQUIRED["README.md"] += ["Interacted with `/root/backend_s001`", "subagent `backend_s001` started"]
# The example PRD folder must follow the templates.
REQUIRED["examples/prd/invoice-approval/invoice-approval.md"] = REQUIRED["skills/engineering-judgment/templates/prd.md"]
REQUIRED["examples/prd/invoice-approval/prd-tasks/001-approve-invoice.md"] = REQUIRED["skills/engineering-judgment/templates/slice.md"]
REQUIRED["examples/prd/invoice-approval/invoice-approval.md"] = REQUIRED["examples/prd/invoice-approval/invoice-approval.md"] + ["Not signed yet"]
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
if errors:
    for error in errors:
        print("ERROR:", error, file=sys.stderr)
    sys.exit(1)
print(f"OK: {main.relative_to(root)} and {len(refs)} resource references")
