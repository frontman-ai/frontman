#!/usr/bin/env bash
# =============================================================================
# Frontman Production Monitoring Setup
# Installs Prometheus, exporters, Alertmanager, and a Python Discord bridge.
#
# Run as root on the production server:
#   ssh root@<server-ip> 'bash -s' < setup-monitoring.sh
#
# Prerequisites:
#   - Ubuntu 24.04 (x86_64 or ARM64)
#   - server-setup.sh already ran (frontman services exist)
#   - Discord webhook URL for #prod-alerts channel
#   - Python 3 installed (ships with Ubuntu 24.04)
# =============================================================================
set -euo pipefail

# --- Configuration ---
DEPLOY_ROOT="/opt/frontman"
MONITORING_DIR="${DEPLOY_ROOT}/monitoring"
TEXTFILE_DIR="${MONITORING_DIR}/textfile"

# Component versions
PROMETHEUS_VERSION="3.2.1"
NODE_EXPORTER_VERSION="1.9.0"
POSTGRES_EXPORTER_VERSION="0.16.0"
BLACKBOX_EXPORTER_VERSION="0.25.0"
ALERTMANAGER_VERSION="0.28.1"

# Auto-detect architecture
case "$(uname -m)" in
  x86_64)  ARCH="amd64" ;;
  aarch64) ARCH="arm64" ;;
  *)
    echo "ERROR: Unsupported architecture: $(uname -m)"
    exit 1
    ;;
esac
echo "=== Frontman Monitoring Setup ==="
echo "Detected architecture: ${ARCH}"
echo ""

# =============================================================================
# 0. Discord Webhook URL
# =============================================================================
echo "=== Discord Webhook Setup ==="
echo "Enter the Discord webhook URL for #prod-alerts channel:"
read -r DISCORD_WEBHOOK_URL
if [ -z "${DISCORD_WEBHOOK_URL}" ]; then
  echo "ERROR: Discord webhook URL is required."
  exit 1
fi
echo "Discord webhook URL saved."
echo ""

# =============================================================================
# 1. Create System Users
# =============================================================================
echo ">>> Creating monitoring system users..."
for USER in prometheus node_exporter postgres_exporter blackbox_exporter alertmanager; do
  if ! id "${USER}" &>/dev/null; then
    useradd --system --no-create-home --shell /usr/sbin/nologin "${USER}"
    echo "  Created user: ${USER}"
  else
    echo "  User already exists: ${USER}"
  fi
done

# =============================================================================
# 2. Create Directories
# =============================================================================
echo ">>> Creating directories..."
mkdir -p /etc/prometheus
mkdir -p /etc/alertmanager
mkdir -p /var/lib/prometheus/data
mkdir -p /var/lib/alertmanager/data
mkdir -p "${MONITORING_DIR}"
mkdir -p "${TEXTFILE_DIR}"

chown prometheus:prometheus /var/lib/prometheus /var/lib/prometheus/data
chown alertmanager:alertmanager /var/lib/alertmanager /var/lib/alertmanager/data
chown deploy:deploy "${MONITORING_DIR}" "${TEXTFILE_DIR}"

# Allow node_exporter to read textfile dir
chmod 755 "${TEXTFILE_DIR}"

# =============================================================================
# 3. Download and Install Binaries
# =============================================================================
TMPDIR=$(mktemp -d)
trap 'rm -rf "${TMPDIR}"' EXIT

echo ">>> Downloading Prometheus ${PROMETHEUS_VERSION} (${ARCH})..."
curl -sL "https://github.com/prometheus/prometheus/releases/download/v${PROMETHEUS_VERSION}/prometheus-${PROMETHEUS_VERSION}.linux-${ARCH}.tar.gz" \
  | tar xz -C "${TMPDIR}"
cp "${TMPDIR}/prometheus-${PROMETHEUS_VERSION}.linux-${ARCH}/prometheus" /usr/local/bin/
cp "${TMPDIR}/prometheus-${PROMETHEUS_VERSION}.linux-${ARCH}/promtool" /usr/local/bin/
chmod +x /usr/local/bin/prometheus /usr/local/bin/promtool

