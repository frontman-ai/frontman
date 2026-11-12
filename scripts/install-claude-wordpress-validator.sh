#!/usr/bin/env bash
set -euo pipefail

root=$(cd "$(dirname "$0")/.." && pwd)
dir="$root/dist/claude-wordpress-validator"
version=2.1.311
fingerprint=31DDDE24DDFAB679F42D7BD2BAA929FF1A7ECACE
case "$(uname -s)-$(uname -m)" in
  Darwin-arm64) platform=darwin-arm64 ;;
  Darwin-x86_64) platform=darwin-x64 ;;
  Linux-x86_64) platform=linux-x64 ;;
  Linux-aarch64) platform=linux-arm64 ;;
  *) echo "Unsupported Claude validator platform" >&2; exit 1 ;;
esac

mkdir -p "$dir/gnupg" "$dir/config"
chmod 700 "$dir/gnupg"
export GNUPGHOME="$dir/gnupg"
base="https://downloads.claude.ai/claude-code-releases/$version"
curl -fsSL https://downloads.claude.ai/keys/claude-code.asc -o "$dir/key.asc"
actual=$(gpg --batch --show-keys --with-colons "$dir/key.asc" | awk -F: '$1 == "fpr" {print $10}')
if [ "$actual" != "$fingerprint" ]; then
  echo "Claude release signing key fingerprint mismatch" >&2
  exit 1
fi
gpg --batch --yes --dearmor -o "$dir/key.gpg" "$dir/key.asc"
curl -fsSL "$base/manifest.json" -o "$dir/manifest.json"
curl -fsSL "$base/manifest.json.sig" -o "$dir/manifest.json.sig"
gpgv --keyring "$dir/key.gpg" "$dir/manifest.json.sig" "$dir/manifest.json"
curl -fsSL "$base/$platform/claude" -o "$dir/claude.download"
expected=$(jq -er --arg platform "$platform" '.platforms[$platform].checksum | select(test("^[0-9a-f]{64}$"))' "$dir/manifest.json")
if command -v sha256sum >/dev/null; then
  actual=$(sha256sum "$dir/claude.download" | awk '{print $1}')
else
  actual=$(shasum -a 256 "$dir/claude.download" | awk '{print $1}')
fi
[ "$expected" = "$actual" ] || { echo "Claude binary checksum mismatch" >&2; exit 1; }
chmod 755 "$dir/claude.download"
mv "$dir/claude.download" "$dir/claude"
CLAUDE_CONFIG_DIR="$dir/config" DISABLE_AUTOUPDATER=1 "$dir/claude" --version
