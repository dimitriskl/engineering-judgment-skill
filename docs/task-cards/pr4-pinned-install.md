# Task card — pinned installer

- User outcome: Install and update the exact pinned hub skill and agents in either scope.
- Existing PRD/issue/tasks (reused): PR 4, reproducible installs.
- Risk and deadline: L1; no deadline specified.
- Required invariants: Resolve overrides to a commit; install the commit's skill bytes; retain a durable receipt; preserve unrelated lock entries and existing scope/configuration; fail clearly without claiming a successful pin on failure.
- Owner / callable agent, or main-agent fallback: Backend specialist (this agent).
- Files owned and contracts: `install/install.ps1:1`, `install/install.sh:1`, `tests/installer_e2e.ps1:1`, `tests/installer_e2e.sh:1`, `README.md:1`, `CONTRIBUTING.md:1`.
- Acceptance evidence / negative case: Real-network suites check exact installed skill bytes after temporary cleanup, personal/project scope and receipt, preservation of unrelated legacy lock entries, update, and bad pins or download failures.
- Actual commands and observed exit statuses: `pwsh -NoProfile -File tests/installer_e2e.ps1` | 0 | 120 passed, 0 failed. Git Bash: `export PATH="$PWD/test-bin:$PATH"; bash tests/installer_e2e.sh` | 0 | 121 passed, 0 failed. Both used Node 24 and real network. `git diff --check` | 0 | no whitespace errors.
- Important decisions and assumptions: The skills CLI treats SHA URLs as branch names; install from a detached local checkout, then remove its transient project lock entry. Receipt is installer-owned; use the installer for future updates. Existing remote global entry for this hub is retired while preserving other entries.
- Reviewer findings and disposition: Pending independent review.
- QA: Pending independent QA.
- Largest unverified behavior: Byte comparisons cover `SKILL.md`, not the whole installed skill tree; successful override receipt and all legacy lock formats are not exercised end to end.
- Status: IMPLEMENTED

## Review round 1
Verdict by senior-code-reviewer, recorded by orchestrator: FAIL.
- P1 | install/install.ps1:394-430; install/install.sh:556-599 | CLI catches per-target file failures and exits 0, so installer can publish receipt without successful install. Verify installed files at required destinations before receipt and test real CLI path conflict.
- P2 | install/install.ps1:405; install/install.sh:573 | personal scope parses ~/skills-lock.json, a project lock global CLI does not use; malformed home project lock causes partial failure. Only retire project lock for project scope, test preservation of home project lock.
Failures: 1/3. Status: In development.

## Backend disposition, review round 1
- Added verification of every source skill file at the Codex and Claude destinations before the receipt is written; an incomplete installation fails and the prior receipt is removed.
- Restricted project lock cleanup to project scope. Added real-CLI path-conflict and malformed/empty home project lock regressions in both suites.
- Validation: `pwsh -NoProfile -File tests/installer_e2e.ps1` completed with 124 passed, 0 failed; Git Bash `bash tests/installer_e2e.sh` completed with 125 passed, 0 failed. Both used Node 24 and real network. `git diff --check` passed.

## Review round 2
Verdict by senior-code-reviewer, recorded by orchestrator: FAIL.
- P2 | install/install.ps1:454 | accepted mixed-case scope is passed to case-sensitive Node checks, skipping lock cleanup. Normalize scope after validation and exercise mixed-case Project.
Prior P1/P2 fixed for lowercase scopes. Failures: 2/3.

## Backend disposition, review round 2
- Normalize validated PowerShell scope before passing it to case-sensitive metadata and lock cleanup logic.
- The real-CLI project scenario uses `--scope Project` and checks the canonical scope marker, project receipt, and transient lock cleanup. The receipt schema contains repository and commit, not scope.
- Validation: `pwsh -NoProfile -File tests/installer_e2e.ps1` with Node 24 and real network exited 0: 124 passed, 0 failed; the optional real Node 18 test was skipped because that binary is not installed.

## Review round 3
Verdict by senior-code-reviewer, recorded by orchestrator: PASS.
No actionable findings. Scope normalized before Node, mixed-case regression checks marker/receipt/cleanup. Reviewer directly verified PowerShell passes Project as project. Network suite counts are backend evidence; reviewer did not rerun them.
Status: In QA. Failures: 2/3.

