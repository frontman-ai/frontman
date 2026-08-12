# Spec: WordPress 7 Support

## Objective

Verify Frontman against WordPress 7.0.3 and support WordPress 7 content models that
the current plugin misses: nested Gutenberg blocks and block-theme navigation.

## Commands

- Unit tests: `make test-wordpress-core-tools`
- WordPress runtime test: `bash scripts/test-wordpress-plugin-runtime.sh`
- Package: `make package-wordpress-plugin VERSION=3.0.0`

## Project Structure

- `libs/frontman-wordpress/tools/`: PHP tool implementations
- `libs/frontman-wordpress/tests/`: isolated PHP behavior tests
- `libs/frontman-wordpress/tests/integration/`: tests executed inside real WordPress
- `.github/workflows/`: compatibility CI

## Code Style

Keep existing WordPress PHP style and additive tool contracts. Existing numeric block
indices continue to address visible top-level blocks; nested blocks use raw tree paths:

```php
[ 'post_id' => 42, 'path' => [ 0, 1, 2 ] ]
```

## Testing Strategy

- Unit tests prove recursive block addressing and navigation CRUD behavior.
- Runtime tests activate packaged source in WordPress 7.0.3, exercise real block
  parsing/serialization and `wp_navigation` persistence, and fail on PHP notices.
- CI runs runtime tests on PHP 7.4 and a current PHP 8 release.

## Boundaries

- Always preserve existing top-level `index` inputs.
- Always require confirmation for destructive navigation deletion.
- Never rewrite classic menu tools to return a new response shape.
- Never mark WordPress 7 as tested unless runtime CI exists.

## Success Criteria

- Nested blocks are listed with paths and can be read, replaced, inserted, moved,
  and deleted without losing sibling/freeform content.
- Block-theme navigation entities can be listed, read, created, updated, and deleted.
- WordPress 7.0.3 runtime CI covers PHP 7.4 and PHP 8.x.
- All PHP tests, runtime tests, packaging validation, and syntax checks pass.
- WordPress.org metadata declares testing through WordPress 7.0.

## Open Questions

None. Existing classic-menu and top-level block contracts remain supported.
