---
"@frontman-ai/astro": minor
---

Use Astro's `astro:routes:resolved` hook (v5+) for route discovery in `get_client_pages` tool

The `get_client_pages` tool now returns routes resolved by Astro's router instead of scanning the filesystem. This catches routes that filesystem scanning misses: content collection routes, config-defined redirects, API endpoints, integration-injected routes (e.g. `@astrojs/sitemap`), and internal fallbacks. Each route now includes params, type, origin, and prerender status.

On Astro v4, the tool falls back to the existing filesystem scanner.
