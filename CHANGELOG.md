# Changelog

## 2.2.0 — Analyst role and live agent status (2026-11-04)

- Added an optional **analyst** agent: read-only requirements analysis before PRD (stories, acceptance criteria, edge cases, slices) and data checks for query/report/metric changes.
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
