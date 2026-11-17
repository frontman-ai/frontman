# Implementation results

## Outcome

Plans 001 through 004 are complete within their defined scopes.
Plan 003 completed characterization without a speculative capture change.
Plan 005 documentation is complete.
Operational landing-page acceptance remains BLOCKED or NOT RUN.

Implementation and independent runtime validation completed on 2026-11-15.
Parent reconciliation completed on 2026-11-17 against unchanged reviewed source.
The repository base remains `e87074a5`.
Validation describes this base plus the reviewed changes, not a deployment.
No Git landing, push, publication, deployment, or customer-site write occurred during implementation validation.
The user later authorized feature-branch publication and a combined PR.
Shared-branch landing, deployment, and customer-site writes remain unauthorized.

## Delivered changes

| Plan | Result |
|---|---|
| 001 | Planner guidance and the existing banner explain explicit Executor handoff. Permissions and selection rules are unchanged |
| 002 | Existing SEO tools support Yoast stored preferences `default`, `noindex`, and `index`, with guarded native persistence and derived-state readback |
| 003 | Real-tool screenshot coverage preserves disclosure state, geometry, image content, and semantic live state. FAQ expansion did not reproduce |
| 004 | Errors remain visible until dismissal. The alert and dismiss button are accessible. Image-only guidance replaces the incorrect PDF promise |
| 005 | A staged acceptance runbook and an honest results template separate local, actual-draft, device, and vendor evidence |

Three user-facing changesets cover the handoff, attachment recovery, and WordPress indexing behavior.
Native PDF ingestion remains outside scope.

## Independent integrated checks

These commands ran in an isolated review worktree.
They exercised the integrated handoff, attachment, and screenshot changes.
The final generic dismiss-label revision also passed its focused four-case browser rerun.

| Command | Result |
|---|---|
| `make build` | Passed |
| `make -C libs/client test-screenshots` | Passed: 86 Chromium tests across 10 files |
| `make -C libs/client test` | Passed: 532 tests, two skipped |
| `make -C libs/frontman-client test` | Passed: 115 tests |
| `make -C apps/frontman_server test TEST_ARGS="test/frontman_server/agents_test.exs test/frontman_server/tasks/interaction_test.exs test/frontman_server_web/channels/task_channel_test.exs"` | Passed: 132 tests |
| `make -C apps/frontman_server precommit` | Passed on retry: 1,195 passed, five skipped, two excluded |
| `make -C libs/client lint` | Initially failed on baseline errors. Final rerun passed after the authorized lint cleanup |
| `make check-source-comments` | Passed: 30 scanner tests and repository scan |
| `git diff --check` | Passed |

Server tests used an owned local test database.
No shared database reset occurred.
The first full precommit run had one 100ms assertion timeout in an unchanged MCP diagnostics test.
Its same-file/same-seed rerun and full retry passed without timeout changes.
That first failure remains recorded as timing-sensitive validation, not a proven baseline defect.

## Final WordPress compatibility matrix

Every command below exited 0 after the final SQL-error correction.
Earlier-source runs do not count as this final acceptance.

| Command | Result |
|---|---|
| `make test-wordpress-runtime WORDPRESS_VERSION=7.0.2 PHP_VERSION=8.4 YOAST_VERSION=28.6` | Passed |
| `make test-wordpress-runtime WORDPRESS_VERSION=7.0.2 PHP_VERSION=7.4 YOAST_VERSION=28.4` | Passed |
| `make test-wordpress-runtime WORDPRESS_VERSION=7.0.2 PHP_VERSION=8.4 YOAST_VERSION=28.4` | Passed |
| `make test-wordpress-runtime WORDPRESS_VERSION=6.9.9 PHP_VERSION=8.2 YOAST_VERSION=19.9` | Passed |
| `make test-wordpress-runtime WORDPRESS_VERSION=7.0.2 PHP_VERSION=8.4 YOAST_VERSION=` | Passed |
| `make test-wordpress-runtime WORDPRESS_VERSION=6.0.9 PHP_VERSION=7.4 YOAST_VERSION=` | Passed |
| `make test-wordpress-runtime WORDPRESS_VERSION=7.0.2 PHP_VERSION=7.4 YOAST_VERSION=` | Passed |
| `make test-wordpress-runtime WORDPRESS_VERSION=7.0.2 PHP_VERSION=8.4 YOAST_VERSION= WOOCOMMERCE_OVERRIDE=11.2.2` | Passed |

All four Yoast rows executed the new indexing and real switched-site cases.
The primary command also passed independent final-source review.
That review used real disposable containers and PHP 8.4.27.
No dependency doubles supplied the integration evidence.

The cases cover:

- Strict enum inputs, omission, reset, repeats, and mixed updates
- Native permissions, sanitizer eligibility, and rejection before authored mutation
- Text-only preservation when indexing-specific write support is unavailable
- Failed saves, deletion, readback, and disabled or failed indexable persistence
- Same-value recovery for stale or absent derived state
- Anonymous robots, duplicate and bot-specific directives, and headers
- Actual sitemap inclusion, noindex exclusion, and restored inclusion
- Inherited policy, unrelated authored-state preservation, and draft/private non-disclosure
- Real switched-site rejection and restored-site recovery

## Review correction

The initial preflight did not distinguish an empty native ORM result from a nonthrowing SQL failure.
A real database fault reproduced a partial mixed save.
The final guard inspects the database error immediately after the native lookup.
It rejects before authored writes without exposing SQL details.
A successful empty lookup remains valid, including recovery after an earlier SQL error.
Independent review found no remaining material issue.

The following Git blob identifiers are content checksums, not commits or deployment versions:

| File | Reviewed final blob |
|---|---|
| `libs/frontman-wordpress/tools/class-tool-seo.php` | `9bd520759dc11168a0d30b687180e64f696f0bc8` |
| `libs/frontman-wordpress/tests/integration/SeoRuntimeFixture.php` | `8fceee4762e3d85dc6ccac6cb5ba82bf58824772` |
| `libs/frontman-wordpress/tests/integration/SeoIndexingRuntimeCases.php` | `a27a455da2ec196c035650a5eef9ee5f3bffde3c` |

Parent reconciliation matched all three identifiers on 2026-11-17.
It did not rerun the full matrix on that date.

## Final lint cleanup

The user authorized correction of the two baseline lint errors before PR publication.
The changes add JSON object spacing and reorder two adjacent JavaScript imports.
No behavior, test doubles, dependencies, or compiler policy changed.

- `make -C libs/client lint`: passed in the worker and parent worktrees.
- `make -C libs/client test TEST_FILTER=Client__IntegrationUpdates`: passed all six tests after compilation.
- `git diff --check`: passed.
- The existing Biome configuration deprecation remains informational.

## Remaining limits

- Optional SDK/client branches of the WordPress runtime lacked their local prerequisites.
  Their coverage is not claimed.
- The standalone PHP unit suite was not run or used as integration evidence.
- No actual landing-page, physical-device, vendor tracking, or consent-submission acceptance occurred.
  The [operational record](005-acceptance-results.md#L46) names the missing inputs and authorization.
- PDF parsing and storage remain unsupported.
- No release, deployment, customer-page mutation, or external lead submission is authorized by these results.
