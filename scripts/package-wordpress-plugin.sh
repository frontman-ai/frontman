#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(git rev-parse --show-toplevel)"
PLUGIN_SRC="$ROOT_DIR/libs/frontman-wordpress"
DIST_DIR="$ROOT_DIR/dist"
BUILD_DIR="$DIST_DIR/frontman-wordpress-package"
PLUGIN_DIR="$BUILD_DIR/frontman"

PLUGIN_VERSION="$(python3 - <<'PY'
import re
from pathlib import Path

text = Path('libs/frontman-wordpress/frontman.php').read_text()
match = re.search(r"Version:\s*([0-9]+\.[0-9]+\.[0-9]+)", text)
if not match:
    raise SystemExit('Could not determine Frontman plugin version')
print(match.group(1))
PY
)"

VERSION="${VERSION:-$PLUGIN_VERSION}"

if [ "$VERSION" != "$PLUGIN_VERSION" ]; then
  printf 'Requested VERSION %s does not match plugin version %s in libs/frontman-wordpress/frontman.php\n' "$VERSION" "$PLUGIN_VERSION" >&2
  exit 1
fi

ZIP_PATH="$DIST_DIR/frontman-wordpress-v${VERSION}.zip"

rm -rf "$BUILD_DIR" "$ZIP_PATH"
mkdir -p "$DIST_DIR"

rsync -a --delete --exclude '.DS_Store' --exclude 'tests/' "$PLUGIN_SRC/" "$PLUGIN_DIR/"

(
  cd "$BUILD_DIR"
  zip -rq "$ZIP_PATH" frontman
)

printf 'Created %s\n' "$ZIP_PATH"
