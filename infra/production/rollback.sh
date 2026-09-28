#!/usr/bin/env bash
set -euo pipefail

DEPLOY_ROOT="${DEPLOY_ROOT:-/opt/frontman}"
DOMAIN="${DOMAIN:-api.frontman.sh}"
HEALTH_PATH="/health/ready"
HEALTH_TIMEOUT="${HEALTH_TIMEOUT:-30}"
HEALTH_INTERVAL="${HEALTH_INTERVAL:-2}"

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

  echo "FATAL: ${slot} failed readiness check after ${HEALTH_TIMEOUT}s. Cannot rollback."
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

echo "=== Frontman Rollback ==="

CURRENT_SLOT=$(cat "${DEPLOY_ROOT}/active_slot" 2>/dev/null || echo "blue")
ROLLBACK_SLOT=$(other_slot "${CURRENT_SLOT}")
ROLLBACK_PORT=$(slot_port "${ROLLBACK_SLOT}")

echo "Current active: ${CURRENT_SLOT}"
echo "Rolling back to: ${ROLLBACK_SLOT} (port ${ROLLBACK_PORT})"
echo ""

if [ ! -L "${DEPLOY_ROOT}/${ROLLBACK_SLOT}/current" ]; then
  echo "ERROR: No release found for ${ROLLBACK_SLOT} slot."
  echo "Cannot rollback - no previous deployment exists."
  exit 1
fi

if [ ! -f "${DEPLOY_ROOT}/${ROLLBACK_SLOT}/env" ]; then
  echo "ERROR: Missing environment file: ${DEPLOY_ROOT}/${ROLLBACK_SLOT}/env"
  exit 1
fi

echo ">>> Starting ${ROLLBACK_SLOT} slot..."
sudo /usr/bin/systemctl start "frontman-${ROLLBACK_SLOT}"

wait_for_readiness "${ROLLBACK_SLOT}" "${ROLLBACK_PORT}"

echo ">>> Switching Caddy to ${ROLLBACK_SLOT} (port ${ROLLBACK_PORT})..."
switch_caddy "${ROLLBACK_SLOT}" "${ROLLBACK_PORT}"

echo "${ROLLBACK_SLOT}" > "${DEPLOY_ROOT}/active_slot"
if [ -x "${DEPLOY_ROOT}/monitoring/update-active-slot.sh" ]; then
  "${DEPLOY_ROOT}/monitoring/update-active-slot.sh" || true
fi

echo ">>> Stopping failed slot (${CURRENT_SLOT})..."
sudo /usr/bin/systemctl stop "frontman-${CURRENT_SLOT}" || true

echo ""
echo "=== Rollback Complete ==="
echo "Active slot: ${ROLLBACK_SLOT} (port ${ROLLBACK_PORT})"
echo ""
