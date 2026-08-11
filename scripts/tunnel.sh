#!/bin/bash

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
