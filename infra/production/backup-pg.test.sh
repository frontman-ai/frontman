#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
TMP=$(mktemp -d)
trap 'rm -rf "${TMP}"' EXIT
export DEPLOY_ROOT="${TMP}/frontman"
export PATH="${TMP}/bin:${PATH}"
BACKUPS="${DEPLOY_ROOT}/backups/daily"
mkdir -p "${TMP}/bin" "${BACKUPS}" "${DEPLOY_ROOT}/green" "${DEPLOY_ROOT}/monitoring/textfile"
printf 'green\n' > "${DEPLOY_ROOT}/active_slot"
printf 'DATABASE_URL=ecto://test:test@localhost/test\n' > "${DEPLOY_ROOT}/green/env"
cat > "${TMP}/bin/pg_dump" <<'STUB'
#!/usr/bin/env bash
set -eu
[[ "$1" == postgresql://test:test@localhost/test ]]
printf 'test dump\n'
exit "${DUMP_EXIT:-0}"
STUB
chmod +x "${TMP}/bin/pg_dump"
for day in $(seq -w 1 31); do
  touch "${BACKUPS}/frontman_server_prod_202001${day}_030001.sql.gz"
done
touch "${BACKUPS}/unrelated.sql.gz" "${BACKUPS}/incomplete.sql.gz.tmp"
printf 'previous metric\n' > "${DEPLOY_ROOT}/monitoring/textfile/backup.prom"

if DUMP_EXIT=1 bash "${SCRIPT_DIR}/backup-pg.sh"; then
  echo 'FAIL: failed dump reported success' >&2
  exit 1
fi
[[ $(find "${BACKUPS}" -name 'frontman_server_prod_*.sql.gz' | wc -l) -eq 31 ]]
[[ $(find "${BACKUPS}" -name 'frontman_server_prod_*.tmp' | wc -l) -eq 0 ]]
grep -qx 'previous metric' "${DEPLOY_ROOT}/monitoring/textfile/backup.prom"

bash "${SCRIPT_DIR}/backup-pg.sh"
[[ $(find "${BACKUPS}" -name 'frontman_server_prod_*.sql.gz' | wc -l) -eq 14 ]]
[[ ! -f "${BACKUPS}/frontman_server_prod_20200118_030001.sql.gz" ]]
for day in $(seq 19 31); do
  [[ -f "${BACKUPS}/frontman_server_prod_202001${day}_030001.sql.gz" ]]
done
[[ -f "${BACKUPS}/unrelated.sql.gz" && -f "${BACKUPS}/incomplete.sql.gz.tmp" ]]
NEWEST=$(find "${BACKUPS}" -name 'frontman_server_prod_*.sql.gz' | LC_ALL=C sort | tail -1)
gzip -dc "${NEWEST}" | grep -qx 'test dump'
grep -q '^node_textfile_backup_last_success_timestamp_seconds ' "${DEPLOY_ROOT}/monitoring/textfile/backup.prom"

rm -- "${BACKUPS}"/frontman_server_prod_202001*.sql.gz
bash "${SCRIPT_DIR}/backup-pg.sh"
[[ -f "${NEWEST}" ]]
echo 'PASS: backup retention and failure safety'
