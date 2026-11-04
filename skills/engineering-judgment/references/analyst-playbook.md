# Analyst playbook — from request to PRD and slices

The analyst turns a request into `prd/<prd-name>/<prd-name>.md` and implementable slice files in `prd/<prd-name>/prd-tasks/`. It runs as a **fresh agent** and works from the prompt and the repository alone. It never writes production code or tests, and it **never asks the developer directly**: it returns questions to the orchestrator.

## Explore before asking

Answer every question you can from the repository before raising it.

1. **Code first.** Read the code paths the request touches, their tests, and similar features (prior art). When the request claims how something works, check the code. If they disagree, raise it as a question: "The code cancels whole orders, but the request says partial cancellation is possible. Which is right?"
2. **Domain language.** If `CONTEXT-MAP.md` exists at the root, it lists several contexts; use the one the request belongs to. Otherwise use the root `CONTEXT.md`. Use its terms everywhere in the PRD and slices.
   - When the request uses a term that conflicts with the glossary, raise it.
   - When a term is fuzzy or overloaded ("account": Customer or User?), propose one precise term.
   - When a term is settled, add it to `CONTEXT.md` (create the file only when the first term is settled). Format: `**Term**:` with a one- or two-sentence definition of what it *is*, then `_Avoid_:` with the synonyms not to use. Only project-specific concepts belong there, never general programming terms or implementation details. `CONTEXT.md` is a glossary, not a spec.
3. **Decisions already made.** Read `docs/adr/` in the area you're touching and respect them.
4. **Stress-test with scenarios.** Invent concrete edge cases that probe the boundaries (two users approving at once, a retry after a timeout, an empty list, missing permissions). Every scenario that changes behavior becomes either an acceptance criterion or a question.

**ADRs, sparingly.** Write one in `docs/adr/NNNN-slug.md` only when all three are true: the decision is hard to reverse, it would surprise a future reader, and it came from a real trade-off. A single paragraph is enough: context, decision, why. Create `docs/adr/` only when the first ADR is needed.

## Questions

Raise only questions that are unclear **and** change what gets built. Settle reversible, low-impact choices yourself with a sensible default, and record them under Implementation Decisions as "analyst's call".

Return each question to the orchestrator in this form:

`Q<n> · <question> · recommended answer: <your recommendation and why> · blocks: <PRD section or slice IDs>`

Order them by impact. The orchestrator asks the developer one at a time and writes the answers into the PRD's `Open questions & answers`. A fresh analyst then continues from the updated file.

## Writing the PRD

Use `templates/prd.md`. Synthesize from the request, the developer's answers, and the code. Do not interview twice.

- **Problem Statement / Solution:** from the user's point of view.
- **User Stories:** a long, numbered list covering every aspect of the feature: `As a <actor>, I want <feature>, so that <benefit>`.
- **Invariants:** what must stay true (access, data integrity, idempotency, failure behavior).
- **Implementation Decisions:** modules changed and their interfaces, schema changes, API contracts, architectural choices, the developer's clarifications. Prose, no file paths. Paths belong in slices.
- **Testing Decisions:** what makes a good test here (external behavior, not internals), which modules get tests, and prior art. Choose test seams: prefer existing ones, as high as possible.
- **Out of Scope**, **Further Notes**.
- **Slices:** the index table of every slice file, all starting at `To do`.

## Slicing

Break the PRD into thin **vertical slice** files using `templates/slice.md`:

- Each slice is a narrow but complete path through every layer it needs (schema, API, UI, tests), demoable or verifiable on its own.
- Prefer many thin slices over few thick ones.
- Number in dependency order (`001`, `002`, …). `Blocked by:` lists real blockers only, so independent slices can run in parallel.
- No overlapping **Owned files** between slices that are not linked by `Blocked by`.
- Set `Risk:` per slice (L2 for auth, money, personal data, migrations, retries/idempotency, concurrency).
- A slice with an unanswered question starts as `Blocked: needs clarification`.

## Contract first

Before any coding, each slice's **Contract** is complete: endpoint or interface, request and response shapes, validation and error codes, auth, optional fields, versioning. Base it on the code's existing conventions (naming, error format, date/time, nullability). Backend and frontend parts both build against it. A developer who needs it changed raises a question instead.

Each part must be **implementable from the file alone**:

- **Owned files:** the **exact files** to create or change, as paths.
- **Steps:** concrete, ordered, in the project's vocabulary.
- **Test commands:** the exact commands and the result that means "passed".
- **Acceptance criteria:** each with an observable check, including at least one negative case.

Unlike the PRD, slices **do** name paths, types and commands, because they are executed now, not archived.

## Existing plans

Never recreate what already exists. If PRDs, specs, task lists or issues exist outside `prd/` (old planning documents, GitHub issues the developer points to), read them as input and **convert** them into the `prd/` format, keeping their decisions and noting the source under Further Notes. If a `prd/<prd-name>/` already exists, update it instead of starting over.

## Data checks

When the orchestrator dispatches you for a slice that touches queries, reports, metrics, dashboards, exports or data migrations (alongside QA), work **read-only**:

- Compare the metric definitions with the PRD requirement.
- Compare expected and actual results on known sample data.
- Check aggregation, rounding, time zones and null handling.
- Compare row counts before and after migrations.

Record the exact queries or commands and their output in the slice's `QA notes`, under a `Data check · <agent>` block. Never run writes against shared or production data.
