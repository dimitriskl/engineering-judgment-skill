# Changelog

## 3.1.0 — Walkthrough, speaker labels, lean orchestrator, model and effort per role (2026-11-05)

- **Guide me is renamed Walkthrough.** The old name still works as an alias.
- New default analyst **requirements-analyst** (derived from software-architect), linked in the README; data-analyst-bi-expert stays available as an alternative.
- Every chat message names its speaker and the model and effort it ran on (`<color> <role> [<model>, <effort>] (<agent name>):`), with one color marker per role: 🟣 analyst, 🔵 backend, 🟢 frontend, 🟠 reviewer, 🟡 qa, ⚪ orchestrator. Questions show who raised them and `Question n/N`. The brackets are mandatory; `[session]` when a value is unknown.
- **Lean orchestrator:** it reads the board, not the code; agents report in at most 10 lines; every agent auto-compacts at 40% context used while its job runs, and a fresh agent starts only for the next job (README shows the Claude Code and Codex settings); after a compaction the board is rebuilt from the files. Subagent runs get readable names (`backend_s001`) and a `subagent … started` line. The README's 30-second start walks through a 2FA example, including what happens in the Walkthrough step.
- Every Walkthrough step card lists the tests written for that step (file:line, name, what it checks, result, new/changed/existing), and the `tests` command shows their code.
- **Model and effort per role:** `.engineering-workflow.json` sets `model` and `effort` per role, each with a `claude` and a `codex` value; the orchestrator detects the host, passes the matching values on every agent start, shows them in the status line, accepts a per-run override (`reviewer: opus high`), and asks once when a model is empty. Defaults: analyst and reviewer on the strong model at high effort, developers on a mid model at medium, QA at low.
- **One-command installer** (`install/install.ps1` for Windows, `install/install.sh` for Linux and macOS): installs or updates the skill and all agents, asks personal or project scope once, sets auto-compact at 40% if unset.
- README: how to update global installs (`npx skills update -g`) and why a running session keeps the old instructions.

## 3.0.0 — PRD folders, kanban orchestration, Guide me sign-off (2026-11-04)

**Breaking:** the skill no longer invokes external planning skills (`grill-with-docs`, `to-prd`, `to-issues`). Their useful abilities are built into the analyst playbook.

- The main session is the **orchestrator**; every step runs in a **fresh agent** that works from the files alone. Works in Claude Code and Codex CLI.
- The analyst writes `prd/<prd-name>/<prd-name>.md` and fully implementable vertical slices in `prd-tasks/` (Contract, backend/frontend parts with exact files and test commands, acceptance criteria). New templates `prd.md` and `slice.md`.
- Kanban protocol: exact statuses, transition table, who writes what, questions asked in chat and saved to the files, 3-failure retry cap, `feature/<prd-name>` branches, optional parallel worktrees, integration check after merge, resume from files, `git diff` write-scope enforcement.
- Reviewer and QA write their own verdicts into the slice file; FAIL sends work back to the developer.
- New **Guide me** mode (renamed **Walkthrough** in 3.1.0): numbered step list in execution-flow order, one step card at a time (`next`, `back`, `go N`, `ask`, `change`, `approve all`), ending in a recorded **Developer sign-off** (ACCEPT / REJECT). L2 slices are signed off individually.
- **Human-on-the-loop** made explicit. Teach-back questions now happen only in Drill mode.
- Validator checks required sections, banned planning-skill names, and teach-back placement. Example PRD folder in `examples/prd/`.
- Before each agent run the orchestrator records a snapshot and checks the agent stayed in scope; the developer's uncommitted work is never touched. Developers record an `Evidence:` block; blocked slices record `Blocked from:`; change requests are `open` / `done`.
- The default `.engineering-workflow.json` maps the author's published agents (data-analyst-bi-expert, csharp-expert-developer, angular-typescript-developer, qa-automation-engineer, senior-code-reviewer); the README links each one for download.

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
