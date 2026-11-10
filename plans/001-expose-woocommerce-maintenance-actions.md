# Plan 001: Expose WooCommerce maintenance actions individually

## Status and constraints

- Status: Implementation present. Changed-code runtime acceptance remains blocked by Docker capacity.
- Priority: P1. OpenAI's scan flags the current discovery/executor pair.
- Effort: M–L, including compatibility and hosted runtime tests.
- Risk: MED. Public tool names change, and maintenance actions can delete store data.
- Planned at: `c59888e1`, 2026-11-10, in an isolated fork with unrelated inherited changes.
- Dependencies: none.
- Hard constraint: delete more code than the implementation adds.

The code budget includes production code, tests, and task-runner code.
It excludes documentation, generated files, vendored dependencies, and formatting-only changes.
The production adapter can grow. The combined code diff must shrink.
Do not count unrelated deletions or remove coverage to meet this constraint.
If the requirement means production-only net deletion, stop for a scope decision.

## Purpose

Replace `wc_get_system_status_tools` and `wc_run_system_status_tool` with individually exposed tools.
Preserve one internal execution path and native WooCommerce authorization.
Support extension actions through an explicit metadata contract, not guessed safety annotations.

OpenAI requires each model-callable operation to have its own description, input schema, and annotations:
https://developers.openai.com/plugins/plugin-guidelines#tool-independence-and-exposure

Separate public tools do not require separate execution implementations.
An enum argument or a renamed generic executor does not meet this requirement.
Portal acceptance remains an external gate.

## Current implementation

`libs/frontman-wordpress/tools/class-tool-woocommerce.php:415–419` registers the problematic pair:

```php
$this->add_endpoint_tool( $tools, 'get_system_status_tools', 'Retrieves WooCommerce system status tools.', 'GET', '/system_status/tools', $this->empty_schema() );
$this->add_endpoint_tool( $tools, 'run_system_status_tool', 'Runs one WooCommerce maintenance action. Depending on toolId, it can delete data, rebuild state, or queue work. Inspect the available action before approval and do not retry blindly.', 'PUT', '/system_status/tools/{toolId}', $this->object_schema( [ 'toolId' => $this->string_prop( 'The system status tool ID.' ) ], [ 'toolId' ] ), [ 'read_before_write' => '/system_status/tools' ] );
```

Existing paths already provide the required infrastructure:

| File | Existing responsibility |
| --- | --- |
| `libs/frontman-wordpress/frontman.php` | Registers WooCommerce tools during `init` |
| `libs/frontman-wordpress/tools/class-tool-woocommerce.php` | Endpoint registration, confirmation, read-before-write, native REST dispatch |
| `libs/frontman-wordpress/includes/class-frontman-tools.php` | Definitions, duplicate-name rejection, schema enforcement, MCP results |
| `libs/frontman-wordpress/includes/class-frontman-tool-annotations.php` | Requires four actual booleans |
| `libs/frontman-wordpress/includes/class-frontman-router.php` | Browser and Application Password transports use the same registry |
| `apps/frontman_server/lib/frontman_server_web/mcp/server.ex` | Forwards descriptors and adds `site_id` |
| `apps/frontman_server/lib/frontman_server/wordpress.ex` | Dispatches only to an owned connection |

`handle_endpoint_tool()` already requires confirmation before REST requests.
For PUT requests, it reads the target before mutation.
`request()` preserves native REST authorization and error handling.
The new tools must reuse these paths.

The generic `add_custom_tool()` suffix claims upstream method parity or a Customizer operation.
Neither claim describes generated maintenance tools.
Construct their existing `Frontman_Tool_Definition` values directly rather than extending that misleading suffix.

## Target design

### One native catalog and one execution path

Use `WC_REST_System_Status_Tools_Controller::get_tools()` for available native action IDs.
Do not make authenticated REST requests during plugin bootstrap.
Do not call `execute_tool()` or extension callbacks during discovery.
The native controller includes conditional actions and the `woocommerce_debug_tools` filter.

