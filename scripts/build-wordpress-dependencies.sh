#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(git rev-parse --show-toplevel)"
RUNTIME="${CONTAINER_RUNTIME:-docker}"
TOOLS="$ROOT_DIR/dist/wordpress-build-tools"
SOURCE="$ROOT_DIR/dist/wordpress-dependencies-source"
SCOPED="$ROOT_DIR/dist/wordpress-dependencies-scoped"
PLUGIN="$ROOT_DIR/libs/frontman-wordpress"
SCOPER_SHA256="4775eb87675b2fb4eb0a31b56fe3d44f276ff3bfaadf69d497fef6d4ea738c48"

USER_ARGS=()
if [[ "$(basename "$RUNTIME")" != "podman" ]]; then
  USER_ARGS=(--user "$(id -u):$(id -g)")
fi
if [[ "${1:-}" == "--update-lock" ]]; then
  "$RUNTIME" run --rm "${USER_ARGS[@]}" -e COMPOSER_HOME=/tmp/composer \
    -v "$ROOT_DIR:/workspace" -w /workspace/libs/frontman-wordpress \
    docker.io/library/composer:2.8.12 update --no-install --no-interaction --no-scripts --no-plugins
  exit
fi

mkdir -p "$TOOLS" "$SOURCE"
if [[ ! -f "$TOOLS/php-scoper.phar" ]]; then
  curl -fL --retry 3 https://github.com/humbug/php-scoper/releases/download/0.18.17/php-scoper.phar -o "$TOOLS/php-scoper.phar"
fi
printf '%s  %s\n' "$SCOPER_SHA256" "$TOOLS/php-scoper.phar" | sha256sum --check --status
cp "$PLUGIN/composer.json" "$PLUGIN/composer.lock" "$SOURCE/"
rm -rf "$SCOPED"

"$RUNTIME" run --rm "${USER_ARGS[@]}" \
  -e COMPOSER_HOME=/tmp/composer \
  -v "$ROOT_DIR:/workspace" -w /workspace/dist/wordpress-dependencies-source \
  docker.io/library/composer:2.8.12 sh -ec '
    composer install --no-dev --no-interaction --prefer-dist --no-scripts --no-plugins
    php /workspace/dist/wordpress-build-tools/php-scoper.phar add-prefix \
      --config=/workspace/scripts/wordpress-scoper.inc.php \
      --output-dir=/workspace/dist/wordpress-dependencies-scoped --force \
      composer.json vendor
    cd /workspace/dist/wordpress-dependencies-scoped
    composer config autoloader-suffix FrontmanWordPress
    composer dump-autoload --no-dev --classmap-authoritative --no-scripts --no-plugins
    php /workspace/scripts/wordpress-scope-autoload.php
    rm vendor/scoper-autoload.php
  '
mkdir -p "$PLUGIN/vendor"
rsync -a --delete "$SCOPED/vendor/" "$PLUGIN/vendor/"
