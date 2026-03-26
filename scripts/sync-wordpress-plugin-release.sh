#!/usr/bin/env bash

set -euo pipefail

if [ "$#" -gt 1 ]; then
  printf 'Usage: %s [version]\n' "$0" >&2
  exit 1
fi

ROOT_DIR="$(git rev-parse --show-toplevel)"
VERSION="${1:-${VERSION:-}}"

if [ -z "$VERSION" ]; then
  printf 'Provide VERSION as an argument or environment variable\n' >&2
  exit 1
fi

export ROOT_DIR VERSION

python3 - <<'PY'
import os
import re
from pathlib import Path

root = Path(os.environ["ROOT_DIR"])
version = os.environ["VERSION"]

frontman_php = root / "libs/frontman-wordpress/frontman.php"
readme_txt = root / "libs/frontman-wordpress/readme.txt"

frontman_text = frontman_php.read_text()
frontman_text, header_count = re.subn(
    r"(\* Version:\s*)([0-9]+\.[0-9]+\.[0-9]+)",
    rf"\g<1>{version}",
    frontman_text,
    count=1,
)
frontman_text, constant_count = re.subn(
    r"(define\(\s*'FRONTMAN_VERSION',\s*')([0-9]+\.[0-9]+\.[0-9]+)('\s*\);)",
    rf"\g<1>{version}\g<3>",
    frontman_text,
    count=1,
)

if header_count != 1 or constant_count != 1:
    raise SystemExit("Could not update WordPress plugin version in frontman.php")

frontman_php.write_text(frontman_text)

readme_text = readme_txt.read_text()
readme_text, stable_tag_count = re.subn(
    r"^(Stable tag:\s*)([0-9]+\.[0-9]+\.[0-9]+)$",
    rf"\g<1>{version}",
    readme_text,
    count=1,
    flags=re.MULTILINE,
)

if stable_tag_count != 1:
    raise SystemExit("Could not update Stable tag in readme.txt")

new_entry = (
    f"= {version} =\n"
    f"* Sync the Frontman plugin release with Frontman v{version}\n"
    "* See the GitHub release notes for the full cross-product changelog\n"
)

changelog_heading = "== Changelog ==\n"
if changelog_heading not in readme_text:
    raise SystemExit("Could not find changelog heading in readme.txt")

heading_index = readme_text.index(changelog_heading) + len(changelog_heading)
existing_top_entry = re.compile(
    r"\n*= [0-9]+\.[0-9]+\.[0-9]+ =\n(?:\* .*\n)+",
    re.MULTILINE,
)
remaining = readme_text[heading_index:]

if re.match(rf"\n*= {re.escape(version)} =\n", remaining):
    remaining = existing_top_entry.sub("\n" + new_entry, remaining, count=1)
else:
    remaining = "\n" + new_entry + "\n" + remaining.lstrip("\n")

readme_txt.write_text(readme_text[:heading_index] + remaining)
PY

printf 'Synced WordPress plugin metadata to version %s\n' "$VERSION"
