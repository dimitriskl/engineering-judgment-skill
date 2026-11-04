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
}
for rel, phrases in REQUIRED.items():
    path = root / rel
    if not path.is_file():
        errors.append(f"Missing file: {rel}")
        continue
    text = path.read_text(encoding="utf-8")
    for phrase in phrases:
        if phrase not in text:
            errors.append(f'{rel} missing: "{phrase}"')

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
