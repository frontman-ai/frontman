#!/bin/sh
set -eu
temporary=$(mktemp -d)
trap 'rm -rf "$temporary"' EXIT HUP INT TERM
cat > "$temporary/psql" <<'PSQL'
#!/bin/sh
set -eu
test "$PGDATABASE" = 'fake_connection_secret'
test "${PGSERVICE-unset}" = unset
test "$PGCONNECT_TIMEOUT" = 5
test "$PGOPTIONS" = '-c default_transaction_read_only=on -c statement_timeout=15000'
test "$*" = '--no-psqlrc --no-password --set ON_ERROR_STOP=1 --single-transaction --file priv/scripts/activation_snapshot.sql'
exit "${FAKE_STATUS:-0}"
PSQL
chmod +x "$temporary/psql"
export PATH="$temporary:$PATH" ACTIVATION_SNAPSHOT_DATABASE=fake_connection_secret
export PGSERVICE=hostile_service
export PGOPTIONS='-c default_transaction_read_only=off -c statement_timeout=0'
make --no-print-directory activation-snapshot
for connection in '' 'postgresql://secret/db?options=-cstatement_timeout=0' 'dbname=db options=hostile'; do
  if ACTIVATION_SNAPSHOT_DATABASE="$connection" sh priv/scripts/activation_snapshot.sh 2>"$temporary/error"; then
    exit 1
  fi
  grep -q 'plain authorized read-only database name' "$temporary/error"
  ! grep -q 'secret' "$temporary/error"
done
if FAKE_STATUS=37 make --no-print-directory activation-snapshot >"$temporary/make" 2>&1; then
  exit 1
fi
grep -q 'Error 37' "$temporary/make"
grep -q 'psql status 37' "$temporary/make"
! grep -q 'fake_connection_secret' "$temporary/make"
