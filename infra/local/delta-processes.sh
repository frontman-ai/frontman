#!/usr/bin/env bash
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
