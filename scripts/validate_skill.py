#!/usr/bin/env python3
"""Validate core Agent Skills structure and local resource references without dependencies."""
import pathlib
import re
import sys

root = pathlib.Path(__file__).resolve().parents[1]
skill_dir = root / "skills" / "engineering-judgment"
main = skill_dir / "SKILL.md"
errors = []
if not main.is_file():
    errors.append(f"Missing {main}")
else:
    body = main.read_text(encoding="utf-8")
    match = re.match(r"\A---\n(.*?)\n---\n", body, re.S)
    if not match:
        errors.append("SKILL.md must start with YAML frontmatter")
    else:
        frontmatter = match.group(1)
        for field in ("name", "description"):
            if not re.search(rf"(?m)^{field}:\s*\S+", frontmatter):
                errors.append(f"Missing nonempty frontmatter field: {field}")
        if not re.search(r"(?m)^name:\s*engineering-judgment\s*$", frontmatter):
            errors.append("Skill name must be engineering-judgment")
    refs = set(re.findall(r"(?:references|templates)/[a-z0-9-]+\.md", body))
    for ref in sorted(refs):
        if not (skill_dir / ref).is_file():
            errors.append(f"Broken skill reference: {ref}")
    if len(body.splitlines()) > 500:
        errors.append("SKILL.md too long; move detail into references")
for p in ("README.md", "LICENSE", "CONTRIBUTING.md", "config.example.json"):
    if not (root / p).is_file():
        errors.append(f"Missing {p}")
if errors:
    for error in errors:
        print("ERROR:", error, file=sys.stderr)
    sys.exit(1)
print(f"OK: {main.relative_to(root)} and {len(refs)} resource references")
