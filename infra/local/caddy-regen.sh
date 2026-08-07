#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CADDY_CONTAINER="frontman-caddy"

CADDYFILE="$SCRIPT_DIR/Caddyfile"
if podman container inspect "$CADDY_CONTAINER" &>/dev/null; then
    MOUNT_SRC=$(podman inspect "$CADDY_CONTAINER" \
        --format '{{range .Mounts}}{{if eq .Destination "/etc/caddy/Caddyfile"}}{{.Source}}{{end}}{{end}}' 2>/dev/null || true)
    if [ -n "$MOUNT_SRC" ]; then
        CADDYFILE="$MOUNT_SRC"
    fi
fi

PODS=$(podman pod ls --format '{{.Name}}' --filter status=running 2>/dev/null | grep '^worktree-' || true)

cat > "$CADDYFILE" << 'HEADER'

HEADER

if [ -z "$PODS" ]; then
    cat >> "$CADDYFILE" << 'EOF'
:9999 {
    respond "No worktree pods running" 503
}
EOF
else
    for POD in $PODS; do
        HASH="${POD#worktree-}"

        BASE_PORT=$(( (16#${HASH} % 1000) * 5 + 10000 ))
        PORT_PHOENIX=$((BASE_PORT))
        PORT_VITE=$((BASE_PORT + 1))
        PORT_NEXTJS=$((BASE_PORT + 2))
        PORT_MARKETING=$((BASE_PORT + 4))

        cat >> "$CADDYFILE" << EOF
${HASH}.api.frontman.local {
    tls internal
    reverse_proxy https://127.0.0.1:${PORT_PHOENIX} {
        transport http {
            tls_insecure_skip_verify
        }
    }
}

${HASH}.vite.frontman.local {
    tls internal
    reverse_proxy 127.0.0.1:${PORT_VITE}
}

${HASH}.nextjs.frontman.local {
    tls internal
    reverse_proxy 127.0.0.1:${PORT_NEXTJS}
}

${HASH}.marketing.frontman.local {
    tls internal
    reverse_proxy 127.0.0.1:${PORT_MARKETING}
}

EOF
    done
fi

echo "Generated $CADDYFILE"

if podman container inspect "$CADDY_CONTAINER" &>/dev/null; then
    podman exec "$CADDY_CONTAINER" caddy reload --config /etc/caddy/Caddyfile 2>/dev/null && \
        echo "Caddy reloaded" || \
        echo "Warning: Caddy reload failed (container may not be running)"
else
    echo "Note: Caddy container ($CADDY_CONTAINER) not running — skipping reload"
fi
