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
"$RUNTIME" cp "$ROOT_DIR/libs/frontman-wordpress/tests/integration/CustomCssRuntimeTest.php" "$WORDPRESS:/tmp/CustomCssRuntimeTest.php"
"$RUNTIME" cp "$ROOT_DIR/libs/frontman-wordpress/tests/integration/ActivateWordPressPlugin.php" "$WORDPRESS:/tmp/ActivateWordPressPlugin.php"
"$RUNTIME" cp "$ROOT_DIR/libs/frontman-wordpress/tests/integration/RunWordPressRuntimeTest.php" "$WORDPRESS:/tmp/RunWordPressRuntimeTest.php"

"$RUNTIME" exec "$WORDPRESS" php -r 'define("WP_INSTALLING", true); define("WP_SITEURL", "http://frontman-runtime.example.test"); require "/var/www/html/wp-load.php"; require_once ABSPATH . "wp-admin/includes/upgrade.php"; if (!is_blog_installed()) { wp_install("Frontman Runtime", "admin", "admin@example.test", true, "", "frontman-runtime-password"); }'
"$RUNTIME" exec "$WORDPRESS" php -r '$db = new mysqli(getenv("WORDPRESS_DB_HOST"), getenv("WORDPRESS_DB_USER"), getenv("WORDPRESS_DB_PASSWORD"), getenv("WORDPRESS_DB_NAME")); $result = $db->query("SELECT option_value FROM wp_options WHERE option_name = '\''siteurl'\''"); $row = $result ? $result->fetch_row() : false; if (!$row || !$row[0]) { throw new RuntimeException("WordPress installation did not persist a site URL."); }'
"$RUNTIME" exec "$WORDPRESS" php -d display_errors=1 -d error_reporting=E_ALL /tmp/ActivateWordPressPlugin.php
TEST_OUTPUT="$("$RUNTIME" exec \
  -e EXPECTED_WORDPRESS_VERSION="$WORDPRESS_VERSION" \
  "$WORDPRESS" \
  php -d display_errors=1 -d error_reporting=E_ALL /tmp/RunWordPressRuntimeTest.php)"
printf '%s\n' "$TEST_OUTPUT"
if [[ "$TEST_OUTPUT" != *"OK (WordPress ${WORDPRESS_VERSION}, PHP "* ]]; then
  printf 'WordPress runtime tests did not report successful completion.\n' >&2
  exit 1
fi
