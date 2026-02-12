#!/bin/bash
# Start SSH tunnel to Hetzner DevPod server
# This forwards local ports 8080/8443 to the remote Caddy proxy
#
# NOTE: With dnsmasq configured (recommended), you don't need this tunnel.
# dnsmasq resolves *.frontman.local directly to the server on port 443.
# This script is only needed if dnsmasq is NOT set up.
#
# Usage: ./scripts/tunnel.sh
#
# After starting, access worktrees via:
#   https://xxxx.nextjs.frontman.local:8443
#   https://xxxx.vite.frontman.local:8443
#   etc.

set -e

if [ -z "${DEVPOD_SERVER:-}" ]; then
  echo "Error: DEVPOD_SERVER is not set. Run via: op run --env-file=.env -- ./scripts/tunnel.sh"
  exit 1
fi
REMOTE_HOST="$DEVPOD_SERVER"
REMOTE_USER="${DEVPOD_USER:-root}"

echo "Starting SSH tunnel to $REMOTE_USER@$REMOTE_HOST"
echo "  Local :8080 → Remote :80 (HTTP)"
echo "  Local :8443 → Remote :443 (HTTPS)"
echo ""
echo "Press Ctrl+C to stop the tunnel"
echo ""

ssh -L 8080:localhost:80 -L 8443:localhost:443 "$REMOTE_USER@$REMOTE_HOST" -N
