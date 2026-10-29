#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(git rev-parse --show-toplevel)"
RUNTIME="${CONTAINER_RUNTIME:-docker}"
WORDPRESS_VERSION="${WORDPRESS_VERSION:-7.0.2}"
PHP_VERSION="${PHP_VERSION:-8.4}"
YOAST_VERSION="${YOAST_VERSION:-}"
FIXTURE="${WORDPRESS_FIXTURE:-}"
FIXTURE_PORT="${WORDPRESS_FIXTURE_PORT:-8887}"
case "$FIXTURE" in
  ""|astra) ;;
  *) printf 'Unknown WORDPRESS_FIXTURE: %s\n' "$FIXTURE" >&2; exit 1 ;;
esac
if [[ "$FIXTURE" == astra && "$WORDPRESS_VERSION" != 7.0.2 ]]; then
  printf 'The Astra fixture requires WordPress 7.0.2.\n' >&2; exit 1
fi
PUBLISH=()
DB_PASSWORD=wordpress
if [[ "$FIXTURE" == astra ]]; then
  [[ "$FIXTURE_PORT" =~ ^[0-9]+$ ]] && (( FIXTURE_PORT > 1024 && FIXTURE_PORT < 65536 ))
  PUBLISH=(-p "127.0.0.1:${FIXTURE_PORT}:80")
  DB_PASSWORD="$(od -An -N32 -tx1 /dev/urandom | tr -d ' \n')"
fi
MEGAMENU_VERSION="3.10.7"
MEGAMENU_SHA256="6cfe5fc2484bccbcc6782364b38e16fde55a496bfaf86d123d1d46b0684c5e7e"
case "$WORDPRESS_VERSION" in
  6.0.*|6.1.*)
    MEGAMENU_VERSION="3.6.2"
    MEGAMENU_SHA256="df0a37af42b6937fc716bbd302d983a9e78abc9a63caf1e731ac09597856ea55"
    ;;
esac
case "$YOAST_VERSION" in
  "") ;;
  28.6) YOAST_SHA256="ebb6e2a89d697cabecf2348a06d1efe807fd13ee1faeddcd06e354b98ee2a4d5" ;;
  28.4) YOAST_SHA256="93eba5afc65149967a4bb4906bc8fdebf92f4a65ee02bec97f5c01a7e14e7028" ;;
  19.9) YOAST_SHA256="8494a158e4bb9fcea9bb2198cc4c5908e92f3a5a2ccfffd989db05cf4e016af9" ;;
  *) printf 'Unsupported Yoast runtime test version: %s\n' "$YOAST_VERSION" >&2; exit 1 ;;
esac
PLUGIN_VERSION="$(bash "$ROOT_DIR/scripts/validate-wordpress-plugin-release.sh")"
RUN_ID="frontman-wp-runtime-$$"
NETWORK="${RUN_ID}-network"
DATABASE="${RUN_ID}-database"
WORDPRESS="${RUN_ID}-wordpress"
IMAGE="${RUN_ID}-image"
BUILD_DIR="$(mktemp -d)"
NETWORK_CREATED=false

cleanup() {
  "$RUNTIME" rm -f "$WORDPRESS" >/dev/null 2>&1 || true
  "$RUNTIME" rm -f "$DATABASE" >/dev/null 2>&1 || true
  if "$NETWORK_CREATED"; then "$RUNTIME" network rm "$NETWORK" >/dev/null 2>&1 || true; fi
  "$RUNTIME" image rm "$IMAGE" >/dev/null 2>&1 || true
  rm -rf "$BUILD_DIR"
}
trap cleanup EXIT

