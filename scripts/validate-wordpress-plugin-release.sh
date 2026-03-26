#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(git rev-parse --show-toplevel)"

export ROOT_DIR

python3 - <<'PY'
import os
import re
from pathlib import Path

root = Path(os.environ["ROOT_DIR"])
frontman_text = (root / "libs/frontman-wordpress/frontman.php").read_text()
readme_text = (root / "libs/frontman-wordpress/readme.txt").read_text()

header_version = re.search(r"Version:\s*([0-9]+\.[0-9]+\.[0-9]+)", frontman_text)
constant_version = re.search(r"FRONTMAN_VERSION',\s*'([0-9]+\.[0-9]+\.[0-9]+)'", frontman_text)
stable_tag = re.search(r"^Stable tag:\s*([0-9]+\.[0-9]+\.[0-9]+)$", readme_text, re.MULTILINE)
changelog_entry = re.search(r"^= ([0-9]+\.[0-9]+\.[0-9]+) =$", readme_text, re.MULTILINE)

values = {
    "Plugin header": header_version.group(1) if header_version else None,
    "FRONTMAN_VERSION": constant_version.group(1) if constant_version else None,
    "Stable tag": stable_tag.group(1) if stable_tag else None,
    "Top changelog entry": changelog_entry.group(1) if changelog_entry else None,
}

missing = [name for name, value in values.items() if value is None]
if missing:
    raise SystemExit("Missing WordPress release metadata: " + ", ".join(missing))

versions = set(values.values())
if len(versions) != 1:
    details = ", ".join(f"{name}={value}" for name, value in values.items())
    raise SystemExit("WordPress release metadata is out of sync: " + details)

print(next(iter(versions)))
PY
