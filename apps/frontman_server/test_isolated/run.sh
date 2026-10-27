set -eu

export ELIXIR_ERL_OPTIONS="${ELIXIR_ERL_OPTIONS:-} +B i"
MIX_ENV=test mix run --no-start test_isolated/run.exs &
runner=$!
trap 'kill -TERM "$runner"; wait "$runner"; exit 143' INT TERM HUP
status=0
wait "$runner" || status=$?
exit "$status"