make -C "$ROOT_DIR" package-wordpress-plugin VERSION="$PLUGIN_VERSION" >/dev/null
curl -fsSL "https://wordpress.org/wordpress-${WORDPRESS_VERSION}.tar.gz" -o "$BUILD_DIR/wordpress.tar.gz"
curl -fsSL "https://downloads.wordpress.org/plugin/megamenu.${MEGAMENU_VERSION}.zip" -o "$BUILD_DIR/megamenu.zip"
printf '%s  %s\n' "$MEGAMENU_SHA256" "$BUILD_DIR/megamenu.zip" | sha256sum --check --status
unzip -q "$BUILD_DIR/megamenu.zip" -d "$BUILD_DIR/megamenu"
if [[ -n "$YOAST_VERSION" ]]; then
  curl -fsSL "https://downloads.wordpress.org/plugin/wordpress-seo.${YOAST_VERSION}.zip" -o "$BUILD_DIR/wordpress-seo.zip"
  printf '%s  %s\n' "$YOAST_SHA256" "$BUILD_DIR/wordpress-seo.zip" | sha256sum --check --status
  unzip -q "$BUILD_DIR/wordpress-seo.zip" -d "$BUILD_DIR/yoast"
  printf 'Verified official Yoast SEO %s package (SHA-256 %s)\n' "$YOAST_VERSION" "$YOAST_SHA256"
fi
"$RUNTIME" build \
  --build-arg PHP_VERSION="$PHP_VERSION" \
  -f "$ROOT_DIR/libs/frontman-wordpress/tests/integration/Dockerfile" \
  -t "$IMAGE" \
  "$BUILD_DIR" >/dev/null

if "$RUNTIME" --version | grep -qi podman; then
  DB_NETWORK=pasta
  WP_NETWORK="container:$DATABASE"
  DB_HOST=127.0.0.1
  DB_PUBLISH=("${PUBLISH[@]}")
  WP_PUBLISH=()
else
  "$RUNTIME" network create "$NETWORK" >/dev/null
  NETWORK_CREATED=true
  DB_NETWORK="$NETWORK"
  WP_NETWORK="$NETWORK"
  DB_HOST="$DATABASE"
  DB_PUBLISH=()
  WP_PUBLISH=("${PUBLISH[@]}")
fi
"$RUNTIME" run -d --name "$DATABASE" --network "$DB_NETWORK" \
  "${DB_PUBLISH[@]}" \
  -e MARIADB_DATABASE=wordpress \
  -e MARIADB_USER=wordpress \
  -e MARIADB_PASSWORD="$DB_PASSWORD" \
  -e MARIADB_ROOT_PASSWORD="$DB_PASSWORD" \
  docker.io/library/mariadb:11 >/dev/null

"$RUNTIME" run -d --name "$WORDPRESS" --network "$WP_NETWORK" \
  "${WP_PUBLISH[@]}" \
  -e WORDPRESS_DB_HOST="$DB_HOST" \
  -e WORDPRESS_DB_USER=wordpress \
  -e WORDPRESS_DB_PASSWORD="$DB_PASSWORD" \
  -e WORDPRESS_DB_NAME=wordpress \
  "$IMAGE" >/dev/null

for _ in $(seq 1 60); do
  if "$RUNTIME" exec "$WORDPRESS" php -r '$db = @new mysqli(getenv("WORDPRESS_DB_HOST"), getenv("WORDPRESS_DB_USER"), getenv("WORDPRESS_DB_PASSWORD"), getenv("WORDPRESS_DB_NAME")); exit($db->connect_errno ? 1 : 0);' >/dev/null 2>&1; then
    break
  fi
  sleep 2
done

