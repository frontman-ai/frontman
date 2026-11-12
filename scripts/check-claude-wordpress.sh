#!/usr/bin/env bash
set -euo pipefail

root=$(cd "$(dirname "$0")/.." && pwd)
bundle=${1:-"$root/plugins/claude-wordpress"}
mode=${2:-source}
validator=${CLAUDE_BIN:-"$root/dist/claude-wordpress-validator/claude"}
config="$root/dist/claude-wordpress-validator/config"
fail() { echo "Claude WordPress check: $*" >&2; exit 1; }
[ "$mode" = source ] || [ "$mode" = archive ] || fail "unknown mode"
[ -d "$bundle" ] && [ ! -L "$bundle" ] || fail "bundle must be a directory"
while IFS= read -r -d '' path; do
  rel=${path#"$bundle"/}
  [ ! -L "$path" ] || fail "symlink: $rel"
  if [ -d "$path" ]; then
    case "$rel" in .claude-plugin|skills|skills/wordpress) ;; *) fail "unexpected directory: $rel" ;; esac
  elif [ -f "$path" ]; then
    case "$rel" in
      .claude-plugin/plugin.json|.mcp.json|skills/wordpress/SKILL.md|README.md) ;;
      Makefile|.gitignore) [ "$mode" = source ] || fail "development file in archive: $rel" ;;
      *) fail "unexpected file: $rel" ;;
    esac
  else
    fail "not a regular file: $rel"
  fi
done < <(find "$bundle" -mindepth 1 -print0)
for file in .claude-plugin/plugin.json .mcp.json skills/wordpress/SKILL.md README.md; do
  [ -f "$bundle/$file" ] || fail "missing $file"
done
if [ "$mode" = source ]; then
  for file in Makefile .gitignore; do [ -f "$bundle/$file" ] || fail "missing $file"; done
fi

manifest="$bundle/.claude-plugin/plugin.json"
mcp="$bundle/.mcp.json"
for file in "$manifest" "$mcp"; do
  jq -se 'length == 1 and (.[0] | type == "object")' "$file" >/dev/null || fail "invalid JSON: $file"
  python3 -c '
import json, sys
def unique(pairs):
    result = {}
    for key, value in pairs:
        if key in result:
            raise ValueError("duplicate key: " + key)
        result[key] = value
    return result
with open(sys.argv[1], encoding="utf-8") as source:
    json.load(source, object_pairs_hook=unique)
' "$file" || fail "invalid or duplicate JSON key: $file"
done
jq -e '
  (keys == ["author","description","displayName","homepage","license","name","repository","version"]) and
  .name == "frontman-wordpress" and .displayName == "Frontman for WordPress" and
  (.version | type == "string" and test("^(0|[1-9][0-9]*)\\.(0|[1-9][0-9]*)\\.(0|[1-9][0-9]*)$")) and
  (.description | type == "string" and length > 0) and
  .author == {"name":"Boilerplate Ventures UG","email":"support@frontman.sh","url":"https://frontman.sh/"} and
  .homepage == "https://frontman.sh/" and .repository == "https://github.com/frontman-ai/frontman" and
  .license == "Apache-2.0"
' "$manifest" >/dev/null || fail "invalid manifest identity or fields"
jq -e '. == {"mcpServers":{"frontman":{"type":"http","url":"https://api.frontman.sh/mcp"}}}' "$mcp" >/dev/null || fail "invalid MCP configuration"
skill="$bundle/skills/wordpress/SKILL.md"
awk 'NR == 1 { if ($0 != "---") exit 1 } NR > 1 && $0 == "---" { found=1; exit } END { if (!found) exit 1 }' "$skill" || fail "missing skill frontmatter"
grep -qx 'name: wordpress' "$skill" || fail "wrong skill name"
grep -Eq '^description: .+' "$skill" || fail "missing skill description"
[ "$(wc -w < "$skill")" -ge 30 ] || fail "skill is too short"
prose_words=$(awk '
  /^[[:space:]]*```/ || /^[[:space:]]*~~~/ { fenced = !fenced; next }
  !fenced { print }
' "$bundle/README.md" | wc -w)
[ "$prose_words" -ge 40 ] || fail "README has fewer than 40 prose words"
grep -q 'Apache-2.0' "$bundle/README.md" || fail "missing license information"
if grep -Eiq '(\$\{[^}]+\}|sk-(ant-|proj-)?[[:alnum:]_-]{16,}|Bearer[[:space:]]+[[:alnum:]_.-]{12,}|-----BEGIN [A-Z ]*PRIVATE KEY-----)' "$manifest" "$mcp" "$skill" "$bundle/README.md"; then
  fail "credential or environment interpolation detected"
fi
[ -x "$validator" ] || fail "validator missing; run make -C plugins/claude-wordpress toolchain"
mkdir -p "$config"
version=$(CLAUDE_CONFIG_DIR="$config" DISABLE_AUTOUPDATER=1 "$validator" --version)
[ "$version" = "2.1.311 (Claude Code)" ] || fail "expected Claude Code 2.1.311, got: $version"
CLAUDE_CONFIG_DIR="$config" DISABLE_AUTOUPDATER=1 "$validator" plugin validate --strict "$bundle"