Register maintenance tools after normal `init` callbacks, before either transport serves requests.
Use `wp_loaded` for this narrow registration step.
If registration starts after `wp_loaded`, register immediately.
Keep all other WooCommerce registration timing unchanged.
The native controller autoloads through WooCommerce's existing autoloader.
Do not add manual dependency includes or bootstrap REST recursively.

Bind every registered handler to its fixed native action ID.
Use stable names of the form `wc_maint_<native-id>`.
Require canonical lowercase ASCII IDs and a maximum full name length of 64 characters.
Reject malformed declarations and duplicate names. Do not silently normalize collisions.
The shorter prefix fits the long native attributes-regeneration action IDs.

Each maintenance tool has the same narrow input shape:

- `confirm`: a required boolean.
- No `toolId`, operation selector, arbitrary path, callback, or request body.
- `additionalProperties: false`.

WooCommerce's maintenance executor calls callbacks without PHP arguments.
That signature does not prove that a callback has no other input.
Some native callbacks read request parameters or require an administrator nonce.
Do not expose those callbacks through a confirmation-only descriptor.
An integration that needs parameters can already register a normal `Frontman_Tool_Definition`.
Do not add arbitrary argument forwarding or invent nonce bypasses.

At execution:

1. Require literal `confirm=true`.
2. Recheck that the fixed native action exists and is not disabled.
3. Use the existing GET-before-PUT REST path for that fixed ID.
4. Return the native result on success.
5. Convert native `success=false` into a tool error, even when HTTP status is 200.

Descriptions must distinguish queued work from completed work.
Do not add automatic retries, a scheduler, a catalog cache, or an output schema.
The hosted relay currently excludes tools with output schemas.

### One explicit metadata contract

Keep reviewed core descriptors in the WooCommerce module.
Each descriptor contains a stable description and all four explicit annotation values.
Do not infer annotations from names, HTTP methods, or the native button label.

An extension supplies the same descriptor under a `frontman` key on its native `woocommerce_debug_tools` entry.
Require:

- `description`: nonempty, plain text explaining the action and its effects.
- `annotations`: the existing `Frontman_Tool_Annotations` value.

This reuses the native WordPress filter. It does not create another registry or callback API.
The adapter owns the fixed schema, confirmation, name, and REST execution.
The extension owns its operation and truthful metadata.
An extension descriptor also commits to an operation that needs no hidden request input.
Construct annotation values only after Frontman loads, rather than requiring Frontman during another plugin's initial load.

Use a complete extension descriptor when present.
Otherwise use the reviewed core descriptor for that ID.
Without either descriptor, do not expose the action through MCP.
Keep it available in native WooCommerce administration.
Reject malformed explicit descriptors instead of applying guessed defaults.

Preserve safety warnings in reviewed descriptions.
For example, `verify_db_tables` can recreate tables, despite its inspection-oriented native label.
`clear_sessions` deletes current and saved carts.
`reset_roles` overwrites roles and capabilities.
Database upgrades and regeneration actions can queue background work.

WooCommerce also registers its own actions through `woocommerce_debug_tools`.
Do not mistake those actions for third-party extensions.
Review the installed native catalog before finalizing the built-in descriptor set.
Record any unsupported native action explicitly. Do not claim complete coverage without that comparison.

### Exceptions found during the complete source reads

The general adapter is suitable for a fixed, unambiguous native operation.
It is not a universal wrapper for every entry in the WooCommerce administration menu.

- `generate_cogs_value_meta_column` creates columns when absent and deletes columns when present.
  A fixed ID is not sufficient to preserve the operation the user approved.
  Do not expose a misleading create-only tool or a silent toggle.
  Separate create/delete adapters need state preconditions and their own fixed public names.
- `delete_inbox_notification` reads a note ID from `$_GET` and requires a `debug_action` nonce.
  It needs an explicit parameterized integration, not generic query forwarding.
- Attributes lookup regeneration reads an optional product ID from `$_REQUEST`.
  Without that input, it performs a full rebuild.
  Do not advertise per-product behavior through the confirmation-only adapter.
