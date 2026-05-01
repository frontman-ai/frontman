#!/bin/bash
set -e

# Usage: register-worktree <worktree-name> <container-name-or-id>
# Example: register-worktree issue-164 goofy_murdock
#
# URL scheme: wt-{hash}-{service}.local
# Example: wt-8f3a-nextjs.local, wt-8f3a-vite.local

WORKTREE_NAME="$1"
CONTAINER="$2"

if [ -z "$WORKTREE_NAME" ] || [ -z "$CONTAINER" ]; then
    echo "Usage: register-worktree <worktree-name> <container-name-or-id>"
    exit 1
fi

# Generate hash (first 4 chars of md5)
HASH=$(echo -n "$WORKTREE_NAME" | md5sum | cut -c1-4)
WT_ID="wt-$HASH"

# Get container IP
CONTAINER_IP=$(docker inspect "$CONTAINER" --format '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}')

if [ -z "$CONTAINER_IP" ]; then
    echo "Error: Could not get IP for container $CONTAINER"
    exit 1
fi

echo "Registering worktree: $WORKTREE_NAME"
echo "  ID: $WT_ID"
echo "  Container: $CONTAINER"
echo "  IP: $CONTAINER_IP"

# Create Caddy config for this worktree
# URL scheme: wt-{hash}-{service}.local (single level for wildcard cert compatibility)
cat > "/etc/caddy/worktrees/$WT_ID.caddy" << EOF
# Worktree: $WORKTREE_NAME ($WT_ID)
# Container: $CONTAINER
# IP: $CONTAINER_IP
# Generated: $(date -Iseconds)

$WT_ID-nextjs.local {
    tls /etc/caddy/certs/worktree.pem /etc/caddy/certs/worktree-key.pem
    reverse_proxy $CONTAINER_IP:3000
}

$WT_ID-vite.local {
    tls /etc/caddy/certs/worktree.pem /etc/caddy/certs/worktree-key.pem
    reverse_proxy $CONTAINER_IP:5173
}

$WT_ID-api.local {
    tls /etc/caddy/certs/worktree.pem /etc/caddy/certs/worktree-key.pem
    reverse_proxy $CONTAINER_IP:4000 {
        transport http {
            tls_insecure_skip_verify
        }
    }
}

EOF

echo "Created /etc/caddy/worktrees/$WT_ID.caddy"

# Store worktree info in JSON registry
REGISTRY="/etc/caddy/worktrees/registry.json"
if [ ! -f "$REGISTRY" ]; then
    echo "{}" > "$REGISTRY"
fi

# Update registry
jq --arg name "$WORKTREE_NAME" \
   --arg id "$WT_ID" \
   --arg container "$CONTAINER" \
   --arg ip "$CONTAINER_IP" \
   --arg date "$(date -Iseconds)" \
   '.[$name] = {id: $id, container: $container, ip: $ip, registered: $date}' \
   "$REGISTRY" > "$REGISTRY.tmp" && mv "$REGISTRY.tmp" "$REGISTRY"

# Reload Caddy
caddy reload --config /etc/caddy/Caddyfile 2>/dev/null || echo "Warning: Caddy reload failed, may need manual reload"

echo ""
echo "URLs for $WORKTREE_NAME:"
echo "  Next.js:   https://$WT_ID-nextjs.local/frontman"
echo "  Vite:      https://$WT_ID-vite.local"
echo "  Phoenix:   https://$WT_ID-api.local"
echo ""
echo "Add to /etc/hosts on your Mac:"
echo "127.0.0.1 $WT_ID-nextjs.local $WT_ID-vite.local $WT_ID-api.local"
