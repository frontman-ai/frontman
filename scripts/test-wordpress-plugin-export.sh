#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(git rev-parse --show-toplevel)"
VERSION="$(bash "$ROOT_DIR/scripts/validate-wordpress-plugin-release.sh")"
EXPORT_DIR="$ROOT_DIR/dist/frontman-wordpress-org-v${VERSION}"
TEMP_DIR="$(mktemp -d)"
PROBE_DIR="$(mktemp -d "$EXPORT_DIR/trunk/export-test.XXXXXX")"
trap 'rm -rf "$TEMP_DIR" "$PROBE_DIR"' EXIT

cat > "$TEMP_DIR/svn" <<'SVN'
#!/usr/bin/env bash
set -euo pipefail
case "$1" in
  checkout)
    mkdir -p "${@: -1}/tags/previous-release"
    printf 'keep this release\n' > "${@: -1}/tags/previous-release/readme.txt"
    ;;
  status)
    grep -qx 'keep this release' "$2/tags/previous-release/readme.txt"
    printf 'M       %s/trunk/readme.txt\n' "$2"
    ;;
  add|propset) ;;
  *) printf 'Unexpected SVN operation: %s\n' "$1" >&2; exit 99 ;;
esac
SVN
chmod +x "$TEMP_DIR/svn"
check_publish_status() {
  local expected="$1" status=0
  PATH="$TEMP_DIR:$PATH" DRY_RUN=1 WORDPRESS_ORG_USERNAME=test WORDPRESS_ORG_PASSWORD=test \
    bash "$ROOT_DIR/scripts/publish-wordpress-plugin-svn.sh" "$VERSION" > "$TEMP_DIR/output" 2>&1 || status=$?
  if [[ "$status" != "$expected" ]]; then
    cat "$TEMP_DIR/output" >&2
    printf 'Expected publisher exit %s, got %s\n' "$expected" "$status" >&2
    exit 1
  fi
}

while IFS= read -r -d '' source; do
  relative="${source#"$ROOT_DIR/dist/wordpress-dependencies-scoped/vendor/"}"
  for vendor in "$EXPORT_DIR/trunk/vendor" "$EXPORT_DIR/tags/$VERSION/vendor" \
    "$ROOT_DIR/dist/frontman-wordpress-package/github/frontman-agentic-ai-editor/vendor"; do
    cmp "$source" "$vendor/$relative"
  done
done < <(find "$ROOT_DIR/dist/wordpress-dependencies-scoped/vendor" -type f \
  \( -name '*.php' -o -iname 'LICENSE*' -o -iname 'COPYING*' -o -iname 'NOTICE*' -o -iname 'AUTHORS*' \) -print0)

check_publish_status 0
grep -q 'DRY_RUN=1; skipping WordPress.org SVN commit' "$TEMP_DIR/output"
for forbidden in unexpected.sh .env; do
  printf 'not for publication\n' > "$PROBE_DIR/$forbidden"
  check_publish_status 1
  grep -q 'Refusing to publish WordPress.org export' "$TEMP_DIR/output"
  rm "$PROBE_DIR/$forbidden"
done
printf 'OK: export scans pass, runtime and attribution files preserved, old tags retained, forbidden files rejected\n'
