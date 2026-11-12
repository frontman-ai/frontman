# Frontman for WordPress

This is a candidate plugin, not a submitted or approved listing. Its proposed
endpoint and live tool catalog remain subject to policy review and actual OAuth
acceptance. The catalog is not silently filtered: it can include WooCommerce
refund tools capable of gateway refunds. Do not treat this bundle as evidence
that those capabilities are accepted by Claude's directory.

## Prerequisites and connection

You need a Frontman account, a WordPress site connected to it, and MCP access
enabled for that connection. Follow the server's setup instructions if
`list_sites` reports that setup is incomplete. The separate model-key setup
for Frontman's embedded agent is not required to use Claude with Frontman MCP.

For local Claude Code testing from the repository root, run
`claude --plugin-dir ./plugins/claude-wordpress`, then use `/mcp` to connect
Frontman and complete authorization. The skill is also available as
`/frontman-wordpress:wordpress`.

For Claude web or Cowork, run `make package-claude-wordpress` at the repository
root. In Claude, choose Customize → Plugins → Add → Upload plugin and upload
the diagnostic ZIP from `dist/claude-wordpress/`. Open the plugin's Connectors
tab to connect Frontman and complete authorization. Do not add another copy of
the connector. A future directory installation is separate from this local
candidate test. Upload, OAuth, and these surface flows have not been verified.

## Examples

- List the draft posts on my connected staging site.
- Read my homepage and suggest a clearer headline without changing it.
- Review my WooCommerce product descriptions and suggest improvements.

Claude sends requests through the hosted Frontman MCP service to your connected
WordPress site, and results return along that path. Available tools depend on
the site's installed integrations and your permissions. Gutenberg, Elementor,
theme, SEO, and WooCommerce capabilities vary by site.

Writes can affect the live site immediately, including published content and
notifications. Review the target and request before confirming. Not every tool
has a preview or automatic rollback; use your site's own backups and recovery
process. After a write, ask Claude to read back the result. If a request times
out, inspect the site's state before repeating it.

See the [Frontman documentation](https://frontman.sh/docs/), [support](https://frontman.sh/contact/),
[privacy policy](https://frontman.sh/privacy/), and [terms](https://frontman.sh/terms/).
This bundle is licensed under Apache-2.0; see the [repository license](https://github.com/frontman-ai/frontman/blob/main/LICENSE).

## Repository checks

Run `make -C plugins/claude-wordpress toolchain` once to download Claude Code
2.1.311 into the ignored workspace `dist/` directory. This verifies Anthropic's
release signing-key fingerprint, signed manifest, and binary checksum. It
requires curl, GnuPG, jq, and a SHA-256 utility; checks also require Make,
Bash, zip, and unzip. The supported bootstrap platforms are macOS and Linux on x64 or
ARM64. Then run `make check-claude-wordpress`.
The official Claude CLI validates the plugin format. A small integration test
checks the Frontman endpoint, isolated CLI configuration, and the ZIP's exact
contents. Run `make package-claude-wordpress` only when you need a local upload.
The directory reads the GitHub-backed source, not this ZIP. Update the committed
manifest version when releasing plugin changes. Validation does not require login or inference.
