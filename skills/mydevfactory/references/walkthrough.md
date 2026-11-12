# Walkthrough — step-by-step tour and developer sign-off

The Walkthrough shows the developer **what was built, in the order it runs**, one step at a time, the way a person would step through code with a debugger. It is:

- **the sign-off screen** at the end of every PRD, and per slice for L2 slices;
- **a standalone mode**: `Use mydevfactory in Walkthrough mode on <PRD | slice | branch | diff>`.

The Walkthrough never quizzes the developer. Check questions belong only to Drill mode.

## Approach and code map

Before the numbered step list, explain the approach in two to four short sentences for a reader who may not be a programmer or a native English speaker: the goal, the main choice and how information moves. Explain necessary technical words when first used. Then show a compact map in execution order that names the actual files, classes and methods and states each one's role and what it passes to the next part. Include key decision and error branches where they matter. Base names and relationships on inspected code; identify unknown or unverified links explicitly and never invent them. If a flow crosses frontend and backend, show their connection.

When the current graphical interface can render a diagram, also show a compact flow diagram, such as Mermaid, with short labels and at most five nodes per row. Split larger maps by flow or use a top-down layout. A diagram supplements the text map; if rendering is unavailable, use the text map. For large changes, group low-level details and identify the main path. Keep the map accessible with a `map` command during the walk, and refresh it after changes.

## Step list

Before showing anything, read the diff (for a PRD: `<Base sha>...feature/<prd-name>`, using the `Base:` line in the PRD header, never assume `main`), the PRD and the slice files. Build a numbered list of the **major** changes, meaning behavior, contracts, guards, persistence, UI states and tests that prove them. Skip formatting, renames and boilerplate.

Order the steps in **execution-flow order**: follow a real request from its entry point through API, service and persistence to UI, not file order. When there are several flows, walk each one in turn and name it in the list. Each step links to its slice.

Show the whole list at the top of every screen. Mark the steps with `▶` for the current step, `✓` for viewed, `✎` for a change requested, and nothing for not yet viewed.

## Step card

Below the list, show **one** step:

```
━━ Walkthrough · invoice-approval · 9 steps ━━━━━━━━━━━━━━━━━━
   1. ✓ POST /invoices/{id}/approve endpoint      (slice 003)
   2. ✓ Permission check: only Approvers          (slice 003)
 ▶ 3.   Guard: invoice must still be "Pending"     (slice 003)
   4.   Save approval + audit row                  (slice 003)
   5.   Approve button in invoice list             (slice 004)
   ...
   9.   Error toast when already approved          (slice 004)
──────────────────────────────────────────────────────────
Step 3/9 · src/Invoices/ApproveInvoiceHandler.cs:42-51
  What:  Rejects the request if status ≠ Pending (409 Conflict).
  Why:   Stops double approval — acceptance criterion 003-2.
  Tests: 2 for this step
    ✓ tests/Invoices/ApproveInvoiceTests.cs:31 · ApproveTwice_Returns409
        approving an already approved invoice returns 409 · PASS · new
    ✓ tests/Invoices/ApproveInvoiceTests.cs:52 · Approve_Pending_SetsApproved
        a pending invoice becomes Approved · PASS · new
──────────────────────────────────────────────────────────
 next · back · go 7 · open 2 · tests · ask … · change … · approve all
```

- **Location:** `file:line-range` of the real code, written as `path/from/repo/root.ext:line` (see "Editor follows the walk"). Show the key lines if they help, but keep it short.
- **What:** what the code does, in plain words.
- **Why:** the slice and acceptance criterion or invariant it serves.
- **Tests:** every test that covers this step, one entry each: `<file:line> · <test name>`, then `<what it checks, in plain words> · PASS | FAIL | NOT RUN · new | changed | existing`. `new` and `changed` come from the diff; results come from the parts' `Evidence:` blocks and the QA notes, never from memory. Mark each entry `✓` (PASS), `✗` (FAIL) or `?` (NOT RUN). If a step has no test, show `Tests: none written — not verified`; it also goes into the blind spots at sign-off.

## Editor follows the walk

