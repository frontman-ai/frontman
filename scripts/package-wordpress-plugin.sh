#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(git rev-parse --show-toplevel)"
PLUGIN_SRC="$ROOT_DIR/libs/frontman-wordpress"
DIST_DIR="$ROOT_DIR/dist"
BUILD_DIR="$DIST_DIR/frontman-wordpress-package"
PLUGIN_DIR="$BUILD_DIR/github/frontman"
WPORG_DIR="$BUILD_DIR/wordpress-org"

PLUGIN_VERSION="$(bash "$ROOT_DIR/scripts/validate-wordpress-plugin-release.sh")"

VERSION="${VERSION:-$PLUGIN_VERSION}"

if [ "$VERSION" != "$PLUGIN_VERSION" ]; then
  printf 'Requested VERSION %s does not match validated plugin version %s\n' "$VERSION" "$PLUGIN_VERSION" >&2
  exit 1
fi

ZIP_PATH="$DIST_DIR/frontman-wordpress-v${VERSION}.zip"
WPORG_TARBALL_PATH="$DIST_DIR/frontman-wordpress-org-v${VERSION}.tar.gz"
WPORG_EXPORT_PATH="$DIST_DIR/frontman-wordpress-org-v${VERSION}"

rm -rf "$BUILD_DIR" "$ZIP_PATH" "$WPORG_TARBALL_PATH" "$WPORG_EXPORT_PATH"
mkdir -p "$DIST_DIR"

rsync -a --delete --exclude '.DS_Store' --exclude '.wordpress-org/' --exclude 'tests/' "$PLUGIN_SRC/" "$PLUGIN_DIR/"
rsync -a --delete --exclude '.DS_Store' --exclude '.wordpress-org/' --exclude 'tests/' "$PLUGIN_SRC/" "$WPORG_DIR/trunk/"
rsync -a --delete "$WPORG_DIR/trunk/" "$WPORG_DIR/tags/$VERSION/"

if [ -d "$PLUGIN_SRC/.wordpress-org/assets" ]; then
  rsync -a --delete --exclude '.DS_Store' "$PLUGIN_SRC/.wordpress-org/assets/" "$WPORG_DIR/assets/"
fi

(
  cd "$BUILD_DIR/github"
  zip -rq "$ZIP_PATH" frontman
)

mkdir -p "$WPORG_EXPORT_PATH"
rsync -a --delete "$WPORG_DIR/" "$WPORG_EXPORT_PATH/"

(
  cd "$DIST_DIR"
  tar -czf "$WPORG_TARBALL_PATH" "frontman-wordpress-org-v${VERSION}"
)

printf 'Created %s\n' "$ZIP_PATH"
printf 'Created %s\n' "$WPORG_TARBALL_PATH"
printf 'Prepared %s\n' "$WPORG_EXPORT_PATH"
