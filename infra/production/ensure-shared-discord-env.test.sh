#!/usr/bin/env bash
set -euo pipefail

ROOT=$(mktemp -d)
trap 'rm -rf "${ROOT}"' EXIT
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LEGACY_ENV="${ROOT}/notifier.env"
SHARED_ENV="${ROOT}/shared/discord.env"
VARIABLE="DISCORD_TASK_SUMMARIES_WEBHOOK_URL"
VALUE="https://discord.test/task?thread_id=123&wait=true"

printf '%s\n%s="%s"\n' "${VARIABLE}=CHANGE_ME" "${VARIABLE}" "${VALUE}" > "${LEGACY_ENV}"
SHARED_ENV="${SHARED_ENV}" LEGACY_ENV="${LEGACY_ENV}" \
  bash "${SCRIPT_DIR}/ensure-shared-discord-env.sh"

test "$(cat "${SHARED_ENV}")" = "${VARIABLE}=${VALUE}"
test "$(stat -c '%a' "${SHARED_ENV}")" = 600

for RELEASE_ENV in \
  "${SCRIPT_DIR}/../../apps/frontman_server/rel/env.sh.eex" \
  "${SCRIPT_DIR}/../../apps/frontman_notifier/rel/env.sh.eex"; do
  FRONTMAN_SHARED_ENV="${SHARED_ENV}" \
    DISCORD_TASK_SUMMARIES_WEBHOOK_URL="old-value" \
    sh -c '. "$1"; test "$DISCORD_TASK_SUMMARIES_WEBHOOK_URL" = "$2"' \
    shell "${RELEASE_ENV}" "${VALUE}"

  FRONTMAN_SHARED_ENV="${ROOT}/missing.env" \
    DISCORD_TASK_SUMMARIES_WEBHOOK_URL="${VALUE}" \
    sh -c '. "$1"; test "$DISCORD_TASK_SUMMARIES_WEBHOOK_URL" = "$2"; case "$-" in *e*|*u*) exit 1;; esac' \
    shell "${RELEASE_ENV}" "${VALUE}"

  if env -u DISCORD_TASK_SUMMARIES_WEBHOOK_URL \
    FRONTMAN_SHARED_ENV="${ROOT}/missing.env" \
    sh -c '. "$1"' shell "${RELEASE_ENV}" 2>/dev/null; then
    echo "ERROR: ${RELEASE_ENV} accepted missing webhook configuration"
    exit 1
  fi
done

printf '%s=%s\n%s=\n' "${VARIABLE}" "${VALUE}" "${VARIABLE}" > "${SHARED_ENV}"
if SHARED_ENV="${SHARED_ENV}" LEGACY_ENV="${LEGACY_ENV}" \
  bash "${SCRIPT_DIR}/ensure-shared-discord-env.sh" 2>/dev/null; then
  echo "ERROR: Accepted an empty final webhook assignment"
  exit 1
fi
