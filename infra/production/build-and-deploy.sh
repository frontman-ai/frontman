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
DEPLOY_ROOT="/opt/frontman"
BUILD_DIR="${DEPLOY_ROOT}/build"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REBAR_URL="https://s3.amazonaws.com/rebar3/rebar3"
REBAR_SHA512="0d00494d849fdc521a55142278d1f6ba552954fbd65b80d40df8022f594f05d6c99ed1d731bc263691a04176e11d4c6e126c56ba20dca19c5e42d4ffab2e7e36"

# --- Activate mise ---
export PATH="/home/deploy/.local/bin:${PATH}"
if ! command -v mise >/dev/null 2>&1; then
  curl https://mise.run | sh
  export PATH="/home/deploy/.local/bin:${PATH}"
fi
mise trust "${BUILD_DIR}/mise.toml" >/dev/null
mise install --yes -C "${BUILD_DIR}" elixir erlang
eval "$(mise activate bash --shims)"

echo "=== Frontman Build & Deploy ==="
echo "Build dir: ${BUILD_DIR}"
echo ""

ensure_elixir_build_tools() {
  echo "Installing Hex..."
  mix local.hex --force

  echo "Installing pinned Rebar..."
  REBAR_TMP=$(mktemp -t rebar3.XXXXXX)
  curl -fsSL "${REBAR_URL}" -o "${REBAR_TMP}"
  chmod +x "${REBAR_TMP}"
  mix local.rebar rebar3 "${REBAR_TMP}" --sha512 "${REBAR_SHA512}" --force
  rm -f "${REBAR_TMP}"
}

# =============================================================================
# Phase 1: Build (Elixir only — no JS/ReScript needed for server)
# =============================================================================
cd "${BUILD_DIR}/apps/frontman_server"
export MIX_ENV=prod

echo ">>> Ensuring Elixir build tools..."
ensure_elixir_build_tools

echo ">>> Installing Elixir dependencies..."
mix deps.get --only prod

echo ">>> Compiling Elixir deps..."
mix deps.compile

echo ">>> Installing Tailwind & esbuild..."
mix tailwind.install --if-missing
mix esbuild.install --if-missing

echo ">>> Compiling application..."
mix compile --warnings-as-errors --all-warnings

echo ">>> Building assets..."
mix tailwind frontman_server --minify
mix esbuild frontman_server --minify
mix phx.digest

echo ">>> Building release..."
mix release --overwrite

echo ""
echo "=== Build Complete ==="
echo ""

# --- Install and hand off to canonical blue-green deploy implementation ---
install -m 0755 "${BUILD_DIR}/infra/production/deploy.sh" "${DEPLOY_ROOT}/deploy.sh"
install -m 0755 "${BUILD_DIR}/infra/production/rollback.sh" "${DEPLOY_ROOT}/rollback.sh"

RELEASE_TAR="${BUILD_DIR}/apps/frontman_server/_build/prod/frontman_server-0.0.1.tar.gz"

if [ ! -f "${RELEASE_TAR}" ]; then
  echo "ERROR: Release tarball not found: ${RELEASE_TAR}"
  exit 1
fi

echo ""
echo "=== Starting Deploy ==="
"${SCRIPT_DIR}/deploy.sh" "${RELEASE_TAR}"
