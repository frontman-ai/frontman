#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(git rev-parse --show-toplevel)"
RUNTIME="${CONTAINER_RUNTIME:-docker}"
WORDPRESS_VERSION="${WORDPRESS_VERSION:-7.0.2}"
PHP_VERSION="${PHP_VERSION:-8.4}"
PLUGIN_VERSION="$(bash "$ROOT_DIR/scripts/validate-wordpress-plugin-release.sh")"
RUN_ID="frontman-wp-runtime-$$"
NETWORK="${RUN_ID}-network"
DATABASE="${RUN_ID}-database"
WORDPRESS="${RUN_ID}-wordpress"
IMAGE="${RUN_ID}-image"
BUILD_DIR="$(mktemp -d)"

cleanup() {
  "$RUNTIME" rm -f "$WORDPRESS" "$DATABASE" >/dev/null 2>&1 || true
  "$RUNTIME" network rm "$NETWORK" >/dev/null 2>&1 || true
  "$RUNTIME" image rm "$IMAGE" >/dev/null 2>&1 || true
  rm -rf "$BUILD_DIR"
}
trap cleanup EXIT

make -C "$ROOT_DIR" package-wordpress-plugin VERSION="$PLUGIN_VERSION" >/dev/null
curl -fsSL "https://wordpress.org/wordpress-${WORDPRESS_VERSION}.tar.gz" -o "$BUILD_DIR/wordpress.tar.gz"
"$RUNTIME" build \
  --build-arg PHP_VERSION="$PHP_VERSION" \
  -f "$ROOT_DIR/libs/frontman-wordpress/tests/integration/Dockerfile" \
  -t "$IMAGE" \
  "$BUILD_DIR" >/dev/null

"$RUNTIME" network create "$NETWORK" >/dev/null
"$RUNTIME" run -d --name "$DATABASE" --network "$NETWORK" \
  -e MARIADB_DATABASE=wordpress \
  -e MARIADB_USER=wordpress \
  -e MARIADB_PASSWORD=wordpress \
  -e MARIADB_ROOT_PASSWORD=wordpress \
  docker.io/library/mariadb:11 >/dev/null

"$RUNTIME" run -d --name "$WORDPRESS" --network "$NETWORK" \
  -e WORDPRESS_DB_HOST="$DATABASE" \
  -e WORDPRESS_DB_USER=wordpress \
  -e WORDPRESS_DB_PASSWORD=wordpress \
  -e WORDPRESS_DB_NAME=wordpress \
  "$IMAGE" >/dev/null

for _ in $(seq 1 60); do
  if "$RUNTIME" exec "$WORDPRESS" php -r '$db = @new mysqli(getenv("WORDPRESS_DB_HOST"), getenv("WORDPRESS_DB_USER"), getenv("WORDPRESS_DB_PASSWORD"), getenv("WORDPRESS_DB_NAME")); exit($db->connect_errno ? 1 : 0);' >/dev/null 2>&1; then
    break
  fi
  sleep 2
done

"$RUNTIME" exec "$WORDPRESS" php -r '$db = @new mysqli(getenv("WORDPRESS_DB_HOST"), getenv("WORDPRESS_DB_USER"), getenv("WORDPRESS_DB_PASSWORD"), getenv("WORDPRESS_DB_NAME")); if ($db->connect_errno) { throw new RuntimeException("Database did not become ready."); }'
"$RUNTIME" exec "$WORDPRESS" php -r '$config = file_get_contents("/var/www/html/wp-config-sample.php"); $config = str_replace(["database_name_here", "username_here", "password_here", "localhost"], [getenv("WORDPRESS_DB_NAME"), getenv("WORDPRESS_DB_USER"), getenv("WORDPRESS_DB_PASSWORD"), getenv("WORDPRESS_DB_HOST")], $config); file_put_contents("/var/www/html/wp-config.php", $config);'
"$RUNTIME" exec "$WORDPRESS" mkdir -p /var/www/html/wp-content/plugins/frontman-agentic-ai-editor
"$RUNTIME" cp "$ROOT_DIR/dist/frontman-wordpress-package/github/frontman-agentic-ai-editor/." "$WORDPRESS:/var/www/html/wp-content/plugins/frontman-agentic-ai-editor/"
"$RUNTIME" cp "$ROOT_DIR/libs/frontman-wordpress/tests/integration/WordPressRuntimeTest.php" "$WORDPRESS:/tmp/WordPressRuntimeTest.php"
"$RUNTIME" cp "$ROOT_DIR/libs/frontman-wordpress/tests/integration/ActivateWordPressPlugin.php" "$WORDPRESS:/tmp/ActivateWordPressPlugin.php"
"$RUNTIME" cp "$ROOT_DIR/libs/frontman-wordpress/tests/integration/RunWordPressRuntimeTest.php" "$WORDPRESS:/tmp/RunWordPressRuntimeTest.php"
"$RUNTIME" cp "$ROOT_DIR/libs/frontman-wordpress/tests/integration/WordPressMcpRuntimeTest.php" "$WORDPRESS:/tmp/WordPressMcpRuntimeTest.php"

