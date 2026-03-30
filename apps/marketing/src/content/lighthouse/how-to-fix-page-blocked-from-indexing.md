---
title: "How to Fix Page Blocked From Indexing"
description: "Lighthouse flags pages that prevent search engines from indexing them. Learn how to identify and remove unintentional indexing blocks so your pages appear in search results."
pubDate: 2026-03-10T00:00:00Z
auditId: "is-crawlable"
category: "seo"
weight: 4
faq:
  - question: "How does Lighthouse detect blocked indexing?"
    answer: "Lighthouse checks for meta robots tags with 'noindex', X-Robots-Tag HTTP headers with 'noindex', and robots.txt rules that block the page. If any of these prevent search engine indexing, the audit fails."
  - question: "What is the difference between noindex and robots.txt blocking?"
    answer: "noindex (via meta tag or HTTP header) tells search engines to remove the page from their index but still allows crawling. robots.txt Disallow prevents crawlers from accessing the page entirely. Use noindex for pages you want crawled but not indexed; use robots.txt for pages you want fully blocked."
  - question: "Can I accidentally noindex my entire site?"
    answer: "Yes. Common causes include a development robots.txt with 'Disallow: /' deployed to production, a global meta robots tag with 'noindex' set in the base layout, or an HTTP header middleware that adds X-Robots-Tag: noindex to all responses."
  - question: "Can Frontman fix indexing issues automatically?"
    answer: "Yes. Tell Frontman to fix your Lighthouse issues and it handles the rest. It runs the audit, fixes the code, and re-runs the audit to check the score improved — iterating until the metrics pass."
---

## What Lighthouse Is Telling You

When Lighthouse flags "Page isn't blocked from indexing" as failing, it means the page has a directive that prevents search engines from including it in their index. This is the **highest-weighted SEO audit** — Lighthouse designed it so that failing this single audit drops the SEO category below 69%.

If this page should be publicly searchable, the indexing block needs to be removed.

## Why Pages Get Blocked Accidentally

- **Development `noindex` left in production** — Adding [`<meta name="robots" content="noindex">`](https://developer.mozilla.org/en-US/docs/Web/HTML/Element/meta/name) during development and forgetting to remove it before deployment
- **robots.txt blocking** — A `Disallow: /` rule in `robots.txt` that was meant for staging but got deployed to production
- **HTTP header middleware** — Server or CDN middleware that adds `X-Robots-Tag: noindex` to responses globally instead of targeting specific paths
- **Framework defaults** — Some frameworks or boilerplate templates include `noindex` in the base layout as a safety measure
- **Environment confusion** — Using the same configuration for staging and production without differentiating robot directives

## The Old Way to Fix It

1. Run Lighthouse and see the "is-crawlable" audit fail
2. View the page source and search for `<meta name="robots">`
3. Check HTTP response headers for `X-Robots-Tag` using DevTools Network panel
4. Check `/robots.txt` for Disallow rules matching the page's path
5. Determine whether the block is intentional (login pages, admin panels) or accidental (public content)
6. Remove the blocking directive from the meta tag, HTTP header, or robots.txt
7. Wait for search engines to recrawl and reindex the page
8. Verify with Google Search Console's URL Inspection tool

## The Frontman Way

Tell Frontman to fix your Lighthouse issues. That is the entire workflow.

Frontman has a built-in Lighthouse tool. It runs the audit, reads the failing scores, fixes the underlying code, and re-runs the audit to verify the score went up. If issues remain, it keeps going — iterating through fixes and re-checks until the metrics pass. You do not hunt through meta tags, HTTP headers, and robots.txt to find the blocking directive. You say "fix the Lighthouse issues on this page" and Frontman handles the rest.

## Key Fixes

- **Remove `noindex` from meta robots** — Change `<meta name="robots" content="noindex">` to `<meta name="robots" content="index, follow">` or remove the meta tag entirely (indexing is the default)
- **Fix robots.txt** — Remove or narrow `Disallow` rules that block important pages. Use `Allow` for specific paths within a blocked directory
- **Remove X-Robots-Tag headers** — Check server config (nginx, Apache, Vercel, Netlify) and CDN settings for headers that add `noindex`
- **Use environment-specific config** — Set `noindex` only in staging/development environments. Use environment variables: `if (process.env.NODE_ENV !== 'production') { noindex = true }`
- **Audit your robots.txt** — Keep `robots.txt` in version control. Review it during deployment. Use [Google's robots.txt documentation](https://developers.google.com/search/docs/crawling-indexing/robots/intro) to verify the rules you ship
- **Use [Google Search Console](https://developers.google.com/search/docs/crawling-indexing/robots-meta-tag)** — After fixing, use the URL Inspection tool to request reindexing and verify the page is indexable

## People Also Ask

### Should some pages be noindexed?

Yes. Pages that should have `noindex`: login pages, admin panels, internal search results, user dashboards, thank-you pages after form submission, and paginated archives (if using `rel="canonical"` to the first page). Only noindex pages you intentionally want excluded from search.

### How long does it take for Google to reindex a page?

After removing the `noindex` directive, Google typically recrawls within days to weeks. You can speed this up by requesting indexing via Google Search Console's URL Inspection tool. Sitemaps help Google discover the change faster.

### Does `nofollow` also prevent indexing?

No. `nofollow` tells search engines not to follow links on the page — it does not prevent indexing. `noindex` prevents indexing. They are separate directives. `<meta name="robots" content="noindex, nofollow">` blocks both indexing and link following.

### Can a canonical tag prevent indexing?

A `rel="canonical"` tag pointing to a different URL tells search engines that this page is a duplicate and the canonical URL is the preferred version. The current page may be dropped from the index in favor of the canonical. This is not the same as `noindex` — it redirects the indexing to another page rather than preventing it entirely.

---

You can use [Frontman](https://frontman.sh) to automatically fix this and any other Lighthouse issue. Frontman runs the audit, reads the results, applies the fixes, and verifies the improvement — all inside the browser you are already working in. [Get started with one install command](https://frontman.sh/blog/getting-started/).
