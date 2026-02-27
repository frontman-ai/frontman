#!/bin/bash
# dnsmasq-setup.sh — One-time setup for wildcard DNS resolution.
#
# Configures dnsmasq to resolve *.frontman.local -> 127.0.0.1
# so all worktree subdomains (e.g. a1b2.api.frontman.local) work
# without manual /etc/hosts entries.
#
# Usage: sudo ./infra/local/dnsmasq-setup.sh

set -euo pipefail

CYAN='\033[36m'
GREEN='\033[32m'
YELLOW='\033[33m'
RED='\033[31m'
RESET='\033[0m'

if [ "$(id -u)" -ne 0 ]; then
    echo -e "${RED}Error: This script must be run as root (sudo)${RESET}"
    echo "Usage: sudo ./infra/local/dnsmasq-setup.sh"
    exit 1
fi

echo -e "${CYAN}Setting up wildcard DNS for *.frontman.local${RESET}"
echo ""

# Check if dnsmasq is installed
if ! command -v dnsmasq &>/dev/null; then
    echo -e "${YELLOW}dnsmasq is not installed.${RESET}"
    echo ""
    echo "Install it with:"
    echo "  sudo apt install dnsmasq    # Debian/Ubuntu"
    echo "  sudo dnf install dnsmasq    # Fedora"
    echo "  sudo pacman -S dnsmasq      # Arch"
    echo ""
    echo "Then re-run this script."
    exit 1
fi

# Ensure /etc/dnsmasq.conf includes the .d directory
# (many distros ship with conf-dir commented out by default)
if ! grep -q '^conf-dir=/etc/dnsmasq.d' /etc/dnsmasq.conf 2>/dev/null; then
    echo -e "${YELLOW}Enabling conf-dir in /etc/dnsmasq.conf...${RESET}"
    if grep -q '#conf-dir=/etc/dnsmasq.d/,\*\.conf' /etc/dnsmasq.conf 2>/dev/null; then
        sed -i 's|^#conf-dir=/etc/dnsmasq.d/,\*\.conf|conf-dir=/etc/dnsmasq.d/,*.conf|' /etc/dnsmasq.conf
    elif grep -q '#conf-dir=/etc/dnsmasq.d' /etc/dnsmasq.conf 2>/dev/null; then
        sed -i 's|^#conf-dir=/etc/dnsmasq.d|conf-dir=/etc/dnsmasq.d/,*.conf|' /etc/dnsmasq.conf
    else
        echo 'conf-dir=/etc/dnsmasq.d/,*.conf' >> /etc/dnsmasq.conf
    fi
    echo -e "${GREEN}Enabled conf-dir=/etc/dnsmasq.d/,*.conf${RESET}"
fi

# Write dnsmasq config
DNSMASQ_CONF="/etc/dnsmasq.d/frontman.conf"
mkdir -p /etc/dnsmasq.d

cat > "$DNSMASQ_CONF" << 'EOF'
# Frontman local development — resolve *.frontman.local to loopback
address=/frontman.local/127.0.0.1
address=/frontman.local/::1
EOF

echo -e "${GREEN}Wrote $DNSMASQ_CONF${RESET}"

# Handle systemd-resolved integration (common on Ubuntu/Arch/Fedora)
if systemctl is-active --quiet systemd-resolved 2>/dev/null; then
    echo -e "${YELLOW}systemd-resolved detected — configuring integration...${RESET}"

    # dnsmasq needs to listen on a loopback alias to avoid conflicting with
    # systemd-resolved on 127.0.0.53:53. We use 127.0.0.2.
    if ! grep -q "listen-address=127.0.0.2" "$DNSMASQ_CONF"; then
        cat >> "$DNSMASQ_CONF" << 'EOF'

# Avoid port 53 conflict with systemd-resolved
listen-address=127.0.0.2
bind-interfaces
EOF
    fi

    # Add 127.0.0.2 to loopback (idempotent)
    if ! ip addr show lo | grep -q '127.0.0.2'; then
        ip addr add 127.0.0.2/8 dev lo
        echo -e "${GREEN}Added 127.0.0.2 to loopback interface${RESET}"
    fi

    # Make the loopback alias persist across reboots via networkd
    NETDEV_CONF="/etc/systemd/network/10-frontman-loopback.network"
    if [ ! -f "$NETDEV_CONF" ]; then
        cat > "$NETDEV_CONF" << 'EOF'
# Persist 127.0.0.2 on loopback for dnsmasq (Frontman dev)
[Match]
Name=lo

[Network]
Address=127.0.0.2/8
EOF
        echo -e "${GREEN}Wrote $NETDEV_CONF (persistent loopback alias)${RESET}"
    fi

    # Tell resolved to forward .frontman.local queries to dnsmasq at 127.0.0.2
    RESOLVED_CONF="/etc/systemd/resolved.conf.d/frontman.conf"
    mkdir -p /etc/systemd/resolved.conf.d

    cat > "$RESOLVED_CONF" << 'EOF'
# Forward .frontman.local queries to dnsmasq
[Resolve]
DNS=127.0.0.2
Domains=~frontman.local
EOF

    echo -e "${GREEN}Wrote $RESOLVED_CONF${RESET}"

    # Create systemd override so dnsmasq runs as root (needed to bind port 53)
    OVERRIDE_DIR="/etc/systemd/system/dnsmasq.service.d"
    mkdir -p "$OVERRIDE_DIR"
    cat > "$OVERRIDE_DIR/frontman.conf" << 'EOF'
[Service]
# Run as root so dnsmasq can bind to port 53 on 127.0.0.2
ExecStart=
ExecStart=/usr/bin/dnsmasq -k --enable-dbus --pid-file
EOF
    echo -e "${GREEN}Wrote systemd override (run as root)${RESET}"

    systemctl daemon-reload
    systemctl restart systemd-resolved
    echo -e "${GREEN}Restarted systemd-resolved${RESET}"
fi

# Restart dnsmasq
systemctl enable dnsmasq 2>/dev/null || true
systemctl restart dnsmasq

echo -e "${GREEN}Restarted dnsmasq${RESET}"

# Verify
echo ""
echo -e "${CYAN}Verifying...${RESET}"
sleep 1

# Determine which address to query (127.0.0.2 if resolved integration, else 127.0.0.1)
DNS_ADDR="127.0.0.1"
if [ -f /etc/systemd/resolved.conf.d/frontman.conf ]; then
    DNS_ADDR="127.0.0.2"
fi

if dig +short test.frontman.local @"$DNS_ADDR" 2>/dev/null | grep -q "127.0.0.1" || \
   resolvectl query test.frontman.local 2>/dev/null | grep -q "127.0.0.1" || \
   getent hosts test.frontman.local 2>/dev/null | grep -q "127.0.0.1"; then
    echo -e "${GREEN}Wildcard DNS is working: *.frontman.local -> 127.0.0.1${RESET}"
else
    echo -e "${YELLOW}Warning: Could not verify DNS resolution.${RESET}"
    echo "Try manually: dig test.frontman.local @$DNS_ADDR"
    echo "You may need to restart your network or flush DNS cache."
fi

echo ""
echo -e "${GREEN}Done! All *.frontman.local domains now resolve to 127.0.0.1${RESET}"
