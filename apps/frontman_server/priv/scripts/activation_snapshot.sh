#!/bin/sh
set -eu
case "${ACTIVATION_SNAPSHOT_DATABASE:-}" in
  ''|*[!a-zA-Z0-9_]*)
    echo 'Set ACTIVATION_SNAPSHOT_DATABASE to a plain authorized read-only database name.' >&2
    exit 1 ;;
esac
command -v psql >/dev/null || { echo 'psql is required.' >&2; exit 127; }
export PGDATABASE="$ACTIVATION_SNAPSHOT_DATABASE" PGCONNECT_TIMEOUT=5
unset PGSERVICE PGSERVICEFILE
export PGOPTIONS='-c default_transaction_read_only=on -c statement_timeout=15000'
psql --no-psqlrc --no-password --set ON_ERROR_STOP=1 --single-transaction \
  --file priv/scripts/activation_snapshot.sql 2>/dev/null || {
  status=$?
  echo "Activation snapshot failed (psql status $status); check connection/query locally." >&2
  exit "$status"
}
