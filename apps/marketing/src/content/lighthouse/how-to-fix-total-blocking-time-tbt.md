---
title: "How to Fix Total Blocking Time (TBT)"
description: "Total Blocking Time measures how long the main thread is blocked during page load. Learn how to identify long tasks and reduce TBT below the 200 ms threshold."
pubDate: 2026-03-10T00:00:00Z
auditId: "total-blocking-time"
category: "performance"
weight: 30
faq:
  - question: "What is a good TBT score?"
    answer: "Lighthouse considers TBT good at 200 ms or less. Between 200 ms and 600 ms needs improvement. Above 600 ms is poor. TBT has the highest weight (30) in the Lighthouse Performance score."
  - question: "What is the difference between TBT and TTI?"
    answer: "Total Blocking Time measures the total duration of long tasks (portions over 50 ms each) between FCP and TTI. Time to Interactive measures when the page becomes reliably interactive. TBT quantifies how bad the blocking is during that window."
  - question: "Does TBT affect Core Web Vitals?"
    answer: "TBT is not a Core Web Vital itself, but it correlates strongly with Interaction to Next Paint (INP), which is a Core Web Vital. Reducing TBT generally improves INP as well."
  - question: "Can Frontman fix TBT issues automatically?"
    answer: "Yes. Tell Frontman to fix your Lighthouse issues and it handles the rest. It runs the audit, fixes the code, and re-runs the audit to check the score improved — iterating until the metrics pass."
---

## What Lighthouse Is Telling You

When Lighthouse flags [Total Blocking Time](https://web.dev/articles/tbt), it means JavaScript tasks on the main thread are running too long during page load. TBT carries a **weight of 30** — the heaviest single metric in the Lighthouse Performance score. It measures the total milliseconds where the main thread was blocked by long tasks between [First Contentful Paint](/lighthouse/how-to-fix-first-contentful-paint-fcp/) and Time to Interactive.

A "long task" is any JavaScript execution that takes more than 50 ms. TBT sums the *blocking portion* of each long task — the time beyond 50 ms. A task that runs for 120 ms contributes 70 ms to TBT.

## Why TBT Is High

- **Large JavaScript bundles** — Parsing and executing a 500 KB bundle blocks the main thread for hundreds of milliseconds
- **Third-party scripts** — Analytics, ad networks, chat widgets, and tag managers each add their own long tasks
- **Synchronous rendering** — React hydration on a complex component tree can produce a single long task that blocks the thread for 200+ ms
- **No code splitting** — Loading the entire application JavaScript on every page instead of splitting by route
- **Heavy computations on load** — Data processing, sorting large arrays, or building complex data structures during initial render

## The Old Way to Fix It

1. Run Lighthouse in DevTools and find the TBT score
2. Open the Performance panel and record a page load
3. Look for long tasks (highlighted with red corners) in the flame chart
4. Click each long task to identify which script and function is responsible
5. Switch to your editor, find the script
6. Refactor: split large bundles with dynamic `import()`, defer non-critical scripts, move heavy computation to a Web Worker
7. Re-run Lighthouse and check TBT
8. Repeat for each long task

Debugging TBT requires correlating flame chart entries with source files, which is tedious when third-party scripts and framework internals are intermixed with application code.

## The Frontman Way

Tell Frontman to fix your Lighthouse issues. That is the entire workflow.

Frontman has a built-in Lighthouse tool. It runs the audit, reads the failing scores, fixes the underlying code, and re-runs the audit to verify the score went up. If issues remain, it keeps going — iterating through fixes and re-checks until the metrics pass. You do not spelunk flame charts or correlate long tasks with source files. You say "fix the Lighthouse issues on this page" and Frontman handles the rest.

## Key Fixes for TBT

- **Defer non-critical JavaScript** — Add `defer` or `async` to `<script>` tags that are not needed for initial render
- **Code split by route** — Use dynamic [`import()`](https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Operators/import) to load page-specific code only when needed. Frameworks like Next.js and Vite do this by default for routes, but component-level splitting often requires manual setup
- **Remove [unused JavaScript](/lighthouse/how-to-fix-unused-javascript/)** — Audit your bundle with source maps and remove dead code
- **Move heavy work to [Web Workers](https://developer.mozilla.org/en-US/docs/Web/API/Web_Workers_API)** — Data processing, sorting, and computation that does not need DOM access can run off the main thread
- **Break up long tasks** — Use `requestIdleCallback`, `setTimeout(fn, 0)`, or the `scheduler.yield()` API to yield to the main thread between chunks of work
- **Reduce third-party impact** — Load analytics and chat widgets after the page is interactive, or use [Partytown](https://partytown.qwik.dev/) to run them in a Web Worker
- **[Minify JavaScript](/lighthouse/how-to-fix-unminified-javascript/)** — Smaller files parse faster

## People Also Ask

### How is TBT calculated?

TBT sums the blocking portions of all long tasks between First Contentful Paint and Time to Interactive. For each task longer than 50 ms, the blocking time equals the task duration minus 50 ms. A task of 200 ms contributes 150 ms to TBT.

### What is the relationship between TBT and INP?

TBT measures blocking during page load; [Interaction to Next Paint](https://frontman.sh/glossary/interaction-to-next-paint/) measures responsiveness to user interactions throughout the page's lifetime. They both reflect main-thread availability, so fixes that reduce TBT (code splitting, deferring scripts) often improve INP too.

### Does server-side rendering help TBT?

Server-side rendering reduces time to first paint but does not eliminate TBT. The client still needs to hydrate components, which requires parsing and executing JavaScript. Partial hydration, progressive hydration, or [React Server Components](https://frontman.sh/glossary/react-server-components/) can reduce hydration cost.

### What tools besides Lighthouse measure TBT?

Chrome DevTools Performance panel shows individual long tasks. WebPageTest reports TBT. The [Web Vitals Chrome extension](https://chrome.google.com/webstore/detail/web-vitals/) shows real-time metrics. For field data, TBT is not directly measurable in the field, but INP serves as its real-user equivalent.

---

You can use [Frontman](https://frontman.sh) to automatically fix this and any other Lighthouse issue. Frontman runs the audit, reads the results, applies the fixes, and verifies the improvement — all inside the browser you are already working in. [Get started with one install command](https://frontman.sh/blog/getting-started/).
