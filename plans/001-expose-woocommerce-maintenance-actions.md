# Plan 001: Expose WooCommerce maintenance actions individually

## Status

Implementation is present in PR #2175. Compatibility CI passed at `694860a5`.
External OpenAI acceptance remains incomplete.
Priority: P1. Risk: medium. Estimated effort: one to several days.
The original planning baseline was `c59888e1` on November 10, 2026.
The implementation branch starts at `3bb83e1a`.

OpenAI flagged `wc_get_system_status_tools` and `wc_run_system_status_tool`.
Each model-callable operation needs its own description, schema, and annotations:
https://developers.openai.com/plugins/plugin-guidelines#tool-independence-and-exposure

## Design decisions

- Replace the generic discovery/executor pair with `wc_maint_<native-id>` tools.
- Reuse `Frontman_Tools`, `Frontman_Tool_Definition`, and the existing WooCommerce REST dispatcher.
- Use the native `WC_REST_System_Status_Tools_Controller::get_tools()` catalog.
- Register at `wp_loaded`, or immediately when that action already ran.
- Do not execute callbacks or make authenticated REST requests during discovery.
- Bind each handler to one fixed action ID. Do not expose an operation selector.
- Require lowercase ASCII IDs and tool names of at most 64 characters.
- Reject invalid declarations and duplicate names instead of normalizing them.
- Give each tool a closed schema containing only the required boolean `confirm`.
- Require literal `confirm=true`, then recheck native availability and disabled state.
- Retain the existing GET-before-PUT path and native capability checks.
- Treat native HTTP 200 results with `success=false` as tool errors.
- Distinguish queued work from completed work. Do not add automatic retries.
- Keep the hosted relay, authentication, other CRUD contracts, and registry unchanged.

The production module contains the reviewed core descriptions and four explicit annotations.
An extension can supply a `frontman` entry through `woocommerce_debug_tools`.
That entry requires a nonempty plain-text description and a `Frontman_Tool_Annotations` value.
Malformed explicit metadata fails. Unknown actions without metadata remain outside MCP.
The adapter owns the schema, confirmation, naming, and REST dispatch.
Extensions that need parameters must register normal explicit tool definitions.
This contract does not permit arbitrary request data or another callback registry.

## Native action boundaries

The source review covered WooCommerce 10.4.3 and 11.2.2 controllers and conditional registrations.
That review does not establish the runtime catalog or every downstream effect.
The common adapter supports only fixed operations without hidden request inputs.

- COGS column management toggles between creation and deletion. It needs separate state-guarded adapters.
- Inbox notification deletion needs a note ID and an administrator nonce.
- Attributes regeneration reads optional request data. The common adapter does not support it.
- Analytics refund repair must retain its native disabled state.
- Administrator-only registrations must not force an administrator bootstrap during discovery.

Unsupported actions remain available through their native administration interfaces.
New adapters require separate descriptions, schemas, annotations, and acceptance evidence.
The implementation does not claim complete coverage of every conditional native action.

## Scope

Production changes belong in `libs/frontman-wordpress/tools/class-tool-woocommerce.php`.
Runtime cases and the independent annotation oracle belong in the existing integration suite.
The root Makefile retires the old WooCommerce test runner.
The shared runtime script and compatibility workflow cover WooCommerce 11.2.2.
The inventory and release acceptance documents retain dated evidence.
The WordPress changeset records the public tool-name change.

No live maintenance action, deployment, publication, or OpenAI submission follows from this plan.
The reviewer-login and package-validator changes belong to PR #2167.
PR #2175 also contains the synthetic WordPress provisioning scripts.
Those scripts are not part of the maintenance executor.

## Test migration

The deleted `WooCommerceToolsTest.php` contained 501 lines of substitute dependencies and assertions.
Its meaningful contracts must remain covered by the shared real-runtime suite:

- Complete tool inventory and valid serialized object and array schemas.
- Product filters, pagination, and exact forwarding of raw request data.
- Native REST persistence parity, rather than assumptions about upstream sanitization.
- GET-before-PUT updates, string gateway IDs, and product-review filtering.
- Missing, false, and wrong-typed confirmation with unchanged persisted state.
- Metadata upsert, deletion, and native readback.

Maintenance cases must cover fixed descriptors, confirmation, extra-argument rejection, and capability denial.
They must also cover disabled actions, discovery without effects, and explicit extension metadata.
Native failure conversion, removed actions, name collisions, and transport parity need acceptance evidence.
The presence of test source does not establish that those cases passed.
No test doubles, separate bootstrap, or feature-specific test target replaces the unified suite.

The original code budget required more deleted lines than added lines.
Do not remove meaningful coverage or compress code to meet that budget.
Report production and test totals separately.
Documentation and generated files do not count toward the code budget.

## Acceptance commands

Run the WordPress targets sequentially because they share package output:

```sh
make test-wordpress-runtime
FRONTMAN_REQUIRE_WP_SDK=1 make test-wordpress-runtime
make test-wordpress-core-tools
make check-source-comments
git diff --check
```

Use a unique `MIX_TEST_DB_SUFFIX` for each independent hosted run.
Do not reset existing developer databases.
Run the compatibility workflow, including its pinned WooCommerce 11.2.2 row.
Use actual WordPress, WooCommerce, and browser dependencies.

## Evidence and limits

The pre-change WordPress baseline passed on WordPress 7.0.2, PHP 8.4.27, and WooCommerce 10.4.3.
Its SDK-required run passed both hosted phases, then lacked Playwright headless shell revision 1248.
That baseline does not certify the changed implementation.

PHP lint, shell syntax, source-comment checks, and whitespace checks passed.
The changed-code local runtime attempt exceeded its 200-second command limit before the tests.
MariaDB failed with error 28. The Docker filesystem reported 100% usage and 3 MB available.
Only that attempt's containers, network, and image were deleted.
The local core-tool target failed an unchanged public-root assertion on this Mac.

Seven CI configurations reached the new WooCommerce cases and failed the raw-description persistence assertion.
The revised test observes exact forwarding and compares persistence against a direct native REST call.
The revised test and all later cases passed in seven WooCommerce-enabled configurations.
The complete [compatibility run](https://github.com/frontman-ai/frontman/actions/runs/42855697332) passed all eight jobs at `694860a5`.
Six rows used WooCommerce 10.4.3, and one used WooCommerce 11.2.2.
The oldest WordPress row passed without WooCommerce.
Both SDK-required rows passed their hosted phases and embedded browser acceptance.
This CI evidence does not change the failed local Docker and public-root results.
No production maintenance action or OpenAI rescan occurred.

## Release gate

Require successful changed-code compatibility, hosted SDK, and browser acceptance before landing.
Confirm equivalent coverage before accepting deletion of the old runner.
After an authorized deployment, upgrade every reviewer-connected site before the OpenAI rescan.
An old connected site can reintroduce the retired tools through the hosted catalog union.
OpenAI acceptance remains external to the local and CI checks.
Stop if hidden inputs, incorrect annotations, or missing coverage require a scope decision.
