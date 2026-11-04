# Agent delegation, review, and handoff contracts

## Analyst request

The analyst is read-only. Give it the request, settled human answers, domain docs, and relevant code paths — not a pre-written solution.

- **Requirements analysis (before PRD):** return user stories, acceptance criteria as observable checks, edge and failure cases, open questions the human must decide, and a proposed slice breakdown.
- **Data analysis (data/report/metric changes):** return metric definitions vs. the requirement, expected vs. actual results on known sample data, aggregation/rounding/time-zone/null findings, and row counts before/after migrations, with the exact queries or commands run and their output.

Never let the analyst write production code or run writes against shared or production data. Its output informs human decisions; it does not make them.

## Implementation specialist request

Provide only a bounded, testable slice:

- **Role and slice ID:** precise owner and task reference.
- **Source evidence:** code paths, domain documents, prior failing test.
- **Owned files:** avoid overlapping parallel writes unless safely isolated.
- **Contract:** accepted input/output, errors, auth, compatibility and invariants.
- **Proof required:** actual commands, expected observable behavior and important negative case.
- **Risks/time:** risk level, deadline and verification reserve.
- **Return:** changed files, assumptions/choices, commands+output+exit status, known untested scenarios.

Do not silently commit/push/merge/deploy or overwrite unrelated changes.

## Independent reviewer request

Give the reviewer **original changed files**, baseline requirements and actual command outputs, **not only** the implementation agent's summary. Require:

1. Findings in severity order: `severity | file:line | failure mode | evidence | reproduction`.
2. Important implicit assumptions, hidden defaults and scope changes.
3. What passing tests **do** and **do not** establish.
4. What is still needed for human approval.

Reviewer is read-only. If the host cannot invoke another agent, say so and label main-agent self-review as **not independent**.

## Integration owner

The coordinator verifies shared API/contracts, overlapping edits, build/test impact and relevant user journeys. Parallel writing is safe only with isolated worktrees or clearly non-overlapping ownership. A reviewer finding returns to the implementation owner for fixes.

## Final status

- `READY FOR HUMAN REVIEW`: an evidenced review candidate, **not** deployment approval.
- `BLOCKED`: unresolved consequential decision or failure.
- `NOT VERIFIED`: code exists but required evidence is missing.