echo ">>> Downloading Node Exporter ${NODE_EXPORTER_VERSION} (${ARCH})..."
curl -sL "https://github.com/prometheus/node_exporter/releases/download/v${NODE_EXPORTER_VERSION}/node_exporter-${NODE_EXPORTER_VERSION}.linux-${ARCH}.tar.gz" \
  | tar xz -C "${TMPDIR}"
cp "${TMPDIR}/node_exporter-${NODE_EXPORTER_VERSION}.linux-${ARCH}/node_exporter" /usr/local/bin/
chmod +x /usr/local/bin/node_exporter

echo ">>> Downloading PostgreSQL Exporter ${POSTGRES_EXPORTER_VERSION} (${ARCH})..."
curl -sL "https://github.com/prometheus-community/postgres_exporter/releases/download/v${POSTGRES_EXPORTER_VERSION}/postgres_exporter-${POSTGRES_EXPORTER_VERSION}.linux-${ARCH}.tar.gz" \
  | tar xz -C "${TMPDIR}"
cp "${TMPDIR}/postgres_exporter-${POSTGRES_EXPORTER_VERSION}.linux-${ARCH}/postgres_exporter" /usr/local/bin/
chmod +x /usr/local/bin/postgres_exporter

echo ">>> Downloading Blackbox Exporter ${BLACKBOX_EXPORTER_VERSION} (${ARCH})..."
curl -sL "https://github.com/prometheus/blackbox_exporter/releases/download/v${BLACKBOX_EXPORTER_VERSION}/blackbox_exporter-${BLACKBOX_EXPORTER_VERSION}.linux-${ARCH}.tar.gz" \
  | tar xz -C "${TMPDIR}"
cp "${TMPDIR}/blackbox_exporter-${BLACKBOX_EXPORTER_VERSION}.linux-${ARCH}/blackbox_exporter" /usr/local/bin/
chmod +x /usr/local/bin/blackbox_exporter

echo ">>> Downloading Alertmanager ${ALERTMANAGER_VERSION} (${ARCH})..."
curl -sL "https://github.com/prometheus/alertmanager/releases/download/v${ALERTMANAGER_VERSION}/alertmanager-${ALERTMANAGER_VERSION}.linux-${ARCH}.tar.gz" \
  | tar xz -C "${TMPDIR}"
cp "${TMPDIR}/alertmanager-${ALERTMANAGER_VERSION}.linux-${ARCH}/alertmanager" /usr/local/bin/
cp "${TMPDIR}/alertmanager-${ALERTMANAGER_VERSION}.linux-${ARCH}/amtool" /usr/local/bin/
chmod +x /usr/local/bin/alertmanager /usr/local/bin/amtool

echo ">>> Installing alertmanager-discord (Python bridge)..."
cat > /usr/local/bin/alertmanager-discord <<'PYBRIDGE'
#!/usr/bin/env python3
"""Minimal Alertmanager -> Discord webhook bridge.

Receives Alertmanager webhook POSTs on port 9095 and forwards them
as Discord embeds with color-coded severity levels.
"""
import http.server
import json
import os
import sys
import urllib.request

DISCORD_WEBHOOK = os.environ.get("DISCORD_WEBHOOK", "")
LISTEN_ADDR = ("127.0.0.1", 9095)

COLOR_MAP = {
    "critical": 0xFF0000,   # red
    "warning": 0xFFA500,    # orange
    "none": 0x00FF00,       # green (heartbeat)
}

