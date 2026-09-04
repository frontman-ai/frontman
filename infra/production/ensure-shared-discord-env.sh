#!/usr/bin/env bash
set -euo pipefail

SHARED_ENV="${SHARED_ENV:-/opt/frontman/shared/discord.env}"
LEGACY_ENV="${LEGACY_ENV:-/opt/frontman-notifier/env}"
VARIABLE="DISCORD_TASK_SUMMARIES_WEBHOOK_URL"

if [ -f "${SHARED_ENV}" ]; then
  if grep -q "^${VARIABLE}=.\+" "${SHARED_ENV}" && ! grep -q "^${VARIABLE}=CHANGE_ME$" "${SHARED_ENV}"; then
    exit 0
  fi

  echo "ERROR: ${VARIABLE} is not configured in ${SHARED_ENV}"
  exit 1
fi

assignment=$(grep -m 1 "^${VARIABLE}=.\+" "${LEGACY_ENV}" 2>/dev/null || true)

if [ -z "${assignment}" ] || [ "${assignment}" = "${VARIABLE}=CHANGE_ME" ]; then
  echo "ERROR: ${VARIABLE} is not configured in ${LEGACY_ENV}"
  exit 1
fi

install -d -m 0700 "$(dirname "${SHARED_ENV}")"
umask 077
temporary_env="${SHARED_ENV}.tmp.$$"
trap 'rm -f "${temporary_env}"' EXIT
printf '%s\n' "${assignment}" > "${temporary_env}"
mv "${temporary_env}" "${SHARED_ENV}"
trap - EXIT

echo "Migrated ${VARIABLE} to ${SHARED_ENV}"
