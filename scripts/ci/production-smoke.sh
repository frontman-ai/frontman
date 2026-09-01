#!/usr/bin/env bash
set -euo pipefail

production_origin="${PRODUCTION_ORIGIN:-https://api.frontman.sh}"
connect_timeout_seconds="${PRODUCTION_SMOKE_CONNECT_TIMEOUT_SECONDS:-5}"
max_time_seconds="${PRODUCTION_SMOKE_MAX_TIME_SECONDS:-20}"

curl_base_args=(
  --connect-timeout "$connect_timeout_seconds"
  --max-time "$max_time_seconds"
  -fsS
)

check_page() {
  local path="$1"

  curl "${curl_base_args[@]}" "${production_origin}${path}" >/dev/null
}

check_redirect() {
  local path="$1"
  local expected_provider="$2"
  local headers
  local status
  local location

  headers="$(mktemp)"

  if ! status="$(
    curl \
      --connect-timeout "$connect_timeout_seconds" \
      --max-time "$max_time_seconds" \
      -sS \
      -o /dev/null \
      -D "$headers" \
      -w '%{http_code}' \
      "${production_origin}${path}"
  )"; then
    rm -f "$headers"
    echo "Request failed for ${path}" >&2
    exit 1
  fi

  location="$(
    awk 'BEGIN{IGNORECASE=1} /^location:/ {sub(/\r$/, ""); print substr($0, 11)}' \
      "$headers" | tail -1
  )"
  rm -f "$headers"

  if [ "$status" != "302" ]; then
    echo "Expected ${path} to return 302, got ${status}" >&2
    exit 1
  fi

  if ! printf '%s' "$location" | grep -q 'https://api.workos.com/user_management/authorize'; then
    echo "Expected ${path} to redirect to WorkOS, got: ${location}" >&2
    exit 1
  fi

  if ! printf '%s' "$location" | grep -q "provider=${expected_provider}"; then
    echo "Expected ${path} to include provider=${expected_provider}, got: ${location}" >&2
    exit 1
  fi
}

check_page /health
check_page /health/ready
check_page /users/log-in
check_redirect /auth/google GoogleOAuth
check_redirect /auth/github GitHubOAuth