## Final independent QA and handoff
Verdict by qa-automation-engineer, recorded by orchestrator: PASS at 2ac35ae.
| Criterion | Evidence | Verdict |
| --- | --- | --- |
| Personal/project pinned bytes and durable receipts | Real-network installer suites, pinned SKILL.md and agent comparisons | PASS |
| Updates, saved scope, configuration and other lock entries preserved | Same suites | PASS |
| Bad refs/downloads and real CLI destination conflict cannot create success receipt | Same suites | PASS |
| Mixed-case PowerShell scope | Project marker, receipt location and lock cleanup assertions | PASS |
| Documentation integration | README installation-method sections inspected | PASS |
Commands: PowerShell suite exit 0, 124 passed; Git Bash suite exit 0, 125 passed; python scripts/validate_skill.py exit 0; git diff --check exit 0. Node 24, Windows and Git Bash, real network. Initial sandbox DNS/Python failure was infrastructure; elevated rerun passed.
Limits: no independent full-tree byte comparison, successful override receipt, every legacy lock format, real Node 18, or macOS run. No visual UI applicable.
Merge risk: verification medium (these limits); request alignment low (targeted fix); impact medium (writes local skill installation and lock metadata); rollback medium (revert PR and reinstall prior version, retain backups); detection medium (explicit errors and receipt, no runtime monitoring).
Status: READY FOR HUMAN REVIEW. Developer sign-off not yet recorded. No merge or release performed.

## Hosted CI integration failure
GitHub Actions run 43239653539 on be8e983 failed: installer-linux 124 passed/1 failed; installer-windows 123 passed/1 failed; validate passed. Both failures are legacy lock migration, unlike local Node24 runs. Hosted Node version: 22.23.4. Root cause is not yet established.
Failures: 3/3. Status: BLOCKED: needs clarification.
Blocked from: READY FOR HUMAN REVIEW. Decision needed: authorize another focused diagnostic/fix round under the skill retry-cap escalation. Do not merge while CI is failing.

## Authorized continuation
Developer: "go on another turn" (2026-11-12). Continue focused diagnosis and correction of hosted legacy-lock failure, followed by fresh review and QA. Status: In development. Prior three failures retained as history; new authorized round starts here.
Orchestrator dispatch backend_pr4_ci at 4d42471; tracked working tree clean, existing local test logs and harness preserved.

## Authorized CI diagnostic round
- The earlier local Node 24 labels were inaccurate: the `npx` command used its adjacent system Node 22.14 binary and cached skills CLI 1.5.18. Node on PATH alone did not determine npm's runtime.
- Reproduced the CI failure with a complete Node 22.23.4 distribution and a fresh npm cache: skills CLI 1.8.1 rewrote the global `mydevfactory` lock entry to `sourceType: local` and the temporary checkout path, retaining the unrelated `other` entry. The existing remote-only cleanup therefore left the transient entry behind.
- Both installers now retire the entry when its local source resolves to that exact temporary checkout; unrelated skill names, including one from the same repository, remain intact. The end-to-end assertions report lock contents on failure.
- Validation: complete Node 22.23.4 distribution and initially empty npm caches resolved skills CLI 1.8.1; real-network PowerShell suite exited 0 (124 passed), Git Bash suite exited 0 (125 passed), and `git diff --check` passed. Hosted CI must be rerun after review and publication.

## CI correction review
Verdict by senior-code-reviewer, recorded by orchestrator: PASS. Both scripts use matching guards for scope, key, local type and exact resolved temporary source; both fixtures preserve unrelated entries including another skill from the same repository. git diff --check 4d42471 passed. End-to-end runs not repeated by reviewer.
Status: In QA. Orchestrator dispatch qa_pr4_ci at 4d42471 with five tracked changed files, local harness/logs preserved.

## Independent QA of CI correction
Verdict by qa-automation-engineer, recorded by orchestrator: PASS. Complete Node22.23.4/npm10.9.9, separate initially empty caches, confirmed skills1.8.1 in both caches. PowerShell124/0 exit0; Bash125/0 exit0. Pinned files/receipts, migration and unrelated entry preservation, updates/scope/config and negative paths passed. Hosted CI pending; previous coverage limitations remain. Status: READY FOR HUMAN REVIEW pending hosted checks.