"$RUNTIME" exec "$WORDPRESS" php -r 'define("WP_INSTALLING", true); require "/var/www/html/wp-load.php"; require_once ABSPATH . "wp-admin/includes/upgrade.php"; if (!is_blog_installed()) { wp_install("Frontman Runtime", "admin", "admin@example.test", true, "", "frontman-runtime-password"); } update_option("home", "http://localhost"); update_option("siteurl", "http://localhost");'
"$RUNTIME" exec "$WORDPRESS" php -d display_errors=1 -d error_reporting=E_ALL /tmp/ActivateWordPressPlugin.php
"$RUNTIME" exec "$WORDPRESS" php -d display_errors=1 -d error_reporting=E_ALL /tmp/RunWordPressRuntimeTest.php
MCP_AUTH="$($RUNTIME exec "$WORDPRESS" php -r 'require "/var/www/html/wp-load.php"; require "/tmp/WordPressMcpRuntimeTest.php";')"
MCP_NONCE="$(php -r '$data = json_decode($argv[1], true, 8, JSON_THROW_ON_ERROR); fwrite(STDOUT, $data["nonce"]);' "$MCP_AUTH")"
MCP_COOKIE_NAME="$(php -r '$data = json_decode($argv[1], true, 8, JSON_THROW_ON_ERROR); fwrite(STDOUT, $data["cookieName"]);' "$MCP_AUTH")"
MCP_COOKIE="$(php -r '$data = json_decode($argv[1], true, 8, JSON_THROW_ON_ERROR); fwrite(STDOUT, $data["cookie"]);' "$MCP_AUTH")"
MCP_VERSION='2026-07-28'
MCP_ORIGIN='http://localhost'

mcp_body() {
  php -r '$params = json_decode($argv[3], true, 64, JSON_THROW_ON_ERROR); $params = array_merge(["_meta" => ["io.modelcontextprotocol/protocolVersion" => $argv[4], "io.modelcontextprotocol/clientCapabilities" => (object) []]], $params); fwrite(STDOUT, json_encode(["jsonrpc" => "2.0", "id" => $argv[2], "method" => $argv[1], "params" => $params], JSON_THROW_ON_ERROR));' "$1" "$2" "$3" "$MCP_VERSION"
}

mcp_request() {
  local method="$1"
  local body="$2"
  shift 2
  MCP_RESPONSE="$($RUNTIME exec "$WORDPRESS" curl -sS -X POST "$MCP_ENDPOINT" -H "Origin: $MCP_ORIGIN" -H 'Content-Type: application/json' -H 'Accept: application/json, text/event-stream' -H "MCP-Protocol-Version: $MCP_VERSION" -H "Mcp-Method: $method" -H "X-WP-Nonce: $MCP_NONCE" -H "Cookie: $MCP_COOKIE_NAME=$MCP_COOKIE" "$@" --data-binary "$body" -w $'\n%{http_code}')"
  MCP_STATUS="${MCP_RESPONSE##*$'\n'}"
  MCP_RESPONSE="${MCP_RESPONSE%$'\n'*}"
}

require_status() {
  if [ "$MCP_STATUS" != "$1" ]; then
    printf '%s returned HTTP %s instead of %s: %s\n' "$2" "$MCP_STATUS" "$1" "$MCP_RESPONSE" >&2
    exit 1
  fi
}

