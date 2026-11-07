# WordPress MCP release acceptance

## Release status

Release acceptance is incomplete. Local checks do not replace staging OAuth acceptance.

The PR candidate uses upstream `7445bd82` plus the WordPress annotation and hosted OAuth changes.
It preserves the upstream post-editing restrictions, onboarding behavior, async tests, and browser fixtures.
The supported WooCommerce catalog contains 111 tools after upstream deleted three redundant metadata-create aliases.
No tool was hidden to simplify ChatGPT submission.

| Gate | Result |
| --- | --- |
| Server precommit | Passed on the latest base: 1,161 tests, two skipped, two excluded |
| Hosted MCP/controller tests | Covered by latest-base precommit; earlier focused run passed 25 tests |
| Core PHP suite | Passed on PHP 8.4.27 with the macOS environment adjustments below |
| Source-comment policy | Passed: 30 scanner tests and repository scan |
| Changed PHP files and runtime shell syntax | Passed |
| Required WordPress/hosted SDK integration | Passed on the latest base: WordPress 7.0.2 / PHP 8.4.27, before and after WooCommerce activation |
| Real embedded-client browser fixture | Passed on the latest base |
| Full compatibility matrix | Historical pass at `efa3d336`: seven configurations and 13 hosted discovery/dispatch phases |
| Real ChatGPT/WorkOS staging connection | Pending |
| External payment-provider sandbox | Not exercised |

The skipped default server cases require the WordPress runtime and browser environment.
The latest separate required runtime command passed both hosted discovery/dispatch phases and the embedded-client browser fixture.
The excluded application-restart cases are outside the default precommit suite.

The first attempts stopped because the Docker VM filesystem was full.
An authorized prune reclaimed 10.87 GB of unused images and 582 MB of build cache.
It did not prune existing containers or volumes.
The next run exposed a missing WordPress admin include during WooCommerce customer fixture cleanup.
Loading `wp-admin/includes/user.php` fixed cleanup without changing assertions.
The complete required runtime then passed.

The latest upstream browser fixture runs after in-place plugin version changes.
Restarting the whole container changed its random host port and left the exported browser URL stale.
The test image now revalidates opcode-cache timestamps on every request instead.
This removes the container restart and preserves the published endpoint.
The complete latest-base runtime passed with both Angie versions and the real client browser fixture.

## Automated acceptance

Use a fresh test database suffix for each independent acceptance run.
The server configuration appends `MIX_TEST_DB_SUFFIX` to the test database name.
Do not reset an existing developer database.

Run these commands from the repository root, sequentially:

```sh
make prepare-server-deps
make check-source-comments
make test-wordpress-core-tools
FRONTMAN_REQUIRE_WP_SDK=1 make test-wordpress-runtime
make -C apps/frontman_server test TEST_ARGS="test/frontman_server_web/mcp_sites_test.exs test/frontman_server_web/controllers/mcp_server_controller_test.exs"
make -C apps/frontman_server precommit
git diff --check
```

The two WordPress targets share generated package directories.
Parallel execution in the same checkout can invalidate their build output.

The runtime needs Docker or Podman, package-download access, Mix, PostgreSQL, and `pg_isready`.
On macOS, PostgreSQL client tools can require an explicit `PATH`.
The local acceptance run used `/opt/homebrew/opt/libpq/bin`.
It also used this process-local checksum function because macOS `sha256sum` rejects the required flags:

```bash
export PATH="/opt/homebrew/opt/php@8.4/bin:/opt/homebrew/opt/libpq/bin:$PATH"
export TMPDIR="$(php -r 'echo realpath(sys_get_temp_dir());')"
sha256sum() { shasum -a 256 "$@"; }
export -f sha256sum
```

The function preserves checksum validation. It does not change project scripts or skip package integrity checks.
The native core suite requires a canonical temporary path for its public-files fixture.
The default local PHP was 8.5, outside this acceptance matrix.
Its reflection deprecation failed the existing router test.
Selecting installed PHP 8.4 and a canonical `TMPDIR` resolved both native environment failures without source changes.

Run every configuration in the existing [compatibility matrix](../.github/workflows/wordpress-compatibility.yml).
The results below record `efa3d336`, before reconciliation with `7445bd82`.
They are not a claim that the full matrix ran again after the latest upstream changes.