"$RUNTIME" exec "$WORDPRESS" php -r '$db = @new mysqli(getenv("WORDPRESS_DB_HOST"), getenv("WORDPRESS_DB_USER"), getenv("WORDPRESS_DB_PASSWORD"), getenv("WORDPRESS_DB_NAME")); if ($db->connect_errno) { throw new RuntimeException("Database did not become ready."); }'
"$RUNTIME" exec "$WORDPRESS" php -r '$config = file_get_contents("/var/www/html/wp-config-sample.php"); $config = str_replace(["<?php", "database_name_here", "username_here", "password_here", "localhost"], ["<?php\ndefine(\"WP_ENVIRONMENT_TYPE\", \"local\");", getenv("WORDPRESS_DB_NAME"), getenv("WORDPRESS_DB_USER"), getenv("WORDPRESS_DB_PASSWORD"), getenv("WORDPRESS_DB_HOST")], $config); file_put_contents("/var/www/html/wp-config.php", $config);'
"$RUNTIME" cp "$BUILD_DIR/megamenu/megamenu" "$WORDPRESS:/var/www/html/wp-content/plugins/megamenu"
"$RUNTIME" exec "$WORDPRESS" mkdir -p /var/www/html/wp-content/plugins/frontman-agentic-ai-editor
"$RUNTIME" cp "$ROOT_DIR/dist/frontman-wordpress-package/github/frontman-agentic-ai-editor/." "$WORDPRESS:/var/www/html/wp-content/plugins/frontman-agentic-ai-editor/"
"$RUNTIME" exec "$WORDPRESS" mkdir -p /var/www/html/wp-content/mu-plugins
"$RUNTIME" cp "$ROOT_DIR/libs/frontman-wordpress/tests/integration/SentryRuntimeFixture.php" "$WORDPRESS:/var/www/html/wp-content/mu-plugins/frontman-sentry-test.php"
"$RUNTIME" cp "$ROOT_DIR/libs/frontman-wordpress/tests/integration/SentryRuntimeTest.php" "$WORDPRESS:/tmp/SentryRuntimeTest.php"
"$RUNTIME" cp "$ROOT_DIR/libs/frontman-wordpress/tests/integration/WordPressRuntimeTest.php" "$WORDPRESS:/tmp/WordPressRuntimeTest.php"
"$RUNTIME" cp "$ROOT_DIR/libs/frontman-wordpress/tests/integration/fixtures" "$WORDPRESS:/tmp/frontman-media-fixtures"
"$RUNTIME" cp "$ROOT_DIR/libs/frontman-wordpress/tests/integration/CustomCssRuntimeTest.php" "$WORDPRESS:/tmp/CustomCssRuntimeTest.php"
"$RUNTIME" cp "$ROOT_DIR/libs/frontman-wordpress/tests/integration/ElementorSnapshotRuntimeTest.php" "$WORDPRESS:/tmp/ElementorSnapshotRuntimeTest.php"
"$RUNTIME" cp "$ROOT_DIR/libs/frontman-wordpress/tests/integration/ActivateWordPressPlugin.php" "$WORDPRESS:/tmp/ActivateWordPressPlugin.php"
"$RUNTIME" cp "$ROOT_DIR/libs/frontman-wordpress/tests/integration/RunWordPressRuntimeTest.php" "$WORDPRESS:/tmp/RunWordPressRuntimeTest.php"
for file in RuntimeTestSupport CoreRuntimeCases IsolatedRuntimeCases InstallationPathsRuntimeTest SeoCoexistenceRuntimeTest SureRankRuntimeTest DirectoristRuntimeTest; do
  "$RUNTIME" cp "$ROOT_DIR/libs/frontman-wordpress/tests/integration/$file.php" "$WORDPRESS:/tmp/$file.php"
done
"$RUNTIME" exec "$WORDPRESS" mkdir -p /var/www/html/wp-content/mu-plugins
"$RUNTIME" cp "$ROOT_DIR/libs/frontman-wordpress/tests/integration/PostAuthorsRuntimeFixture.php" "$WORDPRESS:/var/www/html/wp-content/mu-plugins/frontman-authors-runtime.php"
"$RUNTIME" cp "$ROOT_DIR/libs/frontman-wordpress/tests/integration/PostAuthorsRuntimeTest.php" "$WORDPRESS:/tmp/PostAuthorsRuntimeTest.php"
"$RUNTIME" cp "$ROOT_DIR/libs/frontman-wordpress/tests/integration/LandingPageRuntimeFixture.php" "$WORDPRESS:/var/www/html/wp-content/mu-plugins/frontman-landing-page-runtime.php"
"$RUNTIME" cp "$ROOT_DIR/libs/frontman-wordpress/tests/integration/PostContentRuntimeTest.php" "$WORDPRESS:/tmp/PostContentRuntimeTest.php"
"$RUNTIME" cp "$ROOT_DIR/libs/frontman-wordpress/tests/integration/TemplateCreationRuntimeTest.php" "$WORDPRESS:/tmp/TemplateCreationRuntimeTest.php"
"$RUNTIME" cp "$ROOT_DIR/libs/frontman-wordpress/tests/integration/PageTemplateRuntimeTest.php" "$WORDPRESS:/tmp/PageTemplateRuntimeTest.php"
if [[ -n "$YOAST_VERSION" ]]; then
  "$RUNTIME" exec "$WORDPRESS" mkdir -p /var/www/html/wp-content/mu-plugins /var/www/html/wp-content/plugins/wordpress-seo
  "$RUNTIME" cp "$BUILD_DIR/yoast/wordpress-seo/." "$WORDPRESS:/var/www/html/wp-content/plugins/wordpress-seo/"
  "$RUNTIME" cp "$ROOT_DIR/libs/frontman-wordpress/tests/integration/SeoRuntimeFixture.php" "$WORDPRESS:/var/www/html/wp-content/mu-plugins/frontman-seo-runtime.php"
