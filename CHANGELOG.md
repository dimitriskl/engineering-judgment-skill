# Changelog

## 3.0.0 — PRD folders, kanban orchestration, Guide me sign-off (2026-11-04)

**Breaking:** the skill no longer invokes external planning skills (`grill-with-docs`, `to-prd`, `to-issues`). Their useful abilities are built into the analyst playbook.

- The main session is the **orchestrator**; every step runs in a **fresh agent** that works from the files alone. Works in Claude Code and Codex CLI.
- The analyst writes `prd/<prd-name>/<prd-name>.md` and fully implementable vertical slices in `prd-tasks/` (Contract, backend/frontend parts with exact files and test commands, acceptance criteria). New templates `prd.md` and `slice.md`.
- Kanban protocol: exact statuses, transition table, who writes what, questions asked in chat and saved to the files, 3-failure retry cap, `feature/<prd-name>` branches, optional parallel worktrees, integration check after merge, resume from files, `git diff` write-scope enforcement.
- Reviewer and QA write their own verdicts into the slice file; FAIL sends work back to the developer.
- New **Guide me** mode: numbered step list in execution-flow order, one step card at a time (`next`, `back`, `go N`, `ask`, `change`, `approve all`), ending in a recorded **Developer sign-off** (ACCEPT / REJECT). L2 slices are signed off individually.
- **Human-on-the-loop** made explicit. Teach-back questions now happen only in Drill mode.
- Validator checks required sections, banned planning-skill names, and teach-back placement. Example PRD folder in `examples/prd/`.

## 2.2.0 — Analyst and QA roles, live agent status (2026-11-04)

- Added an optional **analyst** agent: read-only requirements analysis before PRD (stories, acceptance criteria, edge cases, slices) and data checks for query/report/metric changes.
- Added an optional **QA** agent (new Phase 5): read-only — runs builds/tests and exercises the feature against each acceptance criterion, reports PASS/FAIL with evidence and untested criteria; writes no code. Later phases renumbered.
- Added **live agent status** lines (`▶ Now working` / `✓ Done` / `✗ Failed`) showing which agent is working and whether it was really dispatched or a main-agent fallback.
- Renamed `config.example.json` to `.engineering-workflow.json` so it can be copied without renaming; documented that it belongs in the project repository root.
- Removed unused config keys (`version`, `search_terms`, `skills`, `verification`, `preferences`); only `agents.<role>.name` is read.

## 2.1.0 — First public release (2026-11-04)

- Broadened skill positioning to **any programming language / framework**.
- Retained optional orchestration of specialist agents and external planning skills.
- Documented installation via Agent Skills CLI and manual client-specific locations.
- Added public examples, contribution policy, safety guidance, MIT licensing and issue templates.
- Kept risk-based review, deadlines, explainable decisions and optional critical-thinking drills.

## 2.0.0 — Private prototype

- Renamed Engineering Judgment Coach to Engineering Judgment Skill.
- Added `grill-with-docs → to-prd → to-tasks` workflow coordination, C# / Angular agent routing and independent review.
