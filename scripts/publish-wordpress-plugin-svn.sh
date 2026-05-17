#!/usr/bin/env bash

set -euo pipefail

if [ "$#" -gt 1 ]; then
  printf 'Usage: %s [version]\n' "$0" >&2
  exit 1
fi

ROOT_DIR="$(git rev-parse --show-toplevel)"
VERSION="${1:-${VERSION:-}}"

if [ -z "$VERSION" ]; then
  VERSION="$(bash "$ROOT_DIR/scripts/validate-wordpress-plugin-release.sh")"
fi

EXPORT_DIR="$ROOT_DIR/dist/frontman-wordpress-org-v${VERSION}"
SVN_URL="${WORDPRESS_ORG_SVN_URL:-https://plugins.svn.wordpress.org/frontman-agentic-ai-editor}"
SVN_USERNAME="${WORDPRESS_ORG_USERNAME:-}"
SVN_PASSWORD="${WORDPRESS_ORG_PASSWORD:-}"
SVN_BIN="${SVN_BIN:-svn}"

if [ -z "$SVN_USERNAME" ] || [ -z "$SVN_PASSWORD" ]; then
  printf 'WORDPRESS_ORG_USERNAME and WORDPRESS_ORG_PASSWORD are required\n' >&2
  exit 1
fi

for command in "$SVN_BIN" rsync; do
  if ! command -v "$command" >/dev/null 2>&1; then
    printf 'Required command not found: %s\n' "$command" >&2
    exit 1
  fi
done

if [ ! -d "$EXPORT_DIR/trunk" ] || [ ! -d "$EXPORT_DIR/tags/$VERSION" ] || [ ! -d "$EXPORT_DIR/assets" ]; then
  printf 'WordPress.org export not found for version %s. Run: make package-wordpress-plugin VERSION=%s\n' "$VERSION" "$VERSION" >&2
  exit 1
fi

SVN_WC="$(mktemp -d)"
trap 'rm -rf "$SVN_WC"' EXIT

"$SVN_BIN" checkout --depth infinity "$SVN_URL" "$SVN_WC"

rsync -a --delete --exclude '.svn/' "$EXPORT_DIR/" "$SVN_WC/"

while IFS= read -r deleted_path; do
  [ -n "$deleted_path" ] || continue
  "$SVN_BIN" delete --force "$deleted_path"
done < <("$SVN_BIN" status "$SVN_WC" | awk '$1 == "!" {print substr($0, 9)}')

"$SVN_BIN" add --force "$SVN_WC"

for file in "$SVN_WC"/assets/*.png; do
  [ -e "$file" ] || continue
  "$SVN_BIN" propset svn:mime-type image/png "$file"
done

for file in "$SVN_WC"/assets/*.jpg "$SVN_WC"/assets/*.jpeg; do
  [ -e "$file" ] || continue
  "$SVN_BIN" propset svn:mime-type image/jpeg "$file"
done

for file in "$SVN_WC"/assets/*.gif; do
  [ -e "$file" ] || continue
  "$SVN_BIN" propset svn:mime-type image/gif "$file"
done

for file in "$SVN_WC"/assets/*.svg; do
  [ -e "$file" ] || continue
  "$SVN_BIN" propset svn:mime-type image/svg+xml "$file"
done

STATUS="$("$SVN_BIN" status "$SVN_WC")"

if [ -z "$STATUS" ]; then
  printf 'No WordPress.org SVN changes to publish for version %s\n' "$VERSION"
  exit 0
fi

printf '%s\n' "$STATUS"

if [ "${DRY_RUN:-}" = "1" ]; then
  printf 'DRY_RUN=1; skipping WordPress.org SVN commit for version %s\n' "$VERSION"
  exit 0
fi

printf '%s\n' "$SVN_PASSWORD" | "$SVN_BIN" commit \
  --non-interactive \
  --no-auth-cache \
  --username "$SVN_USERNAME" \
  --password-from-stdin \
  -m "Release ${VERSION}" \
  "$SVN_WC"
