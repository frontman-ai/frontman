# Spec: Custom CSS Revision Recovery

## Objective

Expose safe, theme-scoped recovery for WordPress Additional CSS without claiming
atomicity, byte identity, revision creation, or retry behavior that WordPress does
not provide. Real WordPress evidence defines the public restoration contract.

## Commands

- Isolated tests: `make test-wordpress-core-tools`
- Minimum runtime: `WORDPRESS_VERSION=6.0.9 PHP_VERSION=7.4 make test-wordpress-runtime`
- Current runtime: `WORDPRESS_VERSION=7.0.2 PHP_VERSION=7.4 make test-wordpress-runtime`
- Current PHP runtime: `WORDPRESS_VERSION=7.0.2 PHP_VERSION=8.4 make test-wordpress-runtime`
- Package: `make package-wordpress-plugin VERSION=2.0.0`

## Project Structure

- `libs/frontman-wordpress/tools/class-tool-options.php`: Additional CSS tools
- `libs/frontman-wordpress/tests/MutationSnapshotsTest.php`: isolated tool tests
- `libs/frontman-wordpress/tests/integration/CustomCssRuntimeTest.php`: real WordPress characterization and contract tests
- `scripts/test-wordpress-plugin-runtime.sh`: versioned WordPress runtime harness
- `.github/workflows/wordpress-compatibility.yml`: tested compatibility matrix

## Evidence

The runtime suite establishes these behaviors on WordPress 6.0.9 with PHP 7.4
and WordPress 7.0.2 with PHP 7.4 and 8.4:

- Initial and changed Custom CSS saves create enumerable revisions when enabled.
- Enabled-but-empty history and disabled revisions are distinguishable.
- Revision objects identify their parent; missing and cross-parent revisions can be rejected.
- A changed active stylesheet resolves a different Custom CSS parent.
- Generic restore and Custom CSS replay both restore plain `post_content` in the tested default configuration.
- Both paths created a revision in the tested cases, but creation and retention remain conditional WordPress behavior.
- Generic restore leaves `post_content_filtered` unchanged and bypasses `update_custom_css_data`.
- Replaying revision `post_content` invokes `update_custom_css_data`; a test preprocessor double-processes compiled CSS and replaces source with compiled CSS.
- Generic restore of preprocessor-backed CSS combines historical compiled output with current source.
- Generic post-save filters can transform persisted `post_content` for both strategies.
- A SHA-256 mismatch detects a stale state before writing, but another writer can update after that check and be overwritten.

## Restore Strategy

Use `wp_restore_post_revision( $validated_revision, [ 'post_content' ] )` for plain
CSS. Validate the loaded revision type and parent before passing that revision
object forward. Restore and verify only `post_content`.

Reject restoration when current `post_content_filtered` is non-empty. WordPress
revisions do not capture that field by default, so neither candidate can recover
coherent preprocessor source and compiled output. Do not replay stored compiled CSS
through `wp_update_custom_css_post()`.

After restoration, clean relevant post cache state and observe the persisted post
through documented WordPress APIs. Report observed values. Do not call this a
cache-bypassing database reread or promise that persisted bytes equal revision bytes;
post-save filters can transform content.

## Public Tool Contract

Public tools preserve current `wp_get_custom_css` fields and add parent ID, byte
count, SHA-256 fingerprint, modified timestamp, and preprocessor-source presence.
The fingerprint describes captured `post_content`; it is not a revision ID or lock.

Revision listing requires expected active stylesheet and parent ID. It returns
revision IDs, parent IDs, dates, byte counts, and SHA-256 fingerprints without full
CSS. Selected revision inspection returns full content only after stylesheet,
current parent, revision type, and revision parent validation.

Restore requires `confirm=true`, expected active stylesheet, expected parent ID,
selected revision ID, and expected current SHA-256. Every precondition runs before
the write. Hash comparison is best-effort point-in-time conflict detection, not an
atomic compare-and-swap.

Receipt fields are limited to selected revision ID and observed before/after content
metadata. No generated revision ID, byte-identity, atomicity, or retry-safety promise
is allowed. Verification mismatch returns conflict or ambiguity, not success.

## Lost Responses

No durable operation record or idempotency protocol exists in Phase 2. A lost
mutation response remains ambiguous. Recovery is to read current state, compare
observed metadata with known before and target states, inspect content when needed,
and ask the user to decide. Never retry restoration automatically.

## Boundaries

- Always require active stylesheet and current parent checks before revision data is returned.
- Always require confirmation and expected current state before restoration.
- Always verify and report observed persisted fields after restoration.
- Never restore preprocessor-backed CSS while revisions omit source.
- Never return full stylesheets in revision lists.
- Never claim atomic conflict detection, unconditional revision creation, idempotency, or safe blind retry.

## Success Criteria

- Real WordPress tests cover plain CSS, preprocessor filters, save transformations, revision availability, scope, stale state, and concurrent writes.
- CI runs exactly WordPress 6.0.9/PHP 7.4, WordPress 7.0.2/PHP 7.4, and WordPress 7.0.2/PHP 8.4.
- Public tools implement the contract above without changing existing Additional CSS response fields.
- User documentation explains workflow, compatibility, concurrency limits, preprocessor rejection, conditional revision behavior, and lost-response recovery.

## Open Questions

None. The evidence gate is complete, and the public tools implement this strategy.
