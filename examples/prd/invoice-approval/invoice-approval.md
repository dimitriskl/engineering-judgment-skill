# PRD — invoice-approval

*Illustrative example of the files the skill produces; not a real project.*

PRD: invoice-approval · Created: 2026-11-04 · Analyst: data-analyst-bi-expert
Branch: feature/invoice-approval · Base: develop@8a41c07

## Problem Statement

Finance managers approve supplier invoices by email. Approvals get lost, the same invoice is sometimes paid twice, and auditors can't see who approved what.

## Solution

Approvers approve or reject a pending invoice directly in the invoice list. Each invoice can be approved once; every decision is recorded with who made it and when.

## User Stories

1. As an Approver, I want to approve a Pending invoice from the invoice list, so that it can be paid.
2. As an Approver, I want to reject a Pending invoice with a reason, so that the supplier can be contacted.
3. As an Approver, I want a clear message when someone else already approved the invoice, so that I don't approve it twice.
4. As a Clerk, I want the Approve button hidden, so that I can't approve invoices I'm not allowed to.
5. As an Auditor, I want to see the approval history of an invoice, so that I can verify who approved it.

## Invariants

- An invoice is approved at most once, even when two Approvers click at the same moment.
- Only users with the Approver role can approve or reject.
- Every approval or rejection writes one audit row in the same transaction.

## Implementation Decisions

- The Invoices module gets an approval command; the invoice keeps its status (`Pending`, `Approved`, `Rejected`).
- Double approval is prevented with an optimistic concurrency check on the invoice row (developer's answer, Q1).
- API: `POST /api/invoices/{id}/approve` and `POST /api/invoices/{id}/reject`; conflicts return `409`.
- Analyst's call: reject reasons are free text, max 500 characters.

## Testing Decisions

- Test external behavior through the API (integration tests with the existing `WebApplicationFactory` setup) and the UI through component tests.
- Prior art: `CreateInvoiceTests` for API tests, `invoice-list.component.spec.ts` for UI.
- The concurrency invariant gets a dedicated test with two parallel requests.

## Out of Scope

- Multi-level approval chains.
- Email notifications.

## Open questions & answers

| # | Question | Recommended answer | Developer answer | Blocks | Date |
| --- | --- | --- | --- | --- | --- |
| 1 | How should simultaneous approvals be prevented? | Optimistic concurrency on the invoice row; cheapest and matches existing EF Core setup | Optimistic concurrency, agreed | 001 | 2026-11-04 |

## Slices

| ID | Slice | Status | Blocked by |
| --- | --- | --- | --- |
| 001 | [approve-invoice](prd-tasks/001-approve-invoice.md) | Completed | None |
| 002 | approval-history | To do | 001 |

## Developer sign-off

Not signed yet: slice 002 is still `To do`. Slice 001 is L2 and has its own sign-off in its slice file.

## Further Notes

- Converted from the original email-approval issue the developer pointed to.
