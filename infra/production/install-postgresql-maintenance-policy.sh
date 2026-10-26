#!/usr/bin/env bash
set -euo pipefail

ROOT="${ROOT:-/}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEST="${ROOT%/}/etc/needrestart/conf.d/90-frontman-postgresql.conf"

if [ "$#" -ne 0 ] || [[ "${ROOT}" != /* ]]; then
  echo "Usage: ROOT=/absolute/fixture bash $0 (default ROOT=/)" >&2
  exit 1
fi

perl -c "${SCRIPT_DIR}/needrestart-postgresql.conf"
install -d -m 0755 "$(dirname "${DEST}")"
if [ -L "${DEST}" ]; then
  echo "ERROR: refusing to replace a symlink: ${DEST}" >&2
  exit 1
fi
if [ -f "${DEST}" ] && cmp -s "${SCRIPT_DIR}/needrestart-postgresql.conf" "${DEST}"; then
  echo "PostgreSQL maintenance policy is unchanged."
else
  install -m 0644 "${SCRIPT_DIR}/needrestart-postgresql.conf" "${DEST}"
  echo "Installed PostgreSQL maintenance policy: ${DEST}"
fi
