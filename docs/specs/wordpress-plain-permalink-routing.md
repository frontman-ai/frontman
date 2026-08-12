# Spec: WordPress Plain Permalink Routing

## Objective

Make a packaged Frontman plugin usable immediately after installation on a fresh
WordPress site whose permalink structure is still Plain. Preserve existing pretty
permalink URLs and verify compatibility with WordPress 7.0.3.

## Commands

- Isolated tests: `make test-wordpress-core-tools`
- Current runtime: `WORDPRESS_VERSION=7.0.3 PHP_VERSION=8.4 CONTAINER_RUNTIME=podman make test-wordpress-runtime`
- Minimum PHP runtime: `WORDPRESS_VERSION=7.0.3 PHP_VERSION=7.4 CONTAINER_RUNTIME=podman make test-wordpress-runtime`
- Package: `make package-wordpress-plugin VERSION=3.0.0`

## Project Structure

- `libs/frontman-wordpress/`: plugin routing and rendered runtime configuration
- `libs/client/`: shared runtime URL and relay construction
- `libs/frontman-wordpress/tests/`: isolated PHP behavior tests
- `libs/frontman-wordpress/tests/integration/`: real WordPress runtime tests
- `scripts/test-wordpress-plugin-runtime.sh`: disposable WordPress test environment
- `.github/workflows/wordpress-compatibility.yml`: supported compatibility matrix

## Code Style

Expose one optional route prefix through runtime configuration. Root pretty
permalinks use an empty prefix; root plain permalinks use `/index.php`:

```php
$runtime = [
	'basePath'   => 'frontman',
	'routePrefix' => '/index.php',
];
```

## Testing Strategy

- A real HTTP runtime test must first prove that a fresh Plain-permalink install
  cannot reach Frontman through the current generated entrypoint.
- Runtime tests must exercise the admin entrypoint, UI, tool discovery, nonce
  rejection, and authenticated tool calls over HTTP without changing permalinks.
- Existing pretty-permalink routing remains covered by isolated router tests and a
  runtime HTTP check after enabling a post-name structure.
- WordPress 7.0.3 must pass on PHP 7.4 and PHP 8.4 before compatibility metadata changes.

## Boundaries

- Always preserve `/frontman` and suffix routes for pretty permalinks.
- Always keep authentication and nonce behavior unchanged.
- Ask first before changing the site's permalink option.
- Never write `.htaccess` directly or add Apache-only setup.
- Never change plugin semver outside the release workflow.

## Success Criteria

- Fresh Plain-permalink installs expose a working generated Frontman URL through
  the WordPress front controller.
- The admin menu opens that generated URL instead of a web-server 404.
- Frontman UI, `/tools`, and `/tools/call` use the same generated route prefix.
- Missing authentication still returns 401 and missing nonce still returns 403.
- Pretty-permalink `/frontman` behavior remains unchanged.
- WordPress 7.0.3 passes runtime tests on PHP 7.4 and PHP 8.4.
- `Tested up to`, runtime defaults, CI matrix, and user-facing coverage docs say 7.0.3.
- Isolated tests, runtime tests, package validation, and release ZIP creation pass.

## Open Questions

None. Compatibility metadata advances to 7.0.3; plugin version remains managed by
the normal release process.
