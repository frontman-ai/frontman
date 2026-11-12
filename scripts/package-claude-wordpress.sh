#!/usr/bin/env bash
set -euo pipefail
root=$(cd "$(dirname "$0")/.." && pwd)
bundle=${1:-"$root/plugins/claude-wordpress"}
out=${2:-"$root/dist/claude-wordpress"}
files=(.claude-plugin/plugin.json .mcp.json skills/wordpress/SKILL.md README.md)
bash "$root/scripts/check-claude-wordpress.sh" "$bundle" source
version=$(jq -r .version "$bundle/.claude-plugin/plugin.json")
mkdir -p "$out"
out=$(cd "$out" && pwd)
archive="$out/frontman-claude-wordpress-v$version.zip"
tmp=$(mktemp -d "${TMPDIR:-/tmp}/frontman-claude-package.XXXXXX")
trap 'rm -rf "$tmp"' EXIT
(cd "$bundle" && zip -q -X "$tmp/bundle.zip" "${files[@]}")
unzip -Z1 "$tmp/bundle.zip" | LC_ALL=C sort > "$tmp/actual"
printf '%s\n' "${files[@]}" | LC_ALL=C sort > "$tmp/expected"
cmp "$tmp/expected" "$tmp/actual"
mkdir "$tmp/extracted"
unzip -q "$tmp/bundle.zip" -d "$tmp/extracted"
for file in "${files[@]}"; do cmp "$bundle/$file" "$tmp/extracted/$file"; done
bash "$root/scripts/check-claude-wordpress.sh" "$tmp/extracted" archive
mv "$tmp/bundle.zip" "$archive"
echo "Created $archive"