def format_alert(alert):
    status = alert.get("status", "unknown")
    labels = alert.get("labels", {})
    annotations = alert.get("annotations", {})
    severity = labels.get("severity", "warning")
    alertname = labels.get("alertname", "Unknown")

    if status == "resolved":
        color = 0x00FF00
        title = f"\u2705 RESOLVED: {alertname}"
    else:
        color = COLOR_MAP.get(severity, 0xFFA500)
        emoji = "\U0001F6A8" if severity == "critical" else "\u26A0\uFE0F" if severity == "warning" else "\U0001F49A"
        title = f"{emoji} {status.upper()}: {alertname}"

    summary = annotations.get("summary", "")
    description = annotations.get("description", "")

    embed = {
        "title": title,
        "description": f"**{summary}**\n{description}" if description else f"**{summary}**",
        "color": color,
    }

    # Add relevant labels as fields (skip alertname and severity, already shown)
    fields = []
    for k, v in labels.items():
        if k not in ("alertname", "severity"):
            fields.append({"name": k, "value": v, "inline": True})
    if fields:
        embed["fields"] = fields[:25]  # Discord embed limit

    return embed

class Handler(http.server.BaseHTTPRequestHandler):
    def do_POST(self):
        length = int(self.headers.get("Content-Length", 0))
        body = self.rfile.read(length)
        self.send_response(200)
        self.end_headers()

        try:
            data = json.loads(body)
            alerts = data.get("alerts", [])
            embeds = [format_alert(a) for a in alerts[:10]]  # Discord max 10 embeds

            payload = json.dumps({"embeds": embeds}).encode()
            req = urllib.request.Request(
                DISCORD_WEBHOOK,
                data=payload,
                headers={
                    "Content-Type": "application/json",
                    "User-Agent": "alertmanager-discord/1.0",
                },
            )
            urllib.request.urlopen(req, timeout=10)
        except Exception as e:
            print(f"Error: {e}", file=sys.stderr, flush=True)

    def log_message(self, format, *args):
        print(f"[alertmanager-discord] {args[0]}", flush=True)

if not DISCORD_WEBHOOK:
    print("ERROR: DISCORD_WEBHOOK environment variable not set", file=sys.stderr)
    sys.exit(1)

print(f"Listening on {LISTEN_ADDR[0]}:{LISTEN_ADDR[1]}", flush=True)
server = http.server.HTTPServer(LISTEN_ADDR, Handler)
server.serve_forever()
PYBRIDGE
chmod +x /usr/local/bin/alertmanager-discord

echo "All binaries installed."

# =============================================================================
# 4. Deploy Configuration Files
# =============================================================================
echo ">>> Deploying configuration files..."

# Configuration files are expected in /opt/frontman/build/infra/production/monitoring/
# after rsync from CI, or can be copied manually
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [ -f "${SCRIPT_DIR}/prometheus.yml" ]; then
  cp "${SCRIPT_DIR}/prometheus.yml" /etc/prometheus/prometheus.yml
  cp "${SCRIPT_DIR}/alert-rules.yml" /etc/prometheus/alert-rules.yml
  cp "${SCRIPT_DIR}/blackbox.yml" /etc/prometheus/blackbox.yml
  cp "${SCRIPT_DIR}/alertmanager.yml" /etc/alertmanager/alertmanager.yml
  echo "  Config files copied from ${SCRIPT_DIR}"
else
  echo "  WARNING: Config files not found at ${SCRIPT_DIR}."
  echo "  Copy them manually to /etc/prometheus/ and /etc/alertmanager/"
fi

chown -R prometheus:prometheus /etc/prometheus
chown -R alertmanager:alertmanager /etc/alertmanager

# =============================================================================
# 4b. Sudoers for deploy user to sync monitoring configs from CI
# =============================================================================
echo ">>> Adding sudoers entries for monitoring config deployment..."
cat > /etc/sudoers.d/deploy-monitoring <<'SUDOERS'
# Allow deploy user to update monitoring configs and ownership without password
deploy ALL=(ALL) NOPASSWD: /usr/bin/cp /opt/frontman/build/infra/production/monitoring/prometheus.yml /etc/prometheus/prometheus.yml
deploy ALL=(ALL) NOPASSWD: /usr/bin/cp /opt/frontman/build/infra/production/monitoring/alert-rules.yml /etc/prometheus/alert-rules.yml
deploy ALL=(ALL) NOPASSWD: /usr/bin/cp /opt/frontman/build/infra/production/monitoring/blackbox.yml /etc/prometheus/blackbox.yml
deploy ALL=(ALL) NOPASSWD: /usr/bin/cp /opt/frontman/build/infra/production/monitoring/alertmanager.yml /etc/alertmanager/alertmanager.yml
deploy ALL=(ALL) NOPASSWD: /usr/bin/chown -R prometheus\:prometheus /etc/prometheus
deploy ALL=(ALL) NOPASSWD: /usr/bin/chown -R alertmanager\:alertmanager /etc/alertmanager
SUDOERS
chmod 440 /etc/sudoers.d/deploy-monitoring

