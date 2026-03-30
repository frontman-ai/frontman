---
title: "How to Fix Render-Blocking Resources"
description: "Render-blocking resources prevent the browser from painting content until they finish loading. Learn how to identify and eliminate them to speed up your page."
pubDate: 2026-03-10T00:00:00Z
auditId: "render-blocking-resources"
category: "performance"
weight: 0
faq:
  - question: "What are render-blocking resources?"
    answer: "Render-blocking resources are CSS stylesheets and synchronous JavaScript files that prevent the browser from rendering any content until they finish downloading and processing. They sit in the critical rendering path and delay First Contentful Paint."
  - question: "Are all CSS files render-blocking?"
    answer: "By default, yes. The browser treats all CSS as render-blocking because it needs to compute styles before painting. You can make CSS non-blocking by using media queries (media='print'), loading it asynchronously, or inlining critical styles."
  - question: "Does async vs defer matter for render blocking?"
    answer: "Both async and defer make scripts non-render-blocking. The difference is execution order: defer scripts execute in document order after HTML parsing; async scripts execute as soon as they download, regardless of order."
  - question: "Can Frontman fix render-blocking resources automatically?"
    answer: "Yes. Tell Frontman to fix your Lighthouse issues and it handles the rest. It runs the audit, fixes the code, and re-runs the audit to check the score improved — iterating until the metrics pass."
---

## What Lighthouse Is Telling You

When Lighthouse flags [render-blocking resources](https://developer.chrome.com/docs/lighthouse/performance/render-blocking-resources/), it means CSS files or synchronous JavaScript in the `<head>` are preventing the browser from painting anything on screen. The browser downloads these resources, parses them, and only then starts rendering — everything before that point is a blank white page.

This audit directly impacts [First Contentful Paint](/lighthouse/how-to-fix-first-contentful-paint-fcp/), [Speed Index](/lighthouse/how-to-fix-speed-index/), and [LCP](/lighthouse/how-to-fix-largest-contentful-paint-lcp/). Lighthouse lists the specific resources that block rendering and estimates the potential savings in milliseconds.

## Why Resources Block Rendering

The browser's rendering pipeline works like this:

1. Download HTML
2. Parse HTML and discover linked CSS and JavaScript
3. Download and parse **all CSS** before any rendering (CSS is render-blocking by default)
4. Download and execute **synchronous JavaScript** in `<head>` before continuing HTML parsing
5. Only after steps 3-4 complete does the browser build the render tree and paint

Every external stylesheet and synchronous script in `<head>` adds to this blocking time. A page with three CSS files and two synchronous scripts might block rendering for 800+ ms on a mobile connection.

## The Old Way to Fix It

1. Run Lighthouse and identify which resources are flagged
2. For each CSS file, determine which rules apply to above-the-fold content (critical CSS)
3. Use a tool like `critical` or `critters` to extract critical CSS
4. Inline the critical CSS in a `<style>` tag in `<head>`
5. Load the full CSS asynchronously using the `media="print"` trick or a JavaScript loader
6. For each script, evaluate whether it needs to run before rendering
7. Add `defer` or `async` attributes, or move scripts to the end of `<body>`
8. Re-run Lighthouse and check if the render-blocking warning is gone
9. Repeat for missed resources

The critical CSS extraction step is the hardest — you need to test across viewport sizes to ensure above-the-fold content is styled correctly.

## The Frontman Way

Tell Frontman to fix your Lighthouse issues. That is the entire workflow.

Frontman has a built-in Lighthouse tool. It runs the audit, reads the failing scores, fixes the underlying code, and re-runs the audit to verify the score went up. If issues remain, it keeps going — iterating through fixes and re-checks until the metrics pass. You do not manually extract critical CSS or figure out which scripts can be deferred. You say "fix the Lighthouse issues on this page" and Frontman handles the rest.

## Key Fixes

- **Inline critical CSS** — Extract above-the-fold styles and put them in a `<style>` tag in `<head>`. Use tools like `critters` (for Webpack/Vite) or `critical` (standalone)
- **Defer non-critical CSS** — Use `<link rel="stylesheet" href="styles.css" media="print" onload="this.media='all'">` to load CSS without blocking
- **Add [`defer`](https://developer.mozilla.org/en-US/docs/Web/HTML/Element/script#defer) to scripts** — `<script src="app.js" defer>` downloads the script without blocking parsing and executes it after HTML is parsed
- **Use `async` for independent scripts** — `<script src="analytics.js" async>` downloads and executes as soon as ready, without blocking
- **[Minify CSS](/lighthouse/how-to-fix-unminified-css/)** — Smaller files download faster, reducing the blocking window
- **Preload critical fonts** — [`<link rel="preload">`](https://developer.mozilla.org/en-US/docs/Web/HTML/Attributes/rel/preload) with `as="font" crossorigin` starts the font download early, reducing the time fonts block text rendering
- **Use `<link rel="modulepreload">`** — For ES modules, `modulepreload` fetches and compiles the module ahead of time

## People Also Ask

### How do I find which resources are render-blocking?

Lighthouse lists them directly. You can also check the Chrome DevTools Network panel — filter by CSS and JS, and look at resources loaded before the first paint marker. The Coverage tab shows how much of each file is actually used during initial load.

### Does inlining all CSS eliminate render blocking?

Inlining eliminates the network request but increases the HTML size. Inline only critical CSS (styles needed for above-the-fold content). The rest should load asynchronously. Inlining the entire stylesheet bloats the HTML document and slows down TTFB.

### Do Google Fonts block rendering?

Yes. A `<link href="https://fonts.googleapis.com/css2?family=..." rel="stylesheet">` in `<head>` is render-blocking. Options: use `font-display: swap` in the font URL (`&display=swap`), self-host the fonts, or preconnect to `fonts.googleapis.com` and `fonts.gstatic.com`.

### What about CSS-in-JS libraries?

CSS-in-JS libraries like styled-components or Emotion extract styles during server-side rendering and inject them inline. This eliminates external CSS requests but adds to the HTML size. The tradeoff depends on the volume of styles generated.

---

You can use [Frontman](https://frontman.sh) to automatically fix this and any other Lighthouse issue. Frontman runs the audit, reads the results, applies the fixes, and verifies the improvement — all inside the browser you are already working in. [Get started with one install command](https://frontman.sh/blog/getting-started/).
