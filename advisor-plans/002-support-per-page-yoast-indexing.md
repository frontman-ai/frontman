# Plan 002: Support per-page Yoast indexing preferences

> Executor: Read this plan and the complete relevant runtime test files before implementation.
> Use real WordPress and Yoast dependencies. Do not add dependency doubles.
> Stop at a STOP condition. Update the status in `advisor-plans/README.md` after review.
>
> Drift check: `git diff --stat e87074a5..HEAD -- libs/frontman-wordpress/tools/class-tool-seo.php libs/frontman-wordpress/tests/integration/WordPressRuntimeTest.php libs/frontman-wordpress/tests/integration/RuntimeTestSupport.php libs/frontman-wordpress/tests/integration/SeoRuntimeFixture.php libs/frontman-wordpress/tests/integration/SureRankRuntimeTest.php libs/frontman-wordpress/tests/integration/RunWordPressRuntimeTest.php scripts/test-wordpress-plugin-runtime.sh`

## Status

- Priority: P2
- Effort: L, approximately two to three days including the compatibility matrix
- Risk: MED
- Depends on: none
- Category: direction
- Planned at: commit `e87074a5`, 2026-11-15

## Why this matters

The existing SEO writer cannot set a page's Yoast `noindex` preference.
Agents must therefore leave this explicit requirement unfinished.
Extend the existing single-object SEO contract instead of adding arbitrary metadata writes.
Keep stored preferences, derived indexables, rendered directives, and sitemap observations distinct.

## Current state

