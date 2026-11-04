# Example: one change, not a ceremony

*Illustrative interaction; no production system was inspected.*

**Developer:** Use engineering-judgment in Fix + Deadline mode. I have 30 minutes to stop duplicate orders when an external provider retries webhooks.

**Agent:** `Risk: high (duplicate external side effects). Goal: at most one ERP order per external order. No new PRD: the existing bug report is enough. Reserve time for duplicate-delivery and failure-path checks. Need one decision: can the remote API accept an idempotency key?`

The coding specialist then works on a bounded patch. The orchestration skill requires evidence rather than the claim *tests pass*.

**Example handoff:**
- `Delivered`: idempotency guard at the persistence boundary
- `Actually invoked`: backend specialist; reviewer (read-only)
- `Proved`: 2 deliveries of the same event lead to 1 persisted order in a controlled test
- `Not proved`: two workers racing; ERP commit followed by local crash
- `Consequence`: production release requires a concurrency check or explicit residual-risk decision
- `Teach-back`: "Why is a controller-level in-memory lock insufficient?"

## Full feature example

**Developer:** Use engineering-judgment in Full feature mode. Add invoice approval in a C# API and Angular UI. Reuse existing PRD and tasks.

**Agent:** The PRD and tasks already exist, so it skips re-interviewing. First it establishes the shared API contract, then assigns backend and frontend slices to existing callable specialists. The reviewer sees original diffs and test output, not only earlier agent summaries. The final handoff records what each check actually established.

## No subagents? Still usable.

**Developer:** Use engineering-judgment in Auto mode. Implement a small UI validation fix.

**Agent:** No callable frontend specialist found. It uses the current coding agent for implementation and explicitly reports: "specialist role fallback; no separate agent was called." It performs the smallest relevant checks and does not invent independent review.