- Analytics refund repair is disabled in PHP and enabled by an administration UI workflow.
  The adapter must not bypass the disabled flag.
- Approved-directory and helper actions depend on administration bootstrap.
  Do not force `admin_init` or an administrator context to inflate the REST catalog.

Use existing normal tool definitions for exceptional adapters.
Do not expand the common metadata contract into another general execution framework.
Before implementation, classify every currently available native action as:
common adapter, exceptional adapter, or explicitly unsupported with a reason.
If a required exceptional adapter cannot fit the deletion budget, stop for a scope decision.

The upstream review found 23 additional potential IDs beyond the 17 controller entries.
They are conditional, not a promise of 40 simultaneously available tools.
The full read establishes their registrations and direct implementations.
It does not establish every downstream effect or final annotation value.
Unresolved annotation values must remain unresolved until their effects receive a separate source/runtime check.

## Scope

Allowed implementation changes:

- `libs/frontman-wordpress/tools/class-tool-woocommerce.php`
- `libs/frontman-wordpress/tests/WooCommerceToolsTest.php` — delete after coverage migration
- `libs/frontman-wordpress/tests/integration/WooCommerceAnnotationsRuntimeCases.php`
- `libs/frontman-wordpress/tests/integration/ToolAnnotationExpectations.php`
- `libs/frontman-wordpress/tests/integration/ToolAnnotationsRuntimeFixture.php`
- `libs/frontman-wordpress/tests/integration/RuntimeTestSupport.php` — only shared schema assertions, if needed
- `apps/frontman_server/test/frontman_server_web/mcp_sites_test.exs` — small WooCommerce-specific wire assertions
- `Makefile` — delete the retired test from `WORDPRESS_TESTS`
- `scripts/test-wordpress-plugin-runtime.sh` — dependency selection for the actual review version
- `.github/workflows/wordpress-compatibility.yml` — only the corresponding dependency-version coverage
- `libs/frontman-wordpress/tests/integration/TOOL-INVENTORY.md` — dated evidence, not invented results
- `docs/wordpress-mcp-release-acceptance.md` — append new results without replacing historical evidence
- One changeset for `@frontman-ai/frontman-wordpress`
- This plan and its index

Out of scope:

- A second tool registry, generic operation selector, or compatibility executor alias.
- Other WooCommerce CRUD tools and their existing contracts.
- Production registry, router, auth, and hosted relay rewrites.
- Cross-site descriptor conflict resolution, already deferred.
- The inherited login PR, browser fixture, package validator, and review-site provisioning changes.
- Live maintenance actions on the persistent reviewer site.
- Deployment, publication, merging, or pushing without separate authorization.

## Implementation sequence

### 1. Establish an isolated baseline

Start a clean implementation branch from the intended current base.
Do not switch or reset the inherited dirty checkout.
Record the base SHA and compare every scoped file with this plan.
Read any changed files in full.
Classify the source-defined action repertoire before changing production code.
Runtime availability is the intersection with the native catalog, not a prerequisite for writing the adapter.
Record source-reviewed common actions and explicit reasons for exceptional or unsupported actions.
Do not claim that a source inventory establishes the installed runtime catalog.
Complete the installed-catalog comparison during final real-runtime acceptance.
Run the existing runtime suite before implementation.

Check: `make test-wordpress-runtime` exits zero, or record the actual environment blocker.
If hosted integration is available, require it with `FRONTMAN_REQUIRE_WP_SDK=1`.
A missing real dependency is not permission to substitute a fake.
If the WordPress baseline passes, an unrelated browser dependency failure does not prohibit source implementation.
Keep the incomplete browser acceptance explicit. Do not report the full SDK command as passed.
Do not install more dependencies or rerun container builds while Docker storage is full.

### 2. Replace the public pair

Delete both generic registrations and their annotation entries.
Delete the obsolete `toolId` special case in path-field handling.
Retain `wc_get_system_status`, which is a different diagnostic operation.
Add fixed-action generation and the explicit metadata contract in the existing module.

