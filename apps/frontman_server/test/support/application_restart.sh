set -u
export MIX_ENV=test
export MIX_TEST_PARTITION=""
MIX_TEST_DB_SUFFIX="_restart_$(elixir -e 'IO.write(Base.encode16(:crypto.strong_rand_bytes(16), case: :lower))')"
if [[ ! "$MIX_TEST_DB_SUFFIX" =~ ^_restart_[0-9a-f]{32}$ ]]; then
  exit 1
fi
export MIX_TEST_DB_SUFFIX
directory=$(mktemp -d) || exit 1
mkfifo "$directory/timer" || exit 1
exec 3<>"$directory/timer"
child=""
timer=""
interrupted=0
abort() {
  trap '' INT TERM
  interrupted=1
  if [ -n "$child" ]; then
    kill -KILL "$child" 2>/dev/null || true
  fi
}
wait_owned() {
  local seconds=$1
  (
    trap 'exit 0' TERM
    read -r -t "$seconds" -u 3 || {
      touch "$directory/timeout"
      kill -KILL "$child" 2>/dev/null || true
    }
  ) &
  timer=$!
  if [ "$interrupted" -eq 1 ]; then
    kill -KILL "$child" 2>/dev/null || true
  fi
  wait "$child"
  status=$?
  if [ "$interrupted" -eq 1 ]; then
    wait "$child" 2>/dev/null || true
    status=130
  fi
  kill -TERM "$timer" 2>/dev/null || true
  wait "$timer" 2>/dev/null || true
  timer=""
  child=""
  if [ -f "$directory/timeout" ]; then
    rm "$directory/timeout"
    status=124
  fi
}
cleanup() {
  local original=$?
  trap '' INT TERM
  trap - EXIT
  interrupted=0
  elixir -S mix ecto.drop --quiet &
  child=$!
  wait_owned 60
  rm -rf "$directory"
  if [ "$original" -eq 0 ]; then
    exit "$status"
  fi
  exit "$original"
}
trap cleanup EXIT
trap abort INT TERM
elixir -S mix test.application_restart "$@" &
child=$!
wait_owned "${RESTART_TEST_TIMEOUT_SECONDS:-300}"
exit "$status"
