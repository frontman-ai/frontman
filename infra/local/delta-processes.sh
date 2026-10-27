#!/usr/bin/env bash
delta_check_processes() {
  local pid status
  for pid in "$@"; do
    if ! kill -0 "$pid" 2>/dev/null; then
      status=0
      wait "$pid" || status=$?
      echo "Service $pid exited with status $status." >&2
      exit 1
    fi
  done
}

delta_stop_process_group() {
  trap '' TERM INT
  kill -TERM -- "-$$" 2>/dev/null || true
  sleep 2
  while read -r pid group; do
    if [[ "$group" == "$$" && "$pid" != "$$" ]]; then
      kill -KILL "$pid" 2>/dev/null || true
    fi
  done < <(ps -eo pid=,pgid=)
  wait || true
}
