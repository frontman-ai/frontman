#!/usr/bin/env bash
set -euo pipefail
cd /

DEPLOY_ROOT="${DEPLOY_ROOT:-/opt/frontman}"
DB_NAME="frontman_server_prod"
BACKUP_DIR="${DEPLOY_ROOT}/backups/daily"
RETENTION_COUNT=14

ACTIVE_SLOT=$(<"${DEPLOY_ROOT}/active_slot")
ENV_FILE="${DEPLOY_ROOT}/${ACTIVE_SLOT}/env"
set -a
. "${ENV_FILE}"
set +a
: "${DATABASE_URL:?DATABASE_URL must be set in the active slot env}"
PG_DUMP_URL="${DATABASE_URL}"
if [[ "${PG_DUMP_URL}" == ecto://* ]]; then
  PG_DUMP_URL="postgresql://${PG_DUMP_URL#ecto://}"
fi

mkdir -p "${BACKUP_DIR}"

TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="${BACKUP_DIR}/${DB_NAME}_${TIMESTAMP}.sql.gz"
TMP_FILE="${BACKUP_FILE}.tmp"
trap 'rm -f "${TMP_FILE}"' EXIT

echo "[$(date -Iseconds)] Starting backup of ${DB_NAME}..."
pg_dump "${PG_DUMP_URL}" | gzip > "${TMP_FILE}"
mv "${TMP_FILE}" "${BACKUP_FILE}"

BACKUP_SIZE=$(du -h "${BACKUP_FILE}" | cut -f1)
echo "[$(date -Iseconds)] Backup complete: ${BACKUP_FILE} (${BACKUP_SIZE})"

find "${BACKUP_DIR}" -maxdepth 1 -name "${DB_NAME}_*.sql.gz" -type f -print0 \
  | LC_ALL=C sort -zr \
  | tail -z -n +$((RETENTION_COUNT + 1)) \
  | while IFS= read -r -d '' OLD_BACKUP; do
    echo "[$(date -Iseconds)] Removing old backup: ${OLD_BACKUP}"
    rm -- "${OLD_BACKUP}"
  done

TEXTFILE_DIR="${DEPLOY_ROOT}/monitoring/textfile"
if [ -d "${TEXTFILE_DIR}" ]; then
  echo "node_textfile_backup_last_success_timestamp_seconds $(date +%s)" > "${TEXTFILE_DIR}/backup.prom"
fi

TOTAL_BACKUPS=$(find "${BACKUP_DIR}" -maxdepth 1 -name "${DB_NAME}_*.sql.gz" -type f | wc -l)
TOTAL_SIZE=$(du -sh "${BACKUP_DIR}" | cut -f1)
echo "[$(date -Iseconds)] Backups on disk: ${TOTAL_BACKUPS} (${TOTAL_SIZE} total)"
