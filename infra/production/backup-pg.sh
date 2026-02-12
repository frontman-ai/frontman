#!/usr/bin/env bash
# =============================================================================
# Frontman PostgreSQL Backup Script
#
# Daily pg_dump to local disk with 30-day retention.
# Runs as cron job under the deploy user.
#
# Cron entry (installed by server-setup.sh):
#   0 3 * * * /opt/frontman/backup-pg.sh >> /opt/frontman/backups/backup.log 2>&1
# =============================================================================
set -euo pipefail

# --- Configuration ---
DB_NAME="frontman_server_prod"
BACKUP_DIR="/opt/frontman/backups/daily"
RETENTION_DAYS=30

# --- Ensure backup directory exists ---
mkdir -p "${BACKUP_DIR}"

# --- Create backup ---
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="${BACKUP_DIR}/${DB_NAME}_${TIMESTAMP}.sql.gz"

echo "[$(date -Iseconds)] Starting backup of ${DB_NAME}..."
pg_dump "${DB_NAME}" | gzip > "${BACKUP_FILE}"

BACKUP_SIZE=$(du -h "${BACKUP_FILE}" | cut -f1)
echo "[$(date -Iseconds)] Backup complete: ${BACKUP_FILE} (${BACKUP_SIZE})"

# --- Prune old backups ---
DELETED=0
find "${BACKUP_DIR}" -name "*.sql.gz" -type f -mtime +${RETENTION_DAYS} | while read -r OLD_BACKUP; do
  echo "[$(date -Iseconds)] Removing old backup: ${OLD_BACKUP}"
  rm -f "${OLD_BACKUP}"
  DELETED=$((DELETED + 1))
done

# --- Summary ---
TOTAL_BACKUPS=$(find "${BACKUP_DIR}" -name "*.sql.gz" -type f | wc -l)
TOTAL_SIZE=$(du -sh "${BACKUP_DIR}" | cut -f1)
echo "[$(date -Iseconds)] Backups on disk: ${TOTAL_BACKUPS} (${TOTAL_SIZE} total)"
