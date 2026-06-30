#!/usr/bin/env bash
# =============================================================================
# Frontman Blue-Green Deploy Script
# =============================================================================
set -euo pipefail

APP_NAME="${APP_NAME:-frontman_server}"
DEPLOY_ROOT="${DEPLOY_ROOT:-/opt/frontman}"
DOMAIN="${DOMAIN:-api.frontman.sh}"
HEALTH_PATH="/health/ready"
HEALTH_TIMEOUT="${HEALTH_TIMEOUT:-30}"
HEALTH_INTERVAL="${HEALTH_INTERVAL:-2}"
DRAIN_TIMEOUT="${DRAIN_TIMEOUT:-300}"
DRAIN_INTERVAL="${DRAIN_INTERVAL:-5}"
KEEP_RELEASES="${KEEP_RELEASES:-3}"

if [ $# -lt 1 ]; then
  echo "Usage: $0 <path-to-release.tar.gz>"
  exit 1
fi

TARBALL="$1"
if [ ! -f "${TARBALL}" ]; then
  echo "ERROR: Tarball not found: ${TARBALL}"
  exit 1
fi

slot_port() {
  case "$1" in
    blue) echo 4000 ;;
    green) echo 4001 ;;
    *) echo "ERROR: invalid slot: $1" >&2; exit 1 ;;
  esac
}

other_slot() {
  case "$1" in
    blue) echo green ;;
    green) echo blue ;;
    *) echo "ERROR: invalid active slot in ${DEPLOY_ROOT}/active_slot: $1" >&2; exit 1 ;;
  esac
}

active_execution_count() {
  local output count

  if ! output=$(
    set -a
    # shellcheck disable=SC1090
    source "${DEPLOY_ROOT}/${ACTIVE_SLOT}/env"
    set +a
    "${DEPLOY_ROOT}/${ACTIVE_SLOT}/current/bin/${APP_NAME}" rpc \
      "SwarmAi.active_count(FrontmanServer.AgentRuntime)" 2>&1
  ); then
    echo "  WARNING: Could not read active execution count from ${ACTIVE_SLOT}: ${output}" >&2
    return 1
  fi

  count=$(printf '%s\n' "${output}" | awk 'NF { last=$0 } END { print last }')

  if [[ ! "${count}" =~ ^[0-9]+$ ]]; then
    echo "  WARNING: Invalid active execution count from ${ACTIVE_SLOT}: ${output}" >&2
    return 1
  fi

  echo "${count}"
}

wait_for_readiness() {
  local slot="$1"
  local port="$2"
  local elapsed=0

  echo ">>> Waiting for ${slot} readiness on http://localhost:${port}${HEALTH_PATH}..."

  while [ "${elapsed}" -lt "${HEALTH_TIMEOUT}" ]; do
    if curl -sf "http://localhost:${port}${HEALTH_PATH}" > /dev/null 2>&1; then
      echo "${slot} is ready!"
      return 0
    fi

    sleep "${HEALTH_INTERVAL}"
    elapsed=$((elapsed + HEALTH_INTERVAL))
    echo "  Waiting... (${elapsed}s / ${HEALTH_TIMEOUT}s)"
  done

  echo "FATAL: ${slot} failed readiness check after ${HEALTH_TIMEOUT}s!"
  echo "Check logs: journalctl -u frontman-${slot} -n 50"
  return 1
}

switch_caddy() {
  local slot="$1"
  local port="$2"
  local caddy_tmp="${DEPLOY_ROOT}/Caddyfile.${slot}.$$"

  cat > "${caddy_tmp}" <<EOF
${DOMAIN} {
    reverse_proxy localhost:${port}
}
EOF

  if ! /usr/bin/install -m 0644 "${caddy_tmp}" /etc/caddy/Caddyfile 2>/dev/null; then
    sudo /usr/bin/install -o root -g root -m 0644 "${caddy_tmp}" /etc/caddy/Caddyfile
  fi

  rm -f "${caddy_tmp}"
  sudo /usr/bin/systemctl reload caddy
}

drain_old_slot() {
  local elapsed=0
  local count

  echo ">>> Draining old slot (${ACTIVE_SLOT})..."

  while [ "${elapsed}" -lt "${DRAIN_TIMEOUT}" ]; do
    if ! count=$(active_execution_count); then
      echo "  Active execution count unavailable; waiting full ${DRAIN_TIMEOUT}s before stopping ${ACTIVE_SLOT}."
      sleep "${DRAIN_TIMEOUT}"
      return 0
    fi

    echo "  Active executions: ${count} (${elapsed}s / ${DRAIN_TIMEOUT}s)"

    if [ "${count}" -eq 0 ]; then
      echo "Drain complete after ${elapsed}s."
      return 0
    fi

    sleep "${DRAIN_INTERVAL}"
    elapsed=$((elapsed + DRAIN_INTERVAL))
  done

  if count=$(active_execution_count); then
    echo "Drain timeout after ${DRAIN_TIMEOUT}s; stopping ${ACTIVE_SLOT} with ${count} active executions remaining."
  else
    echo "Drain timeout after ${DRAIN_TIMEOUT}s; stopping ${ACTIVE_SLOT} with unknown active executions remaining."
  fi
}

