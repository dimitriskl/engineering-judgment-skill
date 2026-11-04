# Deadline mode: risk budget

Deadlines change *ceremony*, not truthfulness.

| Time budget for a normal L1 task | Intent | Implement | Targeted verification | Handoff |
| --- | ---: | ---: | ---: | ---: |
| 15 minutes | 1 | 10 | 3 | 1 |
| 30 minutes | 2 | 19 | 7 | 2 |
| 60 minutes | 5 | 35 | 15 | 5 |

Numbers are rough planning defaults, **not stopwatch guarantees**. If clock/time instruments aren't available, do not pretend to track elapsed minutes. Reserve more verification for L2 and cut scope.

**Start:** `Deadline | risk | must ship | must not break | minimum evidence | cut first`.

**Protect:** focused reproduction, relevant unit/integration check, read changed diff, and one counterexample. Skip unnecessary interview loops and speculative architecture refactors.

**Escalate:** if the change cannot meet the risk-appropriate evidence threshold, mark it `NOT VERIFIED`. Narrow scope, place behind a feature flag where appropriate, or ask for the decision. Never call green CI proof of safety.

**Finish:** `Outcome | observed checks | strongest blind spot | deferred work | human decision`. No quiz questions; drills happen only in Drill mode.

**Full feature under Deadline:** every slice still gets review and QA, but with **one fix round only**; anything unresolved is flagged in the handoff.