fi

curl -fsSL 'https://downloads.wordpress.org/plugin/directorist.8.10.6.zip' -o "$BUILD_DIR/directorist.zip"
printf '%s  %s\n' 'd2615cb9e29b1003cffd7713b515bb4984b6ba25e32aef76a0e04fff7a2ce28a' "$BUILD_DIR/directorist.zip" | sha256sum --check --status
unzip -q "$BUILD_DIR/directorist.zip" -d "$BUILD_DIR/directorist"
"$RUNTIME" cp "$BUILD_DIR/directorist/directorist" "$WORDPRESS:/var/www/html/wp-content/plugins/directorist"

case "$WORDPRESS_VERSION" in
6.[0-8].*) ;;
*)
  curl -fsSL 'https://downloads.wordpress.org/plugin/surerank.1.10.2.zip' -o "$BUILD_DIR/surerank.zip"
  printf '%s  %s\n' '2ed0ada73535e8c22498e4354b13ca5aa15e45e06fe2bc4e0f78afea0b840287' "$BUILD_DIR/surerank.zip" | sha256sum --check --status
  unzip -q "$BUILD_DIR/surerank.zip" -d "$BUILD_DIR/surerank"
  "$RUNTIME" cp "$BUILD_DIR/surerank/surerank" "$WORDPRESS:/var/www/html/wp-content/plugins/surerank"
  ;;
esac

"$RUNTIME" exec "$WORDPRESS" php -r 'define("WP_INSTALLING", true); define("WP_SITEURL", "http://frontman-runtime.example.test"); require "/var/www/html/wp-load.php"; require_once ABSPATH . "wp-admin/includes/upgrade.php"; if (!is_blog_installed()) { wp_install("Frontman Runtime", "admin", "admin@example.test", true, "", bin2hex(random_bytes(32))); }'
"$RUNTIME" exec "$WORDPRESS" php -r '$db = new mysqli(getenv("WORDPRESS_DB_HOST"), getenv("WORDPRESS_DB_USER"), getenv("WORDPRESS_DB_PASSWORD"), getenv("WORDPRESS_DB_NAME")); $result = $db->query("SELECT option_value FROM wp_options WHERE option_name = '\''siteurl'\''"); $row = $result ? $result->fetch_row() : false; if (!$row || !$row[0]) { throw new RuntimeException("WordPress installation did not persist a site URL."); }'
"$RUNTIME" exec -e EXPECTED_YOAST_VERSION="$YOAST_VERSION" "$WORDPRESS" php -d display_errors=1 -d error_reporting=E_ALL /tmp/ActivateWordPressPlugin.php
if TEST_OUTPUT="$("$RUNTIME" exec \
  -e EXPECTED_WORDPRESS_VERSION="$WORDPRESS_VERSION" \
  -e EXPECTED_YOAST_VERSION="$YOAST_VERSION" \
  "$WORDPRESS" \
  php -d display_errors=1 -d error_reporting=E_ALL /tmp/RunWordPressRuntimeTest.php)"; then
  TEST_STATUS=0
else TEST_STATUS=$?
fi
printf '%s\n' "$TEST_OUTPUT"
if [[ "$TEST_STATUS" -ne 0 || "$TEST_OUTPUT" != *"OK (WordPress ${WORDPRESS_VERSION}, PHP "* ]]; then
  printf 'WordPress runtime tests did not report successful completion.\n' >&2
  exit 1
fi

"$RUNTIME" cp "$ROOT_DIR/libs/frontman-wordpress/tests/integration/ThemeModsAndSearchRuntimeTest.php" "$WORDPRESS:/tmp/ThemeModsAndSearchRuntimeTest.php"
"$RUNTIME" exec "$WORDPRESS" php -d display_errors=1 -d error_reporting=E_ALL /tmp/ThemeModsAndSearchRuntimeTest.php

