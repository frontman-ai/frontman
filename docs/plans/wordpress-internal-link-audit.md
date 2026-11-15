# WordPress docs and blog: internal-link audit

Audit date: 2026-11-15 UTC.
The baseline includes the preceding, uncommitted three-guide documentation delivery, not only Git HEAD.
This report records that cross-link pass before the subsequent workflow and named-agent article delivery.
Its 80-page corpus and before/after measurements are historical, not current site totals.

## Scope and method

- Inventoried all 52 blog articles and 28 documentation pages.
- Reviewed WordPress, agent/MCP, Elementor, themes/builders, performance, maintenance and security reader paths.
- Parsed production HTML before and after the changes.
- Counted editorial anchors only inside `.post-body` and `.sl-markdown-content`.
- Excluded navigation, sidebars, pagination and generated related-post cards from contextual metrics.
- Counted distinct source pages, not repeated anchors, for incoming-link totals.
- Measured contextual depth from `/docs/` separately from homepage crawl depth with navigation.
- Checked same-origin HTML fragments against rendered IDs. Markdown endpoints and assets are outside this HTML graph.

These are local content-structure measurements, not Google rankings or a live-site crawl.
The prior Search Console sample showed WordPress MCP selection queries reaching the MCP comparison article.
This pass used that evidence for priority, not as market search volume. No new traffic query or volume lookup ran.

## Results

| Measurement | Before | After |
| --- | --- | --- |
| Distinct non-self contextual source/HTML-destination pairs | 457 | 479 |
| Incoming editorial source pages: agent connection guide | 4 | 10 |
| Incoming editorial source pages: permissions guide | 3 | 8 |
| Incoming editorial source pages: MCP troubleshooting | 3 | 5 |
| Posts without incoming editorial links | 5 | 1 |
| Contextual depth: docs → header/footer tutorial | 3 | 2 |
| Contextual depth: docs → mobile-layout tutorial | 4 | 2 |
| Contextual depth: docs → Elementor performance tutorial | 3 | 2 |
| Broken same-origin HTML fragments | 0 | 0 |

Across 22 article/doc sources, 39 contextual anchors were added or retargeted and seven old anchors were replaced.
The net increase is 22 distinct source/destination pairs, not 39 new destinations.
The ChatGPT landing page also gained setup and read-only-check links; it is outside the 80-page corpus.

The themes, visual-builders, scroll-video and OpenClaw articles now have incoming editorial links.
They were not true crawl orphans: each already had a two-click homepage path through generated/navigation links.
Their homepage crawl depth remains two. Do not describe this change as a crawl-depth or ranking improvement.

## Reader-path changes

Paths in this table are public routes. Each link sits beside the corresponding decision or instruction.

| Source / reader need | Destination / ownership |
| --- | --- |
| AI-plugin and agent comparisons: connect an external assistant | `/docs/wordpress/connect-agent/`; hosted route explicitly separate from editor demos |
| MCP comparison: grant or stop site access | `/docs/wordpress/permissions/#wordpress-permissions`; existing setup link retained without duplication |
| Maintenance checklist: retire a connection | `/docs/wordpress/permissions/#revoke-the-wordpress-credential` |
| Security article: understand hosted authentication | `/docs/wordpress/permissions/`; cookie/nonce paragraph explicitly scoped to the embedded route |
| Installation, API keys and agent-loop/architecture docs | Hosted setup branch instead of an unconditional provider-key/browser-preview path |
| General troubleshooting and reference index | `/docs/wordpress/troubleshooting/`; editor failures stay in the existing general guide |
| ChatGPT landing setup and first task | Shared setup guide and `#3-check-access-without-edits`; interactive verification link retained |
| Agent comparison, header/footer tutorial and customer case study | `/docs/integrations/wordpress/#use-the-frontman-editor`; no retrospective hosted-MCP claim |
| Mobile, Astra, themes and visual-builder articles | Capability or recovery fragments rather than generic docs/matrix destinations |
| Scroll-video tutorial | Actual installation, current capability and snapshot-restoration sections instead of the homepage |
| WordPress integration guide | Header/footer, mobile-layout and Elementor-performance guides matched to the reader's problem |
| Broad AI-plugin comparison → visual-builder comparison | Distinguishes generation, drag-and-drop design and AI-assisted editing |
| Astra guide → small-business theme comparison | Conditional route for readers who have not chosen their theme |
| Elementor performance → scroll-video tutorial | Interaction/reduced-motion reference, explicitly not evidence of faster loading |
| Lighthouse article → Elementor performance diagnosis | External-test alternative; no claim that WordPress exposes the Lighthouse tool |
| JavaScript installation → OpenClaw skill article | Browser-mediated workspace handoff, not hosted WordPress MCP compatibility |

The original regression test recorded 22 representative source/destination journeys, later expanded to 26.
Test cleanup removed that editorial-link matrix and the tool-name, fixed-date and generic prose assertions.
Current automated coverage checks built-page discovery, HTML/Markdown delivery, interface grouping and the corrected confirmation rule.
The contextual source/destination matrix remains an editorial audit record, not a permanent test specification.
The topic-ownership table in `apps/marketing/writing-style.md` now separates installation/editor, hosted setup, permissions and connection failures.

## Deliberate boundaries and follow-ups

- No redirects, page mergers, competitor-rank changes, keyword stuffing or new named-agent compatibility claims.
- Existing announcements retain dated launch evidence; current installation intent now points to documentation.
- `gpt-5.4-support` remains without incoming editorial links. It is a historical announcement, not a current model recommendation.
- `/docs/guides/` remains an intentionally noindexed moved-section notice.
- Cline/Roo, Puppeteer/Claude Code and WebMCP articles do not gain unrelated hosted-WordPress links.
- At this audit baseline, the shared workflow articles did not exist. The [complete article delivery](wordpress-agent-documentation.md#complete-article-delivery) now records those guides and their contextual links.
- The new SEO metadata guide owns the workflow; the tool reference retains technical browser/tool details. Lighthouse SEO scores are not a substitute for WordPress metadata instructions.
- Resolved the WooCommerce confirmation discrepancy against the implementation: the integration guide overstated the gate.
  The [endpoint registration rule](../../libs/frontman-wordpress/tools/class-tool-woocommerce.php#L516-L525) adds confirmation to `PUT`/`DELETE`; [metadata writers](../../libs/frontman-wordpress/tools/class-tool-woocommerce.php#L550-L578) declare it separately.
  The guide now distinguishes those writes from `POST` creates and separates client approval prompts from plugin enforcement. Tool behavior is unchanged.
- The new links do not establish live assistant compatibility, successful edits, universal preview approval or universal rollback.

## Validation

- `make -C apps/marketing test`: 114 tests passed.
- `make -C apps/marketing test-rendered`: production build, internal link checker and 11 rendered-output tests passed.
- Full rendered same-origin HTML fragment scan: no unresolved fragments.
- JSDOM reports CSS parser warnings for Starlight styles; content assertions pass.
- `git diff --check`: passed.
