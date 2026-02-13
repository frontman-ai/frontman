#!/usr/bin/env bash
# =============================================================================
# Frontman Build & Deploy Script (runs on production server)
#
# CI rsyncs the source code to /opt/frontman/build, then invokes this script.
# It builds the Elixir release natively, then does a blue-green deploy.
#
# Usage: build-and-deploy.sh
# =============================================================================
set -euo pipefail

# --- Configuration ---
APP_NAME="frontman_server"
DEPLOY_ROOT="/opt/frontman"
BUILD_DIR="${DEPLOY_ROOT}/build"
DOMAIN="api.frontman.sh"
HEALTH_PATH="/health"
HEALTH_TIMEOUT=30
HEALTH_INTERVAL=2
KEEP_RELEASES=3

# --- Activate mise ---
export PATH="/home/deploy/.local/bin:${PATH}"
eval "$(mise activate bash --shims)"

echo "=== Frontman Build & Deploy ==="
echo "Build dir: ${BUILD_DIR}"
echo ""

# =============================================================================
# Phase 1: Build
# =============================================================================
cd "${BUILD_DIR}"

echo ">>> Installing JS dependencies..."
yarn install --immutable

echo ">>> Building ReScript..."
yarn rescript clean && yarn rescript build

echo ">>> Installing Elixir dependencies..."
cd "${BUILD_DIR}/apps/frontman_server"
export MIX_ENV=prod

mix local.hex --force --if-missing
mix local.rebar --force --if-missing
mix deps.get --only prod

echo ">>> Compiling Elixir deps..."
mix deps.compile

echo ">>> Installing Tailwind & esbuild..."
mix tailwind.install --if-missing
mix esbuild.install --if-missing

echo ">>> Compiling application..."
mix compile

echo ">>> Building assets..."
mix tailwind frontman_server --minify
mix esbuild frontman_server --minify
mix esbuild browser_test --minify
mix phx.digest

echo ">>> Building release..."
mix release

echo ""
echo "=== Build Complete ==="
echo ""

# =============================================================================
# Phase 2: Blue-Green Deploy
# =============================================================================

# --- Determine active/inactive slots ---
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

# --- Copy release to inactive slot ---
TIMESTAMP=$(date +%Y%m%d%H%M%S)
RELEASE_DIR="${DEPLOY_ROOT}/${INACTIVE_SLOT}/releases/${TIMESTAMP}"
RELEASE_TAR="${BUILD_DIR}/apps/frontman_server/_build/prod/frontman_server-0.0.1.tar.gz"

if [ ! -f "${RELEASE_TAR}" ]; then
  echo "ERROR: Release tarball not found: ${RELEASE_TAR}"
  exit 1
fi

echo ">>> Extracting release to ${RELEASE_DIR}..."
mkdir -p "${RELEASE_DIR}"
tar -xzf "${RELEASE_TAR}" -C "${RELEASE_DIR}"

# --- Atomic symlink swap ---
echo ">>> Swapping symlink to new release..."
ln -sfn "${RELEASE_DIR}" "${DEPLOY_ROOT}/${INACTIVE_SLOT}/current.tmp"
mv -T "${DEPLOY_ROOT}/${INACTIVE_SLOT}/current.tmp" "${DEPLOY_ROOT}/${INACTIVE_SLOT}/current"

# --- Run database migrations ---
echo ">>> Running database migrations..."
set -a
source "${DEPLOY_ROOT}/${INACTIVE_SLOT}/env"
set +a
"${DEPLOY_ROOT}/${INACTIVE_SLOT}/current/bin/migrate"
echo "Migrations complete."

# --- Restart inactive slot ---
echo ">>> Starting ${INACTIVE_SLOT} slot..."
sudo /bin/systemctl restart "frontman-${INACTIVE_SLOT}"

# --- Health check loop ---
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
  sudo /bin/systemctl stop "frontman-${INACTIVE_SLOT}"
  exit 1
fi

echo "${INACTIVE_SLOT} is healthy!"
echo ""

# --- Switch Caddy to new slot ---
echo ">>> Switching Caddy to ${INACTIVE_SLOT} (port ${INACTIVE_PORT})..."
cat > /tmp/Caddyfile.new <<EOF
${DOMAIN} {
    reverse_proxy localhost:${INACTIVE_PORT}
}
EOF
cp /tmp/Caddyfile.new /etc/caddy/Caddyfile && rm /tmp/Caddyfile.new
sudo /bin/systemctl reload caddy
echo "Caddy reloaded. Traffic now routed to ${INACTIVE_SLOT}."

# --- Update active slot marker ---
echo "${INACTIVE_SLOT}" > "${DEPLOY_ROOT}/active_slot"

# --- Stop old slot (after brief drain period) ---
echo ">>> Draining old slot (${ACTIVE_SLOT})..."
sleep 5
sudo /bin/systemctl stop "frontman-${ACTIVE_SLOT}" 2>/dev/null || true
echo "Old slot stopped."

# --- Clean up old releases (keep last N) ---
echo ">>> Cleaning old releases..."
for SLOT in blue green; do
  RELEASES_DIR="${DEPLOY_ROOT}/${SLOT}/releases"
  if [ -d "${RELEASES_DIR}" ]; then
    RELEASES=$(find "${RELEASES_DIR}" -mindepth 1 -maxdepth 1 -type d | sort)
    RELEASE_COUNT=$(echo "${RELEASES}" | grep -c . || true)
    if [ "${RELEASE_COUNT}" -gt "${KEEP_RELEASES}" ]; then
      REMOVE_COUNT=$((RELEASE_COUNT - KEEP_RELEASES))
      CURRENT_TARGET=$(readlink -f "${DEPLOY_ROOT}/${SLOT}/current" 2>/dev/null || echo "")
      echo "${RELEASES}" | head -n "${REMOVE_COUNT}" | while read -r OLD_RELEASE; do
        if [ -n "${OLD_RELEASE}" ] && [ "${OLD_RELEASE}" != "${CURRENT_TARGET}" ]; then
          echo "  Removing old release: ${OLD_RELEASE}"
          rm -rf "${OLD_RELEASE}"
        fi
      done
    fi
  fi
done

echo ""
echo "=== Deploy Complete ==="
echo "Active slot: ${INACTIVE_SLOT} (port ${INACTIVE_PORT})"
echo "Previous slot (${ACTIVE_SLOT}) stopped."
echo ""
