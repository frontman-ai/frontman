# Claude WordPress acceptance record

As of 2026-11-12, acceptance is incomplete. This record contains no credentials.
The [submission runbook](claude-wordpress-submission.md) gives the operator procedure.
The user selected the full current catalog. No Claude-specific tool filter is selected.

## Evidence

| Claude requirement and documentation | Source path and line | Observation or evidence | Status | Next action |
| --- | --- | --- | --- | --- |
| [Discovery and OAuth](https://claude.com/docs/connectors/building/authentication) | [`mcp.ex:10`](../apps/frontman_server/lib/frontman_server_web/mcp.ex#L10), [`workos_token.ex:9`](../apps/frontman_server/lib/frontman_server_web/mcp/workos_token.ex#L9) | On 2026-11-12 at about 10:16 UTC, the parent received `401` from the canonical endpoint with a protected-resource metadata pointer. Both root and `/mcp` metadata returned `200` and the exact canonical resource. The first configured WorkOS issuer's RFC 8414 document returned `200`, with CIMD support, `none`, a registration endpoint, S256, authorization code, refresh token, and `offline_access`. OIDC discovery also returned `200`, with S256 and refresh support but no CIMD or DCR fields. | Public discovery passed only | Run actual Claude authorization and refresh. RFC 8414 availability prevents treating the OIDC omission as failure. |
| [Real client test](https://claude.com/docs/connectors/building/testing) | [Onboarding:4](../apps/frontman_server/lib/frontman_server/wordpress/onboarding.ex#L4), [handoff:4](../apps/frontman_server/lib/frontman_server_web/controllers/connect_handoff_controller.ex#L4) | No authenticated Claude client was available. Registration, sign-in, callback, token exchange, reconnect, and refresh were not run. | Not run | Connect the synthetic account in Claude and record the result. |
| [Tools and annotations](https://claude.com/docs/connectors/building/review-criteria) | [`server.ex:74`](../apps/frontman_server/lib/frontman_server_web/mcp/server.ex#L74), [`server.ex:313`](../apps/frontman_server/lib/frontman_server_web/mcp/server.ex#L313) | Current source supplies server-tool annotations and copies remote descriptors. The authenticated remote catalog and its titles were not read in this probe. | Incomplete | Inspect every exposed tool and its actual effects. Record a complete per-tool ledger. |
| [Separate financial restriction](https://claude.com/docs/connectors/building/review-criteria) | [WooCommerce refund fields:243](../libs/frontman-wordpress/tools/class-tool-woocommerce.php#L243) | The review criteria exclude financial-asset transfers. Refund creation can request a gateway refund. The rule's application to this catalog is not established by local tests. | Review question | Record the actual review outcome. Do not run live payment or refund tests. |
| [Accurate tool behavior](https://claude.com/docs/connectors/building/review-criteria) | [`catalog_tools:275`](../apps/frontman_server/lib/frontman_server_web/mcp/server.ex#L275), [`discovery_connections:191`](../apps/frontman_server/lib/frontman_server_web/mcp/server.ex#L191) | Same-name tools with compatible input schemas use one site's descriptor. Metadata differences can misrepresent another site's behavior. Calls discover the selected site. | Code risk | Characterize differing site metadata and assess the result. No particular merge algorithm is a documented Claude requirement. |
| [Populated reviewer account](https://claude.com/docs/connectors/building/testing) | [Onboarding:4](../apps/frontman_server/lib/frontman_server/wordpress/onboarding.ex#L4) | The production reviewer account exists, with its password in the private vault. Its synthetic WordPress connection returned 205 tools and a successful site-information read. A fresh password login succeeded through the existing embedded flow. Stripe and the authenticated billing API both report an active subscription. | Account and subscription provisioned | Deploy the password-form UI with authorization. Complete browser and Claude access tests, then enter credentials privately in the portal. |
| [Plugin validation](https://claude.com/docs/plugins/submit) | [Bundle README:49](../plugins/claude-wordpress/README.md#L49), [Makefile:3](../plugins/claude-wordpress/Makefile#L3) | W3 local `check test package`, root check, and root package passed with official Claude Code `2.1.311`. The version tests passed. The isolated `file://` marketplace update was rejected, not counted as an update pass. | Local pass, update pending | Repeat for the final candidate and exercise a supported Git source. |
| [Directory submission](https://claude.com/docs/directory/publish) | [Bundle README:3](../plugins/claude-wordpress/README.md#L3), [manifest](../plugins/claude-wordpress/.claude-plugin/plugin.json) | Connector and plugin portal actions, credentials, and publication were not run. | Not run | After authorization and evidence, submit both from the same owning organization. |

The public discovery samples do not prove an OAuth latency service level or reachability
from Anthropic's network. They did not register a client or exchange tokens.

## Reviewer provisioning

On 2026-11-12, the operator authorized the production reviewer account and a complimentary Stripe subscription.
The subscription uses the existing monthly Frontman Pro price and a product-restricted 100% discount with no expiry.
The discount permits one redemption. Stripe Tax is off for this subscription, as the operator requested.
The initial draft invoice has a total and amount due of EUR 0, with no payment attempt.
The customer has no payment method. The subscription uses `send_invoice`, not automatic charging.

The authenticated Frontman billing API reports `status: active`, `has_billing_customer: true`, and `can_start_turn: true`.
No billing rows were inserted manually. The temporary verification token was revoked after the access test.
The production site catalog has all four safety hints but lacks titles.
The password-form UI and title changes remain undeployed. No deployment or Claude authorization occurred during provisioning.

## Separate local baseline

The prior thread [Install Playwright Chromium and rerun runtime tests](delta://thread/ksQQ5FxKybThRAm6QmEs2fraeJLOAHq0zJIBxBDwx7Dr2uVGa58ABQAehaYJ)
recorded a successful full required runtime baseline.
It used WordPress `7.0.2`, PHP `8.4.27`, and WooCommerce `10.4.3`.
Both hosted SDK phases passed three cases each, and the real browser fixture passed.
The earlier [release acceptance](wordpress-mcp-release-acceptance.md) documents runtime procedures and limitations, not this newer run.
This baseline is not evidence of Claude OAuth or the current deployed candidate.

The Claude bundle CI workflow is configured but has not run.
The full exposed-tool ledger, actual Claude workflow, two-account isolation, reviewer browser access,
portal validation, and hosted OAuth remain open.
No claim of submission, approval, or publication follows from local checks.

## Candidate evidence to add

Record the date, client surface and version, source commit, bundle version and checksum,
server deployment, WordPress artifact checksum, integration versions, case, result,
and sanitized evidence reference for each future run.
Compare the tested and final artifacts and relevant configuration.
Repeat affected cases after a material change.
Do not store private hosts, account details, tokens, credentials, or tool output here.
