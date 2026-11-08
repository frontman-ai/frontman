#!/usr/bin/env bash
set -euo pipefail

# Compare the release commit, not the earlier release PR branch.
# Start at its first parent to exclude the current tag on upload retries.
if [ "$(git rev-parse --is-shallow-repository)" = true ]; then
  echo "OpenAI change detection requires full Git history." >&2
  exit 1
fi
previous=$(git describe --first-parent --tags --match 'v[0-9]*' --abbrev=0 HEAD^ 2>/dev/null || true)
if [ -z "$previous" ]; then
  echo true
  exit 0
fi

if git diff --quiet "$previous" HEAD -- \
  plugins/openai-wordpress/plugin.json \
  plugins/openai-wordpress/mcp.json \
  plugins/openai-wordpress/validate.mts \
  plugins/openai-wordpress/release.mts \
  plugins/openai-wordpress/Makefile \
  apps/marketing/public/favicon.svg \
  scripts/openai-wordpress-release-needed.sh; then
  echo false
else
  status=$?
  [ "$status" -eq 1 ] || exit "$status"
  echo true
fi
