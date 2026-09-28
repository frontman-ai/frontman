#!/usr/bin/env bash
set -euo pipefail

DEPLOY_ROOT="/opt/frontman"
BUILD_DIR="${DEPLOY_ROOT}/build"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REBAR_URL="https://github.com/erlang/rebar3/releases/download/3.27.1/rebar3"
REBAR_SHA512="cd9a88e42a1d804b9b01581ea24aacf4563f2746a2bf4900215331c36400fc8f1f19a8272632e83a2da3206e42f1f46425966d4dee51bf16f19538a0b5e0632a"

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

bash "${BUILD_DIR}/infra/production/ensure-shared-discord-env.sh"

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

install -m 0755 "${BUILD_DIR}/infra/production/deploy.sh" "${DEPLOY_ROOT}/deploy.sh"
install -m 0755 "${BUILD_DIR}/infra/production/rollback.sh" "${DEPLOY_ROOT}/rollback.sh"
install -m 0755 "${BUILD_DIR}/infra/production/backup-pg.sh" "${DEPLOY_ROOT}/backup-pg.sh"

RELEASE_TAR="${BUILD_DIR}/apps/frontman_server/_build/prod/frontman_server-0.0.1.tar.gz"

if [ ! -f "${RELEASE_TAR}" ]; then
  echo "ERROR: Release tarball not found: ${RELEASE_TAR}"
  exit 1
fi

echo ""
echo "=== Starting Deploy ==="
"${SCRIPT_DIR}/deploy.sh" "${RELEASE_TAR}"
