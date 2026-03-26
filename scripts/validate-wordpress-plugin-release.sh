#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(git rev-parse --show-toplevel)"
FRONTMAN_PHP="$ROOT_DIR/libs/frontman-wordpress/frontman.php"
README_TXT="$ROOT_DIR/libs/frontman-wordpress/readme.txt"

header_version=$(sed -nE 's/^[[:space:]]*\*[[:space:]]*Version:[[:space:]]*([0-9]+\.[0-9]+\.[0-9]+)[[:space:]]*$/\1/p' "$FRONTMAN_PHP" | head -n 1)
constant_version=$(sed -nE "s/^define\([[:space:]]*'FRONTMAN_VERSION',[[:space:]]*'([0-9]+\.[0-9]+\.[0-9]+)'[[:space:]]*\);$/\1/p" "$FRONTMAN_PHP" | head -n 1)
stable_tag=$(sed -nE 's/^Stable tag:[[:space:]]*([0-9]+\.[0-9]+\.[0-9]+)[[:space:]]*$/\1/p' "$README_TXT" | head -n 1)
changelog_entry=$(sed -nE 's/^= ([0-9]+\.[0-9]+\.[0-9]+) =$/\1/p' "$README_TXT" | head -n 1)

missing=()
[ -n "$header_version" ] || missing+=("Plugin header")
[ -n "$constant_version" ] || missing+=("FRONTMAN_VERSION")
[ -n "$stable_tag" ] || missing+=("Stable tag")
[ -n "$changelog_entry" ] || missing+=("Top changelog entry")

if [ "${#missing[@]}" -gt 0 ]; then
  printf 'Missing WordPress release metadata: %s\n' "$(IFS=', '; echo "${missing[*]}")" >&2
  exit 1
fi

if [ "$header_version" != "$constant_version" ] || [ "$header_version" != "$stable_tag" ] || [ "$header_version" != "$changelog_entry" ]; then
  printf 'WordPress release metadata is out of sync: Plugin header=%s, FRONTMAN_VERSION=%s, Stable tag=%s, Top changelog entry=%s\n' \
    "$header_version" "$constant_version" "$stable_tag" "$changelog_entry" >&2
  exit 1
fi

printf '%s\n' "$header_version"
