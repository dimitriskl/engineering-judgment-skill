# Kanban protocol — PRD folders, statuses and orchestration

The orchestrator is the **main session running this skill**. It never writes production code while a callable specialist exists. Each role is a kanban column, and every step is done by a **fresh agent** that works from the files alone. The files are the board: they hold the full record of what was asked, decided, built, reviewed and tested.

## Folder layout

```
<project root>/
  prd/
    <prd-name>/                    ← kebab-case, e.g. invoice-approval
      <prd-name>.md                ← the PRD (templates/prd.md)
      prd-tasks/
        001-<slice-name>.md        ← one vertical slice per file (templates/slice.md)
        002-<slice-name>.md
```

`prd/` is committed with the code. One slice file = one thin vertical slice = one demoable piece of value. A slice that touches backend and frontend has one part for each, built against the slice's **Contract**. A single-layer slice has one part.

## Statuses

Use these exact strings.

- **Part status** (in each `Backend part` / `Frontend part`): `To do` → `Developing` → `Developed`.
- **Slice status** (header `Status:`): `To do` → `In development` → `In review` → `In QA` → `Completed`, plus `Blocked: needs clarification`.

A status that is **not in the transition table** (for example, hand-edited) is invalid: stop and ask the developer what it should be. Never guess.

## Transition table

Every allowed move. Any other move is invalid and the orchestrator rejects it.

| From | Event | To | Set by |
| --- | --- | --- | --- |
| Part `To do` | developer starts | Part `Developing` | developer |
| Part `Developing` | done with evidence | Part `Developed` | developer |
| Slice `To do` | first part starts | `In development` | orchestrator |
| Slice `In development` | all parts `Developed` | `In review` | orchestrator |
| `In review` | reviewer PASS | `In QA` | orchestrator (after reviewer verdict) |
| `In review` | reviewer FAIL | failed part(s) `To do`, slice `In development` | orchestrator |
| `In QA` | QA PASS | `Completed` | orchestrator (after QA verdict) |
| `In QA` | QA FAIL | affected part(s) `To do`, slice `In development` | orchestrator |
| any | open question | `Blocked: needs clarification` | orchestrator |
| `Blocked: needs clarification` | developer answered | previous status | orchestrator |
| any | 3rd failure | `Blocked: needs clarification` (escalate) | orchestrator |
| `Completed` | merge/integration check fails | `In development` (counts as failure) | orchestrator |
| `Completed` | developer change request (Guide me) | changed part(s) `To do`, slice `In development` | orchestrator |

## Who writes what

| Role | May write | Never writes |
| --- | --- | --- |
| analyst | PRD file, slice files, `CONTEXT.md`, ADRs in `docs/adr/` | production code, tests |
| backend / frontend | its part's **Owned files** and their tests; its own `Part status`; one History line | other parts, slice `Status:`, verdicts, the Contract |
| reviewer | **only the slice file**: its verdict, `Review notes`, one History line | source code, tests, any other file |
| qa | **only the slice file**: its verdict, `QA notes`, one History line | source code, tests, any other file |
| orchestrator | slice `Status:`, `Failures:`, `Questions & answers`, `Change requests`, the PRD `Slices` index and `Developer sign-off` | production code (while a specialist is callable) |

The orchestrator moves a slice only after checking the evidence is written in the file: commands, their output and exit codes for `Developed`, a verdict with findings for review, and a per-criterion table for QA.

## Fresh agent prompts

Every run is a **fresh agent**. Never rely on conversation history, because Codex does not guarantee a clean context. Every prompt is self-contained and includes: role, the slice file path, the PRD path, the files it may change, the update rules from "Who writes what", and what to return.

