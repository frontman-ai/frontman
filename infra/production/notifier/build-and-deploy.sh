#!/usr/bin/env bash
# =============================================================================
# Frontman Notifier Build & Deploy Script (runs on production server)
#
# CI rsyncs source code to /opt/frontman-notifier/build, then invokes this
# script. The notifier is a single worker service, so deployment is an atomic
# release symlink swap plus systemd restart.
# =============================================================================
set -euo pipefail

APP_NAME="frontman_notifier"
SERVICE_NAME="frontman-notifier"
DEPLOY_ROOT="/opt/frontman-notifier"
BUILD_DIR="${DEPLOY_ROOT}/build"
KEEP_RELEASES=3
HEX_ARCHIVE_URL="https://repo.hex.pm/installs/1.19.0/hex-2.4.2-otp-28.ez"
HEX_ARCHIVE_SHA512="c0cd156be5d7a6d4e2a39e09e8248f5c5b1681bca882caabcec4a76d1ae38c3ec29516c70f73cf9336dd6cf2fbb2feaa5145a82424c40454e8e9ee8ef9122c55"
REBAR_URL="https://s3.amazonaws.com/rebar3/rebar3"
REBAR_SHA512="0d00494d849fdc521a55142278d1f6ba552954fbd65b80d40df8022f594f05d6c99ed1d731bc263691a04176e11d4c6e126c56ba20dca19c5e42d4ffab2e7e36"

export PATH="/home/deploy/.local/bin:${PATH}"
mise trust "${BUILD_DIR}/mise.toml" >/dev/null
eval "$(mise activate bash --shims)"

echo "=== Frontman Notifier Build & Deploy ==="
echo "Build dir: ${BUILD_DIR}"
echo ""

ensure_elixir_build_tools() {
  echo "Installing pinned Hex archive..."
  HEX_TMP=$(mktemp -t hex.XXXXXX.ez)
  curl -fsSL "${HEX_ARCHIVE_URL}" -o "${HEX_TMP}"
  mix archive.install "${HEX_TMP}" --sha512 "${HEX_ARCHIVE_SHA512}" --force
  rm -f "${HEX_TMP}"

  echo "Installing pinned Rebar..."
  REBAR_TMP=$(mktemp -t rebar3.XXXXXX)
  curl -fsSL "${REBAR_URL}" -o "${REBAR_TMP}"
  chmod +x "${REBAR_TMP}"
  mix local.rebar rebar3 "${REBAR_TMP}" --sha512 "${REBAR_SHA512}" --force
  rm -f "${REBAR_TMP}"
}

cd "${BUILD_DIR}/apps/frontman_notifier"
export MIX_ENV=prod

echo ">>> Ensuring Elixir build tools..."
ensure_elixir_build_tools

echo ">>> Installing Elixir dependencies..."
mix deps.get --only prod

echo ">>> Compiling Elixir deps..."
mix deps.compile

echo ">>> Compiling notifier..."
mix compile

echo ">>> Building release..."
mix release --overwrite

RELEASE_TAR="${BUILD_DIR}/apps/frontman_notifier/_build/prod/${APP_NAME}-0.0.1.tar.gz"

if [ ! -f "${RELEASE_TAR}" ]; then
  echo "ERROR: Release tarball not found: ${RELEASE_TAR}"
  exit 1
fi

TIMESTAMP=$(date +%Y%m%d%H%M%S)
RELEASE_DIR="${DEPLOY_ROOT}/releases/${TIMESTAMP}"

echo ">>> Extracting release to ${RELEASE_DIR}..."
mkdir -p "${RELEASE_DIR}"
tar -xzf "${RELEASE_TAR}" -C "${RELEASE_DIR}"

echo ">>> Swapping current symlink..."
ln -sfn "${RELEASE_DIR}" "${DEPLOY_ROOT}/current.tmp"
mv -T "${DEPLOY_ROOT}/current.tmp" "${DEPLOY_ROOT}/current"

echo ">>> Restarting ${SERVICE_NAME}..."
sudo /usr/bin/systemctl restart "${SERVICE_NAME}"
sleep 3

if ! systemctl is-active --quiet "${SERVICE_NAME}"; then
  echo "FATAL: ${SERVICE_NAME} is not active after restart."
  echo "Check logs: journalctl -u ${SERVICE_NAME} -n 50"
  exit 1
fi

echo ">>> Cleaning old releases..."
RELEASES_DIR="${DEPLOY_ROOT}/releases"
if [ -d "${RELEASES_DIR}" ]; then
  RELEASES=$(find "${RELEASES_DIR}" -mindepth 1 -maxdepth 1 -type d | sort)
  RELEASE_COUNT=$(echo "${RELEASES}" | grep -c . || true)
  if [ "${RELEASE_COUNT}" -gt "${KEEP_RELEASES}" ]; then
    REMOVE_COUNT=$((RELEASE_COUNT - KEEP_RELEASES))
    CURRENT_TARGET=$(readlink -f "${DEPLOY_ROOT}/current" 2>/dev/null || echo "")
    echo "${RELEASES}" | head -n "${REMOVE_COUNT}" | while read -r OLD_RELEASE; do
      if [ -n "${OLD_RELEASE}" ] && [ "${OLD_RELEASE}" != "${CURRENT_TARGET}" ]; then
        echo "  Removing old release: ${OLD_RELEASE}"
        rm -rf "${OLD_RELEASE}"
      fi
    done
  fi
fi

echo ""
echo "=== Notifier Deploy Complete ==="
echo "Release: ${RELEASE_DIR}"
echo "Service: ${SERVICE_NAME} active"
