#!/usr/bin/env bash
# =============================================================================
# Frontman Production Server Setup
# Run on a fresh Hetzner Ubuntu 24.04 server as root
#
# Usage: ssh root@<server-ip> 'bash -s' < server-setup.sh
#
# Prerequisites:
#   - Fresh Hetzner server with Ubuntu 24.04 (x86_64 or ARM64)
#   - DNS A record for api.frontman.sh pointing to server IP (Cloudflare DNS-only mode)
#   - CI SSH public key ready to paste
# =============================================================================
set -euo pipefail

# --- Configuration ---
APP_NAME="frontman"
DEPLOY_ROOT="/opt/${APP_NAME}"
DB_NAME="frontman_server_prod"
DB_USER="frontman"
DOMAIN="api.frontman.sh"

echo "=== Frontman Production Server Setup ==="
echo "Deploy root: ${DEPLOY_ROOT}"
echo "Database:    ${DB_NAME}"
echo "Domain:      ${DOMAIN}"
echo ""

# =============================================================================
# 1. System Updates & Base Packages
# =============================================================================
echo ">>> Installing system packages..."
apt-get update -y
apt-get upgrade -y
apt-get install -y \
  curl \
  unzip \
  fail2ban \
  ufw \
  logrotate \
  libstdc++6 \
  openssl \
  libncurses6 \
  locales \
  ca-certificates

# Set locale (required by BEAM)
sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen
locale-gen
update-locale LANG=en_US.UTF-8

# =============================================================================
# 2. Firewall (UFW)
# =============================================================================
echo ">>> Configuring firewall..."
ufw default deny incoming
ufw default allow outgoing
ufw allow 22/tcp   comment "SSH"
ufw allow 80/tcp   comment "HTTP - Caddy ACME challenge"
ufw allow 443/tcp  comment "HTTPS - Caddy TLS"
ufw --force enable
echo "Firewall enabled."

# =============================================================================
# 3. Fail2Ban (SSH brute-force protection)
# =============================================================================
echo ">>> Configuring fail2ban..."
systemctl enable fail2ban
systemctl start fail2ban

# =============================================================================
# 4. Deploy User
# =============================================================================
echo ">>> Creating deploy user..."
if ! id "deploy" &>/dev/null; then
  useradd -m -s /bin/bash deploy
fi
mkdir -p /home/deploy/.ssh
chmod 700 /home/deploy/.ssh

# Prompt for CI SSH public key
echo ""
echo "=== SSH Key Setup ==="
echo "Paste the CI runner's SSH public key (or press Enter to skip and add later):"
read -r SSH_KEY
if [ -n "${SSH_KEY}" ]; then
  echo "${SSH_KEY}" >> /home/deploy/.ssh/authorized_keys
  chmod 600 /home/deploy/.ssh/authorized_keys
  chown -R deploy:deploy /home/deploy/.ssh
  echo "SSH key added for deploy user."
else
  echo "Skipped. Add the key later to /home/deploy/.ssh/authorized_keys"
fi

# =============================================================================
# 5. Sudoers for deploy user (passwordless for specific commands)
# =============================================================================
echo ">>> Configuring sudoers for deploy user..."
cat > /etc/sudoers.d/deploy-frontman <<'SUDOERS'
# Allow deploy user to manage frontman services and Caddy without password
deploy ALL=(ALL) NOPASSWD: /usr/bin/systemctl restart frontman-blue
deploy ALL=(ALL) NOPASSWD: /usr/bin/systemctl restart frontman-green
deploy ALL=(ALL) NOPASSWD: /usr/bin/systemctl stop frontman-blue
deploy ALL=(ALL) NOPASSWD: /usr/bin/systemctl stop frontman-green
deploy ALL=(ALL) NOPASSWD: /usr/bin/systemctl start frontman-blue
deploy ALL=(ALL) NOPASSWD: /usr/bin/systemctl start frontman-green
deploy ALL=(ALL) NOPASSWD: /usr/bin/systemctl reload caddy
SUDOERS
chmod 440 /etc/sudoers.d/deploy-frontman

# =============================================================================
# 6. PostgreSQL 17
# =============================================================================
echo ">>> Installing PostgreSQL 17..."

# Add PostgreSQL apt repo
apt-get install -y postgresql-common
/usr/share/postgresql-common/pgdg/apt.postgresql.org.sh -y

