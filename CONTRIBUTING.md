# Contributing to MyDevFactory

Thanks for improving an open skill for engineering accountability.

## What makes a good contribution?

- A reproducible agent failure (missed invariant, misleading test, broken handoff, excess ceremony).
- A smaller or clearer workflow that improves real delivery.
- A stack-specific review reference that remains optional.
- Documentation that helps a first-time user install and run the skill.

## Before opening a PR

1. Open an issue for a substantial behavior change and describe the problem and expected outcome.
2. Make one focused change; avoid requiring any particular coding-agent vendor.
3. Keep the primary `SKILL.md` concise and reference supporting files by relative paths.
4. Verify `SKILL.md` frontmatter and links. If your change affects examples, mark hypothetical output as illustrative.
5. Include a **before / after prompt and observable evidence** where possible.
6. Protect private code, tokens, customer information, and incident details.

## Pull request checklist

- [ ] Existing agents, third-party skills and documents are preserved.
- [ ] The main agent can work without any specialist agents installed.
- [ ] No test/review/external action is described as performed unless evidenced.
- [ ] Urgent work has a shorter path than a large feature.
- [ ] Changes do not weaken explicit human approval for irreversible actions.
- [ ] Added files and instructions are documented in README.

## Community

Be respectful and specific. Disagreement about architectural approaches is welcome; personal attacks are not. See [CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md).

We welcome issue reports and PRs. Merging remains at the maintainers' discretion.
