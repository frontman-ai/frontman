#!/bin/bash
set -e

export PATH="$HOME/.local/bin:$PATH"

WORKSPACE_DIR=""
for dir in /workspaces/*/mise.toml; do
    if [ -f "$dir" ]; then
        WORKSPACE_DIR=$(dirname "$dir")
        break
    fi
done

if [ -z "$WORKSPACE_DIR" ]; then
    echo "ERROR: Could not find workspace with mise.toml"
    exit 1
fi

WORKTREE_NAME=$(basename "$WORKSPACE_DIR")
echo "==> Found workspace at: $WORKSPACE_DIR (worktree: $WORKTREE_NAME)"
cd "$WORKSPACE_DIR"

WT_HASH=$(echo -n "$WORKTREE_NAME" | md5sum | cut -c1-4)
echo "==> Worktree ID: $WT_HASH"

cat > "$WORKSPACE_DIR/.env.devpod" << EOF

export WORKTREE_NAME=$WORKTREE_NAME
export WORKTREE_ID=$WT_HASH

export FRONTMAN_HOST=$WT_HASH.api.frontman.local
export VITE_DEV_URL=https://$WT_HASH.vite.frontman.local
export VITE_HMR_HOST=$WT_HASH.vite.frontman.local
export VITE_HMR_PORT=443
export VITE_HMR_PROTOCOL=wss
export NEXTJS_URL=https://$WT_HASH.nextjs.frontman.local

export PHX_HOST=$WT_HASH.api.frontman.local
export PHX_PORT=4000
export PHX_URL_PORT=443

export DB_HOST=host.docker.internal

export FRONTMAN_CLIENT_URL=https://$WT_HASH.vite.frontman.local/src/Main.res.mjs
EOF

echo "==> Created .env.devpod with worktree-specific URLs"

echo "==> Trusting mise config..."
~/.local/bin/mise trust --all

echo "==> Installing runtimes via mise (this may take a while)..."
~/.local/bin/mise install --yes

export PATH="$HOME/.local/share/mise/shims:$PATH"

echo "==> Verifying tools..."
which node && node --version
which yarn && yarn --version
which elixir && elixir --version

echo "==> Installing project dependencies..."
yarn install

echo "==> Building ReScript..."
yarn rescript build

echo "==> Setting up Phoenix database..."
DOCKER_GATEWAY=$(ip route | grep default | awk '{print $3}' 2>/dev/null || echo "172.17.0.1")

cat > "$WORKSPACE_DIR/apps/frontman_server/envs/.dev.overrides.env" << EOF
DB_HOST=host.docker.internal
PHX_HOST=$WT_HASH.api.frontman.local
PHX_URL_PORT=443
EOF

echo "==> Created .dev.overrides.env (DevPod networking config)"

sed -i "s/hostname: \"localhost\"/hostname: \"$DOCKER_GATEWAY\"/" "$WORKSPACE_DIR/apps/frontman_server/config/dev.exs"

cd "$WORKSPACE_DIR/apps/frontman_server"
mix local.hex --force
mix local.rebar --force
mix deps.get
mix ecto.create || true
mix ecto.migrate
cd "$WORKSPACE_DIR"

echo "==> Setting up Next.js test site..."
cd "$WORKSPACE_DIR/test/sites/blog-starter"
if [ -f "instrumentation.ts" ]; then
    mv instrumentation.ts instrumentation.ts.bak
fi
rm -rf .next
cd "$WORKSPACE_DIR"

echo ""
echo "=========================================="
echo "==> Setup complete!"
echo "=========================================="
echo ""
echo "Worktree: $WORKTREE_NAME ($WT_HASH)"
echo ""
echo "URLs:"
echo "  Next.js:   https://$WT_HASH.nextjs.frontman.local/frontman"
echo "  Vite:      https://$WT_HASH.vite.frontman.local"
echo "  Phoenix:   https://$WT_HASH.api.frontman.local"
echo ""
echo "Add to /etc/hosts on your Mac:"
echo "127.0.0.1 $WT_HASH.nextjs.frontman.local $WT_HASH.vite.frontman.local $WT_HASH.api.frontman.local"
echo ""
echo "Commands:"
echo "  make dev-server  - Start Phoenix server"
echo "  make dev-client  - Start Vite client"
echo "  make dev-nextjs  - Start Next.js test site"
echo ""
echo "Database: postgres://postgres:postgres@$DOCKER_GATEWAY:5432/frontman_server_dev"
echo ""
echo "Note: Caddy config must be added on the server for this worktree."
echo "Run: make worktree-register BRANCH=$WORKTREE_NAME CONTAINER=<container-name>"
