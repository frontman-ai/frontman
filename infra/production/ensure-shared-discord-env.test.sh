#!/usr/bin/env bash
set -euo pipefail

ROOT=$(mktemp -d)
trap 'rm -rf "${ROOT}"' EXIT
LEGACY_ENV="${ROOT}/notifier.env"
SHARED_ENV="${ROOT}/shared/discord.env"

printf '%s\n' 'DISCORD_TASK_SUMMARIES_WEBHOOK_URL=https://discord.test/task' > "${LEGACY_ENV}"
SHARED_ENV="${SHARED_ENV}" LEGACY_ENV="${LEGACY_ENV}" \
  bash "$(dirname "$0")/ensure-shared-discord-env.sh"

test "$(cat "${SHARED_ENV}")" = \
  'DISCORD_TASK_SUMMARIES_WEBHOOK_URL=https://discord.test/task'
test "$(stat -c '%a' "${SHARED_ENV}")" = 600