| WordPress | PHP | Yoast | Result |
| --- | --- | --- | --- |
| 6.0.9 | 7.4 | Absent | Passed |
| 7.0.2 | 7.4 | Absent | Passed |
| 7.0.2 | 8.4 | Absent | Passed, including required hosted SDK integration |
| 7.0.2 | 7.4 | 28.4 | Passed |
| 7.0.2 | 8.4 | 28.4 | Passed |
| 7.0.2 | 8.4 | 28.6 | Passed |
| 6.9.9 | 8.2 | 19.9 | Passed |

Use `WORDPRESS_VERSION`, `PHP_VERSION`, and `YOAST_VERSION` with `make test-wordpress-runtime`.
Require hosted SDK integration for the WordPress 7.0.2 / PHP 8.4 configuration without Yoast.
Dependency exclusions on older WordPress versions remain explicit runner decisions.
Every local matrix run used `FRONTMAN_REQUIRE_WP_SDK=1` and a fresh database suffix.
All seven runs completed sequentially with exit code 0.
The actual PHP versions were 7.4.33, 8.4.27, and 8.2.35.
WordPress 6.0.9 omitted WooCommerce because it requires WordPress 6.7+.
That configuration passed one hosted phase. Each other configuration passed phases before and after WooCommerce activation.
Yoast HTTP SEO checks passed for all specified Yoast versions.

## Metadata contract

The three required OpenAI hints are `readOnlyHint`, `destructiveHint`, and `openWorldHint`.
Explicit `idempotentHint` is an additional Frontman convention.
Every supported mode contributes to a tool's classification.
An `edit_many` dry-run does not make `wp_update_post` read-only because its save mode persists changes.

The constructor requires an annotation value without classification defaults.
The annotation value rejects non-booleans even from non-strict PHP callers.
The intentionally non-strict runtime fixture exercises that boundary.
Catalog fixtures reuse the real post reader to exercise serialization and dispatch.
They do not represent production classifications or replace plugin dependencies.

Publication, uploads, notifications, refunds, and overwrites require separate effect review.
An empty, unassigned menu differs from a published menu item.
Public-file inspection uses real constrained loopback HTTP.
Its write path runs through HTTP under WordPress filesystem ownership.
The test discards stale CLI caches after another process changes stored state.

Hosted OAuth declarations come from one server policy:

```json
{"type": "oauth2", "scopes": []}
```

Anubis 2.2 serializes annotations and `_meta`, but lacks a top-level `securitySchemes` field.
The adapter uses its encoder after pagination and adds both OAuth declarations.
Native tool structs remain unchanged for dispatch.
Existing authorization remains authoritative.

## Staging acceptance procedure

1. Record the candidate commit, package checksum, hosted deployment, and staging MCP URL.
2. Deploy only after explicit deployment authorization.
3. Install the annotation-capable package on every connected staging site.
4. Use consistent tool definitions across those sites.
5. Connect ChatGPT through the existing WorkOS OAuth flow with a designated staging account.
6. Retrieve every page of `tools/list`.
7. Compare the complete hosted catalog with the authenticated catalogs of the connected sites.
8. Verify all four booleans on every descriptor, including `list_sites`.
9. Verify equal top-level and `_meta.securitySchemes` arrays with OAuth and empty scopes.
10. Run `list_sites` and a harmless site read.
11. Verify account isolation with a separate staging account.
12. Record sanitized results without credentials, tokens, or private tool output.

The SDK integration test supplies authenticated context directly.
It proves final wire serialization and WordPress dispatch, not real WorkOS token verification or ChatGPT linking.

The package header remains `5.6.0` until the release process assigns a version.
That number alone does not identify an annotation-capable build.
Record the actual artifact and assign the supported minimum plugin version before release.
Older connected sites do not receive guessed annotations or disappear through a new exposure filter.
Their upgrade is a release prerequisite.

Cross-site metadata conflict resolution remains deferred.
Consent copy, connection lifecycle, new scopes, and authentication rewrites remain separate work.
Refund coverage uses real disposable order/refund records with `api_refund=false`.
It does not prove external gateway behavior and never sends live funds.