"$RUNTIME" cp "$ROOT_DIR/libs/frontman-wordpress/tests/integration/WidgetWithoutWooRuntimeTest.php" "$WORDPRESS:/tmp/WidgetWithoutWooRuntimeTest.php"
"$RUNTIME" exec "$WORDPRESS" php -d display_errors=1 -d error_reporting=E_ALL /tmp/WidgetWithoutWooRuntimeTest.php
WOOCOMMERCE_VERSION=""
case "$WORDPRESS_VERSION" in
6.[0-6].*) printf 'Skipping WooCommerce: requires WordPress 6.7+.\n' ;;
6.7.*)
  WOOCOMMERCE_VERSION="9.9.5"
  WOOCOMMERCE_SHA256="9afd8ef47ce5286412053083cd74c3d5abf0388e8e4a723902162259977241c2"
  ;;
*)
  WOOCOMMERCE_VERSION="10.4.3"
  WOOCOMMERCE_SHA256="3b1bbe109a0ab653863a6c8b4ccbdf75c519fd5ebf51151c54b8ca37b325f242"
  ;;
esac
if [[ -n "${WOOCOMMERCE_VERSION:-}" ]]; then
curl -fsSL "https://downloads.wordpress.org/plugin/woocommerce.${WOOCOMMERCE_VERSION}.zip" -o "$BUILD_DIR/woocommerce.zip"
printf '%s  %s\n' "$WOOCOMMERCE_SHA256" "$BUILD_DIR/woocommerce.zip" | sha256sum --check --status
unzip -q "$BUILD_DIR/woocommerce.zip" -d "$BUILD_DIR/woocommerce"
"$RUNTIME" cp "$BUILD_DIR/woocommerce/woocommerce" "$WORDPRESS:/var/www/html/wp-content/plugins/woocommerce"
"$RUNTIME" exec "$WORDPRESS" php -r 'require "/var/www/html/wp-load.php"; require_once ABSPATH . "wp-admin/includes/plugin.php"; $result = activate_plugin("woocommerce/woocommerce.php"); if (is_wp_error($result)) { throw new RuntimeException($result->get_error_message()); }'
printf 'Testing WooCommerce %s on WordPress %s\n' "$WOOCOMMERCE_VERSION" "$WORDPRESS_VERSION"
"$RUNTIME" cp "$ROOT_DIR/libs/frontman-wordpress/tests/integration/WidgetVisibilityRuntimeTest.php" "$WORDPRESS:/tmp/WidgetVisibilityRuntimeTest.php"
"$RUNTIME" exec "$WORDPRESS" php -d display_errors=1 -d error_reporting=E_ALL /tmp/WidgetVisibilityRuntimeTest.php
if [[ "$WOOCOMMERCE_VERSION" == "10.4.3" ]]; then
"$RUNTIME" cp "$ROOT_DIR/libs/frontman-wordpress/tests/integration/WooCommerceCatalogRuntimeTest.php" "$WORDPRESS:/tmp/WooCommerceCatalogRuntimeTest.php"
"$RUNTIME" exec "$WORDPRESS" php -d display_errors=1 -d error_reporting=E_ALL /tmp/WooCommerceCatalogRuntimeTest.php
else
printf 'Skipping catalog runtime tests: WooCommerce 10.4.3 requires WordPress 6.8+.\n'
fi
if [[ "$FIXTURE" == astra ]]; then
  curl -fsSL 'https://downloads.wordpress.org/theme/astra.4.12.3.zip' -o "$BUILD_DIR/astra.zip"
  printf '%s  %s\n' '18b0b13f23b7ea793235b3ef8e9c62a032cff81646fca562aed2db2a83945a12' "$BUILD_DIR/astra.zip" | sha256sum --check --status
  unzip -q "$BUILD_DIR/astra.zip" -d "$BUILD_DIR/astra"
  "$RUNTIME" cp "$BUILD_DIR/astra/astra" "$WORDPRESS:/var/www/html/wp-content/themes/astra"
  "$RUNTIME" cp "$ROOT_DIR/libs/frontman-wordpress/tests/integration/AstraFixture.php" "$WORDPRESS:/tmp/AstraFixture.php"
  "$RUNTIME" exec -e FIXTURE_URL="http://127.0.0.1:$FIXTURE_PORT" "$WORDPRESS" php /tmp/AstraFixture.php setup
  "$RUNTIME" cp "$ROOT_DIR/libs/frontman-wordpress/tests/integration/AstraRouting.htaccess" "$WORDPRESS:/var/www/html/.htaccess"
  "$RUNTIME" cp "$ROOT_DIR/libs/frontman-wordpress/tests/integration/AstraSafety.php" "$WORDPRESS:/var/www/html/wp-content/mu-plugins/astra-safety.php"
  FRONTMAN_ASTRA_URL="http://127.0.0.1:$FIXTURE_PORT" FRONTMAN_ASTRA_CONTAINER="$WORDPRESS" CONTAINER_RUNTIME="$RUNTIME" \
    FRONTMAN_ASTRA_EVIDENCE_DIR="$ROOT_DIR/dist/astra-fixture" \
    make -C "$ROOT_DIR/libs/client" test TEST_FILTER=test/Client__Astra.test.res.mjs
  printf 'Synthetic Astra fixture verified: http://127.0.0.1:%s (no customer configuration tested).\n' "$FIXTURE_PORT"
  printf 'Fixture container: %s; browser evidence: dist/astra-fixture/\n' "$WORDPRESS"
  if [[ "${WORDPRESS_FIXTURE_KEEP_ALIVE:-0}" == 1 ]]; then
    printf 'Fixture is disposable. Stop with Ctrl+C; only this run’s containers/image/temp directory are removed.\n'
    trap 'exit 0' INT TERM
    while :; do sleep 1; done
  fi
  exit 0
