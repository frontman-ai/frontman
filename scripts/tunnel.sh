#!/bin/bash
# Start SSH tunnel to Hetzner DevPod server
# This forwards local ports 8080/8443 to the remote Caddy proxy
#
# Usage: ./scripts/tunnel.sh
#
# After starting, access worktrees via:
#   https://wt-xxxx-nextjs.local:8443
#   https://wt-xxxx-vite.local:8443
#   etc.

set -e

REMOTE_HOST="${DEVPOD_HOST:-77.42.16.199}"
REMOTE_USER="${DEVPOD_USER:-root}"

echo "Starting SSH tunnel to $REMOTE_USER@$REMOTE_HOST"
echo "  Local :8080 → Remote :80 (HTTP)"
echo "  Local :8443 → Remote :443 (HTTPS)"
echo ""
echo "Press Ctrl+C to stop the tunnel"
echo ""

ssh -L 8080:localhost:80 -L 8443:localhost:443 "$REMOTE_USER@$REMOTE_HOST" -N