[The field map](../libs/frontman-wordpress/tools/class-tool-seo.php#L16) contains:

```php
	private const META = [ 'title' => 'title', 'description' => 'metadesc', 'focus_keyphrase' => 'focuskw' ];
```

[The schema](../libs/frontman-wordpress/tools/class-tool-seo.php#L47-L57), validation at lines 165–184, and update loops at lines 191–239 use this map.
Empty text values reset provider defaults.
Do not give the new enum that string-field behavior.

[Capabilities](../libs/frontman-wordpress/tools/class-tool-seo.php#L66-L82) derive supported fields from the same map for both providers.
SureRank currently supports only the three read fields.
[Its real runtime test](../libs/frontman-wordpress/tests/integration/SureRankRuntimeTest.php#L13-L23) asserts that writes remain unavailable.

[The object guard](../libs/frontman-wordpress/tools/class-tool-seo.php#L241-L262) enforces eligible objects and post/meta permissions.
[Failure reporting](../libs/frontman-wordpress/tools/class-tool-seo.php#L283-L295) reports observed partial or uncertain state.
Preserve both patterns.

[Archive updates](../libs/frontman-wordpress/tools/class-tool-seo.php#L544-L580) already refresh native indexables and inspect persisted results:

```php
			$watcher->build_indexable( $term ? $target['term_id'] : $target['post_type'] );
			$refreshed = $this->verify_archive_indexable( $target, $after );
```

That is a lifecycle exemplar, not permission to add archive indexing fields.
Native watchers can return without a successful persisted refresh.

## Target contract

Add an optional `indexing` property to `wp_update_seo` for supported Yoast runtimes:

```json
{
  "type": "string",
  "enum": ["default", "noindex", "index"]
}
```

| Input | Stored preference | Native Yoast representation |
|---|---|---|
| Omitted | Preserve the current value | No mutation |
| `default` | Inherit the post-type policy | Delete the object override, native default `"0"` |
| `noindex` | Explicit object-level noindex | `"1"` |
| `index` | Explicit object-level index preference | `"2"` |

Use the native `meta-robots-noindex` key through `WPSEO_Meta`.
Do not expose that key or arbitrary robots strings as tool arguments.
The normalized read field describes a stored preference, not search-engine behavior.
An explicit `index` preference cannot override every broader directive or guarantee indexing.

Reject null, booleans, numbers, empty strings, unknown enum values, and unknown fields.
Enforce this through both registry validation and direct handler validation.
Allow an indexing-only request.
Preserve the existing text fields' omission and reset semantics.

Expose normalized indexing in Yoast reads and update snapshots when its reader contract is available.
Do not silently treat an unknown stored value as `default`.
Keep SureRank's existing read-only contract unchanged.
Advertised schemas, capabilities, and direct handler behavior must agree.
Do not disable existing text operations merely because indexing-specific dependencies are absent.

## Scope and conventions

Modify only:

- `libs/frontman-wordpress/tools/class-tool-seo.php`
- `libs/frontman-wordpress/tests/integration/WordPressRuntimeTest.php`
- `libs/frontman-wordpress/tests/integration/RuntimeTestSupport.php`
- `libs/frontman-wordpress/tests/integration/SeoRuntimeFixture.php`
- `libs/frontman-wordpress/tests/integration/SeoIndexingRuntimeCases.php` (new focused case file)
- `libs/frontman-wordpress/tests/integration/SeoIndexingMultisiteRuntimeCases.php` (new focused case file)
- `libs/frontman-wordpress/tests/integration/RunWordPressRuntimeTest.php`, only for the existing real network fixture
- `scripts/test-wordpress-plugin-runtime.sh`, only for that unified case invocation
- `libs/frontman-wordpress/tests/integration/SureRankRuntimeTest.php`, only if an additional preservation assertion is necessary
- One user-facing changeset generated through `yarn changeset`

The review authorized the narrow network-case wiring during implementation.
It reuses the existing real multisite fixture, runner, lifecycle, and cleanup.
It does not authorize another harness, Make target, or author-test refactor.

Read `AGENTS.md` and `libs/frontman-wordpress/AGENTS.md`.
Use the unified runtime runner and shared assertion helpers.
Keep a new case file free of custom bootstraps and assertion frameworks.
Use PHP syntax supported by the existing PHP 7.4 compatibility target.

Out of scope:

- Arbitrary post-meta writers, bulk selectors, and additional SEO writer tools
- Planner permissions or tool access classifications
- Site-wide indexing, robots.txt, post-type defaults, or archive indexing mutations
- Separate sitemap controls, cache purges, or search-engine submissions
- Changing draft status, publishing pages, or editing authored page content
- SureRank writes or another SEO-provider integration

## Commands

Run from the repository root, sequentially.
The runner builds packages, downloads real dependencies, and creates disposable containers.
Do not run it against a customer site.

| Gate | Command | Expected result |
|---|---|---|
| Primary Yoast runtime | `make test-wordpress-runtime WORDPRESS_VERSION=7.0.2 PHP_VERSION=8.4 YOAST_VERSION=28.6` | Exit 0 with new indexing cases executed |
| PHP 7.4 compatibility | `make test-wordpress-runtime WORDPRESS_VERSION=7.0.2 PHP_VERSION=7.4 YOAST_VERSION=28.4` | Exit 0 |
| Other current Yoast pin | `make test-wordpress-runtime WORDPRESS_VERSION=7.0.2 PHP_VERSION=8.4 YOAST_VERSION=28.4` | Exit 0 |
| Older supported Yoast | `make test-wordpress-runtime WORDPRESS_VERSION=6.9.9 PHP_VERSION=8.2 YOAST_VERSION=19.9` | Exit 0 |
| No-Yoast preservation | `make test-wordpress-runtime WORDPRESS_VERSION=7.0.2 PHP_VERSION=8.4 YOAST_VERSION=` | Exit 0 |
| Older WordPress preservation | `make test-wordpress-runtime WORDPRESS_VERSION=6.0.9 PHP_VERSION=7.4 YOAST_VERSION=` | Exit 0 |
| Source policy | `make check-source-comments` | Exit 0 |
| Diff hygiene | `git diff --check` | Exit 0 |

The versions come from `.github/workflows/wordpress-compatibility.yml:54–76`.
An unqualified runtime run defaults to no Yoast in `scripts/test-wordpress-plugin-runtime.sh:7–9`.
That run alone cannot establish indexing coverage.
Run the remaining existing compatibility CI rows before landing.
Do not add a feature-specific Make target.

## Steps

### 1. Establish the native storage and permission contract

Inspect the real dependencies at the existing Yoast pins.
Record the following API contracts in test comments only where necessary:

- `WPSEO_Meta::get_value`, `set_value`, and `delete`
- The registered sanitizer for `_yoast_wpseo_meta-robots-noindex`
- The `wpseo_edit_advanced_metadata` permission and `disableadvanced_meta` policy
- `Indexable_Post_Watcher::build_indexable`
- The persisted post indexable's `is_robots_noindex` tri-state
- The supported method to detect intentionally disabled indexable persistence

The expected stored mapping is `"0"`/default, `"1"`/noindex, and `"2"`/index.
The expected indexable values are null, true, and false respectively.
Do not assume that newer helper methods exist on the oldest supported pin.

Verify: run the primary runtime baseline.
If the real dependency contradicts this contract, stop before adding write behavior.

### 2. Add contract and preservation cases

Create `SeoIndexingRuntimeCases.php` within the existing unified runtime.
Invoke it from the existing Yoast runtime phase after its fixtures and helpers exist.
Extend the shared HTTP parser to expose all robots tags without discarding duplicate directives.
Keep existing parser return fields compatible.
Use existing response headers for `X-Robots-Tag` assertions.

Add these cases through real authenticated tool dispatch:

- All enum states, repeated states, and reset
- Omitted indexing preservation during text-only writes
- Indexing-only and mixed text/indexing updates
- Invalid inputs through both direct handlers and HTTP
- Ineligible objects, missing nonce, object/meta denial, and advanced-field denial
- A sibling page and unrelated content, status, options, and metadata remain unchanged

Warm the page and its indexable before the mutation.
Use a new anonymous HTTP request for rendered assertions.
Inspect robots tokens rather than attribute order.

Use the existing real multisite fixture to exercise the switched-site guard.
Route its focused SEO case through the unified runtime.
Do not simulate a network with replacement APIs or late constant definitions.

Verify: run the primary runtime command.
The new indexing cases must fail before implementation.

### 3. Extend the existing read/update path

Keep text fields and indexing conversion distinct.
Do not append indexing blindly to all `META` loops.
Add only the minimum helpers necessary for provider eligibility and enum conversion.
Keep `wp_update_seo` as `read-write` with its existing mutation annotations.
Describe approval, reset semantics, and independent rendered checks in the tool description.

Before any write, perform all supplied-field checks.
These checks include input, provider, object, metadata, advanced permission, sanitizer, and refresh dependencies.
Reject a switched-site indexing request before mutation.
A mixed request must not save its title before discovering unsupported indexing.

Use native setters and deletion.
Read the stored values after each mutation.
Preserve the existing failed, partial, and uncertain reporting model.
Do not automatically retry or claim rollback after a partial save.

Verify: run the primary runtime command.
Assert the read result, saved enum, omitted-field preservation, and unchanged SureRank contract.

### 4. Refresh derived state and expose honest results

For requests that supply indexing, invoke Yoast's native post watcher.
Read the persisted target indexable without auto-create or upgrade.
Inspect the object identity and expected noindex tri-state.
Perform this refresh even for same-value requests.
An approved repeat can then repair stale derived state.

Use an additive `indexable_refreshed` result for indexing requests:

- `true`: persisted readback matched.
- `false`: the real runtime intentionally disabled persistence.
- Missing or mismatched persistence: return an error with observed save state.

Do not claim rendered success from this field.
Keep text-only refresh behavior unchanged.
Native derived maintenance can update related indexables and scheduling data.
Do not promise that only one physical database row changes.

Use real plugin hooks for runtime denial and save-failure cases.
Reuse the existing native fault-fixture pattern without replacing dependency APIs.
If a case needs a new test double, stop and request permission.

Cover failed writes, failed deletion, partial mixed saves, readback failure, and disabled or failed indexable persistence.
Cover same-value recovery after stale derived state.

Verify: run the primary runtime command and the oldest supported Yoast command.

### 5. Separate rendered and sitemap observations

Use a synthetic published local page for anonymous rendered and sitemap checks.
Preserve draft/private non-disclosure in separate cases.
Observe global and bot-specific robots tags plus relevant headers.
An inherited broader noindex remains effective even after an object-level index preference.

Observe the relevant Yoast sitemap independently.
Do not infer exclusion solely from the stored enum or a rendered tag.
Do not add sitemap mutations or global cache purges.
If native sitemap output remains stale, report it as a separate result.

Preserve explicit canonical/social metadata.
Do not require byte-identical derived schema when Yoast legitimately changes it for noindex.

Verify: run the primary runtime command.
Assert stored, derived, rendered, and sitemap outcomes independently.

### 6. Complete compatibility and release documentation

Run every command-table gate and the remaining existing compatibility CI rows.
Add the changeset.
Document the stored-preference meaning and limits of public rendered checks.
If the implementation exceeds 500 net-new lines, split it into coherent reviewed changes.
Do not split out an advertised but unsafe or incomplete write contract.

## Done criteria

- [ ] The existing tool supports the allowlisted enum on eligible Yoast runtimes.
- [ ] Unknown and malformed inputs fail before any write.
- [ ] Omission, reset, and mixed-field semantics pass through real dispatch.
- [ ] Existing text-only and SureRank contracts remain intact.
- [ ] Permission and failure paths report observed state without automatic retry.
- [ ] Native indexable refresh has independent persisted readback.
- [ ] Anonymous robots and sitemap observations remain separate.
- [ ] Draft/private fixtures do not disclose content anonymously.
- [ ] The real compatibility matrix and policy gates pass.

## STOP conditions

- Real WordPress or Yoast dependencies are unavailable.
- A supported pin lacks the required native sanitizer or safe refresh/readback contract.
- Advertised capabilities disagree with direct handler behavior.
- A partial or uncertain save needs recovery. Report observed state before another approved request.
- A proposed fix requires arbitrary metadata, site-wide policy changes, or cache purges.
- Public output cannot be inspected without publishing a customer draft.
- A gate fails twice after a reasonable correction.

## Git workflow and maintenance

Use a focused feature branch or an attached isolated Delta worktree.
Do not merge, publish, deploy, or modify production without explicit authorization.
Review native API compatibility on every Yoast version update.
Review inherited robots policy and sitemap behavior independently of the stored enum.
