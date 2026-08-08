#!/usr/bin/env bash
set -euo pipefail

APP_NAME="frontman_server"
DEPLOY_ROOT="/opt/frontman"
DOMAIN="api.frontman.sh"
HEALTH_PATH="/health"
HEALTH_TIMEOUT=30
HEALTH_INTERVAL=2
KEEP_RELEASES=3

if [ $# -lt 1 ]; then
  echo "Usage: $0 <path-to-release.tar.gz>"
  exit 1
fi

TARBALL="$1"
if [ ! -f "${TARBALL}" ]; then
  echo "ERROR: Tarball not found: ${TARBALL}"
  exit 1
fi

echo "=== Frontman Deploy ==="
echo "Tarball: ${TARBALL}"
echo ""

ACTIVE_SLOT=$(cat "${DEPLOY_ROOT}/active_slot" 2>/dev/null || echo "blue")

if [ "${ACTIVE_SLOT}" = "blue" ]; then
  INACTIVE_SLOT="green"
  INACTIVE_PORT=4001
else
  INACTIVE_SLOT="blue"
  INACTIVE_PORT=4000
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
set -a
source "${DEPLOY_ROOT}/${INACTIVE_SLOT}/env"
set +a
"${DEPLOY_ROOT}/${INACTIVE_SLOT}/current/bin/migrate"
echo "Migrations complete."

echo ">>> Starting ${INACTIVE_SLOT} slot..."
sudo /usr/bin/systemctl restart "frontman-${INACTIVE_SLOT}"

echo ">>> Waiting for ${INACTIVE_SLOT} to become healthy (port ${INACTIVE_PORT})..."
ELAPSED=0
HEALTHY=false

while [ "${ELAPSED}" -lt "${HEALTH_TIMEOUT}" ]; do
  if curl -sf "http://localhost:${INACTIVE_PORT}${HEALTH_PATH}" > /dev/null 2>&1; then
    HEALTHY=true
    break
  fi
  sleep "${HEALTH_INTERVAL}"
  ELAPSED=$((ELAPSED + HEALTH_INTERVAL))
  echo "  Waiting... (${ELAPSED}s / ${HEALTH_TIMEOUT}s)"
done

if [ "${HEALTHY}" = false ]; then
  echo ""
  echo "FATAL: ${INACTIVE_SLOT} failed health check after ${HEALTH_TIMEOUT}s!"
  echo "Stopping ${INACTIVE_SLOT}, keeping ${ACTIVE_SLOT} active."
  echo ""
  echo "Check logs: journalctl -u frontman-${INACTIVE_SLOT} -n 50"
  sudo /usr/bin/systemctl stop "frontman-${INACTIVE_SLOT}"
  exit 1
fi

echo "${INACTIVE_SLOT} is healthy!"
echo ""

echo ">>> Switching Caddy to ${INACTIVE_SLOT} (port ${INACTIVE_PORT})..."
cat > /tmp/Caddyfile.new <<EOF
${DOMAIN} {
    reverse_proxy localhost:${INACTIVE_PORT}
}
EOF
sudo mv /tmp/Caddyfile.new /etc/caddy/Caddyfile
sudo /usr/bin/systemctl reload caddy
echo "Caddy reloaded. Traffic now routed to ${INACTIVE_SLOT}."

echo "${INACTIVE_SLOT}" > "${DEPLOY_ROOT}/active_slot"
"${DEPLOY_ROOT}/monitoring/update-active-slot.sh" || true

echo ">>> Draining old slot (${ACTIVE_SLOT})..."
sleep 5
sudo /usr/bin/systemctl stop "frontman-${ACTIVE_SLOT}"
echo "Old slot stopped."

echo ">>> Cleaning old releases..."
for SLOT in blue green; do
  RELEASES_DIR="${DEPLOY_ROOT}/${SLOT}/releases"
  if [ -d "${RELEASES_DIR}" ]; then
    RELEASE_COUNT=$(ls -1d "${RELEASES_DIR}"/*/ 2>/dev/null | wc -l)
    if [ "${RELEASE_COUNT}" -gt "${KEEP_RELEASES}" ]; then
      REMOVE_COUNT=$((RELEASE_COUNT - KEEP_RELEASES))
      ls -1d "${RELEASES_DIR}"/*/ | head -n "${REMOVE_COUNT}" | while read -r OLD_RELEASE; do
        CURRENT_TARGET=$(readlink -f "${DEPLOY_ROOT}/${SLOT}/current" 2>/dev/null || echo "")
        if [ "${OLD_RELEASE%/}" != "${CURRENT_TARGET}" ]; then
          echo "  Removing old release: ${OLD_RELEASE}"
          rm -rf "${OLD_RELEASE}"
        fi
      done
    fi
  fi
done

rm -f "${TARBALL}"

echo ""
echo "=== Deploy Complete ==="
echo "Active slot: ${INACTIVE_SLOT} (port ${INACTIVE_PORT})"
echo "Previous slot (${ACTIVE_SLOT}) stopped."
echo ""
