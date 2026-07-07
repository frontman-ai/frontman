#!/usr/bin/env bash

set -euo pipefail

mode="${1:-stale}"
stale_after="${STALE_AFTER:-1 hour}"
pg_host="${DB_HOST:-${PGHOST:-localhost}}"

export PGHOST="${pg_host}"
export PGUSER="${PGUSER:-postgres}"
export PGPASSWORD="${PGPASSWORD:-postgres}"
export PGDATABASE="${PGDATABASE:-postgres}"

run_psql() {
  psql --no-psqlrc --quiet --set ON_ERROR_STOP=1 "$@"
}

drop_database() {
  local database_name="$1"

  if [[ -z "${database_name}" ]]; then
    return 0
  fi

  echo "Dropping PostgreSQL test database: ${database_name}"
  run_psql --set db="${database_name}" <<'SQL'
SELECT pg_terminate_backend(pid)
FROM pg_stat_activity
WHERE datname = :'db'
  AND pid <> pg_backend_pid();

DROP DATABASE IF EXISTS :"db";
SQL
}

case "${mode}" in
  current-e2e)
    drop_database "${DB_NAME:-}"
    ;;

  current-test)
    if [[ -z "${MIX_TEST_DB_SUFFIX:-}" ]]; then
      echo "MIX_TEST_DB_SUFFIX is unset; skipping current test database drop"
      exit 0
    fi

    drop_database "frontman_server_test${MIX_TEST_PARTITION:-}${MIX_TEST_DB_SUFFIX:-}"
    ;;

  stale)
    echo "PostgreSQL data directory:"
    run_psql <<'SQL'
SHOW data_directory;
SQL

    echo "PostgreSQL database usage before stale cleanup:"
    run_psql <<'SQL'
SELECT datname, pg_size_pretty(pg_database_size(datname)) AS size
FROM pg_database
WHERE NOT datistemplate
ORDER BY pg_database_size(datname) DESC, datname;
SQL

    echo "PostgreSQL tablespace usage before stale cleanup:"
    run_psql <<'SQL'
SELECT spcname, nullif(pg_tablespace_location(oid), '') AS location, pg_size_pretty(pg_tablespace_size(oid)) AS size
FROM pg_tablespace
ORDER BY pg_tablespace_size(oid) DESC, spcname;
SQL

    echo "PostgreSQL WAL usage before stale cleanup:"
    run_psql <<'SQL'
SELECT pg_size_pretty(coalesce(sum(size), 0)) AS wal_size
FROM pg_ls_waldir();
SQL

    echo "PostgreSQL temp file usage before stale cleanup:"
    run_psql <<'SQL'
SELECT coalesce(pg_size_pretty(sum(size)), '0 bytes') AS temp_size
FROM pg_ls_tmpdir();
SQL

    echo "PostgreSQL test DB usage before stale cleanup:"
    run_psql <<'SQL'
SELECT datname, pg_size_pretty(pg_database_size(datname)) AS size
FROM pg_database
WHERE datname IN ('frontman_server_e2e', 'frontman_server_test')
   OR datname LIKE 'frontman_server_e2e_%'
   OR datname LIKE 'frontman_server_test%_run_%'
ORDER BY pg_database_size(datname) DESC, datname;
SQL

    echo "Dropping inactive Frontman test databases older than ${stale_after}"
    run_psql --set stale_after="${stale_after}" <<'SQL'
SELECT format('DROP DATABASE IF EXISTS %I;', datname)
FROM pg_database db
WHERE (
    datname IN ('frontman_server_e2e', 'frontman_server_test')
    OR datname LIKE 'frontman_server_e2e_%'
    OR datname LIKE 'frontman_server_test%_run_%'
  )
  AND NOT EXISTS (
    SELECT 1
    FROM pg_stat_activity activity
    WHERE activity.datname = db.datname
  )
  AND (pg_stat_file('base/' || oid || '/PG_VERSION', true)).modification < now() - :'stale_after'::interval
ORDER BY datname
\gexec
SQL

    echo "PostgreSQL test DB usage after stale cleanup:"
    run_psql <<'SQL'
SELECT datname, pg_size_pretty(pg_database_size(datname)) AS size
FROM pg_database
WHERE datname IN ('frontman_server_e2e', 'frontman_server_test')
   OR datname LIKE 'frontman_server_e2e_%'
   OR datname LIKE 'frontman_server_test%_run_%'
ORDER BY pg_database_size(datname) DESC, datname;
SQL

    echo "PostgreSQL database usage after stale cleanup:"
    run_psql <<'SQL'
SELECT datname, pg_size_pretty(pg_database_size(datname)) AS size
FROM pg_database
WHERE NOT datistemplate
ORDER BY pg_database_size(datname) DESC, datname;
SQL

    echo "PostgreSQL tablespace usage after stale cleanup:"
    run_psql <<'SQL'
SELECT spcname, nullif(pg_tablespace_location(oid), '') AS location, pg_size_pretty(pg_tablespace_size(oid)) AS size
FROM pg_tablespace
ORDER BY pg_tablespace_size(oid) DESC, spcname;
SQL

    echo "PostgreSQL WAL usage after stale cleanup:"
    run_psql <<'SQL'
SELECT pg_size_pretty(coalesce(sum(size), 0)) AS wal_size
FROM pg_ls_waldir();
SQL

    echo "PostgreSQL temp file usage after stale cleanup:"
    run_psql <<'SQL'
SELECT coalesce(pg_size_pretty(sum(size)), '0 bytes') AS temp_size
FROM pg_ls_tmpdir();
SQL
    ;;

  *)
    echo "Usage: $0 {stale|current-e2e|current-test}" >&2
    exit 64
    ;;
esac