fi
"$RUNTIME" exec "$WORDPRESS" php -r 'require "/var/www/html/wp-load.php"; require_once ABSPATH . "wp-admin/includes/plugin.php"; deactivate_plugins("woocommerce/woocommerce.php");'
fi

"$RUNTIME" exec "$WORDPRESS" cp -a /var/www/html /tmp/frontman-multisite
"$RUNTIME" exec "$WORDPRESS" php -r '$path = "/tmp/frontman-multisite/wp-config.php"; $config = file_get_contents($path); $config = str_replace("\x27wp_\x27", "\x27fm_multi_\x27", $config); file_put_contents($path, $config);'
"$RUNTIME" cp "$ROOT_DIR/libs/frontman-wordpress/tests/integration/SetupAuthorsMultisite.php" "$WORDPRESS:/tmp/SetupAuthorsMultisite.php"
"$RUNTIME" cp "$ROOT_DIR/libs/frontman-wordpress/tests/integration/MultisiteAuthorsRuntimeTest.php" "$WORDPRESS:/tmp/MultisiteAuthorsRuntimeTest.php"
"$RUNTIME" exec "$WORDPRESS" php -d display_errors=1 -d error_reporting=E_ALL /tmp/SetupAuthorsMultisite.php
if MULTISITE_OUTPUT="$("$RUNTIME" exec "$WORDPRESS" php -d display_errors=1 -d error_reporting=E_ALL /tmp/MultisiteAuthorsRuntimeTest.php)"; then
  MULTISITE_STATUS=0
else MULTISITE_STATUS=$?
fi
printf '%s\n' "$MULTISITE_OUTPUT"
if [[ "$MULTISITE_STATUS" -ne 0 || "$MULTISITE_OUTPUT" != *"OK (Multisite authors, WordPress ${WORDPRESS_VERSION}, PHP "* ]]; then
  printf 'Multisite author tests did not report successful completion.\n' >&2
  exit 1
fi

curl -fsSL 'https://downloads.wordpress.org/plugin/301-redirects.1.05.zip' -o "$BUILD_DIR/301-redirects.zip"
printf '%s  %s\n' '3423c49888af0d73e458fd9d5c1439ba7ca00d9da7ccb1b6c8ed0ac423011c8d' "$BUILD_DIR/301-redirects.zip" | sha256sum --check --status
unzip -q "$BUILD_DIR/301-redirects.zip" -d "$BUILD_DIR/301-redirects"
"$RUNTIME" cp "$BUILD_DIR/301-redirects/301-redirects" "$WORDPRESS:/var/www/html/wp-content/plugins/301-redirects"
"$RUNTIME" cp "$ROOT_DIR/libs/frontman-wordpress/tests/integration/Redirects301RuntimeTest.php" "$WORDPRESS:/tmp/Redirects301RuntimeTest.php"
"$RUNTIME" exec "$WORDPRESS" php /tmp/Redirects301RuntimeTest.php --setup
"$RUNTIME" exec "$WORDPRESS" php /tmp/Redirects301RuntimeTest.php

