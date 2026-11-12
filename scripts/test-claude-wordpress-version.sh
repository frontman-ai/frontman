#!/usr/bin/env bash
set -euo pipefail
root=$(cd "$(dirname "$0")/.." && pwd)
guard="$root/scripts/check-claude-wordpress-version.sh"
tmp=$(mktemp -d "${TMPDIR:-/tmp}/frontman-claude-version.XXXXXX")
trap 'rm -rf "$tmp"' EXIT
export GIT_CONFIG_NOSYSTEM=1 GIT_CONFIG_GLOBAL=/dev/null
git init -q "$tmp/repo"
cd "$tmp/repo"
export GIT_AUTHOR_NAME='Version test' GIT_COMMITTER_NAME='Version test'
export GIT_AUTHOR_EMAIL='version-test@example.invalid' GIT_COMMITTER_EMAIL='version-test@example.invalid'
commit() { git add -A && GIT_EDITOR=true git -c commit.gpgsign=false commit -qm "$1"; }
echo baseline > unrelated
commit baseline
base=$(git rev-parse HEAD)
mkdir -p plugins
cp -R "$root/plugins/claude-wordpress" plugins/claude-wordpress
jq '.version = "1.0.0"' plugins/claude-wordpress/.claude-plugin/plugin.json > "$tmp/manifest"
cp "$tmp/manifest" plugins/claude-wordpress/.claude-plugin/plugin.json
commit initial
initial=$(git rev-parse HEAD)
bash "$guard" "$base" "$initial"

echo unrelated-change >> unrelated
commit unrelated
bash "$guard" "$initial" HEAD

echo change >> plugins/claude-wordpress/README.md
commit unchanged-version
unchanged=$(git rev-parse HEAD)
if bash "$guard" "$initial" "$unchanged"; then
  echo "Unchanged version was accepted" >&2; exit 1
fi
jq '.version = "0.9.9"' plugins/claude-wordpress/.claude-plugin/plugin.json > "$tmp/manifest"
cp "$tmp/manifest" plugins/claude-wordpress/.claude-plugin/plugin.json
commit decrease
if bash "$guard" "$initial" HEAD; then
  echo "Decreased version was accepted" >&2; exit 1
fi
jq '.version = "1.0.1"' plugins/claude-wordpress/.claude-plugin/plugin.json > "$tmp/manifest"
cp "$tmp/manifest" plugins/claude-wordpress/.claude-plugin/plugin.json
commit increase
bash "$guard" "$initial" HEAD

echo development-change >> plugins/claude-wordpress/Makefile
commit development-file
if bash "$guard" HEAD^ HEAD; then
  echo "Changed development file without a bump was accepted" >&2; exit 1
fi
echo "Claude WordPress version tests passed"
