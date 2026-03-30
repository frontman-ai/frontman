---
title: "How to Fix Speed Index"
description: "Speed Index measures how quickly the visible content of a page is populated. Learn how to improve visual completeness during load and lower your Speed Index score."
pubDate: 2026-03-10T00:00:00Z
auditId: "speed-index"
category: "performance"
weight: 10
faq:
  - question: "What is a good Speed Index score?"
    answer: "Lighthouse considers Speed Index good at 3.4 seconds or less. Between 3.4 and 5.8 seconds needs improvement. Above 5.8 seconds is poor."
  - question: "How is Speed Index different from FCP and LCP?"
    answer: "FCP measures when the first content appears. LCP measures when the largest element renders. Speed Index measures how quickly the entire visible area fills in — it captures the visual progression, not just a single moment."
  - question: "Does Speed Index affect SEO?"
    answer: "Speed Index is not a direct ranking signal, but it contributes to the overall Lighthouse Performance score, and slow visual loading correlates with higher bounce rates."
  - question: "Can Frontman fix Speed Index automatically?"
    answer: "Yes. Tell Frontman to fix your Lighthouse issues and it handles the rest. It runs the audit, fixes the code, and re-runs the audit to check the score improved — iterating until the metrics pass."
---

## What Lighthouse Is Telling You

When Lighthouse flags [Speed Index](https://developer.chrome.com/docs/lighthouse/performance/speed-index/), it means the page's visible content is populating slowly. Speed Index carries a **weight of 10** in the Performance score. Unlike metrics that measure a single moment ([FCP](/lighthouse/how-to-fix-first-contentful-paint-fcp/) or [LCP](/lighthouse/how-to-fix-largest-contentful-paint-lcp/)), Speed Index captures how quickly the *entire viewport* becomes visually complete. A page that shows content progressively scores better than one that stays blank for three seconds and then renders everything at once.

Lighthouse calculates Speed Index by capturing video frames of the page loading and computing the area under the visual progress curve.

## Why Speed Index Is High

- **Render-blocking resources** — CSS and synchronous JavaScript prevent any rendering, keeping the screen blank
- **Large above-the-fold images** — Unoptimized images in the viewport load slowly, delaying visual completeness
- **Font loading issues** — `font-display: block` hides text until the font loads, creating gaps in visual progress
- **Client-side rendering** — SPA frameworks that render on the client show a blank or skeleton state until JavaScript executes
- **Heavy main thread work** — Long JavaScript tasks delay rendering between frames

## The Old Way to Fix It

1. Run Lighthouse and note the Speed Index value
2. Record a performance trace and watch the filmstrip to see where visual progress stalls
3. Identify which resources are blocking rendering
4. Inline critical CSS, defer scripts, optimize images
5. Test again and compare filmstrips
6. Iterate until visual progress is smooth

Speed Index is hard to optimize directly because it is a composite measure. You typically fix it by fixing the underlying issues: [render-blocking resources](/lighthouse/how-to-fix-render-blocking-resources/), [unminified CSS](/lighthouse/how-to-fix-unminified-css/), and slow image loading.

## The Frontman Way

Tell Frontman to fix your Lighthouse issues. That is the entire workflow.

Frontman has a built-in Lighthouse tool. It runs the audit, reads the failing scores, fixes the underlying code, and re-runs the audit to verify the score went up. If issues remain, it keeps going — iterating through fixes and re-checks until the metrics pass. You do not compare filmstrips or correlate visual progress stalls with specific resources. You say "fix the Lighthouse issues on this page" and Frontman handles the rest.

## Key Fixes for Speed Index

- **Eliminate [render-blocking resources](/lighthouse/how-to-fix-render-blocking-resources/)** — Inline critical CSS, defer non-critical CSS and JavaScript
- **Optimize above-the-fold images** — Compress, serve in modern formats (WebP/AVIF), and set explicit dimensions
- **Use [`font-display: swap`](https://developer.mozilla.org/en-US/docs/Web/CSS/@font-face/font-display)** — Show text immediately with a fallback font instead of hiding it
- **Server-side render or statically generate** — Send pre-rendered HTML so the browser can start painting without waiting for JavaScript
- **Reduce main thread blocking** — [Cut TBT](/lighthouse/how-to-fix-total-blocking-time-tbt/) to let the browser render frames between JavaScript tasks
- **Preload key resources** — `<link rel="preload">` for fonts, hero images, and critical scripts

## People Also Ask

### Is Speed Index a Core Web Vital?

No. The three Core Web Vitals are [LCP](/lighthouse/how-to-fix-largest-contentful-paint-lcp/), [CLS](/lighthouse/how-to-fix-cumulative-layout-shift-cls/), and [Interaction to Next Paint](https://frontman.sh/glossary/interaction-to-next-paint/). Speed Index is a Lighthouse-specific lab metric.

### Why is my Speed Index high even though FCP is fast?

FCP fires when the first content appears, which could be a small element like a navigation bar. If the rest of the viewport takes a long time to fill in — because of large images, lazy-loaded sections, or slow JavaScript rendering — Speed Index will still be high.

### Does skeleton UI help Speed Index?

Yes. Skeleton screens paint placeholder shapes immediately, which increases the visual completeness score at each frame. The page appears to load progressively even while data is still fetching.

### How does HTTP/2 affect Speed Index?

[HTTP/2](https://developer.mozilla.org/en-US/docs/Web/HTTP/Guides/Connection_management_in_HTTP_1.x) multiplexes multiple requests over a single connection, allowing the browser to download CSS, JavaScript, and images simultaneously. This speeds up visual progress compared to HTTP/1.1, which downloads resources sequentially per connection.

---

You can use [Frontman](https://frontman.sh) to automatically fix this and any other Lighthouse issue. Frontman runs the audit, reads the results, applies the fixes, and verifies the improvement — all inside the browser you are already working in. [Get started with one install command](https://frontman.sh/blog/getting-started/).
