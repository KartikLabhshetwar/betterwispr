#!/usr/bin/env python3
"""Print the GitHub release notes for a version from CHANGELOG.md."""
import re
import sys
from pathlib import Path

CHANGELOG = Path(__file__).resolve().parent.parent / "CHANGELOG.md"


def release_notes(version: str, changelog: str) -> str:
    match = re.search(
        rf"^## \[{re.escape(version)}\][^\n]*\n(.*?)(?=^## \[|\Z)", changelog, re.S | re.M
    )
    if not match:
        sys.exit(f"No ## [{version}] section in CHANGELOG.md")
    sections = []
    for line in match.group(1).strip().splitlines():
        if line.startswith("### "):
            sections.append([line, []])
        elif line.strip():
            sections[-1][1].append(line)
    first_items = sections[0][1]
    first_items[0] = re.sub(r"^- (.+?\.)(?=\s|$)", r"- **\1**", first_items[0], count=1)
    return "\n\n".join(f"{heading}\n\n" + "\n".join(items) for heading, items in sections) + "\n"


if __name__ == "__main__":
    version = sys.argv[1] if len(sys.argv) > 1 else Path(CHANGELOG.parent / "VERSION").read_text().strip()
    print(release_notes(version, CHANGELOG.read_text()), end="")