Check: neither retired name occurs in production registrations.
Check: each generated definition contains only the confirmation input and explicit booleans.
Check: every action delegates to native REST dispatch with a captured, fixed ID.

### 3. Replace the mock runner with real coverage

The existing `WooCommerceToolsTest.php` contains 501 lines.
It declares substitute WordPress and WooCommerce classes, request recorders, and its own assertion runner.
Delete it only after all meaningful assertions have real-runtime replacements.
Delete its entry from the root Makefile.

Retain or migrate these existing behaviors:

| Existing behavior | Real-runtime replacement |
| --- | --- |
| Complete tool-name registration | Independent annotation/catalog oracle |
| Object properties, required fields, array items | Traverse serialized schemas with shared assertions |
| Product pagination and filters | Known fixture products and observable result ordering |
| Raw product inputs | Shared sanitizer byte preservation and native persisted description |
| GET-before-PUT updates | Passive native REST observation plus persisted readback |
| String gateway ID | Read an unconfigured built-in gateway in the disposable store |
| Global review routes and product filtering | Create/read a disposable native product review |
| Update/delete confirmation | Missing, false, and wrong-typed confirmation leave fixtures unchanged |
| Metadata upsert | Existing real metadata suite, plus read-before-write where not already covered |
| Metadata deletion | Real CRUD deletion and readback |

Use passive observation only. Do not replace native REST responses or permission checks.
Use the existing shared assertions, HTTP helpers, fixture cleanup, and failure reporting.
Do not create another test target, bootstrap, or assertion framework.

Add maintenance-specific cases:

- Both retired tool names are absent and cannot dispatch.
- Every supported action has its own stable descriptor before any model tool call.
- A cache action clears a real fixture cache through browser and MCP REST transports.
- Missing, false, coerced, or extra arguments cause no maintenance side effects.
- A `toolId` argument cannot select another operation.
- Native capability denial prevents execution.
- A removed or disabled native action fails before execution.
- Native operation failure is not presented as tool success.
- Discovery never executes a maintenance callback.
- Repeated discovery produces no duplicate names.
- WooCommerce absence registers no maintenance tools.
- Core descriptors work without extension metadata.
- Complete extension metadata works through the same adapter.
- Missing metadata creates no generic fallback.
- Malformed metadata and name collisions fail clearly.

Extend the existing annotation fixture for the extension contract.
Use actual WooCommerce cache functions and real persisted state.
Fixture extensions must not replace WordPress, WooCommerce, or their REST implementation.
Keep descriptor fixtures separate from production inventory counts.
Do not execute all destructive maintenance actions merely to enumerate them.

### 4. Preserve catalog evidence

Update the independent annotation oracle for the new public names.
Keep expected hints independent of production descriptor values.
Account for conditional native availability with explicit reviewed IDs.
Do not replace coverage with a count derived from the production registry itself.

The current count of 111 includes the two retired tools.
The new count is the unchanged 109 tools plus the supported individual maintenance actions.
Native availability can vary by plugin version and feature state.
Keep that variability separate from background jobs that temporarily disable an action.

The existing hosted runtime test already compares the entire PHP and hosted catalogs.
Add only narrow assertions for maintenance names, schemas, annotations, and absence of the retired pair.
Keep the shared hosted relay unchanged.

### 5. Enforce the deletion budget and run acceptance

Target no more than 450 added code lines, funded by deletion of the 501-line mock runner and retired code.
This is a planning budget, not a measured diff.
If equivalent coverage exceeds the budget, simplify or stop. Do not delete more tests to conceal the overrun.

From the clean implementation base, record `git diff --numstat "$BASE"`.
Include every changed code file, including tests and Makefiles.
Require total deleted code lines to exceed total added code lines.
Report production and test totals separately.
Do not count this plan, other Markdown, generated output, or vendored files as deleted code.
Do not compress formatting to meet the budget.

Use this gate after every logical implementation step:

