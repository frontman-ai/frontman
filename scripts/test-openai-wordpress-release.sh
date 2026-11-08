#!/usr/bin/env bash
set -euo pipefail

source_root=$(cd "$(dirname "$0")/.." && pwd)
fixture=$(mktemp -d)
trap 'rm -rf "$fixture"' EXIT
git init -q "$fixture/repo"
cd "$fixture/repo"
git config user.name "Release test"
git config user.email "release-test@example.invalid"
git config commit.gpgSign false
git config tag.gpgSign false
git config core.hooksPath /dev/null
mkdir -p plugins/openai-wordpress apps/marketing/public scripts .changeset
cp "$source_root"/plugins/openai-wordpress/{plugin.json,mcp.json,validate.mts,release.mts,Makefile} plugins/openai-wordpress/
cp "$source_root/apps/marketing/public/favicon.svg" apps/marketing/public/
cp "$source_root/scripts/openai-wordpress-release-needed.sh" scripts/

commit() {
  git add .
  GIT_EDITOR=true git commit --allow-empty -qm "$1"
}
expect() {
  actual=$(bash scripts/openai-wordpress-release-needed.sh)
  [ "$actual" = "$1" ] || {
    echo "Expected $1, got $actual: $2" >&2
    exit 1
  }
  echo "PASS: $2"
}

commit initial
expect true "first release needs a candidate"
GIT_EDITOR=true git tag v1.0.0
expect true "retry of first release still needs a candidate"
commit "next release"
expect false "unchanged package skips candidate"

printf 'Documentation only\n' > plugins/openai-wordpress/README.md
printf '%s\n' '---' '---' 'Unrelated changeset' > .changeset/unrelated.md
commit docs
expect false "docs and unrelated changesets do not force a candidate"

for path in \
  plugins/openai-wordpress/plugin.json \
  plugins/openai-wordpress/mcp.json \
  apps/marketing/public/favicon.svg \
  plugins/openai-wordpress/validate.mts \
  plugins/openai-wordpress/release.mts \
  plugins/openai-wordpress/Makefile \
  scripts/openai-wordpress-release-needed.sh; do
  printf '\n' >> "$path"
  commit "change $path"
  expect true "$path triggers a candidate"
  GIT_EDITOR=true git tag -f v1.0.0 >/dev/null
  expect true "current release tag does not hide changed inputs on retry"
  commit "next release"
  expect false "released input change does not trigger again"
done

base_branch=$(git branch --show-current)
git checkout -qb release-test
printf 'Release notes\n' > CHANGELOG.md
commit "prepare release PR"
expect false "release PR starts without package changes"
git checkout -q "$base_branch"
printf '\n' >> plugins/openai-wordpress/mcp.json
commit "package change while PR is open"
GIT_EDITOR=true git merge -q --no-ff release-test -m "merge release PR"
expect true "merged release includes the late package change"
GIT_EDITOR=true git tag -f v1.0.0 >/dev/null
expect true "merged release retry still includes the candidate"
commit "next release"
expect false "next release does not repeat the candidate"

printf '\n' >> plugins/openai-wordpress/plugin.json
expect false "uncommitted release metadata does not affect detection"
git checkout -- plugins/openai-wordpress/plugin.json

git clone -q --depth=1 "file://$fixture/repo" "$fixture/shallow"
cd "$fixture/shallow"
if bash scripts/openai-wordpress-release-needed.sh >"$fixture/output" 2>"$fixture/error"; then
  echo "Shallow history must fail rather than silently skip a candidate" >&2
  exit 1
fi
grep -q 'requires full Git history' "$fixture/error"
echo "PASS: shallow history fails"
