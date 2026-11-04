# Optional critical-thinking drills using real code

These are **opt-in and used only in Drill mode** — teach-back and check questions never appear in other modes, handoffs or the Walkthrough sign-off. Use actual changed source and evidence, never a generic trivia quiz.

## A. Hypothesis before answer (5–10 minutes)

Show a symptom and minimal relevant code. Ask the human for a likely cause, alternative, and falsifying observation. Run the chosen distinguishing test if permitted; compare prediction and result.

## B. What a green test missed (10 minutes)

Pick one passing test. Ask: "What precise behavior did it prove? Name one production bug it would not catch." Develop a counterexample (retry, competing worker, different tenant, empty input) and a targeted negative test.

## C. Decision excavation (10 minutes)

Choose one consequential diff hunk. Ask which implicit behavior/default it chose, what alternatives existed, and who depends on it. Trace a call path to an external effect.

## D. Human-only slice (10–15 minutes)

Offer one narrow debugging/design/test exercise where the engineer attempts first without generated code. Compare approaches after the attempt; hints are allowed on request.

## E. Architectural defense (10–15 minutes)

Ask for a concise explanation: problem, proposed design, rejected alternative, invariant and operational risk. Add one new constraint, then ask how the design changes.

**Feedback:** `Sound reasoning | Missing evidence | Next practice`. In Drill mode ask **one question at a time**, numbered `Question n/N` with the total for the session (agree the number at the start, for example 5), await the person's answer, and do not leak the solution before the attempt.

The skill is primarily a delivery orchestrator, not a compulsory teacher. After any task, the developer can start a drill on it with `Use engineering-judgment in Drill mode`.