```sh
git diff --numstat "$BASE" -- '*.php' '*.exs' Makefile '*.sh' '*.yml' |
  awk '{ added += $1; deleted += $2 }
       END { print "Added:", added, "Deleted:", deleted; exit !(deleted > added) }'
```

The allowed code paths already exist, so this gate does not omit new code files.
If scope expands to a new code file, include that file before measuring.
The first coherent replacement can contain both deletions and additions.
Do not commit an additive intermediate implementation that violates the gate.

Run these acceptance commands sequentially:

```sh
make test-wordpress-runtime
FRONTMAN_REQUIRE_WP_SDK=1 make test-wordpress-runtime
make test-wordpress-core-tools
make check-source-comments
git diff --check
```

Use a unique `MIX_TEST_DB_SUFFIX` for each independent hosted run.
Do not reset an existing developer database.
The WordPress targets share package output and must not run concurrently in one checkout.
Run the applicable WordPress/PHP/Yoast configurations from `.github/workflows/wordpress-compatibility.yml`.
The current runner selects WooCommerce 9.9.5 or 10.4.3 from the WordPress version.
It does not establish compatibility with 11.2.2 on the persistent reviewer site.
If that version remains the review target, add it to the same runner and always-run compatibility matrix.
Preserve older dependency coverage and existing automatic exclusions.
The downloaded official 11.2.2 ZIP had SHA-256 `a4746183efd951de5837396aad119f7cf508f06cb699ccb590a01cada4c44932`.
Recheck the official artifact before pinning that checksum.
Do not add an opt-in parallel suite.

## Done criteria and external acceptance

- Each supported maintenance operation has a fixed public tool and a closed input schema.
- All four annotations come from explicit descriptors.
- All execution retains native REST permissions and confirmation.
- The old discovery/executor pair has no public aliases or fallback path.
- Equivalent real-runtime coverage replaces the retired mock suite.
- Browser, REST, and hosted catalogs agree for the tested account.
- The code diff is net-negative under the stated counting rule.
- The actual WordPress and WooCommerce versions are recorded with the results.

After authorized deployment, upgrade each site connected to the reviewer account.
An old site can reintroduce the retired tools through the hosted catalog union.
Rescan the actual reviewer connection in OpenAI.
Inspect every generated descriptor and the new findings.
A passing local suite does not establish OpenAI acceptance.
Hosted-tool-only changes do not require a new OpenAI ZIP unless package inputs also change.

## Stop conditions

- The code or native contracts differ from this plan.
- Late registration makes browser and REST catalogs inconsistent.
- A required native action has no defensible effects contract.
- An extension needs arguments that the native maintenance API cannot carry.
- Coverage migration requires test doubles or deletes meaningful assertions.
- The complete code diff is not net-negative.
- The change requires production auth, registry, relay, or unrelated CRUD rewrites.
- Any acceptance command fails twice after a reasonable correction.

Report the specific blocker instead of improvising around these conditions.

## Reading record and limits

The planning pass read the following local files in full, including retained output pages:

- Root `AGENTS.md`, `CLAUDE.md`, `README.md`, `CONTRIBUTING.md`, `package.json`, and `Makefile`.
- `libs/frontman-wordpress/AGENTS.md`, `frontman.php`, `composer.json`, and `package.json`.
- `tools/class-tool-woocommerce.php` in the WordPress package.
- The package's `includes/class-frontman-tools.php`, `class-frontman-tool-annotations.php`, `class-frontman-router.php`, `class-frontman-auth.php`, `class-frontman-sentry.php`, and `class-frontman-plugin-dependencies.php`.
- `tests/WooCommerceToolsTest.php` in the WordPress package.
- Its integration files `WooCommerceAnnotationsRuntimeCases.php`, `WooCommerceMetaRuntimeTest.php`, `WooCommerceCatalogRuntimeTest.php`, `ToolAnnotationExpectations.php`, `ToolAnnotationsRuntimeCases.php`, and `ToolAnnotationsRuntimeFixture.php`.
- Its integration files `RuntimeTestSupport.php`, `RunWordPressRuntimeTest.php`, `IntegrationToolAnnotationsRuntimeCases.php`, `CoreRuntimeCases.php`, `IsolatedRuntimeCases.php`, and `WordPressRuntimeTest.php`.
- Its integration `Dockerfile`, `ActivateWordPressPlugin.php`, and `TOOL-INVENTORY.md`.
- `scripts/test-wordpress-plugin-runtime.sh` and `scripts/package-wordpress-plugin.sh`.
- `.github/workflows/wordpress-compatibility.yml` and `openai-wordpress-release.yml`.
- `apps/frontman_server/AGENTS.md`, `lib/frontman_server_web/mcp/server.ex`, `lib/frontman_server/wordpress.ex`, and `test/frontman_server_web/mcp_sites_test.exs`.
- `plugins/openai-wordpress/README.md`, `mcp.json`, and `plugin.json`.
- `docs/wordpress-mcp-release-acceptance.md`.