- **Analyst:** the request, the developer's answers so far, domain docs, relevant code paths. Do the work in `references/analyst-playbook.md`. Return the files written and the open questions, each with a recommended answer.
- **Backend / frontend:** "Implement only your part of `<slice file>` against its Contract. Read the PRD, the slice, and any Review/QA notes and Change requests addressed to your part. Set your part to `Developing`, then `Developed` only when every test command passed. Add one History line. Return: changed files, commands + output + exit code, assumptions, questions. Do not commit."
- **Reviewer:** "Review the diff `<range>` for `<slice file>` against its Contract and acceptance criteria. Edit only this slice file: verdict, Review notes, History. Write PASS or FAIL per part, with `severity | file:line | failure scenario | what must be done`, and what the green checks don't prove."
- **QA:** "Run the build and test commands, then exercise the feature against every acceptance criterion: happy path, edge, failure, and loading/empty/error states for UI. Edit only this slice file: verdict, QA notes table, criteria with no automated test, History. Write no code."

If a mapped reviewer or QA agent can't write files, the orchestrator records its returned verdict verbatim, labelled `Verdict by <agent>, recorded by orchestrator`.

## Questions

Agents stop only when something is unclear and changes what gets built. A subagent can't talk to the developer, so it **returns** its questions. The orchestrator then:

1. Sets the slice to `Blocked: needs clarification` (for the analyst, the PRD stays in progress).
2. Asks the developer **in chat, one question at a time**, with the recommended answer.
3. Records the question and answer: analyst questions in the PRD `Open questions & answers`, all others in the slice `Questions & answers`.
4. Restores the previous status and dispatches a fresh agent.

## Retry cap

`Failures: n/3` counts review FAILs, QA FAILs and post-merge check failures together. On the **3rd** failure, set `Blocked: needs clarification`, summarise the three rounds for the developer, and wait.

## Branches and commits

- On start, if the working tree has **uncommitted** changes or the current branch is `main`, ask the developer before creating anything.
- Each PRD gets the branch **`feature/<prd-name>`**, created from the current branch.
- After each verified column step, the orchestrator commits on the slice's branch with the message `<slice-id> <column>: <result>`, so git history mirrors the board. Agents don't commit.
- Never commit to `main`, never merge into `main`, never push.

## Parallel worktrees

When **two or more slices are ready and independent** (no `Blocked by` link between them, and no overlapping Owned files), ask the developer whether to run them in parallel. On yes:

- `git worktree add ../<repo>-<slice-id> -b feature/<prd-name>-<slice-id> feature/<prd-name>`, one worktree per slice and one agent per worktree.
- In a worktree, **that worktree's slice file is the source of truth** for that slice until it is merged.
- The orchestrator keeps the PRD `Slices` index current on `feature/<prd-name>`.
- Respect the host's parallel limits (for Codex, `agents.max_concurrent_threads_per_session`).

## After merge

A slice is merged into `feature/<prd-name>` only after it reaches `Completed`. Then:

1. Run the build, tests and contract check on the **combined** code, and record the output.
2. Merge conflicts go to the owning developer agent. The orchestrator does not resolve them in production code.
3. If the merge or the check fails, the slice goes back to `In development` and the failure counts toward the retry cap.
4. Remove the worktree (`git worktree remove`) once its branch is merged.

## Resume

A new session rebuilds the board from the files, never from memory:

1. Read every `prd/*/prd-tasks/*.md` header (`Status:`, `Blocked by:`, `Failures:`) and each part status.
2. Run `git worktree list`. For each worktree on a `feature/<prd-name>-<slice-id>` branch, read that worktree's copy of the slice file instead.
3. Report the board to the developer in one line per slice, then continue with the next ready slice.

## Verdict enforcement

After every reviewer or QA run, check `git diff --name-only` (plus untracked files). If anything other than the slice file changed:

1. Revert those changes.
2. Add a History line `orchestrator | violation | <agent> changed <files>; reverted`.
3. Re-run the step with a fresh agent.

Apply the same check to developers: changes outside their part's Owned files and tests are reverted, then sent back with a corrective prompt.
