# Slice <ID> — <slice-name>

<!-- Saved as prd/<prd-name>/prd-tasks/<ID>-<slice-name>.md. One file = one thin vertical slice = one demoable piece of value.
     A fresh agent must be able to do its job from this file and the PRD alone. If a field is unknown, raise a question instead of leaving it blank. -->

Slice: <ID>
PRD: [../<prd-name>.md](../<prd-name>.md)
Risk: L1 | L2
Status: To do
Blocked by: None
Blocked from: —
Failures: 0/3

## What to build

<!-- End-to-end behavior a user can see or call, in the PRD's vocabulary. User stories covered: #… -->

## Contract

<!-- Written by the analyst BEFORE coding. Both parts build against it. A developer who needs a change raises a question; never change it silently. -->

- Endpoint / interface:
- Request shape:
- Response shape:
- Validation and errors (codes, messages):
- Auth / permissions:
- Optional fields and versioning:

## Backend part

<!-- Delete this part if the slice has no backend work. -->

Owner role: backend
Owned files:
- `path/to/file`
Steps:
1. 
Test commands:
- `<exact command>` → expected: <result>
Evidence:
- <command> | exit <code> | <key output>
Part status: To do

## Frontend part

<!-- Delete this part if the slice has no frontend work. -->

Owner role: frontend
Owned files:
- `path/to/file`
Steps:
1. 
Test commands:
- `<exact command>` → expected: <result>
Evidence:
- <command> | exit <code> | <key output>
Part status: To do

## Acceptance criteria

<!-- For the whole slice. Each criterion has an observable check; include at least one negative case. -->

- [ ] <criterion> — check: <how to observe it>

## Questions & answers

| # | Asked by | Question | Recommended answer | Developer answer | Date |
| --- | --- | --- | --- | --- | --- |

## Review notes

<!-- Written by the reviewer agent itself. One block per round, one verdict per part. -->

Round 1 · <agent>
- Backend: PASS | FAIL
  - <severity> | `file:line` | <failure scenario> | <evidence> | what must be done: …
- Frontend: PASS | FAIL
- Not proved by the green checks: …

## QA notes

<!-- Written by the QA agent itself. One block per round. -->

Round 1 · <agent> · PASS | FAIL
| Criterion | How checked | Result | Evidence |
| --- | --- | --- | --- |
Criteria with no automated test: …

## Change requests

<!-- Added by the orchestrator from the developer's Walkthrough session. -->

- Change request by <git user.name> · YYYY-MM-DD · `file:line` · <what to do differently> · open
<!-- The orchestrator changes `open` to `done (<commit sha>)` when the slice reaches Completed again. -->

## Developer sign-off

<!-- L2 slices only (auth, money, personal data, migrations, retries/idempotency, concurrency). Filled in by the orchestrator after the Walkthrough on this slice. Delete for L0/L1. -->

- Steps viewed: <list or "approved without viewing steps N–M">
- Not proved (blind spots): …
- Decision: ACCEPT | REJECT — reason: …
- Signed: <git user.name> · <date> · commit <sha>

## History

<!-- Append-only. Every agent adds one line per run. Format: YYYY-MM-DD | role (agent) | action | result -->

- YYYY-MM-DD | analyst (<agent>) | created slice | To do
