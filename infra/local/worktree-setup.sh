#!/bin/bash

set -euo pipefail

HASH="${WORKTREE_HASH:?WORKTREE_HASH must be set}"
BRANCH="${WORKTREE_BRANCH:?WORKTREE_BRANCH must be set}"
WORKSPACE="/workspaces/frontman"

echo "==> Setting up worktree: $BRANCH ($HASH)"
echo ""

export PATH="$HOME/.local/bin:$HOME/.local/share/mise/shims:$PATH"

echo "==> Trusting mise config..."
mise trust --all
mise install --yes

export PATH="$HOME/.local/share/mise/shims:$PATH"

echo "==> Verifying tools..."
which node && node --version
which yarn && yarn --version
which elixir && elixir --version

echo "==> Generating local SSL certificates..."
mkdir -p "$WORKSPACE/.certs"
if [ ! -f "$WORKSPACE/.certs/frontman.local-key.pem" ]; then
  mkcert -install
  mkcert \
    -key-file "$WORKSPACE/.certs/frontman.local-key.pem" \
    -cert-file "$WORKSPACE/.certs/frontman.local.pem" \
    frontman.local localhost 127.0.0.1 ::1
else
  echo "  Certificates already exist, skipping."
fi

echo "==> Installing JS dependencies..."
cd "$WORKSPACE"
yarn install

echo "==> Building ReScript..."
yarn rescript build

echo "==> Installing Elixir dependencies..."
cd "$WORKSPACE/apps/frontman_server"
mix local.hex --force
mix local.rebar --force
mix deps.get

echo "==> Setting up database..."
echo "Waiting for Postgres..."
while ! pg_isready -h localhost -U postgres 2>/dev/null; do sleep 2; done
echo "Postgres ready."
mix ecto.create || true
mix ecto.migrate

echo "==> Creating environment overrides..."
cd "$WORKSPACE"

cat > "$WORKSPACE/apps/frontman_server/envs/.dev.overrides.env" << EOF
PHX_HOST=${HASH}.api.frontman.local
PHX_URL_PORT=443
EOF

echo ""
echo "=========================================="
echo "==> Setup complete!"
echo "=========================================="
echo ""
echo "Worktree: $BRANCH ($HASH)"
echo ""
echo "URLs:"
echo "  Phoenix:   https://${HASH}.api.frontman.local"
echo "  Vite:      https://${HASH}.vite.frontman.local"
echo "  Next.js:   https://${HASH}.nextjs.frontman.local/frontman"
echo ""
echo "Start dev with:"
echo "  make wt-dev BRANCH=$BRANCH"