# =============================================================================
# 5. Create Environment Files
# =============================================================================
echo ">>> Creating environment files..."

# PostgreSQL exporter - connect via Unix socket with peer auth.
# The PG role name must match the OS user (postgres_exporter) for peer auth.
sudo -u postgres psql -c "DO \$\$ BEGIN IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'postgres_exporter') THEN CREATE ROLE postgres_exporter LOGIN; END IF; END \$\$;" 2>/dev/null || true
sudo -u postgres psql -c "GRANT pg_monitor TO postgres_exporter;" 2>/dev/null || true

cat > "${MONITORING_DIR}/postgres-exporter.env" <<'ENV'
DATA_SOURCE_NAME=user=postgres_exporter host=/var/run/postgresql/ dbname=postgres sslmode=disable
ENV
chown postgres_exporter:postgres_exporter "${MONITORING_DIR}/postgres-exporter.env"
chmod 600 "${MONITORING_DIR}/postgres-exporter.env"

# alertmanager-discord
cat > "${MONITORING_DIR}/alertmanager-discord.env" <<ENV
DISCORD_WEBHOOK=${DISCORD_WEBHOOK_URL}
ENV
chown alertmanager:alertmanager "${MONITORING_DIR}/alertmanager-discord.env"
chmod 600 "${MONITORING_DIR}/alertmanager-discord.env"

# =============================================================================
# 6. Write Initial Textfile Metrics
# =============================================================================
echo ">>> Writing initial textfile metrics..."

# Active slot metric - written by a small cron job
cat > "${MONITORING_DIR}/update-active-slot.sh" <<'SCRIPT'
#!/usr/bin/env bash
# Write the active slot as a Prometheus metric for the service-down alert.
ACTIVE_SLOT=$(cat /opt/frontman/active_slot 2>/dev/null || echo "unknown")
TEXTFILE_DIR="/opt/frontman/monitoring/textfile"

# Write metric: 1 for the active slot, 0 for the inactive
for SLOT in blue green; do
  if [ "${SLOT}" = "${ACTIVE_SLOT}" ]; then
    VALUE=1
  else
    VALUE=0
  fi
  echo "node_textfile_frontman_active_slot{name=\"frontman-${SLOT}.service\"} ${VALUE}"
done > "${TEXTFILE_DIR}/active_slot.prom"
SCRIPT
chmod +x "${MONITORING_DIR}/update-active-slot.sh"
chown deploy:deploy "${MONITORING_DIR}/update-active-slot.sh"

# Run it once now
"${MONITORING_DIR}/update-active-slot.sh"

# Initialize backup metric (will be updated by backup-pg.sh)
echo "node_textfile_backup_last_success_timestamp_seconds $(date +%s)" > "${TEXTFILE_DIR}/backup.prom"
chown deploy:deploy "${TEXTFILE_DIR}/backup.prom"

# Add cron jobs for the deploy user
echo ">>> Installing cron jobs..."
CRON_ACTIVE_SLOT="* * * * * ${MONITORING_DIR}/update-active-slot.sh"
(crontab -u deploy -l 2>/dev/null | grep -v "update-active-slot.sh"; echo "${CRON_ACTIVE_SLOT}") | crontab -u deploy -
echo "  Active slot metric cron installed (every minute)."

# =============================================================================
# 7. Install Systemd Services
# =============================================================================
echo ">>> Installing systemd services..."