case "$WORDPRESS_VERSION" in
  6.[0-6].*) printf 'Skipping Redirection 5.10.0: requires WordPress 6.7+.\n'; exit 0 ;;
esac
curl -fsSL 'https://downloads.wordpress.org/plugin/redirection.5.10.0.zip' -o "$BUILD_DIR/redirection.zip"
printf '%s  %s\n' '966ac6267cd6a99f2d79ec05db1dee2e0aa0cddb6060b1c32cde2ffde739e333' "$BUILD_DIR/redirection.zip" | sha256sum --check --status
unzip -q "$BUILD_DIR/redirection.zip" -d "$BUILD_DIR/redirection"
"$RUNTIME" cp "$BUILD_DIR/redirection/redirection" "$WORDPRESS:/var/www/html/wp-content/plugins/redirection"
"$RUNTIME" cp "$ROOT_DIR/libs/frontman-wordpress/tests/integration/RedirectionRuntimeTest.php" "$WORDPRESS:/tmp/RedirectionRuntimeTest.php"
"$RUNTIME" exec "$WORDPRESS" php -d display_errors=1 -d error_reporting=E_ALL /tmp/RedirectionRuntimeTest.php --setup
if REDIRECTION_OUTPUT="$("$RUNTIME" exec "$WORDPRESS" php -d display_errors=1 -d error_reporting=E_ALL /tmp/RedirectionRuntimeTest.php)"; then
  REDIRECTION_STATUS=0
else REDIRECTION_STATUS=$?
fi
printf '%s\n' "$REDIRECTION_OUTPUT"
if [[ "$REDIRECTION_STATUS" -ne 0 || "$REDIRECTION_OUTPUT" != *"OK (Redirection 5.10.0, WordPress ${WORDPRESS_VERSION}, PHP "* ]]; then
  printf 'Redirection runtime tests did not report successful completion.\n' >&2
  exit 1
fi

case "$WORDPRESS_VERSION" in
  6.[0-8].*) printf 'Skipping Angie 1.1.16: requires WordPress 6.9+.\n'; exit 0 ;;
esac
"$RUNTIME" cp "$ROOT_DIR/libs/frontman-wordpress/tests/integration/AngieRuntimeTest.php" "$WORDPRESS:/tmp/AngieRuntimeTest.php"
for ANGIE_VERSION in 1.1.0 1.1.16; do
  case "$ANGIE_VERSION" in
    1.1.0) ANGIE_SHA256=b2770a38efb3d79a638e12196aac75025218cde450a04e191bbc339ffa18bc85 ;;
    1.1.16) ANGIE_SHA256=d91f13533c9190e2db6b18f53c6b74c4ba3badb62623d656cac2fac33bb12a95 ;;
  esac
  curl -fsSL "https://downloads.wordpress.org/plugin/angie.${ANGIE_VERSION}.zip" -o "$BUILD_DIR/angie.zip"
  printf '%s  %s\n' "$ANGIE_SHA256" "$BUILD_DIR/angie.zip" | sha256sum --check --status
  unzip -q "$BUILD_DIR/angie.zip" -d "$BUILD_DIR/angie-${ANGIE_VERSION}"
  "$RUNTIME" exec "$WORDPRESS" rm -rf /var/www/html/wp-content/plugins/angie
  "$RUNTIME" cp "$BUILD_DIR/angie-${ANGIE_VERSION}/angie" "$WORDPRESS:/var/www/html/wp-content/plugins/angie"
  	"$RUNTIME" exec "$WORDPRESS" php -d display_errors=1 -d error_reporting=E_ALL /tmp/AngieRuntimeTest.php --setup
	"$RUNTIME" exec -e EXPECTED_ANGIE_VERSION="$ANGIE_VERSION" "$WORDPRESS" php -d display_errors=1 -d error_reporting=E_ALL /tmp/AngieRuntimeTest.php
done
