#!/usr/bin/env bash
set -euo pipefail
export PATH="$HOME/.local/bin:$HOME/.local/share/mise/shims:$PATH"
cd /workspaces/frontman

case "${1:?}" in
  stop)
    if [[ -s /tmp/frontman-supervisor.pid ]]; then
      supervisor="$(cat /tmp/frontman-supervisor.pid)"
      if [[ ! "$supervisor" =~ ^[0-9]+$ ]] || (( supervisor <= 1 )); then
        echo "Invalid supervisor PID; pod shutdown is required." >&2
        exit 1
      fi
      if ! kill -0 "$supervisor" 2>/dev/null; then
        rm -f /tmp/frontman-supervisor.pid
        exit 0
      fi
      kill -TERM "$supervisor" 2>/dev/null || true
      for attempt in $(seq 1 100); do
        [[ -e /tmp/frontman-supervisor.pid ]] || exit 0
        if ! kill -0 "$supervisor" 2>/dev/null ||
          [[ "$(ps -p "$supervisor" -o stat=)" == Z* ]]; then
          rm -f /tmp/frontman-supervisor.pid
          exit 0
        fi
        sleep 0.1
      done
      echo "Supervisor did not stop within ten seconds." >&2
      exit 1
    fi
    ;;
  preview)
    make build-wordpress-preview
    ;;
  prepare)
    mise trust --all
    mise install --yes
    export RELEASE_ROOT=/tmp/frontman-env
    mkdir -p "$RELEASE_ROOT"
    cp apps/frontman_server/envs/.dev.env "$RELEASE_ROOT/"
    export STRIPE_WEBHOOK_SECRET
    STRIPE_WEBHOOK_SECRET="$(stripe listen --api-key "$STRIPE_SECRET_KEY" --print-secret)"
    [[ "$STRIPE_WEBHOOK_SECRET" == whsec_* ]]
    bash infra/local/worktree-setup.sh
    make build-wordpress-preview
    make -C libs/frontman-nextjs build
    make -C libs/frontman-astro build
    make -C libs/client build-standalone
    ;;
  start)
    container_started="$(date -d "$(ps -p 1 -o lstart=)" +%s)"
    for lock in lib/watch.lock /tmp/frontman-supervisor.pid; do
      if [[ -f "$lock" ]] && (( $(stat -c %Y "$lock") < container_started )); then
        rm -f "$lock"
      fi
    done
    if [[ -f /tmp/frontman-supervisor.pid ]] &&
      kill -0 "$(cat /tmp/frontman-supervisor.pid)" 2>/dev/null; then
      echo "Dev supervisor already running."
      exit 0
    fi
    nohup setsid bash infra/local/delta-dev.sh supervise "$2" >/proc/1/fd/1 2>/proc/1/fd/2 </dev/null &
    supervisor=$!
    for attempt in $(seq 1 50); do
      kill -0 "$supervisor" 2>/dev/null || {
        echo "Supervisor failed to start. Inspect make delta-logs." >&2
        exit 1
      }
      if [[ -s /tmp/frontman-supervisor.pid ]] &&
        [[ "$(cat /tmp/frontman-supervisor.pid)" == "$supervisor" ]]; then
        exit 0
      fi
      sleep 0.1
    done
    kill -TERM -- "-$supervisor" 2>/dev/null || true
    echo "Supervisor did not initialize within five seconds. Inspect make delta-logs." >&2
    exit 1
    ;;
  supervise)
    echo "$$" >/tmp/frontman-supervisor.pid
    source infra/local/delta-processes.sh
    trap 'exit 143' TERM INT
    trap 'delta_stop_process_group; rm -f /tmp/frontman-supervisor.pid' EXIT
    export PHX_HOST="$WORKTREE_HASH.api.frontman.local" PHX_URL_PORT="$2"
    export FRONTMAN_HOST="$PHX_HOST:$2"
    export FRONTMAN_CLIENT_URL="https://$WORKTREE_HASH.vite.frontman.local:$2/src/Main.res.mjs"
    export NEXTJS_URL="https://$WORKTREE_HASH.nextjs.frontman.local:$2/"
    export FRONTMAN_INTERNAL_DEV=true
    export RELEASE_ROOT=/tmp/frontman-env
    mkdir -p "$RELEASE_ROOT"
    cp apps/frontman_server/envs/.dev.env "$RELEASE_ROOT/"
    unset STRIPE_WEBHOOK_SECRET
    rm -f "$RELEASE_ROOT/.dev.stripe-webhook.env"
    STRIPE_WEBHOOK_ENV_DIR="$RELEASE_ROOT" make stripe-webhooks &
    listener=$!
    for attempt in $(seq 1 60); do
      kill -0 "$listener"
      [[ -s "$RELEASE_ROOT/.dev.stripe-webhook.env" ]] && break
      sleep 1
    done
    [[ -s "$RELEASE_ROOT/.dev.stripe-webhook.env" ]]
    make rescript-build
    make rescript-watch &
    (cd apps/frontman_server && make dev-container) &
    make dev-client &
    (cd libs/client && yarn vite build --config vite.config.standalone.ts --watch) &
    touch /tmp/frontman-bundles-started
    (cd libs/frontman-nextjs && yarn tsup --watch) &
    next_bundle=$!
    (cd libs/frontman-astro && yarn tsup --watch) &
    astro_bundle=$!
    for attempt in $(seq 1 60); do
      kill -0 "$next_bundle" "$astro_bundle"
      if [[ libs/frontman-nextjs/dist/index.js -nt /tmp/frontman-bundles-started ]] &&
        [[ libs/frontman-nextjs/dist/instrumentation.js -nt /tmp/frontman-bundles-started ]] &&
        [[ libs/frontman-astro/dist/index.js -nt /tmp/frontman-bundles-started ]] &&
        [[ libs/frontman-astro/dist/integration.js -nt /tmp/frontman-bundles-started ]]; then
        break
      fi
      sleep 1
    done
    [[ "$attempt" -lt 60 ]] || exit 1
    make dev-nextjs-prebuilt &
    (cd apps/marketing && yarn dev --host 0.0.0.0 --ignore-lock) &
    wait -n
    exit 1
    ;;
esac