if [ -d "${SCRIPT_DIR}/systemd" ]; then
  cp "${SCRIPT_DIR}/systemd/prometheus.service" /etc/systemd/system/
  cp "${SCRIPT_DIR}/systemd/node-exporter.service" /etc/systemd/system/
  cp "${SCRIPT_DIR}/systemd/postgres-exporter.service" /etc/systemd/system/
  cp "${SCRIPT_DIR}/systemd/blackbox-exporter.service" /etc/systemd/system/
  cp "${SCRIPT_DIR}/systemd/alertmanager.service" /etc/systemd/system/
  cp "${SCRIPT_DIR}/systemd/alertmanager-discord.service" /etc/systemd/system/
  echo "  Systemd units copied."
else
  echo "  WARNING: systemd directory not found. Copy units manually to /etc/systemd/system/"
fi

systemctl daemon-reload

# =============================================================================
# 8. Enable and Start Services
# =============================================================================
echo ">>> Enabling and starting services..."

# Start alertmanager-discord first (port 9095), then alertmanager (port 9093)
SERVICES=(
  node-exporter
  postgres-exporter
  blackbox-exporter
  alertmanager-discord
  alertmanager
  prometheus
)

for SVC in "${SERVICES[@]}"; do
  systemctl enable "${SVC}"
  systemctl restart "${SVC}"
  sleep 1
  if systemctl is-active --quiet "${SVC}"; then
    echo "  ${SVC}: running"
  else
    echo "  ERROR: ${SVC} failed to start!"
    journalctl -u "${SVC}" --no-pager -n 10
  fi
done

# =============================================================================
# 9. Validate
# =============================================================================
echo ""
echo ">>> Validating Prometheus configuration..."
if promtool check config /etc/prometheus/prometheus.yml; then
  echo "  Prometheus config is valid."
else
  echo "  ERROR: Prometheus config is invalid!"
fi

if promtool check rules /etc/prometheus/alert-rules.yml; then
  echo "  Alert rules are valid."
else
  echo "  ERROR: Alert rules are invalid!"
fi

# Wait for Prometheus to be ready
echo ">>> Waiting for Prometheus to be ready..."
for i in $(seq 1 10); do
  if curl -sf http://127.0.0.1:9090/-/ready > /dev/null 2>&1; then
    echo "  Prometheus is ready."
    break
  fi
  if [ "${i}" -eq 10 ]; then
    echo "  WARNING: Prometheus did not become ready within 10 seconds."
  fi
  sleep 1
done

# Check scrape targets
echo ">>> Checking scrape targets..."
sleep 3
curl -sf http://127.0.0.1:9090/api/v1/targets | python3 -c "
import json, sys
data = json.load(sys.stdin)
targets = data.get('data', {}).get('activeTargets', [])
for t in targets:
    status = t.get('health', 'unknown')
    job = t.get('labels', {}).get('job', 'unknown')
    print(f'  {job}: {status}')
" 2>/dev/null || echo "  (Could not query targets yet — they may take a moment to appear)"

# =============================================================================
# Summary
# =============================================================================
echo ""
echo "=============================================="
echo "  Monitoring Setup Complete!"
echo "=============================================="
echo ""
echo "Services running:"
echo "  - Prometheus:          http://127.0.0.1:9090"
echo "  - Node Exporter:       http://127.0.0.1:9100"
echo "  - PostgreSQL Exporter: http://127.0.0.1:9187"
echo "  - Blackbox Exporter:   http://127.0.0.1:9115"
echo "  - Alertmanager:        http://127.0.0.1:9093"
echo "  - alertmanager-discord: http://127.0.0.1:9095"
echo ""
echo "All services bind to 127.0.0.1 only (not externally accessible)."
echo ""
echo "Discord alerts will be sent to your #prod-alerts channel."
echo ""
echo "Config files:"
echo "  - /etc/prometheus/prometheus.yml"
echo "  - /etc/prometheus/alert-rules.yml"
echo "  - /etc/prometheus/blackbox.yml"
echo "  - /etc/alertmanager/alertmanager.yml"
echo ""
echo "To reload configs after changes:"
echo "  curl -X POST http://127.0.0.1:9090/-/reload   # Prometheus"
echo "  curl -X POST http://127.0.0.1:9093/-/reload   # Alertmanager"
echo ""
