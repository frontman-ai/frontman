#!/bin/bash
set -e

# mise is installed in ~/.local/bin
export PATH="$HOME/.local/bin:$PATH"

# Find the workspace directory (DevPod may mount to different paths)
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

# Extract worktree name from workspace directory
WORKTREE_NAME=$(basename "$WORKSPACE_DIR")
echo "==> Found workspace at: $WORKSPACE_DIR (worktree: $WORKTREE_NAME)"
cd "$WORKSPACE_DIR"

# Generate worktree hash for URL scheme
# URL format: {hash}.{service}.frontman.local (required for WorkOS OAuth)
WT_HASH=$(echo -n "$WORKTREE_NAME" | md5sum | cut -c1-4)
echo "==> Worktree ID: $WT_HASH"

# Create environment file with worktree-specific URLs
cat > "$WORKSPACE_DIR/.env.devpod" << EOF
# Auto-generated DevPod environment for worktree: $WORKTREE_NAME
# Worktree Hash: $WT_HASH
# URL Format: {hash}.{service}.frontman.local (required for WorkOS OAuth)
# Access via SSH tunnel: make tunnel

# Worktree identification
WORKTREE_NAME=$WORKTREE_NAME
WORKTREE_ID=$WT_HASH

# External URLs (via Caddy reverse proxy)
# Format: {hash}.{service}.frontman.local:8443
FRONTMAN_HOST=$WT_HASH.api.frontman.local:8443
VITE_DEV_URL=https://$WT_HASH.vite.frontman.local:8443
VITE_HMR_HOST=$WT_HASH.vite.frontman.local
VITE_HMR_PORT=8443
VITE_HMR_PROTOCOL=wss
NEXTJS_URL=https://$WT_HASH.nextjs.frontman.local:8443

# Phoenix configuration
PHX_HOST=$WT_HASH.api.frontman.local
PHX_PORT=4000

# Client URL for Next.js middleware
FRONTMAN_CLIENT_URL=https://$WT_HASH.vite.frontman.local:8443/src/Main.res.mjs
EOF

echo "==> Created .env.devpod with worktree-specific URLs"

echo "==> Trusting mise config..."
~/.local/bin/mise trust --all

echo "==> Installing runtimes via mise (this may take a while)..."
~/.local/bin/mise install --yes

# Add shims to PATH
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
# Get Docker bridge gateway IP for PostgreSQL connection
DOCKER_GATEWAY=$(ip route | grep default | awk '{print $3}' 2>/dev/null || echo "172.17.0.1")

# Update Phoenix dev.env with database host
cat >> "$WORKSPACE_DIR/apps/frontman_server/envs/.dev.env" << EOF

# DevPod: Database connection to host PostgreSQL
DB_HOST=$DOCKER_GATEWAY
EOF

# Update dev.exs to use the gateway IP (compile-time config)
sed -i "s/hostname: \"localhost\"/hostname: \"$DOCKER_GATEWAY\"/" "$WORKSPACE_DIR/apps/frontman_server/config/dev.exs"

# Install Elixir dependencies and run migrations
cd "$WORKSPACE_DIR/apps/frontman_server"
mix local.hex --force
mix local.rebar --force
mix deps.get
mix ecto.create || true  # May already exist
mix ecto.migrate
cd "$WORKSPACE_DIR"

echo "==> Setting up Next.js test site..."
cd "$WORKSPACE_DIR/test/sites/blog-starter"
# Disable Sentry instrumentation (causes issues in DevPod)
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
echo "URLs (via tunnel):"
echo "  Next.js:   https://$WT_HASH.nextjs.frontman.local:8443/__frontman"
echo "  Vite:      https://$WT_HASH.vite.frontman.local:8443"
echo "  Phoenix:   https://$WT_HASH.api.frontman.local:8443"
echo "  Storybook: https://$WT_HASH.storybook.frontman.local:8443"
echo ""
echo "Add to /etc/hosts on your Mac:"
echo "127.0.0.1 $WT_HASH.nextjs.frontman.local $WT_HASH.vite.frontman.local $WT_HASH.api.frontman.local $WT_HASH.storybook.frontman.local $WT_HASH.dogfood.frontman.local"
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
