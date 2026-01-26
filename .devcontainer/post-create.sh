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
WT_HASH=$(echo -n "$WORKTREE_NAME" | md5sum | cut -c1-4)
WT_ID="wt-$WT_HASH"
echo "==> Worktree ID: $WT_ID"

# Create environment file with worktree-specific URLs
cat > "$WORKSPACE_DIR/.env.devpod" << EOF
# Auto-generated DevPod environment for worktree: $WORKTREE_NAME
# Worktree ID: $WT_ID
# Access via SSH tunnel: ./scripts/tunnel.sh

# Worktree identification
WORKTREE_NAME=$WORKTREE_NAME
WORKTREE_ID=$WT_ID

# External URLs (via Caddy reverse proxy)
FRONTMAN_HOST=$WT_ID-api.local:8443
VITE_DEV_URL=https://$WT_ID-vite.local:8443
VITE_HMR_HOST=$WT_ID-vite.local
VITE_HMR_PORT=8443
VITE_HMR_PROTOCOL=wss
NEXTJS_URL=https://$WT_ID-nextjs.local:8443

# Phoenix configuration
PHX_HOST=$WT_ID-api.local
PHX_PORT=4000

# Client URL for Next.js middleware
FRONTMAN_CLIENT_URL=https://$WT_ID-vite.local:8443/src/Main.res.mjs
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

echo ""
echo "=========================================="
echo "==> Setup complete!"
echo "=========================================="
echo ""
echo "Worktree: $WORKTREE_NAME ($WT_ID)"
echo ""
echo "URLs (via tunnel):"
echo "  Next.js:   https://$WT_ID-nextjs.local:8443"
echo "  Vite:      https://$WT_ID-vite.local:8443"
echo "  Phoenix:   https://$WT_ID-api.local:8443"
echo "  Storybook: https://$WT_ID-storybook.local:8443"
echo ""
echo "Add to /etc/hosts on your Mac:"
echo "127.0.0.1 $WT_ID-nextjs.local $WT_ID-vite.local $WT_ID-api.local $WT_ID-storybook.local $WT_ID-dogfood.local"
echo ""
echo "Commands:"
echo "  make dev-server  - Start Phoenix server"
echo "  make dev-client  - Start Vite client"
echo "  make dev-nextjs  - Start Next.js test site"
echo ""
echo "Database: postgres://postgres:postgres@host.docker.internal:5432/frontman_server_dev"