Every location on a card (step code, tests, change requests, findings) is written as `path/from/repo/root.ext:line`: relative to the repository root, forward slashes, no space before `:line` (a range is `:42-51`). VS Code's terminal turns that text into a Ctrl+click link; AI chat panes may or may not, so don't rely on the click alone.

**The editor moves by itself.** Each time a card is shown, run `code -r -g "<absolute path>:<line>"` for the step's code location, so the file opens at that line in the developer's open VS Code window. Use the absolute path of the tree the code is in (for an unmerged parallel slice, its worktree). Do it only when:

- the session runs inside VS Code: `TERM_PROGRAM=vscode`, or `VSCODE_IPC_HOOK_CLI` / `VSCODE_PID` is set (otherwise `code` would start a new window); or the developer typed `editor on`;
- the `code` command exists (`cursor` for Cursor, the same flags).

If neither holds, or the command fails once (for example, a sandbox blocks it), say so in one line (`⚪ orchestrator [<model>, <effort>]: editor jump unavailable — use the links or Ctrl+P`), stop trying for this walk, and keep going with text only. Moving the editor never changes a file.

## Commands

Wait for the developer after every card.

- `map` — show the approach and code map again without advancing.
- `next` / `back` / `go N` — move the pointer and show that card. A step you leave is marked `✓`.
- `open N` — move the editor to location N of the current card (1 = the step's code, 2 and up = its tests, in the order shown), then stay on it.
- `editor off` / `editor on` — stop or restart moving the editor.
- `tests` — show the key lines of each test for the current step (arrange, act, assert), then stay on it.
- `ask …` — answer about the current step from the code and evidence, then stay on it.
- `change …` — record in that step's slice file under `Change requests`: `Change request by <git user.name> · <date> · file:line · <what to do differently> · open`. The orchestrator changes `· open` to `· done (<commit sha>)` when that slice reaches `Completed` again. Mark the step `✎` and continue the walk. Do **not** dispatch anything yet.
- `approve all` — skip the remaining steps and go to the summary. The sign-off records `approved without viewing steps N–M`. This is honest, not a penalty. It does not itself mean ACCEPT; ask for a separate sign-off decision and wait for an unambiguous answer.

When the walk ends, every slice with change requests goes back to its developer parts, following the transition table, then through review and QA again. The next Walkthrough shows **only the changed steps**.

## Sign-off

After the last step (or `approve all`), show a one-screen summary: steps viewed, change requests, and **blind spots**, meaning what the strongest checks did not prove. Then ask for the decision:

- **ACCEPT**: the orchestrator fills in `Developer sign-off` in the PRD (and in the slice file for L2 slices) and commits it on `feature/<prd-name>`.
- **REJECT** with a reason: recorded the same way. The orchestrator asks what should happen next.

```
## Developer sign-off
- Shipped: <n>/<n> slices Completed (links)
- Steps viewed: <list or "approved without viewing steps N–M">
- Change requests: <links or none>
- Not proved (blind spots): …
- Decision: ACCEPT | REJECT — reason: …
- Signed: <git user.name> · <date> · commit <sha>
```

For a per-slice L2 sign-off, ACCEPT requires that slice to be `Completed` and have no open change requests; other slices may still be unfinished. Record the decision in that slice, without signing off the entire PRD. For the overall PRD sign-off, ACCEPT requires every slice to be `Completed` and no change request to be open. A later sign-off is appended as a new block; the latest block is the decision. `Signed:` names the reviewed HEAD commit. Merging into `main` is only **offered** after overall ACCEPT, and the developer does it.

After recording a decision, make the next step explicit. On slice ACCEPT, state which slices remain and automatically continue with the next ready slice if the current request authorizes it; otherwise ask whether to continue. If the next work is blocked, explain the blocker and ask for the specific input needed. On overall ACCEPT, state that the requested implementation and sign-off are complete and offer the merge if applicable. On REJECT, ask what should happen next. For a standalone walkthrough without a board, state when the walkthrough is finished and identify any outstanding decision or action. Never end with a status-only recap when the user needs to act.
