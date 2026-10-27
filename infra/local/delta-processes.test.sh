#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
setsid bash -c '
  source "$1/infra/local/delta-processes.sh"
  trap delta_stop_process_group EXIT
  bash -c '\''sleep 60 & echo "$!" >"$1/grandchild"; wait'\'' bash "$2" &
  echo "$!" >"$2/child"
  for attempt in $(seq 1 100); do
    [[ -s "$2/grandchild" ]] && break
    sleep 0.01
  done
  [[ -s "$2/grandchild" ]]
' bash "$ROOT" "$TMP"
for file in child grandchild; do
  pid="$(cat "$TMP/$file")"
  for attempt in $(seq 1 100); do
    state="$(ps -o stat= -p "$pid" || true)"
    [[ -z "$state" || "$state" == Z* ]] && break
    sleep 0.01
  done
  [[ -z "$state" || "$state" == Z* ]] || {
    kill "$pid" || true
    echo "Process $pid survived group cleanup" >&2
    exit 1
  }
done
echo "Real child and grandchild processes stopped."
