---
title: 'Run Lighthouse Audits Inside Frontman'
pubDate: 2026-02-21T05:00:00Z
description: 'Use Frontman’s Lighthouse tool to capture repeatable performance, accessibility, best-practices, and SEO findings, then verify focused fixes.'
author: 'Danni Friedland'
image: '/blog/lighthouse-audits-cover.png'
imageAlt: 'Lighthouse audits inside Frontman'
articleSection: 'Product Announcement'
tags: ['performance', 'ai', 'developer-tools']
updatedDate: 2026-07-30T00:00:00Z
---

Frontman includes a `lighthouse` tool for auditing a URL from the same agent session used to inspect and edit a project. It does not replace Lighthouse or guarantee a higher score. It gives the agent a structured subset of a Lighthouse run so measurement and code changes can happen in one reviewable workflow.

Google describes [Lighthouse](https://developer.chrome.com/docs/lighthouse/overview) as an automated tool for performance, accessibility, SEO, and other page-quality audits. Lighthouse findings are indicators: each failed audit still needs investigation, an appropriate fix, and another measurement.

## What Frontman actually runs

The implementation in [`FrontmanCore__Tool__Lighthouse.res`](https://github.com/frontman-ai/frontman/blob/main/libs/frontman-core/src/tools/FrontmanCore__Tool__Lighthouse.res) does the following:

1. Launches an installed Chrome instance with `chrome-launcher`.
2. Runs Lighthouse for performance, accessibility, best practices, and SEO.
3. Accepts an explicit `desktop` or `mobile` preset; `desktop` is the default.
4. Returns each category score from 0 to 100.
5. Returns up to three lowest-scoring issues per category.
6. Includes issue IDs, titles, descriptions, display values, and up to three selectors, HTML snippets, resource URLs, or source locations when Lighthouse supplies them.
7. Returns Lighthouse warnings and the audit fetch time.

The integration packages include Lighthouse and `chrome-launcher`, so a separate global Lighthouse install is not required. Chrome itself must be installed, and the target URL must be reachable from the machine running the framework integration.

The audit launches a separate headless Chrome instance. It does not inherit cookies, local storage, or authentication from the Frontman preview browser. Frontman's current Lighthouse input accepts only a URL and preset; it does not provide an authentication strategy. Do not assume that signing in to the preview makes an authenticated route auditable, and do not weaken application authentication to make an audit pass.

## Reproducible audit workflow

Use a fixed URL, preset, application state, and code revision. Otherwise, before-and-after scores are not comparable.

1. Start the application in a deterministic state. Use a URL that the separate headless Chrome instance can access without relying on the preview's authenticated session.
2. Record the current commit or working-tree state.
3. Ask Frontman: `Run Lighthouse on http://localhost:3000/ with the mobile preset. Report the fetch time, four category scores, warnings, and issue IDs. Do not edit files yet.`
4. Save the returned baseline in the task or your PR notes.
5. Pick one reported issue. Ask the agent to inspect the supplied selector, snippet, resource URL, or source location and propose the smallest fix.
6. Review the diff and confirm the page still behaves correctly.
7. Re-run the same URL and preset from the same application state.
8. Compare the specific audit result as well as category scores. Revert the change if it causes a regression elsewhere.

For a desktop comparison, repeat the process with `preset: "desktop"`. Frontman's current tool description tells the agent to consider active device emulation, but the tool input still has an explicit preset. State it in the prompt when reproducibility matters.

## Output shape, not benchmark data

Actual values depend on your page and run. Frontman returns structured data with this shape; placeholders below are intentionally not claimed results:

```text
URL: <audited URL>
Fetch time: <timestamp from Lighthouse>
Warnings: <warnings from this run>

Performance: <0-100 score from this run>
  - <issue ID>: <title>
    <display value, selector, snippet, URL, or source location when available>

Accessibility: <0-100 score from this run>
Best Practices: <0-100 score from this run>
SEO: <0-100 score from this run>
```

Only three failing issues per category are returned. Fixing one can expose another that was previously ranked lower, so absence from Frontman's summary does not mean an audit passed.

## How to interpret results

Lighthouse is a lab test, not a measurement of every real user's experience. Scores can move because of machine load, network conditions, page state, Chrome or Lighthouse versions, third-party requests, and application changes. Run multiple times when a small score difference matters, and use field data where available for production decisions.

Also preserve category boundaries:

- A performance recommendation is not automatically a safe code change.
- An automated accessibility pass does not replace keyboard, screen-reader, or other manual testing.
- SEO audits cover a defined set of checks, not indexing or ranking guarantees.
- Best-practices findings still require security and compatibility review.

Frontman's advantage is operational: the agent receives the measured issue and any element or resource detail Lighthouse provides, can inspect the related source through the framework integration, and can run the audit again after a reviewed edit. The agent may still choose the wrong fix, and the score may still vary.

See [Tool Capabilities](/docs/using/tool-capabilities/#lighthouse) for the current Frontman interface and Google's [Lighthouse documentation](https://developer.chrome.com/docs/lighthouse/overview) for audit methodology.