for MCP_SITE_PATH in '' '/scope:frontman-runtime'; do
  MCP_BASE="$MCP_ORIGIN$MCP_SITE_PATH"
  MCP_ENDPOINT="$MCP_BASE/mcp"
  "$RUNTIME" exec "$WORDPRESS" php -r 'require "/var/www/html/wp-load.php"; update_option("home", $argv[1]);' "$MCP_BASE"

  MCP_BODY="$(mcp_body 'server/discover' 'runtime-discover' '{}')"
  mcp_request 'server/discover' "$MCP_BODY"
  require_status 200 'WordPress MCP discovery'
  php -r '$data = json_decode($argv[1], true, 64, JSON_THROW_ON_ERROR); if (($data["id"] ?? null) !== "runtime-discover" || ($data["result"]["resultType"] ?? null) !== "complete" || ($data["result"]["supportedVersions"] ?? null) !== ["2026-07-28"] || ($data["result"]["capabilities"] ?? null) !== ["tools" => ["listChanged" => false]] || ($data["result"]["ttlMs"] ?? null) !== 0 || ($data["result"]["cacheScope"] ?? null) !== "private") { throw new RuntimeException("WordPress MCP discovery response is invalid."); }' "$MCP_RESPONSE"

  for MCP_ALIAS in '/MCP' '/mcp/' '/frontman/mcp'; do
    MCP_ALIAS_STATUS="$($RUNTIME exec "$WORDPRESS" curl -sS -o /dev/null -w '%{http_code}' -X POST "$MCP_BASE$MCP_ALIAS" -H "Origin: $MCP_ORIGIN" -H "Cookie: $MCP_COOKIE_NAME=$MCP_COOKIE")"
    if [ "$MCP_ALIAS_STATUS" != "404" ]; then
      printf 'WordPress MCP alias %s returned HTTP %s instead of 404.\n' "$MCP_BASE$MCP_ALIAS" "$MCP_ALIAS_STATUS" >&2
      exit 1
    fi
  done

  MCP_STATUS="$($RUNTIME exec "$WORDPRESS" curl -sS -o /dev/null -w '%{http_code}' -X POST "$MCP_ENDPOINT" -H 'Content-Type: application/json' -H "X-WP-Nonce: $MCP_NONCE" -H "Cookie: $MCP_COOKIE_NAME=$MCP_COOKIE" --data-binary "$MCP_BODY")"
  MCP_RESPONSE=''
  require_status 403 'WordPress MCP missing Origin'

  MCP_STATUS="$($RUNTIME exec "$WORDPRESS" curl -sS -o /dev/null -w '%{http_code}' -X POST "$MCP_ENDPOINT" -H 'Origin: https://attacker.example' -H 'Content-Type: application/json' -H "X-WP-Nonce: $MCP_NONCE" -H "Cookie: $MCP_COOKIE_NAME=$MCP_COOKIE" --data-binary "$MCP_BODY")"
  require_status 403 'WordPress MCP foreign Origin'

  MCP_STATUS="$($RUNTIME exec "$WORDPRESS" curl -sS -o /dev/null -w '%{http_code}' -X POST "$MCP_ENDPOINT" -H "Origin: $MCP_ORIGIN" -H 'Content-Type: application/json' -H "X-WP-Nonce: $MCP_NONCE" --data-binary "$MCP_BODY")"
  require_status 401 'WordPress MCP missing authentication'

  MCP_STATUS="$($RUNTIME exec "$WORDPRESS" curl -sS -o /dev/null -w '%{http_code}' -X POST "$MCP_ENDPOINT" -H "Origin: $MCP_ORIGIN" -H 'Content-Type: application/json' -H 'X-WP-Nonce: invalid' -H "Cookie: $MCP_COOKIE_NAME=$MCP_COOKIE" --data-binary "$MCP_BODY")"
  require_status 403 'WordPress MCP invalid nonce'

  MCP_STATUS="$($RUNTIME exec "$WORDPRESS" curl -sS -o /dev/null -w '%{http_code}' -X OPTIONS "$MCP_ENDPOINT" -H "Origin: $MCP_ORIGIN" -H 'Access-Control-Request-Method: POST' -H 'Access-Control-Request-Headers: content-type, mcp-protocol-version, mcp-method, x-wp-nonce')"
  require_status 204 'WordPress MCP preflight'

  MCP_STATUS="$($RUNTIME exec "$WORDPRESS" curl -sS -o /dev/null -w '%{http_code}' -X DELETE "$MCP_ENDPOINT" -H "Origin: $MCP_ORIGIN" -H "X-WP-Nonce: $MCP_NONCE" -H "Cookie: $MCP_COOKIE_NAME=$MCP_COOKIE")"
  require_status 405 'WordPress MCP unsupported HTTP method'

  MCP_STATUS="$($RUNTIME exec "$WORDPRESS" curl -sS -o /dev/null -w '%{http_code}' -X POST "$MCP_ENDPOINT" -H "Origin: $MCP_ORIGIN" -H 'Content-Type: text/plain' -H "X-WP-Nonce: $MCP_NONCE" -H "Cookie: $MCP_COOKIE_NAME=$MCP_COOKIE" --data-binary "$MCP_BODY")"
  require_status 415 'WordPress MCP unsupported media'

  MCP_BODY="$(mcp_body 'tools/list' 'runtime-list' '{}')"
  mcp_request 'tools/list' "$MCP_BODY"
  require_status 200 'WordPress MCP tools/list'
  php -r '$data = json_decode($argv[1], true, 64, JSON_THROW_ON_ERROR); $tools = $data["result"]["tools"] ?? []; $names = array_column($tools, "name"); $sorted = $names; sort($sorted, SORT_STRING); if (($data["id"] ?? null) !== "runtime-list" || $names !== $sorted || !in_array("wp_get_site_info", $names, true) || in_array("list_files", $names, true) || array_key_exists("nextCursor", $data["result"]) || ($data["result"]["ttlMs"] ?? null) !== 0 || ($data["result"]["cacheScope"] ?? null) !== "private") { throw new RuntimeException("WordPress MCP catalog response is invalid."); }' "$MCP_RESPONSE"

  MCP_BODY="$(mcp_body 'tools/list' 'runtime-cursor' '{"cursor":""}')"
  mcp_request 'tools/list' "$MCP_BODY"
  require_status 200 'WordPress MCP cursor rejection'
  php -r '$data = json_decode($argv[1], true, 64, JSON_THROW_ON_ERROR); if (($data["error"]["code"] ?? null) !== -32602) { throw new RuntimeException("WordPress MCP cursor rejection is invalid."); }' "$MCP_RESPONSE"

  MCP_BODY="$(mcp_body 'tools/call' 'runtime-call' '{"name":"wp_get_site_info"}')"
  mcp_request 'tools/call' "$MCP_BODY" -H 'Mcp-Name: wp_get_site_info'
  require_status 200 'WordPress MCP tools/call'
  php -r '$data = json_decode($argv[1], true, 64, JSON_THROW_ON_ERROR); if (($data["id"] ?? null) !== "runtime-call" || ($data["result"]["resultType"] ?? null) !== "complete" || ($data["result"]["isError"] ?? false) === true) { throw new RuntimeException("WordPress MCP call response is invalid: " . $argv[1]); }' "$MCP_RESPONSE"

  MCP_BODY="$(mcp_body 'server/discover' 'runtime-mismatch' '{}')"
  mcp_request 'tools/list' "$MCP_BODY"
  require_status 400 'WordPress MCP mirrored-header mismatch'
  php -r '$data = json_decode($argv[1], true, 64, JSON_THROW_ON_ERROR); if (($data["error"]["code"] ?? null) !== -32020) { throw new RuntimeException("WordPress MCP mismatch response is invalid."); }' "$MCP_RESPONSE"

  MCP_BODY="$(mcp_body 'unknown/method' 'runtime-unknown' '{}')"
  mcp_request 'unknown/method' "$MCP_BODY"
  require_status 404 'WordPress MCP unknown method'
  php -r '$data = json_decode($argv[1], true, 64, JSON_THROW_ON_ERROR); if (($data["error"]["code"] ?? null) !== -32601) { throw new RuntimeException("WordPress MCP unknown-method response is invalid."); }' "$MCP_RESPONSE"

  mcp_request 'server/discover' '{'
  require_status 400 'WordPress MCP malformed JSON'
  php -r '$data = json_decode($argv[1], true, 64, JSON_THROW_ON_ERROR); if (($data["error"]["code"] ?? null) !== -32700) { throw new RuntimeException("WordPress MCP malformed-JSON response is invalid."); }' "$MCP_RESPONSE"

  LEGACY_LIST_STATUS="$($RUNTIME exec "$WORDPRESS" curl -sS -o /dev/null -w '%{http_code}' "$MCP_BASE/frontman/tools" -H "Cookie: $MCP_COOKIE_NAME=$MCP_COOKIE")"
  LEGACY_CALL_STATUS="$($RUNTIME exec "$WORDPRESS" curl -sS -o /dev/null -w '%{http_code}' -X POST "$MCP_BASE/frontman/tools/call" -H 'Content-Type: application/json' -H "X-WP-Nonce: $MCP_NONCE" -H "Cookie: $MCP_COOKIE_NAME=$MCP_COOKIE" --data-binary '{}')"
  if [ "$LEGACY_LIST_STATUS" = "200" ] || [ "$LEGACY_CALL_STATUS" = "200" ]; then
    printf 'Legacy WordPress Relay route remains active.\n' >&2
    exit 1
  fi
done
printf 'OK (WordPress MCP HTTP runtime)\n'