apt-get install -y postgresql-17 postgresql-client-17

echo ">>> Configuring PostgreSQL..."

# Generate a random password for the DB user
DB_PASSWORD=$(openssl rand -base64 32 | tr -dc 'a-zA-Z0-9' | head -c 32)

sudo -u postgres psql -c "CREATE USER ${DB_USER} WITH PASSWORD '${DB_PASSWORD}';"
sudo -u postgres psql -c "CREATE DATABASE ${DB_NAME} OWNER ${DB_USER};"

# PostgreSQL tuning — auto-detect RAM and set reasonable defaults
PG_CONF="/etc/postgresql/17/main/postgresql.conf"
TOTAL_RAM_KB=$(grep MemTotal /proc/meminfo | awk '{print $2}')
TOTAL_RAM_GB=$((TOTAL_RAM_KB / 1024 / 1024))
SHARED_BUFFERS="$((TOTAL_RAM_GB / 4))GB"
EFFECTIVE_CACHE="$((TOTAL_RAM_GB * 3 / 4))GB"

cat >> "${PG_CONF}" <<PGCONF

# --- Frontman production tuning (auto-detected: ${TOTAL_RAM_GB}GB RAM) ---
shared_buffers = ${SHARED_BUFFERS}
effective_cache_size = ${EFFECTIVE_CACHE}
work_mem = 16MB
maintenance_work_mem = 512MB
max_connections = 100
wal_buffers = 64MB
checkpoint_completion_target = 0.9
random_page_cost = 1.1
effective_io_concurrency = 200
PGCONF

# Ensure local connections use md5 auth for the frontman user
PG_HBA="/etc/postgresql/17/main/pg_hba.conf"
# Add before the default local rules
sed -i '/^# "local" is for Unix domain socket connections only/a local   '"${DB_NAME}"'   '"${DB_USER}"'   md5' "${PG_HBA}"
sed -i '/^# IPv4 local connections:/a host    '"${DB_NAME}"'   '"${DB_USER}"'   127.0.0.1/32   md5' "${PG_HBA}"

systemctl restart postgresql
systemctl enable postgresql

echo ""
echo "=== PostgreSQL Setup Complete ==="
echo "Database: ${DB_NAME}"
echo "User:     ${DB_USER}"
echo "Password: ${DB_PASSWORD}"
echo ""
echo "DATABASE_URL=ecto://${DB_USER}:${DB_PASSWORD}@localhost/${DB_NAME}"
echo ""
echo ">>> SAVE THIS PASSWORD - it will not be shown again <<<"
echo ""

# =============================================================================
# 7. Caddy (Reverse Proxy + Auto TLS)
# =============================================================================
echo ">>> Installing Caddy..."
apt-get install -y debian-keyring debian-archive-keyring apt-transport-https
curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' | gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg
curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' | tee /etc/apt/sources.list.d/caddy-stable.list
apt-get update -y
apt-get install -y caddy

# Write initial Caddyfile (blue slot is default first active)
cat > /etc/caddy/Caddyfile <<CADDYFILE
${DOMAIN} {
    reverse_proxy localhost:4000
}
CADDYFILE

systemctl enable caddy
systemctl restart caddy
echo "Caddy installed and running."

# =============================================================================
# 8. Application Directory Structure
# =============================================================================
echo ">>> Creating application directories..."
mkdir -p "${DEPLOY_ROOT}/blue/releases"
mkdir -p "${DEPLOY_ROOT}/green/releases"
mkdir -p "${DEPLOY_ROOT}/backups/daily"
echo "blue" > "${DEPLOY_ROOT}/active_slot"

# Copy deploy scripts
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "${SCRIPT_DIR}/deploy.sh" ]; then
  cp "${SCRIPT_DIR}/deploy.sh" "${DEPLOY_ROOT}/deploy.sh"
  cp "${SCRIPT_DIR}/rollback.sh" "${DEPLOY_ROOT}/rollback.sh"
  cp "${SCRIPT_DIR}/backup-pg.sh" "${DEPLOY_ROOT}/backup-pg.sh"
  chmod +x "${DEPLOY_ROOT}/deploy.sh" "${DEPLOY_ROOT}/rollback.sh" "${DEPLOY_ROOT}/backup-pg.sh"
fi

chown -R deploy:deploy "${DEPLOY_ROOT}"
echo "Directory structure created at ${DEPLOY_ROOT}"

