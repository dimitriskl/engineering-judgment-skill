# Routing matrix and risk levels

Adapt to the current codebase. Do not apply every stage to every change.

| Situation | Discovery and planning | Implementation | Review and learning |
| --- | --- | --- | --- |
| L0: copy/format-only edit | No PRD | Owning specialist or main agent | Relevant smoke check; no coaching interruption |
| L1: localized bug | Reproduce; short intent; existing task | Owning specialist; focused tests | QA re-checks the bug and nearby behavior; reviewer if available; one question at handoff |
| L1: new feature or cross-stack change | Reuse existing spec or run interview → analyst (stories, acceptance criteria, edge cases) → PRD → tasks if needed | Explicit interface/DTO contract; bounded slices | QA checks each acceptance criterion; independent reviewer; end-to-end or contract evidence |
| L2: auth, sensitive data, migrations, retries, payments | Explicit invariants, known failure scenarios, human decision for irreversible choices | Controlled scope, safe handoffs, failure-path tests | QA covers failure paths and invariants; independent verification and human release gate |
| Data/report/metric change | Analyst confirms metric definitions and expected results on known data | Owning specialist; queries and transformations under test | Analyst read-only data check with exact queries and output; reviewer |
| Prepared task/PRD | Do **not** regenerate | Resume next smallest slice | Verify, review, hand off |
| Audit only | No PRD | No implementation unless requested | Review original diff and actual test output |
| Drill | Use real source and current diff | No code generation until requested | Question, human answer, evidence-based feedback |
| Deadline | Only minimal intent | Smallest shippable slice | Protect verification; explicitly flag unverified behavior |

**Risk guide**

- **L0:** formatting, documentation, harmless text changes with no behavior impact.
- **L1:** ordinary behavior change with bounded rollback.
- **L2:** money, authorization, personal data, irreversible writes, schema migration, concurrent external side effects, or multi-tenant boundaries.

The scope may increase the risk. The developer, not the model alone, owns consequential risk acceptance.

**Decision questions**

1. Is the problem already defined in existing project docs? Reuse them.
2. Which behavior must remain invariant, and what would falsify the proposed fix?
3. Are specialist agents really callable or merely named in config files?
4. What codepaths and interface contracts could the change affect?
5. What did actual checks prove, and what did they miss?
6. What would you need to defend this change to its maintainer?

Do not confuse **implemented**, **verified**, **reviewed**, and **released**.
