# Slice 001 — approve-invoice

*Illustrative example; not a real project.*

Slice: 001
PRD: [../invoice-approval.md](../invoice-approval.md)
Risk: L2
Status: Completed
Blocked by: None
Failures: 1/3

## What to build

An Approver clicks **Approve** on a Pending invoice in the invoice list; the invoice becomes Approved and an audit row is written. A second approval of the same invoice is refused with a clear message. User stories covered: #1, #3, #4.

## Contract

- Endpoint / interface: `POST /api/invoices/{id}/approve`
- Request shape: empty body; `If-Match: <rowVersion>` header
- Response shape: `200 { "id": "guid", "status": "Approved", "approvedBy": "string", "approvedAt": "ISO-8601 UTC" }`
- Validation and errors: `404` unknown invoice; `409 { "code": "invoice.not_pending" }` when not Pending or rowVersion changed
- Auth / permissions: role `Approver`, otherwise `403`
- Optional fields and versioning: none; v1

## Backend part

Owner role: backend
Owned files:
- `src/Invoices/ApproveInvoiceHandler.cs`
- `src/Invoices/InvoicesController.cs`
- `tests/Invoices.Tests/ApproveInvoiceTests.cs`
Steps:
1. Add `ApproveInvoiceHandler` that loads the invoice, checks `Pending` and rowVersion, sets `Approved`, writes the audit row in one transaction.
2. Add the endpoint with the `Approver` policy.
3. Add tests for 200, 403, 404, 409 and two parallel approvals.
Test commands:
- `dotnet test tests/Invoices.Tests --filter ApproveInvoice` → expected: all pass
Part status: Developed

## Frontend part

Owner role: frontend
Owned files:
- `web/src/app/invoices/invoice-list.component.ts`
- `web/src/app/invoices/invoice-list.component.html`
- `web/src/app/invoices/invoice-list.component.spec.ts`
Steps:
1. Show **Approve** only for Pending invoices and users with the Approver role.
2. Call the endpoint with `If-Match`; on 409 show "Already approved by someone else" and refresh the row.
Test commands:
- `npx ng test --include=src/app/invoices` → expected: all pass
Part status: Developed

## Acceptance criteria

- [x] Approver approves a Pending invoice — check: status shows Approved, audit row exists
- [x] Clerk sees no Approve button — check: component test with Clerk role
- [x] Two simultaneous approvals produce one approval and one 409 — check: parallel integration test
- [x] Approving an Approved invoice shows "Already approved by someone else" — check: component test on 409

## Questions & answers

| # | Asked by | Question | Recommended answer | Developer answer | Date |
| --- | --- | --- | --- | --- | --- |
| 1 | frontend (ui-ux-developer) | Refresh the whole list or only the row after a 409? | Only the row, to keep the user's scroll position | Only the row | 2026-11-04 |

## Review notes

Round 1 · senior-code-reviewer · FAIL
- Backend: High · `src/Invoices/ApproveInvoiceHandler.cs:48` · audit row is saved in a second `SaveChanges`, so a crash between the two leaves an approval without audit · what must be done: write both in one transaction.
- Frontend: PASS.

Round 2 · senior-code-reviewer · PASS
- Backend: audit row now saved in the same transaction (`ApproveInvoiceHandler.cs:42-51`). Green tests do not prove behavior under database failover.

## QA notes

Round 1 · qa-automation-engineer · PASS
| Criterion | How checked | Result | Evidence |
| --- | --- | --- | --- |
| Approver approves | API call + UI | PASS | 200, row shows Approved |
| Clerk sees no button | UI as Clerk | PASS | button absent |
| Two simultaneous approvals | `dotnet test --filter Parallel` | PASS | 1 × 200, 1 × 409 |
| Already approved message | UI after 409 | PASS | message shown, row refreshed |
Criteria with no automated test: none

## Change requests

- None

## Developer sign-off

- Steps viewed: 1–6 (all)
- Not proved (blind spots): behavior under database failover during approval
- Decision: ACCEPT — reason: invariants covered by the parallel-approval test
- Signed: Example Developer · 2026-11-04 · commit 3f2a1c9

## History

- 2026-11-04 | analyst (data-analyst-bi-expert) | created slice | To do
- 2026-11-04 | backend (csharp-expert-developer) | implemented part | Developed — 7/7 tests pass
- 2026-11-04 | frontend (ui-ux-developer) | implemented part | Developed — 5/5 tests pass
- 2026-11-04 | reviewer (senior-code-reviewer) | review round 1 | FAIL — audit row not in same transaction
- 2026-11-04 | backend (csharp-expert-developer) | fixed review finding | Developed — 7/7 tests pass
- 2026-11-04 | reviewer (senior-code-reviewer) | review round 2 | PASS
- 2026-11-04 | qa (qa-automation-engineer) | QA round 1 | PASS — 4/4 criteria
- 2026-11-04 | orchestrator | merged into feature/invoice-approval, integration check | PASS
- 2026-11-04 | orchestrator | Guide me + L2 sign-off | ACCEPT
