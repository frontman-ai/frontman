#!/usr/bin/env bash
set -euo pipefail

version="${WORDPRESS_VERSION:-7.0.2}"
case "$version" in
  6.0.9) sha256=36988f15f37c9b42e2a1d529d6f0e6b8424185b9b26a70df70ba81b7cc945986 ;;
  6.9.9) sha256=32231b9acbe763a86138e8bbb7b5c4f3f123bec9d65fc3898bcb3b64506a7358 ;;
  7.0.2) sha256=d4a4d219dea64c6c68e62f2ffc3f331c5475510246d6c44f61fb52f377d295b9 ;;
  *) printf 'Unsupported isolated WordPress version: %s\n' "$version" >&2; exit 1 ;;
esac
build="$(mktemp -d)"
trap 'rm -rf "$build"' EXIT
curl -fsSL "https://wordpress.org/wordpress-${version}.tar.gz" -o "$build/wordpress.tar.gz"
printf '%s  %s\n' "$sha256" "$build/wordpress.tar.gz" | sha256sum --check --status
tar -xzf "$build/wordpress.tar.gz" -C "$build"
export FRONTMAN_WORDPRESS_SOURCE="$build/wordpress"
"$@"
