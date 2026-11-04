# Engineering Judgment Skill

**Ship AI-assisted code you can explain, verify, and stand behind.**

[![MIT License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![Agent Skills](https://img.shields.io/badge/Agent%20Skills-compatible-blueviolet.svg)](https://agentskills.io/specification)

AI coding agents can write a feature in minutes. That does **not** mean the team understands its trade-offs, its failure modes, or what the green checks actually prove.

**Engineering Judgment** is one portable [Agent Skill](https://agentskills.io/specification) that adds *intent, risk-aware orchestration, verification evidence, and accountable handoff* to your existing coding workflow. It still lets your agent write the code. It just helps you know what you are shipping.

> **The gap:** more code generated than engineers can meaningfully review. The goal is **verified value per minute**, not the maximum number of generated lines.

## 30-second start

From your project directory, with Node.js and a supported coding-agent client installed:

```bash
npx skills add dimitriskl/Engineering-judgment-skill --skill engineering-judgment
```

Choose your coding agent when prompted. Then open a **new agent session** and ask:

```text
Use engineering-judgment in Auto mode.
Implement this change in my repo: [describe the change].
Use existing agents, PRDs, and tasks if available.
Show me what actually ran, what the checks prove, and what remains unverified.
```

The CLI and agent availability vary by environment. **Installation does not guarantee auto-activation**. Explicitly invoke `engineering-judgment` for consequential tasks.

## What it does

| Problem | What the skill adds |
| --- | --- |
| Requirements are vague | A short intent card with invariants, non-goals, and acceptance evidence |
| Agents invent design choices | Makes important assumptions and decisions visible |
| Multiple agents drift apart | Explicit ownership and backend/frontend (or other) interface contracts |
| Tests pass but behavior is broken | Separates what was *tested* from what was *not tested* |
| Reviewer only reads a summary | Asks the reviewer to inspect the original diff, requirements, and output |
| Deadlines encourage rubber-stamping | Cuts ceremony and scope before critical verification |
| You stop understanding your code | An optional, real-code teach-back question or deliberate practice drill |

**It does not require C#, Angular, subagents, or other vendors' skills.** Those are integrations, not dependencies.

## How it works

```mermaid
flowchart TD
  A[Your request + repository] --> B{Risk and scope?}
  B -->|Small fix| C[Short intent + focused task]
  B -->|Complex feature| A2[Analyst agent: stories, acceptance criteria, edge cases]
  A2 --> D[Existing interview / PRD / task skills, if installed]
  C --> E[Existing specialist agent or main coding agent]
  D --> E
  E --> F[Build + tests + observable verification]
  F --> G[Independent reviewer when available]
  G --> H[Findings + evidence + blind spots]
  H --> I[Human judgment and release decision]
```

The tool should discover and reuse what your repo already has rather than generate more documents for their own sake. A 10-minute fix should not need a 40-minute interview.

## Pick a mode

| Mode | When to use | Example |
| --- | --- | --- |
| **Auto** | Most development | `Use engineering-judgment in Auto mode to add pagination.` |
| **Full feature** | Ambiguous or cross-cutting work | `Use engineering-judgment in Full feature mode to design and implement invoice approval.` |
| **Fix + Deadline** | Production issue, limited time | `Use engineering-judgment in Fix + Deadline mode. I have 30 minutes; fix this retry bug.` |
| **Audit** | Existing PR/diff | `Use engineering-judgment in Audit mode on my branch. What do passing tests miss?` |
| **Drill** | Improve your own engineering judgment | `Use engineering-judgment in Drill mode. Ask one question at a time about a real design decision.` |

### Who is working right now

The skill prints a line each time an agent starts or finishes, and says whether a separate agent really ran or the main agent did the work as a fallback:

```text
▶ Now working: analyst (data-analyst-expert) · Phase 1 requirements · dispatched
✓ Done: analyst (data-analyst-expert) · 5 stories, 2 open questions
▶ Now working: backend (csharp-expert-developer) · Slice S1 · dispatched
✓ Done: backend (csharp-expert-developer) · 3 files, dotnet test PASS
▶ Now working: reviewer (main agent) · review · FALLBACK, not independent
```

### What the handoff looks like

```text
Delivered: Fixed duplicate webhook processing
Agents: backend specialist invoked; reviewer unavailable (self-review fallback)
Evidence: dotnet test ... — PASS (14 tests)
Proved: duplicate sequential deliveries create one order
NOT proved: two workers racing or ERP commit followed by timeout
Decision: enforce idempotency at the persistence boundary
Status: READY FOR HUMAN REVIEW (not approved for deployment)
Question: What happens if ERP commits but our process crashes before recording success?
```

Example output only, not a test result from your project.

## Existing workflow? Keep it.

If your repository already has an **analyst agent**, **C# agent**, **Angular agent**, **code reviewer**, and planning skills such as Matt Pocock's `grill-with-docs → to-prd → to-tasks/to-issues`, the skill can route work through them **when the host supports invoking them**.

It checks for existing PRDs/tasks first, asks the analyst for requirements (and for data checks when reports, queries, or metrics change), delegates code to the appropriate existing agents, reviews changed source and actual test output, and helps you keep responsibility for consequential decisions.

For *any* technology stack, map your own agent names in an optional `.engineering-workflow.json` placed in the **root of your project repository** (the repo you work in, not this skill's folder). Copy [.engineering-workflow.json](.engineering-workflow.json) there and replace the names with your own:

```json
{
  "agents": {
    "analyst": { "name": "my-analyst-agent" },
    "backend": { "name": "my-backend-agent" },
    "frontend": { "name": "my-frontend-agent" },
    "reviewer": { "name": "my-code-reviewer" }
  }
}
```

Names above are examples. **A config file does not create subagents.** If delegation is unavailable, the main agent may perform implementation, and must report that the independent handoff did not happen. Third-party skills are optional and **not bundled**.

## Manual installation (no Node required)

Copy the *entire* [`skills/engineering-judgment/`](skills/engineering-judgment/) directory into **one** of these locations in your target project:

| Client | Project-level destination |
| --- | --- |
| OpenAI Codex | `.agents/skills/engineering-judgment/` |
| Claude Code | `.claude/skills/engineering-judgment/` |
| GitHub Copilot in VS Code | `.github/skills/engineering-judgment/` |

Example (macOS/Linux):

```bash
git clone https://github.com/dimitriskl/Engineering-judgment-skill.git
mkdir -p YourProject/.agents/skills
cp -R Engineering-judgment-skill/skills/engineering-judgment YourProject/.agents/skills/
```

Example (PowerShell):

```powershell
git clone https://github.com/dimitriskl/Engineering-judgment-skill.git
New-Item -ItemType Directory -Force C:\src\YourProject\.claude\skills | Out-Null
Copy-Item -Recurse .\Engineering-judgment-skill\skills\engineering-judgment C:\src\YourProject\.claude\skills\
```

Use the corresponding destination for your agent. Restart its session, then invoke the skill explicitly. Your existing agent definitions and third-party skills are not replaced.

> **Migrating from the older "Engineering Judgment Coach":** back up/remove the old `engineering-judgment-coach` directory in your agent's skills folder to avoid duplicate or conflicting skill discovery. The new invocation name is `engineering-judgment`.

## Requirements, trust, and limitations

- A coding agent that supports [Agent Skills](https://agentskills.io/specification). No specific language/framework is required.
- This is an **instruction-based workflow**, not a runtime permission system, CI service, or autonomous background worker.
- It cannot guarantee agent delegation, third-party skill invocation, test execution, or correctness; it must report unavailable capabilities honestly.
- It never treats a green test or an agent's self-review as sufficient proof of production safety.
- It should not silently push, merge, deploy, modify production data, or make irreversible decisions.
- Review third-party skills and repository instructions before enabling them, especially in untrusted repositories.

See [a real-world-style walkthrough](examples/live-session.md) and the [skill source](skills/engineering-judgment/SKILL.md).

## Contributing

Bug reports, false-positive reviews, missing risk checks, documentation fixes, and integrations for other stacks are welcome. Please read [CONTRIBUTING.md](CONTRIBUTING.md). Especially valuable: **reproducible examples where the skill made a bad engineering call**.

This project is independent and not affiliated with OpenAI, Anthropic, GitHub or Matt Pocock. Other skills named in the examples are their authors' work.

## License

[MIT](LICENSE). Use it, modify it, share improvements.
