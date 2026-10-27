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

for phase in bundles ongoing build; do
  for service_status in 0 23; do
    case_dir="$TMP/$phase-$service_status"
    mkdir "$case_dir"
    supervisor_status=0
    timeout --foreground 12 setsid bash -c '
      set -euo pipefail
      source "$1/infra/local/delta-processes.sh"
      trap delta_stop_process_group EXIT
      dir="$2"
      phase="$3"
      service_status="$4"
      sleep 60 &
      services=("$!")
      echo "$!" >"$dir/sibling"
      bash -c '\''
        while [[ ! -e "$1/release" ]]; do sleep 0.01; done
        exit "$2"
      '\'' bash "$dir" "$service_status" &
      service=$!
      services+=("$service")
      sleep 60 &
      bundle=$!
      echo "$bundle" >"$dir/bundle"
      if [[ "$phase" != build ]]; then
        services+=("$bundle")
      fi
      delta_check_processes "${services[@]}"
      touch "$dir/release"
      while kill -0 "$service" 2>/dev/null; do sleep 0.01; done
      if [[ "$phase" == ongoing ]]; then
        touch "$dir/ready"
        while true; do
          delta_check_processes "${services[@]}"
          sleep 0.01
        done
      else
        while [[ ! -e "$dir/ready" ]]; do
          delta_check_processes "${services[@]}"
          sleep 0.01
        done
      fi
    ' bash "$ROOT" "$case_dir" "$phase" "$service_status" >"$case_dir/output" 2>&1 || supervisor_status=$?
    [[ "$supervisor_status" == 1 ]] || {
      cat "$case_dir/output"
      echo "$phase: expected supervisor failure, got $supervisor_status" >&2
      exit 1
    }
    grep -Eq "Service [0-9]+ exited with status $service_status\\." "$case_dir/output"
    for file in sibling bundle; do
      pid="$(cat "$case_dir/$file")"
      state="$(ps -o stat= -p "$pid" || true)"
      [[ -z "$state" || "$state" == Z* ]] || {
        kill "$pid" || true
        echo "$phase: process $pid survived service completion" >&2
        exit 1
      }
    done
    echo "$phase: service exit $service_status failed fast and stopped siblings."
  done
done
