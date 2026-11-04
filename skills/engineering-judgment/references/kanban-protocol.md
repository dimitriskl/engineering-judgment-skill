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

The orchestrator adds a History line for **every** status move it makes (`orchestrator | <from> → <to> | <reason>`), so the board can be rebuilt from the files alone.

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
| any | open question | `Blocked: needs clarification`, header `Blocked from: <status> · question: <ref>` | orchestrator |
| `Blocked: needs clarification` | developer answered | the status in `Blocked from:` (then clear that line) | orchestrator |
| any | 3rd failure | `Blocked: needs clarification` with `Blocked from:` (escalate) | orchestrator |
| `Completed` | merge/integration check fails | owning part(s) `To do`, slice `In development` (counts as failure) | orchestrator |
| `Completed` | developer change request (Guide me) | changed part(s) `To do`, slice `In development` | orchestrator |

## Who writes what

| Role | May write | Never writes |
| --- | --- | --- |
| analyst | PRD file, slice files, `CONTEXT.md`, ADRs in `docs/adr/` | production code, tests |
| backend / frontend | its part's **Owned files** and their tests; its own `Part status` and `Evidence:` block; one History line | other parts, slice `Status:`, verdicts, the Contract |
| reviewer | **only the slice file**: its verdict, `Review notes`, one History line | source code, tests, any other file |
| qa | **only the slice file**: its verdict, `QA notes`, one History line | source code, tests, any other file |
| orchestrator | slice `Status:`, `Failures:`, `Questions & answers`, `Change requests`, the PRD `Slices` index and `Developer sign-off` | production code (while a specialist is callable) |

The orchestrator moves a slice only after checking the evidence is written in the file: the part's `Evidence:` block (`command | exit code | key output`) for `Developed`, a verdict with findings for review, and a per-criterion table for QA.

## Fresh agent prompts

Every run is a **fresh agent**. Never rely on conversation history, because Codex does not guarantee a clean context. Every prompt is self-contained and includes: role, the slice file path, the PRD path, the files it may change, the update rules from "Who writes what", and what to return.

- **Analyst:** the request, the developer's answers so far, domain docs, relevant code paths. Do the work in `references/analyst-playbook.md`. Return the files written and the open questions, each with a recommended answer.
- **Backend / frontend:** "Implement only your part of `<slice file>` against its Contract. Read the PRD, the slice, and any Review/QA notes and Change requests addressed to your part. Set your part to `Developing`; when every test command passed, fill your part's `Evidence:` block (`command | exit code | key output`) and set it to `Developed`. Add one History line. If you need a file outside your Owned files, stop and return a question instead of editing it. Return: changed files, the same evidence, assumptions, questions. Do not commit or stage."
- **Reviewer:** "Review the diff `<range>` for `<slice file>` against its Contract and acceptance criteria. Edit only this slice file: verdict, Review notes, History. Write PASS or FAIL per part, with `severity | file:line | failure scenario | what must be done`, and what the green checks don't prove."
- **QA:** "Run the build and test commands, then exercise the feature against every acceptance criterion: happy path, edge, failure, and loading/empty/error states for UI. Edit only this slice file: verdict, QA notes table, criteria with no automated test, History. Write no code."

If a mapped reviewer or QA agent can't write files, the orchestrator records its returned verdict verbatim, labelled `Verdict by <agent>, recorded by orchestrator`.

## Questions

Agents stop only when something is unclear and changes what gets built. A subagent can't talk to the developer, so it **returns** its questions. The orchestrator then:

1. Sets the slice to `Blocked: needs clarification` and writes `Blocked from: <previous status> · question: <ref>` in its header (for the analyst, the question's `Blocks` column names the affected slices).
2. Asks the developer **in chat, one question at a time**, with the recommended answer. Each question starts with its position and the total, `Question n/N` (for example `Question 4/10`), where N counts every open question in the current batch. If an answer raises new questions, N grows; say so (`Question 5/12 — 2 new questions from your last answer`).
3. Records the question and answer: analyst questions in the PRD `Open questions & answers`, all others in the slice `Questions & answers`.
4. Restores the status in `Blocked from:`, clears that line, and dispatches a fresh agent.

## Retry cap

`Failures: n/3` counts review FAILs, QA FAILs and post-merge check failures together. On the **3rd** failure, set `Blocked: needs clarification`, summarise the three rounds for the developer, and wait.

## Branches and commits

- **Before dispatching the analyst** (and on every resume), make sure you are on **`feature/<prd-name>`**: create it from the current branch, or switch to it if it exists. Record `Base: <branch>@<sha>` in the PRD header.
- If the working tree has **uncommitted** changes at that point, ask the developer to choose: **stash** them (`git stash push -u -m engineering-judgment`), **commit** them on their current branch first, or **stop**. Never start agents on top of the developer's uncommitted work.
- If the current branch is `main`, say so in the same question; the feature branch is still created from it.
- After each verified step, the orchestrator commits on the current work branch with the message `<prd-or-slice-id> <column>: <result>` (the analysis step included), so git history mirrors the board. Agents don't commit or stage.
- Serial slices are built directly on `feature/<prd-name>`; only parallel slices get their own worktree branch.
- Never commit to `main`, never merge into `main`, never push.

## Parallel worktrees

Within one working tree, the **parts run one after another** (backend, then frontend), never at the same time, so each run's changes can be checked on their own. Two parts of the same slice run in parallel only in separate worktrees.

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

**Before every dispatch**, record a snapshot: `git rev-parse HEAD` and `git status --porcelain`, and add a History line `orchestrator | dispatch <role> | base <sha>`.

**After the agent returns**, compare against that snapshot:

1. **HEAD must not have moved.** Agents never commit or stage. If HEAD moved, stop and ask the developer; do not reset anything yourself.
2. **Changed paths** = `git diff --name-only <base sha>` plus new untracked files in `git status --porcelain`. Judge only paths that changed during this run, and **never revert a path that was already** modified or untracked in the snapshot.
3. **Scope check:** every changed path must be allowed for the role ("Who writes what"): the slice file for reviewer and QA, the part's Owned files and their tests for developers.
4. **Section check:** `git diff <base sha> -- <slice file>` may only touch that role's sections, and History may only gain lines at the end, never lose or rewrite them.

On a violation:

- Revert only this run's out-of-scope changes (`git checkout <base sha> -- <path>`, or delete files the run created), **including this run's edits to the slice file**, so a discarded verdict leaves no trace.
- Add a History line `orchestrator | violation | <agent> changed <files>; reverted`.
- Allow **one corrective re-run** with a fresh agent and an explicit warning. A second violation on the same step sets `Blocked: needs clarification` and asks the developer (for example, the Owned files list may be missing a file the part really needs).

Violations do not count toward `Failures:`, but they are capped as above, so no loop runs forever.
