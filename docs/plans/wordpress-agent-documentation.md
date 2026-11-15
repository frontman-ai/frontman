# WordPress agent documentation: evidence and delivery record

Research date: 2026-11-15 UTC. Implementation baseline: `e87074a5`.
This file is a team research record, not a published compatibility guarantee.

## First delivery

- Added `/docs/wordpress/connect-agent/`: shared site authorization, remote MCP details and a first read-only request.
- Added `/docs/wordpress/permissions/`: credential boundaries, live writes, disabling MCP and credential revocation.
- Added `/docs/wordpress/troubleshooting/`: missing sites, entitlement, Application Passwords and authentication failures.
- Added navigation, Markdown discovery and rendered-output coverage.
- Corrected stale paid-only claims in the ChatGPT page, authentication reference and MCP comparison article.
- No live assistant connection or WordPress mutation was performed for this delivery.

## Complete article delivery

All remaining public articles are now written, linked from the sidebar and contextual hubs, and included in Markdown discovery.

- Interface choice: `/docs/wordpress/choose-interface/`, with embedded-editor and hosted-MCP setup paths.
- Content procedures: `/docs/wordpress/posts-and-pages/`, `/gutenberg/`, and `/elementor/`.
- Other shared editing procedures: `/docs/wordpress/woocommerce-products/` and `/seo-metadata/`.
- Hosted connection management: `/docs/wordpress/multiple-sites/`.
- Client reference and guides: `/docs/wordpress/agents/`, `/chatgpt/`, `/claude/`, `/dots/`, `/muse/`, and `/instinct/`.
- Review and corrective recovery: `/docs/wordpress/recovery/`.
- Assistant disconnection and WordPress credential revocation remain together in `/docs/wordpress/permissions/`.

The shorter sibling paths in these lists are relative to `/docs/wordpress/`.
Workflow examples describe current code contracts, not newly observed live executions.
ChatGPT and Claude guides use current vendor-documented custom-server flows.
Dots, Muse and Instinct articles explain their distinct documented access, unresolved connection paths, and safe validation requirements.
Those pages do not invent missing setup controls or claim tested compatibility.
Live OAuth acceptance and real-site workflow execution remain unperformed, not unwritten documentation.

## Interface-first hierarchy

The WordPress sidebar separates Overview & Installation, Choose Your Editing Interface, MCP Connections, Editing Workflows, and Review & Recovery.
The five shared editing guides begin with either interface, not an unconditional MCP prerequisite.
Hosted-only examples identify `site_id` and `list_sites`; embedded-editor instructions use the current installation and advertised local arguments.
Multiple connected sites, client guides, compatibility, permissions and connection troubleshooting remain in the MCP branch.
Existing URLs are unchanged. The interface-choice article is the only additional route in this restructuring.

## Product facts

