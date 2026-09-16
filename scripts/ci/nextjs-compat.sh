#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
NEXT_VERSION="${NEXT_VERSION:-}"
NEXT_LABEL="${NEXT_LABEL:-$NEXT_VERSION}"
PORT="${PORT:-3210}"
FRONTMAN_SERVER="${FRONTMAN_SERVER:-localhost:4002}"

if [ -z "$NEXT_VERSION" ]; then
  echo "[nextjs-compat] NEXT_VERSION is required" >&2
  exit 1
fi

WORK_ROOT="${RUNNER_TEMP:-/tmp}/frontman-nextjs-compat"
rm -rf "$WORK_ROOT"
mkdir -p "$WORK_ROOT"

CONSUMER_DIR="$WORK_ROOT/consumer"
PACK_DIR="$WORK_ROOT/pack"
LOG_DIR="$WORK_ROOT/logs"
mkdir -p "$CONSUMER_DIR/pages" "$PACK_DIR" "$LOG_DIR"

log() {
  printf '[nextjs-compat:%s] %s\n' "$NEXT_LABEL" "$*"
}

fail() {
  printf '[nextjs-compat:%s] ERROR: %s\n' "$NEXT_LABEL" "$*" >&2
  if [ -f "$LOG_DIR/next-dev.log" ]; then
    echo "[nextjs-compat:$NEXT_LABEL] --- next dev log (tail) ---" >&2
    tail -120 "$LOG_DIR/next-dev.log" >&2 || true
  fi
  exit 1
}

cleanup() {
  if [ -n "${DEV_PID:-}" ]; then
    kill "$DEV_PID" >/dev/null 2>&1 || true
    wait "$DEV_PID" >/dev/null 2>&1 || true
  fi
}
trap cleanup EXIT

log "packing @frontman-ai/nextjs from local build"
TARBALL="$(npm pack "$ROOT/libs/frontman-nextjs" --pack-destination "$PACK_DIR" --silent)"
TARBALL_PATH="$PACK_DIR/$TARBALL"
[ -f "$TARBALL_PATH" ] || fail "package tarball was not created at $TARBALL_PATH"

cp "$ROOT/test/e2e/fixtures/nextjs/pages/index.tsx" "$CONSUMER_DIR/pages/index.tsx"
cp "$ROOT/test/e2e/fixtures/nextjs/next.config.mjs" "$CONSUMER_DIR/next.config.mjs"

cat > "$CONSUMER_DIR/package.json" <<JSON
{
  "name": "frontman-nextjs-compat-consumer",
  "private": true,
  "type": "module",
  "scripts": {
    "dev": "next dev --turbopack",
    "build": "next build"
  },
  "dependencies": {
    "@frontman-ai/nextjs": "file:$TARBALL_PATH",
    "@opentelemetry/api": "^1.9.1",
    "@opentelemetry/sdk-node": "^0.221.0",
    "next": "$NEXT_VERSION",
    "react": "^19.2.8",
    "react-dom": "^19.2.8"
  },
  "devDependencies": {
    "@types/node": "^24.0.0",
    "@types/react": "^19.0.0",
    "typescript": "^5.0.0"
  }
}
JSON

log "installing clean consumer dependencies"
npm install --prefix "$CONSUMER_DIR" --no-audit --no-fund || fail "npm install failed for Next.js $NEXT_VERSION"

INSTALLED_NEXT_VERSION="$(node -p "require('$CONSUMER_DIR/node_modules/next/package.json').version")"
NEXT_MAJOR="${INSTALLED_NEXT_VERSION%%.*}"
log "installed Next.js $INSTALLED_NEXT_VERSION"

log "running packed installer"
(
  cd "$CONSUMER_DIR"
  node node_modules/@frontman-ai/nextjs/dist/cli.js install --skip-deps --server "$FRONTMAN_SERVER"
) || fail "frontman-nextjs installer failed for Next.js $INSTALLED_NEXT_VERSION"

if [ "$NEXT_MAJOR" -ge 16 ]; then
  GENERATED_FILE="proxy.ts"
  UNEXPECTED_FILE="middleware.ts"
else
  GENERATED_FILE="middleware.ts"
  UNEXPECTED_FILE="proxy.ts"
fi
GENERATED_PATH="$CONSUMER_DIR/$GENERATED_FILE"

[ -f "$GENERATED_PATH" ] || fail "expected generated file missing: $GENERATED_FILE"
[ ! -f "$CONSUMER_DIR/$UNEXPECTED_FILE" ] || fail "unexpected generated file present: $UNEXPECTED_FILE"
grep -q "createMiddleware" "$GENERATED_PATH" || fail "$GENERATED_FILE does not import/create Frontman middleware"
grep -q "host: '$FRONTMAN_SERVER'" "$GENERATED_PATH" || fail "$GENERATED_FILE does not include configured Frontman host"

if [ "$GENERATED_FILE" = "proxy.ts" ] && grep -q "runtime:" "$GENERATED_PATH"; then
  fail "$GENERATED_FILE contains route runtime config that Next.js $INSTALLED_NEXT_VERSION rejects"
fi

log "generated $GENERATED_FILE"

log "starting next dev smoke server"
(
  cd "$CONSUMER_DIR"
  NEXT_TELEMETRY_DISABLED=1 PORT="$PORT" node node_modules/next/dist/bin/next dev --turbopack -p "$PORT"
) > "$LOG_DIR/next-dev.log" 2>&1 &
DEV_PID=$!

READY=0
for _ in $(seq 1 180); do
  if ! kill -0 "$DEV_PID" >/dev/null 2>&1; then
    fail "next dev exited before becoming ready for Next.js $INSTALLED_NEXT_VERSION with $GENERATED_FILE"
  fi
  if curl -fsS "http://127.0.0.1:$PORT/" >/dev/null 2>&1; then
    READY=1
    break
  fi
  sleep 0.5
done
[ "$READY" = "1" ] || fail "next dev did not become ready for Next.js $INSTALLED_NEXT_VERSION with $GENERATED_FILE"

curl -fsS "http://127.0.0.1:$PORT/" | grep -q "Hello World" || fail "Next.js $INSTALLED_NEXT_VERSION home page did not render"
curl -fsS "http://127.0.0.1:$PORT/frontman/" | grep -q "frontman" || fail "Next.js $INSTALLED_NEXT_VERSION did not exercise generated $GENERATED_FILE in dev"
log "next dev smoke passed with $GENERATED_FILE"

cleanup
unset DEV_PID

log "running next build"
(
  cd "$CONSUMER_DIR"
  NEXT_TELEMETRY_DISABLED=1 node node_modules/next/dist/bin/next build
) || fail "next build failed for Next.js $INSTALLED_NEXT_VERSION with generated $GENERATED_FILE"

log "compatibility check passed"
