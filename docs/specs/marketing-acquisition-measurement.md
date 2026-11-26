# Marketing acquisition measurement

## Scope

GA4 measures consented activity on `frontman.sh`, including articles and documentation.
Localhost, preview hosts, and other domains do not load the Google Analytics script.
An analytics choice on the marketing site does not authorize collection in a customer installation.

## Funnel definitions

| Stage | Evidence | Interpretation |
| --- | --- | --- |
| Article visit | Consented `page_view` on an article | An observed visit, not all search traffic |
| Setup intent | Article CTA, plugin-directory click, or instruction copy | Interest in setup, not installation |
| Installation | Successful installation with dependencies and configuration present, or WordPress plugin activation | Product-side evidence, not currently a marketing GA4 event |
| Activation | First successful user-requested edit with a recorded change | Product-side outcome, not currently a marketing GA4 event |

`install_intent` records a successful command or manual-instruction copy.
`copy_agent_install_instructions` records a successful agent-instruction copy.
Before this change, the agent-copy event recorded clicks, including failed copy attempts.
Neither event proves that the user ran the instructions.
Their counts can overlap and do not represent unique installations.

## Product boundaries

Next.js and Vite installers return success for dry runs and exit successfully after partial setup.
An exit code alone does not prove installation.
Astro uses its integration installation path.
WordPress records plugin activation locally through `Frontman_UI.activate`.
That marker is not an analytics event.

The client sends `relay_connection_completed` to Heap.
A successful relay connection does not prove ACP readiness or a successful edit.
An assistant response without a recorded change does not meet the activation definition.

Marketing and product outcomes remain separate.
This change adds no product events, identifiers, attribution tokens, or cross-domain links.
It does not calculate article-to-activation conversion rates.
Any future product collection requires a separate consent, retention, and deduplication decision.

## Interpretation rules

- Search Console clicks and consent-gated GA4 sessions have different denominators.
- Missing visits before analytics consent are expected.
- Events before consent or after revocation are not replayed after acceptance.
- A GA4 `(not set)` landing page requires investigation of missing page views.
- Aggregate reports alone do not identify the cause of a missing page view.
- Additional unconditional page views can create duplicates and are not a justified repair.
- A contact-page view does not prove a submitted lead.
- External event rules and key-event configuration require separate authorization.

Raw connected reports and private audit artifacts do not belong in this repository.

## Validation

Run `make -C apps/marketing test`.
Run `make -C apps/marketing test-rendered`.

The rendered tests exercise the production HTML with the real consent runtime.
They use an isolated DOM and a controlled clipboard response.
They inspect GA4 commands without downloading Google scripts or sending analytics events.
They do not establish delivery to GA4.
