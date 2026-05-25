#!/usr/bin/env bash

set -euo pipefail
set +x

validate_version() {
  local version="$1"

  if [[ ! "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    printf 'Invalid WordPress plugin version: %s\n' "$version" >&2
    exit 1
  fi
}

fail_export_scan() {
  printf 'Refusing to publish WordPress.org export: %s\n' "$1" >&2
  exit 1
}

validate_export_top_level() {
  local path name found
  found=0

  for path in "$EXPORT_DIR"/* "$EXPORT_DIR"/.[!.]* "$EXPORT_DIR"/..?*; do
    [ -e "$path" ] || continue
    name="${path##*/}"

    case "$name" in
      trunk|tags|assets) ;;
      *)
        printf 'Unexpected top-level path in WordPress.org export: %s\n' "$name" >&2
        found=1
        ;;
    esac
  done

  if [ "$found" -ne 0 ]; then
    fail_export_scan 'only trunk, tags, and assets may be published'
  fi
}

scan_export_paths() {
  local path rel name found
  found=0

  while IFS= read -r -d '' path; do
    [ "$path" != "$EXPORT_DIR" ] || continue
    rel="${path#"$EXPORT_DIR"/}"
    name="${rel##*/}"

    case "$name" in
      .DS_Store|.env|.env.*|*.pem|*.key|*.p12|*.pfx|*.crt|*.der|*.csr|id_rsa|id_dsa|id_ecdsa|id_ed25519|.npmrc|.yarnrc|.yarnrc.yml|.netrc|.pypirc|*.map)
        printf 'Forbidden path in WordPress.org export: %s\n' "$rel" >&2
        found=1
        ;;
    esac

    case "$rel" in
      .git|.git/*|*/.git|*/.git/*|.github|.github/*|*/.github|*/.github/*|.svn|.svn/*|*/.svn|*/.svn/*|.ssh|.ssh/*|*/.ssh|*/.ssh/*|.aws|.aws/*|*/.aws|*/.aws/*)
        printf 'Forbidden path in WordPress.org export: %s\n' "$rel" >&2
        found=1
        ;;
    esac

    if [ -L "$path" ]; then
      printf 'Forbidden symlink in WordPress.org export: %s\n' "$rel" >&2
      found=1
      continue
    fi

    if [ -d "$path" ]; then
      continue
    fi

    if [ ! -f "$path" ]; then
      printf 'Forbidden non-regular path in WordPress.org export: %s\n' "$rel" >&2
      found=1
      continue
    fi

    case "$name" in
      LICENSE|*.php|*.js|*.css|*.svg|*.txt|*.png|*.jpg|*.jpeg|*.gif|*.webp|*.ico|*.json|*.pot|*.po|*.mo|*.woff|*.woff2|*.ttf|*.eot) ;;
      *)
        printf 'Unexpected file type in WordPress.org export: %s\n' "$rel" >&2
        found=1
        ;;
    esac
  done < <(find "$EXPORT_DIR" -print0)

  if [ "$found" -ne 0 ]; then
    fail_export_scan 'forbidden files or directories were found'
  fi
}

scan_export_secrets() {
  local secret_pattern secret_files status matched_path

  if command -v gitleaks >/dev/null 2>&1; then
    if ! gitleaks detect --no-git --source "$EXPORT_DIR" --redact; then
      fail_export_scan 'secret scanning failed or found potential secrets'
    fi
  fi

  secret_pattern='(-----BEGIN (RSA |DSA |EC |OPENSSH |PGP )?PRIVATE KEY-----|AKIA[0-9A-Z]{16}|ASIA[0-9A-Z]{16}|ghp_[A-Za-z0-9_]{30,}|github_pat_[A-Za-z0-9_]{20,}|glpat-[A-Za-z0-9_-]{20,}|xox[baprs]-[A-Za-z0-9-]{10,}|npm_[A-Za-z0-9]{20,}|sk-[A-Za-z0-9_-]{20,}|AIza[0-9A-Za-z_-]{35})'

  if secret_files="$(LC_ALL=C grep -IRlE "$secret_pattern" "$EXPORT_DIR")"; then
    printf 'Potential secrets detected in WordPress.org export:\n' >&2
    while IFS= read -r matched_path; do
      [ -n "$matched_path" ] || continue
      printf '  %s\n' "${matched_path#"$EXPORT_DIR"/}" >&2
    done <<< "$secret_files"
    fail_export_scan 'potential secrets were found'
  else
    status=$?
    if [ "$status" -ne 1 ]; then
      printf 'Secret scan failed for WordPress.org export\n' >&2
      exit "$status"
    fi
  fi
}

if [ "$#" -gt 1 ]; then
  printf 'Usage: %s [version]\n' "$0" >&2
  exit 1
fi

ROOT_DIR="$(git rev-parse --show-toplevel)"
VERSION="${1:-${VERSION:-}}"

if [ -z "$VERSION" ]; then
  VERSION="$(bash "$ROOT_DIR/scripts/validate-wordpress-plugin-release.sh")"
fi

validate_version "$VERSION"

EXPORT_DIR="$ROOT_DIR/dist/frontman-wordpress-org-v${VERSION}"
svn_url="https://plugins.svn.wordpress.org/frontman-agentic-ai-editor"
svn_bin="svn"
svn_username="${WORDPRESS_ORG_USERNAME:-}"
svn_password="${WORDPRESS_ORG_PASSWORD:-}"
unset WORDPRESS_ORG_USERNAME WORDPRESS_ORG_PASSWORD WORDPRESS_ORG_SVN_URL SVN_BIN
export -n svn_username svn_password 2>/dev/null || true

if [ -z "$svn_username" ] || [ -z "$svn_password" ]; then
  printf 'WORDPRESS_ORG_USERNAME and WORDPRESS_ORG_PASSWORD are required\n' >&2
  exit 1
fi

case "$svn_url" in
  https://plugins.svn.wordpress.org/frontman-agentic-ai-editor) ;;
  *)
    printf 'Unexpected WordPress.org SVN URL\n' >&2
    exit 1
    ;;
esac

for command in "$svn_bin" rsync find grep awk; do
  if ! command -v "$command" >/dev/null 2>&1; then
    printf 'Required command not found: %s\n' "$command" >&2
    exit 1
  fi
done

if [ ! -d "$EXPORT_DIR/trunk" ] || [ ! -d "$EXPORT_DIR/tags/$VERSION" ] || [ ! -d "$EXPORT_DIR/assets" ]; then
  printf 'WordPress.org export not found for version %s. Run: make package-wordpress-plugin VERSION=%s\n' "$VERSION" "$VERSION" >&2
  exit 1
fi

validate_export_top_level
scan_export_paths
scan_export_secrets

SVN_WC="$(mktemp -d)"
trap 'unset svn_password; rm -rf "$SVN_WC"' EXIT

"$svn_bin" checkout --depth infinity "$svn_url" "$SVN_WC"

rsync -a --delete --exclude '.svn/' "$EXPORT_DIR/" "$SVN_WC/"

while IFS= read -r deleted_path; do
  [ -n "$deleted_path" ] || continue
  "$svn_bin" delete --force "$deleted_path"
done < <("$svn_bin" status "$SVN_WC" | awk '$1 == "!" {print substr($0, 9)}')

"$svn_bin" add --force "$SVN_WC"

for file in "$SVN_WC"/assets/*.png; do
  [ -e "$file" ] || continue
  "$svn_bin" propset svn:mime-type image/png "$file"
done

for file in "$SVN_WC"/assets/*.jpg "$SVN_WC"/assets/*.jpeg; do
  [ -e "$file" ] || continue
  "$svn_bin" propset svn:mime-type image/jpeg "$file"
done

for file in "$SVN_WC"/assets/*.gif; do
  [ -e "$file" ] || continue
  "$svn_bin" propset svn:mime-type image/gif "$file"
done

for file in "$SVN_WC"/assets/*.svg; do
  [ -e "$file" ] || continue
  "$svn_bin" propset svn:mime-type image/svg+xml "$file"
done

STATUS="$("$svn_bin" status "$SVN_WC")"

if [ -z "$STATUS" ]; then
  printf 'No WordPress.org SVN changes to publish for version %s\n' "$VERSION"
  exit 0
fi

printf '%s\n' "$STATUS"

if [ "${DRY_RUN:-}" = "1" ]; then
  printf 'DRY_RUN=1; skipping WordPress.org SVN commit for version %s\n' "$VERSION"
  exit 0
fi

set +x
printf '%s\n' "$svn_password" | "$svn_bin" commit \
  --non-interactive \
  --no-auth-cache \
  --username "$svn_username" \
  --password-from-stdin \
  -m "Release ${VERSION}" \
  "$SVN_WC"