The planning pass read both complete v2 maintenance controllers for WooCommerce 10.4.3 and 11.2.2.
It also read the complete 11.2.2 v3 subclass and autoloader.
An independent read-only agent completed full reads of all 11 additional `woocommerce_debug_tools` registration files in the official 11.2.2 archive.
Those files cover coupon migration, COGS, HPOS, legacy cleanup, inbox notifications, transient files, tax lookup migration, attribute lookup regeneration, analytics, approved directories, and helper caches.
The parent also read the complete COGS, inbox, and attributes-regeneration files to check the exceptional cases.

This is not a full audit of every transitive WooCommerce dependency.
No runtime tests, maintenance callbacks, production requests, installs, or deployments ran during this planning pass.
No production code or tests changed.
`git diff --check` passed for the planning workspace.

## Execution baseline update

After authorized build-cache cleanup, `make test-wordpress-runtime` passed on WordPress 7.0.2, PHP 8.4.27, and WooCommerce 10.4.3.
The SDK-required run passed both hosted phases, with two tests in each phase.
It then failed because Playwright headless shell revision 1248 was absent.
Revision 1243 does not satisfy that dependency.
Docker storage became low again, so further browser installs and container reruns remain paused.
Source implementation can continue against the successful real WordPress baseline.
Final acceptance remains incomplete until the required command passes on the changed implementation.

## Implementation review

The combined changes replace the generic pair with fixed tools and the extension metadata contract.
Native availability, disabled state, confirmation, permissions, and native failure results remain authoritative.
`install_pages` has a destructive hint because the native helper can restore and publish a matching trashed page.
The real-runtime test cases replace the retired 501-line mock runner.
The existing compatibility workflow includes a pinned WooCommerce 11.2.2 row.

Measured implementation code: 303 added lines, 515 deleted lines, net -212.
Documentation and the changeset are excluded from those totals.
The unrelated inherited login, package, and browser changes remain untouched.

The following checks passed on the combined changes:

- PHP lint for all three changed PHP files.
- Shell syntax for the modified runtime runner.
- `make check-source-comments`, including 30 scanner tests and the repository scan.
- `git diff --check`.
- Three pre-resource runtime-runner rejection checks through the real Make target.
  These reject WordPress 6.9.9 with WooCommerce 11.2.2, PHP 7.3, and an unknown override.

The new integration cases did not run.
The native HTTP 200 `success=false` conversion also lacks a dedicated runtime failure case.
Docker reported 256 MB available at 100% usage, so no new container build or browser install ran.
No production deployment, publication, or OpenAI rescan occurred.
Do not mark this plan DONE until changed-code runtime acceptance passes.

## Verification attempt after PR creation

PR #2175 contains the implementation and is ready for review.
The November 10 changed-code attempt used `make test-wordpress-runtime`.
The command exceeded its 200-second limit before the tests.
MariaDB failed to create its undo tablespace with error 28.
The container filesystem reported 100% usage and 3 MB available.
Only the containers, network, and image from that attempt were deleted.
The changed-code runtime result remains unknown.
The dedicated CI compatibility run provides the next acceptance evidence.
