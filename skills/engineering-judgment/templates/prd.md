# PRD — <prd-name>

<!-- Saved as prd/<prd-name>/<prd-name>.md in the project root. Written by the analyst; use the project's CONTEXT.md vocabulary. -->

PRD: <prd-name> · Created: YYYY-MM-DD · Analyst: <agent name or "main agent (fallback)">
Branch: feature/<prd-name> · Base: <branch>@<sha>

## Problem Statement

<!-- The problem from the user's point of view: who is affected and what hurts today. -->

## Solution

<!-- The solution from the user's point of view. No file paths here; those belong in the slices. -->

## User Stories

<!-- A long, numbered list covering every aspect of the feature. Format: As a <actor>, I want <feature>, so that <benefit> -->

1. As a <actor>, I want <feature>, so that <benefit>

## Invariants

<!-- What must stay true no matter what: access rules, data integrity, retries/idempotency, failure behavior. -->

- 

## Implementation Decisions

<!-- Modules built or changed, their interfaces, schema changes, API contracts, architectural decisions and the developer's technical clarifications. -->

- 

## Testing Decisions

<!-- What makes a good test here (external behavior, not internals), which modules are tested, test seams (prefer existing, highest possible), and prior art in the codebase. -->

- 

## Out of Scope

<!-- What deliberately stays unchanged. -->

- 

## Open questions & answers

<!-- Only questions that are unclear and change what gets built. The orchestrator asks the developer in chat and records the answer here. -->

| # | Question | Recommended answer | Developer answer | Blocks | Date |
| --- | --- | --- | --- | --- | --- |
| 1 |  |  |  |  |  |

## Slices

<!-- Index of every slice file in prd-tasks/. The orchestrator keeps the status column current. -->

| ID | Slice | Status | Blocked by |
| --- | --- | --- | --- |
| 001 | [<slice-name>](prd-tasks/001-<slice-name>.md) | To do | None |

## Developer sign-off

<!-- Filled in by the orchestrator only when every slice is Completed, from the developer's Guide me session and decision. Never filled in by an agent on its own. A later sign-off is appended as a new block; the latest block is the decision. Until then write: Not signed yet. -->

- Shipped: <n>/<n> slices Completed (links)
- Steps viewed: <list or "approved without viewing steps N–M">
- Change requests: <links or none>
- Not proved (blind spots): …
- Decision: ACCEPT | REJECT — reason: …
- Signed: <git user.name> · <date> · reviewed commit <sha>

## Further Notes

<!-- Anything else a builder needs: links to ADRs, related PRDs, rollout notes. -->
