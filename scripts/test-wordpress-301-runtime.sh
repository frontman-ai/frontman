#!/usr/bin/env bash
# Focused runtime contract without unrelated preview/Sentry build dependencies.
set -euo pipefail
ROOT="$(git rev-parse --show-toplevel)"
RUNTIME="${CONTAINER_RUNTIME:-docker}"
WP="${WORDPRESS_VERSION:-7.0.2}"
PHP="${PHP_VERSION:-8.4}"
ID="frontman-301-$$"
BUILD="$(mktemp -d)"
cleanup() {
  "$RUNTIME" rm -f "$ID-wp" "$ID-db" >/dev/null 2>&1 || true
  "$RUNTIME" network rm "$ID" >/dev/null 2>&1 || true
  "$RUNTIME" image rm "$ID-image" >/dev/null 2>&1 || true
  rm -rf "$BUILD"
}
trap cleanup EXIT
curl -fsSL "https://wordpress.org/wordpress-${WP}.tar.gz" -o "$BUILD/wordpress.tar.gz"
for SPEC in \
  '301-redirects.1.05:3423c49888af0d73e458fd9d5c1439ba7ca00d9da7ccb1b6c8ed0ac423011c8d' \
  'redirection.5.10.0:966ac6267cd6a99f2d79ec05db1dee2e0aa0cddb6060b1c32cde2ffde739e333'; do
  NAME="${SPEC%%:*}"
  curl -fsSL "https://downloads.wordpress.org/plugin/$NAME.zip" -o "$BUILD/$NAME.zip"
  printf '%s  %s\n' "${SPEC#*:}" "$BUILD/$NAME.zip" | sha256sum --check --status
  unzip -q "$BUILD/$NAME.zip" -d "$BUILD/plugins"
done
"$RUNTIME" build --build-arg PHP_VERSION="$PHP" -f "$ROOT/libs/frontman-wordpress/tests/integration/Dockerfile" -t "$ID-image" "$BUILD"
"$RUNTIME" network create "$ID" >/dev/null
"$RUNTIME" run -d --name "$ID-db" --network "$ID" -e MARIADB_DATABASE=wordpress -e MARIADB_USER=wordpress -e MARIADB_PASSWORD=wordpress -e MARIADB_ROOT_PASSWORD=wordpress docker.io/library/mariadb:11 >/dev/null
"$RUNTIME" run -d --name "$ID-wp" --network "$ID" "$ID-image" >/dev/null
for _ in $(seq 1 60); do
  if "$RUNTIME" exec "$ID-wp" php -r "\$db = @new mysqli('$ID-db', 'wordpress', 'wordpress', 'wordpress'); exit(\$db->connect_errno ? 1 : 0);" >/dev/null 2>&1; then break; fi
  sleep 2
done
"$RUNTIME" exec "$ID-wp" php -r "\$config = file_get_contents('/var/www/html/wp-config-sample.php'); \$config = str_replace(['database_name_here','username_here','password_here','localhost'], ['wordpress','wordpress','wordpress','$ID-db'], \$config); file_put_contents('/var/www/html/wp-config.php', \$config);"
"$RUNTIME" cp "$BUILD/plugins/." "$ID-wp:/var/www/html/wp-content/plugins/"
"$RUNTIME" cp "$ROOT/libs/frontman-wordpress" "$ID-wp:/var/www/html/wp-content/plugins/frontman-agentic-ai-editor"
"$RUNTIME" cp "$ROOT/libs/frontman-wordpress/tests/integration/Redirects301RuntimeTest.php" "$ID-wp:/tmp/Redirects301RuntimeTest.php"
"$RUNTIME" exec "$ID-wp" php -r 'define("WP_INSTALLING", true); define("WP_SITEURL", "http://frontman-runtime.example.test"); require "/var/www/html/wp-load.php"; require_once ABSPATH . "wp-admin/includes/upgrade.php"; wp_install("Runtime", "admin", "admin@example.test", true, "", "runtime-test-password"); update_option("active_plugins", ["frontman-agentic-ai-editor/frontman.php"]);'
"$RUNTIME" exec "$ID-wp" php /tmp/Redirects301RuntimeTest.php --setup
"$RUNTIME" exec "$ID-wp" php /tmp/Redirects301RuntimeTest.php
case "$WP" in
  6.[0-6].*) exit 0 ;;
esac
"$RUNTIME" exec "$ID-wp" php -r 'require "/var/www/html/wp-load.php"; require_once ABSPATH . "wp-admin/includes/plugin.php"; $result = activate_plugin("redirection/redirection.php"); if (is_wp_error($result)) { throw new RuntimeException($result->get_error_message()); }'
"$RUNTIME" exec "$ID-wp" php /tmp/Redirects301RuntimeTest.php --coexist
