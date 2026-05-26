#!/usr/bin/env bash
# =============================================================================
# Frontman Notifier Production Setup
# Run on the existing production server as root.
# =============================================================================
set -euo pipefail

DEPLOY_ROOT="/opt/frontman-notifier"
SERVICE_NAME="frontman-notifier"
FRONTMAN_ENV="/opt/frontman/blue/env"

echo "=== Frontman Notifier Setup ==="
echo "Deploy root: ${DEPLOY_ROOT}"
echo ""

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

frontman_database_url() {
  if [ -f "${FRONTMAN_ENV}" ]; then
    DATABASE_URL_FROM_FRONTMAN=$(grep '^DATABASE_URL=' "${FRONTMAN_ENV}" | tail -n 1 | cut -d= -f2- || true)
    if [ -n "${DATABASE_URL_FROM_FRONTMAN}" ]; then
      printf '%s' "${DATABASE_URL_FROM_FRONTMAN}"
      return
    fi
  fi

  printf '%s' "ecto://frontman:DB_PASSWORD@localhost/frontman_server_prod"
}

sed_escape() {
  printf '%s' "$1" | sed -e 's/[#&]/\\&/g'
}

echo ">>> Creating directories..."
mkdir -p "${DEPLOY_ROOT}/build" "${DEPLOY_ROOT}/releases" "${DEPLOY_ROOT}/state"
chown -R deploy:deploy "${DEPLOY_ROOT}"

echo ">>> Installing systemd service..."
cp "${SCRIPT_DIR}/systemd/${SERVICE_NAME}.service" "/etc/systemd/system/${SERVICE_NAME}.service"
systemctl daemon-reload
systemctl enable "${SERVICE_NAME}"

echo ">>> Configuring deploy sudoers..."
cat > /etc/sudoers.d/deploy-frontman-notifier <<'SUDOERS'
deploy ALL=(ALL) NOPASSWD: /usr/bin/systemctl restart frontman-notifier
deploy ALL=(ALL) NOPASSWD: /usr/bin/systemctl stop frontman-notifier
deploy ALL=(ALL) NOPASSWD: /usr/bin/systemctl start frontman-notifier
deploy ALL=(ALL) NOPASSWD: /usr/bin/systemctl status frontman-notifier
SUDOERS
chmod 440 /etc/sudoers.d/deploy-frontman-notifier

echo ">>> Creating environment file..."
if [ ! -f "${DEPLOY_ROOT}/env" ]; then
  DATABASE_URL=$(frontman_database_url)
  DATABASE_URL_FOR_SED=$(sed_escape "${DATABASE_URL}")
  RELEASE_COOKIE=$(openssl rand -base64 32 | tr -dc 'a-zA-Z0-9' | head -c 32)

  sed \
    -e "s#DATABASE_URL=.*#DATABASE_URL=${DATABASE_URL_FOR_SED}#" \
    -e "s#RELEASE_COOKIE=GENERATED_BY_SETUP_SCRIPT#RELEASE_COOKIE=${RELEASE_COOKIE}#" \
    "${SCRIPT_DIR}/env.template" > "${DEPLOY_ROOT}/env"

  chown deploy:deploy "${DEPLOY_ROOT}/env"
  chmod 600 "${DEPLOY_ROOT}/env"
  echo "Created ${DEPLOY_ROOT}/env. Fill Discord webhook URLs and optional GITHUB_TOKEN."
else
  echo "${DEPLOY_ROOT}/env already exists; leaving it unchanged."
fi

echo ""
echo "=============================================="
echo "  Frontman Notifier Setup Complete"
echo "=============================================="
echo ""
echo "Next steps:"
echo "1. Edit ${DEPLOY_ROOT}/env and fill Discord webhook URLs."
echo "2. Run the deploy-notifier workflow or push a notifier path change to main."
