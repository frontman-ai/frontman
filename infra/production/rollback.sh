#!/usr/bin/env bash
# =============================================================================
# Frontman Rollback Script
#
# Instantly rolls back to the previous deployment slot.
# The previous slot should still have its last release on disk.
#
# Usage: rollback.sh
# =============================================================================
set -euo pipefail

# --- Configuration ---
DEPLOY_ROOT="/opt/frontman"
DOMAIN="api.frontman.sh"
HEALTH_PATH="/health"
HEALTH_TIMEOUT=30
HEALTH_INTERVAL=2

echo "=== Frontman Rollback ==="

# --- Determine slots ---
CURRENT_SLOT=$(cat "${DEPLOY_ROOT}/active_slot" 2>/dev/null || echo "blue")

if [ "${CURRENT_SLOT}" = "blue" ]; then
  ROLLBACK_SLOT="green"
  ROLLBACK_PORT=4001
else
  ROLLBACK_SLOT="blue"
  ROLLBACK_PORT=4000
fi

echo "Current active: ${CURRENT_SLOT}"
echo "Rolling back to: ${ROLLBACK_SLOT} (port ${ROLLBACK_PORT})"
echo ""

# --- Verify rollback slot has a release ---
if [ ! -L "${DEPLOY_ROOT}/${ROLLBACK_SLOT}/current" ]; then
  echo "ERROR: No release found for ${ROLLBACK_SLOT} slot."
  echo "Cannot rollback - no previous deployment exists."
  exit 1
fi

# --- Start rollback slot if not running ---
echo ">>> Starting ${ROLLBACK_SLOT} slot..."
sudo /usr/bin/systemctl start "frontman-${ROLLBACK_SLOT}" 2>/dev/null || true

# --- Health check ---
echo ">>> Waiting for ${ROLLBACK_SLOT} to become healthy..."
ELAPSED=0
HEALTHY=false

while [ "${ELAPSED}" -lt "${HEALTH_TIMEOUT}" ]; do
  if curl -sf "http://localhost:${ROLLBACK_PORT}${HEALTH_PATH}" > /dev/null 2>&1; then
    HEALTHY=true
    break
  fi
  sleep "${HEALTH_INTERVAL}"
  ELAPSED=$((ELAPSED + HEALTH_INTERVAL))
  echo "  Waiting... (${ELAPSED}s / ${HEALTH_TIMEOUT}s)"
done

if [ "${HEALTHY}" = false ]; then
  echo ""
  echo "FATAL: ${ROLLBACK_SLOT} failed health check. Cannot rollback."
  echo "Check logs: journalctl -u frontman-${ROLLBACK_SLOT} -n 50"
  exit 1
fi

echo "${ROLLBACK_SLOT} is healthy!"

# --- Switch Caddy ---
echo ">>> Switching Caddy to ${ROLLBACK_SLOT} (port ${ROLLBACK_PORT})..."
cat > /tmp/Caddyfile.new <<EOF
${DOMAIN} {
    reverse_proxy localhost:${ROLLBACK_PORT}
}
EOF
sudo mv /tmp/Caddyfile.new /etc/caddy/Caddyfile
sudo /usr/bin/systemctl reload caddy

# --- Update active slot + monitoring metric ---
echo "${ROLLBACK_SLOT}" > "${DEPLOY_ROOT}/active_slot"
"${DEPLOY_ROOT}/monitoring/update-active-slot.sh" || true

# --- Stop the failed slot ---
echo ">>> Stopping failed slot (${CURRENT_SLOT})..."
sudo /usr/bin/systemctl stop "frontman-${CURRENT_SLOT}"

echo ""
echo "=== Rollback Complete ==="
echo "Active slot: ${ROLLBACK_SLOT} (port ${ROLLBACK_PORT})"
echo ""
