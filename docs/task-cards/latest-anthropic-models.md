# Task card — latest Anthropic models

- User outcome: select current Anthropic models for engineering-judgment agents.
- Existing PRD/issue/tasks (reused): none.
- Risk and deadline: L1; no deadline supplied.
- Required invariants: retain saved choices unless a change is requested; respect host, account and provider availability; keep Codex selection separate.
- Owner / callable agent: csharp-expert-developer.
- Files owned and contracts: `skills/engineering-judgment/SKILL.md` and `README.md`; offer supported Claude Code agent aliases and describe how to change saved choices.
- Acceptance evidence / negative case: review and QA inspected fresh and existing configurations, unsupported-model guidance and the Codex path; live host behavior was not exercised.
- Actual commands and observed exit statuses: `python scripts/validate_skill.py` | 0 | skill and 12 references validated; `git diff --check` | 0.
- Important decisions and assumptions: Claude Code agent invocations use supported aliases; an alias does not promise a particular model version. Model families were checked against Anthropic's model overview.
- Reviewer findings and disposition: senior-code-reviewer PASS; no actionable findings. QA found no defects by inspection.
- Largest unverified behavior: live Claude Code and Codex model selection, persistence, rejection handling and account-specific availability.
- Status: READY FOR HUMAN REVIEW