# =============================================================================
# 9. Systemd Services
# =============================================================================
echo ">>> Installing systemd services..."
if [ -f "${SCRIPT_DIR}/systemd/frontman-blue.service" ]; then
  cp "${SCRIPT_DIR}/systemd/frontman-blue.service" /etc/systemd/system/
  cp "${SCRIPT_DIR}/systemd/frontman-green.service" /etc/systemd/system/
else
  echo "WARNING: systemd unit files not found. Copy them manually to /etc/systemd/system/"
fi
systemctl daemon-reload
systemctl enable frontman-blue frontman-green

# =============================================================================
# 10. Environment File Templates
# =============================================================================
echo ">>> Creating environment file templates..."

# Generate a secret key base
SECRET_KEY_BASE=$(openssl rand -base64 64 | tr -dc 'a-zA-Z0-9' | head -c 64)
RELEASE_COOKIE=$(openssl rand -base64 32 | tr -dc 'a-zA-Z0-9' | head -c 32)

for SLOT in blue green; do
  if [ "${SLOT}" = "blue" ]; then
    PORT=4000
    NODE_NAME="frontman_blue"
  else
    PORT=4001
    NODE_NAME="frontman_green"
  fi

  cat > "${DEPLOY_ROOT}/${SLOT}/env" <<ENV
# Frontman Server - ${SLOT} slot environment
# Generated by server-setup.sh on $(date -Iseconds)

PORT=${PORT}
PHX_HOST=${DOMAIN}
PHX_SERVER=true

DATABASE_URL=ecto://${DB_USER}:${DB_PASSWORD}@localhost/${DB_NAME}
# Local PostgreSQL - no SSL needed
DATABASE_SSL=false

SECRET_KEY_BASE=${SECRET_KEY_BASE}

RELEASE_NODE=${NODE_NAME}@127.0.0.1
RELEASE_COOKIE=${RELEASE_COOKIE}
RELEASE_DISTRIBUTION=name

# --- Fill in these values ---
CLOAK_KEY=CHANGE_ME
WORKOS_API_KEY=CHANGE_ME
WORKOS_CLIENT_ID=CHANGE_ME
ARIZE_API_KEY=CHANGE_ME
ARIZE_SPACE_ID=CHANGE_ME
ENV

  chown deploy:deploy "${DEPLOY_ROOT}/${SLOT}/env"
  chmod 600 "${DEPLOY_ROOT}/${SLOT}/env"
done

echo "Environment files created. Edit /opt/frontman/{blue,green}/env to fill in secrets."

# =============================================================================
# 11. Backup Cron Job
# =============================================================================
echo ">>> Setting up backup cron job..."
# Run daily at 3:00 AM as the deploy user
CRON_LINE="0 3 * * * ${DEPLOY_ROOT}/backup-pg.sh >> ${DEPLOY_ROOT}/backups/backup.log 2>&1"

# Add to deploy user's crontab (replace if exists)
(crontab -u deploy -l 2>/dev/null | grep -v "backup-pg.sh"; echo "${CRON_LINE}") | crontab -u deploy -
echo "Backup cron job installed (daily at 3:00 AM)."

# =============================================================================
# 12. Log Rotation
# =============================================================================
echo ">>> Configuring log rotation..."
cat > /etc/logrotate.d/frontman <<'LOGROTATE'
/opt/frontman/backups/backup.log {
    weekly
    rotate 4
    compress
    missingok
    notifempty
}
LOGROTATE

# =============================================================================
# Summary
# =============================================================================
echo ""
echo "=============================================="
echo "  Frontman Server Setup Complete!"
echo "=============================================="
echo ""
echo "Next steps:"
echo ""
echo "1. Save the database credentials above"
echo ""
echo "2. Edit the environment files with real secrets:"
echo "   nano /opt/frontman/blue/env"
echo "   nano /opt/frontman/green/env"
echo ""
echo "3. Ensure DNS A record for ${DOMAIN} points to this server"
echo "   (Use Cloudflare DNS-only mode, grey cloud)"
echo ""
echo "4. Add CI SSH key to /home/deploy/.ssh/authorized_keys (if skipped)"
echo ""
echo "5. Deploy the first release:"
echo "   scp release.tar.gz deploy@<server>:/tmp/"
echo "   ssh deploy@<server> '/opt/frontman/deploy.sh /tmp/release.tar.gz'"
echo ""
