# Agent delegation, review, and handoff contracts

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
