#!/usr/bin/env bash

set -euo pipefail

if [ "$#" -gt 1 ]; then
  printf 'Usage: %s [version]\n' "$0" >&2
  exit 1
fi

ROOT_DIR="$(git rev-parse --show-toplevel)"
VERSION="${1:-${VERSION:-}}"
FRONTMAN_PHP="$ROOT_DIR/libs/frontman-wordpress/frontman.php"
README_TXT="$ROOT_DIR/libs/frontman-wordpress/readme.txt"

if [ -z "$VERSION" ]; then
  printf 'Provide VERSION as an argument or environment variable\n' >&2
  exit 1
fi

export VERSION

tmp_frontman=$(mktemp)

awk -v version="$VERSION" '
  BEGIN {
    updated_header = 0
    updated_constant = 0
  }

  {
    if ($0 ~ /^[[:space:]]*\*[[:space:]]*Version:/) {
      if (sub(/[0-9]+\.[0-9]+\.[0-9]+/, version)) {
        updated_header += 1
      }
    }

    if ($0 ~ /FRONTMAN_VERSION/) {
      if (sub(/[0-9]+\.[0-9]+\.[0-9]+/, version)) {
        updated_constant += 1
      }
    }

    print
  }

  END {
    if (updated_header != 1 || updated_constant != 1) {
      exit 1
    }
  }
' "$FRONTMAN_PHP" > "$tmp_frontman" || {
  rm -f "$tmp_frontman"
  printf 'Could not update WordPress plugin version in frontman.php\n' >&2
  exit 1
}

mv "$tmp_frontman" "$FRONTMAN_PHP"

tmp_readme=$(mktemp)

awk -v version="$VERSION" '
  BEGIN {
    updated_stable_tag = 0
  }

  {
    if ($0 ~ /^Stable tag:/) {
      if (sub(/[0-9]+\.[0-9]+\.[0-9]+/, version)) {
        updated_stable_tag += 1
      }
    }

    print
  }

  END {
    if (updated_stable_tag != 1) {
      exit 1
    }
  }
' "$README_TXT" > "$tmp_readme" || {
  rm -f "$tmp_readme"
  printf 'Could not update Stable tag in readme.txt\n' >&2
  exit 1
}

mv "$tmp_readme" "$README_TXT"

existing_version=$(sed -nE 's/^= ([0-9]+\.[0-9]+\.[0-9]+) =$/\1/p' "$README_TXT" | head -n 1)

if [ "$existing_version" != "$VERSION" ]; then
  changelog_line=$(sed -n '/^== Changelog ==$/=' "$README_TXT" | head -n 1)
  first_entry_line=$(sed -n '/^= [0-9][0-9.]* =$/=' "$README_TXT" | head -n 1)

  if [ -z "$changelog_line" ] || [ -z "$first_entry_line" ]; then
    printf 'Could not update changelog entry in readme.txt\n' >&2
    exit 1
  fi

  tmp_readme=$(mktemp)
  sed -n "1,${changelog_line}p" "$README_TXT" > "$tmp_readme"
  printf '\n= %s =\n' "$VERSION" >> "$tmp_readme"
  printf '* Sync the Frontman plugin release with Frontman v%s\n' "$VERSION" >> "$tmp_readme"
  printf '* See the GitHub release notes for the full cross-product changelog\n\n' >> "$tmp_readme"
  sed -n "${first_entry_line},\$p" "$README_TXT" >> "$tmp_readme"
  mv "$tmp_readme" "$README_TXT"
fi

printf 'Synced WordPress plugin metadata to version %s\n' "$VERSION"
