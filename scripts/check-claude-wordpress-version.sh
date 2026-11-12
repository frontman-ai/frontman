#!/usr/bin/env bash
set -euo pipefail
base=${1:?Usage: check-claude-wordpress-version.sh BASE [HEAD]}
head=${2:-HEAD}
dir=plugins/claude-wordpress
manifest="$dir/.claude-plugin/plugin.json"
git rev-parse --verify "$base^{commit}" >/dev/null
git rev-parse --verify "$head^{commit}" >/dev/null
if git diff --quiet "$base" "$head" -- "$dir"; then
  echo "No Claude WordPress source changes"
  exit 0
fi
version_at() {
  git show "$1:$manifest" | jq -er '
    .version | select(type == "string" and test("^(0|[1-9][0-9]*)\\.(0|[1-9][0-9]*)\\.(0|[1-9][0-9]*)$"))
  '
}
new=$(version_at "$head") || { echo "Missing or invalid head manifest version" >&2; exit 1; }
if ! git cat-file -e "$base:$manifest" 2>/dev/null; then
  if [ -n "$(git ls-tree "$base" -- "$dir")" ]; then
    echo "Base source exists without its manifest" >&2
    exit 1
  fi
  echo "Initial Claude WordPress source addition: $new"
  exit 0
fi
old=$(version_at "$base") || { echo "Invalid base manifest version" >&2; exit 1; }
IFS=. read -r -a old_parts <<< "$old"
IFS=. read -r -a new_parts <<< "$new"
for i in 0 1 2; do
  a=${new_parts[$i]}
  b=${old_parts[$i]}
  if [ "${#a}" -gt "${#b}" ] || { [ "${#a}" -eq "${#b}" ] && [[ "$a" > "$b" ]]; }; then
    echo "Claude WordPress version increased: $old -> $new"
    exit 0
  fi
  if [ "$a" != "$b" ]; then break; fi
done
echo "Claude WordPress source changed without a version increase: $old -> $new" >&2
exit 1
