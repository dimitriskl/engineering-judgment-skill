# Guide me — walkthrough and developer sign-off

Guide me shows the developer **what was built, in the order it runs**, one step at a time, the way a person would step through code with a debugger. It is:

- **the sign-off screen** at the end of every PRD, and per slice for L2 slices;
- **a standalone mode**: `Use engineering-judgment in Guide me mode on <PRD | slice | branch | diff>`.

Guide me never quizzes the developer. Check questions belong only to Drill mode.

## Step list

Before showing anything, read the diff (for a PRD: `<Base sha>...feature/<prd-name>`, using the `Base:` line in the PRD header, never assume `main`), the PRD and the slice files. Build a numbered list of the **major** changes, meaning behavior, contracts, guards, persistence, UI states and tests that prove them. Skip formatting, renames and boilerplate.

Order the steps in **execution-flow order**: follow a real request from its entry point through API, service and persistence to UI, not file order. When there are several flows, walk each one in turn and name it in the list. Each step links to its slice.

Show the whole list at the top of every screen. Mark the steps with `▶` for the current step, `✓` for viewed, `✎` for a change requested, and nothing for not yet viewed.

## Step card

Below the list, show **one** step:

```
━━ Guide me · invoice-approval · 9 steps ━━━━━━━━━━━━━━━━━━
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
  Proof: test ApproveTwice_Returns409 — PASS
──────────────────────────────────────────────────────────
 next · back · go 7 · ask … · change … · approve all
```

- **Location:** `file:line-range` of the real code. Show the key lines if they help, but keep it short.
- **What:** what the code does, in plain words.
- **Why:** the slice and acceptance criterion or invariant it serves.
- **Proof:** the test or command that proves it, and its recorded result. If nothing proves it, say `Proof: none — not verified`.

## Commands

Wait for the developer after every card.

- `next` / `back` / `go N` — move the pointer and show that card. A step you leave is marked `✓`.
- `ask …` — answer about the current step from the code and evidence, then stay on it.
- `change …` — record in that step's slice file under `Change requests`: `Change request by <git user.name> · <date> · file:line · <what to do differently> · open`. The orchestrator changes `· open` to `· done (<commit sha>)` when that slice reaches `Completed` again. Mark the step `✎` and continue the walk. Do **not** dispatch anything yet.
- `approve all` — skip the remaining steps and go to the summary. The sign-off records `approved without viewing steps N–M`. This is honest, not a penalty.

When the walk ends, every slice with change requests goes back to its developer parts, following the transition table, then through review and QA again. The next Guide me shows **only the changed steps**.

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

Sign-off can't be ACCEPT while any change request is still `· open`, or while any slice is not `Completed`. A later sign-off is appended as a new block; the latest block is the decision. `Signed:` names the reviewed HEAD commit. Merging into `main` is only **offered** after ACCEPT, and the developer does it.