| Fact | Current implementation evidence | Evidence limit |
| --- | --- | --- |
| Active subscriptions and eligible subscription trials grant hosted MCP access | [MCP gate](../../apps/frontman_server/lib/frontman_server_web/mcp/server.ex#L24-L36), [entitlement cases](../../apps/frontman_server/test/frontman_server_web/mcp_sites_test.exs#L600-L688) | Source and existing tests inspected, not rerun here |
| A trial with `cancel_at` or `canceled_at` does not grant access | [Subscription rule](../../apps/frontman_server/lib/frontman_server/billing/subscription.ex#L42-L55) | Not a new billing policy |
| Site discovery is account-scoped; site tools use `site_id` | [Discovery](../../apps/frontman_server/lib/frontman_server_web/mcp/server.ex#L115-L136), [site selector](../../apps/frontman_server/lib/frontman_server_web/mcp/server.ex#L253-L267) | Multiple installations do not establish Multisite support |
| OAuth authorizes the assistant; an Application Password authorizes site requests | [Server requests](../../apps/frontman_server/lib/frontman_server/wordpress.ex#L240-L283), [credential reference](../../apps/marketing/src/pages/auth.md.ts#L130-L139) | Not interchangeable credentials |
| Disabling MCP retains the saved connection and does not revoke the password | [Connection card](../../libs/client/src/Client__WordPressConnectionCard.res#L38-L77), [revocation coverage](../../libs/frontman-wordpress/tests/integration/CoreRuntimeCases.php#L243-L256) | Not complete credential revocation |
| Hosted WordPress tools do not need the embedded editor tab | [Independent REST execution](../../libs/frontman-wordpress/tests/integration/CoreRuntimeCases.php#L292-L312) | Does not supply browser-preview tools to external assistants |

The older paid-only copy was wrong for this baseline.
Do not infer current product behavior from earlier release notes or investigation threads.

## Agent landscape

These are the strongest product candidates, not confirmation of the requester's intended vendors.
No named client has a new end-to-end Frontman acceptance result from this research.

| Candidate | Primary sources | Finding | Remaining live validation |
| --- | --- | --- | --- |
| ChatGPT | [Custom MCP connections](https://help.openai.com/en/articles/12584461-connecting-custom-mcp-servers-in-chatgpt), [OAuth](https://developers.openai.com/plugins/build/auth.md) | Remote MCP and OAuth documented; workspace permissions and plan restrictions apply | Run exact current client flow with Frontman and record account/plan, date and results |
| Claude | [Custom connectors](https://claude.com/docs/connectors/custom/add-unlisted.md), [authentication](https://claude.com/docs/connectors/building/authentication.md) | Remote MCP and OAuth documented; not the same as an Anthropic model-provider connection | Run Frontman authorization, site discovery and a harmless read |
| OpenAI dots | [Product](https://openai.com/index/introducing-dots/), [getting started](https://help.openai.com/en/articles/20001530-getting-started-with-your-dot) | General-purpose agents use connected ChatGPT apps; this does not prove arbitrary custom MCP availability to a dot | Confirm intended product and dot-specific plugin access, then run the Frontman flow |
| Meta Muse | [Product](https://muse.ai/), [connector guidelines](https://platform.muse.ai/docs) | Platform accepts API/MCP documentation and reviews connectors; submission is not proof of a self-service custom-server flow | Confirm consumer connector route and OAuth support before drafting setup steps |
| Instinct personal assistant | [Product](https://instinct.com/), [vendor/privacy](https://instinct.com/privacy-policy) | Spear Street Technology's assistant; no public custom-MCP setup specification located | Obtain official connection instructions before a Frontman guide |

Muse is ambiguous: [Fregio's agents page](https://fregio.ai/agents) was indexed as Muse but currently calls its WordPress agent Fregio Pilot.
[Muse Code](https://dev.meta.ai/docs/muse-code/extending) is another surface with explicit remote MCP support.
Do not apply Muse Code instructions to the Muse personal-agent app.
[Instinct MCP](https://mcp.mspmcp.com/docs) is an unrelated MSP data server, not proof of the personal assistant's capabilities.
Failure to locate public instructions does not prove that a capability is absent.

For OAuth instructions, use current vendor documentation rather than a universal hardcoded callback URL.
ChatGPT's current documentation distinguishes callback-specific redirects from stable redirects.
Claude's hosted connector and Claude Code have different callback requirements.

## Search evidence and keyword ownership

Read-only Search Console queries used the existing team connection for `sc-domain:frontman.sh`.
Window: 2026-10-16 through 2026-11-12, finalized Web data, dimensions `query,page`.
The broad query filtered WordPress/MCP/agent terms and returned at most 60 rows.
A second query filtered agent-plus-WordPress and setup phrases, plus WooCommerce MCP, with a 100-row limit.
These bounded results are not complete site totals, market search volume or evidence of zero demand for absent terms.
Private traffic metrics and raw responses are not committed.

Observed queries included `wordpress mcp plugin`, `wordpress mcp server`, `mcp wordpress plugin` and `best woocommerce mcp server`.
The existing MCP comparison article receives these queries.
Keep selection intent there and link to setup documentation rather than duplicate the ranking.
All other keyword phrases below remain hypotheses until demand/SERP research.

| Reader intent / seed phrases | Canonical target or next action | Status |
| --- | --- | --- |
| Connect AI agent to WordPress; WordPress MCP setup | `/docs/wordpress/connect-agent/` | Added |
| WordPress MCP permissions; revoke Application Password | `/docs/wordpress/permissions/` | Added; separate disconnection article only if procedures outgrow this page |
| WordPress MCP not working; no connected sites | `/docs/wordpress/troubleshooting/` | Added |
| Supported WordPress MCP clients | `/docs/wordpress/agents/` | Written evidence-level matrix; live client acceptance remains unverified |
| Connect ChatGPT / Claude to WordPress | `/docs/wordpress/chatgpt/`, `/claude/` | Written from vendor documentation; live acceptance not performed |
| Dots / Muse / Instinct WordPress integration | `/docs/wordpress/dots/`, `/muse/`, `/instinct/` | Vendor-qualified access and limitation guides written; no invented connection flow |
| Edit WordPress pages with AI | `/docs/wordpress/posts-and-pages/` | Written: draft creation, hash-guarded dry run, save and readback |
| Edit Elementor with AI; Elementor MCP | `/docs/wordpress/elementor/` | Written: one widget, saved readback, snapshot scope and cache effects |
| Edit Gutenberg blocks with AI | `/docs/wordpress/gutenberg/` | Written: nested path selection and surrounding-tree preservation |
| WooCommerce MCP; update product descriptions with AI | `/docs/wordpress/woocommerce-products/` | Written: one staging product description; no money-moving exercise |
| Update WordPress SEO titles / meta descriptions with AI | `/docs/wordpress/seo-metadata/` | Written: provider/target detection, stored values and public HTML |
| Manage multiple WordPress sites with AI | `/docs/wordpress/multiple-sites/` | Written: connection identity, same-host ambiguity and one-site write scope |
| Undo AI changes in WordPress | `/docs/wordpress/recovery/` | Written: review, uncertain outcomes and surface-specific corrective procedures |

## Remaining live acceptance

1. Select the exact agent product and client surface.
2. Record client version, plan, date, Frontman candidate and disposable WordPress environment.
3. Complete OAuth, `list_sites` and a site-information read without publishing secrets.
4. Record expected and observed results, including wrong-account and empty-site behavior.
5. For mutation guides, use disposable records and inspect persisted and rendered results.
6. Have another person complete the procedure without undocumented assistance.
7. Run marketing tests, production build and rendered-output tests.

Research used public vendor pages and read-only Search Console access.
The agent-landscape search used 14 bounded routed searches at $0.00 total.
Keyword volume, authenticated client UI screenshots and live OAuth acceptance remain outstanding.
They do not change the written guides' explicit source-review and unverified-integration labels.

## Local validation

- `make -C apps/marketing test`: 114 tests passed.
- `make -C libs/frontman-astro build`: passed; required because the local integration bundle was absent.
- `make -C apps/marketing test-rendered`: production build, internal link check and 15 rendered-output tests passed after the hierarchy adjustment.
- All 17 WordPress documentation routes returned HTTP 200 from the local development server.
- Technical review compared the seven new workflow/recovery guides with code and the six client/reference pages with primary sources.
- Corrected the Elementor CSS-cache scope description: a supplied post ID does not guarantee isolated cache clearing.
- JSDOM reports CSS parser warnings for Starlight styles; the HTML/Markdown assertions passed.
- `git diff --check`: passed.

The [internal-link audit](wordpress-internal-link-audit.md) records the subsequent blog/docs reader-path changes and before/after measurements.
