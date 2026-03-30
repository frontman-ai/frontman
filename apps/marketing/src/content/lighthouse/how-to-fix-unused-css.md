---
title: "How to Fix Unused CSS"
description: "Lighthouse flags CSS rules that are downloaded but never applied during page load. Learn how to audit stylesheets and remove dead CSS to improve performance."
pubDate: 2026-03-10T00:00:00Z
auditId: "unused-css-rules"
category: "performance"
weight: 0
faq:
  - question: "How does Lighthouse detect unused CSS?"
    answer: "Lighthouse uses Chrome's code coverage tool to check which CSS rules are actually applied during page load. Any rule that downloads but does not match any element on the page is flagged as unused."
  - question: "Does Tailwind CSS cause unused CSS issues?"
    answer: "Only if you are not using Tailwind's purge/content configuration. Tailwind v3+ scans your template files and removes unused utility classes during the build. An improperly configured content array will ship the entire utility library (over 3 MB uncompressed)."
  - question: "Is it safe to remove CSS flagged as unused?"
    answer: "Not always. Lighthouse only checks the current page load. CSS for hover states, focus states, JavaScript-triggered classes, and other pages in a shared stylesheet will be flagged as unused even though it is needed. Review flagged rules before removing them."
  - question: "Can Frontman fix unused CSS automatically?"
    answer: "Yes. Tell Frontman to fix your Lighthouse issues and it handles the rest. It runs the audit, fixes the code, and re-runs the audit to check the score improved — iterating until the metrics pass."
---

## What Lighthouse Is Telling You

When Lighthouse flags unused CSS, it means your stylesheets contain rules that download but never apply to any element during page load. CSS is [render-blocking](/lighthouse/how-to-fix-render-blocking-resources/) by default — every unused byte in your stylesheet delays [First Contentful Paint](/lighthouse/how-to-fix-first-contentful-paint-fcp/).

Lighthouse lists each stylesheet with the total bytes and the percentage that went unused. A 200 KB stylesheet where 160 KB is unused means 80% of the CSS is wasted on that page.

## Why There Is Unused CSS

- **Monolithic stylesheets** — One large CSS file shared across all pages, containing rules for pages the user has not visited
- **CSS frameworks without purging** — Bootstrap, Tailwind, or Bulma ship thousands of utility classes. Without purging, the full library downloads on every page
- **Legacy rules** — Components that were removed from the UI but whose styles remain in the stylesheet
- **Unused vendor styles** — CSS from third-party libraries, UI kits, or icon libraries that include styles for components you never use
- **Scoped styles that apply globally** — CSS files imported at the layout level that contain page-specific rules

## The Old Way to Fix It

1. Run Lighthouse and identify flagged stylesheets
2. Open Chrome DevTools Coverage tab, reload, and find stylesheets with high unused percentages
3. Use a tool like PurgeCSS or UnCSS to scan HTML templates and remove unmatched rules
4. Configure your CSS framework's purge/content settings
5. Split stylesheets by page or component
6. Test every page and interaction to make sure you did not remove CSS that is actually needed (hover states, JS-toggled classes, etc.)
7. Re-run Lighthouse

The hardest part is knowing which CSS is truly unused versus CSS that is used under specific conditions — hover states, media queries, JavaScript-toggled classes, and other interactive states.

## The Frontman Way

Tell Frontman to fix your Lighthouse issues. That is the entire workflow.

Frontman has a built-in Lighthouse tool. It runs the audit, reads the failing scores, fixes the underlying code, and re-runs the audit to verify the score went up. If issues remain, it keeps going — iterating through fixes and re-checks until the metrics pass. You do not cross-reference the Coverage tab with your build config. You say "fix the Lighthouse issues on this page" and Frontman handles the rest.

## Key Fixes

- **Configure CSS purging** — PurgeCSS, Tailwind's `content` config, or PostCSS plugins scan your templates and remove unused utility classes at build time
- **Split CSS by page or route** — Instead of one global stylesheet, import CSS at the page or component level using [`@media`](https://developer.mozilla.org/en-US/docs/Web/CSS/@media) queries or framework-level scoping. Next.js and Astro scope styles per component by default
- **Use [CSS Modules](https://github.com/css-modules/css-modules) or scoped styles** — CSS Modules (`*.module.css`) scope class names to the component that imports them, preventing global style accumulation
- **Inline critical CSS** — Use `critters` or `critical` to inline above-the-fold styles and defer the rest
- **Remove unused vendor CSS** — If you use 5 icons from a 500-icon library, switch to individual SVG imports or a custom icon subset
- **Audit with the Coverage tab** — Chrome DevTools Coverage shows real-time CSS usage. Sort by unused bytes to find the biggest opportunities

## People Also Ask

### Does CSS-in-JS solve the unused CSS problem?

CSS-in-JS libraries like styled-components, Emotion, or vanilla-extract generate only the styles used by rendered components. This eliminates unused CSS by design. The tradeoff is runtime cost (for runtime CSS-in-JS) or build complexity (for zero-runtime solutions).

### Can I defer CSS without breaking the page?

Yes, for non-critical CSS. The pattern is: `<link rel="stylesheet" href="styles.css" media="print" onload="this.media='all'">` with a `<noscript>` fallback. Critical (above-the-fold) CSS should be inlined in `<head>` so the page renders correctly before the deferred stylesheet loads.

### How does `content-visibility: auto` relate to unused CSS?

`content-visibility: auto` tells the browser to skip rendering off-screen elements. This does not remove unused CSS rules from the stylesheet, but it reduces the rendering cost of applying them. The CSS bytes still download — the savings are in rendering time, not transfer size.

### Does HTTP/2 push help with CSS loading?

HTTP/2 Server Push was deprecated by most browsers. Instead, use `<link rel="preload" as="style">` to hint at critical stylesheets. Preloading fetches the resource early without blocking rendering.

---

You can use [Frontman](https://frontman.sh) to automatically fix this and any other Lighthouse issue. Frontman runs the audit, reads the results, applies the fixes, and verifies the improvement — all inside the browser you are already working in. [Get started with one install command](https://frontman.sh/blog/getting-started/).