cleanup_old_releases() {
  local slot releases_dir release_count remove_count current_target old_release

  echo ">>> Cleaning old releases..."

  for slot in blue green; do
    releases_dir="${DEPLOY_ROOT}/${slot}/releases"
    [ -d "${releases_dir}" ] || continue

    release_count=$(find "${releases_dir}" -mindepth 1 -maxdepth 1 -type d | wc -l)
    [ "${release_count}" -gt "${KEEP_RELEASES}" ] || continue

    remove_count=$((release_count - KEEP_RELEASES))
    current_target=$(readlink -f "${DEPLOY_ROOT}/${slot}/current" 2>/dev/null || echo "")

    find "${releases_dir}" -mindepth 1 -maxdepth 1 -type d | sort | head -n "${remove_count}" | while read -r old_release; do
      if [ "${old_release}" != "${current_target}" ]; then
        echo "  Removing old release: ${old_release}"
        rm -rf "${old_release}"
      fi
    done
  done
}

echo "=== Frontman Deploy ==="
echo "Tarball: ${TARBALL}"
echo ""

ACTIVE_SLOT=$(cat "${DEPLOY_ROOT}/active_slot" 2>/dev/null || echo "blue")
INACTIVE_SLOT=$(other_slot "${ACTIVE_SLOT}")
INACTIVE_PORT=$(slot_port "${INACTIVE_SLOT}")

if [ ! -f "${DEPLOY_ROOT}/${INACTIVE_SLOT}/env" ]; then
  echo "ERROR: Missing environment file: ${DEPLOY_ROOT}/${INACTIVE_SLOT}/env"
  exit 1
fi

if [ ! -f "${DEPLOY_ROOT}/${ACTIVE_SLOT}/env" ]; then
  echo "ERROR: Missing environment file: ${DEPLOY_ROOT}/${ACTIVE_SLOT}/env"
  exit 1
fi

echo "Active slot:   ${ACTIVE_SLOT}"
echo "Deploying to:  ${INACTIVE_SLOT} (port ${INACTIVE_PORT})"
echo ""

TIMESTAMP=$(date +%Y%m%d%H%M%S)
RELEASE_DIR="${DEPLOY_ROOT}/${INACTIVE_SLOT}/releases/${TIMESTAMP}"

echo ">>> Extracting release to ${RELEASE_DIR}..."
mkdir -p "${RELEASE_DIR}"
tar -xzf "${TARBALL}" -C "${RELEASE_DIR}"

echo ">>> Swapping symlink to new release..."
ln -sfn "${RELEASE_DIR}" "${DEPLOY_ROOT}/${INACTIVE_SLOT}/current.tmp"
mv -T "${DEPLOY_ROOT}/${INACTIVE_SLOT}/current.tmp" "${DEPLOY_ROOT}/${INACTIVE_SLOT}/current"

echo ">>> Running database migrations..."
(
  set -a
  # shellcheck disable=SC1090
  source "${DEPLOY_ROOT}/${INACTIVE_SLOT}/env"
  set +a
  "${DEPLOY_ROOT}/${INACTIVE_SLOT}/current/bin/migrate"
)
echo "Migrations complete."

echo ">>> Starting ${INACTIVE_SLOT} slot..."
sudo /usr/bin/systemctl restart "frontman-${INACTIVE_SLOT}"

if ! wait_for_readiness "${INACTIVE_SLOT}" "${INACTIVE_PORT}"; then
  echo "Stopping ${INACTIVE_SLOT}, keeping ${ACTIVE_SLOT} active."
  sudo /usr/bin/systemctl stop "frontman-${INACTIVE_SLOT}"
  exit 1
fi

echo ""
echo ">>> Switching Caddy to ${INACTIVE_SLOT} (port ${INACTIVE_PORT})..."
switch_caddy "${INACTIVE_SLOT}" "${INACTIVE_PORT}"
echo "Caddy reloaded. Traffic now routed to ${INACTIVE_SLOT}."

echo "${INACTIVE_SLOT}" > "${DEPLOY_ROOT}/active_slot"
if [ -x "${DEPLOY_ROOT}/monitoring/update-active-slot.sh" ]; then
  "${DEPLOY_ROOT}/monitoring/update-active-slot.sh" || true
fi

drain_old_slot

sudo /usr/bin/systemctl stop "frontman-${ACTIVE_SLOT}"
echo "Old slot stopped."

cleanup_old_releases
rm -f "${TARBALL}"

echo ""
echo "=== Deploy Complete ==="
echo "Active slot: ${INACTIVE_SLOT} (port ${INACTIVE_PORT})"
echo "Previous slot (${ACTIVE_SLOT}) stopped."
echo ""
